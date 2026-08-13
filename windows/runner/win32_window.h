#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <string>
#include <vector>

// A class abstraction for a high DPI-aware Win32 Window. Intended to be
// inherited from by classes that wish to specialize with custom
// rendering and input handling
class Win32Window {
 public:
  struct Point {
    unsigned int x;
    unsigned int y;
    Point(unsigned int x, unsigned int y) : x(x), y(y) {}
  };

  struct Size {
    unsigned int width;
    unsigned int height;
    Size(unsigned int width, unsigned int height)
        : width(width), height(height) {}
  };

  Win32Window();
  virtual ~Win32Window();

  // Creates a win32 window with |title| that is positioned and sized using
  // |origin| and |size|. New windows are created on the default monitor. Window
  // sizes are specified to the OS in physical pixels, hence to ensure a
  // consistent size this function will scale the inputted width and height as
  // as appropriate for the default monitor. The window is invisible until
  // |Show| is called. Returns true if the window was created successfully.
  bool Create(const std::wstring& title, const Point& origin, const Size& size);

  // Show the current window. Returns true if the window was successfully shown.
  bool Show();

  // Release OS resources associated with window.
  void Destroy();

  // Inserts |content| into the window tree.
  void SetChildContent(HWND content);

  // Returns the backing Window handle to enable clients to set icon and other
  // window properties. Returns nullptr if the window has been destroyed.
  HWND GetHandle();

  // If true, closing this window will quit the application.
  void SetQuitOnClose(bool quit_on_close);

  // Return a RECT representing the bounds of the current client area.
  RECT GetClientArea();

  // When true (pass --overlay), the window *starts* borderless, layered,
  // always-on-top, and click-through outside the registered hit regions,
  // instead of the normal decorated window `flutter run` dev uses. Chrome
  // also switches dynamically at runtime after creation — see
  // SwitchToOverlayChrome/SwitchToNormalChrome — so this reflects the
  // *current* chrome, not just how the window was launched.
  void SetOverlayMode(bool enabled);
  bool IsOverlayMode() const { return overlay_mode_; }

  // Switches to borderless/transparent/click-through/topmost chrome,
  // remembering the current window rect so SwitchToNormalChrome can put it
  // back. Triggered when the user minimizes the normal window — Byte stays
  // on screen instead of vanishing to the taskbar.
  void SwitchToOverlayChrome();

  // Reverses SwitchToOverlayChrome: restores the decorated window at its
  // remembered rect. No-op if there's no normal chrome to return to (e.g. a
  // window launched directly with --overlay).  Triggered by double-tapping
  // Byte while it's floating.
  void SwitchToNormalChrome();

  // Physical-pixel client rectangles that should receive mouse input in
  // overlay mode. Everywhere else is click-through to whatever's beneath.
  void SetHitTestRegions(std::vector<RECT> regions);

 protected:
  // Processes and route salient window messages for mouse handling,
  // size change and DPI. Delegates handling of these to member overloads that
  // inheriting classes can handle.
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when CreateAndShow is called, allowing subclass window-related
  // setup. Subclasses should return false if setup fails.
  virtual bool OnCreate();

  // Called when Destroy is called.
  virtual void OnDestroy();

  // Called whenever chrome switches between normal and overlay at runtime
  // (not on the initial launch-time chrome applied in Create()). Lets
  // FlutterWindow forward the change to Dart over the platform channel.
  virtual void OnChromeModeChanged(bool is_overlay) {}

  HWND child_content_ = nullptr;

 private:
  friend class WindowClassRegistrar;

  // OS callback called by message pump. Handles the WM_NCCREATE message which
  // is passed when the non-client area is being created and enables automatic
  // non-client DPI scaling so that the non-client area automatically
  // responds to changes in DPI. All other messages are handled by
  // MessageHandler.
  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  // Retrieves a class instance pointer for |window|
  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // Update the window frame's theme to match the system theme.
  static void UpdateTheme(HWND const window);

  // Polls the cursor position (via GetCursorPos, which works regardless of
  // whether this window is currently receiving messages) and toggles
  // WS_EX_TRANSPARENT so the window is click-through everywhere except over
  // a registered hit region. This replaces an earlier WM_NCHITTEST-based
  // approach: per-message hit-testing on a child HWND you don't own is
  // unreliable in practice (Flutter's view never reliably click-through'd),
  // whereas toggling WS_EX_TRANSPARENT on the top-level window is the
  // standard, OS-documented way real click-through overlays do this.
  void UpdateClickThroughState();
  bool point_is_in_hit_region_ = true;

  bool quit_on_close_ = false;
  bool overlay_mode_ = false;

  // Window rect (screen coordinates) to return to when leaving overlay
  // chrome. Populated the first time SwitchToOverlayChrome() runs from
  // normal chrome; SwitchToNormalChrome() is a no-op without it.
  RECT normal_chrome_rect_ = {0, 0, 0, 0};
  bool has_normal_chrome_rect_ = false;

  // window handle for top level window.
  HWND window_handle_ = nullptr;

  std::vector<RECT> hit_test_regions_;
};

#endif  // RUNNER_WIN32_WINDOW_H_
