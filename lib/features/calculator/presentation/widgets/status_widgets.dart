import 'package:flutter/material.dart';

import '../../../../app_theme.dart';
import '../../models/calculation_input.dart';

/// 正 / 反 小标签。同时使用文字与颜色区分。
class FaceTag extends StatelessWidget {
  const FaceTag({super.key, required this.face});

  final CoinFace face;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final heads = face == CoinFace.heads;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: ShapeDecoration(
        color: heads ? palette.primarySoft : palette.neutralSoft,
        shape: smoothShape(
          AppRadius.tag,
          side: BorderSide(
            color: heads ? palette.primaryBorder : palette.border,
          ),
        ),
      ),
      child: Text(
        face.label,
        style: context.textStyles.labelSmall?.copyWith(
          color: heads ? palette.primary : palette.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}

enum NoticeTone { error, warning }

/// 错误 / 待确认提示块。
class StatusNotice extends StatelessWidget {
  const StatusNotice({
    super.key,
    required this.tone,
    required this.title,
    required this.lines,
  });

  final NoticeTone tone;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (color, background, border, icon) = switch (tone) {
      NoticeTone.error => (
        palette.error,
        palette.errorSoft,
        palette.errorBorder,
        Icons.error_outline,
      ),
      NoticeTone.warning => (
        palette.warning,
        palette.warningSoft,
        palette.warningBorder,
        Icons.help_outline,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: ShapeDecoration(
        color: background,
        shape: smoothShape(AppRadius.control, side: BorderSide(color: border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textStyles.titleSmall?.copyWith(color: color),
                ),
                for (final line in lines) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(line, style: numeric(context.textStyles.bodyMedium)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
