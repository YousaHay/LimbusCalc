import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../models/calculation_input.dart';
import '../../models/calculation_result.dart';
import '../calculation_summary.dart';
import 'section_card.dart';
import 'status_widgets.dart';

/// 逐枚硬币明细：宽时为数据表，窄时为逐枚卡片，避免横向溢出。
class CoinBreakdown extends StatelessWidget {
  const CoinBreakdown({super.key, required this.result});

  final CalculationResult? result;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    if (result == null) {
      return SectionCard(
        title: '逐枚硬币明细',
        child: Text('输入有误，暂无明细', style: context.textStyles.bodySmall),
      );
    }
    final rows = _rowsOf(result);
    final total = result.isOk ? '${result.totalDamage}' : '未输出';
    return LayoutBuilder(
      builder: (context, constraints) {
        final table = constraints.maxWidth >= AppSizes.breakdownTableWidth;
        return SectionCard(
          title: '逐枚硬币明细',
          trailing: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Text(
              '${rows.length} 枚',
              style: numeric(context.textStyles.bodySmall),
            ),
          ),
          bodyPadding: table ? const EdgeInsets.only(top: AppSpacing.md) : null,
          child: table
              ? _BreakdownTable(rows: rows, total: total)
              : _BreakdownCards(rows: rows, total: total),
        );
      },
    );
  }

  static List<_Row> _rowsOf(CalculationResult result) {
    return [
      for (final step in result.powerSteps)
        _Row(
          index: step.index,
          face: step.face,
          power: '${step.powerBefore} → ${step.hitPower}',
          raw: result.isOk
              ? formatNumber(result.coins[step.index].rawDamage)
              : '—',
          damage: result.isOk
              ? '${result.coins[step.index].finalDamage}'
              : '未输出',
          isMinimum: result.isOk && result.coins[step.index].isMinimumApplied,
        ),
    ];
  }
}

class _Row {
  const _Row({
    required this.index,
    required this.face,
    required this.power,
    required this.raw,
    required this.damage,
    required this.isMinimum,
  });

  final int index;
  final CoinFace face;
  final String power;
  final String raw;
  final String damage;
  final bool isMinimum;
}

/// 列定义：标题、弹性宽度、是否为数值列（右对齐）。
const _columns = [
  ('硬币', 2, false),
  ('正反面', 2, false),
  ('威力变化', 3, true),
  ('取整前伤害', 3, true),
  ('最终伤害', 3, true),
];

class _BreakdownTable extends StatelessWidget {
  const _BreakdownTable({required this.rows, required this.total});

  final List<_Row> rows;
  final String total;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pad = context.cardPadding;
    final header = context.textStyles.labelMedium;
    final body = numeric(context.textStyles.bodyMedium);
    final strong = body.copyWith(fontWeight: FontWeight.w600);

    Widget cells(List<Widget> children) => Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: Row(
        children: [
          for (final (i, (_, flex, isNumber)) in _columns.indexed)
            Expanded(
              flex: flex,
              child: Align(
                alignment: isNumber
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: children[i],
              ),
            ),
        ],
      ),
    );

    return Column(
      key: const ValueKey('breakdown-table'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(
            minHeight: AppSizes.tableHeaderHeight,
          ),
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            border: Border.symmetric(
              horizontal: BorderSide(color: palette.border),
            ),
          ),
          child: cells([
            for (final (title, _, _) in _columns) Text(title, style: header),
          ]),
        ),
        for (final row in rows)
          _HoverRow(
            child: cells([
              Text('#${row.index + 1}', style: body),
              FaceTag(face: row.face),
              Text(row.power, style: body),
              Text(row.raw, style: body),
              _FinalDamage(row: row, style: strong),
            ]),
          ),
        Container(
          constraints: const BoxConstraints(minHeight: AppSizes.tableRowHeight),
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            border: Border(top: BorderSide(color: palette.borderStrong)),
          ),
          child: cells([
            Text('合计', style: context.textStyles.titleSmall),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            Text(
              total,
              key: const ValueKey('breakdown-total'),
              style: strong.copyWith(fontWeight: FontWeight.w700),
            ),
          ]),
        ),
      ],
    );
  }
}

/// 表格行：最小行高 46，桌面端悬停时显示浅色背景。
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child});

  final Widget child;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.tableRowHeight),
        decoration: BoxDecoration(
          color: _hovered ? palette.hover : null,
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: widget.child,
      ),
    );
  }
}

class _FinalDamage extends StatelessWidget {
  const _FinalDamage({required this.row, required this.style});

  final _Row row;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (row.isMinimum) ...[
          Tooltip(
            message: '由保底伤害决定',
            child: Text(
              '保底',
              style: context.textStyles.labelSmall?.copyWith(
                color: palette.warning,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(row.damage, style: style),
      ],
    );
  }
}

class _BreakdownCards extends StatelessWidget {
  const _BreakdownCards({required this.rows, required this.total});

  final List<_Row> rows;
  final String total;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final body = numeric(context.textStyles.bodyMedium);
    final small = numeric(context.textStyles.bodySmall);
    final strong = numeric(context.textStyles.titleMedium)
        .copyWith(fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Container(
            key: ValueKey('breakdown-card-${row.index}'),
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('#${row.index + 1}', style: body),
                ),
                FaceTag(face: row.face),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('威力 ${row.power}', style: body),
                      Text('取整前 ${row.raw}', style: small),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FinalDamage(row: row, style: strong),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(child: Text('合计', style: context.textStyles.titleSmall)),
              Text(
                total,
                key: const ValueKey('breakdown-total'),
                style: strong,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
