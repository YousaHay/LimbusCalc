/// 参数扫描（参考 SWEEP_DEF / SWEEP_LABEL / applySweep / runSweep 的计算部分）。
library;

import 'dart:math' as math;

import '../models/mirror_state.dart';
import 'js_numeric.dart';
import 'mirror_engine.dart';

/// 可扫描的参数及参考默认区间 [from, to, step]。
enum SweepParam {
  breath('breath', '呼吸法强度', 0, 20, 1),
  enemyLevel('enemyLevel', '敌方等级', 40, 50, 1),
  atkLevel('atkLevel', '攻击等级', 40, 50, 1),
  basePower('basePower', '基础威力', 0, 12, 1),
  coinPower('coinPower', '硬币威力', 0, 6, 1),
  baseBonus('baseBonus', '终础威力加成', 0, 10, 1),
  coinBonus('coinBonus', '硬币威力加成', 0, 6, 1),
  clashBonus('clashBonus', '拼点威力加成', 0, 6, 1),
  capacity('capacity', '攻击容量', 1, 4, 1),
  z1('z1', '技能第一乘区', 0, 0.5, 0.05),
  z2('z2', '技能第二乘区', 0, 0.5, 0.05),
  coinCount('coinCount', '硬币数量', 1, 9, 1);

  const SweepParam(this.key, this.label, this.from, this.to, this.step);
  final String key;
  final String label;
  final double from;
  final double to;
  final double step;

  /// 对应的全局字段；呼吸法为逐行字段，返回 null。
  MirrorField? get field => switch (this) {
    SweepParam.breath => null,
    _ => MirrorField.values.firstWhere((f) => f.path == key),
  };
}

/// 参考 runSweep 的点数上限。
const int maxSweepPoints = 200;

/// 参考 `applySweep(t, key, v)`。呼吸法写入全部 18 行（未启用行随后会被 normalize 清零）。
///
/// [coinPowerSign] 为高级计算的加减算符号（+1 / −1）：扫描“硬币威力”时，
/// 扫描值视为数值部分并带上该符号；默认 +1 即参考行为。
MirrorState applySweep(
  MirrorState t,
  SweepParam key,
  double v, {
  double coinPowerSign = 1,
}) {
  switch (key) {
    case SweepParam.breath:
      return t.copyWith(
        coins: [for (final c in t.coins) c.withValue(CoinField.breath, v)],
      );
    case SweepParam.coinCount:
      return t.withValue(
        MirrorField.coinCount,
        math.max(0.0, math.min(9.0, jsRound(v))),
      );
    case SweepParam.coinPower:
      return t.withValue(MirrorField.coinPower, coinPowerSign * v);
    default:
      return t.withValue(key.field!, v);
  }
}

/// 扫描区间校验结果。
sealed class SweepPlan {
  const SweepPlan();
}

final class SweepPlanError extends SweepPlan {
  const SweepPlanError(this.message);

  /// 与参考 toast 文案一致。
  final String message;
}

final class SweepPlanOk extends SweepPlan {
  const SweepPlanOk({
    required this.from,
    required this.to,
    required this.step,
    required this.count,
  });

  /// 交换后的起止值（参考：from > to 时交换）。
  final double from;
  final double to;
  final double step;
  final int count;

  /// 第 i 个取值，与参考 `from + step * i` 的浮点运算一致。
  double valueAt(int i) => from + step * i;
}

/// 参考 runSweep 的参数校验与点数计算。
SweepPlan planSweep(double from, double to, double step) {
  if (!(step > 0)) return const SweepPlanError('步长必须大于 0');
  if (from > to) {
    final tmp = from;
    from = to;
    to = tmp;
  }
  // 用 floorToDouble：极端区间下点数可能超出 int 范围或为 Infinity，不能直接转 int。
  final n = ((to - from) / step + 1e-9).floorToDouble() + 1;
  if (n > maxSweepPoints) {
    return SweepPlanError('点太多（${_jsCount(n)} 个），请把步长调大一些');
  }
  if (n < 2) return const SweepPlanError('区间内至少要有 2 个取值');
  return SweepPlanOk(from: from, to: to, step: step, count: n.toInt());
}

/// 按 JavaScript String(number) 的方式显示点数（整数，或 Infinity）。
String _jsCount(double n) {
  if (n.isInfinite) return 'Infinity';
  return n < 1e21 ? n.toStringAsFixed(0) : n.toString();
}

class SweepPoint {
  const SweepPoint({
    required this.value,
    required this.total,
    required this.clash,
  });

  final double value;
  final double total;
  final double clash;
}

/// 单个扫描点：从同一基准状态独立推导（参考：JSON 深拷贝 → applySweep → normalize → compute）。
SweepPoint computeSweepPoint(
  MirrorState base,
  SweepParam key,
  double v, {
  double coinPowerSign = 1,
}) {
  final r = computeMirror(
    normalize(applySweep(base, key, v, coinPowerSign: coinPowerSign)),
  );
  return SweepPoint(value: v, total: r.total, clash: r.clash);
}

/// 扫描基准：未启用行（参考 normalize 已清空其修正）的正反面统一按正面，
/// 使“扫描硬币数量 / 重投次数”时新增的位置有明确的默认值：正面、无逐币修正。
MirrorState sweepBaseState(MirrorState s) => s.copyWith(
  faces: [
    for (var i = 0; i < mirrorCoinRows; i++)
      isRowActive(s, i) ? s.faces[i] : MirrorFace.heads,
  ],
);

/// 同步执行完整扫描（测试与小规模调用使用）。界面中由控制器分批调用 [computeSweepPoint]。
List<SweepPoint> runSweepSync(
  MirrorState base,
  SweepParam key,
  SweepPlanOk plan,
) => [
  for (var i = 0; i < plan.count; i++)
    computeSweepPoint(base, key, plan.valueAt(i)),
];
