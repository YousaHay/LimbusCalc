import 'package:flutter/widgets.dart';

import '../domain/damage_calculator.dart';
import '../models/calculation_input.dart';
import '../models/calculation_result.dart';
import 'input_parsing.dart';

/// 产品层面的硬币数量限制（非游戏机制）。
const int minCoinCount = 1;
const int maxCoinCount = 10;

enum CalculatorField {
  basePower('基础威力'),
  coinCount('硬币数量'),
  coinPower('硬币威力'),
  offenseLevel('最终攻击等级'),
  defenseLevel('目标防御等级'),
  physicalResistance('有效物理抗性倍率'),
  sinResistance('有效罪孽抗性倍率'),
  clashCount('拼点轮数'),
  attackerDynamic('进攻方动态增减伤'),
  defenderDynamic('受击方动态增减伤');

  const CalculatorField(this.label);
  final String label;
}

enum CoinPowerSign { add, subtract }

enum FaceMode { allHeads, allTails, custom }

/// 计算器页面状态：持有原始文本输入，校验通过后即时计算。
///
/// 只负责输入整理与调用计算，不包含任何伤害公式。
class CalculatorController extends ChangeNotifier {
  CalculatorController() {
    for (final field in CalculatorField.values) {
      final controller = TextEditingController(text: _defaultTexts[field]);
      controller.addListener(_recalculate);
      _texts[field] = controller;
    }
    _recalculate();
  }

  static const Map<CalculatorField, String> _defaultTexts = {
    CalculatorField.basePower: '4',
    CalculatorField.coinCount: '3',
    CalculatorField.coinPower: '3',
    CalculatorField.offenseLevel: '40',
    CalculatorField.defenseLevel: '40',
    CalculatorField.physicalResistance: '1.0',
    CalculatorField.sinResistance: '1.0',
    CalculatorField.clashCount: '0',
    CalculatorField.attackerDynamic: '0',
    CalculatorField.defenderDynamic: '0',
  };

  final Map<CalculatorField, TextEditingController> _texts = {};

  CoinPowerSign _coinPowerSign = CoinPowerSign.add;
  FaceMode _faceMode = FaceMode.allHeads;
  bool _isCritical = false;

  /// 自定义正反面按最大硬币数保存，修改数量时只截取前 n 枚，
  /// 因此已有选择不会因为输入过程中的临时数量而丢失。
  final List<CoinFace> _customFaces = List.filled(maxCoinCount, CoinFace.heads);

  int _displayCoinCount = 3;
  Map<CalculatorField, String> _errors = const {};
  CalculationResult? _result;

  TextEditingController textOf(CalculatorField field) => _texts[field]!;
  CoinPowerSign get coinPowerSign => _coinPowerSign;
  FaceMode get faceMode => _faceMode;
  bool get isCritical => _isCritical;

  /// 用于展示硬币开关的数量；数量输入非法时沿用最近一次合法值。
  int get displayCoinCount => _displayCoinCount;

  Map<CalculatorField, String> get errors => _errors;
  String? errorOf(CalculatorField field) => _errors[field];

  /// 当前有效结果；存在输入错误时为 null，绝不保留旧结果。
  CalculationResult? get result => _result;

  List<CoinFace> get displayFaces => _facesFor(_displayCoinCount);

  void setCoinPowerSign(CoinPowerSign sign) {
    if (_coinPowerSign == sign) return;
    _coinPowerSign = sign;
    _recalculate();
  }

  void setFaceMode(FaceMode mode) {
    if (_faceMode == mode) return;
    _faceMode = mode;
    _recalculate();
  }

  void setCritical(bool value) {
    if (_isCritical == value) return;
    _isCritical = value;
    _recalculate();
  }

  /// 切换第 [index] 枚硬币。若当前为“全部正面/反面”，先以当前序列进入自定义。
  void toggleFace(int index) {
    if (_faceMode != FaceMode.custom) {
      final face = _faceMode == FaceMode.allHeads
          ? CoinFace.heads
          : CoinFace.tails;
      _customFaces.fillRange(0, maxCoinCount, face);
      _faceMode = FaceMode.custom;
    }
    _customFaces[index] = _customFaces[index] == CoinFace.heads
        ? CoinFace.tails
        : CoinFace.heads;
    _recalculate();
  }

  void changeCoinCountBy(int delta) {
    final next = (_displayCoinCount + delta).clamp(minCoinCount, maxCoinCount);
    textOf(CalculatorField.coinCount).text = '$next';
  }

  void reset() {
    _coinPowerSign = CoinPowerSign.add;
    _faceMode = FaceMode.allHeads;
    _isCritical = false;
    _customFaces.fillRange(0, maxCoinCount, CoinFace.heads);
    for (final entry in _texts.entries) {
      // 逐个赋值会触发多次重算，结果一致，开销可忽略。
      entry.value.text = _defaultTexts[entry.key]!;
    }
    _recalculate();
  }

  List<CoinFace> _facesFor(int count) {
    return switch (_faceMode) {
      FaceMode.allHeads => List.filled(count, CoinFace.heads),
      FaceMode.allTails => List.filled(count, CoinFace.tails),
      FaceMode.custom => _customFaces.sublist(0, count),
    };
  }

  void _recalculate() {
    final errors = <CalculatorField, String>{};

    int? readInt(CalculatorField field, int min, int max) {
      final parsed = parseIntInRange(textOf(field).text, min: min, max: max);
      if (!parsed.isValid) errors[field] = parsed.error!;
      return parsed.value;
    }

    double? readDecimal(CalculatorField field, double min, double max) {
      final parsed = parseDecimalInRange(
        textOf(field).text,
        min: min,
        max: max,
      );
      if (!parsed.isValid) errors[field] = parsed.error!;
      return parsed.value;
    }

    final basePower = readInt(CalculatorField.basePower, -999, 999);
    final coinCount = readInt(
      CalculatorField.coinCount,
      minCoinCount,
      maxCoinCount,
    );
    final coinPower = readInt(CalculatorField.coinPower, 0, 999);
    if (errors.containsKey(CalculatorField.coinPower) &&
        RegExp(r'^-\d+$')
            .hasMatch(textOf(CalculatorField.coinPower).text.trim())) {
      errors[CalculatorField.coinPower] = '负值请改用“减算”';
    }
    final offense = readInt(CalculatorField.offenseLevel, 0, 999);
    final defense = readInt(CalculatorField.defenseLevel, 0, 999);
    final physical = readDecimal(CalculatorField.physicalResistance, -10, 10);
    final sin = readDecimal(CalculatorField.sinResistance, -10, 10);
    final clash = readInt(CalculatorField.clashCount, 0, 99);
    final attacker = readDecimal(CalculatorField.attackerDynamic, -1000, 1000);
    final defender = readDecimal(CalculatorField.defenderDynamic, -1000, 1000);

    if (coinCount != null) _displayCoinCount = coinCount;
    _errors = Map.unmodifiable(errors);

    if (errors.isEmpty) {
      final input = CalculationInput(
        basePower: basePower!,
        coinPowerDelta: _coinPowerSign == CoinPowerSign.add
            ? coinPower!
            : -coinPower!,
        coinFaces: _facesFor(coinCount!),
        offenseLevel: offense!,
        defenseLevel: defense!,
        physicalResistance: physical!,
        sinResistance: sin!,
        clashCount: clash!,
        isCritical: _isCritical,
        attackerDynamicBonus: attacker! / 100,
        defenderDynamicBonus: defender! / 100,
      );
      _result = calculateSkillDamage(input);
    } else {
      _result = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final controller in _texts.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
