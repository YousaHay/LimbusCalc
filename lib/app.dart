import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'features/settings/app_settings.dart';
import 'features/settings/app_version.dart';
import 'features/settings/system_color.dart';
import 'home_shell.dart';
import 'shell/window_caption.dart';

class LimbusDamageCalcApp extends StatefulWidget {
  const LimbusDamageCalcApp({
    super.key,
    this.settings,
    this.versionLoader = loadPlatformVersion,
    this.systemColor,
    this.systemColorLoader = loadSystemSeedColor,
  });

  /// 界面设置；为空时使用不持久化的内存设置（测试等场景）。
  final SettingsController? settings;
  final AppVersionLoader versionLoader;

  /// 启动前已读取的系统主题色（避免启动后颜色跳变）；为空表示不支持或尚未读取。
  final Color? systemColor;

  /// 回到前台时重新读取系统主题色（例如更换了壁纸）。
  final SystemColorLoader systemColorLoader;

  @override
  State<LimbusDamageCalcApp> createState() => _LimbusDamageCalcAppState();
}

class _LimbusDamageCalcAppState extends State<LimbusDamageCalcApp>
    with WidgetsBindingObserver {
  SettingsController? _ownedSettings;
  late Color? _systemColor = widget.systemColor;

  SettingsController get _settings =>
      widget.settings ??
      (_ownedSettings ??= SettingsController(MemorySettingsStore()));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    widget.systemColorLoader().then((color) {
      if (!mounted || color == _systemColor) return;
      setState(() => _systemColor = color);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ownedSettings?.dispose();
    super.dispose();
  }

  // 主题只随外观设置变化重建，导航等其他设置变化时复用。
  (Color, ThemeData, ThemeData)? _themes;

  (ThemeData, ThemeData) _themesFor(Color seed) {
    final cached = _themes;
    if (cached != null && cached.$1 == seed) return (cached.$2, cached.$3);
    final light = buildAppTheme(seed: seed);
    final dark = buildAppTheme(brightness: Brightness.dark, seed: seed);
    _themes = (seed, light, dark);
    return (light, dark);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final s = _settings.value;
        // 动态取色不可用时回退到手动颜色，手动颜色本身不会被覆盖。
        final seed = s.useDynamicColor && _systemColor != null
            ? _systemColor!
            : s.seedColor;
        final (light, dark) = _themesFor(seed);
        return MaterialApp(
          title: '边狱巴士伤害计算器',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: s.themeMode.themeMode,
          // 切换主题时短暂的颜色过渡，避免闪屏。
          themeAnimationDuration: const Duration(milliseconds: 200),
          themeAnimationCurve: Curves.easeOut,
          builder: (context, child) {
            final target =
                switch (s.themeMode) {
                  ThemeModePreference.light => Brightness.light,
                  ThemeModePreference.dark => Brightness.dark,
                  ThemeModePreference.system => MediaQuery.platformBrightnessOf(
                    context,
                  ),
                } ==
                Brightness.dark;
            final palette = (target ? dark : light).extension<AppPalette>()!;
            return WindowCaptionSync(
              dark: target,
              caption: palette.page,
              text: palette.textPrimary,
              child: child!,
            );
          },
          home: HomeShell(
            settings: _settings,
            versionLoader: widget.versionLoader,
            systemColorAvailable: _systemColor != null,
          ),
        );
      },
    );
  }
}
