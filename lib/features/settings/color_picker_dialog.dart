import 'package:flutter/material.dart';

import '../../app_theme.dart';
import 'app_settings.dart';

/// 自定义主题色：饱和度 / 明度面板 + 色相条 + #RRGGBB 输入。
/// 确认时返回所选颜色；取消返回 null，原颜色保持不变。不开放透明度。
Future<Color?> showColorPickerDialog(BuildContext context, Color initial) =>
    showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(initial: initial),
    );

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial.withValues(alpha: 1));
  late final _hex = TextEditingController(text: colorToHex(widget.initial));
  String? _error;

  Color get _color => _hsv.toColor();

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  /// 拖动面板时同步更新输入框。
  void _setHsv(HSVColor hsv) {
    setState(() {
      _hsv = hsv;
      _error = null;
      _hex.text = colorToHex(_color);
    });
  }

  void _onHexChanged(String text) {
    final color = parseHexColor(text);
    setState(() {
      if (color == null) {
        _error = '请输入 #RRGGBB 格式的颜色';
      } else {
        _error = null;
        // 保留当前色相，避免输入灰色时色相条跳回红色。
        final hsv = HSVColor.fromColor(color);
        _hsv = hsv.saturation == 0 ? hsv.withHue(_hsv.hue) : hsv;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AlertDialog(
      title: const Text('自定义颜色'),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SaturationValuePanel(hsv: _hsv, onChanged: _setHsv),
              const SizedBox(height: AppSpacing.md),
              _HueSlider(hsv: _hsv, onChanged: _setHsv),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左：原颜色；右：新颜色。
                  Semantics(
                    label: '颜色预览',
                    child: Container(
                      key: const ValueKey('color-preview'),
                      width: 64,
                      height: 44,
                      clipBehavior: Clip.antiAlias,
                      decoration: ShapeDecoration(
                        shape: smoothShape(
                          AppRadius.control,
                          side: BorderSide(color: palette.border),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: ColoredBox(color: widget.initial)),
                          Expanded(child: ColoredBox(color: _color)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('color-hex'),
                      controller: _hex,
                      onChanged: _onHexChanged,
                      maxLength: 7,
                      decoration: InputDecoration(
                        hintText: '十六进制 #RRGGBB',
                        counterText: '',
                        errorText: _error,
                      ),
                      style: numeric(context.textStyles.bodyLarge),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('color-cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('color-confirm'),
          onPressed: _error == null
              ? () => Navigator.pop(context, _color)
              : null,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 饱和度（横向）/ 明度（纵向）面板。
class _SaturationValuePanel extends StatelessWidget {
  const _SaturationValuePanel({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 180);
        void update(Offset p) {
          final s = (p.dx / size.width).clamp(0.0, 1.0);
          final v = 1 - (p.dy / size.height).clamp(0.0, 1.0);
          onChanged(hsv.withSaturation(s).withValue(v));
        }

        return Semantics(
          label: '饱和度与明度',
          child: GestureDetector(
            key: const ValueKey('color-sv-panel'),
            onPanDown: (d) => update(d.localPosition),
            onPanUpdate: (d) => update(d.localPosition),
            child: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: CustomPaint(size: size, painter: _SvPainter(hsv)),
            ),
          ),
        );
      },
    );
  }
}

class _SvPainter extends CustomPainter {
  _SvPainter(this.hsv);

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hue = HSVColor.fromAHSV(1, hsv.hue, 1, 1).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(colors: [Colors.white, hue])
            .createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
    final c = Offset(
      hsv.saturation * size.width,
      (1 - hsv.value) * size.height,
    );
    canvas.drawCircle(
      c,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(
      c,
      9.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black45,
    );
  }

  @override
  bool shouldRepaint(_SvPainter old) => old.hsv != hsv;
}

/// 色相条。
class _HueSlider extends StatelessWidget {
  const _HueSlider({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void update(Offset p) =>
            onChanged(hsv.withHue((p.dx / width).clamp(0.0, 1.0) * 360));
        return Semantics(
          label: '色相',
          child: GestureDetector(
            key: const ValueKey('color-hue'),
            onPanDown: (d) => update(d.localPosition),
            onPanUpdate: (d) => update(d.localPosition),
            child: CustomPaint(
              size: Size(width, 28),
              painter: _HuePainter(hsv.hue),
            ),
          ),
        );
      },
    );
  }
}

class _HuePainter extends CustomPainter {
  _HuePainter(this.hue);

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RSuperellipse.fromRectAndRadius(
      Rect.fromLTWH(0, 6, size.width, size.height - 12),
      const Radius.circular(8),
    );
    canvas.drawRSuperellipse(
      track,
      Paint()
        ..shader = LinearGradient(
          colors: [
            for (var h = 0; h <= 360; h += 60)
              HSVColor.fromAHSV(1, h.toDouble(), 1, 1).toColor(),
          ],
        ).createShader(track.outerRect),
    );
    final x = hue / 360 * size.width;
    final thumb = Offset(x.clamp(8, size.width - 8), size.height / 2);
    canvas.drawCircle(thumb, 11, Paint()..color = Colors.white);
    canvas.drawCircle(
      thumb,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black26,
    );
    canvas.drawCircle(
      thumb,
      7,
      Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
    );
  }

  @override
  bool shouldRepaint(_HuePainter old) => old.hue != hue;
}
