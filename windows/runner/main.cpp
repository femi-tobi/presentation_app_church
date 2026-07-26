#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  bool is_audience = false;
  int offset_x = 10;
  int offset_y = 10;
  int width = 1280;
  int height = 720;

  for (size_t i = 0; i < command_line_arguments.size(); ++i) {
    if (command_line_arguments[i] == "--audience") {
      is_audience = true;
    } else if (command_line_arguments[i] == "--offset-x" && i + 1 < command_line_arguments.size()) {
      try { offset_x = std::stoi(command_line_arguments[i + 1]); } catch (...) {}
    } else if (command_line_arguments[i] == "--offset-y" && i + 1 < command_line_arguments.size()) {
      try { offset_y = std::stoi(command_line_arguments[i + 1]); } catch (...) {}
    } else if (command_line_arguments[i] == "--width" && i + 1 < command_line_arguments.size()) {
      try { width = std::stoi(command_line_arguments[i + 1]); } catch (...) {}
    } else if (command_line_arguments[i] == "--height" && i + 1 < command_line_arguments.size()) {
      try { height = std::stoi(command_line_arguments[i + 1]); } catch (...) {}
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(offset_x, offset_y);
  Win32Window::Size size(width, height);
  if (!window.Create(L"presentation_app", origin, size, is_audience)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
