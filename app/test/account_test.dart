import 'package:finx_app/core/format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

Map<String, dynamic> _status(
  String kyc, {
  String? account,
  String? accountNo,
  String submit = 'SUBMITTED',
  List<Map<String, dynamic>> issues = const [],
}) => {
  'kycStatus': kyc,
  'kycUpdatedAt': '2026-11-19T12:01:00Z',
  'issues': issues,
  'requiredDocs': [],
  'accountStatus': account,
  'accountNo': accountNo,
  'applicationRef': 'FX261119-ABCD',
  'submittedAt': '2026-11-19T12:00:00Z',
  'submitState': submit,
};

const _money = {
  'cash': 5000,
  'settledCash': 5000,
  'buyingPower': 5000,
  'cashAvailableForWithdrawal': 0,
  'unsettled': 0,
  'pendingDeposits': 0,
  'withheldForSeasoning': 5000,
  'updatedAt': '2026-11-19T12:30:00Z',
};

FakeBackend _backend(String appStatus, List<Map<String, dynamic>> statuses, {String accountStatus = 'OPEN'}) {
  var n = 0;
  return FakeBackend()
    ..on(
      'GET /me',
      (_) => FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': 'app-1', 'accountStatus': appStatus}),
    )
    ..on('GET /application/status', (_) => FakeBackend.ok(statuses[(n++).clamp(0, statuses.length - 1)]))
    ..on(
      'GET /account',
      (_) => FakeBackend.ok({
        'accountId': 'acc-1',
        'accountNo': 'TEST000001',
        'status': accountStatus,
        'accountType': 'LIVE',
        'tradingType': 'CASH',
        'managementType': 'SELF',
        'openedAt': '2026-11-19T12:02:00Z',
      }),
    )
    ..on('GET /account/money', (_) => FakeBackend.ok(_money));
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  test('金额格式', () {
    expect(fmtUsd(0), r'$0.00');
    expect(fmtUsd(1234567.5), r'$1,234,567.50');
    expect(fmtUsd(-12.345), r'-$12.35');
  });

  testWidgets('P-06：核验中自动轮询，DW 开户后显示账户号码与资金入口', (tester) async {
    await _phone(tester);
    final be = _backend('SUBMITTED', [
      _status('KYC_PROCESSING'), // 首页
      _status('KYC_PROCESSING'), // P-06 首次加载
      _status('KYC_APPROVED', account: 'OPEN', accountNo: 'TEST000001'), // 轮询
    ]);
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await tester.tap(find.byKey(const Key('home.status.link')));
    await frames(tester); // 页面有转圈动画，不能 pumpAndSettle
    expect(find.text('Verifying your identity'), findsWidgets);
    expect(find.byKey(const Key('p06.accountNo')), findsNothing);

    await tester.pump(const Duration(seconds: 5)); // 轮询
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('p06.accountNo')), findsOneWidget);
    expect(find.text('TEST000001'), findsOneWidget);
    expect(find.text('Funding options'), findsOneWidget);
    expect(find.byKey(const Key('p06.step.2.done')), findsOneWidget);
    final polls = be.requests.where((r) => r.url.path.endsWith('/application/status')).length;

    await tester.pump(const Duration(seconds: 12)); // 账户已开立：停止轮询
    expect(be.requests.where((r) => r.url.path.endsWith('/application/status')).length, polls);
    await tester.tap(find.byKey(const Key('p06.later')));
    await tester.pumpAndSettle();
  });

  testWidgets('P-07 / P-08：已开户显示 DW 资金汇总与账户号码', (tester) async {
    await _phone(tester);
    await pumpApp(
      tester,
      backend: _backend('APPROVED', [_status('KYC_APPROVED', account: 'OPEN', accountNo: 'TEST000001')]),
      storedToken: 'tok',
    );
    expect(find.byKey(const Key('home.total')), findsOneWidget);
    expect(find.text(r'$5,000.00'), findsWidgets);
    expect(find.byKey(const Key('home.withdrawable')), findsNothing, reason: 'F22-a：可提现移至账户抽屉资金区');
    expect(find.text('观察期内暂不可提现'), findsOneWidget);
    expect(find.byKey(const Key('home.openAccount')), findsNothing);

    await tester.tap(find.byKey(const Key('home.hide')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('home.total'))).data, '****');

    await tester.tap(find.byKey(const Key('home.avatar')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('drawer.accountNo'))).data, 'TEST000001');
    expect(find.text('现金 · 自主'), findsOneWidget);
    expect(find.text('账户类型 LIVE · CASH · SELF'), findsOneWidget);
  });

  testWidgets('账户冻结：首页常驻受限提示', (tester) async {
    await _phone(tester);
    await pumpApp(
      tester,
      backend: _backend('APPROVED', [_status('KYC_APPROVED', account: 'FROZEN', accountNo: 'TEST000001')], accountStatus: 'FROZEN'),
      storedToken: 'tok',
    );
    expect(find.textContaining('账户已冻结'), findsOneWidget);
    expect(find.byKey(const Key('home.deposit')), findsNothing);
  });

  testWidgets('KYC_INFO_REQUIRED：首页与 P-06 入口标注待沙盒验证，P-34 重新提交不可用', (tester) async {
    await _phone(tester);
    final issue = {'code': 'NAME_MISMATCH', 'field': 'firstName', 'userMessage': 'Enter your name exactly as on your ID'};
    await pumpApp(
      tester,
      backend: _backend('SUBMITTED', [
        _status('KYC_INFO_REQUIRED', issues: [issue]),
      ]),
      storedToken: 'tok',
    );
    expect(find.text('开户资料需要修改'), findsOneWidget);
    expect(find.text('待沙盒验证'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home.status.link')));
    await tester.pumpAndSettle();
    expect(find.text('Update your information'), findsWidgets);
    expect(find.text('Enter your name exactly as on your ID'), findsOneWidget);
    expect(find.text('Pending sandbox verification'), findsOneWidget);
    final btn = tester.widget<TextButton>(find.descendant(of: find.byKey(const Key('p34.submit')), matching: find.byType(TextButton)));
    expect(btn.onPressed, isNull);
  });

  testWidgets('KYC_DENIED：P-06 → P-36 显示参考号，不展示原因', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend('DENIED', [_status('KYC_DENIED')]), storedToken: 'tok');
    expect(find.text('开户未通过'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home.status.link')));
    await tester.pumpAndSettle();
    expect(find.text("We can't open your account right now"), findsOneWidget);
    expect(find.byKey(const Key('p36.ref')), findsOneWidget);
    expect(find.text('FX261119-ABCD'), findsOneWidget);
  });

  testWidgets('提交遇到问题（NEEDS_ATTENTION）：P-06 提示人工处理且不轮询', (tester) async {
    await _phone(tester);
    final be = _backend('SUBMITTED', [_status('KYC_NOT_READY', submit: 'NEEDS_ATTENTION')]);
    await pumpApp(tester, backend: be, storedToken: 'tok');
    expect(find.text('开户申请需要人工处理'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home.status.link')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Our team has been notified'), findsOneWidget);
    final n = be.requests.where((r) => r.url.path.endsWith('/application/status')).length;
    await tester.pump(const Duration(seconds: 10));
    expect(be.requests.where((r) => r.url.path.endsWith('/application/status')).length, n);
  });
}
