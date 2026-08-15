#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>

#include "native_drop_target.h"
#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;
  void OnChromeModeChanged(bool is_overlay) override;

 private:
  void RegisterOverlayChannel();
  void RegisterDropTarget();

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      overlay_channel_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      drop_channel_;
  // Raw, not owned via unique_ptr: COM lifetime (AddRef/Release) governs
  // this, not C++ scope — RegisterDragDrop holds its own reference,
  // RevokeDragDrop + Release() in OnDestroy release both.
  NativeDropTarget* drop_target_ = nullptr;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
