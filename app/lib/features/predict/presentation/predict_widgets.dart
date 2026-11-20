import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format.dart';
import '../domain/predict_rules.dart';

// F19 预测板块的动态组件。系统开启"减弱动态效果"时：数字与比例条直接跳到新值，Live 红点不闪动。


bool reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// 百分比数字滚动（多空比例变化时）。
class RollingPercent extends StatelessWidget {
  const RollingPercent(this.value, {super.key, this.style, this.prefix = '', this.suffix = '%'});
  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value.toDouble()),
    duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 600),
    curve: Curves.easeOutCubic,
    builder: (_, v, _) => Text('$prefix${v.round()}$suffix', style: style),
  );
}

/// 概率条平滑过渡。
class ProbabilityBar extends StatelessWidget {
  const ProbabilityBar({super.key, required this.fraction, required this.color, this.height = 5});
  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height),
    child: Container(
      height: height,
      color: AppColors.track,
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: fraction.clamp(0, 1)),
        duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, f, _) => FractionallySizedBox(
          widthFactor: f,
          child: Container(color: color),
        ),
      ),
    ),
  );
}

/// "Live" 红点：1 秒周期呼吸闪动。
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 7, this.color});
  final double size;
  final Color? color; // 默认跌色（红）

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
      _c.value = 1;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true); // 0.5 秒渐暗 + 0.5 秒渐亮 = 1 秒周期
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    key: const Key('predict.liveDot'),
    opacity: Tween(begin: .25, end: 1.0).animate(_c),
    child: Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color ?? AppColors.down, shape: BoxShape.circle),
    ),
  );
}

/// 逐秒倒计时（[offset] = 服务器时间 − 本地时间，用于校准）。
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.until, this.offset = Duration.zero, this.style, this.onExpired});
  final DateTime until;
  final Duration offset;
  final TextStyle? style;
  final VoidCallback? onExpired;

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _timer;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(Countdown old) {
    super.didUpdateWidget(old);
    if (old.until != widget.until) _fired = false;
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (!_fired && _left.isNegative) {
      _fired = true;
      widget.onExpired?.call();
    }
  }

  Duration get _left => widget.until.difference(DateTime.now().toUtc().add(widget.offset));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(fmtCountdown(_left), style: widget.style);
}

/// 倒计时胶囊（⏱ 11:26）。
class CountdownPill extends StatelessWidget {
  const CountdownPill({super.key, required this.until, required this.offset, this.onExpired, this.compact = false});
  final DateTime until;
  final Duration offset;
  final VoidCallback? onExpired;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: compact ? 11 : 12.5,
      fontWeight: FontWeight.w800,
      color: compact ? AppColors.sub : AppColors.primary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: compact ? 12 : 14, color: style.color),
        const SizedBox(width: 3),
        Countdown(until: until, offset: offset, style: style, onExpired: onExpired),
      ],
    );
    if (compact) return row;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(color: AppColors.pill, borderRadius: BorderRadius.circular(999)),
      child: row,
    );
  }
}

/// 价格走势（面积折线 + 目标价虚线与标签 + 最新点高亮）。价格高于目标为绿色，否则红色。
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.prices, this.target, this.height = 96, this.mini = false});
  final List<double> prices;
  final double? target;
  final double height;
  final bool mini;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _ChartPainter(prices, target, mini)),
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.prices, this.target, this.mini);
  final List<double> prices;
  final double? target;
  final bool mini;

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;
    final up = target == null ? prices.last >= prices.first : prices.last >= target!;
    final color = up ? AppColors.up : AppColors.down;
    final all = [...prices, ?target];
    var lo = all.reduce(math.min), hi = all.reduce(math.max);
    if (hi - lo < 1e-9) {
      hi += 1;
      lo -= 1;
    }
    final padY = mini ? 4.0 : 10.0;
    final right = mini ? 6.0 : 60.0; // 主卡右侧留出最新点与目标价标签
    final w = size.width - 4 - right, h = size.height - padY * 2;
    Offset at(int i, double v) => Offset(4 + w * i / (prices.length - 1), padY + h * (1 - (v - lo) / (hi - lo)));
    final pts = [for (final (i, v) in prices.indexed) at(i, v)];
    if (target != null) {
      final y = at(0, target!).dy;
      final dash = Paint()
        ..color = AppColors.flat
        ..strokeWidth = 1.5;
      for (var x = 0.0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, size.width), y), dash);
      }
      if (!mini) {
        final tp = TextPainter(
          text: TextSpan(
            text: fmtUsd(target!),
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(size.width - tp.width - 14, y - 10, tp.width + 14, 20), const Radius.circular(10));
        canvas.drawRRect(r, Paint()..color = AppColors.primaryWeak);
        tp.paint(canvas, Offset(r.left + 7, y - tp.height / 2));
      }
    }
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    if (!mini) {
      final area = Path.from(line)
        ..lineTo(pts.last.dx, size.height)
        ..lineTo(pts.first.dx, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: .18), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = mini ? 2.2 : 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    if (!mini) {
      canvas.drawCircle(pts.last, 8.5, Paint()..color = color.withValues(alpha: .18));
    }
    canvas.drawCircle(pts.last, mini ? 3.5 : 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.prices != prices || old.target != target;
}

/// 币种圆标（BTC ₿ 橙色 / SOL S 深色）。
class CoinBadge extends StatelessWidget {
  const CoinBadge(this.symbol, {super.key, this.size = 40});
  final String symbol;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: symbol == 'BTC' ? BrandColors.bitcoin : AppColors.coin, shape: BoxShape.circle),
    child: Text(
      symbol == 'BTC' ? '₿' : symbol.substring(0, 1),
      style: TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.w800, fontSize: size * .5),
    ),
  );
}
