#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr char kOverlayChannelName[] = "detective_byte/desktop_overlay";

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
        result->NotImplemented();
      });
}

void FlutterWindow::OnDestroy() {
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
