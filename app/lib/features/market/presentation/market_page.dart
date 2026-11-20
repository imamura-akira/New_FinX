import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../data/market_api.dart';
import '../domain/instruments.dart';
import 'market_widgets.dart';
import 'sentiment_card.dart';
import '../../../l10n/l10n.dart';

/// P-09 市场（Tab 2，仅展示）。数据来自后端虚拟行情（F11）。
/// Demo-1 范围：指数卡片（SPY / QQQ / DIA / IWM）、市场情绪（恐慌贪婪指数 + 涨跌家数，由虚拟行情合成，F11 扩展）、
/// 涨幅榜 / 跌幅榜、ETF 排行（分类筛选）。内部人增减持、今日热点与成交额没有数据源，不展示（不造假数据）。
/// P-09 指数卡（四张等分，均为虚拟行情）。IWM：罗素 2000（F11 扩展）。
const indexSymbols = ['SPY', 'QQQ', 'DIA', 'IWM'];

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  QuoteFeed? _feed;
  SentimentFeed? _mood;
  String _seg = 'STOCK';
  String? _etfCat; // null = 全部

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _feed ??= QuoteFeed(MarketApi(AppScope.of(context).api))..start();
    _mood ??= SentimentFeed(MarketApi(AppScope.of(context).api))..start();
  }

  @override
  void dispose() {
    _feed?.dispose();
    _mood?.dispose();
    super.dispose();
  }

  List<InstrumentInfo> _sorted(String type, {bool desc = true, String? cat}) {
    final qs = _feed!.quotes;
    final list = instruments.where((i) => i.type == type && qs.containsKey(i.symbol) && (cat == null || i.etfCategory == cat)).toList()
      ..sort((a, b) => (desc ? -1 : 1) * qs[a.symbol]!.chgPct.compareTo(qs[b.symbol]!.chgPct));
    return list;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t.tabMarkets)),
    body: ListenableBuilder(
      listenable: Listenable.merge([_feed!, _mood!]),
      builder: (context, _) {
        final f = _feed!;
        final children = <Widget>[
          Seg2<String>(items: [('STOCK', t.assetStock), ('ETF', 'ETF')], value: _seg, onChanged: (v) => setState(() => _seg = v)),
          const SizedBox(height: 12),
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
                    if (k > 0) const SizedBox(width: 8),
                    Expanded(child: _indexCard(s, f)),
                  ],
                ],
              ),
              if (_mood!.data case final m?) ...[const SizedBox(height: 14), MarketSentimentCard(data: m)],
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
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), children: children);
      },
    ),
  );

  Widget _indexCard(String symbol, QuoteFeed f) {
    final q = f.quotes[symbol];
    return InkWell(
      key: Key('market.index.$symbol'),
      onTap: () => context.push('/market/$symbol'),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(symbol, style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 4),
            // 四张等分后单卡较窄：价格与涨跌幅按需缩小，不换行
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                q == null ? '—' : fmtPx(q.last),
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
            if (q != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  fmtSigned(q.chgPct, suffix: '%'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: chgColor(q.chgPct)),
                ),
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
