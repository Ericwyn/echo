#ifndef RUNNER_WINDOWS_SMTC_BRIDGE_H_
#define RUNNER_WINDOWS_SMTC_BRIDGE_H_

#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <winrt/Windows.Media.h>

#include <deque>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>

namespace echoes {

/// Bridges the one shared Flutter playback snapshot to Windows SMTC.
/// A MediaPlayer is used only as a WinRT SMTC host; it never receives a source.
class WindowsSmtcBridge {
 public:
  WindowsSmtcBridge(flutter::BinaryMessenger* messenger, HWND window);
  ~WindowsSmtcBridge();

  WindowsSmtcBridge(const WindowsSmtcBridge&) = delete;
  WindowsSmtcBridge& operator=(const WindowsSmtcBridge&) = delete;

  void DispatchPendingEvents();

 private:
  struct PendingControl {
    std::string type;
    int64_t position_microseconds = 0;
  };

  struct PendingEventState {
    HWND window = nullptr;
    std::mutex mutex;
    std::deque<PendingControl> controls;
    bool closing = false;
  };

  struct ArtworkState {
    std::mutex mutex;
    winrt::Windows::Media::SystemMediaTransportControlsDisplayUpdater updater{
        nullptr};
    uint64_t generation = 0;
    bool closing = false;
  };

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Initialize();
  void UpdateMetadata(const flutter::EncodableMap& values);
  void UpdatePlayback(const flutter::EncodableMap& values);
  void UpdateArtwork(const flutter::EncodableMap& values);
  void Dispose();
  void StartArtworkLoad(const std::string& path, uint64_t generation);
  void QueueControl(PendingControl control);

  HWND window_ = nullptr;
  bool initialized_ = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  winrt::Windows::Media::SystemMediaTransportControls smtc_{nullptr};
  winrt::Windows::Media::SystemMediaTransportControlsDisplayUpdater updater_{
      nullptr};
  winrt::event_token button_pressed_token_{};
  winrt::event_token position_change_token_{};
  std::shared_ptr<PendingEventState> pending_events_;
  std::shared_ptr<ArtworkState> artwork_state_;
};

}  // namespace echoes

#endif  // RUNNER_WINDOWS_SMTC_BRIDGE_H_
