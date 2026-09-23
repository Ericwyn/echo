#ifndef RUNNER_WINDOWS_SMTC_BRIDGE_API_H_
#define RUNNER_WINDOWS_SMTC_BRIDGE_API_H_

#include <windows.h>

#include <memory>

namespace flutter {
class BinaryMessenger;
}

namespace echoes {

inline constexpr UINT kWindowsSmtcEventMessage = WM_APP + 0x42;

class WindowsSmtcBridge;

std::shared_ptr<WindowsSmtcBridge> CreateWindowsSmtcBridge(
    flutter::BinaryMessenger* messenger,
    HWND window);
void DispatchWindowsSmtcBridgeEvents(
    const std::shared_ptr<WindowsSmtcBridge>& bridge);

}  // namespace echoes

#endif  // RUNNER_WINDOWS_SMTC_BRIDGE_API_H_
