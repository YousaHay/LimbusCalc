/// 高级计算（计算模型源自 MirrorCalcWeb）的输入状态。
///
/// 字段与参考实现 `defaultState()` 一一对应；数值统一用 double 保存，
/// 与 JavaScript number 语义一致（整数字段在输入时由 `sanitizeNumber` 取整）。
library;

import 'package:flutter/foundation.dart' show immutable, listEquals;

/// 参考 `COIN_ROWS / COIN_MAIN / LOOP_LEN`：9 行硬币 + 9 行重投，循环每组 6 回合。
const int mirrorCoinRows = 18;
const int mirrorMainCoins = 9;
const int mirrorLoopLength = 6;

/// 技能与全局数值字段。`path` 为参考状态中的字段名。
enum MirrorField {
  coinCount('coinCount', '硬币数量'),
  basePower('basePower', '基础威力'),
  coinPower('coinPower', '硬币威力'),
  capacity('capacity', '攻击容量'),
  atkLevel('atkLevel', '攻击等级'),
  baseBonus('baseBonus', '终础威力加成'),
  coinBonus('coinBonus', '硬币威力加成'),
  clashBonus('clashBonus', '拼点威力加成'),
  atkLevelBonus('atkLevelBonus', '攻击等级加成'),
  enemyLevel('enemyLevel', '敌方等级'),
  rerollCount('rerollCount', '重投次数'),
  z1('z1', '技能第一乘区'),
  z2('z2', '技能第二乘区');

  const MirrorField(this.path, this.label);
  final String path;
  final String label;
}

/// 是 / 否 开关字段。
enum MirrorFlag {
  counter('counter', '不可拼点反击'),
  joinClash('joinClash', '是否参与拼点'),
  crit('crit', '必定暴击'),
  reroll('reroll', '是否重投'),
  rerollClash('rerollClash', '重投是否参与拼点');

  const MirrorFlag(this.path, this.label);
  final String path;
  final String label;
}

/// 逐行数值字段。
enum CoinField {
  breath('breath', '呼吸法强度'),
  z2('z2', '单币第二乘区'),
  h('h', '单币硬币威力'),
  i('i', '终币特殊威力'),
  fixed('fixed', '固定追伤'),
  coef('coef', '追伤系数');

  const CoinField(this.key, this.label);
  final String key;
  final String label;

  /// 参考状态路径，如 `coins.3.breath`。
  String pathFor(int row) => 'coins.$row.$key';
}

/// 一行硬币 / 重投参数（参考 `blankCoin()`）。
@immutable
class MirrorCoin {
  const MirrorCoin({
    this.breath = 0,
    this.z2 = 0,
    this.h = 0,
    this.i = 0,
    this.fixed = 0,
    this.extra = false,
    this.coef = 0,
  });

  static const blank = MirrorCoin();

  final double breath;
  final double z2;
  final double h;
  final double i;
  final double fixed;

  /// 是否追伤（比例追伤开关）。
  final bool extra;
  final double coef;

  double valueOf(CoinField f) => switch (f) {
    CoinField.breath => breath,
    CoinField.z2 => z2,
    CoinField.h => h,
    CoinField.i => i,
    CoinField.fixed => fixed,
    CoinField.coef => coef,
  };

  MirrorCoin withValue(CoinField f, double v) => MirrorCoin(
    breath: f == CoinField.breath ? v : breath,
    z2: f == CoinField.z2 ? v : z2,
    h: f == CoinField.h ? v : h,
    i: f == CoinField.i ? v : i,
    fixed: f == CoinField.fixed ? v : fixed,
    extra: extra,
    coef: f == CoinField.coef ? v : coef,
  );

  MirrorCoin withExtra(bool v) => MirrorCoin(
    breath: breath,
    z2: z2,
    h: h,
    i: i,
    fixed: fixed,
    extra: v,
    coef: coef,
  );

  /// 参考 clearInactiveCoins 的“行内有数据”判断（JavaScript 真值语义：0 与 -0 为假）。
  bool get hasData =>
      breath != 0 ||
      z2 != 0 ||
      h != 0 ||
      i != 0 ||
      fixed != 0 ||
      coef != 0 ||
      extra;

  @override
  bool operator ==(Object other) =>
      other is MirrorCoin &&
      other.breath == breath &&
      other.z2 == z2 &&
      other.h == h &&
      other.i == i &&
      other.fixed == fixed &&
      other.extra == extra &&
      other.coef == coef;

  @override
  int get hashCode => Object.hash(breath, z2, h, i, fixed, extra, coef);
}

/// 命中阶段的硬币投掷结果（本应用对参考模型的扩展）。
///
/// 参考 MirrorCalcWeb 没有正反面，等价于全部正面；缺省值因此为正面。
enum MirrorFace {
  heads('正'),
  tails('反');

  const MirrorFace(this.label);
  final String label;
}

/// 循环组。
enum LoopGroup {
  loop1('第一循环', 0),
  loop2('第二循环', 6),
  loop3('极限循环', 0);

  const LoopGroup(this.label, this.roundOffset);
  final String label;

  /// 回合编号偏移：第二循环接着第一循环往下数（第 7～12 回合）。
  final int roundOffset;
}

/// 循环中一个回合的拼点记录。
///
/// 参考实现只有“有值”与 `null` 两种；这里把 `null` 再区分为“未填写”与
/// “明确不参与平均”，两者在计算中都等同于参考的 `null`。
@immutable
class LoopClash {
  const LoopClash.value(double this.value) : skipped = false;
  const LoopClash.empty() : value = null, skipped = false;
  const LoopClash.skipped() : value = null, skipped = true;

  final double? value;
  final bool skipped;

  bool get hasValue => value != null;

  @override
  bool operator ==(Object other) =>
      other is LoopClash && other.value == value && other.skipped == skipped;

  @override
  int get hashCode => Object.hash(value, skipped);
}

/// 三组循环的手工记录。伤害 `null` 表示未填写（求和时按参考规则视为 0）。
@immutable
class MirrorLoops {
  MirrorLoops({
    Map<LoopGroup, List<double?>>? damage,
    Map<LoopGroup, List<LoopClash>>? clash,
  }) : damage = {
         for (final g in LoopGroup.values)
           g: List.unmodifiable(
             damage?[g] ?? List<double?>.filled(mirrorLoopLength, null),
           ),
       },
       clash = {
         for (final g in LoopGroup.values)
           g: List.unmodifiable(
             clash?[g] ??
                 List<LoopClash>.filled(
                   mirrorLoopLength,
                   const LoopClash.empty(),
                 ),
           ),
       };

  final Map<LoopGroup, List<double?>> damage;
  final Map<LoopGroup, List<LoopClash>> clash;

  MirrorLoops withDamage(LoopGroup g, int round, double? v) {
    final next = {...damage};
    next[g] = [...damage[g]!]..[round] = v;
    return MirrorLoops(damage: next, clash: clash);
  }

  MirrorLoops withClash(LoopGroup g, int round, LoopClash v) {
    final next = {...clash};
    next[g] = [...clash[g]!]..[round] = v;
    return MirrorLoops(damage: damage, clash: next);
  }

  /// 参考状态中的拼点数组：未填写与不参与平均均为 null。
  List<double?> referenceClash(LoopGroup g) => [
    for (final c in clash[g]!) c.value,
  ];

  @override
  bool operator ==(Object other) =>
      other is MirrorLoops &&
      LoopGroup.values.every(
        (g) =>
            listEquals(other.damage[g], damage[g]) &&
            listEquals(other.clash[g], clash[g]),
      );

  @override
  int get hashCode => Object.hashAll([
    for (final g in LoopGroup.values) ...[
      Object.hashAll(damage[g]!),
      Object.hashAll(clash[g]!),
    ],
  ]);
}

/// 高级计算的完整输入状态（参考 `defaultState()`，另含正反面）。
@immutable
class MirrorState {
  MirrorState({
    this.planName = '',
    Map<MirrorField, double>? values,
    Map<MirrorFlag, bool>? flags,
    List<MirrorCoin>? coins,
    List<MirrorFace>? faces,
    MirrorLoops? loops,
  }) : values = Map.unmodifiable({
         for (final f in MirrorField.values) f: values?[f] ?? _defaultValue(f),
       }),
       flags = Map.unmodifiable({
         for (final f in MirrorFlag.values) f: flags?[f] ?? _defaultFlag(f),
       }),
       coins = List.unmodifiable(
         coins ?? List.filled(mirrorCoinRows, MirrorCoin.blank),
       ),
       faces = List.unmodifiable(
         faces ?? List.filled(mirrorCoinRows, MirrorFace.heads),
       ),
       loops = loops ?? MirrorLoops() {
    if (this.coins.length != mirrorCoinRows) {
      throw ArgumentError.value(this.coins.length, 'coins', '必须为 18 行');
    }
    if (this.faces.length != mirrorCoinRows) {
      throw ArgumentError.value(this.faces.length, 'faces', '必须为 18 行');
    }
  }

  /// 参考 defaultState：数值均为 0，攻击容量为 1；“是否参与拼点”默认为是。
  factory MirrorState.initial() => MirrorState();

  static double _defaultValue(MirrorField f) =>
      f == MirrorField.capacity ? 1 : 0;
  static bool _defaultFlag(MirrorFlag f) => f == MirrorFlag.joinClash;

  /// 方案名称（参考 skillName），只用于标识，不参与计算。
  final String planName;
  final Map<MirrorField, double> values;
  final Map<MirrorFlag, bool> flags;
  final List<MirrorCoin> coins;

  /// 18 行（硬币 1～9、重投 1～9）各自的正反面；缺失时默认全部正面。
  final List<MirrorFace> faces;
  final MirrorLoops loops;

  double operator [](MirrorField f) => values[f]!;
  bool flag(MirrorFlag f) => flags[f]!;

  MirrorState copyWith({
    String? planName,
    Map<MirrorField, double>? values,
    Map<MirrorFlag, bool>? flags,
    List<MirrorCoin>? coins,
    List<MirrorFace>? faces,
    MirrorLoops? loops,
  }) => MirrorState(
    planName: planName ?? this.planName,
    values: values ?? this.values,
    flags: flags ?? this.flags,
    coins: coins ?? this.coins,
    faces: faces ?? this.faces,
    loops: loops ?? this.loops,
  );

  MirrorState withValue(MirrorField f, double v) =>
      copyWith(values: {...values, f: v});

  MirrorState withFlag(MirrorFlag f, bool v) =>
      copyWith(flags: {...flags, f: v});

  MirrorState withCoin(int row, MirrorCoin coin) =>
      copyWith(coins: [...coins]..[row] = coin);

  MirrorState withFace(int row, MirrorFace face) =>
      copyWith(faces: [...faces]..[row] = face);

  /// 计算相关输入是否相同（含正反面，不含方案名称与循环记录），用于判断扫描结果是否过期。
  bool sameCalculationInputs(MirrorState other) =>
      MirrorField.values.every((f) => other[f] == this[f]) &&
      MirrorFlag.values.every((f) => other.flag(f) == flag(f)) &&
      listEquals(other.coins, coins) &&
      listEquals(other.faces, faces);

  @override
  bool operator ==(Object other) =>
      other is MirrorState &&
      other.planName == planName &&
      sameCalculationInputs(other) &&
      other.loops == loops;

  @override
  int get hashCode => Object.hash(
    planName,
    Object.hashAll(MirrorField.values.map((f) => this[f])),
    Object.hashAll(MirrorFlag.values.map(flag)),
    Object.hashAll(coins),
    Object.hashAll(faces),
    loops,
  );
}
