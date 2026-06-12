import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/database_service.dart';

class AppTheme {
  static bool isDark = false;

  static Color get background => isDark ? const Color(0xFF1E222B) : const Color(0xFFEFF2F6);
  static Color get shadowLight => isDark ? const Color(0xFF2C3240) : const Color(0xFFFFFFFF);
  static Color get shadowDark => isDark ? const Color(0xFF12141A) : const Color(0xFFD1D9E6);
  static Color get textPrimary => isDark ? const Color(0xFFEFF2F6) : const Color(0xFF1E272C);
  static Color get textSecondary => isDark ? const Color(0xFF8E9BA8) : const Color(0xFF687684);
  static Color get accentDark => isDark ? const Color(0xFFEFF2F6) : const Color(0xFF1A1F26);
  static Color get accentLight => isDark ? const Color(0xFF1E222B) : const Color(0xFFEFF2F6);
  static const Color accentRed = Color(0xFFE53935);

  static void setTheme(String themeMode) {
    isDark = themeMode == 'dark';
  }

  static ThemeData get themeData {
    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: accentDark,
      colorScheme: isDark
          ? ColorScheme.dark(
              background: background,
              surface: background,
              primary: accentDark,
              secondary: textSecondary,
              error: accentRed,
              onBackground: textPrimary,
              onSurface: textPrimary,
            )
          : ColorScheme.light(
              background: background,
              surface: background,
              primary: accentDark,
              secondary: textSecondary,
              error: accentRed,
              onBackground: textPrimary,
              onSurface: textPrimary,
            ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textSecondary,
        ),
      ),
      useMaterial3: true,
    );
  }

  static List<BoxShadow> get neumorphicShadows => [
        BoxShadow(
          color: shadowLight,
          offset: const Offset(-5, -5),
          blurRadius: 10,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: shadowDark,
          offset: const Offset(5, 5),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ];

  static List<BoxShadow> get neumorphicShadowsFlatSoft => [
        BoxShadow(
          color: shadowLight,
          offset: const Offset(-3, -3),
          blurRadius: 6,
          spreadRadius: 0.5,
        ),
        BoxShadow(
          color: shadowDark,
          offset: const Offset(3, 3),
          blurRadius: 6,
          spreadRadius: 0.5,
        ),
      ];

  static List<BoxShadow> get neumorphicShadowsPressed => [
        BoxShadow(
          color: shadowLight,
          offset: const Offset(3, 3),
          blurRadius: 5,
        ),
        BoxShadow(
          color: shadowDark,
          offset: const Offset(-3, -3),
          blurRadius: 5,
        ),
      ];
}

enum NeumorphicStyle {
  flat,
  concave,
  convex,
  pressed,
}

class NeumorphicBox extends ConsumerWidget {
  final Widget? child;
  final NeumorphicStyle style;
  final double borderRadius;
  final BoxShape shape;
  final Color? backgroundColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final AlignmentGeometry? alignment;
  final double shadowDepth;

  const NeumorphicBox({
    super.key,
    this.child,
    this.style = NeumorphicStyle.flat,
    this.borderRadius = 16.0,
    this.shape = BoxShape.rectangle,
    this.backgroundColor,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.alignment,
    this.shadowDepth = 1.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLowSpec = ref.watch(databaseProvider.select((s) => s.lowSpecMode));
    final bgColor = backgroundColor ?? AppTheme.background;
    final isCircular = shape == BoxShape.circle;
    final r = isCircular ? 0.0 : borderRadius;

    if (style == NeumorphicStyle.pressed) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        padding: padding,
        alignment: alignment,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: isCircular ? null : BorderRadius.circular(r),
          color: bgColor,
          border: Border.all(
            color: AppTheme.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.03),
            width: 1,
          ),
          gradient: isLowSpec ? null : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.shadowDark.withOpacity(0.4),
              bgColor,
              AppTheme.shadowLight.withOpacity(0.7),
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: child,
      );
    }

    // Standard raised Flat, Concave or Convex styling
    List<Color> gradientColors;
    if (style == NeumorphicStyle.concave) {
      gradientColors = [
        AppTheme.shadowDark.withOpacity(0.1),
        bgColor,
        AppTheme.shadowLight.withOpacity(0.15),
      ];
    } else if (style == NeumorphicStyle.convex) {
      gradientColors = [
        AppTheme.shadowLight.withOpacity(0.15),
        bgColor,
        AppTheme.shadowDark.withOpacity(0.1),
      ];
    } else {
      gradientColors = [bgColor, bgColor];
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: isCircular ? null : BorderRadius.circular(r),
        color: bgColor,
        border: isLowSpec
            ? Border.all(
                color: AppTheme.isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                width: 1,
              )
            : null,
        gradient: isLowSpec ? null : LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        boxShadow: isLowSpec ? null : [
          BoxShadow(
            color: AppTheme.shadowLight,
            offset: Offset(-4 * shadowDepth, -4 * shadowDepth),
            blurRadius: 8 * shadowDepth,
            spreadRadius: 0.5 * shadowDepth,
          ),
          BoxShadow(
            color: AppTheme.shadowDark,
            offset: Offset(4 * shadowDepth, 4 * shadowDepth),
            blurRadius: 8 * shadowDepth,
            spreadRadius: 0.5 * shadowDepth,
          ),
        ],
      ),
      child: child,
    );
  }
}
