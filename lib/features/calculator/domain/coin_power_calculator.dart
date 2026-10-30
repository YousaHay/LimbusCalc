import '../models/calculation_input.dart';
import '../models/coin_result.dart';

/// 根据基础威力与正反面序列，生成每次命中的当前威力。
///
/// 普通硬币：正面应用带符号的硬币威力，反面不变；累计变化影响后续命中。
/// 本函数不对威力做任何上下限处理，边界判断见 [hasUnconfirmedBoundary]。
List<CoinPowerStep> calculateCoinPowers({
  required int basePower,
  required int coinPowerDelta,
  required List<CoinFace> faces,
}) {
  final steps = <CoinPowerStep>[];
  var current = basePower;
  for (var i = 0; i < faces.length; i++) {
    final before = current;
    if (faces[i] == CoinFace.heads) {
      current += coinPowerDelta;
    }
    steps.add(
      CoinPowerStep(
        index: i,
        face: faces[i],
        powerBefore: before,
        powerAfter: current,
      ),
    );
  }
  return steps;
}

/// 威力是否进入了尚未确认游戏行为的区间。
///
/// 现有资料不足以确定：威力降至 0 或负数时是否被钳制、钳制是否影响后续累计、
/// 0 威力命中是否仍按保底造成 1 点伤害。因此基础威力或任一命中威力 ≤ 0 时，
/// 整个技能不输出确定伤害。
bool hasUnconfirmedBoundary(int basePower, List<CoinPowerStep> steps) {
  if (basePower <= 0) return true;
  return steps.any((step) => step.hitPower <= 0);
}
