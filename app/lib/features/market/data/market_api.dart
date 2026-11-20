import '../../../core/api/api_client.dart';
import '../domain/sentiment.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// 报价（GET /market/quotes 的 quotes[]）。
class Quote {
  const Quote({required this.symbol, required this.last, required this.chg, required this.chgPct, required this.bid, required this.ask});
  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
    symbol: j['symbol'] as String,
    last: _d(j['last']),
    chg: _d(j['chg']),
    chgPct: _d(j['chgPct']),
    bid: _d(j['bid']),
    ask: _d(j['ask']),
  );
  final String symbol;
  final double last;
  final double chg;
  final double chgPct; // 百分数，如 -0.09 表示 -0.09%
  final double bid;
  final double ask;
}

class QuoteBatch {
  const QuoteBatch({required this.simulated, required this.ts, required this.quotes});
  final bool simulated;
  final DateTime? ts;
  final Map<String, Quote> quotes;
}

class Candle {
  const Candle(this.t, this.o, this.h, this.l, this.c);
  final DateTime t;
  final double o, h, l, c;
}

/// GET /market/instruments/{symbol}（P-10）。
class InstrumentDetail {
  const InstrumentDetail({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
    required this.simulated,
    required this.quote,
    required this.dayHigh,
    required this.dayLow,
    required this.prevClose,
    required this.candles,
  });

  factory InstrumentDetail.fromJson(Map<String, dynamic> j) => InstrumentDetail(
    symbol: j['symbol'] as String,
    name: j['name'] as String? ?? '',
    exchange: j['exchange'] as String? ?? '',
    type: j['type'] as String? ?? 'STOCK',
    simulated: j['simulated'] == true,
    quote: Quote.fromJson(j),
    dayHigh: _d(j['dayHigh']),
    dayLow: _d(j['dayLow']),
    prevClose: _d(j['prevClose']),
    candles: [
      for (final c in (j['candles'] as List? ?? const []))
        Candle(DateTime.parse((c as Map)['t'] as String), _d(c['o']), _d(c['h']), _d(c['l']), _d(c['c'])),
    ],
  );

  final String symbol;
  final String name;
  final String exchange;
  final String type;
  final bool simulated;
  final Quote quote;
  final double dayHigh;
  final double dayLow;
  final double prevClose;
  final List<Candle> candles;
}

/// GET /market/sentiment（P-09 市场情绪卡，演示数据）。
class MarketSentiment {
  const MarketSentiment({required this.simulated, required this.ts, required this.fearGreed, required this.breadth});
  factory MarketSentiment.fromJson(Map<String, dynamic> j) {
    final fg = (j['fearGreed'] as Map?)?.cast<String, dynamic>() ?? const {};
    final b = (j['breadth'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MarketSentiment(
      simulated: j['simulated'] == true,
      ts: DateTime.tryParse('${j['ts']}'),
      fearGreed: _d(fg['value']).round().clamp(0, 100),
      breadth: Breadth(up: _d(b['up']).round(), down: _d(b['down']).round(), flat: _d(b['flat']).round()),
    );
  }
  final bool simulated;
  final DateTime? ts;
  final int fearGreed;
  final Breadth breadth;
}

/// 行情接口（api-spec.md 5.5；第一阶段为后端虚拟行情，响应带 simulated:true）。
class MarketApi {
  MarketApi(this._api);
  final ApiClient _api;

  Future<QuoteBatch> quotes([List<String>? symbols]) async {
    final d = await _api.get(
      '/market/quotes',
      query: symbols == null || symbols.isEmpty ? null : {'symbols': symbols.join(',')},
    ) as Map<String, dynamic>;
    return QuoteBatch(
      simulated: d['simulated'] == true,
      ts: DateTime.tryParse('${d['ts']}'),
      quotes: {
        for (final q in (d['quotes'] as List? ?? const [])) (q as Map)['symbol'] as String: Quote.fromJson(q.cast<String, dynamic>()),
      },
    );
  }

  Future<InstrumentDetail> instrument(String symbol) async =>
      InstrumentDetail.fromJson(await _api.get('/market/instruments/${Uri.encodeComponent(symbol)}') as Map<String, dynamic>);

  Future<MarketSentiment> sentiment() async =>
      MarketSentiment.fromJson(await _api.get('/market/sentiment') as Map<String, dynamic>);
}
