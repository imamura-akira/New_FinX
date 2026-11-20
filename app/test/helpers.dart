import 'dart:convert';

import 'package:finx_app/app/config.dart';
import 'package:finx_app/core/api/api_client.dart';
import 'package:finx_app/core/session/session.dart';
import 'package:finx_app/core/widgets/celebration.dart';
import 'package:finx_app/features/auth/presentation/welcome_page.dart';
import 'package:finx_app/features/market/domain/instruments.dart';
import 'package:finx_app/features/trading/domain/trading_mode.dart';
import 'package:finx_app/main.dart';
import 'package:finx_app/l10n/l10n.dart';
import 'package:finx_app/app/appearance.dart';
import 'package:finx_app/app/theme.dart';
import 'package:material_ui/material_ui.dart' show Brightness, Locale, ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 假后端：按 "METHOD /path" 返回预设信封；记录收到的请求。
class FakeBackend {
  final requests = <http.Request>[];
  final handlers = <String, http.Response Function(http.Request)>{};

  static http.Response ok([Object? data]) => http.Response.bytes(
    utf8.encode(jsonEncode({'code': 0, 'message': 'ok', 'data': ?data})),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  static http.Response err(int status, int code, String message, [Object? data]) => http.Response.bytes(
    utf8.encode(jsonEncode({'code': code, 'message': message, 'data': ?data})),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  void on(String key, http.Response Function(http.Request) h) => handlers[key] = h;

  MockClient get client => MockClient((req) async {
    requests.add(req);
    final key = '${req.method} ${req.url.path.replaceFirst('/api/v1', '')}';
    final h = handlers[key];
    if (h == null) return err(404, 50003, '未模拟的接口 $key');
    return h(req);
  });

  Map<String, dynamic> lastBody(String key) {
    final r = requests.lastWhere((r) => '${r.method} ${r.url.path.replaceFirst('/api/v1', '')}' == key);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}

/// 启动完整 App（真实路由与会话），后端为 FakeBackend，token 存内存。
Future<(FakeBackend, SessionController, MemoryTokenStore)> pumpApp(
  WidgetTester tester, {
  FakeBackend? backend,
  String? storedToken,
  bool demo = true,
  String? locale = 'zh', // F18：测试默认固定中文；null = 跟随系统（测试环境系统语言为英文）
  ThemeMode appearance = ThemeMode.light, // F21：测试默认浅色；深色测试传 ThemeMode.dark
}) async {
  LocaleController.instance.value = locale;
  AppearanceController.instance.value = appearance;
  AppColors.apply(appearance == ThemeMode.dark ? Brightness.dark : Brightness.light);
  debugSetLocale(Locale(locale ?? 'en'));
  final be = backend ?? FakeBackend();
  // 行情默认模拟（虚拟行情，价格随请求次数变化）；测试可自行覆盖
  be.handlers.putIfAbsent('GET /market/quotes', () => fakeQuotes());
  be.handlers.putIfAbsent('GET /market/sentiment', () => fakeSentiment());
  Watchlist.instance.reset();
  Celebration.resetForTest();
  LaunchIntro.resetForTest();
  TradingMode.instance.reset();
  final api = ApiClient(baseUrl: 'http://test/api/v1', httpClient: be.client);
  final store = MemoryTokenStore()..value = storedToken;
  final session = SessionController(api: api, store: store);
  await tester.pumpWidget(
    FinxApp(
      config: AppConfig(apiBaseUrl: 'http://test/api/v1', demoMode: demo),
      api: api,
      session: session,
    ),
  );
  await session.restore();
  await tester.pumpAndSettle();
  return (be, session, store);
}

/// 页面含无限动画（转圈）时代替 pumpAndSettle。
Future<void> frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 虚拟行情假数据：每次请求价格 +0.01 * n，便于验证刷新。
http.Response Function(http.Request) fakeQuotes() {
  var n = 0;
  return (req) {
    n++;
    final want = req.url.queryParameters['symbols']?.split(',');
    final all = <String, double>{
      'AAPL': 226.10,
      'NVDA': 129.40,
      'TSLA': 241.20,
      'MSFT': 418.02,
      'SPY': 592.00,
      'QQQ': 508.70,
      'DIA': 440.90,
      'IWM': 226.90,
      'GLD': 241.20,
      'TLT': 92.60,
    };
    final quotes = [
      for (final e in all.entries)
        if (want == null || want.contains(e.key))
          {
            'symbol': e.key,
            'last': e.value + n * 0.01,
            'chg': e.key == 'TSLA' ? -1.5 : 1.0,
            'chgPct': e.key == 'TSLA' ? -0.62 : (e.key == 'NVDA' ? 2.1 : 0.4),
            'bid': e.value - 0.03,
            'ask': e.value + 0.03,
          },
    ];
    return FakeBackend.ok({'simulated': true, 'ts': '2026-11-19T15:00:00Z', 'quotes': quotes});
  };
}

/// 模拟 GET /market/sentiment：每次请求按序返回 values 中的指数（用完停在最后一个），涨跌家数固定。
http.Response Function(http.Request) fakeSentiment({List<int> values = const [62], int up = 18, int down = 9, int flat = 3}) {
  var n = 0;
  return (req) {
    final v = values[n < values.length ? n : values.length - 1];
    n++;
    return FakeBackend.ok({
      'simulated': true,
      'ts': '2026-11-19T15:00:00Z',
      'fearGreed': {'value': v, 'label': 'GREED'},
      'breadth': {'up': up, 'down': down, 'flat': flat, 'total': up + down + flat, 'flatThresholdPct': 0.1},
    });
  };
}
