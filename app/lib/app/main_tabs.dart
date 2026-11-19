import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/widgets/widgets.dart';
import 'theme.dart';

/// 底部 Tab（pages.md 第 2 节；文案按 ui-signoff 第 3 节 FinX 主题变更：资产 P-07 / 市场 P-09 / 股票大师 P-23 / Fifi P-26 / 奖励 P-27）。
/// Demo-1 只做资产与市场，其余三个 Tab 点击提示不在演示范围。
class MainTabs extends StatelessWidget {
  const MainTabs({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const _tabs = [
    ('/home', '资产', Icons.account_balance_wallet_outlined),
    ('/market', '市场', Icons.show_chart_rounded),
    (null, '股票大师', Icons.apartment_rounded),
    (null, 'Fifi', Icons.auto_awesome_outlined),
    (null, '奖励', Icons.card_giftcard_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final index = location.startsWith('/market') ? 1 : 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryWeak,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          final route = _tabs[i].$1;
          if (route == null) {
            showToast(context, '${_tabs[i].$2}不在本次演示范围');
          } else if (i != index) {
            context.go(route);
          }
        },
        destinations: [for (final t in _tabs) NavigationDestination(key: Key('tab.${t.$2}'), icon: Icon(t.$3), label: t.$2)],
      ),
    );
  }
}
