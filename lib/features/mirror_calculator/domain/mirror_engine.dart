/// MirrorCalcWeb 计算核心的纯 Dart 移植。
///
/// 来源：https://github.com/f0lkskill/MirrorCalcWeb
/// 提交 d7f538d2b279e8649f78c2248aab5317697024d9 的 index.html
/// （sanitizeNumber / clearInactiveCoins / normalize / compute / loopAvg）。
/// Copyright (c) 2026 f0lkskill，MIT License。
///
/// 运算顺序与取整位置逐行对应参考实现，以保证浮点结果逐位一致；
/// 参考模型本身的行为（例如 z1 计入两次）原样保留，详见 docs/mirrorcalc_port.md。
library;

import 'dart:math' as math;

import '../models/mirror_result.dart';
import '../models/mirror_state.dart';
import 'js_numeric.dart';

/// 参考 INT_PATHS：只允许整数的字段。
const Set<String> _intPaths = {
  'coinCount',
  'coinPower',
  'basePower',
  'capacity',
  'atkLevel',
  'baseBonus',
  'coinBonus',
  'clashBonus',
  'atkLevelBonus',
  'enemyLevel',
  'rerollCount',
};
const Set<String> _intCoinKeys = {'breath', 'h', 'i', 'fixed'};

/// 参考 NONNEG_PATHS：在整数基础上不允许为负。
const Set<String> _nonNegPaths = {
  'coinCount',
  'coinPower',
  'basePower',
  'capacity',
  'atkLevel',
  'enemyLevel',
  'rerollCount',
};
const Set<String> _min1Paths = {'capacity'};
const Set<String> _nonNegCoinKeys = {'breath'};

/// 参考 `sanitizeNumber(path, raw)`：整数字段按 JavaScript Math.round 取整，受限字段钳制。
double sanitizeNumber(String path, double raw) {
  final parts = path.split('.');
  final v0 = numOf(raw);
  if (parts[0] == 'coins' && parts.length == 3) {
    final key = parts[2];
    if (_intCoinKeys.contains(key)) {
      var v = jsRound(v0);
      if (_nonNegCoinKeys.contains(key) && v < 0) v = 0;
      return v;
    }
    return v0;
  }
  if (_intPaths.contains(path)) {
    var v = jsRound(v0);
    if (_nonNegPaths.contains(path) && v < 0) v = 0;
    if (_min1Paths.contains(path) && v < 1) v = 1;
    return v;
  }
  return v0;
}

/// 第 [idx] 行是否启用（参考 clearInactiveCoins / compute 中相同的判断）。
bool isRowActive(MirrorState s, int idx) {
  final isReroll = idx >= mirrorMainCoins;
  final k = isReroll ? idx - mirrorMainCoins + 1 : idx + 1;
  return isReroll
      ? (s.flag(MirrorFlag.reroll) && k <= numOf(s[MirrorField.rerollCount]))
      : (k <= numOf(s[MirrorField.coinCount]));
}

/// 参考 `clearInactiveCoins(s)`：未启用行一律清零。
///
/// 返回清理后的状态，以及原本带有数据而被清空的行号（与参考返回值一致）。
({MirrorState state, List<int> cleared}) clearInactiveCoins(MirrorState s) {
  final cleared = <int>[];
  final coins = [...s.coins];
  for (var i = 0; i < mirrorCoinRows; i++) {
    if (!isRowActive(s, i)) {
      if (coins[i].hasData) cleared.add(i);
      coins[i] = MirrorCoin.blank;
    }
  }
  return (state: s.copyWith(coins: coins), cleared: cleared);
}

/// 参考 `normalize(o)` 对已是规范结构的状态所做的处理：
/// 硬币数量 / 重投次数取整并钳制到 0..9，数值转为有限数，最后清理未启用行。
MirrorState normalize(MirrorState s) {
  double count(MirrorField f) =>
      math.max(0.0, math.min(9.0, jsRound(numOf(s[f]))));
  final values = {
    for (final f in MirrorField.values) f: numOf(s[f]),
    MirrorField.coinCount: count(MirrorField.coinCount),
    MirrorField.rerollCount: count(MirrorField.rerollCount),
  };
  final coins = [
    for (final c in s.coins)
      MirrorCoin(
        breath: numOf(c.breath),
        z2: numOf(c.z2),
        h: numOf(c.h),
        i: numOf(c.i),
        fixed: numOf(c.fixed),
        extra: c.extra,
        coef: numOf(c.coef),
      ),
  ];
  return clearInactiveCoins(s.copyWith(values: values, coins: coins)).state;
}

/// 参考 `compute(s)`。
MirrorResult computeMirror(MirrorState s) {
  final levelDiff =
      numOf(s[MirrorField.atkLevel]) +
      numOf(s[MirrorField.atkLevelBonus]) -
      numOf(s[MirrorField.enemyLevel]);
  final levelMod = levelDiff / (levelDiff.abs() + 25);
  final counter = s.flag(MirrorFlag.counter);
  final finalBase = excelInt(
    numOf(s[MirrorField.basePower]) +
        numOf(s[MirrorField.baseBonus]) +
        (counter ? levelDiff / 3 : 0),
  );
  final finalCoin =
      numOf(s[MirrorField.coinPower]) + numOf(s[MirrorField.coinBonus]);
  final coinCount = numOf(s[MirrorField.coinCount]);
  final powerTotal =
      numOf(s[MirrorField.basePower]) +
      numOf(s[MirrorField.baseBonus]) +
      finalCoin * coinCount;
  final z1 = numOf(s[MirrorField.z1]);
  final z2 = numOf(s[MirrorField.z2]);
  final cap = numOf(s[MirrorField.capacity]);
  final crit = s.flag(MirrorFlag.crit);

  final rows = <MirrorRow>[];
  var sumH = 0.0, sumI = 0.0;
  var coinH = 0.0, rerollH = 0.0;
  var sumJ = 0.0, sumK = 0.0, sumN = 0.0, sumO = 0.0, sumFixedPart = 0.0;
  var activeCoins = 0, activeRerolls = 0;
  // 正反面扩展：组内截至本行的反面数，以及已启用普通硬币中的反面数（重投从此状态继续）。
  var groupTails = 0, activeCoinTails = 0;
  var prevPower = finalBase;

  for (var idx = 0; idx < mirrorCoinRows; idx++) {
    final isReroll = idx >= mirrorMainCoins;
    final k = isReroll ? idx - mirrorMainCoins + 1 : idx + 1;
    final active = isRowActive(s, idx);
    final c = s.coins[idx];
    final face = s.faces[idx];
    if (idx == mirrorMainCoins) groupTails = 0;
    if (face == MirrorFace.tails) {
      groupTails++;
      if (!isReroll && active) activeCoinTails++;
    }

    // 未启用的行不参与任何累计。
    final hv = active ? numOf(c.h) : 0.0;
    final iv = active ? numOf(c.i) : 0.0;
    sumH += hv;
    sumI += iv;
    if (active) {
      if (isReroll) {
        rerollH += hv;
      } else {
        coinH += hv;
      }
    }

    // 参考（全正面）：硬币行 N = k，重投行 N = 硬币数量 + k。
    // 反面不应用本次硬币威力变化：每个反面使本行及之后的 N 少 1；全部正面时两式逐位等同于参考。
    final n = isReroll
        ? (coinCount - activeCoinTails) + (k - groupTails)
        : (k - groupTails).toDouble();
    final critRate = numOf(c.breath) * 0.05;
    final critPart = crit ? 0.2 : math.min(critRate * 0.2, 0.2);
    final fRaw = critPart + z1 + levelMod;
    final f = excelRound(fRaw, 2);
    final g = numOf(c.z2);
    // 参考行为：z1 既进入 F，又在此处再加一次（见 docs/mirrorcalc_port.md 第 5 节）。
    final m1 = 1 + z1 + f;
    final m2 = 1 + z2 + g;
    final powerBase = finalBase + finalCoin * n + sumH + sumI;
    final mult = m1 * m2;
    final rawJ = powerBase * mult * cap;
    // 伤害保底 1。
    final j = active ? math.max(1.0, excelInt(rawJ)) : null;
    // 参考：比例追伤对未启用行同样求值（此时 J 视为 0），但不计入合计。
    final extraRaw = c.extra ? (j ?? 0) * numOf(c.coef) : null;
    final nv = c.extra ? excelInt(extraRaw!) : 0.0;
    final fixedPart = numOf(c.fixed) * cap;
    final o = (active && j != null) ? excelInt(j + nv + fixedPart) : null;
    final powerBefore = active ? prevPower : null;
    if (active) prevPower = powerBase;

    if (active) {
      if (isReroll) {
        activeRerolls++;
      } else {
        activeCoins++;
      }
      sumJ += j!;
      sumO += o!;
      sumN += nv;
      sumK += numOf(c.fixed);
      sumFixedPart += fixedPart;
    }

    rows.add(
      MirrorRow(
        idx: idx,
        isReroll: isReroll,
        k: k,
        active: active,
        face: face,
        powerBefore: powerBefore,
        n: n,
        breath: numOf(c.breath),
        critRate: critRate,
        critPart: critPart,
        fRaw: fRaw,
        f: f,
        g: g,
        m1: m1,
        m2: m2,
        sumH: sumH,
        sumI: sumI,
        powerBase: powerBase,
        mult: mult,
        rawJ: rawJ,
        j: j,
        loss: j == null ? null : rawJ - j,
        extra: c.extra,
        coef: numOf(c.coef),
        extraRaw: extraRaw,
        nv: nv,
        fixed: numOf(c.fixed),
        fixedPart: fixedPart,
        o: o,
      ),
    );
  }

  // 重投行的单币硬币威力只有在“重投参与拼点”时计入拼点。
  final rerollClash = s.flag(MirrorFlag.rerollClash);
  final clashPower = coinH + (rerollClash ? rerollH : 0);
  final noClash = counter || !s.flag(MirrorFlag.joinClash);
  final clash = noClash
      ? 0.0
      : excelInt(
          numOf(s[MirrorField.basePower]) +
              numOf(s[MirrorField.baseBonus]) +
              finalCoin * coinCount +
              levelDiff / 3 +
              numOf(s[MirrorField.clashBonus]) +
              ((s.flag(MirrorFlag.reroll) && rerollClash)
                  ? finalCoin * numOf(s[MirrorField.rerollCount])
                  : 0) +
              clashPower,
        );

  return MirrorResult(
    levelDiff: levelDiff,
    levelMod: levelMod,
    finalBase: finalBase,
    finalCoin: finalCoin,
    powerTotal: powerTotal,
    rows: List.unmodifiable(rows),
    sumH: sumH,
    sumI: sumI,
    sumJ: sumJ,
    sumK: sumK,
    sumN: sumN,
    sumO: sumO,
    sumFixedPart: sumFixedPart,
    activeCoins: activeCoins,
    activeRerolls: activeRerolls,
    clashPower: clashPower,
    clash: clash,
    loop1: loopDamageSum(s.loops, LoopGroup.loop1),
    loop2: loopDamageSum(s.loops, LoopGroup.loop2),
    loop3: loopDamageSum(s.loops, LoopGroup.loop3),
  );
}

/// 页面实际管线：先清理未启用行（参考 refresh() 第一步），再计算。
({MirrorState state, List<int> cleared, MirrorResult result}) runPagePipeline(
  MirrorState s,
) {
  final c = clearInactiveCoins(s);
  return (state: c.state, cleared: c.cleared, result: computeMirror(c.state));
}

/// 参考 compute 中的循环伤害求和：`loop.reduce((a, b) => a + num(b), 0)`，未填写按 0。
double loopDamageSum(MirrorLoops loops, LoopGroup g) =>
    loops.damage[g]!.fold(0.0, (a, b) => a + numOf(b ?? 0));

/// 参考 `loopAvg(key)`：只统计有数值的回合，按 JavaScript Math.round 取整；无数据时为 0。
double loopAverageClash(List<double?> clash) {
  final vals = [
    for (final v in clash)
      if (v != null && v.isFinite) v,
  ];
  if (vals.isEmpty) return 0;
  final sum = vals.fold(0.0, (a, b) => a + b);
  return jsRound(sum / vals.length);
}

/// 有数值、参与平均的回合数（供界面区分“平均为 0”与“没有参与回合”）。
int loopClashCount(List<double?> clash) =>
    clash.where((v) => v != null && v.isFinite).length;

/// 三组循环伤害合计与“两轮循环总和”（参考 compute 返回的 loop1 / loop2 / loop12 / loop3）。
({double loop1, double loop2, double loop12, double loop3}) loopTotals(
  MirrorLoops loops,
) {
  final l1 = loopDamageSum(loops, LoopGroup.loop1);
  final l2 = loopDamageSum(loops, LoopGroup.loop2);
  return (
    loop1: l1,
    loop2: l2,
    loop12: l1 + l2,
    loop3: loopDamageSum(loops, LoopGroup.loop3),
  );
}
