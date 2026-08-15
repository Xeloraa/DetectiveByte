#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr char kOverlayChannelName[] = "detective_byte/desktop_overlay";
constexpr char kDropChannelName[] = "detective_byte/native_drop";

std::vector<RECT> ParseHitRegions(const flutter::EncodableValue* arguments) {
  std::vector<RECT> regions;
  if (arguments == nullptr ||
      !std::holds_alternative<flutter::EncodableList>(*arguments)) {
    return regions;
  }

  const auto& list = std::get<flutter::EncodableList>(*arguments);
  for (const auto& item : list) {
    if (!std::holds_alternative<flutter::EncodableMap>(item)) {
      continue;
    }
    const auto& map = std::get<flutter::EncodableMap>(item);

    auto read_num = [&map](const char* key) -> double {
      auto it = map.find(flutter::EncodableValue(key));
      if (it == map.end()) {
        return 0;
      }
      if (std::holds_alternative<double>(it->second)) {
        return std::get<double>(it->second);
      }
      if (std::holds_alternative<int32_t>(it->second)) {
        return static_cast<double>(std::get<int32_t>(it->second));
      }
      if (std::holds_alternative<int64_t>(it->second)) {
        return static_cast<double>(std::get<int64_t>(it->second));
      }
      return 0;
    };

    RECT rect;
    rect.left = static_cast<LONG>(read_num("left"));
    rect.top = static_cast<LONG>(read_num("top"));
    rect.right = static_cast<LONG>(read_num("right"));
    rect.bottom = static_cast<LONG>(read_num("bottom"));
    if (rect.right > rect.left && rect.bottom > rect.top) {
      regions.push_back(rect);
    }
  }
  return regions;
}

}  // namespace

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

  RegisterOverlayChannel();
  RegisterDropTarget();

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::RegisterOverlayChannel() {
  if (!flutter_controller_ || !flutter_controller_->engine()) {
    return;
  }

  overlay_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kOverlayChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  overlay_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const std::string& method = call.method_name();
        if (method == "isOverlayMode") {
          result->Success(flutter::EncodableValue(IsOverlayMode()));
          return;
        }
        if (method == "updateHitRegions") {
          if (!IsOverlayMode()) {
            result->Success();
            return;
          }
          SetHitTestRegions(ParseHitRegions(call.arguments()));
          result->Success();
          return;
        }
        if (method == "restoreNormalWindow") {
          SwitchToNormalChrome();
          result->Success();
          return;
        }
        if (method == "closeApp") {
          // Routes through the normal WM_CLOSE -> WM_DESTROY path (same as
          // clicking the window's own close button) rather than exiting the
          // process directly, so teardown (flutter_controller_ reset, etc.)
          // happens the same way either way.
          PostMessage(GetHandle(), WM_CLOSE, 0, 0);
          result->Success();
          return;
        }
        result->NotImplemented();
      });
}

void FlutterWindow::RegisterDropTarget() {
  if (!flutter_controller_ || !flutter_controller_->engine()) {
    return;
  }

  drop_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), kDropChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  // RegisterDragDrop requires OLE (not just plain COM) to be initialized —
  // done once via OleInitialize in main.cpp's wWinMain, ahead of window
  // creation.
  drop_target_ = new NativeDropTarget(GetHandle(), drop_channel_.get());
  if (FAILED(RegisterDragDrop(GetHandle(), drop_target_))) {
    drop_target_->Release();
    drop_target_ = nullptr;
  }
}

void FlutterWindow::OnChromeModeChanged(bool is_overlay) {
  if (!overlay_channel_) {
    // Fires during the initial Create() chrome application too, before the
    // engine/channel exist yet — Dart picks up that initial state itself via
    // the "isOverlayMode" query once it starts, so this is a safe no-op.
    return;
  }
  overlay_channel_->InvokeMethod(
      "chromeModeChanged",
      std::make_unique<flutter::EncodableValue>(is_overlay));
}

void FlutterWindow::OnDestroy() {
  if (drop_target_) {
    RevokeDragDrop(GetHandle());
    drop_target_->Release();
    drop_target_ = nullptr;
  }
  drop_channel_ = nullptr;

  overlay_channel_ = nullptr;
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
