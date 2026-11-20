import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../data/predict_api.dart';
import '../domain/predict_rules.dart';

/// "我的预测"：战绩（命中率、累计盈亏分、已结算）、待领取积分一键领取、进行中 / 已结算下注列表。
class MyPredictionsPage extends StatefulWidget {
  const MyPredictionsPage({super.key});

  @override
  State<MyPredictionsPage> createState() => _MyPredictionsPageState();
}

class _MyPredictionsPageState extends State<MyPredictionsPage> {
  PredictApi? _api;
  List<PredictBet>? _bets;
  PredictStats _stats = const PredictStats();
  String? _error;
  bool _settledTab = false;
  bool _claiming = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api == null) {
      _api = PredictApi(AppScope.of(context).api);
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final r = await _api!.bets();
      if (!mounted) return;
      setState(() {
        _bets = r.bets;
        _stats = r.stats;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && !e.isSessionInvalid) setState(() => _error = e.message);
    }
  }

  Future<void> _claim() async {
    setState(() => _claiming = true);
    try {
      final r = await _api!.claim();
      if (!mounted) return;
      showToast(context, t.predictClaimedToast(fmtPoints(r.claimed)));
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = [
      for (final b in _bets ?? const <PredictBet>[])
        if ((b.status != 'OPEN') == _settledTab) b,
    ];
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/predict'),
        title: Text(t.predictMine),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_error != null) Notice(_error!, kind: NoticeKind.warn),
            AppCard(
              child: Row(
                children: [
                  _stat(t.predictHitRate, '${_stats.hitRate.toStringAsFixed(1)}%', const Key('mine.hitRate')),
                  _stat(t.predictNetPoints, fmtPointsSigned(_stats.netPoints), const Key('mine.net')),
                  _stat(t.predictSettledCount, '${_stats.settled}', const Key('mine.settled')),
                ],
              ),
            ),
            if (_stats.claimable > 0)
              AppCard(
                borderColor: AppColors.primaryWeak,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.predictClaimable(fmtPoints(_stats.claimable)),
                        key: const Key('mine.claimable'),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ),
                    AppButton(
                      t.predictClaim,
                      key: const Key('mine.claim'),
                      small: true,
                      loading: _claiming,
                      onPressed: _claiming ? null : _claim,
                    ),
                  ],
                ),
              ),
            Seg2<bool>(
              items: [(false, t.predictTabOpen), (true, t.predictTabSettled)],
              value: _settledTab,
              onChanged: (v) => setState(() => _settledTab = v),
            ),
            const SizedBox(height: 12),
            if (_bets == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    t.predictNoBets,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.sub),
                  ),
                ),
              )
            else
              ListGroup(children: [for (final b in list) _row(b)]),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Key key) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          key: key,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.sub)),
      ],
    ),
  );

  Widget _row(PredictBet b) {
    final m = b.market;
    final side = m != null && m.isUpDown
        ? (b.outcome == 'YES' ? t.predictUp : t.predictDown)
        : (b.outcome == 'YES' ? m?.yes.label.text : m?.no.label.text) ?? b.outcome;
    final title = m == null ? b.id : (m.isUpDown ? t.predictUpOrDownSymbol(m.symbol ?? '') : m.title.text);
    final statusColor = switch (b.status) {
      'WON' => AppColors.up,
      'LOST' => AppColors.down,
      _ => AppColors.sub,
    };
    return Padding(
      key: Key('mine.bet.${b.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                b.claimed ? '${predictStatusLabel(b.status)} · ${t.predictClaimedTag}' : predictStatusLabel(b.status),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${t.predictYourPick(side)} · ${b.status == 'OPEN' ? t.predictStakeLine(fmtPoints(b.stake), fmtPoints(b.potentialPayout)) : t.predictPaidLine(fmtPoints(b.stake), fmtPoints(b.payout))}',
            style: TextStyle(fontSize: 12, color: AppColors.sub),
          ),
          if (m?.settlePrice != null)
            Text(t.predictSettlesAt(fmtUsd(m!.settlePrice!)), style: TextStyle(fontSize: 11, color: AppColors.hint)),
        ],
      ),
    );
  }
}
