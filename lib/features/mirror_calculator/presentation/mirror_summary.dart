import '../models/mirror_result.dart';
import '../models/mirror_state.dart';
import 'mirror_format.dart';

/// 复制用的计算摘要（参考 resultText 的内容，补充伤害构成）。
String buildMirrorSummary(MirrorState s, MirrorResult r) {
  final reroll = s.flag(MirrorFlag.reroll)
      ? '（重投 ${mirrorNum(s[MirrorField.rerollCount])} 次）'
      : '';
  final lines = [
    '【高级计算】',
    if (s.planName.trim().isNotEmpty) '方案：${s.planName.trim()}',
    '硬币数：${mirrorNum(s[MirrorField.coinCount])}$reroll',
    '硬币威力：${s[MirrorField.coinPower] < 0 ? '减算' : '加算'} '
        '${mirrorNum(s[MirrorField.coinPower].abs())}，最终硬币威力 ${mirrorNum(r.finalCoin)}',
    '正反面：${_faces(r, reroll: false)}'
        '${r.activeRerolls > 0 ? ' · 重投：${_faces(r, reroll: true)}' : ''}',
    '',
    '拼点点数：${mirrorNum(r.clash)}',
    '总伤害：${mirrorNum(r.total)}',
    '  直接伤害 ${mirrorNum(r.sumJ)} · 比例追伤 ${mirrorNum(r.sumN)}'
        ' · 固定追伤 ${mirrorNum(r.sumFixedPart)}',
    '',
    '第一循环：${mirrorNum(r.loop1)}',
    '第二循环：${mirrorNum(r.loop2)}',
    '两轮循环总和：${mirrorNum(r.loop12)}',
    '极限循环：${mirrorNum(r.loop3)}',
    '',
    '说明：正面应用最终硬币威力、反面不应用；呼吸法暴击为线性折算（估算）；'
        '拼点为点数而非胜率，且沿用全正面假设。',
    '计算模型移植自 MirrorCalcWeb（f0lkskill，MIT License）。',
  ];
  return lines.join('\n');
}

String _faces(MirrorResult r, {required bool reroll}) {
  final faces = [
    for (final row in r.activeRows)
      if (row.isReroll == reroll) row.face.label,
  ];
  return faces.isEmpty ? '—' : faces.join(' ');
}
