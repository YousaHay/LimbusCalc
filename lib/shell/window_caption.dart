import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Windows 桌面：让窗口标题栏跟随应用的浅色 / 深色页面背景。
/// 对应 windows/runner/flutter_window.cpp 中的 "limbus/window" 通道；其余平台不做任何事。
class WindowCaptionSync extends StatefulWidget {
  const WindowCaptionSync({
    super.key,
    required this.dark,
    required this.caption,
    required this.text,
    required this.child,
  });

  final bool dark;
  final Color caption;
  final Color text;
  final Widget child;

  static const channel = MethodChannel('limbus/window');

  @override
  State<WindowCaptionSync> createState() => _WindowCaptionSyncState();
}

class _WindowCaptionSyncState extends State<WindowCaptionSync> {
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(WindowCaptionSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dark != widget.dark ||
        oldWidget.caption != widget.caption ||
        oldWidget.text != widget.text) {
      _sync();
    }
  }

  void _sync() {
    if (!_supported) return;
    WindowCaptionSync.channel
        .invokeMethod<void>('setCaptionColors', {
          'caption': widget.caption.toARGB32(),
          'text': widget.text.toARGB32(),
          'dark': widget.dark,
        })
        // 标题栏颜色只是外观；通道不可用（如测试环境）时保持系统默认。
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
