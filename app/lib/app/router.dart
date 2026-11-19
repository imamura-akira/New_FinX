import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/session/session.dart';
import '../features/account/presentation/application_status_page.dart';
import '../features/account/presentation/kyc_action_pages.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/welcome_page.dart';
import '../features/common/session_expired_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/onboarding/presentation/final_pages.dart';
import '../features/onboarding/presentation/onboarding_shell.dart';
import '../features/onboarding/presentation/step_pages.dart';

/// 路由（pages.md 第 2 节导航结构）。会话状态驱动重定向：
///   未登录 → P-01 / P-02；已登录 → P-07；会话过期 → S-01。
abstract final class Routes {
  static const welcome = '/';
  static const login = '/login';
  static const home = '/home';
  static const expired = '/expired';
  static const splash = '/splash';
  static const onboarding = '/onboarding';
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
          return publicRoutes.contains(loc) ? null : Routes.welcome;
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
      GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
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
      // P-06 开户进度；P-34/35/36 KYC 补齐与未通过
      GoRoute(path: Routes.applicationStatus, builder: (_, _) => const ApplicationStatusPage()),
      GoRoute(path: Routes.kycInfo, builder: (_, _) => const KycInfoRequiredPage()),
      GoRoute(path: Routes.kycDocument, builder: (_, _) => const KycDocRequiredPage()),
      GoRoute(path: Routes.kycResult, builder: (_, _) => const KycDeniedPage()),
    ],
  );
}
