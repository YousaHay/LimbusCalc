import 'calculation_input.dart';

/// 一枚硬币投掷前后的威力变化。
class CoinPowerStep {
  const CoinPowerStep({
    required this.index,
    required this.face,
    required this.powerBefore,
    required this.powerAfter,
  });

  /// 从 0 开始的硬币序号。
  final int index;
  final CoinFace face;

  /// 投掷本枚硬币前的累计威力。
  final int powerBefore;

  /// 投掷本枚硬币后的累计威力，也是本次命中使用的当前威力。
  final int powerAfter;

  int get hitPower => powerAfter;
}

/// 一次命中的直接伤害明细。
class CoinResult {
  const CoinResult({
    required this.step,
    required this.rawDamage,
    required this.minimumDamage,
    required this.finalDamage,
  });

  final CoinPowerStep step;

  /// 当前威力 × 静态乘区 × 动态乘区，未经保底与取整。
  final double rawDamage;

  /// 保底伤害：max(1, 当前威力 × 0.05)。
  final double minimumDamage;

  /// floor(max(原始伤害, 保底伤害))。
  final int finalDamage;

  /// 本次命中是否由保底值决定。
  bool get isMinimumApplied => minimumDamage > rawDamage;
}
