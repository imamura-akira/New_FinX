import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/session/session.dart';
import '../features/account/presentation/application_status_page.dart';
import '../features/account/presentation/kyc_action_pages.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/welcome_page.dart';
import '../features/common/session_expired_page.dart';
import '../features/discover/presentation/discover_pages.dart';
import '../features/discover/presentation/rewards_page.dart';
import '../features/predict/presentation/my_predictions_page.dart';
import '../features/predict/presentation/predict_page.dart';
import '../features/funding/presentation/bank_pages.dart';
import '../features/funding/presentation/transfer_pages.dart';
import '../features/home/presentation/home_page.dart';
import '../features/market/presentation/instrument_page.dart';
import '../features/market/presentation/market_page.dart';
import '../features/market/presentation/search_page.dart';
import '../features/onboarding/presentation/final_pages.dart';
import '../features/onboarding/presentation/onboarding_shell.dart';
import '../features/onboarding/presentation/step_pages.dart';
import '../features/trading/presentation/order_page.dart';
import '../features/trading/presentation/orders_page.dart';
import '../features/trading/presentation/positions_page.dart';
import 'main_tabs.dart';

/// 路由（pages.md 第 2 节导航结构）。会话状态驱动重定向：
///   未登录 → P-01 / P-02；已登录 → P-07；会话过期 → S-01。
abstract final class Routes {
  static const welcome = '/';
  static const login = '/login';
  static const home = '/home';
  static const expired = '/expired';
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const market = '/market'; // P-09（未登录也可浏览）
  static const applicationStatus = '/application/status';
  static const kycInfo = '/application/info'; // P-34
  static const kycDocument = '/application/document'; // P-35
  static const kycResult = '/application/result'; // P-36
}

GoRouter buildRouter(SessionController session) {
  const publicRoutes = {Routes.welcome, Routes.login};
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      switch (session.status) {
        case SessionStatus.unknown:
          return loc == Routes.splash ? null : Routes.splash;
        case SessionStatus.expired:
          return loc == Routes.expired ? null : Routes.expired;
        case SessionStatus.signedOut:
          return publicRoutes.contains(loc) || loc.startsWith(Routes.market) ? null : Routes.welcome;
        case SessionStatus.signedIn:
          return (publicRoutes.contains(loc) || loc == Routes.splash || loc == Routes.expired) ? Routes.home : null;
      }
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomePage()),
      GoRoute(
        path: Routes.login,
        builder: (_, state) =>
            LoginPage(initialMode: state.uri.queryParameters['mode'] == 'register' ? LoginMode.register : LoginMode.login),
      ),
      // 底部 Tab：资产 P-07 / 市场 P-09
      ShellRoute(
        builder: (_, state, child) => MainTabs(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            pageBuilder: (_, _) => const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: Routes.market,
            pageBuilder: (_, _) => const NoTransitionPage(child: MarketPage()),
          ),
          GoRoute(
            path: '/predict',
            pageBuilder: (_, _) => const NoTransitionPage(child: PredictPage()),
          ), // F19 预测（积分演示版）
          GoRoute(
            path: '/masters',
            pageBuilder: (_, _) => const NoTransitionPage(child: MastersPage()),
          ), // P-23
          GoRoute(
            path: '/fifi',
            pageBuilder: (_, _) => const NoTransitionPage(child: FifiPage()),
          ), // P-26
          GoRoute(
            path: '/rewards',
            pageBuilder: (_, _) => const NoTransitionPage(child: RewardsPage()),
          ), // P-27
        ],
      ),
      // P-24 全部机构 / 机构详情（全屏，push 进入）
      GoRoute(path: '/predict/mine', builder: (_, _) => const MyPredictionsPage()), // F19 我的预测
      GoRoute(path: '/masters/all', builder: (_, _) => const InstitutionListPage()),
      GoRoute(
        path: '/masters/:id',
        builder: (_, state) => InstitutionDetailPage(id: state.pathParameters['id']!),
      ),
      // F22-b 搜索页（须在 /market/:symbol 之前匹配）
      GoRoute(path: '${Routes.market}/search', builder: (_, _) => const MarketSearchPage()),
      // P-10 个股详情（全屏，push 进入）
      GoRoute(
        path: '${Routes.market}/:symbol',
        builder: (_, state) => InstrumentPage(symbol: state.pathParameters['symbol']!.toUpperCase()),
      ),
      // F14 交易：P-19 下单（P-10 买入 / 卖出进入）、P-11 订单、P-12 持仓
      GoRoute(
        path: '/trade/:symbol',
        builder: (_, state) => OrderPage(
          symbol: state.pathParameters['symbol']!.toUpperCase(),
          side: state.uri.queryParameters['side'] ?? 'BUY',
          paper: state.uri.queryParameters['paper'] == '1',
        ),
      ),
      // F15 模拟盘：同一页面，带 paper=1 时数据来自 /paper/*
      GoRoute(path: '/orders', builder: (_, state) => OrdersPage(paper: state.uri.queryParameters['paper'] == '1')),
      GoRoute(path: '/positions', builder: (_, state) => PositionsPage(paper: state.uri.queryParameters['paper'] == '1')),
      GoRoute(path: Routes.expired, builder: (_, _) => const SessionExpiredPage()),
      // P-03a–g、P-04、P-05、P-30：同一个 OnboardingController（ShellRoute 内创建）
      ShellRoute(
        builder: (_, _, child) => OnboardingHost(child: child),
        routes: [
          GoRoute(path: Routes.onboarding, redirect: (_, _) => '${Routes.onboarding}/a'),
          GoRoute(
            path: '${Routes.onboarding}/:step',
            builder: (_, state) {
              final step = state.pathParameters['step']!;
              return switch (step) {
                'p04' => const IdUploadPage(),
                'p05' => const DisclosuresPage(),
                'p30' => const ReviewPage(),
                _ => OnboardingStepPage(key: ValueKey(step), step: step),
              };
            },
          ),
        ],
      ),
      // 资金（#11）：P-13 入金、P-14 出金、P-18 资金记录、P-31 银行账户、P-32 绑定、P-33 电汇指引
      GoRoute(path: '/funding/deposit', builder: (_, _) => const DepositPage()),
      GoRoute(path: '/funding/withdraw', builder: (_, _) => const WithdrawPage()),
      GoRoute(path: '/funding/history', builder: (_, _) => const TransfersPage()),
      GoRoute(path: '/funding/banks', builder: (_, _) => const BankAccountsPage()),
      GoRoute(path: '/funding/banks/link', builder: (_, _) => const LinkBankPage()),
      GoRoute(path: '/funding/wire', builder: (_, _) => const WireInstructionsPage()),
      // P-06 开户进度；P-34/35/36 KYC 补齐与未通过
      GoRoute(path: Routes.applicationStatus, builder: (_, _) => const ApplicationStatusPage()),
      GoRoute(path: Routes.kycInfo, builder: (_, _) => const KycInfoRequiredPage()),
      GoRoute(path: Routes.kycDocument, builder: (_, _) => const KycDocRequiredPage()),
      GoRoute(path: Routes.kycResult, builder: (_, _) => const KycDeniedPage()),
    ],
  );
}
