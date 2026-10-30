import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import 'number_field.dart';

/// 硬币威力输入：加算 / 减算分段控件 + 非负数值，输入框前显示生效符号。
///
/// 只负责外观与交互，不依赖任何计算器的模型；符号以 [isAdd] 表示。
class SignedPowerInput extends StatelessWidget {
  const SignedPowerInput({
    super.key,
    required this.isAdd,
    required this.onAddChanged,
    required this.controller,
    required this.fieldKey,
    required this.signKey,
    required this.prefixKey,
    this.error,
    this.label = '硬币威力',
    this.tooltip,
    this.onFocusLost,
    this.footer,
  });

  final bool isAdd;
  final ValueChanged<bool> onAddChanged;
  final TextEditingController controller;
  final Key fieldKey;
  final Key signKey;
  final Key prefixKey;
  final String? error;
  final String label;
  final String? tooltip;
  final VoidCallback? onFocusLost;

  /// 输入行下方的补充说明（如实际生效值）。
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label, tooltip: tooltip),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: SegmentedChoice<bool>(
                key: signKey,
                options: const [(true, '加算'), (false, '减算')],
                selected: isAdd,
                onChanged: onAddChanged,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ShellTextField(
                fieldKey: fieldKey,
                controller: controller,
                error: error,
                onFocusLost: onFocusLost,
                leading: Semantics(
                  label: isAdd ? '加算' : '减算',
                  child: SizedBox(
                    width: 32,
                    child: Center(
                      child: Text(
                        isAdd ? '+' : '−',
                        key: prefixKey,
                        style: numeric(context.textStyles.bodyLarge).copyWith(
                          color: palette.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (footer != null) ...[const SizedBox(height: 6), footer!],
      ],
    );
  }
}

/// 单枚硬币的正 / 反按钮：尺寸一致的圆角方块，同时用文字与颜色区分。
class CoinFaceTile extends StatelessWidget {
  const CoinFaceTile({
    super.key,
    required this.inkKey,
    required this.heads,
    required this.caption,
    required this.semanticLabel,
    required this.onTap,
  });

  final Key inkKey;
  final bool heads;

  /// 方块下方的小字（序号，如“1”或“重1”）。
  final String caption;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: FocusableTile(
        inkKey: inkKey,
        color: heads ? palette.primarySoft : palette.neutralSoft,
        borderColor: heads ? palette.primaryBorder : palette.border,
        radius: AppRadius.control,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSizes.coinTileWidth,
            minHeight: AppSizes.coinTileHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                heads ? '正' : '反',
                style: context.textStyles.titleSmall?.copyWith(
                  color: heads ? palette.primary : palette.textSecondary,
                  height: 1.2,
                ),
              ),
              Text(
                caption,
                style: numeric(context.textStyles.labelSmall)
                    .copyWith(fontSize: 11, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
