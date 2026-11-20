import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../data/market_api.dart';
import '../domain/instruments.dart';
import 'market_widgets.dart';

/// P-10 个股详情。报价区展示买一 / 卖一（PDF-5 NBBO 的数量与交易所标识在接入真实行情后补齐）；
/// 图表为虚拟行情的 1 分钟分时。底部买入 / 卖出进入 P-19（F14）。
class InstrumentPage extends StatefulWidget {
  const InstrumentPage({super.key, required this.symbol});
  final String symbol;

  @override
  State<InstrumentPage> createState() => _InstrumentPageState();
}

class _InstrumentPageState extends State<InstrumentPage> {
  InstrumentDetail? _d;
  Quote? _nbbo; // 买一 / 卖一：个股接口不含 bid/ask，取自批量报价接口
  String? _error;
  Timer? _timer;
  DateTime? _at;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _timer = Timer.periodic(quotePollInterval, (_) => _load());
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    try {
      final api = MarketApi(AppScope.of(context).api);
      final (d, b) = await (api.instrument(widget.symbol), api.quotes([widget.symbol])).wait;
      if (!mounted) return;
      setState(() {
        _d = d;
        _nbbo = b.quotes[widget.symbol];
        _at = DateTime.now();
        _error = null;
      });
    } on ParallelWaitError<(InstrumentDetail?, QuoteBatch?), (AsyncError?, AsyncError?)> catch (e) {
      final err = e.errors.$1?.error ?? e.errors.$2?.error;
      if (!mounted) return;
      setState(() => _error = err is ApiException ? err.message : '$err');
      if (_d == null) _timer?.cancel(); // 证券不存在等：不再轮询
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wl = Watchlist.instance;
    return ListenableBuilder(
      listenable: wl,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: '/market'),
          title: Text(widget.symbol),
          actions: [
            IconButton(
              key: const Key('p10.watch'),
              tooltip: '自选',
              icon: Icon(
                wl.contains(widget.symbol) ? Icons.star_rounded : Icons.star_border_rounded,
                color: wl.contains(widget.symbol) ? AppColors.warn : null,
              ),
              onPressed: () {
                final had = wl.contains(widget.symbol);
                wl.toggle(widget.symbol);
                showToast(context, had ? '已从自选移除' : '已加入自选');
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _body()),
            FooterBar(
              children: [
                Expanded(
                  child: AppButton(
                    '卖出',
                    key: const Key('p10.sell'),
                    kind: ButtonKind.secondary,
                    onPressed: _d == null ? null : () => context.push('/trade/${widget.symbol}?side=SELL'),
                  ),
                ),
                Expanded(
                  child: AppButton(
                    '买入',
                    key: const Key('p10.buy'),
                    onPressed: _d == null ? null : () => context.push('/trade/${widget.symbol}?side=BUY'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final d = _d;
    if (d == null) {
      return _error == null
          ? const Center(child: CircularProgressIndicator())
          : StateView(icon: Icons.search_off_rounded, title: '暂时无法查看', message: _error!);
    }
    final q = d.quote;
    final color = chgColor(q.chg);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        if (_error != null) Notice('行情暂时无法刷新：$_error', kind: NoticeKind.warn),
        Text(d.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(
          '${d.symbol} · ${d.exchange} · ${d.type == 'ETF' ? 'ETF' : '股票'}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              fmtPx(q.last),
              key: const Key('p10.last'),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${fmtSigned(q.chg)}  ${fmtSigned(q.chgPct, suffix: '%')}',
                key: const Key('p10.chg'),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
        Text('${d.simulated ? '虚拟行情（演示数据）' : '实时'} · 更新于 ${fmtTime(_at)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SectionTitle('报价'),
        Row(
          children: [
            Expanded(child: _px('买一价（Bid）', _nbbo?.bid, AppColors.up)),
            const SizedBox(width: 8),
            Expanded(child: _px('卖一价（Ask）', _nbbo?.ask, AppColors.down)),
          ],
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 170,
                width: double.infinity,
                child: CustomPaint(
                  key: const Key('p10.chart'),
                  painter: LineChartPainter([for (final c in d.candles) c.c], color: color, baseline: d.prevClose),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Text('分时（1 分钟） · 虚线为昨收', style: TextStyle(fontSize: 12, color: AppColors.faint)),
              ),
            ],
          ),
        ),
        const SectionTitle('关键数据'),
        AppCard(
          child: Column(children: [KvRow('昨收', fmtPx(d.prevClose)), KvRow('今日最高', fmtPx(d.dayHigh)), KvRow('今日最低', fmtPx(d.dayLow))]),
        ),
        MarketDataNote(ts: _at),
      ],
    );
  }

  Widget _px(String label, double? v, Color c) => AppCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(
          v == null ? '—' : fmtPx(v),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ],
    ),
  );
}

/// 折线图（原型 lineChart）：收盘价折线 + 渐变填充 + 昨收虚线。
class LineChartPainter extends CustomPainter {
  LineChartPainter(this.values, {required this.color, this.baseline});
  final List<double> values;
  final Color color;
  final double? baseline;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (baseline != null) {
      lo = lo < baseline! ? lo : baseline!;
      hi = hi > baseline! ? hi : baseline!;
    }
    final span = (hi - lo) == 0 ? 1.0 : hi - lo;
    double y(double v) => size.height - 6 - (v - lo) / span * (size.height - 12);
    double x(int i) => i / (values.length - 1) * size.width;

    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .18), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    if (baseline != null) {
      final by = y(baseline!);
      final dash = Paint()
        ..color = AppColors.faint
        ..strokeWidth = 1;
      for (var dx = 0.0; dx < size.width; dx += 8) {
        canvas.drawLine(Offset(dx, by), Offset(dx + 4, by), dash);
      }
    }
  }

  @override
  bool shouldRepaint(LineChartPainter old) => old.values != values || old.color != color || old.baseline != baseline;
}
