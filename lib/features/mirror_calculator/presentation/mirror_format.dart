/// 高级计算的显示格式（只用于显示与回写输入框，不参与计算）。
library;

/// 参考 `fmt(v)`：接近整数时不显示小数，否则最多保留 [digits] 位并去掉末尾 0。
String mirrorNum(double? v, {int digits = 6}) {
  if (v == null) return '—';
  if (!v.isFinite) return v.toString();
  if ((v - v.roundToDouble()).abs() < 1e-12) {
    final r = v.roundToDouble();
    return r == 0 ? '0' : r.toStringAsFixed(0);
  }
  var text = v.toStringAsFixed(digits);
  text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return text == '-0' ? '0' : text;
}

/// 固定小数位显示（参考 `fmt(v, dp)`，如单币第一乘区保留 2 位）。
String mirrorFixed(double? v, int dp) =>
    v == null ? '—' : v.toStringAsFixed(dp);

/// 输入路径的中文描述，用于错误列表（如 `coins.10.h` → “重投2 · 单币硬币威力”）。
String describeMirrorPath(String path) {
  final parts = path.split('.');
  if (parts[0] == 'coins' && parts.length == 3) {
    final row = int.parse(parts[1]);
    final label = row < 9 ? '硬币${row + 1}' : '重投${row - 8}';
    return '$label · ${_coinLabels[parts[2]] ?? parts[2]}';
  }
  final loop = RegExp(r'^loop([123])(c?)$').firstMatch(parts[0]);
  if (loop != null && parts.length == 2) {
    final group = const ['第一循环', '第二循环', '极限循环'][int.parse(loop[1]!) - 1];
    final offset = loop[1] == '2' ? 6 : 0;
    final round = int.parse(parts[1]) + 1 + offset;
    return '$group 第 $round 回合${loop[2] == 'c' ? '拼点' : '伤害'}';
  }
  return _fieldLabels[path] ?? path;
}

const _coinLabels = {
  'breath': '呼吸法强度',
  'z2': '单币第二乘区',
  'h': '单币硬币威力',
  'i': '终币特殊威力',
  'fixed': '固定追伤',
  'coef': '追伤系数',
};

const _fieldLabels = {
  'coinCount': '硬币数量',
  'basePower': '基础威力',
  'coinPower': '硬币威力',
  'capacity': '攻击容量',
  'atkLevel': '攻击等级',
  'baseBonus': '终础威力加成',
  'coinBonus': '硬币威力加成',
  'clashBonus': '拼点威力加成',
  'atkLevelBonus': '攻击等级加成',
  'enemyLevel': '敌方等级',
  'rerollCount': '重投次数',
  'z1': '技能第一乘区',
  'z2': '技能第二乘区',
};

/// 回合名称：第二循环接着第一循环往下数（参考 roundLabel）。
String loopRoundLabel(int offset, int i) =>
    '第${const ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二'][offset + i]}回合';
