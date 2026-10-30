/// 硬币投掷结果。
enum CoinFace {
  heads,
  tails;

  String get label => this == heads ? '正' : '反';
}

/// 一次技能伤害计算所需的全部输入。
///
/// 只描述“已经确定的数值”，不包含任何来源（人格、饰品、状态）的解析。
/// 后续模块可以生成本对象，再交给 [DamageCalculator] 计算。
class CalculationInput {
  CalculationInput({
    required this.basePower,
    required this.coinPowerDelta,
    required List<CoinFace> coinFaces,
    this.offenseLevel = 40,
    this.defenseLevel = 40,
    this.physicalResistance = 1.0,
    this.sinResistance = 1.0,
    this.clashCount = 0,
    this.isCritical = false,
    this.attackerDynamicBonus = 0.0,
    this.defenderDynamicBonus = 0.0,
  }) : coinFaces = List.unmodifiable(coinFaces) {
    if (coinFaces.isEmpty) {
      throw ArgumentError.value(coinFaces, 'coinFaces', '至少需要 1 枚硬币');
    }
    if (clashCount < 0) {
      throw ArgumentError.value(clashCount, 'clashCount', '拼点轮数不能为负数');
    }
    _requireFinite(physicalResistance, 'physicalResistance');
    _requireFinite(sinResistance, 'sinResistance');
    _requireFinite(attackerDynamicBonus, 'attackerDynamicBonus');
    _requireFinite(defenderDynamicBonus, 'defenderDynamicBonus');
  }

  /// 技能基础威力。
  final int basePower;

  /// 硬币威力（带符号）：加算为正，减算为负。
  final int coinPowerDelta;

  /// 按投掷顺序排列的正反面结果，长度即硬币数量。
  final List<CoinFace> coinFaces;

  /// 已计入外部修正后的技能攻击等级。
  final int offenseLevel;

  /// 目标防御等级。
  final int defenseLevel;

  /// 本次攻击实际使用的物理（伤害类型）抗性倍率。
  final double physicalResistance;

  /// 本次攻击实际使用的罪孽抗性倍率。
  final double sinResistance;

  /// 拼点轮数；0 表示未经拼点的单方面攻击。
  final int clashCount;

  /// 是否暴击；第一版统一应用于所有命中。
  final bool isCritical;

  /// 进攻方动态增减伤，以小数表示（+10% 即 0.1）。
  final double attackerDynamicBonus;

  /// 受击方动态增减伤，以小数表示（+10% 即 0.1）。
  final double defenderDynamicBonus;

  int get coinCount => coinFaces.length;

  static void _requireFinite(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, '必须是有限数值');
    }
  }
}
