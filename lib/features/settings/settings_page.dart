import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_theme.dart';
import '../../shell/shell_layout.dart';
import 'app_settings.dart';
import 'app_version.dart';
import 'settings_widgets.dart';
import 'theme_settings_page.dart';

const String appDisplayName = '边狱巴士伤害计算器';

/// 项目英文名与仓库。
const String appEnglishName = 'LimbusCalc';
const String authorName = 'YousaHay';
const String authorUrl = 'https://github.com/YousaHay';
const String repositoryUrl = 'https://github.com/YousaHay/LimbusCalc';

/// 设置页：分组列表。只包含真实生效的设置、关于信息与恢复操作。
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.layout,
    required this.versionLoader,
    this.systemColorAvailable = false,
  });

  final SettingsController settings;

  /// 当前窗口实际使用的导航形态，用于说明偏好是否被降级。
  final ShellNavLayout layout;
  final AppVersionLoader versionLoader;
  final bool systemColorAvailable;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Future<String?> _version = widget.versionLoader();

  SettingsController get _settings => widget.settings;

  void _openAppearance() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ThemeSettingsPage(
          settings: _settings,
          systemColorAvailable: widget.systemColorAvailable,
        ),
      ),
    );
  }

  Future<void> _pickNavLayout() async {
    final picked = await showDialog<NavLayoutPreference>(
      context: context,
      builder: (context) =>
          _NavLayoutDialog(current: _settings.value.navLayout),
    );
    if (picked != null) await _settings.setNavLayout(picked);
  }

  Future<void> _reset({
    required String title,
    required String message,
    required Key confirmKey,
    required Future<void> Function() action,
    required String done,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: title,
      message: message,
      confirmLabel: '恢复',
      confirmKey: confirmKey,
    );
    if (!confirmed) return;
    await action();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(done), duration: const Duration(seconds: 2)),
      );
  }

  /// 在系统浏览器中打开链接；无法打开时复制到剪贴板并提示。
  Future<void> _openLink(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened) return;
    await Clipboard.setData(ClipboardData(text: url));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('无法打开浏览器，已复制链接'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openLicenses() async {
    final version = await _version;
    if (!mounted) return;
    showLicensePage(
      context: context,
      applicationName: appDisplayName,
      applicationVersion: version,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => SettingsBody(children: _children()),
    );
  }

  List<Widget> _children() {
    final value = _settings.value;
    final layout = widget.layout;
    final dynamicActive = value.useDynamicColor && widget.systemColorAvailable;
    final currentNav = StringBuffer('当前窗口：${layout.nav.label}');
    if (layout.degraded) currentNav.write('（窗口过窄，已临时改用底部栏）');
    final colorLabel = dynamicActive
        ? '系统动态取色'
        : themeColorLabel(value.seedColor);

    return [
      if (_settings.error case final error?) ...[
        SettingsNotice(text: error),
        const SizedBox(height: AppSpacing.lg),
      ],
      const SettingsSectionLabel('外观', first: true),
      SettingsGroup(
        children: [
          SettingsTile(
            key: const ValueKey('settings-appearance'),
            icon: Icons.palette_outlined,
            title: '主题与动画',
            subtitle:
                '${value.themeMode.label} · $colorLabel · 页面动画${value.pageAnimation.label}',
            chevron: true,
            onTap: _openAppearance,
          ),
        ],
      ),
      const SettingsSectionLabel('界面'),
      SettingsGroup(
        children: [
          SettingsTile(
            key: const ValueKey('settings-nav-layout'),
            icon: Icons.view_sidebar_outlined,
            title: '导航布局',
            subtitle: currentNav.toString(),
            value: value.navLayout.label,
            chevron: true,
            onTap: _pickNavLayout,
          ),
          SettingsTile(
            icon: Icons.menu_open,
            title: '宽窗口展开侧栏',
            subtitle: '窗口宽度不小于 840 时显示图标与文字；也可点击侧栏顶部按钮切换',
            trailing: Switch(
              key: const ValueKey('settings-rail-expanded'),
              value: value.railExpanded,
              onChanged: _settings.setRailExpanded,
            ),
            onTap: () => _settings.setRailExpanded(!value.railExpanded),
          ),
        ],
      ),
      const SettingsSectionLabel('关于'),
      SettingsGroup(
        children: [
          FutureBuilder<String?>(
            future: _version,
            builder: (context, snapshot) => SettingsTile(
              icon: Icons.info_outline,
              title: '$appDisplayName（$appEnglishName）',
              subtitle: switch (snapshot.connectionState) {
                ConnectionState.done => '版本 ${snapshot.data ?? '未知'}',
                _ => '正在读取版本…',
              },
              subtitleKey: const ValueKey('settings-version'),
            ),
          ),
          const SettingsTile(
            icon: Icons.calculate_outlined,
            title: '基础计算',
            subtitle:
                '普通技能逐枚硬币的直接伤害：抗性、攻防等级、拼点、暴击、动态增减伤与 5% 保底；'
                '不含追伤、重投与状态伤害。',
          ),
          const SettingsTile(
            icon: Icons.insights_outlined,
            title: '高级计算',
            subtitle:
                '逐币修正、重投、比例 / 固定追伤、循环统计与参数扫描；'
                '拼点点数按全部正面估算，不是胜率。',
          ),
          const SettingsTile(
            icon: Icons.menu_book_outlined,
            title: '计算资料来源',
            subtitle:
                '基础计算的公式整理自 Syx 博客《Damage Formula》等社区资料；'
                '高级计算的计算模型移植自 MirrorCalcWeb（f0lkskill，MIT 许可证），'
                '加减算与逐枚正反面为本应用扩展。计算结果尚未与游戏实测逐项核对。',
          ),
          SettingsTile(
            key: const ValueKey('settings-author'),
            icon: Icons.person_outline,
            title: '作者',
            subtitle: 'github.com/$authorName',
            value: authorName,
            trailing: const _OpenIcon(),
            onTap: () => _openLink(authorUrl),
          ),
          SettingsTile(
            key: const ValueKey('settings-repository'),
            icon: Icons.code,
            title: '项目主页',
            subtitle: 'github.com/$authorName/$appEnglishName',
            value: 'GitHub',
            trailing: const _OpenIcon(),
            onTap: () => _openLink(repositoryUrl),
          ),
          SettingsTile(
            key: const ValueKey('settings-licenses'),
            icon: Icons.description_outlined,
            title: '开源许可',
            subtitle: '本项目以 GPL-3.0 发布；Noto Sans SC 字体、MirrorCalcWeb 与 Flutter 组件的许可证',
            chevron: true,
            onTap: _openLicenses,
          ),
        ],
      ),
      const SettingsSectionLabel('恢复'),
      SettingsGroup(
        children: [
          SettingsTile(
            key: const ValueKey('settings-reset'),
            icon: Icons.restart_alt,
            title: '恢复界面设置',
            subtitle: _resetInterfaceDescription,
            chevron: true,
            onTap: () => _reset(
              title: '恢复界面设置？',
              message: _resetInterfaceDescription,
              confirmKey: const ValueKey('settings-reset-confirm'),
              action: _settings.resetInterface,
              done: '已恢复界面设置',
            ),
          ),
          SettingsTile(
            key: const ValueKey('settings-reset-appearance'),
            icon: Icons.format_color_reset_outlined,
            title: '恢复默认外观',
            subtitle: _resetAppearanceDescription,
            chevron: true,
            onTap: () => _reset(
              title: '恢复默认外观？',
              message: _resetAppearanceDescription,
              confirmKey: const ValueKey('settings-reset-appearance-confirm'),
              action: _settings.resetAppearance,
              done: '已恢复默认外观',
            ),
          ),
        ],
      ),
    ];
  }
}

const String _resetInterfaceDescription =
    '导航布局恢复为“自动”，宽窗口侧栏恢复为展开。'
    '不影响外观设置，也不会清除计算输入、方案名称、循环记录与扫描结果。';

const String _resetAppearanceDescription =
    '主题模式恢复为“跟随系统”，主题色恢复为蓝色，关闭系统动态取色，页面动画恢复为“非线性滑动”。'
    '不影响导航设置，也不会清除计算输入、方案名称、循环记录与扫描结果。';

/// 外部链接图标。
class _OpenIcon extends StatelessWidget {
  const _OpenIcon();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.open_in_new, size: 18, color: context.palette.textSecondary);
}

class _NavLayoutDialog extends StatelessWidget {
  const _NavLayoutDialog({required this.current});

  final NavLayoutPreference current;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导航布局'),
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      content: SingleChildScrollView(
        child: RadioGroup<NavLayoutPreference>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(context, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in NavLayoutPreference.values)
                RadioListTile<NavLayoutPreference>(
                  key: ValueKey('nav-layout-${p.name}'),
                  value: p,
                  title: Text(p.label),
                  subtitle: Text(
                    p.description,
                    style: context.textStyles.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
