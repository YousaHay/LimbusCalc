import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 读取系统提供的主题色；不支持或失败时返回 null。
typedef SystemColorLoader = Future<Color?> Function();

/// 系统动态取色：Android 12 及以上读取系统调色板（随壁纸变化），
/// Windows / macOS / Linux 读取系统强调色。Web 等其余平台不支持。
/// 不需要任何权限。
Future<Color?> loadSystemSeedColor() async {
  if (kIsWeb) return null;
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    // 调色板的主色调 40 号色即系统主题的关键色。
    if (palette != null) return Color(palette.primary.get(40));
  } catch (_) {
    // 平台未实现或读取失败，继续尝试强调色。
  }
  try {
    final accent = await DynamicColorPlugin.getAccentColor();
    if (accent != null) return accent.withValues(alpha: 1);
  } catch (_) {
    // 平台不支持系统强调色。
  }
  return null;
}
