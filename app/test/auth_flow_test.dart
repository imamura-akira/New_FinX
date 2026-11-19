import 'package:finx_app/core/session/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

const _me = {'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': null, 'accountStatus': 'NONE'};

FakeBackend _backend() => FakeBackend()
  ..on('POST /auth/otp/request', (_) => FakeBackend.ok({'ttl': 300, 'resendAfter': 60}))
  ..on('POST /auth/otp/verify', (req) {
    return req.body.contains('"000000"')
        ? FakeBackend.ok({'sessionToken': 'tok-1', 'isNewUser': true})
        : FakeBackend.err(422, 42200, '验证码不正确或已过期', {
            'fields': [
              {'field': 'code', 'reason': '验证码不正确或已过期，请重新获取'},
            ],
          });
  })
  ..on('GET /me', (_) => FakeBackend.ok(_me))
  ..on('POST /auth/logout', (_) => FakeBackend.ok());

Future<void> _goLogin(WidgetTester tester, {bool register = false}) async {
  await tester.tap(find.byKey(Key(register ? 'welcome.register' : 'welcome.login')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('P-01 未登录时显示欢迎页，可进入注册', (tester) async {
    await pumpApp(tester);
    expect(find.text('美股与 ETF 投资，开户、入金、交易一站完成。'), findsOneWidget);
    await _goLogin(tester, register: true);
    expect(find.text('注册并登录'), findsOneWidget);
    expect(find.textContaining('《用户服务协议》'), findsOneWidget);
  });

  group('P-02 表单校验', () {
    final cases = <(String, String, String, bool, String)>[
      // (名称, 邮箱, 验证码, 注册模式, 期望出现的错误文案)
      ('邮箱格式错误', 'not-an-email', '000000', false, '请输入有效的邮箱地址'),
      ('验证码不足 6 位', 'demo@example.com', '123', false, '请输入 6 位验证码'),
      ('注册未同意条款', 'demo@example.com', '000000', true, '请先同意平台条款'),
      ('服务端验证码错误映射到字段', 'demo@example.com', '111111', false, '验证码不正确或已过期，请重新获取'),
    ];
    for (final (name, email, code, register, want) in cases) {
      testWidgets(name, (tester) async {
        final (be, session, _) = await pumpApp(tester, backend: _backend());
        await _goLogin(tester, register: register);
        await tester.enterText(find.byKey(const Key('login.email')), email);
        await tester.enterText(find.byKey(const Key('login.code')), code);
        await tester.tap(find.byKey(const Key('login.submit')));
        await tester.pumpAndSettle();
        expect(find.text(want), findsOneWidget);
        expect(session.status, SessionStatus.signedOut);
      });
    }
  });

  testWidgets('P-02 获取验证码：空邮箱不请求、倒计时与演示提示', (tester) async {
    final be = _backend();
    final (_, _, _) = await pumpApp(tester, backend: be);
    await _goLogin(tester);
    await tester.tap(find.byKey(const Key('login.send')));
    await tester.pumpAndSettle();
    expect(find.text('邮箱'), findsOneWidget);
    expect(find.text('请输入有效的邮箱地址'), findsOneWidget, reason: '未填邮箱时不应请求');
    expect(be.requests, isEmpty);

    await tester.enterText(find.byKey(const Key('login.email')), 'Demo@Example.com');
    await tester.tap(find.byKey(const Key('login.send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(be.lastBody('POST /auth/otp/request')['email'], 'Demo@Example.com');
    expect(find.text('演示环境验证码：000000'), findsOneWidget);
    expect(find.textContaining('s 后重发'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    expect(find.text('重新获取'), findsOneWidget);
  });

  testWidgets('登录成功进入首页并显示 /me；退出回到欢迎页', (tester) async {
    final (be, session, store) = await pumpApp(tester, backend: _backend());
    await _goLogin(tester);
    await tester.enterText(find.byKey(const Key('login.email')), 'demo@example.com');
    await tester.enterText(find.byKey(const Key('login.code')), '000000');
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();

    expect(session.status, SessionStatus.signedIn);
    expect(store.value, 'tok-1');
    expect(find.byKey(const Key('home.email')), findsOneWidget);
    expect(find.text('demo@example.com'), findsOneWidget);
    expect(find.text('尚未开户'), findsOneWidget);
    // 后续请求带 Bearer token
    final meReq = be.requests.lastWhere((r) => r.url.path.endsWith('/me'));
    expect(meReq.headers['Authorization'], 'Bearer tok-1');

    await tester.tap(find.byKey(const Key('home.logout')));
    await tester.pumpAndSettle();
    expect(store.value, isNull);
    expect(find.byKey(const Key('welcome.login')), findsOneWidget);
  });

  testWidgets('已保存的 token 启动即进入首页', (tester) async {
    await pumpApp(tester, backend: _backend(), storedToken: 'tok-saved');
    expect(find.byKey(const Key('home.email')), findsOneWidget);
  });

  testWidgets('会话过期（40102）进入 S-01，返回登录', (tester) async {
    final be = _backend()..on('GET /me', (_) => FakeBackend.err(401, 40102, '登录已过期，请重新登录'));
    final (_, session, store) = await pumpApp(tester, backend: be, storedToken: 'tok-old');
    expect(session.status, SessionStatus.expired);
    expect(store.value, isNull);
    expect(find.text('请重新登录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('expired.relogin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome.login')), findsOneWidget);
  });

  testWidgets('Google / Apple 登录提示暂未开通，不调用接口', (tester) async {
    final (be, _, _) = await pumpApp(tester, backend: _backend());
    await _goLogin(tester);
    await tester.tap(find.text('使用 Google 登录'));
    await tester.pump();
    expect(find.textContaining('后续版本开通，请先使用邮箱验证码登录'), findsOneWidget);
    expect(be.requests.where((r) => r.url.path.contains('oauth')), isEmpty);
  });
}
