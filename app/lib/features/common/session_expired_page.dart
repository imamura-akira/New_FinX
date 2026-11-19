import 'package:material_ui/material_ui.dart';

import '../../app/scope.dart';
import '../../core/widgets/widgets.dart';

/// S-01 全局状态页 · 会话过期（文案同原型 S-01 expired）。
class SessionExpiredPage extends StatelessWidget {
  const SessionExpiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    return Scaffold(
      body: SafeArea(
        child: StateView(
          icon: Icons.lock_outline_rounded,
          title: '请重新登录',
          message: '登录已过期或尚未登录。返回 App 登录后即可继续您的申请。',
          actions: [AppButton('返回登录', key: const Key('expired.relogin'), onPressed: () => session.acknowledgeExpired())],
        ),
      ),
    );
  }
}
