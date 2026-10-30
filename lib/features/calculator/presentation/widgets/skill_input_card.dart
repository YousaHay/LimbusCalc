import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../models/calculation_input.dart';
import '../calculator_controller.dart';
import 'coin_controls.dart';
import 'number_field.dart';
import 'section_card.dart';

/// 技能参数：基础威力、硬币数量、硬币威力、正反面。
class SkillInputCard extends StatelessWidget {
  const SkillInputCard({super.key, required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SectionCard(
      title: '技能参数',
      trailing: TextButton.icon(
        key: const ValueKey('reset-button'),
        onPressed: controller.reset,
        style: TextButton.styleFrom(foregroundColor: palette.textSecondary),
        icon: Icon(Icons.restart_alt, color: palette.textSecondary),
        label: const Text('重置参数'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TwoColumnFields(
            left: NumberField(
              controller: controller,
              field: CalculatorField.basePower,
              signed: true,
            ),
            right: _CoinCountStepper(controller: controller),
          ),
          const SizedBox(height: AppSpacing.lg + 4),
          _CoinPowerInput(controller: controller),
          const SizedBox(height: AppSpacing.lg + 4),
          const FieldLabel('硬币正反面'),
          SegmentedChoice<FaceMode>(
            key: const ValueKey('face-mode'),
            options: const [
              (FaceMode.allHeads, '全部正面'),
              (FaceMode.allTails, '全部反面'),
              (FaceMode.custom, '自定义'),
            ],
            selected: controller.faceMode,
            onChanged: controller.setFaceMode,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final (i, face) in controller.displayFaces.indexed)
                CoinFaceTile(
                  inkKey: ValueKey('coin-toggle-$i'),
                  heads: face == CoinFace.heads,
                  caption: '${i + 1}',
                  semanticLabel: '第 ${i + 1} 枚硬币：${face.label}面，点击切换',
                  onTap: () => controller.toggleFace(i),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('点击单枚硬币可切换正反面', style: context.textStyles.bodySmall),
        ],
      ),
    );
  }
}

/// 硬币数量：− 数值 + 合并为一个控件，外框与其他输入框共用 [ShellTextField]。
class _CoinCountStepper extends StatelessWidget {
  const _CoinCountStepper({required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    final count = controller.displayCoinCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('硬币数量', hint: '$minCoinCount～$maxCoinCount 枚'),
        ShellTextField(
          fieldKey: const ValueKey('field-coinCount'),
          controller: controller.textOf(CalculatorField.coinCount),
          error: controller.errorOf(CalculatorField.coinCount),
          textAlign: TextAlign.center,
          leading: StepIconButton(
            key: const ValueKey('coin-count-minus'),
            icon: Icons.remove,
            tooltip: count > minCoinCount ? '减少一枚' : '已达下限 1 枚',
            onPressed: count > minCoinCount
                ? () => controller.changeCoinCountBy(-1)
                : null,
          ),
          trailing: StepIconButton(
            key: const ValueKey('coin-count-plus'),
            icon: Icons.add,
            tooltip: count < maxCoinCount ? '增加一枚' : '已达上限 10 枚',
            onPressed: count < maxCoinCount
                ? () => controller.changeCoinCountBy(1)
                : null,
          ),
        ),
      ],
    );
  }
}

/// 硬币威力：加算 / 减算 + 非负数值（公共组件 [SignedPowerInput]）。
class _CoinPowerInput extends StatelessWidget {
  const _CoinPowerInput({required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    return SignedPowerInput(
      isAdd: controller.coinPowerSign == CoinPowerSign.add,
      onAddChanged: (add) => controller.setCoinPowerSign(
        add ? CoinPowerSign.add : CoinPowerSign.subtract,
      ),
      controller: controller.textOf(CalculatorField.coinPower),
      error: controller.errorOf(CalculatorField.coinPower),
      fieldKey: const ValueKey('field-coinPower'),
      signKey: const ValueKey('coin-power-sign'),
      prefixKey: const ValueKey('coin-power-prefix'),
      tooltip: '正面时对当前威力应用的变化值；减算即负值',
    );
  }
}
