import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../calculator_controller.dart';

/// 输入框上方的标签，可附带说明 Tooltip 与右侧简短提示。
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.tooltip, this.hint});

  final String text;
  final String? tooltip;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.textStyles.labelMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // 标签区占满剩余宽度，右侧提示保持自身宽度，避免两者平分空间导致标签被截断。
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    text,
                    style: style,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (tooltip != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Tooltip(
                    message: tooltip,
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (hint != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(hint!, style: numeric(context.textStyles.bodySmall)),
          ],
        ],
      ),
    );
  }
}

/// 绑定到 [CalculatorController] 的数值输入框，标签位于输入框上方。
///
/// 不使用输入过滤器：非法字符保留在框内并给出明确错误，而不是被静默吞掉。
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.field,
    this.label,
    this.tooltip,
    this.hint,
    this.suffixText,
    this.prefix,
    this.decimal = false,
    this.signed = false,
  });

  final CalculatorController controller;
  final CalculatorField field;

  /// 显示用标签；默认使用 [CalculatorField.label]。
  final String? label;
  final String? tooltip;
  final String? hint;
  final String? suffixText;
  final Widget? prefix;
  final bool decimal;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label ?? field.label, tooltip: tooltip, hint: hint),
        ShellTextField(
          fieldKey: ValueKey('field-${field.name}'),
          controller: controller.textOf(field),
          error: controller.errorOf(field),
          keyboardType: TextInputType.numberWithOptions(
            decimal: decimal,
            signed: signed,
          ),
          leading: prefix,
          trailing: suffixText == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      suffixText!,
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 统一的输入框外壳：外框高度固定为 [AppThemeContext.controlHeight]。
///
/// 填充式外观：静止时只有柔和的底色、没有描边；悬停时底色略变；
/// 聚焦显示主题色描边，出错显示错误色描边，状态之间平滑过渡。错误文字显示在外框下方。
///
/// 不依赖 InputDecorator 的内边距推算高度，因此在不同字体度量下都能与
/// 步进器、分段控件严格对齐。
class ShellTextField extends StatefulWidget {
  const ShellTextField({
    super.key,
    required this.fieldKey,
    required this.controller,
    this.error,
    this.keyboardType = TextInputType.number,
    this.textAlign = TextAlign.start,
    this.leading,
    this.trailing,
    this.hintText,
    this.enabled = true,
    this.onFocusLost,
    this.showErrorText = true,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String? error;
  final TextInputType keyboardType;
  final TextAlign textAlign;
  final String? hintText;
  final bool enabled;

  /// 失去焦点时回调（例如把输入回写为规范化后的值）。
  final VoidCallback? onFocusLost;

  /// 为 false 时只显示红色边框，错误文字由外部统一展示（如表格单元格）。
  final bool showErrorText;

  /// 输入区左侧 / 右侧的附加内容（符号、单位、步进按钮等）。
  final Widget? leading;
  final Widget? trailing;

  @override
  State<ShellTextField> createState() => _ShellTextFieldState();
}

class _ShellTextFieldState extends State<ShellTextField> {
  final _focusNode = FocusNode();
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    setState(() {});
    if (!_focusNode.hasFocus) widget.onFocusLost?.call();
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final focused = _focusNode.hasFocus;
    final error = widget.error;
    // 静止时描边透明（宽度不变，避免过渡时跳动）。
    final borderColor = error != null
        ? palette.error
        : focused
        ? palette.primary
        : Colors.transparent;
    final fill = !widget.enabled
        ? palette.surfaceMuted
        : _hovered && !focused
        ? palette.fieldHover
        : palette.field;
    final hasLeading = widget.leading != null;
    final hasTrailing = widget.trailing != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            height: context.controlHeight,
            decoration: ShapeDecoration(
              color: fill,
              shape: smoothShape(
                AppRadius.control,
                side: BorderSide(color: borderColor, width: 1.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?widget.leading,
                Expanded(
                  // 保持输入框自然高度并垂直居中；点击外框空白处同样聚焦。
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _focusNode.requestFocus,
                    child: Center(
                      child: TextField(
                        key: widget.fieldKey,
                        controller: widget.controller,
                        focusNode: _focusNode,
                        enabled: widget.enabled,
                        textAlign: widget.textAlign,
                        keyboardType: widget.keyboardType,
                        style: numeric(context.textStyles.bodyLarge),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          hintText: widget.hintText,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.only(
                            left: hasLeading ? 0 : AppSpacing.md,
                            right: hasTrailing ? AppSpacing.sm : AppSpacing.md,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ?widget.trailing,
              ],
            ),
          ),
        ),
        if (error != null && widget.showErrorText)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: AppSpacing.md),
            child: Text(
              error,
              style: Theme.of(context).inputDecorationTheme.errorStyle,
            ),
          ),
      ],
    );
  }
}

/// 两个字段并排；可用宽度不足时自动改为上下排列。
class TwoColumnFields extends StatelessWidget {
  const TwoColumnFields({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: AppSpacing.lg),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

/// 分段选择：与输入框同高的填充底槽 + 随选中项滑动的主题色滑块。
///
/// 与高级计算子页面按钮、悬浮底栏同一套动画（非线性曲线，系统减少动画时直接切换）。
/// 没有描边与分隔线；每段均可获得键盘焦点，并带有选中语义。
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final index = options.indexWhere((o) => o.$1 == selected);
    final thumbColor = Color.alphaBlend(
      palette.primary.withValues(alpha: dark ? 0.24 : 0.14),
      palette.field,
    );
    return Container(
      height: context.controlHeight,
      decoration: ShapeDecoration(
        color: palette.field,
        shape: smoothShape(AppRadius.control),
      ),
      padding: const EdgeInsets.all(_inset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / options.length;
          return Stack(
            children: [
              if (index >= 0)
                AnimatedPositioned(
                  duration: AppMotion.expandDuration(context),
                  curve: AppMotion.expandCurve,
                  left: itemWidth * index,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: thumbColor,
                        shape: smoothShape(AppRadius.control - _inset),
                      ),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (value, label) in options)
                    Expanded(
                      child: _Segment(
                        label: label,
                        selected: value == selected,
                        onTap: () => onChanged(value),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      // 选中背景由滑块绘制，这里保持透明，只负责点击与焦点环。
      child: FocusableTile(
        inkKey: ValueKey('segment-$label'),
        color: Colors.transparent,
        radius: AppRadius.control - SegmentedChoice._inset,
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: AnimatedDefaultTextStyle(
              duration: AppMotion.expandDuration(context),
              curve: AppMotion.expandCurve,
              style: context.textStyles.labelLarge!.copyWith(
                fontSize: 13.5,
                color: selected ? palette.primary : palette.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
    );
  }
}

/// 步进器内的圆形 − / + 按钮：位于输入框填充底色之内，以容器色的小圆底区分。
class StepIconButton extends StatelessWidget {
  const StepIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SizedBox(
      width: 44,
      child: Center(
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          style: IconButton.styleFrom(
            shape: const CircleBorder(),
            backgroundColor: palette.surface,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: palette.textPrimary,
            disabledForegroundColor: palette.disabled,
            fixedSize: const Size.square(32),
            minimumSize: const Size.square(32),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

/// 可点击的色块：获得键盘焦点时在内侧绘制 2px 主色描边。
///
/// 选中态本身已是浅蓝底，仅靠 InkWell 的焦点叠加色难以分辨，因此单独绘制焦点环。
class FocusableTile extends StatefulWidget {
  const FocusableTile({
    super.key,
    required this.color,
    required this.onTap,
    required this.child,
    this.inkKey,
    this.borderColor,
    this.radius = 0,
  });

  final Color color;
  final VoidCallback onTap;
  final Widget child;

  /// 传给内部 [InkWell] 的 key，便于测试定位点击目标。
  final Key? inkKey;
  final Color? borderColor;
  final double radius;

  @override
  State<FocusableTile> createState() => _FocusableTileState();
}

class _FocusableTileState extends State<FocusableTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final side = _focused
        ? BorderSide(
            color: palette.primary,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          )
        : widget.borderColor == null
        ? BorderSide.none
        : BorderSide(color: widget.borderColor!);
    return Material(
      color: widget.color,
      clipBehavior: Clip.antiAlias,
      shape: smoothShape(widget.radius, side: side),
      child: InkWell(
        key: widget.inkKey,
        onTap: widget.onTap,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: widget.child,
      ),
    );
  }
}
