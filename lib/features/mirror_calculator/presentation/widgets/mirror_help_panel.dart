import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../../calculator/presentation/widgets/section_card.dart';

/// 字段说明与参考模型的简化假设。
class MirrorHelpPanel extends StatelessWidget {
  const MirrorHelpPanel({
    super.key,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  static const _sections = <(String, List<String>)>[
    (
      '输入单位',
      [
        '硬币数量、基础威力、硬币威力、攻击容量、各等级与加成、呼吸法强度、单币硬币威力、终币特殊威力、固定追伤为整数：'
            '输入小数时按 JavaScript Math.round 取整（如 2.5 → 3，−2.5 → −2），失焦后显示取整结果。',
        '技能第一 / 第二乘区、单币第二乘区、追伤系数为小数倍率：0.1 表示 +10%，不取整。',
        '基础威力、攻击等级、敌方等级、呼吸法强度不能为负（负数按 0）；攻击容量至少为 1。',
        '硬币威力用“加算 / 减算”加非负数值输入，内部保存带符号的值；'
            '最终硬币威力 = 带符号的硬币威力 + 硬币威力加成（加成只应用一次）。',
      ],
    ),
    (
      '正反面（本应用扩展）',
      [
        '普通硬币与重投分别选择全部正面 / 全部反面 / 自定义，并可逐枚点击切换；默认全部正面，与参考结果一致。',
        '起始威力为最终基础威力；正面应用最终硬币威力，反面不应用，已有累计保留到之后的硬币；每次命中使用当时的累计威力。',
        '反面不等于未命中：反面行仍造成伤害，并照常结算比例追伤（以实际的不计算追伤伤害为基数）与固定追伤。',
        '正反面与暴击相互独立；拼点点数沿用参考的全正面假设，不随正反面变化。',
        '重投（简化模型）：在全部普通硬币之后结算，从此时的累计威力继续，按重投自身的正反面逐次应用最终硬币威力。',
        '减少硬币数量或关闭重投时，隐藏行不参与计算，但保留其正反面与逐币修正，重新启用时恢复。',
      ],
    ),
    (
      '作用范围',
      [
        '呼吸法强度、单币第二乘区、固定追伤、追伤系数只作用于当前行。',
        '单币硬币威力与终币特殊威力是手动修正：无论正反面，都计入当前行以及之后所有启用行的威力；'
            '不自动解析游戏技能的触发条件。',
        '拼点点数只累计单币硬币威力；重投行只有在“重投是否参与拼点 = 是”时计入。',
      ],
    ),
    (
      '计算顺序',
      [
        '单币第一乘区先 ROUND 到 2 位小数，再与第二乘区相乘；伤害一律 INT 向下取整。',
        '不计算追伤伤害 = MAX(1, INT(威力基数 × 乘区积 × 攻击容量))，保底为 1。',
        '比例追伤 = INT(已取整的不计算追伤伤害 × 追伤系数)，不再乘攻击容量。',
        '伤害数值 = INT(不计算追伤伤害 + 比例追伤 + 固定追伤 × 攻击容量)；总伤害为各启用行之和。',
      ],
    ),
    (
      '参考模型的简化假设',
      [
        '技能第一乘区计入两次（进入单币第一乘区，并在乘区中再加一次），与参考实现保持一致，未修改。',
        '呼吸法按 MIN(层数 × 5% × 0.2, 0.2) 线性折算暴击贡献，不是逐枚概率枚举，也不是精确期望。',
        '拼点结果是点数，不是胜率；正反面表示命中阶段的投掷结果，不模拟拼点过程；'
            '循环数据是手工记录的统计，不是战斗模拟。',
        '本模式不含抗性、攻防等级乘区、威力 5% 保底等基础模式规则；威力降至 0 以下时伤害仍按参考保底为 1，'
            '与基础计算不同。两种模式的公式互不混用。',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CollapsibleCard(
      key: const ValueKey('mirror-help'),
      title: '字段说明与模型假设',
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      summary: '单位、累计范围、取整位置与参考模型的简化假设',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (title, lines) in _sections) ...[
            Text(title, style: context.textStyles.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  top: 2,
                  bottom: 2,
                ),
                child: Text('· $line', style: context.textStyles.bodyMedium),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            '计算模型移植自 MirrorCalcWeb（f0lkskill，MIT License），基准提交 d7f538d；加减算与正反面为本应用扩展。',
            style: context.textStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}
