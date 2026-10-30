import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../features/settings/app_settings.dart';
import 'page_transition.dart';
import 'shell_layout.dart';

/// 导航文字最多随系统放大到 1.3 倍，导航容器高度随之增长，避免文字溢出或截断。
const double _navMaxTextScale = 1.3;

/// 侧栏：紧凑时只显示图标（带 Tooltip），展开时显示图标 + 标题。
///
/// 与页面同色、无边框，背景延伸到状态栏与左侧显示缺口后方，按钮通过 SafeArea 避开。
class SideNav extends StatelessWidget {
  const SideNav({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.expanded,
    this.onToggleExpanded,
  });

  static const double compactWidth = 80;
  static const double expandedWidth = 232;

  final AppDestination selected;
  final ValueChanged<AppDestination> onSelected;
  final bool expanded;

  /// 为空时不显示展开 / 收起按钮（窗口不足以展开）。
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).left;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _navMaxTextScale,
      child: AnimatedContainer(
        key: const ValueKey('nav-rail'),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: (expanded ? expandedWidth : compactWidth) + inset,
        color: context.palette.page,
        child: SafeArea(
          right: false,
          child: FocusTraversalGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onToggleExpanded != null)
                  _RailHeader(expanded: expanded, onToggle: onToggleExpanded!)
                else
                  const SizedBox(height: AppSpacing.md),
                Expanded(
                  // 矮窗口时可滚动，设置项始终可达。
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final d in AppDestination.values)
                              _RailItem(
                                destination: d,
                                selected: d == selected,
                                onTap: () => onSelected(d),
                              ),
                          ],
                        ),
                        // 所有项共用一条指示条，切换时在新旧项之间伸缩移动。
                        _RailIndicator(
                          index: selected.index,
                          color: context.palette.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, AppSpacing.sm, 12, AppSpacing.sm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          key: const ValueKey('nav-rail-toggle'),
          tooltip: expanded ? '收起侧栏' : '展开侧栏',
          onPressed: onToggle,
          icon: Icon(expanded ? Icons.menu_open : Icons.menu),
        ),
      ),
    );
  }
}

/// 侧栏项的固定尺寸：指示条据此计算各项位置。
abstract final class _RailMetrics {
  static const double itemHeight = 52;
  static const double itemGap = 3;
  static const double horizontalPadding = 12;
  static const double indicatorHeight = 20;
  static const double indicatorWidth = 3;

  static const double extent = itemHeight + itemGap * 2;

  /// 第 [index] 项指示条的上下边缘（相对于项列表顶部）。
  static (double, double) indicatorSpan(int index) {
    final center = index * extent + itemGap + itemHeight / 2;
    return (center - indicatorHeight / 2, center + indicatorHeight / 2);
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  static const _fade = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = selected ? palette.primary : palette.textSecondary;
    final shape = smoothShape(AppRadius.item);
    final selectedColor = Color.alphaBlend(
      palette.primary.withValues(alpha: dark ? 0.20 : 0.10),
      palette.page,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _RailMetrics.horizontalPadding,
        vertical: _RailMetrics.itemGap,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final showLabel = c.maxWidth >= 120;
          final item = Semantics(
            button: true,
            selected: selected,
            label: destination.label,
            onTap: onTap,
            excludeSemantics: true,
            // 选中背景：旧项淡出、新项淡入。
            child: AnimatedContainer(
              duration: _fade,
              curve: Curves.easeOut,
              height: _RailMetrics.itemHeight,
              decoration: ShapeDecoration(
                color: selected ? selectedColor : selectedColor.withAlpha(0),
                shape: shape,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: ValueKey('nav-${destination.name}'),
                  onTap: onTap,
                  customBorder: shape,
                  child: Row(
                    children: [
                      SizedBox(
                        // 紧凑侧栏不足 56 时占满。
                        width: showLabel ? 56 : c.maxWidth,
                        child: AnimatedSwitcher(
                          duration: _fade,
                          child: Icon(
                            selected
                                ? destination.selectedIcon
                                : destination.icon,
                            key: ValueKey(selected),
                            color: color,
                            size: 24,
                          ),
                        ),
                      ),
                      if (showLabel)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.md,
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: _fade,
                              style: context.textStyles.labelLarge!.copyWith(
                                color: selected
                                    ? palette.primary
                                    : palette.textPrimary,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                              child: Text(
                                destination.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
          return showLabel
              ? item
              : Tooltip(message: destination.label, child: item);
        },
      ),
    );
  }
}

/// 侧栏选中指示条：切换时朝目标方向的一端先伸出、连接新旧两项，另一端随后收拢，
/// 最终停在新选中项上。动画进行中再次切换时从当前形状继续。
/// 页面动画关闭或系统减少动画时直接跳到目标位置。
class _RailIndicator extends StatefulWidget {
  const _RailIndicator({required this.index, required this.color});

  final int index;
  final Color color;

  @override
  State<_RailIndicator> createState() => _RailIndicatorState();
}

class _RailIndicatorState extends State<_RailIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PageMotion.railIndicatorDuration,
    value: 1,
  );

  late (double, double) _from = _RailMetrics.indicatorSpan(widget.index);
  late (double, double) _to = _from;

  // 移动方向的前端走前段区间、后端走后段区间，中间阶段指示条连接新旧两项。
  static const _lead = Interval(0, 0.62);
  static const _trail = Interval(0.32, 1);

  /// 当前帧的上下边缘。
  (double, double) get _span {
    final t = _controller.value;
    double lerp(double a, double b, Interval interval) =>
        a +
        (b - a) *
            PageMotion.railIndicatorCurve.transform(interval.transform(t));
    final down = _to.$1 > _from.$1;
    return (
      lerp(_from.$1, _to.$1, down ? _trail : _lead),
      lerp(_from.$2, _to.$2, down ? _lead : _trail),
    );
  }

  @override
  void didUpdateWidget(_RailIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final target = _RailMetrics.indicatorSpan(widget.index);
    if (PageAnimationScope.of(context) == PageAnimation.none) {
      _from = _to = target;
      _controller.value = 1;
      return;
    }
    _from = _span;
    _to = target;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 在构建期间订阅动画范围，便于切换到“关闭”时立即生效。
    PageAnimationScope.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final (top, bottom) = _span;
        return Positioned(
          left: _RailMetrics.horizontalPadding,
          top: top,
          width: _RailMetrics.indicatorWidth,
          height: bottom - top,
          child: IgnorePointer(
            child: DecoratedBox(
              key: const ValueKey('nav-rail-indicator'),
              decoration: ShapeDecoration(
                color: widget.color,
                shape: smoothShape(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 手机上的胶囊形悬浮底栏：应用内导航，不是系统悬浮窗。
///
/// 放在 Scaffold.bottomNavigationBar 并配合 extendBody：页面在其后方滚动，
/// Scaffold 把本组件的高度（含系统手势区）作为正文的底部 padding，只计算一次；
/// SnackBar 也会自动显示在底栏上方。底栏周围透明，露出的就是页面本身。
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.contentGutter,
  });

  static const double maxWidth = 480;

  /// 底栏与系统手势区（或屏幕底边）之间的间距。
  static const double gap = 10;

  /// 底栏两侧比内容容器额外内缩的距离。
  static const double inset = 10;

  final AppDestination selected;
  final ValueChanged<AppDestination> onSelected;

  /// 内容容器的左右边距；底栏在此基础上再内缩 [inset]。
  final double contentGutter;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final padding = MediaQuery.paddingOf(context);
    final side = contentGutter + inset;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _navMaxTextScale,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          side + padding.left,
          0,
          side + padding.right,
          padding.bottom + gap,
        ),
        // heightFactor 1：Scaffold 给底栏的高度约束是宽松的，不能撑满。
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Material(
              key: const ValueKey('nav-bottom-bar'),
              color: palette.navBar,
              // 两端完整半圆，圆角随实际高度变化。
              shape: const StadiumBorder(),
              elevation: 3,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const items = AppDestination.values;
                    final itemWidth = constraints.maxWidth / items.length;
                    return Stack(
                      children: [
                        // 选中滑块：切换时按非线性曲线滑到新的选中项。
                        AnimatedPositioned(
                          duration: AppMotion.expandDuration(context),
                          curve: AppMotion.expandCurve,
                          left: itemWidth * selected.index,
                          top: 0,
                          bottom: 0,
                          width: itemWidth,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              key: const ValueKey('nav-bottom-thumb'),
                              decoration: ShapeDecoration(
                                color: palette.navIndicator,
                                shape: const StadiumBorder(),
                              ),
                            ),
                          ),
                        ),
                        FocusTraversalGroup(
                          child: Row(
                            children: [
                              for (final d in items)
                                Expanded(
                                  child: _BarItem(
                                    destination: d,
                                    selected: d == selected,
                                    onTap: () => onSelected(d),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.primary : palette.textSecondary;
    final duration = AppMotion.expandDuration(context);
    const shape = StadiumBorder();
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      excludeSemantics: true,
      // 选中背景由底栏的滑块绘制，这里保持透明。
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('nav-${destination.name}'),
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: duration,
                    child: TweenAnimationBuilder<Color?>(
                      key: ValueKey(selected),
                      tween: ColorTween(end: color),
                      duration: duration,
                      builder: (context, c, _) => Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        color: c,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: AppMotion.expandCurve,
                    style: context.textStyles.labelSmall!.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
