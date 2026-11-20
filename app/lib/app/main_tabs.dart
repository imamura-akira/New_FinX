import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import 'theme.dart';

/// 底部 Tab（pages.md 第 2 节；文案按 ui-signoff 第 3 节 FinX 主题变更：资产 P-07 / 市场 P-09 / 股票大师 P-23 / Fifi P-26 / 奖励 P-27）。
/// 股票大师 / Fifi / 奖励为 F13 模拟数据展示页。
class MainTabs extends StatelessWidget {
  const MainTabs({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  /// (路由, Key 后缀, 文案, 图标)。F18：英文 Assets / Markets / Masters / Fifi / Rewards。
  static List<(String, String, String, IconData)> get _tabs => [
    ('/home', 'home', t.tabAssets, Icons.account_balance_wallet_outlined),
    ('/market', 'market', t.tabMarkets, Icons.show_chart_rounded),
    ('/masters', 'masters', t.tabMasters, Icons.apartment_rounded),
    ('/fifi', 'fifi', t.tabFifi, Icons.auto_awesome_outlined),
    ('/rewards', 'rewards', t.tabRewards, Icons.card_giftcard_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final index = location.startsWith('/market')
        ? 1
        : location.startsWith('/masters')
        ? 2
        : location.startsWith('/fifi')
        ? 3
        : location.startsWith('/rewards')
        ? 4
        : 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryWeak,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (i != index) context.go(_tabs[i].$1);
        },
        destinations: [for (final d in _tabs) NavigationDestination(key: Key('tab.${d.$2}'), icon: Icon(d.$4), label: d.$3)],
      ),
    );
  }
}
