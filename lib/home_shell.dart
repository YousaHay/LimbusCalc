import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'features/calculator/presentation/calculator_page.dart';
import 'features/mirror_calculator/presentation/mirror_page.dart';
import 'features/settings/app_settings.dart';
import 'features/settings/app_version.dart';
import 'features/settings/settings_page.dart';
import 'shell/navigation.dart';
import 'shell/page_transition.dart';
import 'shell/shell_layout.dart';
import 'shell/system_ui.dart';

/// 应用外壳：统一管理一级导航（基础计算 / 高级计算 / 设置）、
/// 宽窄布局切换（侧栏 / 悬浮底栏）、页面切换动画与系统栏适配。
///
/// 三个页面放在同一个 [AnimatedPageStack] 中常驻，并用 GlobalKey 固定其位置：
/// 切换目的地、宽窄断点变化、键盘出现、切换主题都不会重建页面，各自的输入、
/// 结果、滚动位置与高级计算的子页面都会保留。
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.settings,
    this.versionLoader = loadPlatformVersion,
    this.systemColorAvailable = false,
  });

  final SettingsController settings;
  final AppVersionLoader versionLoader;

  /// 当前平台能否提供系统动态取色。
  final bool systemColorAvailable;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppDestination _destination = AppDestination.basic;

  // 高级计算与设置在首次进入时才构建，之后常驻。
  final Set<AppDestination> _built = {AppDestination.basic};

  final _pagesKey = GlobalKey(debugLabel: 'shell-pages');

  void _select(AppDestination destination) {
    if (destination == _destination) return;
    setState(() {
      _destination = destination;
      _built.add(destination);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyleFor(Theme.of(context).brightness),
      child: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => LayoutBuilder(builder: _buildLayout),
      ),
    );
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final settings = widget.settings.value;
    // 断点基于整个外壳的宽度，侧栏展开与否不影响判断，不会来回切换。
    final layout = resolveShellNav(
      width: constraints.maxWidth,
      preference: settings.navLayout,
      railExpanded: settings.railExpanded,
    );
    final rail = layout.nav.isRail;
    // 键盘弹出时隐藏手机底栏，避免它被顶到键盘上方遮挡输入内容。
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // 系统开启“减少动画”时不播放页面切换动画。
    final animation = MediaQuery.disableAnimationsOf(context)
        ? PageAnimation.none
        : settings.pageAnimation;

    return PopScope(
      // 非起始目的地按返回键先回到基础计算；位于基础计算时交给系统（退出 / 返回桌面）。
      canPop: _destination == AppDestination.basic,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(AppDestination.basic);
      },
      child: PageAnimationScope(
        animation: animation,
        child: Scaffold(
          extendBody: true,
          bottomNavigationBar: !rail && !keyboardOpen
              ? FloatingNavBar(
                  selected: _destination,
                  onSelected: _select,
                  contentGutter: contentGutter(constraints.maxWidth),
                )
              : null,
          // 子组件数量与类型在两种布局下保持一致，正文子树不会被重新挂载。
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              rail
                  ? SideNav(
                      selected: _destination,
                      onSelected: _select,
                      expanded: layout.nav == ShellNav.expandedRail,
                      onToggleExpanded: layout.canExpand
                          ? () => widget.settings.setRailExpanded(
                              !settings.railExpanded,
                            )
                          : null,
                    )
                  : const SizedBox.shrink(),
              Expanded(
                // 必须读取 Scaffold 内部的 MediaQuery：其底部 padding 已包含悬浮底栏高度。
                // 侧栏已避让左侧显示缺口，正文不再重复避让。
                child: Builder(
                  builder: (context) => MediaQuery.removePadding(
                    context: context,
                    removeLeft: rail,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final header = ShellHeaderMetrics.of(
                          context,
                          constraints.maxWidth,
                        );
                        // 正文视口从标题不透明区下沿开始：“滚动到可见”（键盘焦点、输入法弹出）
                        // 不会把控件停在标题后方；视口不裁剪，向上滚出的正文继续绘制到
                        // 标题后方并被渐隐层遮住，且视口外的内容本就不响应点击。
                        return Stack(
                          children: [
                            Positioned(
                              top: header.solid,
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: MediaQuery.removePadding(
                                context: context,
                                removeTop: true,
                                child: SafeArea(
                                  top: false,
                                  bottom: false,
                                  child: KeyedSubtree(
                                    key: _pagesKey,
                                    child: _pages(layout, animation),
                                  ),
                                ),
                              ),
                            ),
                            // 宽屏：正文左缘渐隐。左右切页时正文在侧栏边界处融入页面背景，
                            // 而不是被硬切；宽度等于内容左边距，静止时只覆盖空白。
                            if (rail)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                left: 0,
                                width: header.gutter,
                                child: _EdgeFade(color: context.palette.page),
                              ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: _ShellHeader(
                                destination: _destination,
                                metrics: header,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pages(ShellNavLayout layout, PageAnimation animation) {
    Widget lazy(AppDestination d, Widget Function() build) =>
        _built.contains(d) ? build() : const SizedBox.shrink();
    return AnimatedPageStack(
      index: _destination.index,
      animation: animation,
      children: [
        const CalculatorPage(),
        lazy(AppDestination.mirror, () => const MirrorCalculatorPage()),
        lazy(
          AppDestination.settings,
          () => SettingsPage(
            settings: widget.settings,
            layout: layout,
            versionLoader: widget.versionLoader,
            systemColorAvailable: widget.systemColorAvailable,
          ),
        ),
      ],
    );
  }
}

/// 左缘渐隐：页面背景色 → 透明，不参与命中测试。
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        key: const ValueKey('shell-edge-fade'),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// 标题区尺寸：根据顶部安全区与实际标题行高计算，不写死像素。
@immutable
class ShellHeaderMetrics {
  const ShellHeaderMetrics({
    required this.solid,
    required this.fade,
    required this.compact,
    required this.gutter,
  });

  factory ShellHeaderMetrics.of(BuildContext context, double width) {
    final compact = width < AppSizes.compactWidth;
    final style = context.textStyles.headlineMedium!;
    final titleHeight =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    final top = MediaQuery.paddingOf(context).top;
    return ShellHeaderMetrics(
      solid:
          top +
          (compact ? AppSpacing.lg : AppSpacing.xl) +
          titleHeight +
          (compact ? AppSpacing.xs : AppSpacing.sm),
      // 与页面内容的顶部留白相同：初始位置的第一块内容恰好位于渐隐区下方，完整可见。
      fade: compact ? AppSpacing.lg : AppSpacing.xl,
      compact: compact,
      gutter: contentGutter(width),
    );
  }

  /// 不透明部分：状态栏 + 标题。完全遮挡其后方的正文，并拦截点击。
  final double solid;

  /// 渐隐部分：从页面背景过渡到透明，不拦截点击与滚动。
  final double fade;
  final bool compact;
  final double gutter;
}

/// 页面标题区：覆盖在正文之上。上部为不透明的页面背景色，向下渐隐为透明，
/// 正文向上滚动时从标题后方经过并逐渐融入背景；标题本身不随之变淡。
/// 没有独立的顶栏底色、分隔线或阴影；渐隐颜色跟随当前主题。
class _ShellHeader extends StatelessWidget {
  const _ShellHeader({required this.destination, required this.metrics});

  final AppDestination destination;
  final ShellHeaderMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final page = context.palette.page;
    final total = metrics.solid + metrics.fade;
    return SizedBox(
      key: const ValueKey('shell-header'),
      height: total,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 渐隐层不参与命中测试：渐隐区内仍部分可见的正文可以正常点击与滚动。
          IgnorePointer(
            child: DecoratedBox(
              key: const ValueKey('shell-header-fade'),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [page, page, page.withValues(alpha: 0)],
                  stops: [0, metrics.solid / total, 1],
                ),
              ),
            ),
          ),
          // 不透明部分拦截点击，避免误触被完全遮挡的控件。
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: metrics.solid,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              child: SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.contentMaxWidth,
                    ),
                    // 与页面内容使用相同的最大宽度与边距，标题左边缘与内容容器对齐。
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        metrics.gutter,
                        metrics.compact ? AppSpacing.lg : AppSpacing.xl,
                        metrics.gutter,
                        0,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Semantics(
                          header: true,
                          child: Text(
                            destination.label,
                            key: const ValueKey('page-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.headlineMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
