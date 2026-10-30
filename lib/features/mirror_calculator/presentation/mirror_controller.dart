import 'package:flutter/widgets.dart';

import '../../calculator/presentation/input_parsing.dart';
import '../domain/mirror_engine.dart';
import '../domain/mirror_sweep.dart';
import '../models/mirror_result.dart';
import '../models/mirror_state.dart';
import 'mirror_format.dart';

/// 输入数值的合理范围（界面校验，防止误输入极端值；不属于参考模型）。
const double _inputLimit = 99999;

/// 正反面选择方式。
enum FaceSelection {
  allHeads('全部正面'),
  allTails('全部反面'),
  custom('自定义');

  const FaceSelection(this.label);
  final String label;
}

/// 正反面分组：普通硬币（第 0～8 行）与重投（第 9～17 行）各自独立选择。
enum FaceGroup {
  coins('普通硬币', 0),
  rerolls('重投', mirrorMainCoins);

  const FaceGroup(this.label, this.offset);
  final String label;
  final int offset;

  static FaceGroup ofRow(int row) => row < mirrorMainCoins ? coins : rerolls;
}

/// 编辑器的完整输入快照（含隐藏行、正反面与加减算），用于循环记录与恢复。
@immutable
class MirrorEditorSnapshot {
  const MirrorEditorSnapshot({
    required this.planName,
    required this.fieldTexts,
    required this.coinTexts,
    required this.extras,
    required this.flags,
    required this.coinPowerAdd,
    required this.faceModes,
    required this.customFaces,
  });

  final String planName;
  final Map<MirrorField, String> fieldTexts;
  final List<Map<CoinField, String>> coinTexts;
  final List<bool> extras;
  final Map<MirrorFlag, bool> flags;
  final bool coinPowerAdd;
  final Map<FaceGroup, FaceSelection> faceModes;
  final Map<FaceGroup, List<MirrorFace>> customFaces;
}

/// 循环中一个回合的记录：写入时的结果与对应的完整输入快照。
@immutable
class LoopRecord {
  const LoopRecord({
    required this.total,
    required this.clash,
    required this.faces,
    required this.snapshot,
  });

  /// 记录时保存的结果（不会随当前参数重算）。
  final double total;
  final double clash;

  /// 记录时启用行的正反面序列（普通硬币在前，重投在后）。
  final List<(int row, MirrorFace face)> faces;
  final MirrorEditorSnapshot snapshot;

  String get faceText => faces.isEmpty
      ? '无启用硬币'
      : faces
            .map((e) => e.$1 < mirrorMainCoins ? e.$2.label : '重${e.$2.label}')
            .join(' ');
}

/// 高级计算的输入状态与即时计算。
///
/// 只负责文本解析、按参考 sanitizeNumber 规范化、组织正反面与调用领域层，不包含任何公式。
class MirrorController extends ChangeNotifier {
  MirrorController() {
    for (final f in MirrorField.values) {
      _fieldText[f] = _text(_defaultText(f));
    }
    for (var row = 0; row < mirrorCoinRows; row++) {
      _coinText.add({for (final f in CoinField.values) f: _text('')});
    }
    for (final g in LoopGroup.values) {
      _damageText[g] = [for (var i = 0; i < mirrorLoopLength; i++) _text('')];
      _clashText[g] = [for (var i = 0; i < mirrorLoopLength; i++) _text('')];
      _clashSkipped[g] = List.filled(mirrorLoopLength, false);
    }
    planName.addListener(notifyListeners);
    _recalculate();
  }

  static const _countFields = {MirrorField.coinCount, MirrorField.rerollCount};

  static String _defaultText(MirrorField f) =>
      f == MirrorField.capacity ? '1' : '0';

  final planName = TextEditingController();
  final Map<MirrorField, TextEditingController> _fieldText = {};
  final List<Map<CoinField, TextEditingController>> _coinText = [];
  final Map<LoopGroup, List<TextEditingController>> _damageText = {};
  final Map<LoopGroup, List<TextEditingController>> _clashText = {};
  final Map<LoopGroup, List<bool>> _clashSkipped = {};
  final Map<MirrorFlag, bool> _flags = {
    for (final f in MirrorFlag.values) f: f == MirrorFlag.joinClash,
  };
  final List<bool> _extra = List.filled(mirrorCoinRows, false);

  /// 硬币威力的加减算；输入框只保存非负数值部分。
  bool _coinPowerAdd = true;
  final Map<FaceGroup, FaceSelection> _faceModes = {
    for (final g in FaceGroup.values) g: FaceSelection.allHeads,
  };

  /// 自定义序列按 9 个位置保存：减少数量时隐藏位置的选择保留，重新增加时恢复。
  final Map<FaceGroup, List<MirrorFace>> _customFaces = {
    for (final g in FaceGroup.values)
      g: List.filled(mirrorMainCoins, MirrorFace.heads),
  };
  final Map<(LoopGroup, int), LoopRecord> _records = {};

  bool _suspended = false;
  Map<String, String> _errors = const {};
  MirrorState? _state;
  MirrorResult? _result;
  MirrorLoops _loops = MirrorLoops();
  MirrorState _lastValid = MirrorState.initial();

  LoopGroup _recordGroup = LoopGroup.loop1;
  int _recordRound = 0;

  TextEditingController _text(String initial) =>
      TextEditingController(text: initial)..addListener(_recalculate);

  TextEditingController fieldText(MirrorField f) => _fieldText[f]!;
  TextEditingController coinText(int row, CoinField f) => _coinText[row][f]!;
  TextEditingController damageText(LoopGroup g, int i) => _damageText[g]![i];
  TextEditingController clashText(LoopGroup g, int i) => _clashText[g]![i];
  bool clashSkipped(LoopGroup g, int i) => _clashSkipped[g]![i];
  bool flag(MirrorFlag f) => _flags[f]!;
  bool extra(int row) => _extra[row];
  bool get coinPowerAdd => _coinPowerAdd;

  /// 扫描“硬币威力”时使用的符号（+1 / −1）。
  double get coinPowerSign => _coinPowerAdd ? 1 : -1;

  FaceSelection faceMode(FaceGroup g) => _faceModes[g]!;

  /// 第 [row] 行当前生效的正反面（隐藏行同样有值，重新启用时直接使用）。
  MirrorFace faceOf(int row) {
    final g = FaceGroup.ofRow(row);
    return switch (_faceModes[g]!) {
      FaceSelection.allHeads => MirrorFace.heads,
      FaceSelection.allTails => MirrorFace.tails,
      FaceSelection.custom => _customFaces[g]![row - g.offset],
    };
  }

  List<MirrorFace> get faces => [
    for (var i = 0; i < mirrorCoinRows; i++) faceOf(i),
  ];

  Map<String, String> get errors => _errors;
  String? errorOf(String path) => _errors[path];

  /// 技能计算相关的输入错误（不含循环记录）。
  Iterable<MapEntry<String, String>> get inputErrors =>
      _errors.entries.where((e) => !e.key.startsWith('loop'));
  int get loopErrorCount =>
      _errors.keys.where((k) => k.startsWith('loop')).length;

  /// 当前有效状态（已规范化；未启用行的修正已按参考清空，正反面保留）；输入有误时为 null。
  MirrorState? get state => _state;

  /// 当前计算结果；技能输入有误时为 null，绝不保留旧结果。
  MirrorResult? get result => _result;

  /// 参数扫描的基准快照：隐藏位置按正面、无逐币修正。
  MirrorState? get sweepBase => _state == null ? null : sweepBaseState(_state!);

  /// 循环记录（循环单元格有误时，该单元格按未填写处理，界面会单独提示）。
  MirrorLoops get loops => _loops;

  /// 最近一次有效输入，用于决定显示哪些行与步进器状态。
  MirrorState get lastValid => _lastValid;

  bool isRowShown(int row) => isRowActive(_lastValid, row);

  LoopGroup get recordGroup => _recordGroup;
  int get recordRound => _recordRound;
  LoopRecord? recordOf(LoopGroup g, int i) => _records[(g, i)];

  // ---------------- 编辑操作 ----------------

  void setFlag(MirrorFlag f, bool v) {
    if (_flags[f] == v) return;
    _flags[f] = v;
    _recalculate();
  }

  void setExtra(int row, bool v) {
    if (_extra[row] == v) return;
    _extra[row] = v;
    _recalculate();
  }

  void setCoinPowerAdd(bool add) {
    if (_coinPowerAdd == add) return;
    _coinPowerAdd = add;
    _recalculate();
  }

  void setFaceMode(FaceGroup g, FaceSelection mode) {
    if (_faceModes[g] == mode) return;
    _faceModes[g] = mode;
    _recalculate();
  }

  /// 切换第 [row] 行的正反面。若该组为“全部正面 / 全部反面”，先以当前序列初始化自定义。
  void toggleFace(int row) {
    final g = FaceGroup.ofRow(row);
    final mode = _faceModes[g]!;
    if (mode != FaceSelection.custom) {
      _customFaces[g]!.fillRange(
        0,
        mirrorMainCoins,
        mode == FaceSelection.allHeads ? MirrorFace.heads : MirrorFace.tails,
      );
      _faceModes[g] = FaceSelection.custom;
    }
    final list = _customFaces[g]!;
    final i = row - g.offset;
    list[i] = list[i] == MirrorFace.heads ? MirrorFace.tails : MirrorFace.heads;
    _recalculate();
  }

  void changeCount(MirrorField f, int delta) {
    final current = _lastValid[f];
    final next = (current + delta).clamp(0, 9).toDouble();
    fieldText(f).text = mirrorNum(next);
  }

  /// 失焦时把输入回写为实际参与计算的值（硬币威力回写数值部分）。
  void commitField(MirrorField f) {
    final ctrl = fieldText(f);
    if (_errors.containsKey(f.path)) return;
    final v = _lastValid[f];
    final text = mirrorNum(f == MirrorField.coinPower ? v.abs() : v);
    if (ctrl.text != text) ctrl.text = text;
  }

  void commitCoin(int row, CoinField f) {
    final ctrl = coinText(row, f);
    if (_errors.containsKey(f.pathFor(row)) || ctrl.text.trim().isEmpty) return;
    final text = mirrorNum(_lastValid.coins[row].valueOf(f));
    if (ctrl.text != text) ctrl.text = text;
  }

  void toggleClashSkip(LoopGroup g, int i) {
    final skipped = !_clashSkipped[g]![i];
    _suspended = true;
    _clashSkipped[g]![i] = skipped;
    if (skipped) clashText(g, i).text = '';
    _suspended = false;
    _recalculate();
  }

  void setRecordTarget(LoopGroup g, int round) {
    _recordGroup = g;
    _recordRound = round;
    notifyListeners();
  }

  /// 把当前结果写入所选回合（覆盖已有记录），同时保存完整输入快照；不修改任何技能参数。
  bool recordCurrent() {
    final r = _result;
    if (r == null) return false;
    _records[(_recordGroup, _recordRound)] = LoopRecord(
      total: r.total,
      clash: r.clash,
      faces: [for (final row in r.activeRows) (row.idx, row.face)],
      snapshot: captureSnapshot(),
    );
    _suspended = true;
    damageText(_recordGroup, _recordRound).text = mirrorNum(r.total);
    clashText(_recordGroup, _recordRound).text = mirrorNum(r.clash);
    _clashSkipped[_recordGroup]![_recordRound] = false;
    _suspended = false;
    _recalculate();
    return true;
  }

  /// 记录后把目标前进一个回合（参考 nextTurn 的回合推进规则）：
  /// 一组记满 6 回合后回到第 1 回合；第一循环记满时切换到第二循环。
  /// 与参考不同，这里不会存档，也不会清空硬币明细。
  bool recordAndAdvance() {
    if (!recordCurrent()) return false;
    var round = _recordRound + 1;
    var group = _recordGroup;
    if (round >= mirrorLoopLength) {
      round = 0;
      if (group == LoopGroup.loop1) group = LoopGroup.loop2;
    }
    setRecordTarget(group, round);
    return true;
  }

  /// 把某回合记录时的完整输入（含正反面）恢复到编辑器；当前结果随之重新计算。
  bool restoreRecord(LoopGroup g, int i) {
    final record = _records[(g, i)];
    if (record == null) return false;
    applySnapshot(record.snapshot);
    return true;
  }

  /// 恢复技能参数、硬币参数、全局设置与正反面（全部正面、加算），
  /// 保留方案名称、敌方等级与三组循环数据（参考 doResetParams）。
  void resetParams() {
    _suspended = true;
    for (final f in MirrorField.values) {
      if (f != MirrorField.enemyLevel) fieldText(f).text = _defaultText(f);
    }
    for (var row = 0; row < mirrorCoinRows; row++) {
      for (final f in CoinField.values) {
        coinText(row, f).text = '';
      }
      _extra[row] = false;
    }
    for (final f in MirrorFlag.values) {
      _flags[f] = f == MirrorFlag.joinClash;
    }
    _coinPowerAdd = true;
    for (final g in FaceGroup.values) {
      _faceModes[g] = FaceSelection.allHeads;
      _customFaces[g]!.fillRange(0, mirrorMainCoins, MirrorFace.heads);
    }
    _suspended = false;
    _recalculate();
  }

  MirrorEditorSnapshot captureSnapshot() => MirrorEditorSnapshot(
    planName: planName.text,
    fieldTexts: {for (final f in MirrorField.values) f: fieldText(f).text},
    coinTexts: [
      for (var row = 0; row < mirrorCoinRows; row++)
        {for (final f in CoinField.values) f: coinText(row, f).text},
    ],
    extras: List.unmodifiable(_extra),
    flags: Map.unmodifiable(_flags),
    coinPowerAdd: _coinPowerAdd,
    faceModes: Map.unmodifiable(_faceModes),
    customFaces: {
      for (final g in FaceGroup.values) g: List.unmodifiable(_customFaces[g]!),
    },
  );

  void applySnapshot(MirrorEditorSnapshot s) {
    _suspended = true;
    planName.text = s.planName;
    s.fieldTexts.forEach((f, t) => fieldText(f).text = t);
    for (var row = 0; row < mirrorCoinRows; row++) {
      s.coinTexts[row].forEach((f, t) => coinText(row, f).text = t);
      _extra[row] = s.extras[row];
    }
    _flags.addAll(s.flags);
    _coinPowerAdd = s.coinPowerAdd;
    _faceModes.addAll(s.faceModes);
    for (final g in FaceGroup.values) {
      _customFaces[g]!.setAll(0, s.customFaces[g]!);
    }
    _suspended = false;
    _recalculate();
  }

  /// 载入一个计算状态（例如旧数据）：负的硬币威力映射为“减算 + 绝对值”，
  /// 正反面按状态设置（旧状态缺省为全部正面）。不修改循环数据。
  void loadState(MirrorState s) {
    _suspended = true;
    planName.text = s.planName;
    for (final f in MirrorField.values) {
      final v = s[f];
      fieldText(f).text = mirrorNum(f == MirrorField.coinPower ? v.abs() : v);
    }
    _coinPowerAdd = !(s[MirrorField.coinPower] < 0);
    _flags.addAll(s.flags);
    for (var row = 0; row < mirrorCoinRows; row++) {
      final c = s.coins[row];
      for (final f in CoinField.values) {
        final v = c.valueOf(f);
        coinText(row, f).text = v == 0 ? '' : mirrorNum(v);
      }
      _extra[row] = c.extra;
    }
    for (final g in FaceGroup.values) {
      final group = s.faces.sublist(g.offset, g.offset + mirrorMainCoins);
      _customFaces[g]!.setAll(0, group);
      _faceModes[g] = group.every((f) => f == MirrorFace.heads)
          ? FaceSelection.allHeads
          : group.every((f) => f == MirrorFace.tails)
          ? FaceSelection.allTails
          : FaceSelection.custom;
    }
    _suspended = false;
    _recalculate();
  }

  // ---------------- 解析与计算 ----------------

  static ParseResult<double> _parse(String text) =>
      parseDecimalInRange(text, min: -_inputLimit, max: _inputLimit);

  void _recalculate() {
    if (_suspended) return;
    final errors = <String, String>{};

    // 1) 技能与全局参数：留空按参考视为 0；硬币数量 / 重投次数留空视为未完成输入。
    final values = <MirrorField, double>{};
    for (final f in MirrorField.values) {
      final text = fieldText(f).text.trim();
      double raw = 0;
      if (text.isEmpty) {
        if (_countFields.contains(f)) {
          errors[f.path] = '请输入数值';
          continue;
        }
      } else {
        final p = _parse(text);
        if (!p.isValid) {
          errors[f.path] = p.error!;
          continue;
        }
        raw = p.value!;
      }
      if (f == MirrorField.coinPower && raw < 0) {
        errors[f.path] = '负值请改用“减算”';
        continue;
      }
      var v = sanitizeNumber(f.path, raw);
      if (_countFields.contains(f) && v > 9) {
        errors[f.path] = '范围 0～9';
        continue;
      }
      // 输入框为非负数值部分，计算状态保存带符号的基础硬币威力。
      if (f == MirrorField.coinPower && !_coinPowerAdd && v != 0) v = -v;
      values[f] = v;
    }

    // 2) 逐行参数：隐藏行保留编辑内容但不参与计算，其输入错误不阻塞计算。
    final countsKnown = _countFields.every(values.containsKey);
    final provisional = MirrorState(values: values, flags: _flags);
    final coins = <MirrorCoin>[];
    for (var row = 0; row < mirrorCoinRows; row++) {
      final active = countsKnown
          ? isRowActive(provisional, row)
          : isRowActive(_lastValid, row);
      var coin = MirrorCoin(extra: _extra[row]);
      for (final f in CoinField.values) {
        final text = coinText(row, f).text.trim();
        if (text.isEmpty) continue;
        final p = _parse(text);
        if (!p.isValid) {
          if (active) errors[f.pathFor(row)] = p.error!;
          continue;
        }
        coin = coin.withValue(f, sanitizeNumber(f.pathFor(row), p.value!));
      }
      coins.add(coin);
    }

    // 3) 循环记录：伤害留空为“未填写”；拼点区分未填写与不参与平均。
    var loops = MirrorLoops();
    for (final g in LoopGroup.values) {
      for (var i = 0; i < mirrorLoopLength; i++) {
        final dText = damageText(g, i).text.trim();
        if (dText.isNotEmpty) {
          final p = _parse(dText);
          if (p.isValid) {
            loops = loops.withDamage(
              g,
              i,
              sanitizeNumber('${g.name}.$i', p.value!),
            );
          } else {
            errors['${g.name}.$i'] = p.error!;
          }
        }
        final cText = clashText(g, i).text.trim();
        if (_clashSkipped[g]![i] && cText.isEmpty) {
          loops = loops.withClash(g, i, const LoopClash.skipped());
        } else if (cText.isNotEmpty) {
          final p = _parse(cText);
          if (p.isValid) {
            _clashSkipped[g]![i] = false;
            loops = loops.withClash(
              g,
              i,
              LoopClash.value(sanitizeNumber('${g.name}c.$i', p.value!)),
            );
          } else {
            errors['${g.name}c.$i'] = p.error!;
          }
        }
      }
    }
    _loops = loops;
    _errors = Map.unmodifiable(errors);

    final skillErrors = errors.keys.any((k) => !k.startsWith('loop'));
    if (skillErrors) {
      _state = null;
      _result = null;
    } else {
      final candidate = MirrorState(
        planName: planName.text,
        values: values,
        flags: _flags,
        coins: coins,
        faces: faces,
        loops: loops,
      );
      // 参考 refresh()：先 clearInactiveCoins，再 compute。清理只作用于计算副本，
      // 编辑器中隐藏行的内容与正反面保留，重新启用时恢复。
      final out = runPagePipeline(candidate);
      _state = out.state;
      _result = out.result;
      _lastValid = out.state;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    planName.dispose();
    for (final c in _fieldText.values) {
      c.dispose();
    }
    for (final row in _coinText) {
      for (final c in row.values) {
        c.dispose();
      }
    }
    for (final g in LoopGroup.values) {
      for (final c in [..._damageText[g]!, ..._clashText[g]!]) {
        c.dispose();
      }
    }
    super.dispose();
  }
}
