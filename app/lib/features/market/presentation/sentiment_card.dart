import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../data/market_api.dart';
import '../domain/sentiment.dart';
import 'market_widgets.dart';

// F11 扩展：P-09 市场情绪卡（design/reward-design/market_mock.png 定稿；版式参考 market_reference.html）。
// 数据来自 GET /market/sentiment（虚拟行情合成，演示数据），与报价同频每 3 秒刷新。

const _ink = Color(0xFF1B1830);
const _sub = Color(0xFF7A7490);
const _faint = Color(0xFFA7A1BC);
const _track = Color(0xFFF1EFF8);
const _flat = Color(0xFFC9C4DC);
const _needle = Color(0xFF2E2752);

/// 市场情绪轮询（页面可见期间每 3 秒）。失败时保留上次数据，首次失败则不显示卡片。
class SentimentFeed extends ChangeNotifier {
  SentimentFeed(this._api);
  final MarketApi _api;
  MarketSentiment? data;
  Timer? _timer;
  bool _disposed = false;

  void start() {
    _load();
    _timer?.cancel();
    _timer = Timer.periodic(quotePollInterval, (_) => _load());
  }

  Future<void> _load() async {
    try {
      final d = await _api.sentiment();
      if (_disposed) return;
      data = d;
      notifyListeners();
    } on ApiException {
      // 情绪卡为演示数据：失败时静默，保留上次结果
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

class MarketSentimentCard extends StatelessWidget {
  const MarketSentimentCard({super.key, required this.data});
  final MarketSentiment data;

  @override
  Widget build(BuildContext context) {
    final level = FearGreedLevel.of(data.fearGreed);
    final b = data.breadth;
    final (fu, ff, fd) = b.flexes;
    return Container(
      key: const Key('market.sentiment'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0F1B1830), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '市场情绪',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF4F2FB), borderRadius: BorderRadius.circular(999)),
                child: const Text(
                  '演示数据 · 每 3 秒更新',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _faint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 150,
                height: 89,
                // 指针随数值动画摆动（首次从 0 摆到当前值，之后在新旧值之间摆动，略带回弹）
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: data.fearGreed.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutBack,
                  builder: (_, v, _) => CustomPaint(key: const Key('market.gauge'), painter: FearGreedGaugePainter(v)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.fearGreed}',
                      key: const Key('market.fg.value'),
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      key: const Key('market.fg.label'),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: level.bg, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        level.label,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: level.text),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '由虚拟行情的涨跌幅、动量与波动合成',
                      style: TextStyle(fontSize: 11.5, height: 1.6, color: _sub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: _track),
          const SizedBox(height: 13),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '涨跌家数',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _sub),
                ),
              ),
              Text.rich(
                key: const Key('market.breadth.text'),
                TextSpan(
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _sub),
                  children: [
                    TextSpan(
                      text: '${b.up} 涨',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.up),
                    ),
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: '${b.down} 跌',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.down),
                    ),
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: '${b.flat} 平',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 9,
              child: Row(
                children: [
                  for (final (k, (flex, color, name)) in [
                    (fu, AppColors.up, 'up'),
                    (ff, _flat, 'flat'),
                    (fd, AppColors.down, 'down'),
                  ].indexed)
                    if (flex > 0)
                      Expanded(
                        key: Key('market.breadth.bar.$name'),
                        flex: flex,
                        child: Container(
                          margin: EdgeInsets.only(left: k > 0 && _hasBefore(k, fu, ff) ? 2 : 0),
                          color: color,
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _legend(AppColors.up, '上涨 ${b.up}'),
              const SizedBox(width: 14),
              _legend(_flat, '平盘 ${b.flat}'),
              const SizedBox(width: 14),
              _legend(AppColors.down, '下跌 ${b.down}'),
            ],
          ),
        ],
      ),
    );
  }

  /// 第 k 段（1 = 平盘，2 = 下跌）之前是否已有非空段（有才留 2px 间隔）。
  static bool _hasBefore(int k, int up, int flat) => k == 1 ? up > 0 : (up > 0 || flat > 0);

  static Widget _legend(Color c, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _sub),
      ),
    ],
  );
}

/// 半圆仪表盘（market_reference.html 的 SVG，viewBox 200×118：圆心 (100,104)，半径 82，描边 15）。
class FearGreedGaugePainter extends CustomPainter {
  const FearGreedGaugePainter(this.value);

  /// 0–100（动画过程中可能因回弹略超出，绘制时夹紧）。
  final double value;

  /// 指针相对竖直向上的偏转角（度）：0 → -90°（指向左），50 → 0°，100 → +90°（指向右）。
  static double needleDegrees(double v) => (v.clamp(0, 100) - 50) * 1.8;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 200, size.height / 118);
    canvas.save();
    canvas.translate((size.width - 200 * s) / 2, (size.height - 118 * s) / 2);
    canvas.scale(s);
    const center = Offset(100, 104);
    final arcRect = Rect.fromCircle(center: center, radius: 82);
    Paint stroke(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round
      ..color = c;
    canvas.drawArc(arcRect, math.pi, math.pi, false, stroke(_track));
    canvas.drawArc(
      arcRect,
      math.pi,
      math.pi,
      false,
      stroke(Colors.white)
        ..shader = const LinearGradient(
          colors: [Color(0xEBE5484D), Color(0xEBF0A13C), Color(0xEBE9C878), Color(0xEB16A34A)],
          stops: [0, .3, .62, 1],
        ).createShader(const Rect.fromLTRB(18, 0, 182, 0)),
    );
    _label(canvas, '0', 18, 117);
    _label(canvas, '100', 172, 117);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(needleDegrees(value) * math.pi / 180);
    canvas.drawLine(
      Offset.zero,
      const Offset(0, -66),
      Paint()
        ..color = _needle
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    canvas.drawCircle(center, 7, Paint()..color = _needle);
    canvas.drawCircle(center, 3, Paint()..color = Colors.white);
    canvas.restore();
  }

  static void _label(Canvas canvas, String s, double x, double baseline) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _faint),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, baseline - tp.computeDistanceToActualBaseline(TextBaseline.alphabetic)));
  }

  @override
  bool shouldRepaint(covariant FearGreedGaugePainter oldDelegate) => oldDelegate.value != value;
}
