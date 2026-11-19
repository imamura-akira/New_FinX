import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/config.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/widgets.dart';

/// P-01 欢迎页（pages.md P-01；布局与文案同原型）。
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 16),
                const Text(AppConfig.appName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  '美股与 ETF 投资，开户、入金、交易一站完成。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                ),
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
                // 原型中的"先逛逛行情"入口；行情（P-09）不在 Demo-1 范围
                LinkButton('先逛逛行情', onPressed: () => showToast(context, '行情功能即将开放')),
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
