import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app/appearance.dart';
import 'app/config.dart';
import 'app/router.dart';
import 'app/scope.dart';
import 'app/theme.dart';
import 'core/api/api_client.dart';
import 'core/session/session.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocaleController.instance.load(); // F18 / F22-0：读取语言选择（首次安装默认英文）
  await AppearanceController.instance.load(); // F21：读取外观选择（默认跟随系统）
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
  String? _shownLocale;
  final _listenables = Listenable.merge([LocaleController.instance, AppearanceController.instance]);

  /// F18：语言切换后把整棵树标记为重建（保留所有页面状态与当前路由），
  /// 让不依赖 Localizations 的组件（const 子树、路由缓存的外壳等）也换成新语言的文案。
  /// F21：深浅色切换时同样整树重建，并标记全部重绘（CustomPainter 的 shouldRepaint 不感知色板变化）。
  void _rebuildAll({bool repaint = false}) => WidgetsBinding.instance.addPostFrameCallback((_) {
    void visit(Element e) {
      e.markNeedsBuild();
      if (repaint && e is RenderObjectElement) e.renderObject.markNeedsPaint();
      e.visitChildren(visit);
    }

    if (mounted) (context as Element).visitChildren(visit);
  });

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
    child: ListenableBuilder(
      listenable: _listenables,
      builder: (context, _) => MaterialApp.router(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(AppPalette.light),
        darkTheme: buildTheme(AppPalette.dark),
        themeMode: AppearanceController.instance.value,
        themeAnimationDuration: Duration.zero, // 令牌按当前色板取值，逐帧插值无意义
        routerConfig: _router,
        // F18：中英双语（F22-0 首次安装为英文）。跟随系统时 locale 为 null，按系统语言解析（zh → 中文，其余 → 英文）
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
          final localeChanged = _shownLocale != null && _shownLocale != l.localeName;
          _shownLocale = l.localeName;
          // F21：按解析后的亮度切换色板（跟随系统时随 iOS 深浅色实时变化）
          final themeChanged = AppColors.apply(Theme.of(context).brightness);
          if (localeChanged || themeChanged) _rebuildAll(repaint: themeChanged);
          // 无 AppBar 的页面（资产首页、欢迎页等）同样按深浅色设置状态栏文字颜色
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppColors.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    ),
  );
}
