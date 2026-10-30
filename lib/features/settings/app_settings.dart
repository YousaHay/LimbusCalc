import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 导航布局偏好。
enum NavLayoutPreference {
  auto('自动', '窗口宽度不小于 600 时显示侧栏，较窄时显示底部栏'),
  rail('侧边栏', '始终显示侧栏；宽度不足 840 时为紧凑侧栏，不足 360 时临时改用底部栏'),
  bottom('底部栏', '始终显示悬浮底部栏');

  const NavLayoutPreference(this.label, this.description);
  final String label;
  final String description;
}

/// 主题模式。
enum ThemeModePreference {
  system('跟随系统', ThemeMode.system),
  light('浅色', ThemeMode.light),
  dark('深色', ThemeMode.dark);

  const ThemeModePreference(this.label, this.themeMode);
  final String label;
  final ThemeMode themeMode;
}

/// 一级页面切换动画。系统开启“减少动画”时一律不播放。
///
/// 枚举名即保存值：`fadeSlide` 沿用上一版本的保存值（现名“左右滑动”），
/// 不改名以保留已有选择；无法识别的保存值回退为默认的非线性滑动。
enum PageAnimation {
  nonlinear('非线性滑动'),
  fadeSlide('左右滑动'),
  fade('淡入淡出'),
  none('关闭');

  const PageAnimation(this.label);
  final String label;
}

/// 预设主题色。
const List<({String name, Color color})> themePresets = [
  (name: '蓝色', color: Color(0xFF2563EB)),
  (name: '靛蓝', color: Color(0xFF4F46E5)),
  (name: '紫色', color: Color(0xFF7C3AED)),
  (name: '粉色', color: Color(0xFFDB2777)),
  (name: '橙色', color: Color(0xFFEA580C)),
  (name: '绿色', color: Color(0xFF16A34A)),
  (name: '青色', color: Color(0xFF0891B2)),
  (name: '灰蓝', color: Color(0xFF64748B)),
];

/// 主题色的显示名称：预设色显示名称，其余显示 #RRGGBB。
String themeColorLabel(Color color) {
  for (final p in themePresets) {
    if (p.color.toARGB32() == color.toARGB32()) return p.name;
  }
  return colorToHex(color);
}

/// #RRGGBB（不含透明度）。
String colorToHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// 解析 #RRGGBB 或 RRGGBB；格式不正确时返回 null。结果总是不透明。
Color? parseHexColor(String input) {
  final text = input.trim();
  final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(text);
  if (match == null) return null;
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

/// 界面与外观设置。只包含界面偏好，不包含任何计算输入。
@immutable
class AppSettings {
  const AppSettings({
    this.navLayout = NavLayoutPreference.auto,
    this.railExpanded = true,
    this.themeMode = ThemeModePreference.system,
    this.seedColor = const Color(0xFF2563EB),
    this.useDynamicColor = false,
    this.pageAnimation = PageAnimation.nonlinear,
  });

  static const defaults = AppSettings();

  final NavLayoutPreference navLayout;

  /// 宽窗口（≥ 840）下侧栏是否展开。
  final bool railExpanded;

  final ThemeModePreference themeMode;

  /// 用户手动选择的主题色（不透明）。启用系统动态取色时保留不变，关闭后恢复使用。
  final Color seedColor;

  /// 是否使用系统动态取色；平台不支持时忽略。
  final bool useDynamicColor;

  final PageAnimation pageAnimation;

  AppSettings copyWith({
    NavLayoutPreference? navLayout,
    bool? railExpanded,
    ThemeModePreference? themeMode,
    Color? seedColor,
    bool? useDynamicColor,
    PageAnimation? pageAnimation,
  }) => AppSettings(
    navLayout: navLayout ?? this.navLayout,
    railExpanded: railExpanded ?? this.railExpanded,
    themeMode: themeMode ?? this.themeMode,
    seedColor: seedColor ?? this.seedColor,
    useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    pageAnimation: pageAnimation ?? this.pageAnimation,
  );

  /// 只保留导航设置，外观恢复默认。
  AppSettings withDefaultAppearance() => copyWith(
    themeMode: defaults.themeMode,
    seedColor: defaults.seedColor,
    useDynamicColor: defaults.useDynamicColor,
    pageAnimation: defaults.pageAnimation,
  );

  /// 只保留外观设置，导航恢复默认。
  AppSettings withDefaultInterface() => copyWith(
    navLayout: defaults.navLayout,
    railExpanded: defaults.railExpanded,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.navLayout == navLayout &&
      other.railExpanded == railExpanded &&
      other.themeMode == themeMode &&
      other.seedColor.toARGB32() == seedColor.toARGB32() &&
      other.useDynamicColor == useDynamicColor &&
      other.pageAnimation == pageAnimation;

  @override
  int get hashCode => Object.hash(
    navLayout,
    railExpanded,
    themeMode,
    seedColor.toARGB32(),
    useDynamicColor,
    pageAnimation,
  );
}

/// 设置的读写。读取遇到缺失或无法识别的值时回退为默认值。
abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// 基于 shared_preferences（Android / Windows / Web 等平台的轻量键值存储）。
class SharedPreferencesSettingsStore implements SettingsStore {
  SharedPreferencesSettingsStore([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const navLayoutKey = 'ui.navLayout';
  static const railExpandedKey = 'ui.railExpanded';
  static const themeModeKey = 'ui.themeMode';
  static const seedColorKey = 'ui.seedColor';
  static const dynamicColorKey = 'ui.dynamicColor';
  static const pageAnimationKey = 'ui.pageAnimation';

  final SharedPreferencesAsync _prefs;

  static T _byName<T extends Enum>(List<T> values, String? name, T fallback) =>
      values.firstWhere((v) => v.name == name, orElse: () => fallback);

  @override
  Future<AppSettings> load() async {
    const d = AppSettings.defaults;
    final seed = await _prefs.getInt(seedColorKey);
    return AppSettings(
      navLayout: _byName(
        NavLayoutPreference.values,
        await _prefs.getString(navLayoutKey),
        d.navLayout,
      ),
      railExpanded: await _prefs.getBool(railExpandedKey) ?? d.railExpanded,
      themeMode: _byName(
        ThemeModePreference.values,
        await _prefs.getString(themeModeKey),
        d.themeMode,
      ),
      // 只保存 RGB，读取时强制不透明。
      seedColor: seed == null ? d.seedColor : Color(0xFF000000 | seed),
      useDynamicColor:
          await _prefs.getBool(dynamicColorKey) ?? d.useDynamicColor,
      pageAnimation: _byName(
        PageAnimation.values,
        await _prefs.getString(pageAnimationKey),
        d.pageAnimation,
      ),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setString(navLayoutKey, settings.navLayout.name);
    await _prefs.setBool(railExpandedKey, settings.railExpanded);
    await _prefs.setString(themeModeKey, settings.themeMode.name);
    await _prefs.setInt(seedColorKey, settings.seedColor.toARGB32() & 0xFFFFFF);
    await _prefs.setBool(dynamicColorKey, settings.useDynamicColor);
    await _prefs.setString(pageAnimationKey, settings.pageAnimation.name);
  }
}

/// 内存存储：测试使用，或在没有持久化时作为回退。
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this.value = AppSettings.defaults]);

  AppSettings value;

  /// 测试用：模拟读写失败。
  bool failLoad = false;
  bool failSave = false;

  @override
  Future<AppSettings> load() async {
    if (failLoad) throw StateError('load failed');
    return value;
  }

  @override
  Future<void> save(AppSettings settings) async {
    if (failSave) throw StateError('save failed');
    value = settings;
  }
}

/// 界面设置的状态。修改立即生效；保存失败时仍在本次运行中生效并给出提示。
class SettingsController extends ChangeNotifier {
  SettingsController(this._store);

  final SettingsStore _store;

  AppSettings _value = AppSettings.defaults;
  AppSettings get value => _value;

  /// 读取或保存失败时的提示；成功保存后清除。
  String? _error;
  String? get error => _error;

  // 串行写入，保证后一次修改不会被先发出的写入覆盖。
  Future<void> _pending = Future.value();

  static const loadTimeout = Duration(seconds: 3);

  /// 读取已保存的设置；失败或超时则使用默认值，不阻塞界面。
  Future<void> load() async {
    try {
      _value = await _store.load().timeout(loadTimeout);
      _error = null;
    } catch (_) {
      _value = AppSettings.defaults;
      _error = '读取已保存的设置失败，已使用默认设置。';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setNavLayout(NavLayoutPreference preference) =>
      _update(_value.copyWith(navLayout: preference));

  Future<void> setRailExpanded(bool expanded) =>
      _update(_value.copyWith(railExpanded: expanded));

  Future<void> setThemeMode(ThemeModePreference mode) =>
      _update(_value.copyWith(themeMode: mode));

  /// 选择手动主题色，同时关闭系统动态取色。
  Future<void> setSeedColor(Color color) => _update(
    _value.copyWith(
      seedColor: color.withValues(alpha: 1),
      useDynamicColor: false,
    ),
  );

  Future<void> setUseDynamicColor(bool enabled) =>
      _update(_value.copyWith(useDynamicColor: enabled));

  Future<void> setPageAnimation(PageAnimation animation) =>
      _update(_value.copyWith(pageAnimation: animation));

  /// 恢复界面设置：只恢复导航布局与侧栏展开状态，不触及外观与计算数据。
  Future<void> resetInterface() =>
      _update(_value.withDefaultInterface(), force: true);

  /// 恢复默认外观：只恢复主题模式、主题色、动态取色与页面动画。
  Future<void> resetAppearance() =>
      _update(_value.withDefaultAppearance(), force: true);

  Future<void> _update(AppSettings next, {bool force = false}) {
    if (next == _value && !force) return _pending;
    _value = next;
    notifyListeners();
    return _pending = _pending.then((_) async {
      String? error;
      try {
        await _store.save(next);
      } catch (_) {
        error = '设置未能保存，本次运行中仍然生效。';
      }
      if (_disposed || error == _error) return;
      _error = error;
      notifyListeners();
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
