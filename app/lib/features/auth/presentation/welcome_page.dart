import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/widgets.dart';

/// P-01 欢迎页（pages.md P-01；FinX 品牌版式同原型：白底、字标、Fifi 主视觉）。
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(BrandAssets.logo, key: const Key('welcome.logo'), width: 210, semanticLabel: 'FinX'),
                const SizedBox(height: 8),
                const Text(
                  '美股与 ETF 投资，开户、入金、交易一站完成。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Image.asset(BrandAssets.fifiPill, width: 300, semanticLabel: 'Fifi'),
                const SizedBox(height: 48),
                AppButton('注册', key: const Key('welcome.register'), onPressed: () => context.push('/login?mode=register')),
                const SizedBox(height: 8),
                AppButton(
                  '登录',
                  key: const Key('welcome.login'),
                  kind: ButtonKind.ghost,
                  onPressed: () => context.push('/login?mode=login'),
                ),
                const SizedBox(height: 12),
                LinkButton('先逛逛行情', key: const Key('welcome.market'), onPressed: () => context.go('/market')), // 未登录可浏览；资产 Tab 回到欢迎页
                const SizedBox(height: 24),
                const Text('证券服务由合作券商提供。投资有风险。', style: TextStyle(fontSize: 12, color: AppColors.faint)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
