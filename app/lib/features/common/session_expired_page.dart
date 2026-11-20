import 'package:material_ui/material_ui.dart';

import '../../app/scope.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/l10n.dart';

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
          title: t.expiredPleaseSignInAgain,
          message: t.expiredYourSessionHasExpired,
          actions: [AppButton(t.expiredBackToSignIn, key: const Key('expired.relogin'), onPressed: () => session.acknowledgeExpired())],
        ),
      ),
    );
  }
}
