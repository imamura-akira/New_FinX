import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/data/account_api.dart';
import '../../account/domain/account_overview.dart';
import '../../account/presentation/account_drawer.dart';
import '../../account/presentation/asset_analysis.dart';
import '../../auth/presentation/welcome_page.dart';
import '../../market/data/market_api.dart';
import '../../market/domain/instruments.dart';
import '../../market/presentation/market_widgets.dart';
import '../../trading/data/trading_api.dart';
import '../../trading/domain/trading_mode.dart';
import '../../trading/presentation/paper_widgets.dart';
import '../../../l10n/l10n.dart';

/// P-07 资产首页（Demo-1：资产卡取 DW 真实资金汇总 F12；未开户 / 开户中显示开户提示卡）。
/// 自选股报价来自虚拟行情（F11），每 3 秒刷新；已开户时显示持仓 P-12 / 订单 P-11 入口（F14）；智能组合不在本期范围。
/// F17：已开户（或模拟盘模式）时在资产卡下方显示资产分布与资产趋势（各自加载，失败整卡隐藏）。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AccountOverview? _overview;
  SessionController? _session;
  String? _loadedFor;
  bool _hide = false;
  QuoteFeed? _feed;
  final _watch = Watchlist.instance;
  final _mode = TradingMode.instance;
  PaperAccount? _paper; // F15 模拟账户（只在模拟盘模式显示）
  String? _paperError;
  int _analysisGen = 0; // F17：变化时资产分布 / 趋势重新加载

  @override
  void initState() {
    super.initState();
    LaunchIntro.skip(); // 冷启动直接进入资产页：之后回到 P-01 不再播放品牌入场
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_overview == null) {
      final scope = AppScope.of(context);
      _overview = AccountOverview(AccountApi(scope.api));
      _session = scope.session..addListener(_onSession);
      _onSession();
      _feed = QuoteFeed(MarketApi(scope.api), symbols: _watch.symbols)..start();
      _watch.addListener(_onWatch);
      _mode.addListener(_onMode);
      if (_mode.paper) _loadPaper();
    }
  }

  void _onMode() {
    if (_mode.paper) _loadPaper();
    if (mounted) setState(() {});
  }

  Future<void> _loadPaper() async {
    try {
      final a = await TradingApi(AppScope.of(context).api, paper: true).paperAccount();
      if (!mounted) return;
      setState(() {
        _paper = a;
        _paperError = null;
        _analysisGen++;
      });
    } on ApiException catch (e) {
      if (mounted && !e.isSessionInvalid) setState(() => _paperError = e.message);
    }
  }

  Future<void> _resetPaper() async {
    if (!await confirmPaperReset(context) || !mounted) return;
    try {
      final a = await TradingApi(AppScope.of(context).api, paper: true).resetPaper();
      if (!mounted) return;
      setState(() => _paper = a);
      showToast(context, t.homePaperAccountHasBeen);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  void _onSession() {
    final st = _session!.me?.accountStatus;
    if (st != _loadedFor) {
      _loadedFor = st;
      _overview!.load(st);
    }
  }

  void _onWatch() => _feed!.symbols = _watch.symbols;

  Future<void> _refresh() async {
    if (_mode.paper) return _loadPaper();
    setState(() => _analysisGen++);
    final session = AppScope.of(context).session;
    try {
      await session.refreshMe();
    } catch (_) {
      if (mounted) showToast(context, t.homeCouldnTRefreshPlease);
      return;
    }
    await _overview!.load(session.me?.accountStatus);
  }

  @override
  void dispose() {
    _session?.removeListener(_onSession);
    _overview?.dispose();
    _watch.removeListener(_onWatch);
    _mode.removeListener(_onMode);
    _feed?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    final ov = _overview!;
    return ListenableBuilder(
      listenable: Listenable.merge([session, ov, _feed!]),
      builder: (context, _) {
        final me = session.me;
        final cue = OnboardingCue.of(me?.accountStatus, ov.progress);
        final money = ov.money;
        final opened = ov.opened && money != null;
        return Scaffold(
          appBar: AppBar(
            title: Text(t.tabAssets),
            actions: [
              Builder(
                builder: (context) => IconButton(
                  key: const Key('home.avatar'),
                  tooltip: t.homeAccount,
                  icon: NameAvatar(email: me?.email ?? ''),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          endDrawer: AccountDrawer(overview: ov, cue: cue),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                const AccountModeSwitch(),
                if (_mode.paper)
                  ..._paperSection(context)
                else ...[
                  if (ov.restriction != null) Notice(ov.restriction!, kind: NoticeKind.danger),
                  if (ov.error != null) Notice(t.homeCouldnTRefreshYour(ov.error!), kind: NoticeKind.warn),
                  _hero(opened ? money : null),
                  if (opened && money.updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                      child: Text(
                        t.homeAccountDataFromDrivewealth(fmtTime(money.updatedAt)),
                        key: const Key('home.updatedAt'),
                        style: TextStyle(fontSize: 12, color: AppColors.faint),
                      ),
                    ),
                  if (opened && (money.pendingDeposits > 0 || money.withheldForSeasoning > 0 || money.unsettled > 0))
                    AppCard(
                      child: Column(
                        children: [
                          if (money.pendingDeposits > 0) KvRow(t.homeDepositsInTransitNot, fmtUsd(money.pendingDeposits)),
                          if (money.withheldForSeasoning > 0) KvRow(t.homeNotYetWithdrawableHolding, fmtUsd(money.withheldForSeasoning)),
                          if (money.unsettled > 0) KvRow(t.homePendingSettlement, fmtUsd(money.unsettled)),
                        ],
                      ),
                    ),
                  if (opened) AssetAnalysis(key: const Key('home.analysis'), paper: false, generation: _analysisGen),
                  if (opened && money.cash == 0 && money.pendingDeposits == 0 && ov.restriction == null)
                    AppCard(
                      child: Row(
                        children: [
                          _iconTile(Icons.south_rounded),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.homeFundYourAccountTo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                Text(t.homeLinkYourOwnUs, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          AppButton(t.homeDeposit, key: const Key('home.deposit'), small: true, onPressed: () => openDeposit(context)),
                        ],
                      ),
                    ),
                  if (cue != null) _cueCard(context, cue),
                  if (!opened && !(ov.loading && ov.progress == null)) // 首次加载完成前不显示，避免闪现
                    AppButton(t.homeBrowseMarketsFirst, key: const Key('home.market'), kind: ButtonKind.ghost, onPressed: () => context.go('/market')),
                  if (opened) ...[
                    SectionTitle(t.homeTrading),
                    ListGroup(
                      children: [
                        ListRow(
                          key: const Key('home.positions'),
                          icon: Icons.pie_chart_outline_rounded,
                          title: t.homePositions,
                          subtitle: t.homeQuantityMarketValueCost,
                          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                          onTap: () => context.push('/positions'),
                        ),
                        ListRow(
                          key: const Key('home.orders'),
                          icon: Icons.receipt_long_outlined,
                          title: t.homeOrders,
                          subtitle: t.homeCheckOrderStatusAnd,
                          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                          onTap: () => context.push('/orders'),
                        ),
                      ],
                    ),
                  ],
                ],
                SectionTitle(t.homeWatchlist, trailing: LinkButton(t.homeGoToMarkets, fontSize: 13, onPressed: () => context.go('/market'))),
                if (_watch.symbols.isEmpty)
                  AppCard(
                    child: Text(t.homeYourWatchlistIsEmpty, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  )
                else
                  ListGroup(
                    children: [for (final s in _watch.symbols) QuoteRow(symbol: s, quote: _feed!.quotes[s], moved: _feed!.moved[s] ?? 0)],
                  ),
                MarketDataNote(ts: _feed!.ts),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 模拟盘模式：只显示模拟账户与模拟交易入口（不显示任何 DW 资金数字）。
  List<Widget> _paperSection(BuildContext context) => [
    const PaperBanner(),
    if (_paperError != null) Notice(t.homeCouldnTRefreshYour2(_paperError!), kind: NoticeKind.warn),
    if (_paper != null)
      PaperAccountCard(account: _paper!, hide: _hide, onReset: _resetPaper)
    else if (_paperError == null)
      const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    if (_paper != null) AssetAnalysis(key: const Key('home.paper.analysis'), paper: true, generation: _analysisGen),
    SectionTitle(t.homePaperTrading),
    ListGroup(
      children: [
        ListRow(
          key: const Key('home.paper.positions'),
          icon: Icons.pie_chart_outline_rounded,
          title: t.homePaperPositions,
          subtitle: t.homePaperPositionsAndP,
          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.faint),
          onTap: () async {
            await context.push('/positions?paper=1');
            _loadPaper();
          },
        ),
        ListRow(
          key: const Key('home.paper.orders'),
          icon: Icons.receipt_long_outlined,
          title: t.homePaperOrders,
          subtitle: t.homeMarketOrdersFillInstantly,
          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.faint),
          onTap: () async {
            await context.push('/orders?paper=1');
            _loadPaper();
          },
        ),
      ],
    ),
    Text(t.homePickAStockOn, style: TextStyle(fontSize: 12, color: AppColors.faint)),
  ];

  Widget _hero(AccountMoney? m) {
    String v(double x) => _hide ? '****' : fmtUsd(x);
    return Container(
      key: const Key('home.hero'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(gradient: AppGradients.hero, borderRadius: BorderRadius.circular(AppShape.radiusLarge)),
      child: DefaultTextStyle(
        style: TextStyle(color: AppColors.onAccent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(t.homeLiveTotalAssetsUsd, style: TextStyle(fontSize: 13, color: AppColors.onAccent.withValues(alpha: .85))),
                const SizedBox(width: 4),
                InkWell(
                  key: const Key('home.hide'),
                  onTap: () => setState(() => _hide = !_hide),
                  child: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16, color: AppColors.onAccent),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              m == null ? '—' : v(m.cash),
              key: const Key('home.total'),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            if (m != null && _overview!.dayPL != null) ...[
              const SizedBox(height: 2),
              Text(
                _hide ? t.homeTodayHidden : t.homeTodayChange(_signedUsd(_overview!.dayPL!), _signedPct(_overview!.dayPLPct)),
                key: const Key('home.dayChange'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _split(t.homeBuyingPower, m == null ? '—' : v(m.buyingPower), const Key('home.buyingPower'))),
                Expanded(child: _split(t.homeAvailableToWithdraw, m == null ? '—' : v(m.cashAvailableForWithdrawal), const Key('home.withdrawable'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// +$42.18 / -$3.10 / $0.00。
  static String _signedUsd(double v) => v > 0 ? '+${fmtUsd(v)}' : fmtUsd(v);

  /// (+0.65%)；无法计算时为空串。
  static String _signedPct(double? p) => p == null ? '' : ' (${p > 0 ? '+' : ''}${p.toStringAsFixed(2)}%)';

  Widget _split(String k, String v, Key key) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: TextStyle(fontSize: 12, color: AppColors.onAccent.withValues(alpha: .75))),
      const SizedBox(height: 2),
      Text(
        v,
        key: key,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
      ),
    ],
  );

  Widget _cueCard(BuildContext context, OnboardingCue cue) {
    final draftOrNew = cue.route.startsWith('/onboarding');
    return InkWell(
      key: Key(draftOrNew ? 'home.openAccount' : 'home.status.link'),
      onTap: () => context.go(cue.route),
      borderRadius: BorderRadius.circular(AppShape.radius),
      child: AppCard(
        borderColor: cue.warn ? AppColors.warn : AppColors.primaryWeak,
        child: Row(
          children: [
            _iconTile(cue.icon, color: cue.warn ? AppColors.warn : AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cue.title,
                    key: const Key('home.cue.title'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  Text(cue.sub, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  if (cue.sandboxPending) ...[const SizedBox(height: 6), StatusBadge(t.homePendingSandboxVerification, kind: BadgeKind.warn)],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}

Widget _iconTile(IconData icon, {Color? color}) => Container(
  width: 38,
  height: 38,
  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(11)),
  child: Icon(icon, size: 20, color: color ?? AppColors.primary),
);
