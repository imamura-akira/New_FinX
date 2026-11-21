import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/sound/ui_sound.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';

/// 冷启动品牌入场（design/theme.md 第 7 节）：只在冷启动后第一个出现的是 P-01 时播放一次。
/// 冷启动直接进入资产页（已登录）则视为已消耗，之后退出登录回到 P-01 也不再播放。
abstract final class LaunchIntro {
  static bool _consumed = false;

  /// 返回本次是否应播放，并标记为已消耗。
  static bool consume() {
    if (_consumed) return false;
    _consumed = true;
    return true;
  }

  /// 冷启动进入的不是 P-01（如已登录直接进入资产页）时调用。
  static void skip() => _consumed = true;

  @visibleForTesting
  static void resetForTest() => _consumed = false;
}

/// P-01 欢迎页（pages.md P-01；FinX 品牌版式同原型：白底、字标、Fifi 主视觉）。
/// F22-g：由 F20 AK 版回滚为本版（正向提交）；AK 版归档在 welcome_ak_page.dart。深色（F21）：深底，字标外加浅色光晕。
/// 冷启动入场：字标从左侧滑入定格，Fifi 轻微弹跳落位后左右摆动两下（挥手），文案与按钮淡入，共 1.6 秒；
/// 同时播放一声脚本合成的提示音（跟随系统静音开关）。系统"减弱动态效果"开启时只做淡入。
/// 动画期间按钮始终可点。
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  static const introDuration = Duration(milliseconds: 1600);

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: WelcomePage.introDuration);
  bool _intro = false;
  bool _reduced = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (LaunchIntro.consume()) {
      _intro = true;
      if (_reduced) _c.duration = const Duration(milliseconds: 400);
      _c.forward();
      UiSound.play(UiSound.welcomeChime);
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// [begin, end] 区间内的 0→1 进度（以整体时长为基准）。
  Animation<double> _seg(double begin, double end, Curve curve) =>
      CurvedAnimation(parent: _c, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final fade = _seg(0, 1, Curves.easeOut);
    final logoIn = _seg(0, .4, Curves.easeOutCubic);
    final fifiDrop = _seg(.12, .62, Curves.easeOutBack);
    final wave = _seg(.62, 1, Curves.linear);
    final restIn = _seg(.25, .6, Curves.easeOut);

    Widget logo = _Logo(key: const Key('welcome.logo'));
    Widget fifi = Image.asset(BrandAssets.fifiPill, width: 300, semanticLabel: 'Fifi');
    Widget Function(Widget) rest = (child) => child;

    if (_intro && _reduced) {
      // 减弱动态效果：整体淡入，无位移与旋转
      logo = FadeTransition(key: const Key('welcome.intro.fade'), opacity: fade, child: logo);
      fifi = FadeTransition(opacity: fade, child: fifi);
      rest = (child) => FadeTransition(opacity: fade, child: child);
    } else if (_intro) {
      logo = AnimatedBuilder(
        key: const Key('welcome.intro'),
        animation: logoIn,
        builder: (_, child) => Opacity(
          opacity: logoIn.value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(-80 * (1 - logoIn.value), 0), child: child),
        ),
        child: logo,
      );
      fifi = AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final d = fifiDrop.value; // easeOutBack 会略微越过 1，形成落位时的轻微弹跳
          // 挥手：两次左右摆动，幅度逐渐减小
          final w = wave.value;
          final angle = w == 0 || w == 1 ? 0.0 : math.sin(w * 4 * math.pi) * (1 - w) * 0.10;
          return Opacity(
            opacity: (d * 1.6).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -48 * (1 - d)),
              child: Transform.rotate(angle: angle, alignment: Alignment.bottomCenter, child: child),
            ),
          );
        },
        child: fifi,
      );
      rest = (child) => FadeTransition(opacity: restIn, child: child);
    }

    return Scaffold(
      backgroundColor: AppColors.isDark ? AppColors.bg : AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                logo,
                const SizedBox(height: 8),
                rest(
                  Text(
                    t.welcomeInvestInUsStocks,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                fifi,
                const SizedBox(height: 48),
                rest(
                  Column(
                    children: [
                      AppButton(t.welcomeSignUp, key: const Key('welcome.register'), onPressed: () => context.push('/login?mode=register')),
                      const SizedBox(height: 8),
                      AppButton(
                        t.welcomeSignIn,
                        key: const Key('welcome.login'),
                        kind: ButtonKind.ghost,
                        onPressed: () => context.push('/login?mode=login'),
                      ),
                      const SizedBox(height: 12),
                      // 未登录可浏览；资产 Tab 回到欢迎页
                      LinkButton(t.welcomeBrowseMarketsFirst, key: const Key('welcome.market'), onPressed: () => context.go('/market')),
                      const SizedBox(height: 24),
                      Text(t.welcomeBrokerageServicesAreProvided, style: TextStyle(fontSize: 12, color: AppColors.faint)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// FinX 渐变字标 + "GO FinX Go Alpha" 手写标语（logo.png）。深色下沿字标轮廓加一圈浅色光晕，保证深底上可读（F21）。
class _Logo extends StatelessWidget {
  const _Logo({super.key});

  @override
  Widget build(BuildContext context) {
    const img = Image(image: AssetImage(BrandAssets.logo), width: 210, semanticLabel: 'FinX');
    if (!AppColors.isDark) return img;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: ColorFiltered(colorFilter: ColorFilter.mode(WelcomeColors.markHalo, BlendMode.srcIn), child: img),
        ),
        img,
      ],
    );
  }
}
