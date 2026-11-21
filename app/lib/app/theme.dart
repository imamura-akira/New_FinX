import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:material_ui/material_ui.dart';

/// 设计令牌：AK Stocks 主题（design/theme.md 为唯一视觉基准）。
/// F21：浅色 / 深色两套色板（theme.md 第 10 节）；页面一律通过 [AppColors] 等令牌取色，不写死颜色。
class AppPalette {
  const AppPalette({required this.brightness, required this.bg, required this.surface, required this.surface2, required this.text, required this.muted, required this.faint, required this.line, required this.primary, required this.primary2, required this.primaryWeak, required this.accent, required this.up, required this.upWeak, required this.down, required this.warn, required this.warnWeak, required this.danger, required this.dangerWeak, required this.infoWeak, required this.infoText, required this.warnText, required this.dangerText, required this.onAccent, required this.toast, required this.shadow, required this.allocCash, required this.allocStock, required this.allocEtf, required this.ink, required this.sub, required this.hint, required this.track, required this.pill, required this.chip, required this.divider, required this.panel, required this.border, required this.flat, required this.needle, required this.coin, required this.upBorder, required this.downBorder, required this.goldWeak, required this.goldText, required this.cardShadow, required this.cardShadow2});
  final Brightness brightness;
  final Color bg; // 页面背景
  final Color surface; // 卡片 / 弹层 / 输入框
  final Color surface2; // 次级底、图标底
  final Color text; // 主文字
  final Color muted; // 次要文字
  final Color faint; // 弱文字、占位
  final Color line; // 分隔线、描边
  final Color primary; // 品牌紫（深色下提亮一档）
  final Color primary2; // 主色强调文字（浅底上的深紫 / 深底上的亮紫）
  final Color primaryWeak; // 主色浅底（badge、选中底）
  final Color accent; // 信息蓝
  final Color up; // 涨（美式绿涨红跌）
  final Color upWeak; // 涨的浅底
  final Color down; // 跌
  final Color warn; // 警示（琥珀）
  final Color warnWeak; // 警示浅底
  final Color danger; // 错误
  final Color dangerWeak; // 错误浅底
  final Color infoWeak; // 信息浅底
  final Color infoText; // 信息条文字
  final Color warnText; // 警示条文字
  final Color dangerText; // 错误条文字
  final Color onAccent; // 渐变 / 实色按钮上的文字与图标（两套均为白）
  final Color toast; // SnackBar 底
  final Color shadow; // 投影基色（按透明度使用）
  final Color allocCash; // 资产配置：现金
  final Color allocStock; // 资产配置：股票
  final Color allocEtf; // 资产配置：ETF
  final Color ink; // F11 后新版卡片的主文字（略深于 text）
  final Color sub; // 新版卡片次级文字
  final Color hint; // 新版卡片弱文字、注释
  final Color track; // 进度条 / 图表网格 / 轨道
  final Color pill; // 中性胶囊底
  final Color chip; // 中性小标签底
  final Color divider; // 卡内细分隔线
  final Color panel; // 卡内浅色面板
  final Color border; // 描边按钮 / 胶囊描边
  final Color flat; // 平盘 / 中性图形
  final Color needle; // 仪表盘指针
  final Color coin; // 币种圆标底（非 BTC）
  final Color upBorder; // 涨的描边
  final Color downBorder; // 跌的描边
  final Color goldWeak; // 金色提示底
  final Color goldText; // 金色提示文字
  final Color cardShadow; // 新版卡片投影
  final Color cardShadow2; // 新版卡片投影（略重）

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF6F5FC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF3F2FA),
    text: Color(0xFF171A2E),
    muted: Color(0xFF6B7191),
    faint: Color(0xFF9BA0B8),
    line: Color(0xFFE9E8F4),
    primary: Color(0xFF6C5BF5),
    primary2: Color(0xFF4F3ED9),
    primaryWeak: Color(0xFFEFECFE),
    accent: Color(0xFF3B82F6),
    up: Color(0xFF16A34A),
    upWeak: Color(0xFFE8F7EE),
    down: Color(0xFFE5484D),
    warn: Color(0xFFB45309),
    warnWeak: Color(0xFFFFF6E5),
    danger: Color(0xFFE5484D),
    dangerWeak: Color(0xFFFDEDEE),
    infoWeak: Color(0xFFEDF2FD),
    infoText: Color(0xFF1E3A5F),
    warnText: Color(0xFF7A4A06),
    dangerText: Color(0xFF8A1C1C),
    onAccent: Color(0xFFFFFFFF),
    toast: Color(0xEB171A2E),
    shadow: Color(0xFF2A2260),
    allocCash: Color(0xFF6C5BF5),
    allocStock: Color(0xFFD63AA8),
    allocEtf: Color(0xFFF0A13C),
    ink: Color(0xFF1B1830),
    sub: Color(0xFF7A7490),
    hint: Color(0xFFA7A1BC),
    track: Color(0xFFF1EFF8),
    pill: Color(0xFFF1EFFA),
    chip: Color(0xFFF4F2FB),
    divider: Color(0xFFF4F2FA),
    panel: Color(0xFFFAF9FE),
    border: Color(0xFFE4E0F5),
    flat: Color(0xFFC9C4DC),
    needle: Color(0xFF2E2752),
    coin: Color(0xFF1B1830),
    upBorder: Color(0xFFBFE8CD),
    downBorder: Color(0xFFF5C6C9),
    goldWeak: Color(0xFFFBF3DF),
    goldText: Color(0xFFB57E0C),
    cardShadow: Color(0x0F1B1830),
    cardShadow2: Color(0x121B1830),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF141220),
    surface: Color(0xFF1E1B2E),
    surface2: Color(0xFF252238),
    text: Color(0xFFF2F0FA),
    muted: Color(0xFF9B95B5),
    faint: Color(0xFF6F6A8A),
    line: Color(0xFF2A2740),
    primary: Color(0xFF8F7BF8),
    primary2: Color(0xFFA99BFA),
    primaryWeak: Color(0xFF2A2548),
    accent: Color(0xFF60A5FA),
    up: Color(0xFF22C55E),
    upWeak: Color(0xFF15301F),
    down: Color(0xFFF87171),
    warn: Color(0xFFF59E0B),
    warnWeak: Color(0xFF2E2516),
    danger: Color(0xFFF87171),
    dangerWeak: Color(0xFF3A1E26),
    infoWeak: Color(0xFF1C2440),
    infoText: Color(0xFFB4C8EE),
    warnText: Color(0xFFF3C77B),
    dangerText: Color(0xFFFCA5A5),
    onAccent: Color(0xFFFFFFFF),
    toast: Color(0xEB37334F),
    shadow: Color(0xFF000000),
    allocCash: Color(0xFF8F7BF8),
    allocStock: Color(0xFFE35DB8),
    allocEtf: Color(0xFFF5B04F),
    ink: Color(0xFFF2F0FA),
    sub: Color(0xFF9B95B5),
    hint: Color(0xFF77718F),
    track: Color(0xFF2A2740),
    pill: Color(0xFF2A2740),
    chip: Color(0xFF252238),
    divider: Color(0xFF26233A),
    panel: Color(0xFF221F33),
    border: Color(0xFF2F2B45),
    flat: Color(0xFF4A4663),
    needle: Color(0xFFE4E0F5),
    coin: Color(0xFF3A3555),
    upBorder: Color(0xFF1F5132),
    downBorder: Color(0xFF5A2A30),
    goldWeak: Color(0xFF2E2716),
    goldText: Color(0xFFE9B949),
    cardShadow: Color(0x4D000000),
    cardShadow2: Color(0x4D000000),
  );
}

/// 当前外观的颜色令牌。外观由根组件按"跟随系统 / 浅色 / 深色"解析后调用 [AppColors.apply] 切换，
/// 切换后整棵树重建（见 main.dart），因此令牌是 getter 而非 const。
/// 按当前外观取浅色 / 深色值（仅供本文件的模块令牌使用；页面不直接调用）。
Color _ld(int light, int dark) => Color(AppColors.isDark ? dark : light);

abstract final class AppColors {
  static AppPalette _p = AppPalette.light;
  static AppPalette get palette => _p;
  static bool get isDark => _p.brightness == Brightness.dark;

  /// 切换色板；返回是否发生了变化。
  static bool apply(Brightness b) {
    final next = b == Brightness.dark ? AppPalette.dark : AppPalette.light;
    if (identical(next, _p)) return false;
    _p = next;
    return true;
  }

  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get surface2 => _p.surface2;
  static Color get text => _p.text;
  static Color get muted => _p.muted;
  static Color get faint => _p.faint;
  static Color get line => _p.line;
  static Color get primary => _p.primary;
  static Color get primary2 => _p.primary2;
  static Color get primaryWeak => _p.primaryWeak;
  static Color get accent => _p.accent;
  static Color get up => _p.up;
  static Color get upWeak => _p.upWeak;
  static Color get down => _p.down;
  static Color get warn => _p.warn;
  static Color get warnWeak => _p.warnWeak;
  static Color get danger => _p.danger;
  static Color get dangerWeak => _p.dangerWeak;
  static Color get infoWeak => _p.infoWeak;
  static Color get infoText => _p.infoText;
  static Color get warnText => _p.warnText;
  static Color get dangerText => _p.dangerText;
  static Color get onAccent => _p.onAccent;
  static Color get toast => _p.toast;
  static Color get shadow => _p.shadow;
  static Color get allocCash => _p.allocCash;
  static Color get allocStock => _p.allocStock;
  static Color get allocEtf => _p.allocEtf;
  static Color get ink => _p.ink;
  static Color get sub => _p.sub;
  static Color get hint => _p.hint;
  static Color get track => _p.track;
  static Color get pill => _p.pill;
  static Color get chip => _p.chip;
  static Color get divider => _p.divider;
  static Color get panel => _p.panel;
  static Color get border => _p.border;
  static Color get flat => _p.flat;
  static Color get needle => _p.needle;
  static Color get coin => _p.coin;
  static Color get upBorder => _p.upBorder;
  static Color get downBorder => _p.downBorder;
  static Color get goldWeak => _p.goldWeak;
  static Color get goldText => _p.goldText;
  static Color get cardShadow => _p.cardShadow;
  static Color get cardShadow2 => _p.cardShadow2;
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

  /// F22-a 资产页渐变大卡：118deg #4D5BEF → #8A4BE0 42% → #D4569B 70% → #F0944C（深浅色相同）
  static const assetHero = LinearGradient(
    begin: Alignment(-1, -0.55),
    end: Alignment(1, 0.55),
    colors: [Color(0xFF4D5BEF), Color(0xFF8A4BE0), Color(0xFFD4569B), Color(0xFFF0944C)],
    stops: [0, .42, .70, 1],
  );

  /// F22-a 筛选胶囊选中态：135deg #7D4DF0 → #A944D8
  static const filterOn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7D4DF0), Color(0xFFA944D8)],
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
  /// 卡片投影：浅色为淡紫灰；深色下改为更深的黑影（深底上淡紫影不可见）。
  static List<BoxShadow> get shadow => AppColors.isDark
      ? [
          BoxShadow(color: AppColors.shadow.withValues(alpha: .35), blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(color: AppColors.shadow.withValues(alpha: .28), blurRadius: 18, offset: const Offset(0, 6)),
        ]
      : [
          BoxShadow(color: AppColors.shadow.withValues(alpha: .05), blurRadius: 2, offset: const Offset(0, 1)),
          BoxShadow(color: AppColors.shadow.withValues(alpha: .07), blurRadius: 18, offset: const Offset(0, 6)),
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

  /// F22-c 成交成功页：Fifi 举回执（透明背景，来源 design/brand/fifi_order.png，缩至 720px）。
  static const fifiOrder = 'assets/brand/fifi_order.png';

  /// F22-d Fifi 页英雄卡：Fifi 拿平板（透明背景，来源 design/brand/fifi_quant.png，原图 240×333）。
  static const fifiQuant = 'assets/brand/fifi_quant.png';

  /// F22-e / F22-f 商店与任务页素材（来源 design/brand/store/；*_placeholder 为占位图，高清图后续热替换）。
  static const storeHero = 'assets/brand/store/st_hero_full.png';
  static const xpHero = 'assets/brand/store/xp_hero.png';
  static String storeItem(String id) => 'assets/brand/store/st_$id.png';

  /// F20 P-01 欢迎页 AK 字标（透明背景，来源 design/brand/ak_mark.png，缩至 600px 宽）。
  static const akMark = 'assets/brand/ak_mark.png';
}

/// Material 主题（F21：按色板生成浅色 / 深色两套；MaterialApp.theme / darkTheme）。
ThemeData buildTheme([AppPalette c = AppPalette.light]) {
  final dark = c.brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: c.brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.primary,
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onAccent,
      surface: c.surface,
      onSurface: c.text,
      error: c.danger,
      outline: c.line,
      outlineVariant: c.line,
    ),
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.surface,
    dividerColor: c.line,
  );
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppShape.inputRadius),
    borderSide: BorderSide(color: color, width: 1.5),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.text),
      shape: Border(bottom: BorderSide(color: c.line)),
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: c.faint, fontSize: 16),
      border: border(c.line),
      enabledBorder: border(c.line),
      focusedBorder: border(c.primary),
      errorBorder: border(c.danger),
      focusedErrorBorder: border(c.danger),
      errorStyle: TextStyle(color: c.danger, fontSize: 12),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.primary, selectionHandleColor: c.primary),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : null),
      checkColor: WidgetStatePropertyAll(c.onAccent),
      side: BorderSide(color: c.faint, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStatePropertyAll(c.line),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surface, modalBackgroundColor: c.surface, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: c.surface, surfaceTintColor: Colors.transparent),
    popupMenuTheme: PopupMenuThemeData(color: c.surface, surfaceTintColor: Colors.transparent),
    drawerTheme: DrawerThemeData(backgroundColor: c.surface, surfaceTintColor: Colors.transparent),
    dividerTheme: DividerThemeData(color: c.line),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.toast,
      contentTextStyle: TextStyle(color: c.onAccent, fontSize: 14),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
  );
}

/// F16 P-27 奖励页（圣诞季）专用色（theme.md 第 8 节；深色版见第 10 节）。
abstract final class RewardColors {
  static Color get ink => _ld(0xFF1B1830, 0xFFF2F0FA);
  static Color get sub => _ld(0xFF7A7490, 0xFF9B95B5);
  static Color get heroInk => _ld(0xFF241F4E, 0xFFF2F0FA);
  static Color get heroText => _ld(0xFF5F5880, 0xFFB5AECF);
  static Color get heroBorder => _ld(0xFFE7E0F7, 0xFF332D52);
  static const gold = Color(0xFFE9C878); // 金色点缀（两套相同）
  static Color get goldDark => _ld(0xFFC9A14E, 0xFFD9B566);
  static Color get badgeBorder => _ld(0xFFD4B46A, 0xFFB89A55);
  static Color get badgeText => _ld(0xFF9A7524, 0xFFE9C878);
  static const goldInk = Color(0xFF2E2752); // 金色胶囊上的文字（金底不变，两套相同）
  static Color get lilac => _ld(0xFFA08CF0, 0xFFB3A3F7);
  static Color get snow => _ld(0xFFC9B9F2, 0xFF8C7CC8);
  static Color get chipBorder => _ld(0xFFE4E0F5, 0xFF2F2B45);
  static Color get pill => _ld(0xFFF1EFFA, 0xFF2A2740);
  static Color get lockBg => _ld(0xFFF3F0FC, 0xFF2A2548);
  static Color get note => _ld(0xFFA7A1BC, 0xFF7D7798);
  static Color get xpBorder => _ld(0xFFD9D4F7, 0xFF4A4178);
  static Color get heroShadow => _ld(0x296C5BF5, 0x40000000);
  static Color get glowLilac => _ld(0x80D9CEF8, 0x407D4DF0);
  static Color get glowPink => _ld(0x80F3CBE8, 0x33D63AA8);
  static Color get goldShadow => _ld(0x59E9C878, 0x33E9C878);
  static const purpleShadow = Color(0x527D4DF0);
  static Color get ctaShadow => _ld(0x597D4DF0, 0x667D4DF0);
  static Color get cardShadow => _ld(0x121B1830, 0x4D000000);

  /// 奖品图底部径向柔光
  static List<Color> get prizeGlow =>
      AppColors.isDark ? const [Color(0xFF2E2852), Color(0xFF241F3A), Color(0x00241F3A)] : const [Color(0xFFF1EDFF), Color(0xFFFAF8FF), Color(0x00FAF8FF)];

  // 奖品插画（移植自 mock_reference.html 的 SVG）
  static const art1 = [Color(0xFF7D4DF0), Color(0xFFC13AC8)];
  static const art4 = [Color(0xFF8F5BF5), Color(0xFFD63AA8)];
  static const artPurple = Color(0xFFA944D8);
  static const artMagenta = Color(0xFFC13AC8);
  static const artHighlight = Color(0xFFFFFFFF); // 插画高光
  static const artShade = Color(0xFF4A3ED1);
  static Color get artNavy => _ld(0xFF2E2752, 0xFFC9C2F5); // 深底上提亮，保证插画轮廓可见

  /// 英雄区浅紫渐变：135deg #F2EDFC → #F7F2FC 55% → #F6EBF7（深色：深紫渐变）
  static LinearGradient get hero => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.isDark
        ? const [Color(0xFF2A2350), Color(0xFF231E3D), Color(0xFF2E1F3E)]
        : const [Color(0xFFF2EDFC), Color(0xFFF7F2FC), Color(0xFFF6EBF7)],
    stops: const [0, .55, 1],
  );

  /// 等级胶囊选中：135deg #7D4DF0 → #C13AC8
  static const chipOn = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7D4DF0), Color(0xFFC13AC8)],
  );

  /// 金色"即将推出"胶囊：135deg #F6E7BF → #E9C878
  static const goldPill = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6E7BF), gold],
  );

  /// 奖品卡渐变细描边：紫 → 金 → 玫红（半透明；深色略加不透明度）
  static LinearGradient get cardBorder => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppColors.isDark
        ? const [Color(0x807D4DF0), Color(0x80E9C878), Color(0x66D63AA8)]
        : const [Color(0x597D4DF0), Color(0x66E9C878), Color(0x4DD63AA8)],
    stops: const [0, .6, 1],
  );
}

/// 模拟盘品牌色：琥珀色系，与实盘的紫色明显区分（theme.md 第 7 节"模拟盘标识"；深色版第 10 节）。
abstract final class PaperColors {
  static Color get fg => _ld(0xFFB45309, 0xFFF5A524);
  static Color get bg => _ld(0xFFFFF4E0, 0xFF2E2414);
  static Color get border => _ld(0xFFF5C46B, 0xFF6B4E1C);
}

/// 庆祝特效（theme.md 第 7 节）：深底上彩带提亮一档，爪印保持白色。
abstract final class CelebrationColors {
  static List<Color> get palette => AppColors.isDark
      ? const [Color(0xFF7B78FF), Color(0xFF9B80FF), Color(0xFFC46BEB), Color(0xFFDA62DE), Color(0xFFF062C2), Color(0xFFD4CFFF)]
      : const [Color(0xFF5A57EE), Color(0xFF7D5CF0), Color(0xFFA944D8), Color(0xFFC13AC8), Color(0xFFD63AA8), Color(0xFFB9B2FF)];
  static const paw = Color(0xFFFFFFFF);
  static Color get pawOutline => _ld(0xFF7D5CF0, 0xFF9B80FF);
}

/// 市场情绪档位色（F11，P-09）：极度恐慌 → 极度贪婪；深色下文字提亮、底色压暗。
abstract final class SentimentColors {
  static const _textLight = [0xFFC2373C, 0xFFC2640A, 0xFF6B7191, 0xFFB57E0C, 0xFF15803D];
  static const _textDark = [0xFFF87171, 0xFFFB923C, 0xFF9B95B5, 0xFFE9B949, 0xFF22C55E];
  static const _bgLight = [0xFFFDEDEE, 0xFFFFF1E3, 0xFFF1EFFA, 0xFFFBF3DF, 0xFFE7F6EC];
  static const _bgDark = [0xFF3A1E26, 0xFF35231A, 0xFF2A2740, 0xFF2E2716, 0xFF15301F];
  static Color text(int level) => Color((AppColors.isDark ? _textDark : _textLight)[level]);
  static Color bg(int level) => Color((AppColors.isDark ? _bgDark : _bgLight)[level]);

  /// 仪表盘弧线渐变：红 → 橙 → 金 → 绿
  static List<Color> get gauge => AppColors.isDark
      ? const [Color(0xEBF87171), Color(0xEBF5B04F), Color(0xEBE9C878), Color(0xEB22C55E)]
      : const [Color(0xEBE5484D), Color(0xEBF0A13C), Color(0xEBE9C878), Color(0xEB16A34A)];
}

/// 头像底色（按名称稳定取色；中等明度，深浅两套通用，白字）。
abstract final class AvatarColors {
  static const all = [
    Color(0xFFA34D5B),
    Color(0xFF6B4FA5),
    Color(0xFF7FA05A),
    Color(0xFF8C9A4E),
    Color(0xFF4A9EA3),
    Color(0xFF4E9A79),
    Color(0xFF5B6FB0),
    Color(0xFFB0785B),
  ];
}

/// 外部品牌 / 通用图形色（两套相同）。
abstract final class BrandColors {
  static const bitcoin = Color(0xFFF7931A);
  static const star = Color(0xFFF5B301);
}

/// P-01 欢迎页专属强调色（橙色；App 内部主题仍为紫色系，theme.md 第 9 节）。
/// 深色下：背景换深底，字标与橙色趋势线不变，字标外加浅色光晕（第 10 节）。
abstract final class WelcomeColors {
  static const orangeLight = Color(0xFFFEA81E);
  static const orangeDeep = Color(0xFFF58500);
  static const orange = Color(0xFFFE9502);
  static const buttonShadow = Color(0x61FE9502);
  static Color get sub => AppColors.sub;
  static Color get faint => AppColors.hint;
  static Color get ink => AppColors.ink;
  static Color get border => AppColors.border;

  /// 字标下的投影（浅色）/ 光晕（深色）
  static Color get markHalo => _ld(0x2E1B1830, 0x73FFFFFF);
}

/// F22-a 资产页令牌（design/reward-design/v3/asset_v2.png）。渐变卡上的元素深浅色相同。
abstract final class AssetHeroColors {
  /// 渐变卡上的涨 / 跌箭头（浅绿 / 浅红，保证在渐变上可读）
  static const upOnGrad = Color(0xFF7CF2A4);
  static const downOnGrad = Color(0xFFFFC9CB);

  /// 卡投影（紫）
  static const shadow = Color(0x4D6C5BF5);

  /// 眼睛按钮底
  static const eyeBg = Color(0x38FFFFFF);

  /// 环形图按标的拆分（股票 / ETF 筛选）的系列色：前 5 个标的 + "其他"
  static List<Color> get series => [
    AppColors.allocStock,
    AppColors.allocCash,
    AppColors.allocEtf,
    _ld(0xFF22A6B3, 0xFF3CC4D1),
    _ld(0xFF16A34A, 0xFF22C55E),
    _ld(0xFFB5AFC9, 0xFF5E5878),
  ];
}

/// F22-b 市场页令牌（design/reward-design/v3/market_v2.png）。指数卡渐变与卡上文字深浅色相同。
abstract final class MarketColors {
  static const indexGrads = [
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5A57EE), Color(0xFF8A4BE0)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFA944D8), Color(0xFFD4569B)]),
    LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFE0638A), Color(0xFFF0944C)]),
  ];
  static const upOnGrad = Color(0xFF8CF2B0);
  static const downOnGrad = Color(0xFFFFC9CB);

  /// 涨跌分布"平"档柱色与数字色
  static Color get flatBar => _ld(0xFFC9C4DC, 0xFF4A4566);
  static Color get flatText => _ld(0xFF8F87A5, 0xFF9B95B5);

  /// 内部人交易三卡底色：买入（绿）/ 卖出（红）/ 最活跃（紫）
  static Color get buyBg => _ld(0xFFE8F7EE, 0xFF173326);
  static Color get sellBg => _ld(0xFFFDEDEE, 0xFF3A1E24);
  static Color get activeBg => _ld(0xFFF1EFFA, 0xFF27233D);

  /// "演示数据"角标（琥珀）
  static Color get demoBg => _ld(0xFFFBF3DF, 0xFF3A3018);
  static Color get demoFg => _ld(0xFFB57E0C, 0xFFE8B54A);
}

/// F22-c 成交成功页令牌（design/reward-design/v3/order_done.png）。
abstract final class OrderDoneColors {
  /// 底部紫色波浪（上 → 下）
  static List<Color> get wave => [_c(0xFFD9CEF8, 0xFF2C2350), _c(0xFFEFEAFB, 0xFF221C3A), _c(0xFFF6F3FE, 0xFF1A1729)];
  static Color get badgeRing => _ld(0xFFEFEBFE, 0xFF2E2A4A);
  static Color get sparkle => _ld(0xFFA98FF5, 0xFF8F7BF8);
  static const coinPurple = [Color(0xFFC9B2FF), Color(0xFF8F5BF5)];
  static const coinGold = [Color(0xFFFFD9A0), Color(0xFFF0A13C)];
  static const arrow = Color(0xFF16A34A);
  static Color _c(int l, int d) => _ld(l, d);
}

/// F22-d / F22-e / F22-f 令牌（design/reward-design/v3/fifi_v2、store_final、earn_xp）。渐变深浅色相同。
abstract final class StoreColors {
  /// CTA / 选中等级：100deg #7D4DF0 → #A944D8 55% → #D63AA8
  static const grad = LinearGradient(
    begin: Alignment(-1, -0.18),
    end: Alignment(1, 0.18),
    colors: [Color(0xFF7D4DF0), Color(0xFFA944D8), Color(0xFFD63AA8)],
    stops: [0, .55, 1],
  );

  /// Fifi 页英雄卡：118deg #4D4FE0 → #7D4DF0 40% → #B44BD8 72% → #E08BC8
  static const fifiHero = LinearGradient(
    begin: Alignment(-1, -0.55),
    end: Alignment(1, 0.55),
    colors: [Color(0xFF4D4FE0), Color(0xFF7D4DF0), Color(0xFFB44BD8), Color(0xFFE08BC8)],
    stops: [0, .40, .72, 1],
  );

  static Color get xpBorder => _ld(0xFFD9D2F5, 0xFF3A3560);
  static Color get tierBg => _ld(0xFFEFEBFC, 0xFF27233D);
  static Color get lockedBg => _ld(0xFFEFEDF4, 0xFF221F33);
  static Color get lockedFg => _ld(0xFFA7A1BC, 0xFF6E6889);
  static Color get availBg => _ld(0xFFE8F7EE, 0xFF173326);
  static Color get mutedChipBg => _ld(0xFFF1EFFA, 0xFF27233D);
  static Color get mutedChipFg => _ld(0xFF8F87A5, 0xFF9B95B5);
  static List<Color> get bundleBg => [_ld(0xFFF3EBFD, 0xFF2A2342), _ld(0xFFFBEAF6, 0xFF33213A)];
  static Color get lockBadge => const Color(0x8C141028);
  static Color get remindBg => _ld(0xFFEFEBFE, 0xFF2A2546);
  static Color get doneRowBg => _ld(0xFFEDF9F1, 0xFF15291F);
  static Color get xpDoneBg => _ld(0xFFE4F6EA, 0xFF1C3A28);
  static Color get fireBg => _ld(0xFFFDEDE4, 0xFF3A2620);
  static Color get ring => _ld(0xFFC9C2E8, 0xFF4A4566);
  static const imageShadow = Color(0x406C5BF5);
}
