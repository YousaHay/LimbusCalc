import 'dart:math' as math;

import '../models/calculation_input.dart';
import '../models/calculation_result.dart';
import '../models/coin_result.dart';
import 'coin_power_calculator.dart';

/// 每轮拼点提供的静态加成。
const double clashBonusPerRound = 0.03;

/// 暴击基础加成（进入静态乘区）。
const double criticalBaseBonus = 0.2;

/// 保底伤害占当前威力的比例。
const double minimumDamagePowerRatio = 0.05;

/// 抗性修正：倍率 r 对应的静态乘区加成。
double resistanceBonus(double r) {
  if (r <= 0) return -0.5;
  if (r < 1) return (r - 1) / 2;
  return r - 1;
}

/// 攻防等级修正 C = d / (|d| + 25)。
///
/// 本版保留完整精度，不截断至两位小数（见 docs/calculation_rules.md）。
double levelBonus(int levelDifference) {
  return levelDifference / (levelDifference.abs() + 25);
}

DamageFactors calculateFactors(CalculationInput input) {
  final a = resistanceBonus(input.sinResistance);
  final b = resistanceBonus(input.physicalResistance);
  final d = input.offenseLevel - input.defenseLevel;
  final c = levelBonus(d);
  final clash = input.clashCount * clashBonusPerRound;
  final critical = input.isCritical ? criticalBaseBonus : 0.0;
  final staticSum = 1 + a + b + c + clash + critical;
  return DamageFactors(
    sinResistanceBonus: a,
    physicalResistanceBonus: b,
    levelDifference: d,
    levelBonus: c,
    clashBonus: clash,
    criticalBonus: critical,
    staticSum: staticSum,
    staticFactor: math.max(staticSum, 0),
    dynamicFactor: 1 + input.attackerDynamicBonus + input.defenderDynamicBonus,
  );
}

/// 计算单次命中：先求原始伤害，再与保底比较，最后向下取整。
CoinResult calculateHit(CoinPowerStep step, DamageFactors factors) {
  final power = step.hitPower;
  final raw = power * factors.staticFactor * factors.dynamicFactor;
  final minimum = math.max(1.0, power * minimumDamagePowerRatio);
  return CoinResult(
    step: step,
    rawDamage: raw,
    minimumDamage: minimum,
    finalDamage: math.max(raw, minimum).floor(),
  );
}

/// 计算整个技能的直接伤害：每次命中独立取整后求和。
CalculationResult calculateSkillDamage(CalculationInput input) {
  final steps = calculateCoinPowers(
    basePower: input.basePower,
    coinPowerDelta: input.coinPowerDelta,
    faces: input.coinFaces,
  );
  final factors = calculateFactors(input);

  if (hasUnconfirmedBoundary(input.basePower, steps)) {
    return CalculationResult(
      input: input,
      status: CalculationStatus.unconfirmedPowerBoundary,
      powerSteps: steps,
      factors: factors,
      coins: const [],
      totalDamage: null,
    );
  }

  final coins = [for (final step in steps) calculateHit(step, factors)];
  return CalculationResult(
    input: input,
    status: CalculationStatus.ok,
    powerSteps: steps,
    factors: factors,
    coins: coins,
    totalDamage: coins.fold<int>(0, (sum, coin) => sum + coin.finalDamage),
  );
}
