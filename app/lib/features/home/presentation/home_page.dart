import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/format.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/data/account_api.dart';
import '../../account/domain/account_overview.dart';
import '../../account/presentation/account_drawer.dart';

/// P-07 资产首页（Demo-1：资产卡取 DW 真实资金汇总 F12；未开户 / 开户中显示开户提示卡）。
/// 行情与自选股在 F11b 接入；持仓、订单、智能组合等不在 Demo-1 范围。
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_overview == null) {
      final scope = AppScope.of(context);
      _overview = AccountOverview(AccountApi(scope.api));
      _session = scope.session..addListener(_onSession);
      _onSession();
    }
  }

  void _onSession() {
    final st = _session!.me?.accountStatus;
    if (st != _loadedFor) {
      _loadedFor = st;
      _overview!.load(st);
    }
  }

  Future<void> _refresh() async {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    final ov = _overview!;
    return ListenableBuilder(
      listenable: Listenable.merge([session, ov]),
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
              ],
            ),
          ),
        );
      },
    );
  }

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
