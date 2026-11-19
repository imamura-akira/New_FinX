import 'dart:convert';

import 'package:finx_app/app/config.dart';
import 'package:finx_app/core/api/api_client.dart';
import 'package:finx_app/core/session/session.dart';
import 'package:finx_app/core/widgets/celebration.dart';
import 'package:finx_app/features/market/domain/instruments.dart';
import 'package:finx_app/main.dart';
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
}) async {
  final be = backend ?? FakeBackend();
  // 行情默认模拟（虚拟行情，价格随请求次数变化）；测试可自行覆盖
  be.handlers.putIfAbsent('GET /market/quotes', () => fakeQuotes());
  Watchlist.instance.reset();
  Celebration.resetForTest();
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
