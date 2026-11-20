import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// 总资产卡"今日变动"行：DW 各持仓 unrealizedDayPL 之和；百分比 = 今日盈亏 ÷（现金 + 持仓市值 − 今日盈亏）。

FakeBackend _backend({bool opened = true, List<double> dayPLs = const [30, 12.18], double equity = 4907.41, bool positionsFail = false}) =>
    FakeBackend()
      ..on(
        'GET /me',
        (_) => FakeBackend.ok({
          'email': 'demo@example.com',
          'loginProvider': 'EMAIL',
          'applicationId': opened ? 'app-1' : null,
          'accountStatus': opened ? 'APPROVED' : 'NONE',
        }),
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
          'cash': 1635.80,
          'settledCash': 1635.80,
          'buyingPower': 1635.80,
          'cashAvailableForWithdrawal': 1000,
          'unsettled': 0,
          'pendingDeposits': 0,
          'withheldForSeasoning': 0,
          'updatedAt': '2026-11-20T15:00:00Z',
        }),
      )
      ..on(
        'GET /positions',
        (_) => positionsFail
            ? FakeBackend.err(502, 50001, '券商服务暂时不可用')
            : FakeBackend.ok({
                'equityValue': equity,
                'positions': [
                  for (final (i, d) in dayPLs.indexed) {'symbol': 'S$i', 'quantity': 1, 'marketValue': 1, 'unrealizedDayPL': d},
                ],
              }),
      );

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

String _row(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('home.dayChange'))).data!;

void main() {
  testWidgets('今日变动：DW 持仓今日盈亏之和与百分比（以昨日资产为基数）', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    // 42.18 ÷ (1635.80 + 4907.41 − 42.18) = 0.6488% → +0.65%
    expect(_row(tester), r'今日 +$42.18 (+0.65%)');
  });

  testWidgets('今日下跌显示负号', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(dayPLs: [-10, -5.5]), storedToken: 'tok');
    expect(_row(tester), startsWith(r'今日 -$15.50 (-0.'));
  });

  testWidgets('无持仓：今日为零', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(dayPLs: const [], equity: 0), storedToken: 'tok');
    expect(_row(tester), r'今日 $0.00 (0.00%)');
  });

  testWidgets('隐藏金额时今日变动同样隐藏', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await tester.tap(find.byKey(const Key('home.hide')));
    await tester.pump();
    expect(_row(tester), '今日 ****');
  });

  testWidgets('持仓接口失败：不显示今日变动，资金照常', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(positionsFail: true), storedToken: 'tok');
    expect(find.byKey(const Key('home.dayChange')), findsNothing);
    expect(find.byKey(const Key('home.total')), findsOneWidget);
  });

  testWidgets('未开户：不显示今日变动', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(opened: false), storedToken: 'tok');
    expect(find.byKey(const Key('home.dayChange')), findsNothing);
  });
}
