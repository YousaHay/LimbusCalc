import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app_theme.dart';
import '../../models/calculation_result.dart';
import '../calculation_summary.dart';
import '../calculator_controller.dart';
import 'section_card.dart';
import 'status_widgets.dart';

/// 结果摘要：总伤害为视觉焦点，下方为逐枚构成与正反面。
class DamageResultCard extends StatefulWidget {
  const DamageResultCard({super.key, required this.controller});

  final CalculatorController controller;

  @override
  State<DamageResultCard> createState() => _DamageResultCardState();
}

class _DamageResultCardState extends State<DamageResultCard> {
  bool _scopeExpanded = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final result = controller.result;
    final palette = context.palette;
    return SectionCard(
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('技能直接伤害', style: context.textStyles.labelMedium),
              ),
              TextButton.icon(
                key: const ValueKey('copy-button'),
                onPressed: result == null ? null : () => _copy(result),
                icon: const Icon(Icons.content_copy_outlined),
                label: const Text('复制摘要'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (result == null)
            _InputErrors(errors: controller.errors)
          else if (!result.isOk)
            _BoundaryNotice(result: result)
          else
            _Total(result: result),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: palette.border),
          const SizedBox(height: AppSpacing.sm),
          _ScopeLine(
            expanded: _scopeExpanded,
            onToggle: () => setState(() => _scopeExpanded = !_scopeExpanded),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(CalculationResult result) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: buildCalculationSummary(result)),
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('已复制计算摘要'),
          duration: Duration(seconds: 2),
        ),
      );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.result});

  final CalculationResult result;

  @override
  Widget build(BuildContext context) {
    final styles = context.textStyles;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${result.totalDamage}',
          key: const ValueKey('total-damage'),
          style: numeric(styles.displaySmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.coins.map((c) => c.finalDamage).join(' + '),
          key: const ValueKey('per-coin-damage'),
          style: numeric(styles.bodyLarge)
              .copyWith(color: context.palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        _FaceSequence(result: result),
      ],
    );
  }
}

class _FaceSequence extends StatelessWidget {
  const _FaceSequence({required this.result});

  final CalculationResult result;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const ValueKey('face-sequence'),
      spacing: AppSpacing.xs + 2,
      runSpacing: AppSpacing.xs + 2,
      children: [
        for (final face in result.input.coinFaces) FaceTag(face: face),
      ],
    );
  }
}

class _BoundaryNotice extends StatelessWidget {
  const _BoundaryNotice({required this.result});

  final CalculationResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xs),
        StatusNotice(
          key: const ValueKey('boundary-notice'),
          tone: NoticeTone.warning,
          title: '伤害未输出：威力降至 0 或以下',
          lines: [
            '各次命中威力：${result.powerSteps.map((s) => s.hitPower).join(' / ')}'
                '（正反面：${formatFaces(result.input.coinFaces)}）',
            '现有资料无法确认此时游戏是否钳制威力、钳制是否影响后续累计，'
                '因此不给出确定伤害。“伤害至少为 1”不等于“威力至少为 1”。',
          ],
        ),
      ],
    );
  }
}

class _InputErrors extends StatelessWidget {
  const _InputErrors({required this.errors});

  final Map<CalculatorField, String> errors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xs),
        StatusNotice(
          key: const ValueKey('input-error-notice'),
          tone: NoticeTone.error,
          title: '输入有误，当前没有有效结果',
          lines: [
            for (final entry in errors.entries)
              '${entry.key.label}：${entry.value}',
          ],
        ),
      ],
    );
  }
}

class _ScopeLine extends StatelessWidget {
  const _ScopeLine({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final small = context.textStyles.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, size: 14, color: palette.textSecondary),
            const SizedBox(width: 6),
            Expanded(child: Text('仅含普通硬币直接伤害', style: small)),
            TextButton(
              key: const ValueKey('scope-toggle'),
              onPressed: onToggle,
              style: TextButton.styleFrom(
                foregroundColor: palette.textSecondary,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('计算范围说明'),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(Icons.expand_more, size: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: AppMotion.expandDuration(context),
          curve: AppMotion.expandCurve,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    '$calculationScopeNote'
                    '所有硬币视为保留并命中同一目标，攻击期间抗性、攻防等级与增减伤不变。'
                    '计算使用 Dart 64 位浮点，游戏内部为 32 位浮点，不保证逐位一致。',
                    key: const ValueKey('scope-detail'),
                    style: small,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
