#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>

#include "resource.h"

namespace {

// Polling interval for UpdateClickThroughState(), ~60Hz.
constexpr UINT kClickThroughTimerId = 1;
constexpr UINT kClickThroughIntervalMs = 16;

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
  L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

void Win32Window::SetOverlayMode(bool enabled) {
  overlay_mode_ = enabled;
  if (window_handle_ && overlay_mode_) {
    SwitchToOverlayChrome();
  }
}

void Win32Window::SetHitTestRegions(std::vector<RECT> regions) {
  hit_test_regions_ = std::move(regions);
  // A region may have just appeared/moved under a stationary cursor —
  // re-check immediately rather than waiting for the next mouse move.
  UpdateClickThroughState();
}

void Win32Window::UpdateClickThroughState() {
  if (!window_handle_ || !overlay_mode_) {
    return;
  }

  POINT cursor;
  GetCursorPos(&cursor);
  ScreenToClient(window_handle_, &cursor);

  bool in_region = false;
  for (const RECT& region : hit_test_regions_) {
    if (PtInRect(&region, cursor)) {
      in_region = true;
      break;
    }
  }

  if (in_region == point_is_in_hit_region_) {
    return;
  }
  point_is_in_hit_region_ = in_region;

  LONG ex_style = GetWindowLong(window_handle_, GWL_EXSTYLE);
  if (in_region) {
    ex_style &= ~WS_EX_TRANSPARENT;
  } else {
    ex_style |= WS_EX_TRANSPARENT;
  }
  SetWindowLong(window_handle_, GWL_EXSTYLE, ex_style);
}

void Win32Window::SwitchToOverlayChrome() {
  if (!window_handle_) {
    return;
  }

  // Remember where the decorated window was so SwitchToNormalChrome can put
  // it back. Skipped when already in overlay chrome — in particular, this
  // correctly leaves has_normal_chrome_rect_ false for a window launched
  // directly with --overlay, since it never had a "normal" rect.
  if (!overlay_mode_) {
    GetWindowRect(window_handle_, &normal_chrome_rect_);
    has_normal_chrome_rect_ = true;
  }
  overlay_mode_ = true;

  // Borderless popup.
  LONG style = GetWindowLong(window_handle_, GWL_STYLE);
  style &= ~(WS_OVERLAPPEDWINDOW | WS_CAPTION | WS_THICKFRAME | WS_SYSMENU |
             WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
  style |= WS_POPUP;
  SetWindowLong(window_handle_, GWL_STYLE, style);

  // Layered + always on top. TOOLWINDOW keeps it out of the taskbar.
  LONG ex_style = GetWindowLong(window_handle_, GWL_EXSTYLE);
  ex_style &= ~(WS_EX_APPWINDOW);
  ex_style |= WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW;
  SetWindowLong(window_handle_, GWL_EXSTYLE, ex_style);

  // Per-pixel alpha via DWM frame extension (Flutter paints transparent).
  MARGINS margins = {-1, -1, -1, -1};
  DwmExtendFrameIntoClientArea(window_handle_, &margins);

  // Keep the layered window fully opaque at the host level; content alpha
  // comes from Flutter/DWM composition. Color-key is avoided (breaks Flutter).
  SetLayeredWindowAttributes(window_handle_, 0, 255, LWA_ALPHA);

  // Cover the primary monitor work area (physical pixels). Deliberately NOT
  // passing SWP_SHOWWINDOW here. At initial creation time (called from
  // Create(), before OnCreate() has run) the Flutter engine's D3D surface
  // doesn't exist yet, and compositing a layered + DWM-frame-extended window
  // against a surface that isn't ready caused an immediate
  // STATUS_FATAL_APP_EXIT crash — the window stays positioned-but-hidden and
  // the existing SetNextFrameCallback -> Show() path in
  // FlutterWindow::OnCreate() reveals it once Flutter has painted. On a
  // runtime switch (minimize) the window is already shown with a live
  // surface, so this is a no-op with respect to visibility either way.
  HMONITOR monitor =
      MonitorFromWindow(window_handle_, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info = {};
  monitor_info.cbSize = sizeof(MONITORINFO);
  if (GetMonitorInfo(monitor, &monitor_info)) {
    const RECT& work = monitor_info.rcWork;
    SetWindowPos(window_handle_, HWND_TOPMOST, work.left, work.top,
                 work.right - work.left, work.bottom - work.top,
                 SWP_FRAMECHANGED | SWP_NOACTIVATE);
  } else {
    SetWindowPos(window_handle_, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED | SWP_NOACTIVATE);
  }

  // Cursor position is polled independently of window messages because,
  // by design, this window stops receiving mouse messages entirely once
  // WS_EX_TRANSPARENT is set — GetCursorPos still works in that state,
  // which is exactly why polling (rather than reacting to WM_MOUSEMOVE)
  // is the standard way to drive this toggle.
  SetTimer(window_handle_, kClickThroughTimerId, kClickThroughIntervalMs,
           nullptr);

  OnChromeModeChanged(true);
}

void Win32Window::SwitchToNormalChrome() {
  // No normal rect to return to — either already normal, or this window
  // was launched directly with --overlay and has no decorated state.
  if (!window_handle_ || !overlay_mode_ || !has_normal_chrome_rect_) {
    return;
  }

  KillTimer(window_handle_, kClickThroughTimerId);
  point_is_in_hit_region_ = true;
  hit_test_regions_.clear();

  // Undo the DWM frame extension used for per-pixel alpha in overlay chrome.
  MARGINS margins = {0, 0, 0, 0};
  DwmExtendFrameIntoClientArea(window_handle_, &margins);

  LONG style = GetWindowLong(window_handle_, GWL_STYLE);
  style &= ~WS_POPUP;
  style |= WS_OVERLAPPEDWINDOW;
  SetWindowLong(window_handle_, GWL_STYLE, style);

  LONG ex_style = GetWindowLong(window_handle_, GWL_EXSTYLE);
  ex_style &= ~(WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW |
                WS_EX_TRANSPARENT);
  SetWindowLong(window_handle_, GWL_EXSTYLE, ex_style);

  overlay_mode_ = false;

  const RECT& r = normal_chrome_rect_;
  SetWindowPos(window_handle_, HWND_NOTOPMOST, r.left, r.top,
               r.right - r.left, r.bottom - r.top,
               SWP_FRAMECHANGED | SWP_SHOWWINDOW);
  SetForegroundWindow(window_handle_);

  OnChromeModeChanged(false);
}

bool Win32Window::Create(const std::wstring& title,
                         const Point& origin,
                         const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {static_cast<LONG>(origin.x),
                              static_cast<LONG>(origin.y)};
  HMONITOR monitor = MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  DWORD style = overlay_mode_ ? WS_POPUP : WS_OVERLAPPEDWINDOW;
  DWORD ex_style = overlay_mode_
                       ? (WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW)
                       : 0;

  HWND window = CreateWindowEx(
      ex_style, window_class, title.c_str(), style,
      Scale(origin.x, scale_factor), Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor), Scale(size.height, scale_factor),
      nullptr, nullptr, GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  if (overlay_mode_) {
    SwitchToOverlayChrome();
  } else {
    UpdateTheme(window);
  }

  return OnCreate();
}

bool Win32Window::Show() {
  return ShowWindow(window_handle_, SW_SHOWNORMAL);
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      if (overlay_mode_) {
        KillTimer(hwnd, kClickThroughTimerId);
      }
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_TIMER:
      if (overlay_mode_ && wparam == kClickThroughTimerId) {
        UpdateClickThroughState();
        return 0;
      }
      break;

    case WM_SYSCOMMAND:
      // Minimizing the decorated window would send it to the taskbar and
      // hide Byte entirely. Intercept it and switch to the floating overlay
      // instead, so Byte stays visible; double-tapping Byte switches back.
      if (!overlay_mode_ && (wparam & 0xFFF0) == SC_MINIMIZE) {
        SwitchToOverlayChrome();
        return 0;
      }
      break;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, overlay_mode_ ? HWND_TOPMOST : nullptr,
                   newRectSize->left, newRectSize->top, newWidth, newHeight,
                   (overlay_mode_ ? 0 : SWP_NOZORDER) | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      if (!overlay_mode_) {
        UpdateTheme(hwnd);
      }
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
