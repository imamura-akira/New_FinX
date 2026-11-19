import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/config.dart';
import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/account_overview.dart';

/// 入金入口（P-13，Demo-1 #11 接入）。
void openDeposit(BuildContext context) => showToast(context, '入金功能将在下一版本接入');

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
              const Center(
                child: Text('切换账户', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              Seg2<String>(
                items: const [('LIVE', '实盘'), ('PAPER', '模拟')],
                value: 'LIVE',
                onChanged: (v) {
                  if (v == 'PAPER') showToast(context, '模拟账户暂未开放');
                },
              ),
              const SizedBox(height: 12),
              _accountCard(context),
              _group('资金', [
                ListRow(icon: Icons.south_rounded, title: '入金', onTap: () => openDeposit(context)),
                ListRow(icon: Icons.north_rounded, title: '出金', onTap: () => showToast(context, '出金功能将在下一版本接入')),
                ListRow(icon: Icons.account_balance_outlined, title: '银行账户', onTap: () => showToast(context, '银行账户管理将在下一版本接入')),
                ListRow(icon: Icons.swap_horiz_rounded, title: '转入其他券商账户', onTap: () => _notInDemo(context)),
              ]),
              _group('动态', [
                ListRow(icon: Icons.notifications_none_rounded, title: '通知', onTap: () => _notInDemo(context)),
                ListRow(icon: Icons.history_rounded, title: '历史记录', onTap: () => showToast(context, '资金记录将在下一版本接入')),
                ListRow(icon: Icons.description_outlined, title: '文件', onTap: () => _notInDemo(context)),
              ]),
              _group('管理', [
                ListRow(icon: Icons.settings_outlined, title: '设置', onTap: () => _notInDemo(context)),
                ListRow(icon: Icons.help_outline_rounded, title: '帮助中心', onTap: () => _notInDemo(context)),
                ListRow(key: const Key('drawer.logout'), icon: Icons.logout_rounded, title: '退出登录', onTap: () => _logout(context)),
              ]),
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
            const Text(
              '交易账户暂不可用',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.warn),
            ),
            const SizedBox(height: 8),
            const KvRow('账户号码', '--'),
            const KvRow('市值', '—'),
            const KvRow('购买力', '—'),
            const KvRow('现金', '—'),
            if (c != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(c.title, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ),
                  if (c.sandboxPending) ...[const SizedBox(width: 6), const StatusBadge('待沙盒验证', kind: BadgeKind.warn)],
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
    const statusLabel = {'OPEN_NO_NEW_TRADES': '仅可卖出', 'FROZEN': '已冻结', 'CLOSED': '已关闭', 'PENDING': '开立中'};
    return AppCard(
      borderColor: AppColors.primaryWeak,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '实盘账户',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary2),
                ),
              ),
              restricted
                  ? StatusBadge(statusLabel[acct.status] ?? acct.status, kind: BadgeKind.danger)
                  : const StatusBadge('现金 · 自主', kind: BadgeKind.ok),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('账户号码', style: TextStyle(fontSize: 14, color: AppColors.muted)),
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
                  showToast(context, '账户号码已复制');
                },
              ),
            ],
          ),
          Text(
            '账户类型 ${acct.accountType} · ${acct.tradingType} · ${acct.managementType}',
            style: const TextStyle(fontSize: 12, color: AppColors.faint),
          ),
          const Divider(height: 20, color: AppColors.line),
          const KvRow('市值', r'$0.00'), // Demo-1 无交易，持仓市值为 0
          KvRow('购买力', fmtUsd(money.buyingPower), valueKey: const Key('drawer.buyingPower')),
          KvRow('现金', fmtUsd(money.cash), valueKey: const Key('drawer.cash')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: AppButton('入金', small: true, onPressed: () => openDeposit(context))),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton('转入', small: true, kind: ButtonKind.ghost, onPressed: () => _notInDemo(context)),
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

  void _notInDemo(BuildContext context) => showToast(context, '该功能不在本次演示范围');

  Future<void> _logout(BuildContext context) async {
    final session = AppScope.of(context).session;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录？'),
        content: const Text('退出后需重新验证邮箱登录。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(key: const Key('drawer.logout.confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('退出')),
        ],
      ),
    );
    if (ok == true) await session.signOut();
  }
}
