import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../../calculator/presentation/widgets/number_field.dart';
import '../../../calculator/presentation/widgets/section_card.dart';
import '../../../calculator/presentation/widgets/status_widgets.dart';
import '../../domain/mirror_engine.dart';
import '../../models/mirror_state.dart';
import '../mirror_controller.dart';
import '../mirror_format.dart';

/// 循环统计：记录当前结果到指定回合，三组 × 6 回合的手工数据与汇总。
class MirrorLoopView extends StatelessWidget {
  const MirrorLoopView({
    super.key,
    required this.controller,
    required this.wide,
  });

  final MirrorController controller;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final g in LoopGroup.values)
        _LoopGroupCard(controller: controller, group: g),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecordCard(controller: controller),
        const SizedBox(height: AppSpacing.section),
        _SummaryCard(controller: controller),
        const SizedBox(height: AppSpacing.section),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, g) in groups.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.section),
                Expanded(child: g),
              ],
            ],
          )
        else
          for (final (i, g) in groups.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.section),
            g,
          ],
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.controller});

  final MirrorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final r = c.result;
    final g = c.recordGroup;
    final round = c.recordRound;
    final existingDamage = c.loops.damage[g]![round];
    final existingClash = c.loops.clash[g]![round];
    final hasExisting = existingDamage != null || existingClash.hasValue;
    final record = c.recordOf(g, round);
    final styles = context.textStyles;

    return SectionCard(
      title: '记录到循环',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            r == null
                ? '当前输入有误，无法记录。'
                : '当前结果（按编辑器参数重新计算）：总伤害 ${mirrorNum(r.total)}'
                      ' · 拼点 ${mirrorNum(r.clash)}',
            key: const ValueKey('mirror-record-current'),
            style: numeric(styles.bodyLarge),
          ),
          const SizedBox(height: AppSpacing.lg),
          const FieldLabel('目标循环'),
          SegmentedChoice<LoopGroup>(
            key: const ValueKey('mirror-record-group'),
            options: [for (final x in LoopGroup.values) (x, x.label)],
            selected: g,
            onChanged: (x) => c.setRecordTarget(x, round),
          ),
          const SizedBox(height: AppSpacing.md),
          const FieldLabel('目标回合'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < mirrorLoopLength; i++)
                SizedBox(
                  width: 92,
                  height: 36,
                  child: FocusableTile(
                    inkKey: ValueKey('mirror-record-round-$i'),
                    color: i == round
                        ? context.palette.primarySoft
                        : context.palette.surface,
                    borderColor: i == round
                        ? context.palette.primaryBorder
                        : context.palette.border,
                    radius: AppRadius.control,
                    onTap: () => c.setRecordTarget(g, i),
                    child: Center(
                      child: Text(
                        loopRoundLabel(g.roundOffset, i),
                        style: styles.labelMedium?.copyWith(
                          color: i == round ? context.palette.primary : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hasExisting
                ? '该回合已有数据（伤害 ${mirrorNum(existingDamage)} · 拼点 '
                      '${existingClash.hasValue ? mirrorNum(existingClash.value) : '未填写'}），记录会覆盖。'
                : '该回合尚无记录。',
            style: styles.bodySmall,
          ),
          if (record != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '已保存的记录：伤害 ${mirrorNum(record.total)} · 拼点 ${mirrorNum(record.clash)}'
                    ' · 正反面 ${record.faceText}（记录时的结果，不随当前参数重算）',
                    key: const ValueKey('mirror-record-saved'),
                    style: styles.bodySmall,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('mirror-record-restore'),
                  onPressed: () => c.restoreRecord(g, round),
                  icon: const Icon(Icons.history),
                  label: const Text('恢复此回合配置'),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                key: const ValueKey('mirror-record'),
                onPressed: r == null ? null : c.recordCurrent,
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('记录当前结果'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('mirror-record-next'),
                onPressed: r == null ? null : c.recordAndAdvance,
                icon: const Icon(Icons.skip_next_outlined, size: 18),
                label: const Text('记录并进入下一回合'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '记录把当前总伤害与拼点写入所选回合，并保存含正反面的完整输入，可随时恢复；不会修改或清空技能参数。'
            '“记录并进入下一回合”会在写入后把目标前进一个回合；第一循环记满 6 回合后切换到第二循环。',
            style: styles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final MirrorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final totals = loopTotals(c.loops);
    final styles = context.textStyles;
    String avg(LoopGroup g) {
      final clash = c.loops.referenceClash(g);
      final n = loopClashCount(clash);
      return n == 0
          ? '—（无参与回合）'
          : '${mirrorNum(loopAverageClash(clash))}（$n 回合）';
    }

    final items = [
      ('第一循环', totals.loop1, avg(LoopGroup.loop1)),
      ('第二循环', totals.loop2, avg(LoopGroup.loop2)),
      ('两轮循环总和', totals.loop12, null),
      ('极限循环', totals.loop3, avg(LoopGroup.loop3)),
    ];
    return SectionCard(
      title: '循环汇总',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.loopErrorCount > 0) ...[
            StatusNotice(
              tone: NoticeTone.error,
              title: '有 ${c.loopErrorCount} 个循环单元格输入有误',
              lines: [
                for (final e in c.errors.entries)
                  if (e.key.startsWith('loop'))
                    '${describeMirrorPath(e.key)}：${e.value}',
                '有误的单元格按未填写处理，合计与平均暂不含这些格。',
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Wrap(
            spacing: AppSpacing.xxl,
            runSpacing: AppSpacing.lg,
            children: [
              for (final (label, total, average) in items)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: styles.labelMedium),
                    Text(
                      mirrorNum(total),
                      key: ValueKey('mirror-loop-total-$label'),
                      style: numeric(styles.headlineSmall),
                    ),
                    if (average != null)
                      Text('平均拼点 $average', style: numeric(styles.bodySmall)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '循环数据是手工记录的统计，不推导技能抽取、资源变化、被动触发或敌人状态。'
            '伤害未填写按 0 计入合计；拼点只统计有数值的回合，平均按四舍五入取整（半数向上）。',
            style: styles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LoopGroupCard extends StatelessWidget {
  const _LoopGroupCard({required this.controller, required this.group});

  final MirrorController controller;
  final LoopGroup group;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final g = group;
    final palette = context.palette;
    final styles = context.textStyles;
    return SectionCard(
      title: g.label,
      trailing: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: Text(
          '合计 ${mirrorNum(loopDamageSum(c.loops, g))}',
          style: numeric(styles.bodySmall),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(width: 72, child: Text('回合', style: styles.labelMedium)),
              Expanded(child: Text('伤害', style: styles.labelMedium)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('拼点', style: styles.labelMedium)),
              const SizedBox(width: 40 + 36),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < mirrorLoopLength; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    height: context.controlHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _RoundLabel(controller: c, group: g, round: i),
                    ),
                  ),
                  Expanded(
                    child: ShellTextField(
                      fieldKey: ValueKey('mirror-loop-${g.name}-d-$i'),
                      controller: c.damageText(g, i),
                      error: c.errorOf('${g.name}.$i'),
                      showErrorText: false,
                      textAlign: TextAlign.end,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      hintText: '未填写',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ShellTextField(
                      fieldKey: ValueKey('mirror-loop-${g.name}-c-$i'),
                      controller: c.clashText(g, i),
                      error: c.errorOf('${g.name}c.$i'),
                      showErrorText: false,
                      textAlign: TextAlign.end,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      hintText: c.clashSkipped(g, i) ? '不参与' : '未填写',
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: context.controlHeight,
                    child: IconButton(
                      key: ValueKey('mirror-loop-${g.name}-skip-$i'),
                      tooltip: c.clashSkipped(g, i) ? '恢复参与平均' : '本回合拼点不参与平均',
                      onPressed: () => c.toggleClashSkip(g, i),
                      icon: Icon(
                        c.clashSkipped(g, i)
                            ? Icons.block
                            : Icons.remove_circle_outline,
                        size: 18,
                        color: c.clashSkipped(g, i)
                            ? palette.warning
                            : palette.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    height: context.controlHeight,
                    child: c.recordOf(g, i) == null
                        ? null
                        : IconButton(
                            key: ValueKey('mirror-loop-${g.name}-restore-$i'),
                            tooltip: '恢复此回合记录时的完整配置（含正反面）',
                            onPressed: () => c.restoreRecord(g, i),
                            icon: Icon(
                              Icons.history,
                              size: 18,
                              color: palette.primary,
                            ),
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

/// 回合名：有记录快照时标注；当前数值与记录时不同则提示已手动修改。
class _RoundLabel extends StatelessWidget {
  const _RoundLabel({
    required this.controller,
    required this.group,
    required this.round,
  });

  final MirrorController controller;
  final LoopGroup group;
  final int round;

  @override
  Widget build(BuildContext context) {
    final record = controller.recordOf(group, round);
    final label = loopRoundLabel(group.roundOffset, round);
    final style = context.textStyles.bodySmall;
    if (record == null) return Text(label, style: style);
    final damage = controller.loops.damage[group]![round];
    final clash = controller.loops.clash[group]![round].value;
    final modified = damage != record.total || clash != record.clash;
    return Tooltip(
      message: modified
          ? '数值与记录时不同（已手动修改）；记录时：伤害 ${mirrorNum(record.total)}'
                ' · 拼点 ${mirrorNum(record.clash)} · ${record.faceText}'
          : '已记录：${record.faceText}',
      child: Text(
        modified ? '$label*' : '$label·',
        key: ValueKey('mirror-loop-${group.name}-label-$round'),
        style: style?.copyWith(
          color: modified ? context.palette.warning : context.palette.primary,
        ),
      ),
    );
  }
}
