import 'package:flutter/widgets.dart';

import '../core/api/api_client.dart';
import '../core/session/session.dart';
import 'config.dart';

/// 依赖注入：页面通过 AppScope.of(context) 取得 API 与会话。
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.config, required this.api, required this.session, required super.child});

  final AppConfig config;
  final ApiClient api;
  final SessionController session;

  static AppScope of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(s != null, 'AppScope not found');
    return s!;
  }

  @override
  bool updateShouldNotify(AppScope old) => api != old.api || session != old.session || config != old.config;
}
