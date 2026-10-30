import 'calculation_input.dart';
import 'coin_result.dart';

/// 整个技能共用的伤害乘区明细。
class DamageFactors {
  const DamageFactors({
    required this.sinResistanceBonus,
    required this.physicalResistanceBonus,
    required this.levelDifference,
    required this.levelBonus,
    required this.clashBonus,
    required this.criticalBonus,
    required this.staticSum,
    required this.staticFactor,
    required this.dynamicFactor,
  });

  /// A：罪孽抗性修正。
  final double sinResistanceBonus;

  /// B：物理抗性修正。
  final double physicalResistanceBonus;

  /// d = 攻击等级 − 防御等级。
  final int levelDifference;

  /// C = d / (|d| + 25)，不截断。
  final double levelBonus;

  final double clashBonus;
  final double criticalBonus;

  /// 1 + A + B + C + 拼点 + 暴击，未经 max(…, 0)。
  final double staticSum;

  /// max(staticSum, 0)。
  final double staticFactor;

  /// 1 + 进攻方动态修正 + 受击方动态修正。
  final double dynamicFactor;
}

enum CalculationStatus {
  /// 所有命中均已得到确定伤害。
  ok,

  /// 威力降至 0 或负数，游戏如何处理尚未确认，不输出伤害。
  unconfirmedPowerBoundary,
}

class CalculationResult {
  const CalculationResult({
    required this.input,
    required this.status,
    required this.powerSteps,
    required this.factors,
    required this.coins,
    required this.totalDamage,
  });

  final CalculationInput input;
  final CalculationStatus status;

  /// 每枚硬币的威力变化，任何状态下都会给出。
  final List<CoinPowerStep> powerSteps;

  final DamageFactors factors;

  /// 逐枚命中伤害；状态非 [CalculationStatus.ok] 时为空。
  final List<CoinResult> coins;

  /// 技能直接伤害合计；状态非 [CalculationStatus.ok] 时为 null。
  final int? totalDamage;

  bool get isOk => status == CalculationStatus.ok;
}
