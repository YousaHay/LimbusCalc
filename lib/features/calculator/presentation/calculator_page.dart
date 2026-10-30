import 'package:flutter/material.dart';

import '../../../app_theme.dart';
import 'calculator_controller.dart';
import 'widgets/calculation_process_panel.dart';
import 'widgets/coin_breakdown.dart';
import 'widgets/damage_modifiers_card.dart';
import 'widgets/damage_result_card.dart';
import 'widgets/skill_input_card.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final _controller = CalculatorController();

  // 结果区文本选择的焦点：点击可聚焦以支持复制快捷键，但不作为 Tab 停靠点。
  final _selectionFocusNode = FocusNode(skipTraversal: true);

  // 折叠状态由页面持有：输入重算与宽窄布局切换都不会使其收起。
  bool _modifiersExpanded = false;
  bool _processExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    _selectionFocusNode.dispose();
    super.dispose();
  }

  /// 页面内容；Scaffold、标题与导航由 HomeShell 提供。
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
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
    final twoColumns = contentWidth >= AppSizes.twoColumnWidth;

    final inputs = [
      SkillInputCard(controller: _controller),
      DamageModifiersCard(
        controller: _controller,
        expanded: _modifiersExpanded,
        onExpandedChanged: (v) => setState(() => _modifiersExpanded = v),
      ),
    ];
    // 参数区与结果区各自成为焦点组：组内按阅读顺序，组间先参数后结果。
    final inputGroup = FocusTraversalGroup(child: _stack(inputs));
    // 结果区允许选择与复制文本。
    final outputs = FocusTraversalGroup(
      child: SelectionArea(
        focusNode: _selectionFocusNode,
        child: _stack([
          DamageResultCard(controller: _controller),
          CoinBreakdown(result: _controller.result),
          CalculationProcessPanel(
            result: _controller.result,
            expanded: _processExpanded,
            onExpandedChanged: (v) => setState(() => _processExpanded = v),
          ),
        ]),
      ),
    );

    final body = twoColumns
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: AppSizes.sidebarWidth, child: inputGroup),
              const SizedBox(width: AppSpacing.xl),
              Expanded(child: outputs),
            ],
          )
        : _stack([inputGroup, outputs]);

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
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _stack(List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.section),
          child,
        ],
      ],
    );
  }
}
