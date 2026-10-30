import 'package:flutter/material.dart';

import '../../app_theme.dart';

/// 设置类页面的正文：与标题左边缘对齐，限制最大宽度，底部为悬浮底栏 / 手势区留出空间。
class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key, required this.children});

  final List<Widget> children;

  static const double maxWidth = 760;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppSizes.compactWidth;
        final gutter = contentGutter(constraints.maxWidth);
        return SingleChildScrollView(
          // 不裁剪：向上滚出视口的内容继续绘制到外壳标题区后方，由其渐隐层遮住。
          clipBehavior: Clip.none,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.contentMaxWidth,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  compact ? AppSpacing.lg : AppSpacing.xl,
                  gutter,
                  AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 分组标题：左对齐，位于容器外。
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key, this.first = false});

  final String text;

  /// 第一个分组上方不再额外留白。
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        first ? 0 : AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: context.textStyles.labelLarge?.copyWith(
            color: context.palette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 同组设置共享的大圆角容器；项之间的分隔线从文字处开始。
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      clipBehavior: Clip.antiAlias,
      shape: smoothShape(AppRadius.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: SettingsTile.textIndent,
                endIndent: AppSpacing.lg,
                color: palette.border,
              ),
            child,
          ],
        ],
      ),
    );
  }
}

/// 设置项：左侧图标、中间名称（及说明）、右侧当前值或操作入口。
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleKey,
    this.value,
    this.leading,
    this.trailing,
    this.chevron = false,
    this.onTap,
  });

  static const double _hPadding = 20;
  static const double _iconSlot = 40;

  /// 文字起始位置（分隔线由此开始）。
  static const double textIndent = _hPadding + _iconSlot;

  final IconData icon;
  final String title;
  final String? subtitle;
  final Key? subtitleKey;
  final String? value;

  /// 替代 [icon] 的前置组件（如颜色样本）。
  final Widget? leading;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final styles = context.textStyles;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _hPadding,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: _iconSlot,
              child: Align(
                alignment: Alignment.centerLeft,
                child:
                    leading ??
                    Icon(icon, size: 22, color: palette.textSecondary),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: styles.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, key: subtitleKey, style: styles.bodySmall),
                  ],
                ],
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md),
                child: Text(
                  value!,
                  style: styles.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: trailing,
              ),
            if (chevron)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: palette.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// 设置读写失败等提示。
class SettingsNotice extends StatelessWidget {
  const SettingsNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      key: const ValueKey('settings-error'),
      decoration: ShapeDecoration(
        color: palette.warningSoft,
        shape: smoothShape(AppRadius.item),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: palette.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: palette.warning,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 确认对话框；返回是否确认。
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Key confirmKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: confirmKey,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
