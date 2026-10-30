/// 文本输入的严格解析。只接受普通十进制写法，拒绝 NaN、Infinity、科学计数法等。
library;

final RegExp _integerPattern = RegExp(r'^[+-]?\d+$');
final RegExp _decimalPattern = RegExp(r'^[+-]?(\d+(\.\d*)?|\.\d+)$');

/// 解析结果：要么有值，要么有面向用户的错误提示。
class ParseResult<T extends num> {
  const ParseResult.value(T this.value) : error = null;
  const ParseResult.error(String this.error) : value = null;

  final T? value;
  final String? error;

  bool get isValid => error == null;
}

ParseResult<int> parseIntInRange(
  String text, {
  required int min,
  required int max,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const ParseResult.error('请输入数值');
  if (!_integerPattern.hasMatch(trimmed)) {
    return const ParseResult.error('请输入整数');
  }
  final value = int.tryParse(trimmed);
  if (value == null || value < min || value > max) {
    return ParseResult.error('范围 $min～$max');
  }
  return ParseResult.value(value);
}

ParseResult<double> parseDecimalInRange(
  String text, {
  required double min,
  required double max,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const ParseResult.error('请输入数值');
  if (!_decimalPattern.hasMatch(trimmed)) {
    return const ParseResult.error('请输入数字');
  }
  final value = double.tryParse(trimmed);
  if (value == null || !value.isFinite) {
    return const ParseResult.error('请输入有限数值');
  }
  if (value < min || value > max) {
    return ParseResult.error('范围 ${_trim(min)}～${_trim(max)}');
  }
  return ParseResult.value(value);
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
