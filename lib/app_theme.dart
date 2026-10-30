import 'package:flutter/material.dart';

import 'shell/system_ui.dart';

/// 打包的子集字体（见 tool/subset_fonts.py），保证离线也能正确显示中文。
const String appFontFamily = 'NotoSansSC';

/// 默认主题色。
const Color defaultSeedColor = Color(0xFF2563EB);

/// 基础间距。
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// 卡片之间的间距。
  static const double section = 20;
}

abstract final class AppRadius {
  /// 内容分组容器（参数、结果、设置分组）。
  static const double card = 24;

  /// 列表项、导航项等容器内部的可点击区域。
  static const double item = 14;
  static const double control = 12;
  static const double tag = 6;
}

abstract final class AppSizes {
  static const double contentMaxWidth = 1280;
  static const double sidebarWidth = 380;
  static const double controlHeight = 44;
  static const double tableRowHeight = 46;
  static const double tableHeaderHeight = 40;
  static const double coinTileWidth = 44;
  static const double coinTileHeight = 48;

  /// 可用宽度低于此值时使用窄屏间距（卡片内边距 16）。
  static const double compactWidth = 600;

  /// 内容区宽度达到此值时使用左右双栏。
  static const double twoColumnWidth = 880;

  /// 明细区宽度达到此值时使用表格，否则使用逐枚卡片。
  static const double breakdownTableWidth = 520;
}

/// 连续曲线圆角（超椭圆）：圆角与直边之间曲率连续过渡，没有普通圆角的“折点”。
/// 全应用的容器、按钮、输入框、选中背景等统一使用。
RoundedSuperellipseBorder smoothShape(
  double radius, {
  BorderSide side = BorderSide.none,
}) => RoundedSuperellipseBorder(
  borderRadius: BorderRadius.circular(radius),
  side: side,
);

/// 连续曲线圆角的输入框边框。
///
/// 只绘制完整边框，不为浮动标签留缺口：本应用的输入框标签都放在框外。
class SmoothInputBorder extends InputBorder {
  const SmoothInputBorder({
    super.borderSide = const BorderSide(),
    this.radius = AppRadius.control,
  });

  final double radius;

  RoundedSuperellipseBorder get _shape => smoothShape(radius, side: borderSide);

  @override
  bool get isOutline => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  SmoothInputBorder copyWith({BorderSide? borderSide}) => SmoothInputBorder(
    borderSide: borderSide ?? this.borderSide,
    radius: radius,
  );

  @override
  ShapeBorder scale(double t) =>
      SmoothInputBorder(borderSide: borderSide.scale(t), radius: radius * t);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is SmoothInputBorder
      ? SmoothInputBorder(
          borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
          radius: a.radius + (radius - a.radius) * t,
        )
      : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => b is SmoothInputBorder
      ? SmoothInputBorder(
          borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
          radius: radius + (b.radius - radius) * t,
        )
      : super.lerpTo(b, t);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) => _shape.paint(canvas, rect, textDirection: textDirection);

  @override
  bool operator ==(Object other) =>
      other is SmoothInputBorder &&
      other.borderSide == borderSide &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(borderSide, radius);
}

/// 展开 / 收起动画：非线性缓入缓出（起步平滑、中段较快、末段减速停稳），
/// 与页面的非线性滑动使用同一类曲线。系统开启“减少动画”时直接切换。
abstract final class AppMotion {
  static const Duration expand = Duration(milliseconds: 300);
  static const Curve expandCurve = Curves.easeInOutCubic;

  static Duration expandDuration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : expand;
}

/// 内容容器的左右边距（与计算页面一致）：窄屏 16，其余 32。
double contentGutter(double width) =>
    width < AppSizes.compactWidth ? AppSpacing.lg : AppSpacing.xxl;

/// 主题之外的语义颜色。组件通过 `context.palette` 读取，不直接写色值。
///
/// 层次：页面背景（含状态栏背后与标题区）→ 内容容器 → 容器内的控件。
/// 页面与容器保持中性色；主题色只用于按钮、选中、焦点与关键结果。
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.page,
    required this.surface,
    required this.surfaceMuted,
    required this.navBar,
    required this.navIndicator,
    required this.field,
    required this.fieldHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.primaryBorder,
    required this.neutralSoft,
    required this.hover,
    required this.error,
    required this.errorSoft,
    required this.errorBorder,
    required this.warning,
    required this.warningSoft,
    required this.warningBorder,
    required this.disabled,
  });

  /// 由明暗与主题色方案生成。中性色固定，强调色取自 [scheme]。
  factory AppPalette.resolve(Brightness brightness, ColorScheme scheme) {
    final dark = brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF252628) : const Color(0xFFFFFFFF);
    final navBar = dark ? const Color(0xFF303134) : const Color(0xFFFFFFFF);
    final primary = scheme.primary;
    Color tint(double alpha, Color base) =>
        Color.alphaBlend(primary.withValues(alpha: alpha), base);
    return AppPalette(
      page: dark ? const Color(0xFF111214) : const Color(0xFFF0F2F5),
      surface: surface,
      surfaceMuted: dark ? const Color(0xFF2D2E31) : const Color(0xFFF7F8FA),
      navBar: navBar,
      navIndicator: tint(dark ? 0.22 : 0.12, navBar),
      field: dark ? const Color(0xFF303135) : const Color(0xFFF1F3F6),
      fieldHover: dark ? const Color(0xFF37383C) : const Color(0xFFE9ECF0),
      textPrimary: dark ? const Color(0xFFE9EAEC) : const Color(0xFF17212F),
      textSecondary: dark ? const Color(0xFFA5A8AF) : const Color(0xFF526071),
      border: dark ? const Color(0xFF3D3F44) : const Color(0xFFE2E7EE),
      borderStrong: dark ? const Color(0xFF52555B) : const Color(0xFFCBD3DE),
      primary: primary,
      onPrimary: scheme.onPrimary,
      primarySoft: tint(dark ? 0.20 : 0.10, surface),
      primaryBorder: tint(dark ? 0.50 : 0.35, surface),
      neutralSoft: dark ? const Color(0xFF303134) : const Color(0xFFF1F4F8),
      hover: dark ? const Color(0xFF2E2F32) : const Color(0xFFF5F7FA),
      error: dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
      errorSoft: dark ? const Color(0xFF3A2224) : const Color(0xFFFEF2F2),
      errorBorder: dark ? const Color(0xFF6E3135) : const Color(0xFFF9CACA),
      warning: dark ? const Color(0xFFF2B84B) : const Color(0xFF9A5B00),
      warningSoft: dark ? const Color(0xFF3A3020) : const Color(0xFFFFFAEB),
      warningBorder: dark ? const Color(0xFF6B5524) : const Color(0xFFF5DDA3),
      disabled: dark ? const Color(0xFF6E727A) : const Color(0xFFA7B1BE),
    );
  }

  /// 页面背景：状态栏背后、标题区与内容容器之外的区域。
  final Color page;

  /// 内容容器背景。
  final Color surface;

  /// 容器内的次级区域（表头、只读值等）。
  final Color surfaceMuted;

  /// 悬浮底栏背景。
  final Color navBar;

  /// 导航选中项背景。
  final Color navIndicator;

  /// 输入框、分段选择等填充式控件的底色（位于内容容器之上）。
  final Color field;
  final Color fieldHover;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color borderStrong;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color primaryBorder;
  final Color neutralSoft;
  final Color hover;
  final Color error;
  final Color errorSoft;
  final Color errorBorder;
  final Color warning;
  final Color warningSoft;
  final Color warningBorder;
  final Color disabled;

  @override
  AppPalette copyWith() => this;

  /// 切换主题时逐色过渡（MaterialApp 的主题动画会调用）。
  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      page: l(page, other.page),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      navBar: l(navBar, other.navBar),
      navIndicator: l(navIndicator, other.navIndicator),
      field: l(field, other.field),
      fieldHover: l(fieldHover, other.fieldHover),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primarySoft: l(primarySoft, other.primarySoft),
      primaryBorder: l(primaryBorder, other.primaryBorder),
      neutralSoft: l(neutralSoft, other.neutralSoft),
      hover: l(hover, other.hover),
      error: l(error, other.error),
      errorSoft: l(errorSoft, other.errorSoft),
      errorBorder: l(errorBorder, other.errorBorder),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      warningBorder: l(warningBorder, other.warningBorder),
      disabled: l(disabled, other.disabled),
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  TextTheme get textStyles => Theme.of(this).textTheme;

  /// 卡片内边距：窄屏 16，其余 24。
  double get cardPadding =>
      MediaQuery.sizeOf(this).width < AppSizes.compactWidth
      ? AppSpacing.lg
      : AppSpacing.xl;

  /// 单行控件高度：默认约 44～46，随系统文字缩放增长，避免放大后溢出。
  double get controlHeight {
    final line = MediaQuery.textScalerOf(this).scale(15) * 1.45;
    final height = line + AppSpacing.sm * 2 + 4;
    return height < AppSizes.controlHeight ? AppSizes.controlHeight : height;
  }
}

/// 数字使用等宽数字，保证列对齐。
TextStyle numeric(TextStyle? style) => (style ?? const TextStyle()).copyWith(
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// 由主题色生成强调色方案。fidelity 变体尽量保留所选颜色的彩度，
/// 并由算法保证 primary / onPrimary 等成对颜色的对比度。
ColorScheme seedColorScheme(Color seed, Brightness brightness) =>
    ColorScheme.fromSeed(
      seedColor: seed.withValues(alpha: 1),
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

ThemeData buildAppTheme({
  Brightness brightness = Brightness.light,
  Color seed = defaultSeedColor,
}) {
  final dark = brightness == Brightness.dark;
  final seeded = seedColorScheme(seed, brightness);
  final p = AppPalette.resolve(brightness, seeded);
  // 只取主题色相关的角色，背景、文字、描边保持中性。
  final scheme = seeded.copyWith(
    error: p.error,
    onError: dark ? const Color(0xFF2B0E0E) : const Color(0xFFFFFFFF),
    surface: p.surface,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    outline: p.border,
    outlineVariant: p.border,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceMuted,
    surfaceContainerHighest: p.neutralSoft,
    inverseSurface: p.textPrimary,
    onInverseSurface: p.surface,
  );

  // 显式携带字体：组件主题（按钮、提示、错误文字等）直接引用这些样式，
  // 不会经过 ThemeData.fontFamily 的统一应用。
  TextStyle text(double size, FontWeight weight, Color color, {double? h}) =>
      TextStyle(
        fontFamily: appFontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: h,
      );

  final textTheme = TextTheme(
    displaySmall: text(48, FontWeight.w700, p.textPrimary, h: 1.1),
    headlineMedium: text(28, FontWeight.w700, p.textPrimary, h: 1.25),
    headlineSmall: text(22, FontWeight.w600, p.textPrimary, h: 1.3),
    titleLarge: text(18, FontWeight.w600, p.textPrimary, h: 1.35),
    titleMedium: text(16, FontWeight.w600, p.textPrimary, h: 1.4),
    titleSmall: text(14, FontWeight.w600, p.textPrimary, h: 1.4),
    bodyLarge: text(15, FontWeight.w400, p.textPrimary, h: 1.45),
    bodyMedium: text(14, FontWeight.w400, p.textPrimary, h: 1.5),
    bodySmall: text(12.5, FontWeight.w400, p.textSecondary, h: 1.45),
    labelLarge: text(14, FontWeight.w500, p.textPrimary),
    labelMedium: text(13, FontWeight.w500, p.textSecondary, h: 1.4),
    labelSmall: text(12, FontWeight.w500, p.textSecondary),
  );

  InputBorder inputBorder(Color color, [double width = 1]) => SmoothInputBorder(
    borderSide: BorderSide(color: color, width: width),
  );

  final controlShape = smoothShape(AppRadius.control);

  // 状态叠加色：按下期间不显示任何临时反馈（无遮罩、无水波纹），
  // 只保留键盘焦点与桌面悬停提示；选中等持久样式由各组件自身的颜色表达。
  WidgetStateProperty<Color?> overlay(Color base) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return Colors.transparent;
        if (states.contains(WidgetState.focused)) {
          return base.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return base.withValues(alpha: 0.06);
        }
        return null;
      });

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    fontFamily: appFontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: p.page,
    canvasColor: p.surface,
    dividerColor: p.border,
    hoverColor: p.hover,
    focusColor: p.primary.withValues(alpha: 0.12),
    // 全局取消按压反馈：InkWell / 列表项 / 菜单项等默认使用这三项。
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    extensions: [p],
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    // 二级页面（主题设置、许可证）的标题栏：与页面同色、左对齐，滚动后不变色。
    appBarTheme: AppBarTheme(
      backgroundColor: p.page,
      foregroundColor: p.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      systemOverlayStyle: systemUiStyleFor(brightness),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: smoothShape(AppRadius.card),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.primary,
      selectionColor: p.primary.withValues(alpha: 0.24),
      selectionHandleColor: p.primary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: p.field,
      hoverColor: p.fieldHover,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: inputBorder(Colors.transparent, 1.5),
      enabledBorder: inputBorder(Colors.transparent, 1.5),
      focusedBorder: inputBorder(p.primary, 1.5),
      errorBorder: inputBorder(p.error, 1.5),
      focusedErrorBorder: inputBorder(p.error, 1.5),
      disabledBorder: inputBorder(Colors.transparent, 1.5),
      hintStyle: textTheme.bodyMedium?.copyWith(color: p.disabled),
      suffixStyle: textTheme.bodyMedium?.copyWith(color: p.textSecondary),
      errorStyle: textTheme.bodySmall?.copyWith(color: p.error, fontSize: 12),
      errorMaxLines: 2,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: controlShape,
        minimumSize: const Size(0, 40),
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        textStyle: textTheme.labelLarge,
        elevation: 0,
      ).copyWith(overlayColor: overlay(p.onPrimary)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: controlShape,
        minimumSize: const Size(0, 40),
        side: BorderSide(color: p.borderStrong),
        foregroundColor: p.textPrimary,
        textStyle: textTheme.labelLarge,
      ).copyWith(overlayColor: overlay(p.textPrimary)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(controlShape),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        textStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(fontSize: 13.5),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? p.disabled : p.primary,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? p.disabled : p.primary,
        ),
        iconSize: const WidgetStatePropertyAll(16),
        overlayColor: overlay(p.primary),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(controlShape),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? p.disabled : p.textPrimary,
        ),
        overlayColor: overlay(p.textPrimary),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.borderStrong,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.neutralSoft,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.textSecondary,
      ),
      // 开关切换动画保留，只取消按住时滑块周围的光晕。
      overlayColor: overlay(p.primary),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.primary : p.textSecondary,
      ),
      overlayColor: overlay(p.primary),
    ),
    // 弹出菜单：与内容容器区分的底色、连续曲线圆角、轻阴影；菜单项按下时无高亮。
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(p.navBar),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(3),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.35),
        ),
        shape: WidgetStatePropertyAll(smoothShape(AppRadius.item)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.all(AppSpacing.xs + 2),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(controlShape),
        minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        textStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
        foregroundColor: WidgetStatePropertyAll(p.textPrimary),
        iconColor: WidgetStatePropertyAll(p.textSecondary),
        overlayColor: overlay(p.textPrimary),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 300),
      textStyle: textTheme.bodySmall?.copyWith(color: p.surface),
      decoration: ShapeDecoration(
        color: p.textPrimary,
        shape: smoothShape(AppRadius.tag),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.textPrimary,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: p.surface),
      shape: smoothShape(AppRadius.item),
      elevation: 2,
    ),
  );
}
