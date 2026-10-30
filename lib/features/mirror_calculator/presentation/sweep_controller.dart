import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../calculator/presentation/input_parsing.dart';
import '../domain/mirror_sweep.dart';
import '../models/mirror_state.dart';
import 'mirror_format.dart';

/// 参数扫描的界面状态：分批执行、可取消、结果过期判定。
///
/// 扫描只读取启动时的状态快照，不会修改正在编辑的参数。
class SweepController extends ChangeNotifier {
  SweepController() {
    _applyDefaults(_param);
    for (final c in [fromText, toText, stepText]) {
      c.addListener(_validate);
    }
    _validate();
  }

  /// 每批计算的点数；每批之后让出事件循环，避免阻塞界面。
  static const int batchSize = 20;

  final fromText = TextEditingController();
  final toText = TextEditingController();
  final stepText = TextEditingController();

  SweepParam _param = SweepParam.breath;
  Map<String, String> _inputErrors = const {};
  SweepPlan? _plan;

  int _jobId = 0;
  bool _running = false;
  SweepParam? _resultParam;
  MirrorState? _snapshot;
  double _snapshotSign = 1;
  SweepPlanOk? _resultPlan;
  final List<SweepPoint> _points = [];
  String? _runError;

  SweepParam get param => _param;
  String? inputError(String key) => _inputErrors[key];

  /// 当前区间的校验结果（参考 runSweep 的规则）；输入非法时为 null。
  SweepPlan? get plan => _plan;
  bool get running => _running;
  String? get runError => _runError;
  SweepParam? get resultParam => _resultParam;
  MirrorState? get snapshot => _snapshot;
  SweepPlanOk? get resultPlan => _resultPlan;
  List<SweepPoint> get points => List.unmodifiable(_points);
  bool get hasResult => _points.isNotEmpty;
  bool get complete =>
      _resultPlan != null && _points.length == _resultPlan!.count;

  /// 扫描时硬币威力的加减算符号（+1 / −1）。
  double get snapshotSign => _snapshotSign;

  /// 当前输入（含正反面与加减算）与扫描快照不同：旧结果已过期。
  bool isStaleFor(MirrorState? current, {double coinPowerSign = 1}) =>
      _snapshot != null &&
      (current == null ||
          !_snapshot!.sameCalculationInputs(current) ||
          coinPowerSign != _snapshotSign);

  void setParam(SweepParam p) {
    if (p == _param) return;
    _param = p;
    _applyDefaults(p);
  }

  /// 恢复参考 SWEEP_DEF 中的默认区间。
  void resetRange() => _applyDefaults(_param);

  void _applyDefaults(SweepParam p) {
    fromText.text = mirrorNum(p.from);
    toText.text = mirrorNum(p.to);
    stepText.text = mirrorNum(p.step);
  }

  void _validate() {
    final errors = <String, String>{};
    double? read(String key, TextEditingController c) {
      final r = parseDecimalInRange(c.text, min: -99999, max: 99999);
      if (!r.isValid) errors[key] = r.error!;
      return r.value;
    }

    final from = read('from', fromText);
    final to = read('to', toText);
    final step = read('step', stepText);
    _inputErrors = Map.unmodifiable(errors);
    _plan = errors.isEmpty ? planSweep(from!, to!, step!) : null;
    notifyListeners();
  }

  /// 以 [base] 为快照启动扫描。新的扫描会使正在进行的旧任务失效。
  /// [coinPowerSign] 为当前加减算符号，扫描“硬币威力”时带上该符号。
  Future<void> start(MirrorState base, {double coinPowerSign = 1}) async {
    final plan = _plan;
    if (plan is! SweepPlanOk) return;
    final job = ++_jobId;
    _running = true;
    _runError = null;
    _snapshot = base;
    _snapshotSign = coinPowerSign;
    _resultParam = _param;
    _resultPlan = plan;
    _points.clear();
    notifyListeners();

    final param = _param;
    for (var i = 0; i < plan.count; i++) {
      if (job != _jobId) return; // 已取消或被新任务取代
      _points.add(
        computeSweepPoint(
          base,
          param,
          plan.valueAt(i),
          coinPowerSign: coinPowerSign,
        ),
      );
      if ((i + 1) % batchSize == 0 && i + 1 < plan.count) {
        notifyListeners();
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (job != _jobId) return;
    _running = false;
    notifyListeners();
  }

  /// 取消正在进行的扫描；已算出的点保留并标记为未完成。
  void cancel() {
    if (!_running) return;
    _jobId++;
    _running = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _jobId++;
    fromText.dispose();
    toText.dispose();
    stepText.dispose();
    super.dispose();
  }
}
