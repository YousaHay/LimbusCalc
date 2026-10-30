import 'package:flutter/material.dart';

import '../../../../app_theme.dart';

/// 高级计算的子页面切换：胶囊形容器 + 随选中项滑动的胶囊滑块。
///
/// 与悬浮底栏同一套造型：容器使用内容容器色、无描边与分隔线；滑块使用浅色主题色，
/// 切换时按非线性曲线滑到新位置（系统开启“减少动画”时直接切换）。
/// 宽度足够时每项带图标，较窄时只显示文字。
class MirrorTabBar<T> extends StatelessWidget {
  const MirrorTabBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<({T value, String label, IconData icon})> options;
  final T selected;
  final ValueChanged<T> onChanged;

  static const double _inset = 4;

  /// 每项宽度达到此值时显示图标。
  static const double _iconMinItemWidth = 124;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = AppMotion.expandDuration(context);
    final index = options.indexWhere((o) => o.value == selected);
    // 高度随系统文字放大增长，与其他单行控件一致并略高。
    final height = context.controlHeight + _inset * 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - _inset * 2) / options.length;
        final showIcons = itemWidth >= _iconMinItemWidth;
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: palette.surface,
            shape: const StadiumBorder(),
          ),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: duration,
                  curve: AppMotion.expandCurve,
                  left: _inset + itemWidth * index,
                  top: _inset,
                  bottom: _inset,
                  width: itemWidth,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const ValueKey('mirror-tabs-thumb'),
                      decoration: ShapeDecoration(
                        color: palette.navIndicator,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(_inset),
                  child: Row(
                    children: [
                      for (final o in options)
                        Expanded(
                          child: _TabItem(
                            label: o.label,
                            icon: showIcons ? o.icon : null,
                            selected: o.value == selected,
                            duration: duration,
                            onTap: () => onChanged(o.value),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.primary : palette.textSecondary;
    const shape = StadiumBorder();
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('segment-$label'),
          onTap: onTap,
          customBorder: shape,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: color),
                      duration: duration,
                      builder: (context, c, _) =>
                          Icon(icon, size: 18, color: c),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: AppMotion.expandCurve,
                      style: context.textStyles.labelLarge!.copyWith(
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
