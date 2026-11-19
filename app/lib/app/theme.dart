import 'package:material_ui/material_ui.dart';

/// 设计令牌：与原型 prototype/css/app.css 的 :root 一致（UI 以原型为准）。
abstract final class AppColors {
  static const bg = Color(0xFFF4F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF1F3F6);
  static const text = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const line = Color(0xFFE6E8EC);
  static const primary = Color(0xFF0E7C66);
  static const primary2 = Color(0xFF0A5E4E);
  static const primaryWeak = Color(0xFFE6F3EF);
  static const accent = Color(0xFF1F4E79);
  static const up = Color(0xFF15803D);
  static const down = Color(0xFFDC2626);
  static const warn = Color(0xFFB45309);
  static const warnWeak = Color(0xFFFFF6E5);
  static const danger = Color(0xFFDC2626);
  static const dangerWeak = Color(0xFFFDEDED);
  static const infoWeak = Color(0xFFEDF3FA);
  static const infoText = Color(0xFF1E3A5F);
  static const warnText = Color(0xFF7A4A06);
  static const dangerText = Color(0xFF8A1C1C);
}

/// 圆角与阴影（原型 --radius: 14px，--shadow）。
abstract final class AppShape {
  static const radius = 14.0;
  static const controlRadius = 12.0; // .btn
  static const inputRadius = 10.0; // .input
  static const shadow = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 14, offset: Offset(0, 4)),
  ];
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text),
      shape: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      hintStyle: const TextStyle(color: AppColors.faint, fontSize: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
      side: const BorderSide(color: AppColors.faint, width: 1.5),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xEB0F172A),
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
  );
}
