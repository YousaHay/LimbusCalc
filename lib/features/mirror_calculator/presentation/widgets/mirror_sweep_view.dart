import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../../calculator/presentation/widgets/number_field.dart';
import '../../../calculator/presentation/widgets/section_card.dart';
import '../../../calculator/presentation/widgets/status_widgets.dart';
import '../../domain/mirror_engine.dart';
import '../../domain/mirror_sweep.dart';
import '../../models/mirror_state.dart';
import '../mirror_controller.dart';
import '../mirror_format.dart';
import '../sweep_controller.dart';

/// 参数扫描：选择参数与区间，逐点重算总伤害与拼点。
class MirrorSweepView extends StatelessWidget {
  const MirrorSweepView({
    super.key,
    required this.controller,
    required this.sweep,
  });

  final MirrorController controller;
  final SweepController sweep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ControlsCard(controller: controller, sweep: sweep),
        const SizedBox(height: AppSpacing.section),
        _ResultCard(controller: controller, sweep: sweep),
      ],
    );
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard({required this.controller, required this.sweep});

  final MirrorController controller;
  final SweepController sweep;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final styles = context.textStyles;
    final plan = sweep.plan;
    // 扫描基准：隐藏位置按正面、无逐币修正（扫描硬币数量时新增位置的默认规则）。
    final base = controller.sweepBase;
    final canRun = plan is SweepPlanOk && base != null && !sweep.running;

    Widget range(String key, String label, TextEditingController ctrl) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FieldLabel(label),
            ShellTextField(
              fieldKey: ValueKey('mirror-sweep-$key'),
              controller: ctrl,
              error: sweep.inputError(key),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
          ],
        );

    final status = switch (plan) {
      null => ('请检查区间输入', palette.error),
      SweepPlanError(:final message) => (message, palette.error),
      SweepPlanOk(:final count) => ('将计算 $count 个点', palette.textSecondary),
    };

    return SectionCard(
      title: '参数扫描',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final paramField = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FieldLabel('扫描参数'),
                  _SweepParamPicker(
                    value: sweep.param,
                    onChanged: sweep.setParam,
                  ),
                ],
              );
              final fields = [
                paramField,
                range('from', '起始值', sweep.fromText),
                range('to', '结束值', sweep.toText),
                range('step', '步长', sweep.stepText),
              ];
              final wide = constraints.maxWidth >= 640;
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final (i, f) in fields.indexed) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.md),
                          Expanded(flex: i == 0 ? 2 : 1, child: f),
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, f) in fields.indexed) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.md),
                          f,
                        ],
                      ],
                    );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            status.$1,
            key: const ValueKey('mirror-sweep-status'),
            style: styles.bodySmall?.copyWith(color: status.$2),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                key: const ValueKey('mirror-sweep-run'),
                onPressed: canRun
                    ? () => sweep.start(
                        base,
                        coinPowerSign: controller.coinPowerSign,
                      )
                    : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('开始扫描'),
              ),
              if (sweep.running)
                OutlinedButton.icon(
                  key: const ValueKey('mirror-sweep-cancel'),
                  onPressed: sweep.cancel,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('取消'),
                ),
              TextButton(
                key: const ValueKey('mirror-sweep-defaults'),
                onPressed: sweep.resetRange,
                child: const Text('恢复默认区间'),
              ),
            ],
          ),
          if (base == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '当前技能输入有误，修正后才能扫描。',
              style: styles.bodySmall?.copyWith(color: palette.error),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            '每个取值都从开始扫描时的参数快照独立重算，不会修改正在编辑的参数。'
            '“呼吸法强度”作用于全部启用的硬币与重投行；“硬币数量”按四舍五入取整并限制在 0～9；'
            '其余参数按输入原值代入（与参考实现一致，不额外取整）。最多 $maxSweepPoints 个点。',
            style: styles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.controller, required this.sweep});

  final MirrorController controller;
  final SweepController sweep;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    final points = sweep.points;
    final param = sweep.resultParam;
    final snapshot = sweep.snapshot;
    if (param == null || snapshot == null) {
      return SectionCard(
        title: '扫描结果',
        child: Text('尚未扫描。', style: styles.bodySmall),
      );
    }
    final stale = sweep.isStaleFor(
      controller.sweepBase,
      coinPowerSign: controller.coinPowerSign,
    );
    final label = param == SweepParam.coinPower
        ? '${param.label}（${sweep.snapshotSign < 0 ? '减算' : '加算'}）'
        : param.label;
    final total = sweep.resultPlan?.count ?? points.length;
    var maxI = 0;
    for (var i = 1; i < points.length; i++) {
      if (points[i].total > points[maxI].total) maxI = i;
    }

    return SectionCard(
      title: '扫描结果 · $label',
      trailing: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: Text(
          '${points.length} / $total 点',
          key: const ValueKey('mirror-sweep-progress'),
          style: numeric(styles.bodySmall),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stale) ...[
            const StatusNotice(
              key: ValueKey('mirror-sweep-stale'),
              tone: NoticeTone.warning,
              title: '结果已过期',
              lines: ['当前参数已在扫描后修改，以下结果仍基于下方快照。重新扫描以获取最新结果。'],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (sweep.running)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: LinearProgressIndicator(
                value: total == 0 ? null : points.length / total,
              ),
            )
          else if (!sweep.complete)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                '扫描已取消，只显示已计算的 ${points.length} 个点。',
                style: styles.bodySmall,
              ),
            ),
          Text(
            '快照：${_snapshotText(snapshot, param, sweep.snapshotSign)}',
            key: const ValueKey('mirror-sweep-snapshot'),
            style: styles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (points.length >= 2) ...[
            SizedBox(
              height: 220,
              child: CustomPaint(
                key: const ValueKey('mirror-sweep-chart'),
                painter: _SweepChartPainter(
                  points: points,
                  maxIndex: maxI,
                  palette: context.palette,
                  labelStyle: numeric(styles.bodySmall),
                ),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('蓝线：总伤害　灰线：拼点点数　圆圈：区间内总伤害最高点', style: styles.bodySmall),
            Text(
              '扫描区间内总伤害最高：$label = ${mirrorNum(points[maxI].value)}，'
              '总伤害 ${mirrorNum(points[maxI].total)}'
              '（仅为本快照下的计算结果，不代表实战最优）。',
              style: styles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _SweepTable(points: points, label: label, maxIndex: maxI),
        ],
      ),
    );
  }

  static String _snapshotText(MirrorState s, SweepParam p, double sign) {
    final n = mirrorNum;
    String faces(bool reroll) => [
      for (var i = 0; i < mirrorCoinRows; i++)
        if ((i >= mirrorMainCoins) == reroll && isRowActive(s, i))
          s.faces[i].label,
    ].join('');
    final coinFaces = faces(false);
    final rerollFaces = faces(true);
    final parts = [
      '硬币 ${n(s[MirrorField.coinCount])} 枚',
      if (s.flag(MirrorFlag.reroll)) '重投 ${n(s[MirrorField.rerollCount])} 次',
      '基础威力 ${n(s[MirrorField.basePower])}',
      '硬币威力 ${sign < 0 ? '减算' : '加算'} ${n(s[MirrorField.coinPower].abs())}',
      '正反面 ${coinFaces.isEmpty ? '—' : coinFaces}'
          '${rerollFaces.isEmpty ? '' : ' / 重投 $rerollFaces'}',
      '攻击等级 ${n(s[MirrorField.atkLevel])} / 敌方 ${n(s[MirrorField.enemyLevel])}',
      '容量 ${n(s[MirrorField.capacity])}',
      'z1 ${n(s[MirrorField.z1])} · z2 ${n(s[MirrorField.z2])}',
      if (s.flag(MirrorFlag.crit)) '必定暴击',
      if (s.flag(MirrorFlag.counter)) '反击',
    ];
    final plan = s.planName.trim();
    return '${plan.isEmpty ? '' : '$plan · '}${parts.join(' · ')}'
        '（扫描“${p.label}”时其余参数与正反面保持不变；扫描硬币数量时新增位置按正面、无逐币修正）';
  }
}

class _SweepTable extends StatelessWidget {
  const _SweepTable({
    required this.points,
    required this.label,
    required this.maxIndex,
  });

  final List<SweepPoint> points;
  final String label;
  final int maxIndex;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final header = context.textStyles.labelMedium;
    final body = numeric(context.textStyles.bodyMedium);
    Widget row(List<Widget> cells, {Color? color, Key? key}) => Container(
      key: key,
      color: color,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: [
          for (final (i, c) in cells.indexed)
            Expanded(
              child: Align(
                alignment: i == 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: c,
              ),
            ),
        ],
      ),
    );

    return Container(
      key: const ValueKey('mirror-sweep-table'),
      decoration: ShapeDecoration(
        shape: smoothShape(
          AppRadius.control,
          side: BorderSide(color: palette.border),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row([
            Text(label, style: header),
            Text('总伤害', style: header),
            Text('拼点', style: header),
            Text('变化', style: header),
          ], color: palette.surfaceMuted),
          for (final (i, p) in points.indexed)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: palette.border)),
              ),
              child: row(
                [
                  Text(mirrorNum(p.value), style: body),
                  Text(
                    mirrorNum(p.total),
                    style: i == maxIndex
                        ? body.copyWith(fontWeight: FontWeight.w700)
                        : body,
                  ),
                  Text(mirrorNum(p.clash), style: body),
                  Text(
                    i == 0
                        ? '—'
                        : p.total == points[i - 1].total
                        ? '持平'
                        : p.total > points[i - 1].total
                        ? '↑'
                        : '↓',
                    style: body,
                  ),
                ],
                color: i == maxIndex ? palette.primarySoft : null,
                key: ValueKey('mirror-sweep-row-$i'),
              ),
            ),
        ],
      ),
    );
  }
}

/// 总伤害折线（主色）与拼点折线（灰色），标出区间内总伤害最高点。
class _SweepChartPainter extends CustomPainter {
  _SweepChartPainter({
    required this.points,
    required this.maxIndex,
    required this.palette,
    required this.labelStyle,
  });

  final List<SweepPoint> points;
  final int maxIndex;
  final AppPalette palette;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 48.0, right = 12.0, top = 12.0, bottom = 28.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;

    final xs = points.map((p) => p.value);
    final ys = points.expand((p) => [p.total, p.clash]);
    final x0 = xs.reduce(math.min), x1 = xs.reduce(math.max);
    var y0 = math.min(0.0, ys.reduce(math.min)), y1 = ys.reduce(math.max);
    if (y1 == y0) y1 = y0 + 1;
    final dx = x1 == x0 ? 1.0 : x1 - x0;
    Offset at(double x, double y) =>
        Offset(left + (x - x0) / dx * w, top + (1 - (y - y0) / (y1 - y0)) * h);

    final grid = Paint()
      ..color = palette.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + h * i / 4;
      canvas.drawLine(Offset(left, y), Offset(left + w, y), grid);
      _label(
        canvas,
        mirrorNum(y1 - (y1 - y0) * i / 4, digits: 1),
        Offset(left - 6, y),
        alignRight: true,
      );
    }
    _label(canvas, mirrorNum(x0), Offset(left, top + h + 6));
    _label(
      canvas,
      mirrorNum(x1),
      Offset(left + w, top + h + 6),
      alignRight: true,
    );

    void line(double Function(SweepPoint) y, Color color, double width) {
      final path = Path();
      for (final (i, p) in points.indexed) {
        final o = at(p.value, y(p));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round,
      );
    }

    line((p) => p.clash, palette.borderStrong, 1.5);
    line((p) => p.total, palette.primary, 2);
    final dot = Paint()..color = palette.primary;
    for (final p in points) {
      canvas.drawCircle(at(p.value, p.total), 2.2, dot);
    }
    final best = at(points[maxIndex].value, points[maxIndex].total);
    canvas.drawCircle(best, 5, Paint()..color = palette.surface);
    canvas.drawCircle(
      best,
      5,
      Paint()
        ..color = palette.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    bool alignRight = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? at.dx - tp.width : at.dx;
    tp.paint(canvas, Offset(dx, at.dy - (alignRight ? tp.height / 2 : 0)));
  }

  @override
  bool shouldRepaint(_SweepChartPainter old) =>
      old.points != points || old.maxIndex != maxIndex;
}

/// 扫描参数选择：输入框样式的触发器 + 从其下方展开的菜单。
///
/// 菜单使用 SDK 的展开动画（高度按非线性曲线展开），系统开启“减少动画”时直接显示；
/// 宽度与触发器一致，连续曲线圆角，选中项以主题色标出。
class _SweepParamPicker extends StatelessWidget {
  const _SweepParamPicker({required this.value, required this.onChanged});

  final SweepParam value;
  final ValueChanged<SweepParam> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final styles = context.textStyles;
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        animated: !MediaQuery.disableAnimationsOf(context),
        alignmentOffset: const Offset(0, AppSpacing.xs),
        crossAxisUnconstrained: false,
        style: MenuStyle(
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 420)),
        ),
        menuChildren: [
          for (final p in SweepParam.values)
            MenuItemButton(
              key: ValueKey('mirror-sweep-option-${p.name}'),
              onPressed: () => onChanged(p),
              style: p == value
                  ? MenuItemButton.styleFrom(
                      backgroundColor: palette.primarySoft,
                      foregroundColor: palette.primary,
                      iconColor: palette.primary,
                    )
                  : null,
              trailingIcon: p == value
                  ? const Icon(Icons.check, size: 18)
                  : null,
              child: Text(p.label),
            ),
        ],
        builder: (context, controller, _) => Material(
          color: palette.surface,
          shape: smoothShape(
            AppRadius.control,
            side: BorderSide(
              color: controller.isOpen ? palette.primary : palette.border,
              width: controller.isOpen ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            key: const ValueKey('mirror-sweep-param'),
            customBorder: smoothShape(AppRadius.control),
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: SizedBox(
              height: context.controlHeight,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.bodyMedium,
                      ),
                    ),
                    AnimatedRotation(
                      turns: controller.isOpen ? 0.5 : 0,
                      duration: AppMotion.expandDuration(context),
                      curve: AppMotion.expandCurve,
                      child: Icon(
                        Icons.expand_more,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
