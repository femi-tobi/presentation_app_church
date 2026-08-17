#include "flutter_window.h"

#include <optional>
#include <vector>
#include <string>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Setup MethodChannel for native fullscreen and topmost controls
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "window_control",
      &flutter::StandardMethodCodec::GetInstance());

  HWND hwnd = GetHandle();

  channel_->SetMethodCallHandler(
      [hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setFullscreen") {
          const auto* arguments = std::get_if<flutter::EncodableMap>(call.arguments());
          bool fullscreen = false;
          if (arguments) {
            auto it = arguments->find(flutter::EncodableValue("fullscreen"));
            if (it != arguments->end()) {
              fullscreen = std::get<bool>(it->second);
            }
          }

          static WINDOWPLACEMENT g_wpPrev = { sizeof(g_wpPrev) };
          DWORD dwStyle = GetWindowLong(hwnd, GWL_STYLE);
          if (fullscreen) {
            MONITORINFO mi = { sizeof(mi) };
            if (GetWindowPlacement(hwnd, &g_wpPrev) &&
                GetMonitorInfo(MonitorFromWindow(hwnd, MONITOR_DEFAULTTOPRIMARY), &mi)) {
              SetWindowLong(hwnd, GWL_STYLE, dwStyle & ~WS_OVERLAPPEDWINDOW);
              SetWindowPos(hwnd, HWND_TOPMOST,
                           mi.rcMonitor.left, mi.rcMonitor.top,
                           mi.rcMonitor.right - mi.rcMonitor.left,
                           mi.rcMonitor.bottom - mi.rcMonitor.top,
                           SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
            }
          } else {
            SetWindowLong(hwnd, GWL_STYLE, dwStyle | WS_OVERLAPPEDWINDOW);
            SetWindowPlacement(hwnd, &g_wpPrev);
            SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                         SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                         SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "showWindow") {
          ShowWindow(hwnd, SW_SHOW);
          SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "hideWindow") {
          ShowWindow(hwnd, SW_HIDE);
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "getDisplays") {
          struct MonitorData {
            std::wstring name;
            int x;
            int y;
            int width;
            int height;
            bool is_primary;
          };
          std::vector<MonitorData> monitors;

          EnumDisplayMonitors(nullptr, nullptr, [](HMONITOR hMonitor, HDC hdcMonitor, LPRECT lprcMonitor, LPARAM dwData) -> BOOL {
            auto* list = reinterpret_cast<std::vector<MonitorData>*>(dwData);
            MONITORINFOEXW mi;
            mi.cbSize = sizeof(mi);
            if (GetMonitorInfoW(hMonitor, &mi)) {
              MonitorData data;
              data.name = mi.szDevice;
              data.x = mi.rcMonitor.left;
              data.y = mi.rcMonitor.top;
              data.width = mi.rcMonitor.right - mi.rcMonitor.left;
              data.height = mi.rcMonitor.bottom - mi.rcMonitor.top;
              data.is_primary = (mi.dwFlags & MONITORINFOF_PRIMARY) != 0;
              list->push_back(data);
            }
            return TRUE;
          }, reinterpret_cast<LPARAM>(&monitors));

          flutter::EncodableList list;
          for (const auto& m : monitors) {
            std::string name_utf8;
            if (!m.name.empty()) {
              int size_needed = WideCharToMultiByte(CP_UTF8, 0, &m.name[0], (int)m.name.size(), NULL, 0, NULL, NULL);
              name_utf8.resize(size_needed);
              WideCharToMultiByte(CP_UTF8, 0, &m.name[0], (int)m.name.size(), &name_utf8[0], size_needed, NULL, NULL);
            }

            std::string display_name = name_utf8;
            if (display_name.rfind("\\\\.\\", 0) == 0) {
              display_name = display_name.substr(4);
            }

            flutter::EncodableMap map;
            map[flutter::EncodableValue("id")] = flutter::EncodableValue(name_utf8);
            map[flutter::EncodableValue("name")] = flutter::EncodableValue(display_name);
            map[flutter::EncodableValue("x")] = flutter::EncodableValue(m.x);
            map[flutter::EncodableValue("y")] = flutter::EncodableValue(m.y);
            map[flutter::EncodableValue("width")] = flutter::EncodableValue(m.width);
            map[flutter::EncodableValue("height")] = flutter::EncodableValue(m.height);
            map[flutter::EncodableValue("isPrimary")] = flutter::EncodableValue(m.is_primary);
            list.push_back(flutter::EncodableValue(map));
          }

          result->Success(flutter::EncodableValue(list));
        } else {
          result->NotImplemented();
        }
      });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
