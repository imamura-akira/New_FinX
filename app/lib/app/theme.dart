import 'package:material_ui/material_ui.dart';

/// 设计令牌：FinX 主题（design/theme.md 为唯一视觉基准；与原型 prototype/css/app.css :root 一致）。
abstract final class AppColors {
  static const bg = Color(0xFFF6F5FC); // 浅薰衣草
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF3F2FA);
  static const text = Color(0xFF171A2E);
  static const muted = Color(0xFF6B7191);
  static const faint = Color(0xFF9BA0B8);
  static const line = Color(0xFFE9E8F4);
  static const primary = Color(0xFF6C5BF5); // 紫罗兰
  static const primary2 = Color(0xFF4F3ED9);
  static const primaryWeak = Color(0xFFEFECFE);
  static const accent = Color(0xFF3B82F6);
  static const up = Color(0xFF16A34A); // 美式绿涨红跌
  static const down = Color(0xFFE5484D);
  static const warn = Color(0xFFB45309);
  static const warnWeak = Color(0xFFFFF6E5);
  static const danger = Color(0xFFE5484D);
  static const dangerWeak = Color(0xFFFDEDEE);
  static const infoWeak = Color(0xFFEDF2FD);
  static const infoText = Color(0xFF1E3A5F);
  static const warnText = Color(0xFF7A4A06);
  static const dangerText = Color(0xFF8A1C1C);

  // 资产配置环图
  static const allocCash = Color(0xFF6C5BF5);
  static const allocStock = Color(0xFFD63AA8);
  static const allocEtf = Color(0xFFF0A13C);
}

/// 渐变（design/theme.md 第 1 节）。CSS 角度换算为 Alignment。
abstract final class AppGradients {
  /// 主 CTA 按钮：100deg #5A57EE → #A944D8 55% → #D63AA8
  static const grad = LinearGradient(
    begin: Alignment(-1, -0.18),
    end: Alignment(1, 0.18),
    colors: [Color(0xFF5A57EE), Color(0xFFA944D8), Color(0xFFD63AA8)],
    stops: [0, .55, 1],
  );

  /// 小选中态、mark：135deg #7D5CF0 → #C13AC8
  static const gradSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7D5CF0), Color(0xFFC13AC8)],
  );

  /// 资产总览大卡：135deg #7D4DF0 → #A944D8 55% → #D63AA8
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7D4DF0), Color(0xFFA944D8), Color(0xFFD63AA8)],
    stops: [0, .55, 1],
  );

  /// 预告卡（Fifi / 奖励）
  static const soon = LinearGradient(
    begin: Alignment(-1, -0.6),
    end: Alignment(1, 0.6),
    colors: [Color(0xFF4A43E8), Color(0xFF8A3FE0), Color(0xFFD63AA8)],
  );
}

/// 形状与投影（design/theme.md 第 2 节）。
abstract final class AppShape {
  static const radius = 18.0; // 卡片
  static const radiusLarge = 22.0; // 大卡
  static const buttonRadius = 24.0; // 主按钮全圆角（高 48）
  static const smallButtonRadius = 17.0; // 小按钮（高 34）
  static const inputRadius = 15.0; // 输入框（高 50，1.5px 描边）
  static const shadow = [
    BoxShadow(color: Color(0x0D2A2260), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x122A2260), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

/// 品牌素材（app/assets/brand，来源 prototype/assets/）。
abstract final class BrandAssets {
  static const logo = 'assets/brand/logo.png';
  static const fifiPill = 'assets/brand/fifi_pill.png';
  static const fifiPaw = 'assets/brand/fifi_paw.png';
  static const fifiAvatar = 'assets/brand/fifi_avatar.png';

  /// F16 P-27 圣诞季限定：圣诞毛衣 Fifi（透明背景，来源 design/reward-design/cat_xmas.png）。
  static const catXmas = 'assets/brand/cat_xmas.png';
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.faint, fontSize: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        borderSide: const BorderSide(color: AppColors.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        borderSide: const BorderSide(color: AppColors.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppShape.inputRadius),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
      side: const BorderSide(color: AppColors.faint, width: 1.5),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xEB171A2E),
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
  );
}
