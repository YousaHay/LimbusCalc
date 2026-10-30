/// 复刻 MirrorCalcWeb（JavaScript）数值语义的辅助函数。
///
/// Dart 的同名方法与 JavaScript 存在差异（如 `round()` 的半整数方向），
/// 因此这里逐一按参考源码的实际行为实现，不能直接替换为 Dart 内置方法。
library;

import 'dart:math' as math;

/// 参考 `num()`：非有限数视为 0。
double numOf(double v) => v.isFinite ? v : 0.0;

/// JavaScript `Math.round`：最接近的整数，半整数向 +∞（`-2.5 → -2`，`2.5 → 3`）。
///
/// 不能写成 `(x + 0.5).floor()`：当 x = 0.49999999999999994 时 x + 0.5 会舍入为 1。
double jsRound(double x) {
  if (!x.isFinite) return x;
  final floor = x.floorToDouble();
  final rounded = x - floor >= 0.5 ? floor + 1 : floor;
  // Math.round 对 (-0.5, -0] 返回 -0。
  return rounded == 0 && x < 0 ? -0.0 : rounded;
}

/// 参考 `excelRound(v, d)`：Excel ROUND（四舍五入，负数远离零），含参考的浮点修正步骤。
double excelRound(double v, int d) {
  v = numOf(v);
  final m = math.pow(10.0, d).toDouble();
  var x = v * m;
  x = jsRound(x * 1e6) / 1e6;
  final s = x < 0 ? -1.0 : 1.0;
  return s * jsRound(x.abs() + 1e-9) / m;
}

/// 参考 `excelInt(v)`：Excel INT（向下取整），与最近整数相差 1e-9 以内时吸附到该整数。
double excelInt(double v) {
  v = numOf(v);
  final r = jsRound(v);
  if ((v - r).abs() < 1e-9) return r;
  return v.floorToDouble();
}
