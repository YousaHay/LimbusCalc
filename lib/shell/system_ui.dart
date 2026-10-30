import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 系统栏样式：背景透明，由应用的页面背景绘制到系统栏后方；
/// 系统图标明暗与当前主题相反，保证清晰。
///
/// - 状态栏不强制对比度遮罩：其后方就是页面背景，图标明暗已与之匹配。
/// - 导航栏保留系统对比度保护：三键导航时系统会在按钮后加半透明遮罩，
///   手势导航时手势条保持透明。
SystemUiOverlayStyle systemUiStyleFor(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: const Color(0x00000000),
    statusBarIconBrightness: icons,
    // iOS 使用相反语义：指状态栏背景的明暗。
    statusBarBrightness: brightness,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarColor: const Color(0x00000000),
    systemNavigationBarDividerColor: const Color(0x00000000),
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: true,
  );
}

/// 启动时调用一次：Android 上启用边到边显示并应用系统栏样式。
///
/// Android 15 起 targetSdk ≥ 35 默认即为边到边；更早的系统上 FlutterActivity
/// 默认给状态栏加 0x40000000 的半透明黑色遮罩，这里显式改为透明。
/// 其余平台没有可配置的系统栏，不做任何调用。
void configureSystemUi(Brightness brightness) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(systemUiStyleFor(brightness));
}
