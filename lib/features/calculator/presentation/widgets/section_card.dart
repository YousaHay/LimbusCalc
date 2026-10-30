import 'package:flutter/material.dart';

import '../../../../app_theme.dart';

/// 内容容器外壳：容器色与页面背景形成层次，不加描边；可选极轻阴影。
/// 使用 [Material] 以承载内部水波纹。
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.elevated = false});

  final Widget child;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final card = Material(
      color: palette.surface,
      clipBehavior: Clip.antiAlias,
      shape: smoothShape(AppRadius.card),
      child: child,
    );
    if (!elevated) return card;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: smoothShape(AppRadius.card),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: card,
    );
  }
}

/// 标准分组卡片：标题 + 可选右侧操作 + 内容。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.bodyPadding,
    this.elevated = false,
  });

  final String? title;
  final Widget? trailing;
  final Widget child;

  /// 默认使用卡片内边距；表格等需要贴边的内容可以传入自定义值。
  final EdgeInsetsGeometry? bodyPadding;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final pad = context.cardPadding;
    return _CardShell(
      elevated: elevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad - 4, pad - 8, 0),
              child: SizedBox(
                height: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        style: context.textStyles.titleMedium,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
          Padding(
            padding:
                bodyPadding ??
                EdgeInsets.fromLTRB(
                  pad,
                  title == null ? pad : AppSpacing.md,
                  pad,
                  pad,
                ),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// 可折叠卡片。展开状态由外部持有，因此输入引起的重建与布局切换都不会使其收起。
class CollapsibleCard extends StatelessWidget {
  const CollapsibleCard({
    super.key,
    required this.title,
    required this.expanded,
    required this.onExpandedChanged,
    required this.child,
    this.summary,
    this.summaryIsError = false,
  });

  final String title;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final Widget child;

  /// 标题下方的一行摘要。
  final String? summary;
  final bool summaryIsError;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pad = context.cardPadding;
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              onTap: () => onExpandedChanged(!expanded),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: pad,
                  vertical: AppSpacing.lg,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.textStyles.titleMedium),
                          if (summary != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              summary!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: numeric(context.textStyles.bodySmall)
                                  .copyWith(
                                    color: summaryIsError
                                        ? palette.error
                                        : palette.textSecondary,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: AppMotion.expandDuration(context),
                      curve: AppMotion.expandCurve,
                      child: Icon(
                        Icons.expand_more,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.expandDuration(context),
            curve: AppMotion.expandCurve,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: EdgeInsets.fromLTRB(pad, AppSpacing.xs, pad, pad),
                    child: child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
