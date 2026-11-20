import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/sound/ui_sound.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/demo_data.dart';
import '../../../l10n/l10n.dart';

// F16：P-27 奖励 Tab 圣诞季限定版式（design/reward-design/rewards_mock_v8.png 为定稿；
// 颜色与奖品图形取自同目录 mock_reference.html）。整页为"即将上线"展示态，纯客户端模拟数据。
// 节后可切回常规版（见 prd F16）。

/// 奖励页专用色（design/theme.md 第 8 节）。
abstract final class RewardColors {
  static const ink = Color(0xFF1B1830);
  static const sub = Color(0xFF7A7490);
  static const heroInk = Color(0xFF241F4E);
  static const heroText = Color(0xFF5F5880);
  static const heroBorder = Color(0xFFE7E0F7);
  static const gold = Color(0xFFE9C878);
  static const goldDark = Color(0xFFC9A14E);
  static const badgeBorder = Color(0xFFD4B46A);
  static const badgeText = Color(0xFF9A7524);
  static const navy = Color(0xFF2E2752);
  static const lilac = Color(0xFFA08CF0);
  static const snow = Color(0xFFC9B9F2);
  static const chipBorder = Color(0xFFE4E0F5);
  static const pill = Color(0xFFF1EFFA);
  static const lockBg = Color(0xFFF3F0FC);
  static const note = Color(0xFFA7A1BC);
  static const xpBorder = Color(0xFFD9D4F7);

  /// 英雄区浅紫渐变：135deg #F2EDFC → #F7F2FC 55% → #F6EBF7
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF2EDFC), Color(0xFFF7F2FC), Color(0xFFF6EBF7)],
    stops: [0, .55, 1],
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

  /// 奖品卡渐变细描边：紫 → 金 → 玫红（半透明）
  static const cardBorder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x597D4DF0), Color(0x66E9C878), Color(0x4DD63AA8)],
    stops: [0, .6, 1],
  );
}

String get rewardSoon => t.mastersComingSoon2;

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  /// 上线提醒：仅本地状态（不落盘，重启恢复未开启）。
  bool _reminder = false;

  void _toggleReminder() {
    final on = !_reminder;
    setState(() => _reminder = on);
    if (on) {
      UiSound.play(UiSound.reminderDing);
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        children: [
          const _Header(),
          const SizedBox(height: 12),
          const _Hero(),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var lv = 1; lv <= 4; lv++) ...[
                if (lv > 1) const SizedBox(width: 6),
                Expanded(
                  child: _LevelChip(
                    key: Key('p27.level.$lv'),
                    level: lv,
                    selected: lv == 1,
                    onTap: lv == 1 ? null : () => showToast(context, t.rewardsLevel(lv, rewardSoon)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Icon(Icons.ac_unit_rounded, size: 17, color: AppColors.primary),
              SizedBox(width: 10),
              Text(
                t.rewardsHolidayStarterGifts,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: .3, color: RewardColors.ink),
              ),
              SizedBox(width: 10),
              Text(
                t.rewardsUnlocksAtLevel1,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: RewardColors.sub),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .84,
            children: [
              for (final (k, (name, xp)) in xmasRewards.indexed)
                _PrizeCard(
                  key: Key('p27.item.$name'),
                  name: name,
                  xp: xp,
                  art: _PrizeArt.values[k],
                  onTap: () => showToast(context, rewardSoon),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _ReminderButton(on: _reminder, onTap: _toggleReminder),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 10, 0, 8),
            child: Text(
              t.rewardsRewardsShownAreDemo,
              key: Key('p27.note'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: RewardColors.note),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          t.rewardsFifiRewards,
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: .5, color: RewardColors.ink),
        ),
      ),
      Container(
        key: const Key('p27.xp'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: RewardColors.xpBorder, width: 1.5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 15, color: RewardColors.goldDark),
            SizedBox(width: 6),
            Text('XP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryWeak,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(BrandAssets.fifiAvatar, fit: BoxFit.cover, semanticLabel: 'Fifi'),
      ),
    ],
  );
}

class _Hero extends StatelessWidget {
  const _Hero();

  static const _snow = [(150.0, 64.0, 3.0, .9), (30.0, 96.0, 2.0, .6), (120.0, 150.0, 2.5, .7), (60.0, 200.0, 2.0, .5), (200.0, 120.0, 3.0, .9)];

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('p27.hero'),
    decoration: BoxDecoration(
      gradient: RewardColors.hero,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: RewardColors.heroBorder),
      boxShadow: const [BoxShadow(color: Color(0x296C5BF5), blurRadius: 36, offset: Offset(0, 16))],
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        // 柔光
        Positioned(left: -50, top: -70, child: _glow(200, const Color(0x80D9CEF8))),
        Positioned(right: 60, bottom: -60, child: _glow(180, const Color(0x80F3CBE8))),
        // 浅紫雪点与金星
        for (final (x, y, r, o) in _snow)
          Positioned(
            left: x,
            top: y,
            child: Container(
              width: r,
              height: r,
              decoration: BoxDecoration(color: RewardColors.snow.withValues(alpha: o), shape: BoxShape.circle),
            ),
          ),
        const Positioned(left: 160, top: 180, child: Text('✦', style: TextStyle(fontSize: 10, color: RewardColors.goldDark))),
        // 吉祥物（圣诞毛衣 Fifi，透明背景）
        Positioned(
          right: 2,
          bottom: -6,
          height: 236,
          child: Image.asset(BrandAssets.catXmas, key: const Key('p27.cat'), fit: BoxFit.contain, semanticLabel: t.rewardsHolidayFifi),
        ),
        // 顶部紫金彩灯串
        const Positioned(left: 0, right: 0, top: 0, height: 46, child: CustomPaint(painter: _LightsPainter())),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 38, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x24E9C878),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: RewardColors.badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 用图标而非 ❄ 字符：iOS 会把 ❄ 渲染成蓝色 emoji，与定稿金色不符
                    Icon(Icons.ac_unit_rounded, size: 12, color: RewardColors.badgeText),
                    SizedBox(width: 6),
                    Text(
                      t.rewardsHolidayNewYearLimited,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 2, color: RewardColors.badgeText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: t.rewardsFifiHolidayShop),
                    TextSpan(
                      text: t.rewardsOpeningSoon,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.32, color: RewardColors.heroInk),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 184,
                child: Text(
                  t.rewardsCompleteTasksToEarn,
                  style: TextStyle(fontSize: 13, height: 1.7, color: RewardColors.heroText),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: RewardColors.goldPill,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [BoxShadow(color: Color(0x59E9C878), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: Text(
                  '🎁 $rewardSoon',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: RewardColors.navy),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static Widget _glow(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

/// 彩灯串（mock_reference.html .lights，viewBox 390×46，按宽度缩放）。
class _LightsPainter extends CustomPainter {
  const _LightsPainter();

  static const _bulbs = [
    (40.0, 22.0, RewardColors.gold),
    (105.0, 28.0, RewardColors.lilac),
    (170.0, 20.0, RewardColors.gold),
    (235.0, 26.0, RewardColors.lilac),
    (300.0, 22.0, RewardColors.gold),
    (358.0, 16.0, RewardColors.lilac),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    Offset p(double x, double y) => Offset(x * sx, y);
    // M-5 8 Q 70 34 150 20 T 300 22 T 400 10（T 为平滑二次曲线，控制点取前一控制点的镜像）
    final wire = Path()
      ..moveTo(p(-5, 8).dx, 8)
      ..quadraticBezierTo(p(70, 34).dx, 34, p(150, 20).dx, 20)
      ..quadraticBezierTo(p(230, 6).dx, 6, p(300, 22).dx, 22)
      ..quadraticBezierTo(p(370, 38).dx, 38, p(400, 10).dx, 10);
    canvas.drawPath(
      wire,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0x4D6C5BF5),
    );
    for (final (x, y, c) in _bulbs) {
      canvas.drawCircle(p(x, y), 7, Paint()..color = c.withValues(alpha: .25));
      canvas.drawCircle(p(x, y), 4, Paint()..color = c);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({super.key, required this.level, required this.selected, this.onTap});
  final int level;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: selected ? RewardColors.chipOn : null,
        color: selected ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: selected ? null : Border.all(color: RewardColors.chipBorder, width: 1.5),
        boxShadow: selected ? const [BoxShadow(color: Color(0x527D4DF0), blurRadius: 18, offset: Offset(0, 8))] : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              t.rewardsLevel2(level),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : RewardColors.sub),
            ),
          ),
          if (!selected) ...[
            const SizedBox(width: 3),
            const Icon(Icons.lock_rounded, size: 11, color: RewardColors.goldDark),
          ],
        ],
      ),
    ),
  );
}

enum _PrizeArt { bottle, hat, headphones, bag }

class _PrizeCard extends StatelessWidget {
  const _PrizeCard({super.key, required this.name, required this.xp, required this.art, required this.onTap});
  final String name;
  final int xp;
  final _PrizeArt art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: RewardColors.cardBorder,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x121B1830), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(19)),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const RadialGradient(
                        center: Alignment(0, -.08),
                        radius: .7,
                        colors: [Color(0xFFF1EDFF), Color(0xFFFAF8FF), Color(0x00FAF8FF)],
                        stops: [0, .7, 1],
                      ),
                    ),
                    child: SizedBox(height: 82, width: 100, child: CustomPaint(painter: _PrizePainter(art))),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: RewardColors.ink),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('★', style: TextStyle(fontSize: 13.5, color: RewardColors.goldDark)),
                    const SizedBox(width: 5),
                    Text(
                      '$xp XP',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: RewardColors.pill, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    rewardSoon,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: RewardColors.sub),
                  ),
                ),
              ],
            ),
            Positioned(
              top: -6,
              right: -2,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(color: RewardColors.lockBg, shape: BoxShape.circle),
                child: const Icon(Icons.lock_rounded, size: 12, color: RewardColors.goldDark),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 奖品图（移植自 mock_reference.html 的 SVG，按 viewBox 等比缩放居中）。
class _PrizePainter extends CustomPainter {
  const _PrizePainter(this.art);
  final _PrizeArt art;

  static const _g1 = [Color(0xFF7D4DF0), Color(0xFFC13AC8)];
  static const _g2 = [AppColors.primary, Color(0xFFA944D8)];
  static const _g3 = [AppColors.primary, Color(0xFFC13AC8)];
  static const _g4 = [Color(0xFF8F5BF5), Color(0xFFD63AA8)];

  Size get _viewBox => switch (art) {
    _PrizeArt.bottle => const Size(80, 100),
    _PrizeArt.hat => const Size(100, 80),
    _PrizeArt.headphones || _PrizeArt.bag => const Size(100, 90),
  };

  static Paint _fill(Color c) => Paint()..color = c;

  /// objectBoundingBox 渐变：x1/y1 → x2/y2 对应外接框比例。
  static Paint _grad(Rect box, List<Color> colors, {bool horizontal = false}) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: horizontal ? Alignment.topRight : Alignment.bottomRight,
      colors: colors,
    ).createShader(box);

  static void _text(Canvas canvas, String s, double cx, double baseline, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final asc = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(cx - tp.width / 2, baseline - asc));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final vb = _viewBox;
    final s = (size.width / vb.width) < (size.height / vb.height) ? size.width / vb.width : size.height / vb.height;
    canvas.save();
    canvas.translate((size.width - vb.width * s) / 2, (size.height - vb.height * s) / 2);
    canvas.scale(s);
    switch (art) {
      case _PrizeArt.bottle:
        _bottle(canvas);
      case _PrizeArt.hat:
        _hat(canvas);
      case _PrizeArt.headphones:
        _headphones(canvas);
      case _PrizeArt.bag:
        _bag(canvas);
    }
    canvas.restore();
  }

  void _bottle(Canvas c) {
    c.drawRRect(RRect.fromLTRBR(30, 2, 50, 11, const Radius.circular(4.5)), _fill(RewardColors.navy));
    c.drawPath(
      Path()
        ..moveTo(50, 11)
        ..quadraticBezierTo(64, 13, 60, 23)
        ..lineTo(56, 27),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = RewardColors.navy,
    );
    c.drawRRect(RRect.fromLTRBR(26, 11, 54, 21, const Radius.circular(4)), _fill(AppColors.primary));
    const body = Rect.fromLTRB(20, 20, 60, 96);
    c.drawRRect(
      RRect.fromRectAndCorners(
        body,
        topLeft: const Radius.elliptical(10, 8),
        topRight: const Radius.elliptical(10, 8),
        bottomLeft: const Radius.circular(10),
        bottomRight: const Radius.circular(10),
      ),
      _grad(body, _g1),
    );
    c.drawRect(const Rect.fromLTWH(20, 48, 40, 22), _fill(Colors.white.withValues(alpha: .92)));
    _text(c, 'FinX', 40, 63, 11, AppColors.primary);
  }

  void _hat(Canvas c) {
    const box = Rect.fromLTRB(14, 16, 86, 52);
    c.drawPath(
      Path()
        ..moveTo(14, 46)
        ..arcToPoint(const Offset(86, 46), radius: const Radius.elliptical(36, 30))
        ..lineTo(86, 52)
        ..lineTo(14, 52)
        ..close(),
      _grad(box, _g2),
    );
    c.drawPath(
      Path()
        ..moveTo(50, 16)
        ..arcToPoint(const Offset(86, 46), radius: const Radius.elliptical(36, 30))
        ..lineTo(86, 52)
        ..lineTo(78, 52)
        ..arcToPoint(const Offset(50, 22), radius: const Radius.elliptical(28, 24), clockwise: false)
        ..close(),
      _fill(const Color(0xFF4A3ED1).withValues(alpha: .35)),
    );
    c.drawPath(
      Path()
        ..moveTo(12, 52)
        ..quadraticBezierTo(50, 42, 94, 54)
        ..quadraticBezierTo(96, 64, 84, 62)
        ..lineTo(22, 62)
        ..quadraticBezierTo(10, 62, 12, 52)
        ..close(),
      _fill(RewardColors.navy),
    );
    c.drawCircle(const Offset(50, 16), 4, _fill(RewardColors.lilac));
    _text(c, '✦', 50, 42, 13, RewardColors.gold);
  }

  void _headphones(Canvas c) {
    const box = Rect.fromLTRB(20, 20, 80, 58);
    c.drawPath(
      Path()
        ..moveTo(20, 58)
        ..lineTo(20, 50)
        ..arcToPoint(const Offset(80, 50), radius: const Radius.circular(30))
        ..lineTo(80, 58),
      _grad(box, _g3, horizontal: true)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    c.drawRRect(RRect.fromLTRBR(12, 52, 30, 80, const Radius.circular(8)), _fill(AppColors.primary));
    c.drawRRect(RRect.fromLTRBR(70, 52, 88, 80, const Radius.circular(8)), _fill(const Color(0xFFC13AC8)));
  }

  void _bag(Canvas c) {
    c.drawLine(
      const Offset(24, 34),
      const Offset(76, 20),
      Paint()
        ..color = RewardColors.navy
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    c.save();
    c.translate(44, 50);
    c.rotate(-8 * 3.141592653589793 / 180);
    c.translate(-44, -50);
    const body = Rect.fromLTWH(18, 30, 52, 40);
    c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(12)), _grad(body, _g4));
    c.drawRRect(RRect.fromLTRBR(30, 40, 56, 48, const Radius.circular(4)), _fill(Colors.white.withValues(alpha: .85)));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _PrizePainter oldDelegate) => oldDelegate.art != art;
}

class _ReminderButton extends StatelessWidget {
  const _ReminderButton({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: on,
    child: GestureDetector(
      key: const Key('p27.notify'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: on ? null : AppGradients.grad,
          color: on ? AppColors.primaryWeak : null,
          borderRadius: BorderRadius.circular(999),
          border: on ? Border.all(color: RewardColors.xpBorder, width: 1.5) : null,
          boxShadow: on ? null : const [BoxShadow(color: Color(0x597D4DF0), blurRadius: 26, offset: Offset(0, 12))],
        ),
        child: Text(
          on ? t.rewardsReminderOn : t.rewardsRemindMeAtLaunch,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: on ? AppColors.primary : Colors.white,
          ),
        ),
      ),
    ),
  );
}
