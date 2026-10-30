import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'features/settings/app_settings.dart';
import 'features/settings/system_color.dart';
import 'shell/system_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 打包的 Noto Sans SC 子集字体遵循 SIL OFL 1.1。
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Noto Sans SC'], license);
  });
  // 本项目（LimbusCalc）以 GPL-3.0 发布。
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(const ['LimbusCalc'], license);
  });
  // 高级计算的计算模型移植自 MirrorCalcWeb（MIT）。
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(
      'assets/licenses/MirrorCalcWeb-LICENSE.txt',
    );
    yield LicenseEntryWithLineBreaks(const ['MirrorCalcWeb'], license);
  });

  // 先读取设置与系统主题色再显示，避免启动后先闪出错误的主题或导航布局；
  // 读取失败或超时使用默认值。
  final settings = SettingsController(SharedPreferencesSettingsStore());
  final systemColor = loadSystemSeedColor().timeout(
    const Duration(seconds: 2),
    onTimeout: () => null,
  );
  await settings.load();
  final brightness = switch (settings.value.themeMode) {
    ThemeModePreference.light => Brightness.light,
    ThemeModePreference.dark => Brightness.dark,
    ThemeModePreference.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
  };
  configureSystemUi(brightness);
  runApp(
    LimbusDamageCalcApp(settings: settings, systemColor: await systemColor),
  );
}
