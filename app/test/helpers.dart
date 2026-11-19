import 'dart:convert';

import 'package:finx_app/app/config.dart';
import 'package:finx_app/core/api/api_client.dart';
import 'package:finx_app/core/session/session.dart';
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
