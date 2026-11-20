import '../../../core/api/api_client.dart';
import '../../../l10n/l10n.dart';

// F19 预测板块（积分演示版）：/predict/*（api-spec.md 5.9）。全程预测积分，不涉及真实资金。

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int _i(Object? v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;
DateTime? _t(Object? v) => v == null ? null : DateTime.tryParse('$v');

/// 后端双语文案，按当前语言取用。
class BiText {
  const BiText(this.zh, this.en);
  factory BiText.fromJson(Object? j) {
    final m = (j as Map?)?.cast<String, dynamic>() ?? const {};
    return BiText('${m['zh'] ?? ''}', '${m['en'] ?? ''}');
  }
  final String zh;
  final String en;
  String get text => isEnglish ? en : zh;
}

class PredictOutcome {
  const PredictOutcome({required this.key, required this.label, required this.percent, required this.pool});
  factory PredictOutcome.fromJson(Map<String, dynamic> j) =>
      PredictOutcome(key: '${j['key']}', label: BiText.fromJson(j['label']), percent: _i(j['percent']), pool: _i(j['pool']));
  final String key; // YES / NO
  final BiText label;
  final int percent;
  final int pool;
}

class PredictMarket {
  const PredictMarket({
    required this.id,
    required this.kind,
    required this.category,
    required this.symbol,
    required this.title,
    required this.subtitle,
    required this.outcomes,
    required this.opensAt,
    required this.closesAt,
    required this.targetPrice,
    required this.settlePrice,
    required this.status,
    required this.result,
  });

  factory PredictMarket.fromJson(Map<String, dynamic> j) => PredictMarket(
    id: '${j['id']}',
    kind: '${j['kind']}',
    category: '${j['category']}',
    symbol: j['symbol'] as String?,
    title: BiText.fromJson(j['title']),
    subtitle: BiText.fromJson(j['subtitle']),
    outcomes: [for (final o in (j['outcomes'] as List? ?? const [])) PredictOutcome.fromJson((o as Map).cast<String, dynamic>())],
    opensAt: _t(j['opensAt']) ?? DateTime.now(),
    closesAt: _t(j['closesAt']) ?? DateTime.now(),
    targetPrice: j['targetPrice'] == null ? null : _d(j['targetPrice']),
    settlePrice: j['settlePrice'] == null ? null : _d(j['settlePrice']),
    status: '${j['status'] ?? 'OPEN'}',
    result: j['result'] as String?,
  );

  final String id;
  final String kind; // UPDOWN / EVENT
  final String category;
  final String? symbol;
  final BiText title;
  final BiText subtitle;
  final List<PredictOutcome> outcomes;
  final DateTime opensAt;
  final DateTime closesAt;
  final double? targetPrice;
  final double? settlePrice;
  final String status;
  final String? result;

  bool get isUpDown => kind == 'UPDOWN';
  PredictOutcome get yes => outcomes.firstWhere(
    (o) => o.key == 'YES',
    orElse: () => const PredictOutcome(key: 'YES', label: BiText('', ''), percent: 50, pool: 0),
  );
  PredictOutcome get no => outcomes.firstWhere(
    (o) => o.key == 'NO',
    orElse: () => const PredictOutcome(key: 'NO', label: BiText('', ''), percent: 50, pool: 0),
  );

  /// 所选方向的概率（0–1，按两边池计算，与后端一致）。
  double prob(String outcome) {
    final total = yes.pool + no.pool;
    if (total <= 0) return .5;
    return (outcome == 'NO' ? no.pool : yes.pool) / total;
  }
}

class PredictMarkets {
  const PredictMarkets({required this.serverTime, required this.updown, required this.events});
  final DateTime serverTime;
  final List<PredictMarket> updown;
  final List<PredictMarket> events;
}

class PredictStats {
  const PredictStats({this.settled = 0, this.wins = 0, this.hitRate = 0, this.netPoints = 0, this.claimable = 0, this.openBets = 0});
  factory PredictStats.fromJson(Object? j) {
    final m = (j as Map?)?.cast<String, dynamic>() ?? const {};
    return PredictStats(
      settled: _i(m['settled']),
      wins: _i(m['wins']),
      hitRate: _d(m['hitRate']),
      netPoints: _i(m['netPoints']),
      claimable: _i(m['claimable']),
      openBets: _i(m['openBets']),
    );
  }
  final int settled;
  final int wins;
  final double hitRate;
  final int netPoints;
  final int claimable;
  final int openBets;
}

class PredictBet {
  const PredictBet({
    required this.id,
    required this.outcome,
    required this.stake,
    required this.potentialPayout,
    required this.status,
    required this.payout,
    required this.claimed,
    required this.createdAt,
    required this.market,
  });
  factory PredictBet.fromJson(Map<String, dynamic> j) => PredictBet(
    id: '${j['id']}',
    outcome: '${j['outcome']}',
    stake: _i(j['stake']),
    potentialPayout: _i(j['potentialPayout']),
    status: '${j['status']}',
    payout: _i(j['payout']),
    claimed: j['claimed'] == true,
    createdAt: _t(j['createdAt']) ?? DateTime.now(),
    market: j['market'] is Map ? PredictMarket.fromJson((j['market'] as Map).cast<String, dynamic>()) : null,
  );
  final String id;
  final String outcome;
  final int stake;
  final int potentialPayout;
  final String status; // OPEN / WON / LOST / VOID
  final int payout;
  final bool claimed;
  final DateTime createdAt;
  final PredictMarket? market;
}

class PredictApi {
  PredictApi(this._api);
  final ApiClient _api;

  Future<({int points, PredictStats stats})> account() async {
    final d = await _api.get('/predict/account') as Map<String, dynamic>;
    return (points: _i(d['points']), stats: PredictStats.fromJson(d['stats']));
  }

  Future<PredictMarkets> markets() async {
    final d = await _api.get('/predict/markets') as Map<String, dynamic>;
    List<PredictMarket> list(String k) => [
      for (final m in (d[k] as List? ?? const [])) PredictMarket.fromJson((m as Map).cast<String, dynamic>()),
    ];
    return PredictMarkets(serverTime: _t(d['serverTime']) ?? DateTime.now().toUtc(), updown: list('updown'), events: list('events'));
  }

  Future<({int points, int potentialPayout, PredictMarket market})> bet(String marketId, String outcome, int stake) async {
    final d = await _api.post('/predict/bets', {'marketId': marketId, 'outcome': outcome, 'stake': stake}) as Map<String, dynamic>;
    return (
      points: _i(d['points']),
      potentialPayout: _i((d['bet'] as Map)['potentialPayout']),
      market: PredictMarket.fromJson((d['market'] as Map).cast<String, dynamic>()),
    );
  }

  Future<({List<PredictBet> bets, PredictStats stats})> bets() async {
    final d = await _api.get('/predict/bets') as Map<String, dynamic>;
    return (
      bets: [for (final b in (d['bets'] as List? ?? const [])) PredictBet.fromJson((b as Map).cast<String, dynamic>())],
      stats: PredictStats.fromJson(d['stats']),
    );
  }

  Future<({int claimed, int points})> claim() async {
    final d = await _api.post('/predict/claim') as Map<String, dynamic>;
    return (claimed: _i(d['claimed']), points: _i(d['points']));
  }
}
