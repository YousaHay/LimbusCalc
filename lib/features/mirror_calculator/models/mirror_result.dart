import 'package:flutter/foundation.dart' show immutable;

import 'mirror_state.dart';

/// 参考 `compute()` 中一行硬币 / 重投的全部中间量。
///
/// 字段名与参考实现保持一致，便于差分验证与逐项核对。
@immutable
class MirrorRow {
  const MirrorRow({
    required this.idx,
    required this.isReroll,
    required this.k,
    required this.active,
    required this.face,
    required this.powerBefore,
    required this.n,
    required this.breath,
    required this.critRate,
    required this.critPart,
    required this.fRaw,
    required this.f,
    required this.g,
    required this.m1,
    required this.m2,
    required this.sumH,
    required this.sumI,
    required this.powerBase,
    required this.mult,
    required this.rawJ,
    required this.j,
    required this.loss,
    required this.extra,
    required this.coef,
    required this.extraRaw,
    required this.nv,
    required this.fixed,
    required this.fixedPart,
    required this.o,
  });

  /// 0..17；前 9 行为硬币，后 9 行为重投。
  final int idx;
  final bool isReroll;

  /// 组内序号 1..9。
  final int k;
  final bool active;

  /// 本行命中时的硬币正反面。
  final MirrorFace face;

  /// 命中前的累计威力（上一启用行的威力基数；首行为最终基础威力）；未启用行为 null。
  final double? powerBefore;

  /// 已应用硬币威力的次数 N（威力基数中“最终硬币威力 × N”的 N）。
  /// 全部正面时与参考一致：硬币行 = k；重投行 = 硬币数量 + k。
  /// 每个反面使本行及之后的 N 少 1（见 docs/mirrorcalc_port.md 第 8 节）。
  final double n;
  final double breath;
  final double critRate;

  /// 暴击部分。
  final double critPart;

  /// 单币第一乘区取整前的值。
  final double fRaw;

  /// 单币第一乘区 = ROUND(fRaw, 2)。
  final double f;

  /// 单币第二乘区。
  final double g;
  final double m1;
  final double m2;

  /// 截至本行（含）的 Σ单币硬币威力 / Σ终币特殊威力。
  final double sumH;
  final double sumI;
  final double powerBase;
  final double mult;
  final double rawJ;

  /// 不计算追伤伤害；未启用行为 null。
  final double? j;

  /// 取整损失 rawJ − J；未启用行为 null。
  final double? loss;
  final bool extra;
  final double coef;

  /// 比例追伤取整前；未开启比例追伤时为 null。
  final double? extraRaw;

  /// 比例追伤（追伤数值）。
  final double nv;
  final double fixed;

  /// 固定追伤 × 攻击容量。
  final double fixedPart;

  /// 伤害数值；未启用行为 null。
  final double? o;

  String get label => '${isReroll ? '重投' : '硬币'}$k';
}

/// 参考 `compute()` 的完整输出。
@immutable
class MirrorResult {
  const MirrorResult({
    required this.levelDiff,
    required this.levelMod,
    required this.finalBase,
    required this.finalCoin,
    required this.powerTotal,
    required this.rows,
    required this.sumH,
    required this.sumI,
    required this.sumJ,
    required this.sumK,
    required this.sumN,
    required this.sumO,
    required this.sumFixedPart,
    required this.activeCoins,
    required this.activeRerolls,
    required this.clashPower,
    required this.clash,
    required this.loop1,
    required this.loop2,
    required this.loop3,
  });

  final double levelDiff;
  final double levelMod;
  final double finalBase;
  final double finalCoin;

  /// 威力总值（仅展示）。
  final double powerTotal;
  final List<MirrorRow> rows;

  /// 全部 18 行累计后的 Σh / Σi（参考 compute 返回值）。
  final double sumH;
  final double sumI;

  /// 启用行的 Σ不计算追伤伤害。
  final double sumJ;

  /// 启用行的 Σ固定追伤（未乘攻击容量，参考 sumK）。
  final double sumK;

  /// 启用行的 Σ比例追伤。
  final double sumN;

  /// 启用行的 Σ伤害数值 = 总伤害。
  final double sumO;

  /// 启用行的 Σ(固定追伤 × 攻击容量)。参考未直接输出，由同一循环中的 fixedPart 累加，供构成展示。
  final double sumFixedPart;

  /// 启用的硬币行数（不含重投）。
  final int activeCoins;

  /// 启用的重投行数。
  final int activeRerolls;
  final double clashPower;

  /// 拼点点数（不是胜率）。
  final double clash;
  final double loop1;
  final double loop2;
  final double loop3;

  double get total => sumO;
  double get loop12 => loop1 + loop2;

  /// 总伤害与“直接伤害 + 比例追伤 + 固定追伤×容量”之差。
  /// 每行伤害数值整体取 INT，固定追伤 × 容量非整数时两者可能不等；整数输入下为 0。
  double get compositionRemainder => sumO - (sumJ + sumN + sumFixedPart);

  Iterable<MirrorRow> get activeRows => rows.where((r) => r.active);
}
