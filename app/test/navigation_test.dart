import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

/// 已开户、各页面所需接口齐全的假后端。
FakeBackend _backend() => FakeBackend()
  ..on(
    'GET /me',
    (_) => FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': 'app-1', 'accountStatus': 'APPROVED'}),
  )
  ..on(
    'GET /application/status',
    (_) => FakeBackend.ok({
      'kycStatus': 'KYC_APPROVED',
      'issues': [],
      'requiredDocs': [],
      'accountStatus': 'OPEN',
      'accountNo': 'TEST000001',
      'applicationRef': 'FX-1',
      'submittedAt': '2026-10-01T12:00:00Z',
      'submitState': 'SUBMITTED',
    }),
  )
  ..on(
    'GET /account',
    (_) => FakeBackend.ok({
      'accountId': 'a',
      'accountNo': 'TEST000001',
      'status': 'OPEN',
      'accountType': 'LIVE',
      'tradingType': 'CASH',
      'managementType': 'SELF',
    }),
  )
  ..on(
    'GET /account/money',
    (_) => FakeBackend.ok({
      'cash': 1000,
      'settledCash': 1000,
      'buyingPower': 1000,
      'cashAvailableForWithdrawal': 100,
      'unsettled': 0,
      'pendingDeposits': 0,
      'withheldForSeasoning': 0,
    }),
  )
  ..on('GET /positions', (_) => FakeBackend.ok({'equityValue': 0, 'positions': []}))
  ..on('GET /orders', (_) => FakeBackend.ok([]))
  ..on('POST /orders', (_) => FakeBackend.ok({'orderId': 'ord-1', 'status': 'NEW'}))
  ..on(
    'GET /orders/ord-1',
    (_) => FakeBackend.ok({
      'orderId': 'ord-1',
      'symbol': 'AAPL',
      'side': 'BUY',
      'orderType': 'MARKET',
      'amount': 100,
      'status': 'NEW',
      'submittedAt': '2026-11-23T15:00:00Z',
      'updatedAt': '2026-11-23T15:00:00Z',
    }),
  )
  ..on(
    'GET /funding/bank-accounts',
    (_) => FakeBackend.ok([
      {
        'id': 'bank-1',
        'bankName': '',
        'nickname': 'Payroll',
        'mask': '6789',
        'type': 'CHECKING',
        'ownerName': 'Demo Tester',
        'status': 'ACTIVE',
        'createdAt': '2026-11-19T12:00:00Z',
      },
    ]),
  )
  ..on('GET /funding/transfers', (_) => FakeBackend.ok([]))
  ..on('POST /funding/deposits', (_) => FakeBackend.ok({'transferId': 'tr-1', 'status': 'PENDING'}))
  ..on('GET /funding/deposit-instructions', (_) => FakeBackend.ok({'beneficiaryName': 'DriveWealth', 'reference': 'TEST000001'}))
  ..on(
    'GET /market/instruments/AAPL',
    (_) => FakeBackend.ok({
      'simulated': true,
      'symbol': 'AAPL',
      'name': 'Apple Inc.',
      'exchange': 'NASDAQ',
      'type': 'STOCK',
      'last': 226.1,
      'chg': 1.0,
      'chgPct': 0.4,
      'dayHigh': 227.0,
      'dayLow': 225.0,
      'prevClose': 225.1,
      'candles': [
        for (var i = 0; i < 5; i++) {'t': '2026-11-23T14:0$i:00Z', 'o': 226.0, 'h': 226.5, 'l': 225.5, 'c': 226.0 + i * 0.1},
      ],
    }),
  );

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

GoRouter _router(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Scaffold).first));

Future<void> _settle(WidgetTester tester) => frames(tester, 8);

void main() {
  // 每个全屏页经 context.go 直达（栈里没有上一页）时，都必须有返回箭头，且能回到资产页 / 市场页。
  const deepLinks = {
    '/funding/deposit': '/home',
    '/funding/withdraw': '/home',
    '/funding/history': '/home', // P-18（本次 bug）
    '/funding/banks': '/home',
    '/funding/banks/link': '/home',
    '/funding/wire': '/home',
    '/orders': '/home',
    '/positions': '/home',
    '/trade/AAPL': '/home',
    '/market/AAPL': '/market',
    '/masters/all': '/home',
    '/masters/i1': '/home',
    '/application/status': '/home',
  };
  for (final e in deepLinks.entries) {
    testWidgets('直达 ${e.key}：有返回箭头，返回到 ${e.value}', (tester) async {
      await _phone(tester);
      await pumpApp(tester, backend: _backend(), storedToken: 'tok');
      _router(tester).go(e.key);
      await _settle(tester);
      final back = find.byWidgetPredicate((w) => w.key == const Key('nav.back') || w.key == const Key('kyc.back'));
      expect(back, findsOneWidget, reason: '${e.key} 不能是死胡同');
      await tester.tap(back);
      await _settle(tester);
      expect(_router(tester).routeInformationProvider.value.uri.path, e.value);
    });
  }

  testWidgets('P-13 入金结果 → 查看资金记录（P-18）→ 返回回到资产页', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    _router(tester).push('/funding/deposit');
    await _settle(tester);
    await tester.tap(find.byKey(const Key('p13.ach')));
    await _settle(tester);
    await tester.enterText(find.byKey(const Key('p13.amount')), '100');
    await tester.tap(find.byKey(const Key('p13.next')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('p13.submit')));
    await _settle(tester);
    await tester.tap(find.text('查看资金记录'));
    await tester.pumpAndSettle();
    expect(find.text('资金记录'), findsWidgets);
    await tester.tap(find.byKey(const Key('nav.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.hero')), findsOneWidget, reason: '返回资产页，而不是回到已完成的入金结果页');
  });

  testWidgets('P-10 → P-19 结果 → 查看订单（P-11）→ 返回回到 P-10', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    _router(tester).push('/market/AAPL');
    await _settle(tester);
    await tester.tap(find.byKey(const Key('p10.buy')));
    await _settle(tester);
    await tester.enterText(find.byKey(const Key('p19.input')), '100');
    await tester.tap(find.byKey(const Key('p19.next')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('p19.submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('p19.orders')));
    await tester.pumpAndSettle();
    expect(find.text('订单'), findsWidgets);
    await tester.tap(find.byKey(const Key('nav.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('p10.last')), findsOneWidget);
  });

  testWidgets('未登录直达个股页：返回到市场页', (tester) async {
    await _phone(tester);
    final be = _backend()..handlers.remove('GET /me');
    await pumpApp(tester, backend: be);
    _router(tester).go('/market/AAPL');
    await _settle(tester);
    await tester.tap(find.byKey(const Key('nav.back')));
    await _settle(tester);
    expect(_router(tester).routeInformationProvider.value.uri.path, '/market');
  });

  testWidgets('登录页（P-02）有返回箭头回到欢迎页', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: FakeBackend());
    _router(tester).go('/login');
    await _settle(tester);
    await tester.tap(find.byKey(const Key('nav.back')));
    await _settle(tester);
    expect(_router(tester).routeInformationProvider.value.uri.path, '/');
  });
}
