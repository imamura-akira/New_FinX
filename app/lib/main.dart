import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app/config.dart';
import 'app/router.dart';
import 'app/scope.dart';
import 'app/theme.dart';
import 'core/api/api_client.dart';
import 'core/session/session.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleController.instance.load(); // F18：读取语言选择（默认跟随系统）
  const config = AppConfig.fromEnvironment;
  final api = ApiClient(baseUrl: config.apiBaseUrl);
  final session = SessionController(api: api, store: SecureTokenStore());
  runApp(FinxApp(config: config, api: api, session: session));
  session.restore();
}

class FinxApp extends StatefulWidget {
  const FinxApp({super.key, required this.config, required this.api, required this.session});
  final AppConfig config;
  final ApiClient api;
  final SessionController session;

  @override
  State<FinxApp> createState() => _FinxAppState();
}

class _FinxAppState extends State<FinxApp> {
  late final GoRouter _router = buildRouter(widget.session);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    config: widget.config,
    api: widget.api,
    session: widget.session,
    child: ValueListenableBuilder<String?>(
      valueListenable: LocaleController.instance,
      builder: (context, _, _) => MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: _router,
        // F18：中英双语。跟随系统时 locale 为 null，按系统语言解析（zh → 中文，其余 → 英文）
        locale: LocaleController.instance.locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate, // material_ui
          GlobalCupertinoLocalizations.delegate, // cupertino_ui
          GlobalWidgetsLocalizations.delegate,
        ],
        localeListResolutionCallback: (locales, _) => resolveLocale(locales == null || locales.isEmpty ? null : locales.first),
        builder: (context, child) {
          final l = AppLocalizations.of(context);
          setCurrentLocalizations(l);
          // 语言变化时重建整棵页面树（保留当前路由），让所有文案（含 const 子树）切换
          return KeyedSubtree(key: ValueKey(l.localeName), child: child ?? const SizedBox.shrink());
        },
      ),
    ),
  );
}
