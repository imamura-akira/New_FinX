import 'dart:io';

import 'package:finx_app/core/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

void main() {
  group('ApiClient 信封与错误映射', () {
    final cases = <(String, http.Response, int?, String?)>[
      ('成功返回 data', FakeBackend.ok({'x': 1}), null, null),
      (
        '42200 带字段错误',
        FakeBackend.err(422, 42200, '请检查标红的字段', {
          'fields': [
            {'field': 'email', 'reason': '请输入有效的邮箱地址'},
          ],
        }),
        42200,
        'email',
      ),
      ('42901 限频', FakeBackend.err(429, 42901, '请求过于频繁，请稍后再试', {'retryAfter': 30}), 42901, null),
      ('非 JSON 响应', http.Response('<html>502</html>', 502), ApiCodes.network, null),
    ];
    for (final (name, resp, wantCode, wantField) in cases) {
      test(name, () async {
        final api = ApiClient(baseUrl: 'http://t/api/v1', httpClient: MockClient((_) async => resp));
        if (wantCode == null) {
          expect(await api.get('/x'), {'x': 1});
          return;
        }
        try {
          await api.get('/x');
          fail('应抛出 ApiException');
        } on ApiException catch (e) {
          expect(e.code, wantCode);
          expect(e.message, isNotEmpty);
          if (wantField != null) expect(e.fieldMap.keys, contains(wantField));
        }
      });
    }
  });

  test('网络错误转为可展示的中文', () async {
    final api = ApiClient(baseUrl: 'http://t/api/v1', httpClient: MockClient((_) async => throw const SocketException('down')));
    expect(() => api.get('/x'), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('网络'))));
  });

  test('401xx 触发会话失效回调；带 token 时附加 Authorization', () async {
    String? auth;
    final api = ApiClient(
      baseUrl: 'http://t/api/v1/',
      httpClient: MockClient((req) async {
        auth = req.headers['Authorization'];
        expect(req.url.toString(), 'http://t/api/v1/me');
        return FakeBackend.err(401, 40101, '请先登录');
      }),
    )..tokenProvider = () => 'abc';
    var invalid = 0;
    api.onSessionInvalid = () => invalid++;
    await expectLater(api.get('/me'), throwsA(isA<ApiException>()));
    expect(auth, 'Bearer abc');
    expect(invalid, 1);
  });
}
