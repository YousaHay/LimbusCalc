import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../../calculator/presentation/widgets/section_card.dart';
import '../../models/mirror_result.dart';
import '../../models/mirror_state.dart';
import '../mirror_format.dart';

/// 可展开的逐行计算过程。数值全部来自 [MirrorResult]，此处只做格式化展示。
class MirrorProcessPanel extends StatelessWidget {
  const MirrorProcessPanel({
    super.key,
    required this.state,
    required this.result,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final MirrorState? state;
  final MirrorResult? result;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final r = result;
    return CollapsibleCard(
      key: const ValueKey('mirror-process'),
      title: '逐行计算过程',
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      summary: r == null
          ? '输入有误，暂无计算过程'
          : '${r.activeRows.length} 行 · 每行展开暴击、乘区、威力基数、取整与追伤',
      child: s == null || r == null
          ? Text('输入有误，暂无计算过程。', style: context.textStyles.bodySmall)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Block(title: '全局', lines: _globalLines(s, r)),
                for (final row in r.activeRows)
                  _Block(
                    title:
                        '${row.label} · ${row.face.label}面 · 已应用硬币威力 ${mirrorNum(row.n)} 次',
                    lines: _rowLines(s, r, row),
                  ),
                _Block(title: '拼点点数', lines: _clashLines(s, r)),
              ],
            ),
    );
  }

  static List<String> _globalLines(MirrorState s, MirrorResult r) {
    final n = mirrorNum;
    return [
      '攻/防等级差值 = ${n(s[MirrorField.atkLevel])} + ${n(s[MirrorField.atkLevelBonus])}'
          ' − ${n(s[MirrorField.enemyLevel])} = ${n(r.levelDiff)}',
      '等级差修正 = 差值 ÷ (|差值| + 25) = ${mirrorFixed(r.levelMod, 6)}',
      '最终基础威力 = INT(${n(s[MirrorField.basePower])} + ${n(s[MirrorField.baseBonus])}'
          '${s.flag(MirrorFlag.counter) ? ' + 差值 ÷ 3' : ''}) = ${n(r.finalBase)}',
      '最终硬币威力 = ${n(s[MirrorField.coinPower])} + ${n(s[MirrorField.coinBonus])}'
          ' = ${n(r.finalCoin)}',
      '技能第一乘区 z1 = ${n(s[MirrorField.z1])}，技能第二乘区 z2 = ${n(s[MirrorField.z2])}，'
          '攻击容量 = ${n(s[MirrorField.capacity])}',
    ];
  }

  static List<String> _rowLines(MirrorState s, MirrorResult r, MirrorRow row) {
    final n = mirrorNum;
    final z1 = n(s[MirrorField.z1]);
    final z2 = n(s[MirrorField.z2]);
    final cap = n(s[MirrorField.capacity]);
    final c = s.coins[row.idx];
    final heads = row.face == MirrorFace.heads;
    return [
      '威力：命中前 ${n(row.powerBefore)}'
          ' ${heads ? '+ 最终硬币威力 ${n(r.finalCoin)}（正面）' : '+ 0（反面不应用硬币威力）'}'
          '${c.h != 0 ? ' + 单币硬币威力 ${n(c.h)}' : ''}'
          '${c.i != 0 ? ' + 终币特殊威力 ${n(c.i)}' : ''}'
          ' = ${n(row.powerBase)}',
      s.flag(MirrorFlag.crit)
          ? '暴击部分 = 0.2（必定暴击）'
          : '暴击部分 = MIN(${n(row.breath)} × 5% × 0.2, 0.2) = ${n(row.critPart)}',
      '单币第一乘区 F = ROUND(${n(row.critPart)} + $z1 + ${mirrorFixed(r.levelMod, 6)}, 2)'
          ' = ROUND(${n(row.fRaw)}, 2) = ${mirrorFixed(row.f, 2)}',
      '乘区 = (1 + $z1 + ${mirrorFixed(row.f, 2)}) × (1 + $z2 + ${n(row.g)})'
          ' = ${n(row.m1)} × ${n(row.m2)} = ${n(row.mult)}',
      '（等价于 威力基数 = ${n(r.finalBase)} + ${n(r.finalCoin)} × ${n(row.n)}'
          ' + Σ硬币威力 ${n(row.sumH)} + Σ特殊威力 ${n(row.sumI)} = ${n(row.powerBase)}）',
      '不计算追伤伤害 = MAX(1, INT(${n(row.powerBase)} × ${n(row.mult)} × $cap))'
          ' = MAX(1, INT(${n(row.rawJ)})) = ${n(row.j)}（取整损失 ${n(row.loss)}）',
      row.extra
          ? '比例追伤 = INT(${n(row.j)} × ${n(row.coef)}) = INT(${n(row.extraRaw)}) = ${n(row.nv)}'
          : '比例追伤：未开启 = 0',
      '伤害数值 = INT(${n(row.j)} + ${n(row.nv)} + ${n(row.fixed)} × $cap)'
          ' = ${n(row.o)}',
    ];
  }

  static List<String> _clashLines(MirrorState s, MirrorResult r) {
    final n = mirrorNum;
    if (s.flag(MirrorFlag.counter)) return ['不可拼点反击：拼点点数 = 0'];
    if (!s.flag(MirrorFlag.joinClash)) return ['不参与拼点：拼点点数 = 0'];
    final rerollIn =
        s.flag(MirrorFlag.reroll) && s.flag(MirrorFlag.rerollClash);
    return [
      '拼点 = INT(基础威力 ${n(s[MirrorField.basePower])} + 终础威力加成 ${n(s[MirrorField.baseBonus])}'
          ' + ${n(r.finalCoin)} × ${n(s[MirrorField.coinCount])} + 差值 ÷ 3'
          ' + 拼点威力加成 ${n(s[MirrorField.clashBonus])}'
          '${rerollIn ? ' + ${n(r.finalCoin)} × ${n(s[MirrorField.rerollCount])}' : ''}'
          ' + Σ单币硬币威力 ${n(r.clashPower)}) = ${n(r.clash)}',
      '使用原始“基础威力 + 终础威力加成”（未取整、不含反击加成），不含终币特殊威力。',
      '拼点点数沿用参考模型的全正面假设，不随命中阶段的正反面变化；它是点数，不是胜率。',
    ];
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
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
                    child: Text(
                      line,
                      style: numeric(context.textStyles.bodyMedium),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
