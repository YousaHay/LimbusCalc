import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../models/calculation_result.dart';
import '../calculation_summary.dart';
import 'section_card.dart';

/// 可展开的“计算过程”。所有数值来自 [CalculationResult]，此处只做展示。
class CalculationProcessPanel extends StatelessWidget {
  const CalculationProcessPanel({
    super.key,
    required this.result,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final CalculationResult? result;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    return CollapsibleCard(
      key: const ValueKey('process-tile'),
      title: '计算过程',
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      summary: result == null
          ? '输入有误，暂无计算过程'
          : '静态乘区 ${formatNumber(result.factors.staticFactor)}'
                ' · 动态乘区 ${formatNumber(result.factors.dynamicFactor)}',
      child: result == null
          ? Text('输入有误，暂无计算过程。', style: context.textStyles.bodySmall)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._steps(result),
                Text(
                  '显示值最多保留 4 位小数（C 为 6 位），底层使用 Dart double 完整精度；'
                  '游戏内部为 32 位浮点，本版不保证逐位一致。',
                  style: context.textStyles.bodySmall,
                ),
              ],
            ),
    );
  }

  List<Widget> _steps(CalculationResult result) {
    final input = result.input;
    final f = result.factors;
    final n = formatNumber;
    return [
      _Step(
        title: '① 罪孽抗性修正 A',
        lines: [
          '倍率 r = ${n(input.sinResistance)}，${_resistanceBranch(input.sinResistance)}',
          'A = ${n(f.sinResistanceBonus)}',
        ],
      ),
      _Step(
        title: '② 物理抗性修正 B',
        lines: [
          '倍率 r = ${n(input.physicalResistance)}，'
              '${_resistanceBranch(input.physicalResistance)}',
          'B = ${n(f.physicalResistanceBonus)}',
        ],
      ),
      _Step(
        title: '③ 攻防等级修正 C',
        lines: [
          'd = ${input.offenseLevel} − ${input.defenseLevel} = ${f.levelDifference}',
          'C = d / (|d| + 25) = ${f.levelDifference} / '
              '${f.levelDifference.abs() + 25} = ${n(f.levelBonus, digits: 6)}',
        ],
        note: '本版不截断中间结果（两位截断规则待验证）',
      ),
      _Step(
        title: '④ 拼点与暴击修正',
        lines: [
          '拼点 = ${input.clashCount} × 0.03 = ${n(f.clashBonus)}',
          '暴击 = ${input.isCritical ? '0.2（暴击）' : '0（未暴击）'}',
        ],
      ),
      _Step(
        title: '⑤ 静态乘区',
        lines: [
          'max(1 + A + B + C + 拼点 + 暴击, 0)',
          '= max(1 + ${n(f.sinResistanceBonus)} + ${n(f.physicalResistanceBonus)}'
              ' + ${n(f.levelBonus)} + ${n(f.clashBonus)} + ${n(f.criticalBonus)}, 0)',
          '= max(${n(f.staticSum)}, 0) = ${n(f.staticFactor)}',
        ],
      ),
      _Step(
        title: '⑥ 动态乘区',
        lines: [
          '1 + 进攻方 + 受击方 = 1 + ${n(input.attackerDynamicBonus)}'
              ' + ${n(input.defenderDynamicBonus)} = ${n(f.dynamicFactor)}',
        ],
      ),
      _Step(
        title: '⑦ 伤害保底与最终取整（逐枚独立）',
        lines: result.isOk
            ? [
                '伤害 = floor(max(P × 静态 × 动态, max(1, P × 0.05)))',
                for (final coin in result.coins)
                  '#${coin.step.index + 1}  P = ${coin.step.hitPower}：'
                      '原始 ${n(coin.rawDamage)}，保底 ${n(coin.minimumDamage)}'
                      ' → floor(${n(coin.isMinimumApplied ? coin.minimumDamage : coin.rawDamage)})'
                      ' = ${coin.finalDamage}',
                '合计 = ${result.coins.map((c) => c.finalDamage).join(' + ')}'
                    ' = ${result.totalDamage}',
              ]
            : const ['威力降至 0 或以下，游戏处理方式待确认，未计算逐枚伤害。'],
      ),
    ];
  }

  static String _resistanceBranch(double r) {
    if (r <= 0) return '适用 r ≤ 0 → −0.5';
    if (r < 1) return '适用 0 < r < 1 → (r − 1) / 2';
    return '适用 r ≥ 1 → r − 1';
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.title, required this.lines, this.note});

  final String title;
  final List<String> lines;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final formula = numeric(context.textStyles.bodyMedium);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.textStyles.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: ShapeDecoration(
              color: palette.surfaceMuted,
              shape: smoothShape(
                AppRadius.control,
                side: BorderSide(color: palette.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(line, style: formula),
                  ),
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.xs + 2),
            Text(note!, style: context.textStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}
