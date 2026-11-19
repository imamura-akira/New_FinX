import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/session/session.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/welcome_page.dart';
import '../features/common/session_expired_page.dart';
import '../features/home/presentation/home_page.dart';

/// 路由（pages.md 第 2 节导航结构）。会话状态驱动重定向：
///   未登录 → P-01 / P-02；已登录 → P-07；会话过期 → S-01。
abstract final class Routes {
  static const welcome = '/';
  static const login = '/login';
  static const home = '/home';
  static const expired = '/expired';
  static const splash = '/splash';
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
    ],
  );
}
