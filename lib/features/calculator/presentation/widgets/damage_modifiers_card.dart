import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../calculator_controller.dart';
import 'number_field.dart';
import 'section_card.dart';

/// 伤害修正，默认折叠；折叠时显示当前参数摘要。
class DamageModifiersCard extends StatelessWidget {
  const DamageModifiersCard({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final CalculatorController controller;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  static const _modifierFields = {
    CalculatorField.offenseLevel,
    CalculatorField.defenseLevel,
    CalculatorField.physicalResistance,
    CalculatorField.sinResistance,
    CalculatorField.clashCount,
    CalculatorField.attackerDynamic,
    CalculatorField.defenderDynamic,
  };

  @override
  Widget build(BuildContext context) {
    final errorCount = controller.errors.keys
        .where(_modifierFields.contains)
        .length;
    return CollapsibleCard(
      key: const ValueKey('modifiers-tile'),
      title: '伤害修正',
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      summary: errorCount > 0 ? '$errorCount 项输入有误' : _summary(),
      summaryIsError: errorCount > 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Group(
            title: '攻防等级',
            child: TwoColumnFields(
              left: NumberField(
                controller: controller,
                field: CalculatorField.offenseLevel,
                label: '攻击等级',
                tooltip: '最终攻击等级：已计入外部修正后的技能攻击等级，不是角色等级',
              ),
              right: NumberField(
                controller: controller,
                field: CalculatorField.defenseLevel,
                label: '防御等级',
                tooltip: '目标防御等级',
              ),
            ),
          ),
          _Group(
            title: '抗性倍率',
            tooltip: '直接输入本次攻击实际使用的倍率，不自动处理混乱或抗性覆盖',
            child: TwoColumnFields(
              left: NumberField(
                controller: controller,
                field: CalculatorField.physicalResistance,
                label: '物理',
                decimal: true,
                signed: true,
              ),
              right: NumberField(
                controller: controller,
                field: CalculatorField.sinResistance,
                label: '罪孽',
                decimal: true,
                signed: true,
              ),
            ),
          ),
          _Group(
            title: '拼点与暴击',
            child: TwoColumnFields(
              left: NumberField(
                controller: controller,
                field: CalculatorField.clashCount,
                label: '拼点轮数',
                tooltip: '0 表示未经拼点的单方面攻击',
              ),
              right: _CriticalSwitch(controller: controller),
            ),
          ),
          _Group(
            title: '动态增减伤',
            tooltip: '以百分数输入，可为负数；两侧在同一动态乘区相加',
            isLast: true,
            child: TwoColumnFields(
              left: NumberField(
                controller: controller,
                field: CalculatorField.attackerDynamic,
                label: '进攻方',
                suffixText: '%',
                decimal: true,
                signed: true,
              ),
              right: NumberField(
                controller: controller,
                field: CalculatorField.defenderDynamic,
                label: '受击方',
                suffixText: '%',
                decimal: true,
                signed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 摘要使用原始输入文本，仅用于提示，不参与计算。
  /// 固定分两行，避免中文在任意位置断行把一项拆开。
  String _summary() {
    String t(CalculatorField f) => controller.textOf(f).text.trim();
    return '攻 ${t(CalculatorField.offenseLevel)} / 防 ${t(CalculatorField.defenseLevel)}'
        ' · 物理 ×${t(CalculatorField.physicalResistance)}'
        ' · 罪孽 ×${t(CalculatorField.sinResistance)}\n'
        '拼点 ${t(CalculatorField.clashCount)}'
        ' · ${controller.isCritical ? '暴击' : '未暴击'}'
        ' · 动态 ${t(CalculatorField.attackerDynamic)}% / '
        '${t(CalculatorField.defenderDynamic)}%';
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.child,
    this.tooltip,
    this.isLast = false,
  });

  final String title;
  final String? tooltip;
  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: context.textStyles.titleSmall),
              if (tooltip != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: tooltip,
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _CriticalSwitch extends StatelessWidget {
  const _CriticalSwitch({required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('暴击', tooltip: '暴击基础加成 +0.2 计入静态乘区，第一版应用于所有命中'),
        Material(
          color: palette.field,
          shape: smoothShape(AppRadius.control),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => controller.setCritical(!controller.isCritical),
            canRequestFocus: false,
            child: SizedBox(
              height: context.controlHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.isCritical ? '所有命中暴击' : '未暴击',
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.bodyMedium,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        key: const ValueKey('critical-switch'),
                        value: controller.isCritical,
                        onChanged: controller.setCritical,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
