import 'dart:async';
import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../data/market_api.dart';
import '../domain/insiders.dart';
import '../domain/instruments.dart';
import 'market_widgets.dart';
import '../../../l10n/l10n.dart';

/// P-09 市场（Tab 2，仅展示；F22-b 定稿 design/reward-design/v3/market_v2.png，参考 market_v2.html）。
/// - 标题右侧搜索 → 搜索页（标的池，点击进个股页）；"美国市场"纯文字标签（无下划线）；股票 / ETF 切换。
/// - 股票：QQQ / SPY / DIA 三张渐变指数卡 + 白色迷你走势（IWM 移除）；市场统计（涨跌分布 9 档，今日 / 近 30 日，
///   底部上涨 / 下跌比例条，GET /market/stats）；内部人交易三卡（演示数据角标，seed）；涨幅榜 / 跌幅榜。
/// - ETF：ETF 排行（分类筛选）不变。
/// - 恐慌贪婪 UI 移除（GET /market/sentiment 接口保留）。全部为虚拟行情。
const indexSymbols = ['QQQ', 'SPY', 'DIA'];

/// 迷你走势取最近的分时根数。
const sparkBars = 60;

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  QuoteFeed? _feed;
  MarketApi? _api;
  String _seg = 'STOCK';
  String? _etfCat; // null = 全部
  String _period = 'TODAY';
  final _stats = <String, MarketStats>{};
  bool _statsFailed = false;
  final _spark = <String, List<double>>{};
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api == null) {
      _api = MarketApi(AppScope.of(context).api);
      _feed = QuoteFeed(_api!)..start();
      _loadStats();
      _loadSparks();
      // 今日统计随行情变化：每 15 秒刷新；迷你走势每分钟刷新
      _timer = Timer.periodic(const Duration(seconds: 15), (t) {
        if (_period == 'TODAY') _loadStats();
        if (t.tick % 4 == 0) _loadSparks();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _feed?.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final p = _period;
    try {
      final s = await _api!.stats(p);
      if (!mounted) return;
      setState(() {
        _stats[p] = s;
        if (p == _period) _statsFailed = false;
      });
    } on ApiException {
      if (mounted && p == _period && !_stats.containsKey(p)) setState(() => _statsFailed = true);
    }
  }

  Future<void> _loadSparks() async {
    for (final s in indexSymbols) {
      try {
        final d = await _api!.instrument(s);
        if (!mounted) return;
        final cs = d.candles;
        setState(() => _spark[s] = [for (final c in cs.skip(math.max(0, cs.length - sparkBars))) c.c]);
      } on ApiException {
        // 迷你走势为装饰：失败时不画线
      }
    }
  }

  void _setPeriod(String p) {
    if (p == _period) return;
    setState(() {
      _period = p;
      _statsFailed = false;
    });
    _loadStats();
  }

  List<InstrumentInfo> _sorted(String type, {bool desc = true, String? cat}) {
    final qs = _feed!.quotes;
    final list = instruments.where((i) => i.type == type && qs.containsKey(i.symbol) && (cat == null || i.etfCategory == cat)).toList()
      ..sort((a, b) => (desc ? -1 : 1) * qs[a.symbol]!.chgPct.compareTo(qs[b.symbol]!.chgPct));
    return list;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(t.tabMarkets),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Semantics(
            button: true,
            label: t.marketSearch,
            child: InkWell(
              key: const Key('market.search'),
              customBorder: const CircleBorder(),
              onTap: () => context.push('/market/search'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Icon(Icons.search_rounded, size: 19, color: AppColors.sub),
              ),
            ),
          ),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: _feed!,
      builder: (context, _) {
        final f = _feed!;
        final children = <Widget>[
          Text(
            t.marketUsMarket,
            key: const Key('market.region'),
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          _segPills(),
          const SizedBox(height: 14),
          if (f.error != null) Notice(t.marketCouldnTRefreshQuotes(f.error!), kind: NoticeKind.warn),
          if (f.quotes.isEmpty && f.error == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
        ];
        if (f.quotes.isNotEmpty) {
          if (_seg == 'STOCK') {
            children.addAll([
              Row(
                children: [
                  for (final (k, s) in indexSymbols.indexed) ...[
                    if (k > 0) const SizedBox(width: 10),
                    Expanded(child: _indexCard(k, s, f)),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              _statsSection(),
              _insiderSection(),
              SectionTitle(t.marketTopGainers),
              _list([for (final i in _sorted('STOCK').take(5)) i.symbol], f),
              SectionTitle(t.marketTopLosers),
              _list([for (final i in _sorted('STOCK', desc: false).take(3)) i.symbol], f),
            ]);
          } else {
            children.addAll([
              SectionTitle(t.marketEtfRankings),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in <String?>[null, ...etfCategories])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChipToggle(
                          label: c == null ? t.marketAll : etfCategoryLabel(c),
                          selected: _etfCat == c,
                          onTap: () => setState(() => _etfCat = c),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _list([for (final i in _sorted('ETF', cat: _etfCat)) i.symbol], f),
            ]);
          }
        }
        children.add(MarketDataNote(ts: f.ts));
        return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: children);
      },
    ),
  );

  /// 股票 / ETF 胶囊（定稿：选中实色紫，未选白底紫字描边）。
  Widget _segPills() => Row(
    children: [
      for (final (v, label) in [('STOCK', t.assetStock), ('ETF', 'ETF')]) ...[
        GestureDetector(
          key: Key('market.seg.$v'),
          onTap: () => setState(() => _seg = v),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: _seg == v ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _seg == v ? Colors.transparent : AppColors.border, width: 1.5),
              boxShadow: _seg == v ? [BoxShadow(color: AppColors.primary.withValues(alpha: .3), blurRadius: 12, offset: const Offset(0, 5))] : null,
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _seg == v ? AppColors.onAccent : AppColors.primary),
            ),
          ),
        ),
      ],
    ],
  );

  Widget _indexCard(int k, String symbol, QuoteFeed f) {
    final q = f.quotes[symbol];
    final spark = _spark[symbol];
    return GestureDetector(
      key: Key('market.index.$symbol'),
      onTap: () => context.push('/market/$symbol'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        decoration: BoxDecoration(gradient: MarketColors.indexGrads[k % 3], borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              symbol,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onAccent.withValues(alpha: .9)),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                q == null ? '—' : fmtPx(q.last),
                style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: AppColors.onAccent, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            if (q != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  fmtSigned(q.chgPct, suffix: '%'),
                  key: Key('market.index.$symbol.chg'),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: q.chgPct < 0 ? MarketColors.downOnGrad : MarketColors.upOnGrad),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              height: 26,
              width: double.infinity,
              child: spark == null || spark.length < 2
                  ? null
                  : CustomPaint(key: Key('market.index.$symbol.spark'), painter: SparkPainter(spark)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHead(String title, {Widget? badge, Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
        if (badge != null) ...[const SizedBox(width: 8), badge],
        const Spacer(),
        ?trailing,
      ],
    ),
  );

  Widget _statsSection() {
    Widget tab(String p, String label) => GestureDetector(
      key: Key('market.stats.$p'),
      onTap: () => _setPeriod(p),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: _period == p ? FontWeight.w800 : FontWeight.w600,
          color: _period == p ? AppColors.ink : AppColors.sub,
        ),
      ),
    );
    final s = _stats[_period];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHead(
          t.marketStats,
          trailing: Row(
            children: [
              tab('TODAY', t.marketStatsToday),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(width: 1.5, height: 12, color: AppColors.sub.withValues(alpha: .5)),
              ),
              tab('30D', t.marketStats30d),
            ],
          ),
        ),
        Container(
          key: const Key('market.stats'),
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: _statsFailed && s == null
              ? _statsPlaceholder(t.homeCouldnTRefreshPlease)
              : s == null
              ? const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()))
              : s.insufficient || s.counts.length != 9
              ? _statsPlaceholder(s.since == null ? t.marketStatsBuilding : t.marketStatsBuildingSince(s.since!), key: const Key('market.stats.building'))
              : MarketHistogram(stats: s),
        ),
      ],
    );
  }

  Widget _statsPlaceholder(String text, {Key? key}) => SizedBox(
    height: 150,
    child: Center(
      child: Text(
        text,
        key: key,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.hint),
      ),
    ),
  );

  Widget _insiderSection() {
    final badge = Container(
      key: const Key('market.insiders.demo'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: MarketColors.demoBg, borderRadius: BorderRadius.circular(999)),
      child: Text(t.demoDataBadge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: MarketColors.demoFg)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHead(
          t.marketInsiders,
          badge: badge,
          trailing: InkWell(
            key: const Key('market.insiders.more'),
            onTap: () => showToast(context, t.insiderMoreComingSoon),
            child: Icon(Icons.chevron_right_rounded, color: AppColors.sub),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            children: [
              for (final (k, h) in insiderHighlights.indexed) ...[
                if (k > 0) const SizedBox(width: 10),
                Expanded(child: _insiderCard(h)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _insiderCard(InsiderHighlight h) {
    final (title, detail, bg, fg) = switch (h.kind) {
      InsiderKind.topBuy => (t.insiderTopBuy, t.insiderBought('\$${h.amountB!.toStringAsFixed(1)}B'), MarketColors.buyBg, AppColors.up),
      InsiderKind.topSell => (t.insiderTopSell, t.insiderSold('\$${h.amountB!.toStringAsFixed(1)}B'), MarketColors.sellBg, AppColors.down),
      InsiderKind.mostActive => (t.insiderMostActive, t.insiderTrades(h.trades!), MarketColors.activeBg, AppColors.primary),
    };
    return GestureDetector(
      key: Key('market.insider.${h.kind.name}'),
      onTap: () => context.push('/market/${h.symbol}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub)),
            const SizedBox(height: 4),
            Text(h.symbol, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(detail, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<String> symbols, QuoteFeed f) => symbols.isEmpty
      ? AppCard(
          child: Text(t.marketNone, style: TextStyle(color: AppColors.muted)),
        )
      : ListGroup(
          children: [for (final s in symbols) QuoteRow(symbol: s, quote: f.quotes[s], moved: f.moved[s] ?? 0)],
        );
}

/// 涨跌分布直方图（9 档：红 = 下跌，灰 = 平，绿 = 上涨）+ 底部下跌 / 平 / 上涨比例条与家数。
class MarketHistogram extends StatelessWidget {
  const MarketHistogram({super.key, required this.stats});
  final MarketStats stats;

  static const labels = ['>7%', '7~5', '5~3', '3~0', '0', '0~3', '3~5', '5~7', '>7%'];

  static Color colorOf(int i) => i < 4 ? AppColors.down : (i == 4 ? MarketColors.flatBar : AppColors.up);

  @override
  Widget build(BuildContext context) {
    final c = stats.counts;
    final peak = c.fold<int>(0, math.max);
    final total = stats.up + stats.down + stats.flat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 118,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 9; i++)
                Expanded(
                  child: Column(
                    key: Key('market.stats.bar.$i'),
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${c[i]}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: i == 4 ? MarketColors.flatText : colorOf(i)),
                      ),
                      const SizedBox(height: 3),
                      FractionallySizedBox(
                        widthFactor: .7,
                        child: Container(
                          height: peak == 0 ? 2 : math.max(2, 76 * c[i] / peak),
                          decoration: BoxDecoration(
                            color: colorOf(i),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(labels[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.hint)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 7,
            child: Row(
              children: [
                if (total == 0)
                  Expanded(child: ColoredBox(color: MarketColors.flatBar))
                else ...[
                  if (stats.down > 0) Expanded(key: const Key('market.stats.ratio.down'), flex: stats.down, child: ColoredBox(color: AppColors.down)),
                  if (stats.down > 0 && (stats.flat > 0 || stats.up > 0)) const SizedBox(width: 2),
                  if (stats.flat > 0) Expanded(key: const Key('market.stats.ratio.flat'), flex: stats.flat, child: ColoredBox(color: MarketColors.flatBar)),
                  if (stats.flat > 0 && stats.up > 0) const SizedBox(width: 2),
                  if (stats.up > 0) Expanded(key: const Key('market.stats.ratio.up'), flex: stats.up, child: ColoredBox(color: AppColors.up)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(t.marketStatsDown(stats.down), key: const Key('market.stats.down'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.down)),
            const Spacer(),
            Text(t.marketStatsUp(stats.up), key: const Key('market.stats.up'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.up)),
          ],
        ),
        const SizedBox(height: 6),
        Text(t.marketStatsNote, style: TextStyle(fontSize: 10.5, color: AppColors.faint)),
      ],
    );
  }
}

/// 指数卡白色迷你走势。
class SparkPainter extends CustomPainter {
  const SparkPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final path = Path();
    for (final (i, v) in values.indexed) {
      final x = size.width * i / (values.length - 1);
      final y = hi == lo ? size.height / 2 : 2 + (size.height - 4) * (1 - (v - lo) / (hi - lo));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.onAccent.withValues(alpha: .9),
    );
  }

  @override
  bool shouldRepaint(covariant SparkPainter old) => old.values.toString() != values.toString();
}
