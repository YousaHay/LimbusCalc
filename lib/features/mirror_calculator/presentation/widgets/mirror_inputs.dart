import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../../calculator/presentation/widgets/number_field.dart';
import '../../models/mirror_state.dart';
import '../mirror_controller.dart';

/// 按可用宽度自动分列的字段网格（每列不窄于 [minItemWidth]，最多 [maxColumns] 列）。
class FieldGrid extends StatelessWidget {
  const FieldGrid({
    super.key,
    required this.children,
    this.minItemWidth = 140,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.md;
        final columns = ((constraints.maxWidth + gap) / (minItemWidth + gap))
            .floor()
            .clamp(1, maxColumns);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: AppSpacing.lg,
          children: [
            for (final c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

/// 分组小标题（可带说明 Tooltip）。
class GroupTitle extends StatelessWidget {
  const GroupTitle(this.text, {super.key, this.tooltip});

  final String text;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Text(text, style: context.textStyles.titleSmall),
          if (tooltip != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Tooltip(
              message: tooltip,
              child: Icon(
                Icons.info_outline,
                size: 14,
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 技能 / 全局数值字段：顶部标签 + 统一输入框；失焦时回写规范化后的值。
class MirrorFieldInput extends StatelessWidget {
  const MirrorFieldInput({
    super.key,
    required this.controller,
    required this.field,
    this.tooltip,
    this.hint,
    this.suffix,
  });

  final MirrorController controller;
  final MirrorField field;
  final String? tooltip;
  final String? hint;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(field.label, tooltip: tooltip, hint: hint),
        ShellTextField(
          fieldKey: ValueKey('mirror-field-${field.path}'),
          controller: controller.fieldText(field),
          error: controller.errorOf(field.path),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          hintText: '0',
          onFocusLost: () => controller.commitField(field),
          trailing: suffix == null ? null : _Suffix(suffix!),
        ),
      ],
    );
  }
}

class _Suffix extends StatelessWidget {
  const _Suffix(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Center(
        widthFactor: 1,
        child: Text(text, style: context.textStyles.bodySmall),
      ),
    );
  }
}

/// 是 / 否 开关字段，外观与输入框一致。
class MirrorSwitchField extends StatelessWidget {
  const MirrorSwitchField({
    super.key,
    required this.controller,
    required this.flag,
    this.tooltip,
    this.enabled = true,
    this.disabledText,
  });

  final MirrorController controller;
  final MirrorFlag flag;
  final String? tooltip;
  final bool enabled;
  final String? disabledText;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final on = controller.flag(flag);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(flag.label, tooltip: tooltip),
        Material(
          color: enabled ? palette.field : palette.surfaceMuted,
          shape: smoothShape(AppRadius.control),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? () => controller.setFlag(flag, !on) : null,
            canRequestFocus: false,
            child: SizedBox(
              height: context.controlHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        enabled ? (on ? '是' : '否') : (disabledText ?? '—'),
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: enabled ? null : palette.textSecondary,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        key: ValueKey('mirror-flag-${flag.path}'),
                        value: on && enabled,
                        onChanged: enabled
                            ? (v) => controller.setFlag(flag, v)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 0～9 的数量步进器（硬币数量 / 重投次数）。
class MirrorCountStepper extends StatelessWidget {
  const MirrorCountStepper({
    super.key,
    required this.controller,
    required this.field,
    this.tooltip,
    this.enabled = true,
  });

  final MirrorController controller;
  final MirrorField field;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final count = controller.lastValid[field];
    Widget button(IconData icon, String tip, int delta, bool can) =>
        StepIconButton(
          key: ValueKey('mirror-${field.path}-${delta < 0 ? 'minus' : 'plus'}'),
          icon: icon,
          tooltip: tip,
          onPressed: enabled && can
              ? () => controller.changeCount(field, delta)
              : null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(field.label, tooltip: tooltip, hint: '0～9'),
        ShellTextField(
          fieldKey: ValueKey('mirror-field-${field.path}'),
          controller: controller.fieldText(field),
          error: controller.errorOf(field.path),
          enabled: enabled,
          textAlign: TextAlign.center,
          onFocusLost: () => controller.commitField(field),
          leading: button(
            Icons.remove,
            count > 0 ? '减少一个' : '已达下限 0',
            -1,
            count > 0,
          ),
          trailing: button(
            Icons.add,
            count < 9 ? '增加一个' : '已达上限 9',
            1,
            count < 9,
          ),
        ),
      ],
    );
  }
}
