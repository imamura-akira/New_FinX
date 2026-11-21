import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/sound/ui_sound.dart';
import '../../../l10n/l10n.dart';
import 'welcome_page.dart' show LaunchIntro;

/// 趋势线路径（design/reward-design/welcome_reference.html 的 SVG，viewBox 342×150）。
const trendPoints = <Offset>[
  Offset(6, 128),
  Offset(48, 108),
  Offset(84, 120),
  Offset(128, 86),
  Offset(162, 98),
  Offset(206, 58),
  Offset(240, 72),
  Offset(284, 30),
  Offset(322, 14),
];

/// 阶段性高点在 [trendPoints] 中的序号：3 个局部高点（48,108）（128,86）（206,58）、
/// 上升由陡转缓的拐点（284,30）与终点（322,14），共 5 个，对应 5 声音调递增的"滴"。
const trendPeakIndices = [1, 3, 5, 7, 8];

/// 各阶段性高点在路径上的位置（0–1，按长度）；描画越过这些位置时依次"滴"一声。
List<double> trendPeakFractions() {
  final lens = <double>[0];
  for (var i = 1; i < trendPoints.length; i++) {
    lens.add(lens.last + (trendPoints[i] - trendPoints[i - 1]).distance);
  }
  return [for (final i in trendPeakIndices) lens[i] / lens.last];
}

/// 【F22-g 归档，未接入路由】P-01 欢迎页 AK 品牌版（F20，2026-11-21 回滚为 FinX 原版；素材与代码留档不删除）。
/// 原说明：P-01 欢迎页（F20 AK 品牌版，定稿 design/reward-design/welcome_v3.png）：AK 字标 + 两行 slogan、
/// 橙色震荡上行趋势线、注册（橙色渐变）/ 登录 / 先逛逛行情 / 免责。
///
/// 冷启动入场（只播一次）：字标与 slogan 淡入；趋势线从左向右描画（约 1.35 秒，缓动），每画到一个阶段性高点
/// "滴"一声且音调依次升高（共 5 声，跟随静音开关）；终点光点亮起并呼吸；画完后"注册"按钮轻微放大一次。
/// 光点呼吸 3 次后保持常亮。系统"减弱动态效果"开启时直接显示完整静态线，不播声音、光点不呼吸。动画期间按钮始终可点。
class AkWelcomePage extends StatefulWidget {
  const AkWelcomePage({super.key});

  /// 入场总时长：淡入 0–0.45 s，描线 0.3–1.65 s，注册按钮放大 1.65–2.05 s。
  static const introDuration = Duration(milliseconds: 2050);
  static const drawStart = 300 / 2050, drawEnd = 1650 / 2050;

  @override
  State<AkWelcomePage> createState() => _AkWelcomePageState();
}

class _AkWelcomePageState extends State<AkWelcomePage> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AkWelcomePage.introDuration);
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  final _peaks = trendPeakFractions();
  int _ticked = 0;
  bool _intro = false;
  bool _reduced = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (LaunchIntro.consume() && !_reduced) {
      _intro = true;
      _c.addListener(_onTick);
      _c.addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted && !_reduced) _breathe();
      });
      _c.forward();
    } else {
      // 非冷启动或减弱动态效果：直接显示完整静态线，不播声音
      _c.value = 1;
      if (!_reduced) _breathe();
    }
  }

  /// 终点光点呼吸 3 次后保持常亮（避免无限动画持续耗电）。
  void _breathe() => _breath.repeat(reverse: true, count: 6);

  double get _draw => Interval(AkWelcomePage.drawStart, AkWelcomePage.drawEnd, curve: Curves.easeInOutCubic).transform(_c.value);

  /// 描线越过第 i 个高点时播放第 i 声（音调递增）。
  void _onTick() {
    final d = _draw;
    while (_ticked < _peaks.length && d >= _peaks[_ticked] - 1e-6) {
      UiSound.play(UiSound.peakTicks[math.min(_ticked, UiSound.peakTicks.length - 1)]);
      _ticked++;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _breath.dispose();
    super.dispose();
  }

  Animation<double> _seg(double begin, double end, Curve curve) => CurvedAnimation(parent: _c, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final markIn = _seg(0, .2, Curves.easeOut);
    final sloganIn = _seg(.06, .26, Curves.easeOut);
    final buttonsIn = _seg(.1, .3, Curves.easeOut);
    final pulse = _seg(AkWelcomePage.drawEnd, 1, Curves.easeInOut);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    children: [
                      SizedBox(height: math.min(56, box.maxHeight * .05)),
                      FadeTransition(
                        key: Key(_intro ? 'welcome.intro' : 'welcome.static'),
                        opacity: markIn,
                        child: const _Mark(),
                      ),
                      const SizedBox(height: 22),
                      FadeTransition(
                        opacity: sloganIn,
                        child: Text(
                          '${t.welcomeSlogan1}\n${t.welcomeSlogan2}',
                          key: const Key('welcome.slogan'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14.5, height: 1.7, fontWeight: FontWeight.w600, color: WelcomeColors.sub),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: AspectRatio(
                              aspectRatio: 342 / 150,
                              child: AnimatedBuilder(
                                animation: Listenable.merge([_c, _breath]),
                                builder: (_, _) => CustomPaint(
                                  key: const Key('welcome.trend'),
                                  painter: TrendLinePainter(progress: _draw, breath: _reduced ? 0 : _breath.value),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: buttonsIn,
                        child: Column(
                          children: [
                            AnimatedBuilder(
                              animation: pulse,
                              // 画完后注册按钮 1.0 → 1.04 → 1.0
                              builder: (_, child) => Transform.scale(scale: 1 + .04 * math.sin(math.pi * pulse.value), child: child),
                              child: _RegisterButton(onTap: () => context.push('/login?mode=register')),
                            ),
                            const SizedBox(height: 12),
                            _LoginButton(onTap: () => context.push('/login?mode=login')),
                            const SizedBox(height: 18),
                            GestureDetector(
                              key: const Key('welcome.market'),
                              onTap: () => context.go('/market'), // 未登录可浏览；资产 Tab 回到欢迎页
                              child: Text(
                                t.welcomeBrowseMarkets,
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              t.welcomeBrokerageServicesAreProvided,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: WelcomeColors.faint),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// AK 字标（约 200pt 宽，轻投影：按字标轮廓的模糊阴影）。
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    const img = Image(image: AssetImage(BrandAssets.akMark), width: 200, semanticLabel: 'AK');
    return Stack(
      key: const Key('welcome.logo'),
      clipBehavior: Clip.none,
      children: [
        // 浅色：下方模糊投影；深色：黑描边字标外加一圈浅色光晕，保证深底上可见（F21）
        Transform.translate(
          offset: AppColors.isDark ? Offset.zero : const Offset(0, 16),
          child: ImageFiltered(
            imageFilter: AppColors.isDark ? ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7) : ui.ImageFilter.blur(sigmaX: 13, sigmaY: 13),
            child: ColorFiltered(colorFilter: ColorFilter.mode(WelcomeColors.markHalo, BlendMode.srcIn), child: img),
          ),
        ),
        img,
      ],
    );
  }
}

class _RegisterButton extends StatelessWidget {
  const _RegisterButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('welcome.register'),
    onTap: onTap,
    child: Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WelcomeColors.orangeLight, WelcomeColors.orangeDeep],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: WelcomeColors.buttonShadow, blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Text(
        t.welcomeSignUp,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.onAccent, letterSpacing: isEnglish ? .5 : 2),
      ),
    ),
  );
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('welcome.login'),
    onTap: onTap,
    child: Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: WelcomeColors.border, width: 1.5),
      ),
      child: Text(
        t.welcomeLogIn,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: WelcomeColors.ink, letterSpacing: isEnglish ? .3 : 2),
      ),
    ),
  );
}

/// 趋势线：浅橙 → 深橙渐变描边 4pt，线下淡橙渐变填充（随描画推进），终点光点（画完后亮起，按 [breath] 呼吸）。
class TrendLinePainter extends CustomPainter {
  const TrendLinePainter({required this.progress, this.breath = 0});

  /// 描画进度 0–1（按路径长度）。
  final double progress;

  /// 光点呼吸 0–1。
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 342;
    canvas.save();
    canvas.scale(s);
    final full = Path()..moveTo(trendPoints.first.dx, trendPoints.first.dy);
    for (final p in trendPoints.skip(1)) {
      full.lineTo(p.dx, p.dy);
    }
    final metric = full.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress.clamp(0, 1));
    final head = metric.getTangentForOffset(metric.length * progress.clamp(0, 1))?.position ?? trendPoints.first;
    if (progress > 0) {
      // 线下填充：只填到当前描画位置
      final fill = Path.from(drawn)
        ..lineTo(head.dx, 148)
        ..lineTo(trendPoints.first.dx, 148)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [WelcomeColors.orange.withValues(alpha: .14), WelcomeColors.orange.withValues(alpha: 0)],
          ).createShader(const Rect.fromLTWH(0, 0, 342, 150)),
      );
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = LinearGradient(
            colors: [WelcomeColors.orangeLight.withValues(alpha: .5), WelcomeColors.orangeDeep],
          ).createShader(const Rect.fromLTWH(6, 0, 316, 150)),
      );
    }
    if (progress >= 1) {
      final end = trendPoints.last;
      canvas.drawCircle(end, 10 + 3 * breath, Paint()..color = WelcomeColors.orange.withValues(alpha: .22 - .1 * breath));
      canvas.drawCircle(end, 5.5, Paint()..color = WelcomeColors.orangeDeep);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TrendLinePainter old) => old.progress != progress || old.breath != breath;
}
