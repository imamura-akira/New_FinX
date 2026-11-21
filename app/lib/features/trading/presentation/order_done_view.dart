import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../market/domain/instruments.dart';
import '../data/trading_api.dart';
import '../domain/trading_rules.dart';
import 'paper_widgets.dart';
import '../../../l10n/l10n.dart';

/// F22-c 成交成功页（定稿 design/reward-design/v3/order_done.png，参考 order_done.html）。实盘与模拟盘通用：
/// 对勾徽章 → "下单成功" → 公司 · 数量 → Fifi 举回执（从紫色波浪探出）→ 成交摘要卡（代码 / 成交价 / 数量 / 总金额 / 时间，
/// 实盘取 DW 订单回执，模拟盘取模拟撮合）→ 返回首页。只在下单即成交（FILLED）时进入；其余（已提交、挂单、待确认、被拒）走原结果页。
/// 庆祝彩带、提示音与触感由下单页在进入时触发（同一订单只播一次）；模拟盘右上角琥珀"模拟"角标。
class OrderDoneView extends StatelessWidget {
  const OrderDoneView({super.key, required this.order, required this.paper});
  final Order order;
  final bool paper;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final qty = o.filledQty ?? o.quantity ?? 0;
    final name = instrumentOf(o.symbol)?.name ?? o.symbol;
    final total = o.totalAmount ?? ((o.avgPrice ?? 0) * qty);
    return Scaffold(
      key: const Key('orderDone'),
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // 底部紫色波浪（自 Fifi 脚下延伸到页底）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            child: LayoutBuilder(
              builder: (context, c) => Padding(
                padding: EdgeInsets.only(top: c.maxHeight * .50), // Fifi 从波浪中探出
                child: ClipPath(
                  clipper: _WaveClipper(),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: OrderDoneColors.wave,
                        stops: const [0, .4, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                _badge(),
                const SizedBox(height: 12),
                Text(
                  t.orderDoneTitle,
                  key: const Key('orderDone.title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: .5),
                ),
                const SizedBox(height: 5),
                Text(
                  '$name · ${t.ordersShares(fmtQty(qty))}',
                  key: const Key('orderDone.subtitle'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.sub),
                ),
                const SizedBox(height: 4),
                SizedBox(height: 250, child: _scene()),
                _summary(o, qty, total),
                const SizedBox(height: 18),
                AppButton(t.orderDoneBackHome, key: const Key('orderDone.home'), onPressed: () => context.go('/home')),
              ],
            ),
          ),
          if (paper)
            const SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(padding: EdgeInsets.fromLTRB(0, 12, 16, 0), child: PaperBadge()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge() => Center(
    child: Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: OrderDoneColors.badgeRing, width: 3),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .22), blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: Icon(Icons.check_rounded, size: 34, color: AppColors.primary),
    ),
  );

  /// Fifi 举回执 + 装饰（闪光、金币、上行箭头）。
  Widget _scene() => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned(left: 46, top: 8, child: _spark(14)),
      Positioned(right: 50, top: 40, child: _spark(11)),
      Positioned(left: 24, top: 120, child: _spark(12)),
      Positioned(right: 30, top: 6, child: CustomPaint(size: const Size(64, 46), painter: _ArrowPainter())),
      Positioned(left: 18, top: 128, child: _coin(OrderDoneColors.coinPurple, 26, 18, -.3)),
      Positioned(right: 36, bottom: 30, child: _coin(OrderDoneColors.coinGold, 26, 18, .25)),
      Positioned(right: 74, bottom: 104, child: _coin(OrderDoneColors.coinPurple, 20, 14, -.14)),
      Align(
        alignment: Alignment.bottomCenter,
        child: Image.asset(BrandAssets.fifiOrder, key: const Key('orderDone.fifi'), height: 246, semanticLabel: 'Fifi'),
      ),
    ],
  );

  Widget _spark(double size) => Text('✦', style: TextStyle(fontSize: size, color: OrderDoneColors.sparkle));

  Widget _coin(List<Color> c, double w, double h, double angle) => Transform.rotate(
    angle: angle,
    child: Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
        gradient: RadialGradient(center: const Alignment(-.3, -.4), colors: c),
      ),
    ),
  );

  Widget _summary(Order o, double qty, double total) {
    Widget row(String k, String v, String key) => Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          Text(k, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.sub)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              v,
              key: Key('orderDone.$key'),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.primary, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
    return Container(
      key: const Key('orderDone.summary'),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.cardShadow2, blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: OrderDoneColors.badgeRing, borderRadius: BorderRadius.circular(9)),
                  child: Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(t.orderDoneSummary, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ],
            ),
          ),
          row(t.orderDoneSymbol, o.symbol, 'symbol'),
          row(t.orderDonePrice, o.avgPrice == null ? '—' : fmtUsd(o.avgPrice!), 'price'),
          row(t.orderDoneQty, t.ordersShares(fmtQty(qty)), 'qty'),
          row(t.orderDoneTotal, fmtUsd(total), 'total'),
          row(t.orderDoneTime, fmtEtDateTime(o.doneAt ?? o.updatedAt ?? o.submittedAt), 'time'),
        ],
      ),
    );
  }
}

/// 波浪顶边：中间高、两侧低的椭圆弧。
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 40)
    ..quadraticBezierTo(size.width / 2, -24, size.width, 40)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 绿色上行箭头（order_done.html 的 SVG，viewBox 70×50）。
class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 70;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = OrderDoneColors.arrow;
    canvas.drawPath(
      Path()
        ..moveTo(4 * s, 44 * s)
        ..lineTo(22 * s, 28 * s)
        ..lineTo(34 * s, 36 * s)
        ..lineTo(52 * s, 16 * s),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(42 * s, 12 * s)
        ..lineTo(56 * s, 12 * s)
        ..lineTo(56 * s, 26 * s),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
