#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <string>
#include "app_links/app_links_plugin_c_api.h"

#include "flutter_window.h"
#include "utils.h"

static void RegisterBeautyStudioProtocol() {
  std::wstring executable(32768, L'\0');
  DWORD length = GetModuleFileNameW(nullptr, executable.data(), static_cast<DWORD>(executable.size()));
  if (length == 0 || length >= executable.size()) return;
  executable.resize(length);
  HKEY key;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\beautystudio", 0, nullptr, 0, KEY_WRITE, nullptr, &key, nullptr) != ERROR_SUCCESS) return;
  const std::wstring description = L"URL:BeautyStudio Protocol";
  RegSetValueExW(key, nullptr, 0, REG_SZ, reinterpret_cast<const BYTE*>(description.c_str()), static_cast<DWORD>((description.size() + 1) * sizeof(wchar_t)));
  RegSetValueExW(key, L"URL Protocol", 0, REG_SZ, reinterpret_cast<const BYTE*>(L""), sizeof(wchar_t));
  RegCloseKey(key);
  if (RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\beautystudio\\shell\\open\\command", 0, nullptr, 0, KEY_WRITE, nullptr, &key, nullptr) != ERROR_SUCCESS) return;
  const std::wstring command = L"\"" + executable + L"\" \"%1\"";
  RegSetValueExW(key, nullptr, 0, REG_SZ, reinterpret_cast<const BYTE*>(command.c_str()), static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(key);
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  if (SendAppLinkToInstance()) return EXIT_SUCCESS;
  RegisterBeautyStudioProtocol();
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

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"beautystudio_aplikacija", origin, size)) {
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
