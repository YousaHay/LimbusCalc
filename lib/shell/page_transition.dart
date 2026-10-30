import 'package:flutter/widgets.dart';

import '../features/settings/app_settings.dart';

/// 页面切换的时长与曲线集中在这里，便于统一微调。
abstract final class PageMotion {
  /// 左右滑动 / 淡入淡出：新页面淡入（左右滑动时小幅移入）。
  static const Duration entranceDuration = Duration(milliseconds: 220);
  static const Curve entranceCurve = Curves.easeOutCubic;

  /// 左右滑动的移入距离（逻辑像素）。
  static const double entranceDistance = 24;

  /// 非线性滑动：新旧页面整页并排水平移动，起步平滑、中段较快、末段减速停稳。
  /// easeInOutCubic 是单调的标准缓入缓出曲线，无回弹、无越界。
  static const Duration nonlinearDuration = Duration(milliseconds: 320);
  static const Curve nonlinearCurve = Curves.easeInOutCubic;

  /// 页面内子页面（如高级计算的标签页）的进入动画。
  static const Duration innerDuration = Duration(milliseconds: 200);
  static const double innerDistance = 12;

  /// 侧栏选中指示条在新旧项之间的伸缩移动。
  static const Duration railIndicatorDuration = Duration(milliseconds: 380);
  static const Curve railIndicatorCurve = Curves.easeInOutCubic;

  static Duration durationFor(PageAnimation mode) =>
      mode == PageAnimation.nonlinear ? nonlinearDuration : entranceDuration;
}

/// 向页面内部（如高级计算的子页面）提供实际生效的切换动画；
/// 已考虑系统“减少动画”设置。
class PageAnimationScope extends InheritedWidget {
  const PageAnimationScope({
    super.key,
    required this.animation,
    required super.child,
  });

  final PageAnimation animation;

  static PageAnimation of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PageAnimationScope>()
          ?.animation ??
      PageAnimation.none;

  @override
  bool updateShouldNotify(PageAnimationScope oldWidget) =>
      oldWidget.animation != animation;
}

/// 非线性滑动中某个页面的水平位置（以页面宽度为单位）：从 [from] 移动到 [to]。
class _Motion {
  const _Motion(this.index, this.from, this.to);

  final int index;
  final double from;
  final double to;

  double at(double t) => from + (to - from) * t;
}

/// 一组常驻页面：只有 [index] 对应的页面可交互，切换时播放所选转场。
///
/// - 所有页面始终保持挂载，每个页面外层的组件结构固定，状态、控制器与滚动位置都保留。
/// - 非线性滑动时旧页面与新页面并排移动；其余模式下旧页面立即隐藏、新页面进入。
/// - 离开中的页面不响应点击、不参与焦点。
/// - 快速连续切换时从各页面的当前位置继续移向最新目标，不排队、不跳回；
///   跨越多个导航项时直接切到目标页面。
class AnimatedPageStack extends StatefulWidget {
  const AnimatedPageStack({
    super.key,
    required this.index,
    required this.animation,
    required this.children,
  });

  final int index;
  final PageAnimation animation;
  final List<Widget> children;

  @override
  State<AnimatedPageStack> createState() => _AnimatedPageStackState();
}

class _AnimatedPageStackState extends State<AnimatedPageStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PageMotion.durationFor(widget.animation),
    value: 1,
  )..addStatusListener(_onStatus);

  /// 左右滑动 / 淡入淡出的方向：1 为新页面从右侧进入（目的地在导航中靠后）。
  double _direction = 1;

  /// 非线性滑动中正在进入 / 离开的页面；动画结束后清空。
  _Motion? _incoming;
  _Motion? _outgoing;

  double get _t => PageMotion.nonlinearCurve.transform(_controller.value);

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing != null) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didUpdateWidget(AnimatedPageStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final next = widget.index;
    _direction = next > oldWidget.index ? 1 : -1;

    switch (widget.animation) {
      case PageAnimation.none:
        _incoming = _outgoing = null;
        _controller.value = 1;
        return;
      case PageAnimation.fadeSlide || PageAnimation.fade:
        _incoming = _outgoing = null;
        _controller.duration = PageMotion.entranceDuration;
      case PageAnimation.nonlinear:
        _retargetSlide(oldWidget.index, next);
        _controller.duration = PageMotion.nonlinearDuration;
    }
    _controller.forward(from: 0);
  }

  /// 计算非线性滑动的起止位置。动画进行中切换时，各页面从当前位置继续移动。
  void _retargetSlide(int previous, int next) {
    // 当前可见的页面及其位置。
    final visible = <int, double>{};
    if (_controller.isAnimating && _incoming != null) {
      visible[_incoming!.index] = _incoming!.at(_t);
      if (_outgoing case final out?) visible[out.index] = out.at(_t);
    } else {
      visible[previous] = 0;
    }
    // 离开的页面：除目标外最靠近屏幕中央的那个；其余可见页面直接隐藏。
    int? leaving;
    for (final MapEntry(key: i, value: x) in visible.entries) {
      if (i == next) continue;
      if (leaving == null || x.abs() < visible[leaving]!.abs()) leaving = i;
    }
    final direction = leaving == null || next > leaving ? 1.0 : -1.0;
    _incoming = _Motion(next, visible[next] ?? direction, 0);
    _outgoing = leaving == null
        ? null
        : _Motion(leaving, visible[leaving]!, -direction);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 只裁剪左右：滑动中的页面不会画到侧栏上；上方保持不裁剪，
    // 让正文能从外壳标题区后方滚过。
    return ClipRect(
      clipper: const _HorizontalClipper(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (final (i, child) in widget.children.indexed)
            _PageSlot(
              active: i == widget.index,
              visible: i == widget.index || i == _outgoing?.index,
              child: _SlotTransition(
                animation: _controller,
                motion: switch (i) {
                  _ when _incoming?.index == i => _incoming,
                  _ when _outgoing?.index == i => _outgoing,
                  _ => null,
                },
                entering: i == widget.index && _incoming == null,
                mode: widget.animation,
                direction: _direction,
                child: child,
              ),
            ),
        ],
      ),
    );
  }
}

class _HorizontalClipper extends CustomClipper<Rect> {
  const _HorizontalClipper();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -size.height, size.width, size.height * 2);

  @override
  bool shouldReclip(_HorizontalClipper oldClipper) => false;
}

/// 非可见页面不绘制；非当前页面不响应点击、不参与焦点、暂停其动画。
class _PageSlot extends StatelessWidget {
  const _PageSlot({
    required this.active,
    required this.visible,
    required this.child,
  });

  final bool active;
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !visible,
      child: TickerMode(
        enabled: active,
        child: ExcludeFocus(
          excluding: !active,
          child: IgnorePointer(ignoring: !active, child: child),
        ),
      ),
    );
  }
}

/// 单个页面的转场。组件结构固定（Opacity → Transform → FractionalTranslation），
/// 无论处于哪种模式或状态，子树都不会重新挂载。
class _SlotTransition extends AnimatedWidget {
  const _SlotTransition({
    required Animation<double> animation,
    required this.motion,
    required this.entering,
    required this.mode,
    required this.direction,
    required this.child,
  }) : super(listenable: animation);

  /// 非线性滑动中的位置；为空表示不参与滑动。
  final _Motion? motion;

  /// 左右滑动 / 淡入淡出中正在进入的页面。
  final bool entering;
  final PageAnimation mode;
  final double direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final value = (listenable as Animation<double>).value;
    var opacity = 1.0;
    var dx = 0.0;
    var fraction = 0.0;
    if (motion case final m?) {
      fraction = m.at(PageMotion.nonlinearCurve.transform(value));
    } else if (entering && mode != PageAnimation.none) {
      final t = PageMotion.entranceCurve.transform(value);
      opacity = t;
      if (mode == PageAnimation.fadeSlide) {
        dx = (1 - t) * PageMotion.entranceDistance * direction;
      }
    }
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: FractionalTranslation(
          translation: Offset(fraction, 0),
          child: child,
        ),
      ),
    );
  }
}

/// 页面内部子页面（如高级计算的标签页）的切换容器：[child] 对应 [index]。
///
/// - 非线性滑动：新旧内容并排水平移动（与一级页面同一曲线），离开的内容在动画结束后移除；
///   动画中再次切换时从当前位置继续，不排队、不跳回。
/// - 左右滑动 / 淡入淡出：新内容淡入（左右滑动时小幅移入），旧内容立即移除。
/// - 关闭或系统减少动画：直接切换。
///
/// 每份内容以其 index 为 key，切换时离开的内容保留原有元素与状态直到动画结束；
/// 离开中的内容不响应点击、不参与焦点。高度以较高者为准，动画结束后恢复为新内容高度。
class SlideSwitcher extends StatefulWidget {
  const SlideSwitcher({
    super.key,
    required this.index,
    required this.extent,
    required this.child,
  });

  final int index;

  /// 非线性滑动的移动距离（逻辑像素），应为整个页面的宽度：
  /// 内容按整页平移，离开的内容完全移出页面，新旧内容之间隔着两侧边距，
  /// 不会停留在边距里或在页面边缘被截成半张卡片。
  final double extent;
  final Widget child;

  @override
  State<SlideSwitcher> createState() => _SlideSwitcherState();
}

class _SlideSwitcherState extends State<SlideSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  )..addStatusListener(_onStatus);

  PageAnimation _mode = PageAnimation.none;
  double _direction = 1;

  /// 非线性滑动中正在进入的内容位置；为空表示不参与滑动。
  _Motion? _incoming;

  /// 非线性滑动中正在离开的内容及其位置。
  ({_Motion motion, Widget child})? _outgoing;

  double get _t => PageMotion.nonlinearCurve.transform(_controller.value);

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _outgoing != null) {
      setState(() => _outgoing = null);
    }
  }

  @override
  void didUpdateWidget(SlideSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final next = widget.index;
    _mode = PageAnimationScope.of(context);
    _direction = next > oldWidget.index ? 1 : -1;

    switch (_mode) {
      case PageAnimation.none:
        _incoming = null;
        _outgoing = null;
        _controller.value = 1;
        return;
      case PageAnimation.fadeSlide || PageAnimation.fade:
        _incoming = null;
        _outgoing = null;
        _controller.duration = PageMotion.innerDuration;
      case PageAnimation.nonlinear:
        _retarget(oldWidget, next);
        _controller.duration = PageMotion.nonlinearDuration;
    }
    _controller.forward(from: 0);
  }

  /// 计算非线性滑动的起止位置：离开的是除目标外最靠近原位的内容。
  void _retarget(SlideSwitcher oldWidget, int next) {
    final animating = _controller.isAnimating;
    final visible = <({int index, double pos, Widget child})>[
      (
        index: oldWidget.index,
        pos: animating && _incoming != null ? _incoming!.at(_t) : 0,
        child: oldWidget.child,
      ),
      if (animating && _outgoing != null)
        (
          index: _outgoing!.motion.index,
          pos: _outgoing!.motion.at(_t),
          child: _outgoing!.child,
        ),
    ];
    final current = visible.where((v) => v.index == next).firstOrNull;
    final others = visible.where((v) => v.index != next).toList()
      ..sort((a, b) => a.pos.abs().compareTo(b.pos.abs()));
    final leaving = others.firstOrNull;
    final direction = leaving == null || next > leaving.index ? 1.0 : -1.0;
    _incoming = _Motion(next, current?.pos ?? direction, 0);
    _outgoing = leaving == null
        ? null
        : (
            motion: _Motion(leaving.index, leaving.pos, -direction),
            child: leaving.child,
          );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outgoing = _outgoing;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (outgoing != null)
          _SwitchSlot(
            key: ValueKey(outgoing.motion.index),
            animation: _controller,
            active: false,
            motion: outgoing.motion,
            extent: widget.extent,
            mode: _mode,
            direction: _direction,
            child: outgoing.child,
          ),
        _SwitchSlot(
          key: ValueKey(widget.index),
          animation: _controller,
          active: true,
          motion: _incoming,
          extent: widget.extent,
          mode: _mode,
          direction: _direction,
          child: widget.child,
        ),
      ],
    );
  }
}

/// [SlideSwitcher] 中的一份内容。组件结构固定，从“进入”变为“离开”时元素与状态保留。
class _SwitchSlot extends AnimatedWidget {
  const _SwitchSlot({
    super.key,
    required Animation<double> animation,
    required this.active,
    required this.motion,
    required this.extent,
    required this.mode,
    required this.direction,
    required this.child,
  }) : super(listenable: animation);

  final bool active;
  final _Motion? motion;

  /// [motion] 的单位长度（逻辑像素）。
  final double extent;
  final PageAnimation mode;
  final double direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final value = (listenable as Animation<double>).value;
    var opacity = 1.0;
    var dx = 0.0;
    if (motion case final m?) {
      dx = m.at(PageMotion.nonlinearCurve.transform(value)) * extent;
    } else if (active &&
        (mode == PageAnimation.fade || mode == PageAnimation.fadeSlide)) {
      final t = PageMotion.entranceCurve.transform(value);
      opacity = t;
      if (mode == PageAnimation.fadeSlide) {
        dx = (1 - t) * PageMotion.innerDistance * direction;
      }
    }
    return IgnorePointer(
      ignoring: !active,
      child: ExcludeFocus(
        excluding: !active,
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(offset: Offset(dx, 0), child: child),
        ),
      ),
    );
  }
}
