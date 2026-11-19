import 'dart:convert';

import 'package:finx_app/core/widgets/celebration.dart';
import 'package:finx_app/features/funding/domain/funding_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

const _bank = {
  'id': 'bank-1',
  'bankName': '',
  'nickname': 'Payroll',
  'mask': '6789',
  'type': 'CHECKING',
  'ownerName': 'Demo Tester',
  'status': 'APPROVED',
  'createdAt': '2026-11-19T12:00:00Z',
};

FakeBackend _backend({List<Map<String, dynamic>> banks = const [], double withdrawable = 0}) {
  final bankList = [...banks];
  return FakeBackend()
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
        'submittedAt': '2026-11-19T12:00:00Z',
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
        'cashAvailableForWithdrawal': withdrawable,
        'unsettled': 0,
        'pendingDeposits': 0,
        'withheldForSeasoning': 1000 - withdrawable,
        'updatedAt': '2026-11-19T12:30:00Z',
      }),
    )
    ..on('GET /funding/bank-accounts', (_) => FakeBackend.ok(bankList))
    ..on('POST /funding/bank-accounts', (req) {
      bankList.add(_bank);
      return FakeBackend.ok({'id': 'bank-1', 'status': 'APPROVED'});
    })
    ..on('POST /funding/deposits', (_) => FakeBackend.ok({'transferId': 'tr-1', 'status': 'PENDING'}))
    ..on(
      'GET /funding/transfers',
      (_) => FakeBackend.ok([
        {
          'transferId': 'tr-1',
          'type': 'DEPOSIT',
          'method': 'ACH',
          'amount': 1000,
          'status': 'SUCCESSFUL',
          'failureReason': null,
          'submittedAt': '2026-11-19T12:00:00Z',
          'doneAt': '2026-11-19T12:00:05Z',
          'bankAccountId': 'bank-1',
          'buyingPowerAvailableAt': '2026-11-23T00:00:00Z',
          'withdrawableAt': '2026-12-19T00:00:00Z',
        },
      ]),
    );
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _openDrawerItem(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(const Key('home.avatar')));
  await tester.pumpAndSettle();
  final f = find.byKey(Key(key));
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first,
  );
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('金额与路由号码校验', () {
    test('入金', () {
      expect(validateDeposit(''), '请输入入金金额');
      expect(validateDeposit('abc'), contains('有效金额'));
      expect(validateDeposit('10.123'), contains('两位小数'));
      expect(validateDeposit('5'), contains(r'$10.00'));
      expect(validateDeposit('50000.01'), contains(r'$50,000.00'));
      expect(validateDeposit('1,000.50'), isNull);
    });
    test('出金不超过 DW 可提现金额', () {
      expect(validateWithdrawal('10', 0), contains('超过可提现金额'));
      expect(validateWithdrawal('0.5', 100), contains('最低'));
      expect(validateWithdrawal('100', 100), isNull);
    });
    test('ABA 校验位', () {
      expect(validAba('021000021'), isTrue);
      expect(validAba('021000022'), isFalse);
      expect(validAba('12345'), isFalse);
    });
  });

  testWidgets('P-13：未绑卡 → P-32 绑定 → 金额校验 → 确认 → 提交', (tester) async {
    await _phone(tester);
    final (be, _, _) = await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _openDrawerItem(tester, 'drawer.deposit');
    expect(find.text('需先绑定本人名下的美国银行账户'), findsOneWidget);

    await tester.tap(find.byKey(const Key('p13.ach')));
    await tester.pumpAndSettle();
    // P-32：客户端校验
    await tester.enterText(find.byKey(const Key('p32.routing')), '021000022');
    await tester.enterText(find.byKey(const Key('p32.account')), '12');
    await tester.tap(find.byKey(const Key('p32.submit')));
    await tester.pumpAndSettle();
    expect(find.text('请输入有效的 9 位 ABA 路由号码'), findsOneWidget);
    expect(find.text('请输入 4–17 位银行账号'), findsOneWidget);
    expect(be.requests.where((r) => r.method == 'POST'), isEmpty);

    await tester.enterText(find.byKey(const Key('p32.routing')), '021000021');
    await tester.enterText(find.byKey(const Key('p32.account')), '000123456789');
    await tester.tap(find.byKey(const Key('p32.submit')));
    await tester.pumpAndSettle();
    final link = be.lastBody('POST /funding/bank-accounts');
    expect(link['type'], 'CHECKING');
    expect(link.containsKey('ownerName'), isFalse, reason: '户名由后端写入');

    // 回到 P-13 填写页
    expect(find.text('Payroll ••6789'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // 等"绑定成功"提示消失（会盖住底部按钮）
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('p13.amount')), '5');
    await tester.tap(find.byKey(const Key('p13.next')));
    await tester.pumpAndSettle();
    expect(find.text(r'单笔最低入金 $10.00'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('p13.amount')), '1000');
    await tester.tap(find.byKey(const Key('p13.next')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('p13.confirm.amount'))).data, r'$1,000.00');
    await tester.tap(find.byKey(const Key('p13.submit')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // 逐帧推进：pumpAndSettle 会把 2 秒庆祝动画跑完
    }
    expect(be.lastBody('POST /funding/deposits'), {'bankAccountId': 'bank-1', 'amount': 1000});
    expect(find.text('入金已提交'), findsWidgets);
    expect(find.text('tr-1'), findsOneWidget);
    // 入金提交成功：轻量版庆祝
    expect(find.byType(ConfettiBurst), findsOneWidget);
    expect(tester.widget<ConfettiBurst>(find.byType(ConfettiBurst)).level, CelebrationLevel.light);
    await tester.pumpAndSettle();
    expect(find.byType(ConfettiBurst), findsNothing);
  });

  testWidgets('P-13：券商结果不明（50001 附 transferId）显示"已记录"，不报错', (tester) async {
    await _phone(tester);
    final be = _backend(banks: [_bank])
      ..on('POST /funding/deposits', (_) => FakeBackend.err(502, 50001, '券商暂时无法处理', {'transferId': 'tr-9'}));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _openDrawerItem(tester, 'drawer.deposit');
    await tester.tap(find.byKey(const Key('p13.ach')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('p13.amount')), '20');
    await tester.tap(find.byKey(const Key('p13.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('p13.submit')));
    await tester.pumpAndSettle();
    expect(find.text('入金已记录'), findsWidgets);
    expect(find.text('tr-9'), findsOneWidget);
    expect(find.text('提交中'), findsOneWidget);
    expect(find.byType(ConfettiBurst), findsNothing, reason: '结果待确认时不庆祝');
  });

  testWidgets('P-14：可提现为 0 时拦截；服务端 42201 显示限额信息', (tester) async {
    await _phone(tester);
    final be = _backend(banks: [_bank], withdrawable: 0);
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _openDrawerItem(tester, 'drawer.withdraw');
    expect(tester.widget<Text>(find.byKey(const Key('p14.withdrawable'))).data, r'$0.00');
    await tester.enterText(find.byKey(const Key('p14.amount')), '10');
    await tester.tap(find.byKey(const Key('p14.next')));
    await tester.pumpAndSettle();
    expect(find.text(r'超过可提现金额 $0.00'), findsOneWidget);
    expect(be.requests.where((r) => r.url.path.endsWith('/funding/withdrawals')), isEmpty);
  });

  testWidgets('P-14：服务端以 DW 实时可提现拒绝（42201）', (tester) async {
    await _phone(tester);
    final be = _backend(banks: [_bank], withdrawable: 500)
      ..on(
        'POST /funding/withdrawals',
        (_) => FakeBackend.err(422, 42201, r'超过可提现金额 $0.00', {
          'limits': {'available': '0.00'},
        }),
      );
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _openDrawerItem(tester, 'drawer.withdraw');
    await tester.enterText(find.byKey(const Key('p14.amount')), '100');
    await tester.tap(find.byKey(const Key('p14.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('p14.submit')));
    await tester.pumpAndSettle();
    expect(jsonDecode(be.requests.lastWhere((r) => r.url.path.endsWith('/funding/withdrawals')).body)['method'], 'ACH');
    expect(find.text(r'超过可提现金额 $0.00'), findsWidgets);
  });

  testWidgets('P-18：详情显示 DW 返回的购买力可用日与可提现日', (tester) async {
    await _phone(tester);
    await pumpApp(
      tester,
      backend: _backend(banks: [_bank]),
      storedToken: 'tok',
    );
    await _openDrawerItem(tester, 'drawer.history');
    expect(find.text('ACH 入金'), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);
    await tester.tap(find.byKey(const Key('p18.row.tr-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('p18.bpDate'))).data, '2026-11-23');
    expect(tester.widget<Text>(find.byKey(const Key('p18.wdDate'))).data, '2026-12-19');
    expect(find.text('Payroll ••6789'), findsOneWidget);
  });
}
