import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// 成功时刻庆祝特效（design/theme.md 第 7 节"动效"）：紫罗兰渐变色系彩带 / 圆点从顶部撒下，混入少量白色爪印，
/// 约 2 秒；覆盖在页面最上层但不拦截点击（IgnorePointer），播放完自动移除。
///
/// "只播一次"：同一个 [key]（如账户号码、入金流水号）在本次运行中只会播放一次，页面刷新 / 重建不重播。
/// 系统开启"减弱动态效果"时不播放动画（触感仍保留）。
abstract final class Celebration {
  static final Set<String> _played = {};

  /// 测试用：清空已播放记录。
  @visibleForTesting
  static void resetForTest() => _played.clear();

  static bool hasPlayed(String key) => _played.contains(key);

  /// 播放一次；[key] 已播放过则忽略，返回是否实际播放。
  static bool show(BuildContext context, {required String key, CelebrationLevel level = CelebrationLevel.full, bool haptic = false}) {
    if (_played.contains(key)) return false;
    _played.add(key);
    if (haptic) HapticFeedback.mediumImpact();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return true;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return true;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: ConfettiBurst(key: Key('celebration.$key'), level: level, seed: key.hashCode, onDone: () => entry.remove()),
      ),
    );
    overlay.insert(entry);
    return true;
  }
}

enum CelebrationLevel {
  /// 开户成功：完整版
  full(90, 7),

  /// 入金提交成功：轻量版（粒子更少）
  light(32, 3);

  const CelebrationLevel(this.pieces, this.paws);
  final int pieces;
  final int paws;
}

/// FinX 渐变色系（theme.md：#5A57EE → #A944D8 → #D63AA8）及其浅色。

class _Piece {
  _Piece(math.Random r, {required this.paw})
    : x = r.nextDouble(),
      delay = r.nextDouble() * .35,
      fall = .75 + r.nextDouble() * .5,
      drift = (r.nextDouble() - .5) * .25,
      sway = 6 + r.nextDouble() * 14,
      swayFreq = 2 + r.nextDouble() * 3,
      spin = (r.nextDouble() - .5) * 10,
      size = paw ? 18 + r.nextDouble() * 8 : 6 + r.nextDouble() * 6,
      ribbon = !paw && r.nextBool(),
      color = paw ? CelebrationColors.paw : CelebrationColors.palette[r.nextInt(CelebrationColors.palette.length)];

  final bool paw;
  final double x, delay, fall, drift, sway, swayFreq, spin, size;
  final bool ribbon;
  final Color color;
}

/// 一次性的粒子动画（约 2 秒）。
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.level = CelebrationLevel.full, this.seed = 0, this.onDone});
  final CelebrationLevel level;
  final int seed;
  final VoidCallback? onDone;

  static const duration = Duration(milliseconds: 2000);

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: ConfettiBurst.duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    })
    ..forward();
  late final List<_Piece> _pieces = () {
    final r = math.Random(widget.seed);
    return [
      for (var i = 0; i < widget.level.pieces; i++) _Piece(r, paw: false),
      for (var i = 0; i < widget.level.paws; i++) _Piece(r, paw: true),
    ];
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(child: CustomPaint(painter: _ConfettiPainter(_pieces, _c)));
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.anim) : super(repaint: anim);
  final List<_Piece> pieces;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final paint = Paint();
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -30 + local * p.fall * (size.height + 60);
      final x = (p.x + p.drift * local) * size.width + math.sin(local * math.pi * p.swayFreq) * p.sway;
      final fade = local > .8 ? (1 - local) / .2 : 1.0; // 最后 20% 淡出
      paint.color = p.color.withValues(alpha: p.color.a * fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      if (p.paw) {
        _paw(canvas, p.size, paint, shadowAlpha: .18 * fade);
      } else if (p.ribbon) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size * .5, height: p.size * 1.6), const Radius.circular(2)),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  /// 爪印：一个掌垫 + 四个趾垫（白色，带淡紫描边以便浅底可见）。
  void _paw(Canvas canvas, double s, Paint fill, {required double shadowAlpha}) {
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = CelebrationColors.pawOutline.withValues(alpha: shadowAlpha * 3);
    final pad = Rect.fromCenter(center: Offset(0, s * .18), width: s * .62, height: s * .5);
    final toes = [Offset(-s * .36, -s * .12), Offset(-s * .13, -s * .34), Offset(s * .13, -s * .34), Offset(s * .36, -s * .12)];
    canvas.drawOval(pad, fill);
    canvas.drawOval(pad, outline);
    for (final o in toes) {
      canvas.drawCircle(o, s * .13, fill);
      canvas.drawCircle(o, s * .13, outline);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
