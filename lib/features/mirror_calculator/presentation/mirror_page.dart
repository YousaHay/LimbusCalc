import 'package:flutter/material.dart';

import '../../../app_theme.dart';
import '../../../shell/page_transition.dart';
import 'mirror_controller.dart';
import 'sweep_controller.dart';
import 'widgets/mirror_coin_editor.dart';
import 'widgets/mirror_help_panel.dart';
import 'widgets/mirror_loop_view.dart';
import 'widgets/mirror_params_card.dart';
import 'widgets/mirror_process_panel.dart';
import 'widgets/mirror_result_card.dart';
import 'widgets/mirror_tab_bar.dart';
import 'widgets/mirror_sweep_view.dart';

enum MirrorTab {
  single('单技能计算', Icons.bolt_outlined),
  loops('循环统计', Icons.repeat),
  sweep('参数扫描', Icons.show_chart);

  const MirrorTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// 高级计算模式：计算模型移植自 MirrorCalcWeb，并扩展了加减算与逐枚正反面。
class MirrorCalculatorPage extends StatefulWidget {
  const MirrorCalculatorPage({super.key});

  @override
  State<MirrorCalculatorPage> createState() => _MirrorCalculatorPageState();
}

class _MirrorCalculatorPageState extends State<MirrorCalculatorPage> {
  final _controller = MirrorController();
  final _sweep = SweepController();
  final _selectionFocusNode = FocusNode(skipTraversal: true);
  late final Listenable _listenable = Listenable.merge([_controller, _sweep]);

  MirrorTab _tab = MirrorTab.single;
  bool _processExpanded = false;
  bool _helpExpanded = false;
  bool _rerollExpanded = false;
  bool _advancedExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    _sweep.dispose();
    _selectionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _listenable,
      builder: (context, _) => LayoutBuilder(builder: _buildLayout),
    );
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final compact = constraints.maxWidth < AppSizes.compactWidth;
    final gutter = compact ? AppSpacing.lg : AppSpacing.xxl;
    final contentWidth =
        (constraints.maxWidth < AppSizes.contentMaxWidth
            ? constraints.maxWidth
            : AppSizes.contentMaxWidth) -
        gutter * 2;

    final body = switch (_tab) {
      MirrorTab.single => _single(contentWidth),
      MirrorTab.loops => MirrorLoopView(
        controller: _controller,
        wide: contentWidth >= 1150,
      ),
      MirrorTab.sweep => MirrorSweepView(
        controller: _controller,
        sweep: _sweep,
      ),
    };

    return SingleChildScrollView(
      // 不裁剪：向上滚出视口的内容继续绘制到外壳标题区后方，由其渐隐层遮住。
      clipBehavior: Clip.none,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              compact ? AppSpacing.lg : AppSpacing.xl,
              gutter,
              // 外壳的悬浮底栏 / 系统手势区高度（由 Scaffold 计入 padding）。
              AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: compact ? double.infinity : 480,
                    child: MirrorTabBar<MirrorTab>(
                      key: const ValueKey('mirror-tabs'),
                      options: [
                        for (final t in MirrorTab.values)
                          (value: t, label: t.label, icon: t.icon),
                      ],
                      selected: _tab,
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                // 子页面切换：与一级页面的动画设置一致（默认非线性左右滑动）。
                SlideSwitcher(
                  index: _tab.index,
                  extent: constraints.maxWidth,
                  child: body,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _single(double contentWidth) {
    // 首屏只放常用参数；重投与其余高级参数分组折叠。
    final params = FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MirrorParamsCard(controller: _controller),
          const SizedBox(height: AppSpacing.section),
          MirrorRerollCard(
            controller: _controller,
            expanded: _rerollExpanded,
            onExpandedChanged: (v) => setState(() => _rerollExpanded = v),
          ),
          const SizedBox(height: AppSpacing.section),
          MirrorAdvancedCard(
            controller: _controller,
            expanded: _advancedExpanded,
            onExpandedChanged: (v) => setState(() => _advancedExpanded = v),
          ),
        ],
      ),
    );
    final result = FocusTraversalGroup(
      child: SelectionArea(
        focusNode: _selectionFocusNode,
        child: MirrorResultCard(controller: _controller),
      ),
    );
    final top = contentWidth >= AppSizes.twoColumnWidth
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: params),
              const SizedBox(width: AppSpacing.xl),
              SizedBox(width: 360, child: result),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              params,
              const SizedBox(height: AppSpacing.section),
              result,
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        const SizedBox(height: AppSpacing.section),
        FocusTraversalGroup(child: MirrorCoinEditor(controller: _controller)),
        const SizedBox(height: AppSpacing.section),
        MirrorProcessPanel(
          state: _controller.state,
          result: _controller.result,
          expanded: _processExpanded,
          onExpandedChanged: (v) => setState(() => _processExpanded = v),
        ),
        const SizedBox(height: AppSpacing.section),
        MirrorHelpPanel(
          expanded: _helpExpanded,
          onExpandedChanged: (v) => setState(() => _helpExpanded = v),
        ),
      ],
    );
  }
}
