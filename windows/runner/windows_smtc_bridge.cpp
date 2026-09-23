#include "windows_smtc_bridge.h"
#include "windows_smtc_bridge_api.h"

#include <windows.h>
#include <SystemMediaTransportControlsInterop.h>

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <thread>
#include <utility>

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/base.h>

namespace echoes {
namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using winrt::Windows::Foundation::TimeSpan;
using winrt::Windows::Media::MediaPlaybackStatus;
using winrt::Windows::Media::SystemMediaTransportControls;
using winrt::Windows::Media::SystemMediaTransportControlsButton;
using winrt::Windows::Media::SystemMediaTransportControlsTimelineProperties;
using winrt::Windows::Storage::StorageFile;
using winrt::Windows::Storage::Streams::RandomAccessStreamReference;

const EncodableValue* FindValue(const EncodableMap& values,
                                const std::string& name) {
  const auto found = values.find(EncodableValue(name));
  return found == values.end() ? nullptr : &found->second;
}

std::string ReadString(const EncodableMap& values,
                       const std::string& name,
                       const std::string& fallback = "") {
  const auto* value = FindValue(values, name);
  if (value == nullptr || value->IsNull()) return fallback;
  const auto* string_value = std::get_if<std::string>(value);
  return string_value == nullptr ? fallback : *string_value;
}

bool ReadBool(const EncodableMap& values,
              const std::string& name,
              bool fallback = false) {
  const auto* value = FindValue(values, name);
  if (value == nullptr || value->IsNull()) return fallback;
  const auto* bool_value = std::get_if<bool>(value);
  return bool_value == nullptr ? fallback : *bool_value;
}

int64_t ReadInt64(const EncodableMap& values,
                  const std::string& name,
                  int64_t fallback = 0) {
  const auto* value = FindValue(values, name);
  if (value == nullptr || value->IsNull()) return fallback;
  if (const auto* int64_value = std::get_if<int64_t>(value)) {
    return *int64_value;
  }
  if (const auto* int32_value = std::get_if<int32_t>(value)) {
    return *int32_value;
  }
  return fallback;
}

TimeSpan ToTimeSpan(int64_t microseconds) {
  const auto non_negative = std::max<int64_t>(0, microseconds);
  return std::chrono::duration_cast<TimeSpan>(
      std::chrono::microseconds(non_negative));
}

MediaPlaybackStatus PlaybackStatusFor(const std::string& status) {
  if (status == "playing") return MediaPlaybackStatus::Playing;
  if (status == "changing") return MediaPlaybackStatus::Changing;
  if (status == "stopped") return MediaPlaybackStatus::Stopped;
  if (status == "closed") return MediaPlaybackStatus::Closed;
  return MediaPlaybackStatus::Paused;
}

std::string ButtonName(SystemMediaTransportControlsButton button) {
  switch (button) {
    case SystemMediaTransportControlsButton::Play:
      return "play";
    case SystemMediaTransportControlsButton::Pause:
      return "pause";
    case SystemMediaTransportControlsButton::Next:
      return "next";
    case SystemMediaTransportControlsButton::Previous:
      return "previous";
    case SystemMediaTransportControlsButton::Stop:
      return "stop";
    default:
      return "";
  }
}

}  // namespace

WindowsSmtcBridge::WindowsSmtcBridge(flutter::BinaryMessenger* messenger,
                                     HWND window)
    : window_(window),
      channel_(std::make_unique<
               flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "echoes/windows_smtc",
          &flutter::StandardMethodCodec::GetInstance())),
      pending_events_(std::make_shared<PendingEventState>()),
      artwork_state_(std::make_shared<ArtworkState>()) {
  pending_events_->window = window_;
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

WindowsSmtcBridge::~WindowsSmtcBridge() {
  Dispose();
  if (channel_) channel_->SetMethodCallHandler(nullptr);
}

void WindowsSmtcBridge::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  try {
    const auto* values = std::get_if<EncodableMap>(call.arguments());
    if (call.method_name() == "initialize") {
      Initialize();
      result->Success();
      return;
    }
    if (call.method_name() == "dispose") {
      Dispose();
      result->Success();
      return;
    }
    if (values == nullptr) {
      result->Error("INVALID_ARGUMENTS", "Expected a map payload.");
      return;
    }
    if (call.method_name() == "updateMetadata") {
      UpdateMetadata(*values);
    } else if (call.method_name() == "updatePlayback") {
      UpdatePlayback(*values);
    } else if (call.method_name() == "updateArtwork") {
      UpdateArtwork(*values);
    } else {
      result->NotImplemented();
      return;
    }
    result->Success();
  } catch (const winrt::hresult_error& error) {
    result->Error("SMTC_FAILED", winrt::to_string(error.message()));
  } catch (const std::exception& error) {
    result->Error("SMTC_FAILED", error.what());
  } catch (...) {
    result->Error("SMTC_FAILED", "Unknown native media-control error.");
  }
}

void WindowsSmtcBridge::Initialize() {
  if (initialized_) return;
  {
    const std::lock_guard<std::mutex> lock(pending_events_->mutex);
    pending_events_->closing = false;
    pending_events_->controls.clear();
  }
  {
    const std::lock_guard<std::mutex> lock(artwork_state_->mutex);
    artwork_state_->closing = false;
  }

  // Bind the transport session to Flutter's top-level HWND. Audio remains
  // owned by just_audio; this adapter only publishes metadata and commands.
  const auto interop = winrt::get_activation_factory<
      SystemMediaTransportControls, ISystemMediaTransportControlsInterop>();
  winrt::check_hresult(interop->GetForWindow(
      window_, winrt::guid_of<SystemMediaTransportControls>(),
      winrt::put_abi(smtc_)));
  updater_ = smtc_.DisplayUpdater();
  smtc_.IsEnabled(false);
  smtc_.IsPlayEnabled(false);
  smtc_.IsPauseEnabled(false);
  smtc_.IsNextEnabled(false);
  smtc_.IsPreviousEnabled(false);

  std::weak_ptr<PendingEventState> weak_events = pending_events_;
  button_pressed_token_ = smtc_.ButtonPressed(
      [weak_events](const auto&, const auto& args) {
        const auto state = weak_events.lock();
        if (!state) return;
        const auto type = ButtonName(args.Button());
        if (type.empty()) return;
        {
          const std::lock_guard<std::mutex> lock(state->mutex);
          if (state->closing) return;
          state->controls.push_back(PendingControl{type, 0});
        }
        PostMessage(state->window, kWindowsSmtcEventMessage, 0, 0);
      });

  position_change_token_ = smtc_.PlaybackPositionChangeRequested(
      [weak_events](const auto&, const auto& args) {
        const auto state = weak_events.lock();
        if (!state) return;
        const auto requested = std::chrono::duration_cast<std::chrono::microseconds>(
                                   args.RequestedPlaybackPosition())
                                   .count();
        {
          const std::lock_guard<std::mutex> lock(state->mutex);
          if (state->closing) return;
          state->controls.push_back(PendingControl{"seek", requested});
        }
        PostMessage(state->window, kWindowsSmtcEventMessage, 0, 0);
      });

  initialized_ = true;
}

void WindowsSmtcBridge::UpdateMetadata(const EncodableMap& values) {
  if (!initialized_) Initialize();
  const auto has_track = ReadBool(values, "hasTrack");
  const auto clear_artwork = ReadBool(values, "clearArtwork", true);
  const auto generation = static_cast<uint64_t>(
      std::max<int64_t>(0, ReadInt64(values, "artworkGeneration")));

  {
    const std::lock_guard<std::mutex> lock(artwork_state_->mutex);
    artwork_state_->generation = generation;
    artwork_state_->updater = updater_;
  }

  if (!has_track) {
    updater_.ClearAll();
    updater_.Update();
    smtc_.IsEnabled(false);
    smtc_.PlaybackStatus(MediaPlaybackStatus::Stopped);
    return;
  }

  if (clear_artwork) updater_.ClearAll();
  updater_.Type(winrt::Windows::Media::MediaPlaybackType::Music);
  auto music = updater_.MusicProperties();
  music.Title(winrt::to_hstring(ReadString(values, "title")));
  music.Artist(winrt::to_hstring(ReadString(values, "artist")));
  music.AlbumTitle(winrt::to_hstring(ReadString(values, "album")));
  updater_.Update();
  smtc_.IsEnabled(true);

  const auto art_path = ReadString(values, "artworkPath");
  if (!art_path.empty()) StartArtworkLoad(art_path, generation);
}

void WindowsSmtcBridge::UpdatePlayback(const EncodableMap& values) {
  if (!initialized_) Initialize();

  const auto has_track = ReadBool(values, "hasTrack");
  const auto can_seek = has_track && ReadBool(values, "canSeek");
  const auto duration = std::max<int64_t>(
      0, ReadInt64(values, "durationMicroseconds"));
  const auto position = std::clamp<int64_t>(
      ReadInt64(values, "positionMicroseconds"), 0, duration);

  smtc_.IsEnabled(has_track);
  smtc_.IsPlayEnabled(has_track && ReadBool(values, "canPlay"));
  smtc_.IsPauseEnabled(has_track && ReadBool(values, "canPause"));
  smtc_.IsNextEnabled(has_track && ReadBool(values, "canGoNext"));
  smtc_.IsPreviousEnabled(has_track && ReadBool(values, "canGoPrevious"));
  smtc_.PlaybackStatus(PlaybackStatusFor(ReadString(values, "status", "stopped")));

  SystemMediaTransportControlsTimelineProperties timeline;
  timeline.StartTime(ToTimeSpan(0));
  timeline.EndTime(ToTimeSpan(duration));
  timeline.Position(ToTimeSpan(position));
  timeline.MinSeekTime(ToTimeSpan(0));
  timeline.MaxSeekTime(ToTimeSpan(can_seek ? duration : 0));
  smtc_.UpdateTimelineProperties(timeline);
}

void WindowsSmtcBridge::UpdateArtwork(const EncodableMap& values) {
  if (!initialized_) Initialize();
  const auto generation = static_cast<uint64_t>(
      std::max<int64_t>(0, ReadInt64(values, "artworkGeneration")));
  const auto path = ReadString(values, "artworkPath");
  if (path.empty()) return;

  {
    const std::lock_guard<std::mutex> lock(artwork_state_->mutex);
    if (generation != artwork_state_->generation || artwork_state_->closing) {
      return;
    }
  }
  StartArtworkLoad(path, generation);
}

void WindowsSmtcBridge::StartArtworkLoad(const std::string& path,
                                         uint64_t generation) {
  const auto state = artwork_state_;
  const auto local_path = winrt::to_hstring(path);
  std::thread([state, local_path, generation]() {
    try {
      winrt::init_apartment(winrt::apartment_type::multi_threaded);
      const auto file = StorageFile::GetFileFromPathAsync(local_path).get();
      const auto thumbnail = RandomAccessStreamReference::CreateFromFile(file);
      const std::lock_guard<std::mutex> lock(state->mutex);
      if (state->closing || generation != state->generation ||
          state->updater == nullptr) {
        return;
      }
      state->updater.Thumbnail(thumbnail);
      state->updater.Update();
    } catch (...) {
      // The UI, transport buttons, and audio session remain available.
    }
  }).detach();
}

void WindowsSmtcBridge::QueueControl(PendingControl control) {
  {
    const std::lock_guard<std::mutex> lock(pending_events_->mutex);
    if (pending_events_->closing) return;
    pending_events_->controls.push_back(std::move(control));
  }
  PostMessage(window_, kWindowsSmtcEventMessage, 0, 0);
}

void WindowsSmtcBridge::DispatchPendingEvents() {
  std::deque<PendingControl> controls;
  {
    const std::lock_guard<std::mutex> lock(pending_events_->mutex);
    controls.swap(pending_events_->controls);
  }

  for (const auto& control : controls) {
    EncodableMap payload;
    payload.emplace(EncodableValue("type"), EncodableValue(control.type));
    if (control.type == "seek") {
      payload.emplace(EncodableValue("positionMicroseconds"),
                      EncodableValue(control.position_microseconds));
    }
    channel_->InvokeMethod(
        "onControl", std::make_unique<EncodableValue>(std::move(payload)));
  }
}

void WindowsSmtcBridge::Dispose() {
  if (pending_events_) {
    const std::lock_guard<std::mutex> lock(pending_events_->mutex);
    pending_events_->closing = true;
    pending_events_->controls.clear();
  }
  if (artwork_state_) {
    const std::lock_guard<std::mutex> lock(artwork_state_->mutex);
    artwork_state_->closing = true;
    artwork_state_->generation += 1;
    artwork_state_->updater = nullptr;
  }

  if (smtc_ != nullptr) {
    smtc_.ButtonPressed(button_pressed_token_);
    smtc_.PlaybackPositionChangeRequested(position_change_token_);
    smtc_.IsEnabled(false);
    smtc_.PlaybackStatus(MediaPlaybackStatus::Closed);
  }
  if (updater_ != nullptr) {
    updater_.ClearAll();
    updater_.Update();
  }
  updater_ = nullptr;
  smtc_ = nullptr;
  initialized_ = false;
}

std::shared_ptr<WindowsSmtcBridge> CreateWindowsSmtcBridge(
    flutter::BinaryMessenger* messenger,
    HWND window) {
  return std::make_shared<WindowsSmtcBridge>(messenger, window);
}

void DispatchWindowsSmtcBridgeEvents(
    const std::shared_ptr<WindowsSmtcBridge>& bridge) {
  if (bridge) bridge->DispatchPendingEvents();
}

}  // namespace echoes
