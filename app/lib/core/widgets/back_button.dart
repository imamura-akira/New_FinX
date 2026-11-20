import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/scope.dart';
import '../session/session.dart';

/// 全屏页统一的返回箭头：能返回上一页就返回；页面是经 `context.go` 直达、栈里没有上一页时，
/// 回到 [fallback]（默认：已登录 → 资产页，未登录 → 欢迎页）。保证任何全屏页都不是"死胡同"。
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback});
  final String? fallback;

  static String defaultFallback(BuildContext context) =>
      AppScope.of(context).session.status == SessionStatus.signedIn ? '/home' : '/';

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('nav.back'),
    tooltip: '返回',
    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
    onPressed: () => context.canPop() ? context.pop() : context.go(fallback ?? defaultFallback(context)),
  );
}
