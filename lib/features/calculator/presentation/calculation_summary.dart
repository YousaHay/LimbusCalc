import '../models/calculation_input.dart';
import '../models/calculation_result.dart';

/// 当前计算范围说明，结果区与复制摘要共用。
const String calculationScopeNote =
    '仅计算普通硬币在指定正反面下的直接伤害；不含追加伤害、状态伤害、被动与状态效果自动解析，'
    '不模拟拼点过程与命中后的状态变化。';

/// 仅用于显示的数值格式：最多保留 [digits] 位小数并去掉末尾 0。
/// 不参与也不回写任何计算。
String formatNumber(double value, {int digits = 4}) {
  var text = value.toStringAsFixed(digits);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return text == '-0' ? '0' : text;
}

String formatSigned(num value) {
  final text = value is int ? '$value' : formatNumber(value.toDouble());
  return value > 0 ? '+$text' : text;
}

String formatPercent(double fraction) => '${formatSigned(fraction * 100)}%';

String formatFaces(List<CoinFace> faces) => faces.map((f) => f.label).join(' ');

String buildCalculationSummary(CalculationResult result) {
  final input = result.input;
  final factors = result.factors;
  final buffer = StringBuffer()
    ..writeln('【边狱巴士 直接伤害计算 · 摘要】')
    ..writeln(
      '技能：基础威力 ${input.basePower}，硬币 ${input.coinCount} 枚，'
      '硬币威力 ${formatSigned(input.coinPowerDelta)}',
    )
    ..writeln('正反面：${formatFaces(input.coinFaces)}')
    ..writeln(
      '修正：攻击等级 ${input.offenseLevel} / 防御等级 ${input.defenseLevel}，'
      '物理抗性 ×${formatNumber(input.physicalResistance)}，'
      '罪孽抗性 ×${formatNumber(input.sinResistance)}，'
      '拼点 ${input.clashCount} 轮，暴击 ${input.isCritical ? '开' : '关'}，'
      '动态增减伤 进攻方 ${formatPercent(input.attackerDynamicBonus)} / '
      '受击方 ${formatPercent(input.defenderDynamicBonus)}',
    )
    ..writeln(
      '静态乘区 ${formatNumber(factors.staticFactor)}，'
      '动态乘区 ${formatNumber(factors.dynamicFactor)}',
    );

  if (result.isOk) {
    for (final coin in result.coins) {
      final step = coin.step;
      buffer.writeln(
        '硬币${step.index + 1}（${step.face.label}）威力 ${step.hitPower}'
        ' → 取整前 ${formatNumber(coin.rawDamage)}，伤害 ${coin.finalDamage}'
        '${coin.isMinimumApplied ? '（保底）' : ''}',
      );
    }
    buffer.writeln('技能直接伤害合计：${result.totalDamage}');
  } else {
    final powers = result.powerSteps.map((s) => s.hitPower).join(' / ');
    buffer
      ..writeln('各次命中威力：$powers')
      ..writeln('技能直接伤害合计：未输出（威力降至 0 或以下，游戏处理方式待确认）');
  }
  buffer.write('范围：$calculationScopeNote');
  return buffer.toString();
}
