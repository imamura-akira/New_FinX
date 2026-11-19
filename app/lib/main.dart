import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app/config.dart';
import 'app/router.dart';
import 'app/scope.dart';
import 'app/theme.dart';
import 'core/api/api_client.dart';
import 'core/session/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    child: MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
      locale: const Locale('zh', 'CN'),
    ),
  );
}
