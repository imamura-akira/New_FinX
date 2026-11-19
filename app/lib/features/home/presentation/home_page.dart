import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/widgets.dart';

/// P-07 资产首页（Demo-1 #8 最小外壳：登录态与开户状态；账户卡 P-08 与入口在 #10 实现）。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _statusLabel = {'NONE': '尚未开户', 'DRAFT': '开户资料填写中', 'SUBMITTED': '开户申请审核中', 'APPROVED': '账户已开通', 'DENIED': '开户未通过'};

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final me = session.me;
        return Scaffold(
          appBar: AppBar(
            title: const Text('资产'),
            actions: [
              IconButton(
                key: const Key('home.logout'),
                tooltip: '退出登录',
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => session.signOut(),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              try {
                await session.refreshMe();
              } catch (_) {
                if (context.mounted) showToast(context, '刷新失败，请稍后重试');
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('已登录', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text(
                        me?.email ?? '—',
                        key: const Key('home.email'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('开户状态', style: TextStyle(fontSize: 14, color: AppColors.muted)),
                          const Spacer(),
                          Text(_statusLabel[me?.accountStatus] ?? '—', key: const Key('home.status'), style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
                // 开户入口（原型 P-07"继续开户"卡片；资产卡与 P-08 在 #10 接入）
                if (me != null && (me.accountStatus == 'NONE' || me.accountStatus == 'DRAFT'))
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me.accountStatus == 'DRAFT' ? '继续开户' : '开立证券账户',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        const Text('账户由合作券商 DriveWealth 开立和托管，约 5 分钟完成。', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                        const SizedBox(height: 12),
                        AppButton(
                          me.accountStatus == 'DRAFT' ? '继续开户' : '开始开户',
                          key: const Key('home.openAccount'),
                          onPressed: () => context.go('/onboarding/a'),
                        ),
                      ],
                    ),
                  )
                else if (me != null)
                  AppCard(
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('开户申请已提交', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                        LinkButton('查看开户进度', key: const Key('home.status.link'), onPressed: () => context.go('/application/status')),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
