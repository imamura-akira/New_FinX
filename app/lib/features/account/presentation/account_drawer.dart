import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/config.dart';
import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_api.dart';
import '../domain/account_overview.dart';
import '../../../l10n/l10n.dart';

/// 入金入口（P-13）。
void openDeposit(BuildContext context) => context.push('/funding/deposit');

/// 从抽屉进入资金页面：先关闭抽屉再跳转。
void _fromDrawer(BuildContext context, String route) {
  Navigator.of(context).pop();
  context.push(route);
}

/// 姓名首字母头像（原型 nameAvatar）。
class NameAvatar extends StatelessWidget {
  const NameAvatar({super.key, required this.email, this.size = 32});
  final String email;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(gradient: AppGradients.gradSoft, shape: BoxShape.circle),
    child: Text(
      email.isEmpty ? '?' : email[0].toUpperCase(),
      style: TextStyle(color: Colors.white, fontSize: size * .42, fontWeight: FontWeight.w700),
    ),
  );
}

/// P-08 账户抽屉（右侧滑出；中文）。账户号码须在 App 内可见（PDF-6）。
class AccountDrawer extends StatelessWidget {
  const AccountDrawer({super.key, required this.overview, this.cue});
  final AccountOverview overview;
  final OnboardingCue? cue;

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    final email = session.me?.email ?? '';
    return Drawer(
      backgroundColor: AppColors.bg,
      width: MediaQuery.of(context).size.width * .86,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: overview,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: const Key('drawer.close'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Center(child: NameAvatar(email: email, size: 56)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  email,
                  key: const Key('drawer.email'),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(t.drawerSwitchAccount, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              Seg2<String>(
                items: [('LIVE', t.drawerLive), ('PAPER', t.drawerPaper)],
                value: 'LIVE',
                onChanged: (v) {
                  if (v == 'PAPER') showToast(context, t.drawerPaperAccountIsnT);
                },
              ),
              const SizedBox(height: 12),
              _accountCard(context),
              _group(t.drawerFunds, [
                ListRow(
                  key: const Key('drawer.deposit'),
                  icon: Icons.south_rounded,
                  title: t.homeDeposit,
                  onTap: () => _fromDrawer(context, '/funding/deposit'),
                ),
                ListRow(
                  key: const Key('drawer.withdraw'),
                  icon: Icons.north_rounded,
                  title: t.drawerWithdraw,
                  onTap: () => _fromDrawer(context, '/funding/withdraw'),
                ),
                ListRow(
                  key: const Key('drawer.banks'),
                  icon: Icons.account_balance_outlined,
                  title: t.drawerBankAccounts,
                  onTap: () => _fromDrawer(context, '/funding/banks'),
                ),
                ListRow(icon: Icons.swap_horiz_rounded, title: t.drawerTransferFromAnotherBroker, onTap: () => _notInDemo(context)),
              ]),
              _group(t.drawerActivity, [
                ListRow(icon: Icons.notifications_none_rounded, title: t.drawerNotifications, onTap: () => _notInDemo(context)),
                ListRow(
                  key: const Key('drawer.history'),
                  icon: Icons.history_rounded,
                  title: t.drawerHistory,
                  onTap: () => _fromDrawer(context, '/funding/history'),
                ),
                ListRow(icon: Icons.description_outlined, title: t.drawerDocuments, onTap: () => _notInDemo(context)),
              ]),
              _group(t.drawerManage, [
                ListRow(
                  key: const Key('drawer.language'),
                  icon: Icons.translate_rounded,
                  title: t.langTitle,
                  subtitle: _languageLabel(LocaleController.instance.value),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                  onTap: () => _pickLanguage(context),
                ),
                ListRow(icon: Icons.settings_outlined, title: t.drawerSettings, onTap: () => _notInDemo(context)),
                ListRow(icon: Icons.help_outline_rounded, title: t.drawerHelpCenter, onTap: () => _notInDemo(context)),
                ListRow(key: const Key('drawer.logout'), icon: Icons.logout_rounded, title: t.drawerSignOut, onTap: () => _logout(context)),
              ]),
              // 演示验真：仅 DEMO_MODE=true 构建渲染；正式构建完全不出现
              if (AppScope.of(context).config.demoMode) DwSandboxPanel(overview: overview),
              const Center(
                child: Text('${AppConfig.appName} Demo-1', style: TextStyle(fontSize: 12, color: AppColors.faint)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountCard(BuildContext context) {
    final acct = overview.account;
    final money = overview.money;
    if (acct == null || money == null) {
      final c = cue;
      return AppCard(
        borderColor: AppColors.primaryWeak,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.drawerBrokerageAccountUnavailable,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.warn),
            ),
            const SizedBox(height: 8),
            KvRow(t.drawerAccountNumber, '--'),
            KvRow(t.drawerMarketValue, '—'),
            KvRow(t.homeBuyingPower, '—'),
            KvRow(t.assetCash, '—'),
            if (c != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(c.title, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ),
                  if (c.sandboxPending) ...[const SizedBox(width: 6), StatusBadge(t.homePendingSandboxVerification, kind: BadgeKind.warn)],
                ],
              ),
              const SizedBox(height: 10),
              AppButton(
                c.cta,
                key: const Key('drawer.cue'),
                small: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(c.route);
                },
              ),
            ],
          ],
        ),
      );
    }
    final restricted = acct.status != 'OPEN';
    final statusLabel = {'OPEN_NO_NEW_TRADES': t.drawerSellOnly, 'FROZEN': t.drawerFrozen, 'CLOSED': t.drawerClosed, 'PENDING': t.drawerOpening};
    return AppCard(
      borderColor: AppColors.primaryWeak,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.drawerLiveAccount,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary2),
                ),
              ),
              restricted
                  ? StatusBadge(statusLabel[acct.status] ?? acct.status, kind: BadgeKind.danger)
                  : StatusBadge(t.drawerCashSelfDirected, kind: BadgeKind.ok),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(t.drawerAccountNumber, style: TextStyle(fontSize: 14, color: AppColors.muted)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  acct.accountNo,
                  key: const Key('drawer.accountNo'),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.muted),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: acct.accountNo));
                  showToast(context, t.drawerAccountNumberCopied);
                },
              ),
            ],
          ),
          Text(
            t.drawerAccountType(acct.accountType, acct.tradingType, acct.managementType),
            style: const TextStyle(fontSize: 12, color: AppColors.faint),
          ),
          const Divider(height: 20, color: AppColors.line),
          KvRow(t.drawerPositionsValue, overview.equityValue == null ? '—' : fmtUsd(overview.equityValue!), valueKey: const Key('drawer.equity')),
          KvRow(t.homeBuyingPower, fmtUsd(money.buyingPower), valueKey: const Key('drawer.buyingPower')),
          KvRow(t.assetCash, fmtUsd(money.cash), valueKey: const Key('drawer.cash')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: AppButton(t.homeDeposit, small: true, onPressed: () => _fromDrawer(context, '/funding/deposit'))),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(t.drawerTransferIn, small: true, kind: ButtonKind.ghost, onPressed: () => _notInDemo(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _group(String label, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
      ),
      ListGroup(children: rows),
    ],
  );

  void _notInDemo(BuildContext context) => showToast(context, t.drawerThisFeatureIsnT);

  static String _languageLabel(String? code) => switch (code) {
    'zh' => t.langZh,
    'en' => t.langEn,
    _ => t.langSystem,
  };

  /// F18：语言选择（跟随系统 / 简体中文 / English），持久化；切换后页面立即按新语言重建。
  Future<void> _pickLanguage(BuildContext context) async {
    final current = LocaleController.instance.value;
    final picked = await showModalBottomSheet<(String?,)>(
      context: context,
      useRootNavigator: true, // 显示在底部 Tab 之上
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(t.langTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final code in const [null, 'zh', 'en'])
              ListTile(
                key: Key('language.${code ?? 'system'}'),
                title: Text(_languageLabel(code)),
                trailing: code == current ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.of(ctx).pop((code,)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked.$1 == current) return;
    await LocaleController.instance.select(picked.$1);
  }

  Future<void> _logout(BuildContext context) async {
    final session = AppScope.of(context).session;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.drawerSignOut2),
        content: Text(t.drawerYouLlNeedTo),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.drawerCancel)),
          TextButton(key: const Key('drawer.logout.confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(t.drawerSignOut3)),
        ],
      ),
    );
    if (ok == true) await session.signOut();
  }
}

/// "DW 沙盒凭证"折叠区（演示验真）：显示 DW 返回的 userID、accountID、accountNo、KYC 状态与最近同步时间，
/// 每项可点击复制，用于和 `demoreset verify` 打印的 DW 原始值当场对照。只在 DEMO_MODE=true 时被使用。
class DwSandboxPanel extends StatefulWidget {
  const DwSandboxPanel({super.key, required this.overview});
  final AccountOverview overview;

  @override
  State<DwSandboxPanel> createState() => _DwSandboxPanelState();
}

class _DwSandboxPanelState extends State<DwSandboxPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final DwIdentifiers? dw = widget.overview.account?.dw;
    final rows = dw == null
        ? const <(String, String)>[]
        : [
            ('userID', dw.userId),
            ('accountID', dw.accountId),
            ('accountNo', dw.accountNo),
            (t.drawerKycStatus, dw.kycStatus),
            (t.drawerLastSynced, dw.syncedAt == null ? '—' : fmtDateTime(dw.syncedAt)),
          ];
    return Container(
      key: const Key('drawer.dwPanel'),
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShape.radius),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          InkWell(
            key: const Key('drawer.dwPanel.toggle'),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.drawerDwSandboxIds, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  StatusBadge(t.drawerDemoOnly, kind: BadgeKind.warn),
                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.faint),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 10),
              child: dw == null
                  ? Padding(
                      padding: EdgeInsets.only(bottom: 4, right: 8),
                      child: Text(t.drawerNoDwIdsYet, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    )
                  : Column(
                      children: [
                        for (final (k, v) in rows)
                          InkWell(
                            key: Key('drawer.dw.$k'),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: v));
                              showToast(context, t.drawerCopied(k));
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 78,
                                    child: Text(k, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                  ),
                                  Expanded(
                                    child: Text(
                                      v.isEmpty ? '—' : v,
                                      style: const TextStyle(fontSize: 12, fontFamily: 'Menlo', fontFamilyFallback: ['Courier']),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6, right: 6),
                                    child: Icon(Icons.copy_rounded, size: 14, color: AppColors.faint),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.only(top: 4, right: 8),
                          child: Text(t.drawerTheseAreTheValues, style: TextStyle(fontSize: 11, color: AppColors.faint)),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
