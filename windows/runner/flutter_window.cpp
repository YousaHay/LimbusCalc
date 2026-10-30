#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {

// One-shot timer that re-applies the title bar colors shortly after the window
// first appears (see FlutterWindow::OnCreate).
constexpr UINT_PTR kThemeTimerId = 1;
constexpr UINT kThemeTimerDelayMs = 500;

// Converts a Dart ARGB color value to a Win32 COLORREF.
COLORREF ToColorRef(int64_t argb) {
  return RGB((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);
}

// Reads an integer from a method call argument map (Dart ints may arrive as
// 32-bit or 64-bit values).
std::optional<int64_t> GetInt(const flutter::EncodableMap& map,
                              const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return std::nullopt;
  if (auto v = std::get_if<int32_t>(&it->second)) return *v;
  if (auto v = std::get_if<int64_t>(&it->second)) return *v;
  return std::nullopt;
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

  // Lets the app make the title bar follow its light / dark theme.
  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "limbus/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (call.method_name() != "setCaptionColors" || args == nullptr) {
          result->NotImplemented();
          return;
        }
        auto caption = GetInt(*args, "caption");
        auto text = GetInt(*args, "text");
        auto dark = args->find(flutter::EncodableValue("dark"));
        if (!caption || !text || dark == args->end() ||
            !std::holds_alternative<bool>(dark->second)) {
          result->Error("bad_args", "caption, text and dark are required");
          return;
        }
        SetCaptionColors(ToColorRef(*caption), ToColorRef(*text),
                         std::get<bool>(dark->second));
        UpdateTheme(GetHandle());
        result->Success();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
    UpdateTheme(GetHandle());
    // Observed on a recent Windows 11 build with the system dark theme: the
    // caption is switched back to dark around the window's first paint, outside
    // this window procedure. Re-apply once more after it has fully appeared.
    SetTimer(GetHandle(), kThemeTimerId, kThemeTimerDelayMs, nullptr);
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
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
    // Re-apply the title bar colors when the window is shown, activated or the
    // system theme changes. These messages are infrequent, so this is cheap.
    if (message == WM_SHOWWINDOW || message == WM_ACTIVATE ||
        message == WM_SETTINGCHANGE || message == WM_THEMECHANGED ||
        message == WM_DWMCOLORIZATIONCOLORCHANGED) {
      UpdateTheme(hwnd);
    }
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_TIMER:
      if (wparam == kThemeTimerId) {
        KillTimer(hwnd, kThemeTimerId);
        UpdateTheme(hwnd);
        return 0;
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
