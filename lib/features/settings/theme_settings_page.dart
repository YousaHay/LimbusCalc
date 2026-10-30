import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../calculator/presentation/widgets/number_field.dart';
import 'app_settings.dart';
import 'color_picker_dialog.dart';
import 'settings_widgets.dart';

/// 二级页面：主题模式、主题颜色、页面动画与预览。修改即时生效并保存。
class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({
    super.key,
    required this.settings,
    required this.systemColorAvailable,
  });

  final SettingsController settings;
  final bool systemColorAvailable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('主题与动画')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => SafeArea(
          top: false,
          bottom: false,
          child: SettingsBody(children: _children(context)),
        ),
      ),
    );
  }

  List<Widget> _children(BuildContext context) {
    final value = settings.value;
    final dynamicActive = value.useDynamicColor && systemColorAvailable;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return [
      if (settings.error case final error?) ...[
        SettingsNotice(text: error),
        const SizedBox(height: AppSpacing.lg),
      ],
      const SettingsSectionLabel('主题模式', first: true),
      SettingsGroup(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SegmentedChoice<ThemeModePreference>(
              key: const ValueKey('theme-mode-switch'),
              options: [
                for (final m in ThemeModePreference.values) (m, m.label),
              ],
              selected: value.themeMode,
              onChanged: settings.setThemeMode,
            ),
          ),
        ],
      ),
      const SettingsSectionLabel('主题颜色'),
      SettingsGroup(
        children: [
          if (systemColorAvailable)
            SettingsTile(
              icon: Icons.wallpaper_outlined,
              title: '系统动态取色',
              subtitle: '使用系统壁纸或强调色生成配色；关闭后恢复手动选择的颜色',
              trailing: Switch(
                key: const ValueKey('theme-dynamic'),
                value: value.useDynamicColor,
                onChanged: settings.setUseDynamicColor,
              ),
              onTap: () => settings.setUseDynamicColor(!value.useDynamicColor),
            )
          else
            const SettingsTile(
              key: ValueKey('theme-dynamic-unavailable'),
              icon: Icons.wallpaper_outlined,
              title: '系统动态取色',
              subtitle: '当前平台不支持。需要 Android 12 及以上，或提供系统强调色的桌面系统。',
              value: '不可用',
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (i, preset) in themePresets.indexed)
                  _Swatch(
                    key: ValueKey('theme-preset-$i'),
                    color: preset.color,
                    label: preset.name,
                    selected:
                        !dynamicActive &&
                        preset.color.toARGB32() == value.seedColor.toARGB32(),
                    onTap: () => settings.setSeedColor(preset.color),
                  ),
              ],
            ),
          ),
          SettingsTile(
            key: const ValueKey('theme-custom'),
            icon: Icons.colorize_outlined,
            leading: _ColorDot(color: value.seedColor),
            title: '自定义颜色',
            subtitle: dynamicActive ? '正在使用系统动态取色，选择颜色后改用手动颜色' : null,
            value: colorToHex(value.seedColor),
            chevron: true,
            onTap: () async {
              final picked = await showColorPickerDialog(
                context,
                value.seedColor,
              );
              if (picked != null) await settings.setSeedColor(picked);
            },
          ),
        ],
      ),
      const SettingsSectionLabel('页面动画'),
      SettingsGroup(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedChoice<PageAnimation>(
                  key: const ValueKey('page-animation-switch'),
                  options: [for (final a in PageAnimation.values) (a, a.label)],
                  selected: value.pageAnimation,
                  onChanged: settings.setPageAnimation,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  reduceMotion
                      ? '系统已开启“减少动画”，页面切换不会播放动画。'
                      : '用于基础计算、高级计算、设置之间以及高级计算子页面的切换。',
                  style: context.textStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
      const SettingsSectionLabel('预览'),
      const ThemePreview(),
    ];
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.palette.border),
      ),
    );
  }
}

/// 预设颜色样本：48×48 触控区域，选中时显示对勾。
class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? context.palette.textPrimary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, size: 20, color: onColor)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 外观预览：页面背景、内容容器、主次文字、按钮、选中状态与关键结果。
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final styles = context.textStyles;
    return Container(
      key: const ValueKey('theme-preview'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: ShapeDecoration(
        color: palette.page,
        shape: smoothShape(
          AppRadius.card,
          side: BorderSide(color: palette.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('页面标题', style: styles.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: ShapeDecoration(
              color: palette.surface,
              shape: smoothShape(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('内容容器', style: styles.titleMedium),
                const SizedBox(height: 2),
                Text('次要说明文字', style: styles.bodySmall),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '128',
                      style: numeric(
                        styles.displaySmall?.copyWith(
                          fontSize: 32,
                          color: palette.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('关键结果', style: styles.bodySmall),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(onPressed: () {}, child: const Text('主要按钮')),
                    OutlinedButton(onPressed: () {}, child: const Text('次要按钮')),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      decoration: ShapeDecoration(
                        color: palette.primarySoft,
                        shape: smoothShape(
                          AppRadius.control,
                          side: BorderSide(color: palette.primaryBorder),
                        ),
                      ),
                      child: Text(
                        '选中项',
                        style: styles.labelLarge?.copyWith(
                          color: palette.primary,
                        ),
                      ),
                    ),
                    Switch(value: true, onChanged: (_) {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
