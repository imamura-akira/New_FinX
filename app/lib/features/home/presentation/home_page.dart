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
import '../../auth/presentation/welcome_page.dart';
import '../../market/data/market_api.dart';
import '../../market/domain/instruments.dart';
import '../../market/presentation/market_widgets.dart';
import '../../trading/data/trading_api.dart';
import '../../trading/domain/trading_mode.dart';
import '../../trading/presentation/paper_widgets.dart';

/// P-07 资产首页（Demo-1：资产卡取 DW 真实资金汇总 F12；未开户 / 开户中显示开户提示卡）。
/// 自选股报价来自虚拟行情（F11），每 3 秒刷新；已开户时显示持仓 P-12 / 订单 P-11 入口（F14）；智能组合不在本期范围。
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
      showToast(context, '模拟账户已重置');
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
    final session = AppScope.of(context).session;
    try {
      await session.refreshMe();
    } catch (_) {
      if (mounted) showToast(context, '刷新失败，请稍后重试');
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
            title: const Text('资产'),
            actions: [
              Builder(
                builder: (context) => IconButton(
                  key: const Key('home.avatar'),
                  tooltip: '账户',
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
                  if (ov.error != null) Notice('资产数据暂时无法刷新：${ov.error}', kind: NoticeKind.warn),
                  _hero(opened ? money : null),
                  if (opened && money.updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                      child: Text(
                        '资金数据来自 DriveWealth · 更新于 ${fmtTime(money.updatedAt)}',
                        key: const Key('home.updatedAt'),
                        style: const TextStyle(fontSize: 12, color: AppColors.faint),
                      ),
                    ),
                  if (opened && (money.pendingDeposits > 0 || money.withheldForSeasoning > 0 || money.unsettled > 0))
                    AppCard(
                      child: Column(
                        children: [
                          if (money.pendingDeposits > 0) KvRow('在途入金（尚未计入购买力）', fmtUsd(money.pendingDeposits)),
                          if (money.withheldForSeasoning > 0) KvRow('观察期内暂不可提现', fmtUsd(money.withheldForSeasoning)),
                          if (money.unsettled > 0) KvRow('待交收', fmtUsd(money.unsettled)),
                        ],
                      ),
                    ),
                  if (opened && money.cash == 0 && money.pendingDeposits == 0 && ov.restriction == null)
                    AppCard(
                      child: Row(
                        children: [
                          _iconTile(Icons.south_rounded),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('入金开始投资', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                Text('绑定本人美国银行账户（ACH）后转入资金', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          AppButton('入金', key: const Key('home.deposit'), small: true, onPressed: () => openDeposit(context)),
                        ],
                      ),
                    ),
                  if (cue != null) _cueCard(context, cue),
                  if (!opened && !(ov.loading && ov.progress == null)) // 首次加载完成前不显示，避免闪现
                    AppButton('先看看行情', key: const Key('home.market'), kind: ButtonKind.ghost, onPressed: () => context.go('/market')),
                  if (opened) ...[
                    const SectionTitle('交易'),
                    ListGroup(
                      children: [
                        ListRow(
                          key: const Key('home.positions'),
                          icon: Icons.pie_chart_outline_rounded,
                          title: '持仓',
                          subtitle: '数量、市值、成本与盈亏（券商返回）',
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                          onTap: () => context.push('/positions'),
                        ),
                        ListRow(
                          key: const Key('home.orders'),
                          icon: Icons.receipt_long_outlined,
                          title: '订单',
                          subtitle: '查看订单状态，撤销未成交订单',
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                          onTap: () => context.push('/orders'),
                        ),
                      ],
                    ),
                  ],
                ],
                SectionTitle('自选股', trailing: LinkButton('去市场', fontSize: 13, onPressed: () => context.go('/market'))),
                if (_watch.symbols.isEmpty)
                  const AppCard(
                    child: Text('还没有自选股。在个股页点击右上角星标即可加入。', style: TextStyle(fontSize: 13, color: AppColors.muted)),
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
    if (_paperError != null) Notice('模拟账户暂时无法刷新：$_paperError', kind: NoticeKind.warn),
    if (_paper != null)
      PaperAccountCard(account: _paper!, hide: _hide, onReset: _resetPaper)
    else if (_paperError == null)
      const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    const SectionTitle('模拟交易'),
    ListGroup(
      children: [
        ListRow(
          key: const Key('home.paper.positions'),
          icon: Icons.pie_chart_outline_rounded,
          title: '模拟持仓',
          subtitle: '按演示行情估值的模拟持仓与盈亏',
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
          onTap: () async {
            await context.push('/positions?paper=1');
            _loadPaper();
          },
        ),
        ListRow(
          key: const Key('home.paper.orders'),
          icon: Icons.receipt_long_outlined,
          title: '模拟订单',
          subtitle: '市价单即时成交，限价单到价成交，可撤单',
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
          onTap: () async {
            await context.push('/orders?paper=1');
            _loadPaper();
          },
        ),
      ],
    ),
    const Text('在市场页选择股票，点"买入 / 卖出"即可模拟下单。', style: TextStyle(fontSize: 12, color: AppColors.faint)),
  ];

  Widget _hero(AccountMoney? m) {
    String v(double x) => _hide ? '****' : fmtUsd(x);
    return Container(
      key: const Key('home.hero'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(gradient: AppGradients.hero, borderRadius: BorderRadius.circular(AppShape.radiusLarge)),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('实盘 · 总资产 (USD)', style: TextStyle(fontSize: 13, color: Color(0xD9FFFFFF))),
                const SizedBox(width: 4),
                InkWell(
                  key: const Key('home.hide'),
                  onTap: () => setState(() => _hide = !_hide),
                  child: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              m == null ? '—' : v(m.cash),
              key: const Key('home.total'),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _split('购买力', m == null ? '—' : v(m.buyingPower), const Key('home.buyingPower'))),
                Expanded(child: _split('可提现', m == null ? '—' : v(m.cashAvailableForWithdrawal), const Key('home.withdrawable'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _split(String k, String v, Key key) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: const TextStyle(fontSize: 12, color: Color(0xBFFFFFFF))),
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
                  Text(cue.sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  if (cue.sandboxPending) ...[const SizedBox(height: 6), const StatusBadge('待沙盒验证', kind: BadgeKind.warn)],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}

Widget _iconTile(IconData icon, {Color color = AppColors.primary}) => Container(
  width: 38,
  height: 38,
  decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(11)),
  child: Icon(icon, size: 20, color: color),
);
