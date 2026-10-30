import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app_theme.dart';
import '../../../calculator/presentation/widgets/section_card.dart';
import '../../../calculator/presentation/widgets/status_widgets.dart';
import '../../models/mirror_result.dart';
import '../../models/mirror_state.dart';
import '../mirror_controller.dart';
import '../mirror_format.dart';
import '../mirror_summary.dart';

/// 结果摘要：总伤害、拼点点数、伤害构成与派生值。数值全部来自 [MirrorResult]。
class MirrorResultCard extends StatelessWidget {
  const MirrorResultCard({super.key, required this.controller});

  final MirrorController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final state = controller.state;
    return SectionCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('计算结果', style: context.textStyles.labelMedium),
              ),
              TextButton.icon(
                key: const ValueKey('mirror-copy'),
                onPressed: result == null || state == null
                    ? null
                    : () => _copy(context, state, result),
                icon: const Icon(Icons.content_copy_outlined),
                label: const Text('复制摘要'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (result == null || state == null)
            StatusNotice(
              key: const ValueKey('mirror-input-error'),
              tone: NoticeTone.error,
              title: '输入有误，当前没有有效结果',
              lines: [
                for (final e in controller.inputErrors)
                  '${describeMirrorPath(e.key)}：${e.value}',
              ],
            )
          else
            _ResultBody(state: state, result: result),
        ],
      ),
    );
  }

  Future<void> _copy(
    BuildContext context,
    MirrorState state,
    MirrorResult result,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: buildMirrorSummary(state, result)),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('已复制计算摘要'),
          duration: Duration(seconds: 2),
        ),
      );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.state, required this.result});

  final MirrorState state;
  final MirrorResult result;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    final palette = context.palette;
    final counter = state.flag(MirrorFlag.counter);
    final joined = state.flag(MirrorFlag.joinClash);
    final clashNote = counter
        ? '不可拼点反击：点数为 0'
        : !joined
        ? '不参与拼点：点数为 0'
        : '拼点点数，不是胜率';
    final rerolls = result.activeRerolls;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xxl,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _Metric(
              label: '总伤害',
              value: mirrorNum(result.total),
              valueKey: const ValueKey('mirror-total'),
              large: true,
            ),
            _Metric(
              label: '拼点点数',
              value: mirrorNum(result.clash),
              valueKey: const ValueKey('mirror-clash'),
              note: clashNote,
              tooltip:
                  '拼点点数沿用参考模型的全正面假设：修改命中阶段的正反面不会改变它。'
                  '它是点数，不是拼点胜率。',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '启用 ${result.activeCoins} 枚硬币'
          '${rerolls > 0 ? ' + $rerolls 次重投' : ''}',
          key: const ValueKey('mirror-active-summary'),
          style: styles.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          _faceSequence(result),
          key: const ValueKey('mirror-face-sequence'),
          style: styles.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        Divider(color: palette.border),
        const SizedBox(height: AppSpacing.md),
        Text('伤害构成', style: styles.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _Composition(result: result),
        const SizedBox(height: AppSpacing.lg),
        Text('派生值', style: styles.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _KeyValues(
          entries: [
            ('攻/防等级差值', mirrorNum(result.levelDiff)),
            ('等级差修正', mirrorFixed(result.levelMod, 6)),
            ('最终基础威力', mirrorNum(result.finalBase)),
            ('最终硬币威力', mirrorNum(result.finalCoin)),
            ('威力总值', mirrorNum(result.powerTotal)),
            ('暴击部分', state.flag(MirrorFlag.crit) ? '0.2（必定暴击）' : '按行估算（呼吸法折算）'),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.valueKey,
    this.large = false,
    this.note,
    this.tooltip,
  });

  final String label;
  final String value;
  final Key valueKey;
  final bool large;
  final String? note;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: styles.labelMedium),
            if (tooltip != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Tooltip(
                message: tooltip,
                child: Icon(
                  Icons.info_outline,
                  size: 14,
                  color: context.palette.textSecondary,
                ),
              ),
            ],
          ],
        ),
        Text(
          value,
          key: valueKey,
          style: numeric(
            large
                ? styles.displaySmall
                : styles.displaySmall?.copyWith(fontSize: 32),
          ),
        ),
        if (note != null) Text(note!, style: styles.bodySmall),
      ],
    );
  }
}

/// 直接伤害 / 比例追伤 / 固定追伤 的构成条与数值。
class _Composition extends StatelessWidget {
  const _Composition({required this.result});

  final MirrorResult result;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parts = [
      ('直接伤害', result.sumJ, palette.primary, '各行“不计算追伤伤害”之和'),
      ('比例追伤', result.sumN, palette.primaryBorder, '各行 INT(不计算追伤伤害 × 追伤系数) 之和'),
      ('固定追伤', result.sumFixedPart, palette.borderStrong, '各行 固定追伤 × 攻击容量 之和'),
    ];
    final positive = [
      for (final p in parts)
        if (p.$2 > 0) p,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (positive.isNotEmpty)
          ClipRSuperellipse(
            borderRadius: BorderRadius.circular(AppRadius.tag),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  for (final p in positive)
                    Expanded(
                      // 整数权重仅用于条形比例显示。
                      flex: (p.$2 * 1000).round().clamp(1, 1 << 30),
                      child: ColoredBox(color: p.$3),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        for (final p in parts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: ShapeDecoration(
                    color: p.$3,
                    shape: smoothShape(2),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Tooltip(
                    message: p.$4,
                    child: Text(p.$1, style: context.textStyles.bodyMedium),
                  ),
                ),
                Text(
                  mirrorNum(p.$2),
                  key: ValueKey('mirror-part-${p.$1}'),
                  style: numeric(context.textStyles.bodyMedium),
                ),
              ],
            ),
          ),
        if (result.compositionRemainder != 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '各行伤害数值整体向下取整，分项之和与总伤害相差 '
              '${mirrorNum(result.compositionRemainder)}',
              style: context.textStyles.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _KeyValues extends StatelessWidget {
  const _KeyValues({required this.entries});

  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    return Column(
      children: [
        for (final (k, v) in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(child: Text(k, style: styles.bodySmall)),
                Text(v, style: numeric(styles.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// 启用行的正反面序列（普通硬币与重投分开显示）。
String _faceSequence(MirrorResult r) {
  final coins = [
    for (final row in r.activeRows)
      if (!row.isReroll) row.face.label,
  ];
  final rerolls = [
    for (final row in r.activeRows)
      if (row.isReroll) row.face.label,
  ];
  return '正反面：${coins.isEmpty ? '—' : coins.join(' ')}'
      '${rerolls.isEmpty ? '' : ' · 重投：${rerolls.join(' ')}'}';
}
