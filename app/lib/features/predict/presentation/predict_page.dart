import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../market/data/market_api.dart';
import '../../market/presentation/market_widgets.dart';
import '../data/predict_api.dart';
import '../domain/predict_rules.dart';
import 'bet_sheet.dart';
import 'predict_widgets.dart';

// F19 预测板块（积分演示版）：design/reward-design/predict_mock.png 定稿，版式参考 predict_reference.html。
// 全程预测积分，不涉及真实资金与券商账户；页面常驻"积分预测 · 演示模式"标识。
// 价格（BTC / SOL 虚拟行情）每 3 秒刷新；多空比例每 3 秒随下注量刷新（数字滚动、比例条平滑过渡）；倒计时逐秒。

class PredictPage extends StatefulWidget {
  const PredictPage({super.key});

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> {
  PredictApi? _api;
  QuoteFeed? _quotes;
  Timer? _poll;
  PredictMarkets? _markets;
  int? _points;
  String? _error;
  String _cat = 'ALL';
  Duration _offset = Duration.zero;
  final Map<String, List<double>> _series = {}; // 价格走势：分时收盘 + 实时报价

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api != null) return;
    final api = AppScope.of(context).api;
    _api = PredictApi(api);
    _quotes = QuoteFeed(MarketApi(api), symbols: const ['BTC', 'SOL'])
      ..addListener(_onQuotes)
      ..start();
    _loadHistory(MarketApi(api));
    _refresh();
    _poll = Timer.periodic(quotePollInterval, (_) => _loadMarkets());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _quotes?.removeListener(_onQuotes);
    _quotes?.dispose();
    super.dispose();
  }

  Future<void> _loadHistory(MarketApi api) async {
    for (final s in const ['BTC', 'SOL']) {
      try {
        final d = await api.instrument(s);
        final closes = [for (final c in d.candles) c.c];
        _series[s] = [...closes.skip(closes.length > 20 ? closes.length - 20 : 0), ...?_series[s]];
        if (mounted) setState(() {});
      } on ApiException {
        // 走势取不到时只显示实时点
      }
    }
  }

  void _onQuotes() {
    for (final s in const ['BTC', 'SOL']) {
      final q = _quotes!.quotes[s];
      if (q == null) continue;
      final list = _series.putIfAbsent(s, () => []);
      if (list.isEmpty || list.last != q.last) list.add(q.last);
      if (list.length > 60) list.removeRange(0, list.length - 60);
    }
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await Future.wait([_loadMarkets(), _loadPoints()]);
  }

  Future<void> _loadMarkets() async {
    try {
      final m = await _api!.markets();
      if (!mounted) return;
      setState(() {
        _markets = m;
        _offset = m.serverTime.difference(DateTime.now().toUtc());
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && !e.isSessionInvalid) setState(() => _error = e.message);
    }
  }

  Future<void> _loadPoints() async {
    try {
      final a = await _api!.account();
      if (mounted) setState(() => _points = a.points);
    } on ApiException {
      // 积分暂时取不到时不显示余额
    }
  }

  Future<void> _bet(PredictMarket m, String outcome) async {
    final placed = await showBetSheet(context, api: _api!, market: m, outcome: outcome, balance: _points ?? 0);
    if (placed == null || !mounted) return;
    setState(() => _points = placed.points);
    showToast(context, t.predictPlaced(fmtPoints(placed.potentialPayout)));
    _loadMarkets();
  }

  List<PredictMarket> get _events => [
    for (final m in _markets?.events ?? const <PredictMarket>[])
      if (_cat == 'ALL' || m.category == _cat) m,
  ];

  bool get _showUpDown => _cat == 'ALL' || _cat == 'CRYPTO';

  @override
  Widget build(BuildContext context) {
    final m = _markets;
    final updown = m?.updown ?? const <PredictMarket>[];
    PredictMarket? btc;
    for (final u in updown) {
      if (u.symbol == 'BTC') btc = u;
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              _header(),
              const SizedBox(height: 8),
              _categories(),
              const SizedBox(height: 12),
              _demoBadge(),
              if (_error != null) Notice(t.predictLoadFailed(_error!), kind: NoticeKind.warn),
              if (m == null && _error == null)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (m != null) ...[
                if (_showUpDown && btc != null) _hero(btc),
                if (_showUpDown && updown.isNotEmpty) ...[
                  _section(
                    t.predict15m,
                    trailing: _cat == 'ALL' ? t.predictSeeAll : null,
                    onTrailing: () => setState(() => _cat = 'CRYPTO'),
                  ),
                  Row(
                    children: [
                      for (final (i, u) in updown.indexed) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: _mini(u))],
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                _section(t.predictTrending, live: true),
                if (_events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(t.predictNoMarkets, style: const TextStyle(color: predictSub)),
                    ),
                  )
                else
                  for (final e in _events) _eventCard(e),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  t.predictDisclaimer,
                  key: const Key('predict.disclaimer'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: predictFaint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
    children: [
      Expanded(
        child: Text(
          t.predictTitle,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: predictInk),
        ),
      ),
      GestureDetector(
        key: const Key('predict.mine'),
        onTap: () async {
          await context.push('/predict/mine');
          _refresh();
        },
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(
            t.predictMine,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
      ),
      Container(
        key: const Key('predict.points'),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE4E0F5), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5B301)),
            const SizedBox(width: 5),
            Text(
              _points == null ? '—' : t.predictPoints(fmtPoints(_points!)),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _categories() => SizedBox(
    height: 30,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final c in predictCategories)
          GestureDetector(
            key: Key('predict.cat.$c'),
            onTap: () => setState(() => _cat = c),
            child: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    predictCategoryLabel(c),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c == _cat ? predictInk : predictFaint),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 3,
                    width: 24,
                    decoration: BoxDecoration(gradient: c == _cat ? AppGradients.grad : null, borderRadius: BorderRadius.circular(2)),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _demoBadge() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      key: const Key('predict.demoBadge'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFFBF3DF), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFB57E0C)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              t.predictDemoBadge,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB57E0C)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _section(String title, {String? trailing, VoidCallback? onTrailing, bool live = false}) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: predictInk),
          ),
        ),
        if (live) ...[
          const LiveDot(),
          const SizedBox(width: 5),
          Text(
            t.predictLive,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ],
        if (trailing != null)
          GestureDetector(
            onTap: onTrailing,
            child: Text(
              '$trailing >',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
      ],
    ),
  );

  BoxDecoration get _card => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(20),
    boxShadow: const [BoxShadow(color: Color(0x121B1830), blurRadius: 22, offset: Offset(0, 8))],
  );

  /// Up or Down 主卡（BTC 当前 15 分钟窗口）。
  Widget _hero(PredictMarket m) {
    final price = _quotes!.quotes['BTC']?.last;
    return Container(
      key: const Key('predict.hero'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.predictUpOrDownSymbol('BTC'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: predictSub),
                ),
              ),
              CountdownPill(until: m.closesAt, offset: _offset, onExpired: _loadMarkets),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const CoinBadge('BTC'),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        price == null ? '—' : fmtUsd(price),
                        key: const Key('predict.hero.price'),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: predictInk,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Text(
                      t.predictTarget(fmtUsd(m.targetPrice ?? 0)),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: predictSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          PriceChart(prices: _series['BTC'] ?? const [], target: m.targetPrice),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _sideButton(m, 'YES')),
              const SizedBox(width: 10),
              Expanded(child: _sideButton(m, 'NO')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sideButton(PredictMarket m, String side) {
    final up = side == 'YES';
    final color = up ? AppColors.up : AppColors.down;
    return GestureDetector(
      key: Key('predict.hero.$side'),
      onTap: () => _bet(m, side),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: up ? predictUpBg : predictDownBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: up ? predictUpBorder : predictDownBorder, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, color: color, size: 26),
            Flexible(
              child: RollingPercent(
                up ? m.yes.percent : m.no.percent,
                prefix: '${up ? t.predictUp : t.predictDown} · ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 15 分钟市场横排卡。
  Widget _mini(PredictMarket m) {
    final sym = m.symbol ?? '';
    final upLeads = m.yes.percent >= m.no.percent;
    final color = upLeads ? AppColors.up : AppColors.down;
    return GestureDetector(
      key: Key('predict.mini.$sym'),
      onTap: () => _bet(m, upLeads ? 'YES' : 'NO'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        decoration: _card.copyWith(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.predictUpOrDown,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: predictSub),
                  ),
                ),
                CountdownPill(until: m.closesAt, offset: _offset, compact: true, onExpired: _loadMarkets),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CoinBadge(sym, size: 22),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '$sym · 15m',
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: predictInk),
                  ),
                ),
                Icon(upLeads ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, color: color, size: 20),
                RollingPercent(
                  upLeads ? m.yes.percent : m.no.percent,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PriceChart(prices: _series[sym] ?? const [], target: m.targetPrice, height: 30, mini: true),
          ],
        ),
      ),
    );
  }

  /// 事件卡（是 / 否两个选项：概率条 + 概率胶囊）。
  Widget _eventCard(PredictMarket m) {
    final week = m.closesAt.difference(DateTime.now()).inDays < 7;
    return Container(
      key: Key('predict.event.${m.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
      decoration: _card.copyWith(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.subtitle.text,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: predictFaint),
                ),
              ),
              if (week) ...[
                const LiveDot(size: 6),
                const SizedBox(width: 4),
                Text(
                  t.predictLiveSettle(fmtMonthDay(m.closesAt)),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.down),
                ),
              ] else
                Text(
                  t.predictCloses(fmtMonthDay(m.closesAt)),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: predictFaint),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            m.title.text,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.45, color: predictInk),
          ),
          const SizedBox(height: 8),
          _outcomeRow(m, m.yes, hot: m.yes.percent >= m.no.percent),
          _outcomeRow(m, m.no, hot: m.no.percent > m.yes.percent),
        ],
      ),
    );
  }

  Widget _outcomeRow(PredictMarket m, PredictOutcome o, {required bool hot}) {
    final yes = o.key == 'YES';
    return InkWell(
      key: Key('predict.event.${m.id}.${o.key}'),
      onTap: () => _bet(m, o.key),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: yes ? predictUpBg : predictDownBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(yes ? Icons.check_rounded : Icons.close_rounded, size: 18, color: yes ? AppColors.up : AppColors.down),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    o.label.text,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: predictInk),
                  ),
                  const SizedBox(height: 5),
                  ProbabilityBar(fraction: o.percent / 100, color: yes ? AppColors.up : AppColors.down),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hot ? AppColors.primaryWeak : const Color(0xFFF4F2FB),
                borderRadius: BorderRadius.circular(11),
              ),
              child: RollingPercent(
                o.percent,
                key: Key('predict.event.${m.id}.${o.key}.pct'),
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: hot ? AppColors.primary : predictInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
