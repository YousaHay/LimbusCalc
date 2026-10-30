import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../../calculator/presentation/widgets/number_field.dart';
import '../../../calculator/presentation/widgets/section_card.dart';
import '../../models/mirror_result.dart';
import '../../models/mirror_state.dart';
import '../mirror_controller.dart';
import '../mirror_format.dart';
import 'mirror_inputs.dart';

/// 表格模式所需的最小卡片内宽。
const double _tableMinWidth = 1060;

/// 逐行硬币 / 重投参数：宽屏表格，窄屏逐行卡片。只显示启用的行；
/// 隐藏行保留配置，重新启用时恢复。正反面与顶部按钮共用同一份数据。
class MirrorCoinEditor extends StatelessWidget {
  const MirrorCoinEditor({super.key, required this.controller});

  final MirrorController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final rows = [
      for (var i = 0; i < mirrorCoinRows; i++)
        if (c.isRowShown(i)) i,
    ];
    final mains = rows.where((i) => i < mirrorMainCoins).length;
    final rerolls = rows.length - mains;
    return LayoutBuilder(
      builder: (context, constraints) {
        final table =
            constraints.maxWidth - 2 * context.cardPadding >= _tableMinWidth;
        return SectionCard(
          title: '硬币参数',
          trailing: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Text(
              '硬币 $mains · 重投 $rerolls',
              style: numeric(context.textStyles.bodySmall),
            ),
          ),
          bodyPadding: table && rows.isNotEmpty
              ? const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm)
              : null,
          child: rows.isEmpty
              ? Text(
                  '还没有启用任何硬币：把“硬币数量”设为 1 以上，硬币行会依次出现。',
                  key: const ValueKey('mirror-coins-empty'),
                  style: context.textStyles.bodySmall,
                )
              : table
              ? _CoinTable(controller: c, rows: rows)
              : _CoinCards(controller: c, rows: rows),
        );
      },
    );
  }
}

/// 列定义：标题、说明、弹性宽度、是否为自动计算列。
const _columns = <(String, String, int, bool)>[
  ('编号', '', 6, false),
  ('正反面', '命中时的投掷结果，点击切换；与上方硬币按钮同步。反面不应用最终硬币威力，但仍造成伤害并结算追伤', 5, false),
  ('呼吸法', '呼吸法强度（层，整数）。暴击部分 = MIN(层数 × 5% × 0.2, 0.2)，仅当前行', 8, false),
  ('一乘区', '单币第一乘区（自动）= ROUND(暴击部分 + 技能第一乘区 + 等级差修正, 2)', 7, true),
  ('二乘区', '单币第二乘区（小数倍率），仅当前行', 8, false),
  ('硬币威力', '单币硬币威力（整数）。累计计入当前行及之后的行，并计入拼点', 8, false),
  ('特殊威力', '终币特殊威力（整数）。累计计入当前行及之后的行，不计入拼点', 8, false),
  (
    '威力变化',
    '命中前 → 命中时的威力（自动）：正面加最终硬币威力，反面不加；再加本行单币硬币威力与终币特殊威力（手动修正，正反面都计入）',
    9,
    true,
  ),
  ('不计追伤', '不计算追伤伤害（自动）= MAX(1, INT(威力基数 × 乘区 × 容量))', 7, true),
  ('固定追伤', '固定追伤（整数），乘攻击容量后加入本行伤害', 8, false),
  ('比例追伤', '是否追伤：开启后追伤数值 = INT(不计算追伤伤害 × 追伤系数)', 7, false),
  ('追伤系数', '追伤系数（小数倍率，0.5 = 50%），仅当前行', 8, false),
  ('追伤数值', '比例追伤（自动）', 7, true),
  ('伤害数值', '伤害数值（自动）= INT(不计追伤 + 追伤数值 + 固定追伤 × 容量)', 7, true),
];

class _CoinTable extends StatelessWidget {
  const _CoinTable({required this.controller, required this.rows});

  final MirrorController controller;
  final List<int> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pad = context.cardPadding;
    final result = controller.result;

    Widget cells(List<Widget> children, {bool header = false}) => Padding(
      padding: EdgeInsets.symmetric(horizontal: pad - 6),
      child: Row(
        children: [
          for (final (i, (_, _, flex, auto)) in _columns.indexed)
            Expanded(
              flex: flex,
              child: Container(
                color: auto && !header ? palette.surfaceMuted : null,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                alignment: i == 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: children[i],
              ),
            ),
        ],
      ),
    );

    final header = context.textStyles.labelMedium;
    return Column(
      key: const ValueKey('mirror-coin-table'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            border: Border.symmetric(
              horizontal: BorderSide(color: palette.border),
            ),
          ),
          child: cells(header: true, [
            for (final (title, tip, _, _) in _columns)
              Tooltip(
                message: tip,
                child: Text(
                  title,
                  style: header,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ]),
        ),
        for (final (n, row) in rows.indexed) ...[
          if (row >= mirrorMainCoins &&
              (n == 0 || rows[n - 1] < mirrorMainCoins))
            Container(
              padding: EdgeInsets.fromLTRB(
                pad,
                AppSpacing.sm,
                pad,
                AppSpacing.xs,
              ),
              child: Text('重投', style: context.textStyles.labelMedium),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: cells(_rowCells(context, row, result?.rows[row])),
          ),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(pad, AppSpacing.sm, pad, 0),
          child: Text(
            '灰底列为自动计算；悬停表头可查看各列含义与公式。',
            style: context.textStyles.bodySmall,
          ),
        ),
      ],
    );
  }

  List<Widget> _rowCells(BuildContext context, int row, MirrorRow? r) {
    final c = controller;
    final body = numeric(context.textStyles.bodyMedium);
    Widget input(CoinField f) => _CoinInput(controller: c, row: row, field: f);
    Widget out(String text, {bool strong = false}) => Text(
      text,
      style: strong ? body.copyWith(fontWeight: FontWeight.w700) : body,
    );
    return [
      Text(_rowLabel(row), style: context.textStyles.titleSmall),
      _FaceToggle(controller: c, row: row),
      input(CoinField.breath),
      out(r == null ? '—' : mirrorFixed(r.f, 2)),
      input(CoinField.z2),
      input(CoinField.h),
      input(CoinField.i),
      out(r == null ? '—' : _powerChange(r)),
      out(mirrorNum(r?.j)),
      input(CoinField.fixed),
      Switch(
        key: ValueKey('mirror-extra-$row'),
        value: c.extra(row),
        onChanged: (v) => c.setExtra(row, v),
      ),
      input(CoinField.coef),
      out(r == null ? '—' : mirrorNum(r.nv)),
      out(mirrorNum(r?.o), strong: true),
    ];
  }
}

String _rowLabel(int row) =>
    row < mirrorMainCoins ? '硬币${row + 1}' : '重投${row - mirrorMainCoins + 1}';

String _powerChange(MirrorRow r) =>
    '${mirrorNum(r.powerBefore)} → ${mirrorNum(r.powerBase)}';

/// 表格 / 卡片中的正反面切换（与顶部硬币按钮读写同一份数据）。
class _FaceToggle extends StatelessWidget {
  const _FaceToggle({required this.controller, required this.row});

  final MirrorController controller;
  final int row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final face = controller.faceOf(row);
    final heads = face == MirrorFace.heads;
    return Semantics(
      button: true,
      label: '${_rowLabel(row)}：${face.label}面，点击切换',
      excludeSemantics: true,
      child: SizedBox(
        width: 40,
        height: 32,
        child: FocusableTile(
          inkKey: ValueKey('mirror-table-face-$row'),
          color: heads ? palette.primarySoft : palette.neutralSoft,
          borderColor: heads ? palette.primaryBorder : palette.border,
          radius: AppRadius.tag,
          onTap: () => controller.toggleFace(row),
          child: Center(
            child: Text(
              face.label,
              style: context.textStyles.titleSmall?.copyWith(
                color: heads ? palette.primary : palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinInput extends StatelessWidget {
  const _CoinInput({
    required this.controller,
    required this.row,
    required this.field,
    this.showErrorText = false,
  });

  final MirrorController controller;
  final int row;
  final CoinField field;
  final bool showErrorText;

  @override
  Widget build(BuildContext context) {
    return ShellTextField(
      fieldKey: ValueKey('mirror-coin-$row-${field.key}'),
      controller: controller.coinText(row, field),
      error: controller.errorOf(field.pathFor(row)),
      showErrorText: showErrorText,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      textAlign: TextAlign.end,
      hintText: '0',
      onFocusLost: () => controller.commitCoin(row, field),
    );
  }
}

class _CoinCards extends StatelessWidget {
  const _CoinCards({required this.controller, required this.rows});

  final MirrorController controller;
  final List<int> rows;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final palette = context.palette;
    final small = numeric(context.textStyles.bodySmall);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Container(
            key: ValueKey('mirror-coin-card-$row'),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: ShapeDecoration(
              color: palette.surfaceMuted,
              shape: smoothShape(
                AppRadius.control,
                side: BorderSide(color: palette.border),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(_rowLabel(row), style: context.textStyles.titleSmall),
                    const SizedBox(width: AppSpacing.sm),
                    _FaceToggle(controller: c, row: row),
                    const Spacer(),
                    Text(
                      '伤害 ${mirrorNum(c.result?.rows[row].o)}',
                      style: numeric(context.textStyles.titleSmall),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Builder(
                  builder: (context) {
                    final r = c.result?.rows[row];
                    return Text(
                      r == null
                          ? '输入有误，暂无计算值'
                          : '威力 ${_powerChange(r)} · 一乘区 ${mirrorFixed(r.f, 2)}'
                                ' · 不计追伤 ${mirrorNum(r.j)} · 追伤 ${mirrorNum(r.nv)}',
                      style: small,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                FieldGrid(
                  minItemWidth: 130,
                  maxColumns: 3,
                  children: [
                    for (final f in CoinField.values)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FieldLabel(f.label),
                          _CoinInput(
                            controller: c,
                            row: row,
                            field: f,
                            showErrorText: true,
                          ),
                        ],
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FieldLabel('比例追伤'),
                        SizedBox(
                          height: context.controlHeight,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Switch(
                              key: ValueKey('mirror-extra-$row'),
                              value: c.extra(row),
                              onChanged: (v) => c.setExtra(row, v),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
