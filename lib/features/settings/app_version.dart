import 'package:package_info_plus/package_info_plus.dart';

/// 应用版本：来自构建时写入的版本元数据（pubspec.yaml 的 version，
/// Android 的 versionName / versionCode、Windows 可执行文件版本资源、Web 的 version.json）。
typedef AppVersionLoader = Future<String?> Function();

/// 读取失败时返回 null，由界面显示“未知”。
Future<String?> loadPlatformVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isEmpty) return null;
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version}（构建 ${info.buildNumber}）';
  } catch (_) {
    return null;
  }
}
