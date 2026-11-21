import 'dart:convert';

import 'package:finx_app/core/api/api_client.dart';
import 'package:finx_app/core/widgets/celebration.dart';
import 'package:finx_app/features/funding/domain/funding_rules.dart';
import 'package:finx_app/features/trading/data/trading_api.dart';
import 'package:finx_app/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

FakeBackend _backend({
  List<Map<String, dynamic>> banks = const [],
  double withdrawable = 0,
}) {
  final bankList = [...banks];
  return FakeBackend()
    ..on(
      'GET /me',
      (_) => FakeBackend.ok({
        'email': 'demo@example.com',
        'loginProvider': 'EMAIL',
        'applicationId': 'app-1',
        'accountStatus': 'APPROVED',
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
    ..on(
      'POST /funding/deposits',
      (_) => FakeBackend.ok({'transferId': 'tr-1', 'status': 'PENDING'}),
    )
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
    scrollable: find
        .descendant(of: find.byType(Drawer), matching: find.byType(Scrollable))
        .first,
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
    final (be, _, _) = await pumpApp(
      tester,
      backend: _backend(),
      storedToken: 'tok',
    );
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
    await tester.enterText(
      find.byKey(const Key('p32.account')),
      '000123456789',
    );
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
    expect(
      tester.widget<Text>(find.byKey(const Key('p13.confirm.amount'))).data,
      r'$1,000.00',
    );
    await tester.tap(find.byKey(const Key('p13.submit')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // 逐帧推进：pumpAndSettle 会把 2 秒庆祝动画跑完
    }
    expect(be.lastBody('POST /funding/deposits'), {
      'bankAccountId': 'bank-1',
      'amount': 1000,
    });
    expect(find.text('入金已提交'), findsWidgets);
    expect(find.text('tr-1'), findsOneWidget);
    // 入金提交成功：轻量版庆祝
    expect(find.byType(ConfettiBurst), findsOneWidget);
    expect(
      tester.widget<ConfettiBurst>(find.byType(ConfettiBurst)).level,
      CelebrationLevel.light,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConfettiBurst), findsNothing);
  });

  testWidgets('P-13：券商结果不明（50001 附 transferId）显示"已记录"，不报错', (tester) async {
    await _phone(tester);
    final be = _backend(banks: [_bank])
      ..on(
        'POST /funding/deposits',
        (_) => FakeBackend.err(502, 50001, '券商暂时无法处理', {'transferId': 'tr-9'}),
      );
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

  testWidgets(
    'P-13：网络超时 → 提示"确认中"而非"稍后重试"；再次提交沿用同一幂等键；成功后下一笔换新键（审计 FUND-P0-1）',
    (tester) async {
      await _phone(tester);
      var n = 0;
      final be = _backend(banks: [_bank])
        ..on('POST /funding/deposits', (_) {
          n++;
          if (n == 1) throw http.ClientException('timeout'); // 首次：网络中断，结果不明
          return FakeBackend.ok({'transferId': 'tr-7', 'status': 'PENDING'});
        });
      await pumpApp(tester, backend: be, storedToken: 'tok');
      await _openDrawerItem(tester, 'drawer.deposit');
      await tester.tap(find.byKey(const Key('p13.ach')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('p13.amount')), '20');
      await tester.tap(find.byKey(const Key('p13.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('p13.submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('提交结果确认中'), findsOneWidget);
      expect(find.textContaining('稍后重试'), findsNothing);
      await tester.tap(find.byKey(const Key('p13.submit')));
      await tester.pumpAndSettle();
      final keys = [
        for (final r in be.requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/funding/deposits'),
        ))
          r.headers['Idempotency-Key'],
      ];
      expect(keys, hasLength(2));
      expect(
        keys[0],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(keys[1], keys[0], reason: '结果不明后的重试必须是同一笔申请');
      expect(find.text('tr-7'), findsOneWidget);
    },
  );

  test('下单：实盘带 Idempotency-Key 且超时提示"确认中"；模拟盘不带（审计 FUND-P0-1）', () async {
    debugSetLocale(const Locale('zh'));
    var fail = true;
    final be = FakeBackend()
      ..on('POST /orders', (_) {
        if (fail) throw http.ClientException('timeout');
        return FakeBackend.ok({'orderId': 'o-1', 'status': 'NEW'});
      })
      ..on(
        'POST /paper/orders',
        (_) => FakeBackend.ok({'orderId': 'p-1', 'status': 'FILLED'}),
      );
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      httpClient: be.client,
    );
    final live = TradingApi(client);
    await expectLater(
      live.place(
        symbol: 'AAPL',
        side: 'BUY',
        amount: 100,
        idempotencyKey: 'k-1',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('订单结果确认中'),
        ),
      ),
    );
    fail = false;
    await live.place(
      symbol: 'AAPL',
      side: 'BUY',
      amount: 100,
      idempotencyKey: 'k-1',
    );
    final heads = [
      for (final r in be.requests.where(
        (r) => r.url.path.endsWith('/api/v1/orders'),
      ))
        r.headers['Idempotency-Key'],
    ];
    expect(heads, ['k-1', 'k-1']);
    await TradingApi(
      client,
      paper: true,
    ).place(symbol: 'AAPL', side: 'BUY', amount: 100);
    expect(be.requests.last.headers.containsKey('Idempotency-Key'), isFalse);
  });

  test('SubmitKey：内容不变沿用；内容变化、明确结果后换新；超时保留', () {
    final k = SubmitKey();
    final a = k.forRequest('bank|20');
    expect(k.forRequest('bank|20'), a);
    expect(k.forRequest('bank|30'), isNot(a), reason: '金额变化是另一笔申请');
    final b = k.forRequest('bank|30');
    k.settle(ApiException(code: ApiCodes.network, message: 'timeout'));
    expect(k.forRequest('bank|30'), b, reason: '超时：结果不明，保留');
    k.settle(ApiException(code: ApiCodes.validation, message: 'x'));
    expect(k.forRequest('bank|30'), isNot(b), reason: '明确结果后换新键');
  });

  testWidgets('P-14：可提现为 0 时拦截；服务端 42201 显示限额信息', (tester) async {
    await _phone(tester);
    final be = _backend(banks: [_bank], withdrawable: 0);
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _openDrawerItem(tester, 'drawer.withdraw');
    expect(
      tester.widget<Text>(find.byKey(const Key('p14.withdrawable'))).data,
      r'$0.00',
    );
    await tester.enterText(find.byKey(const Key('p14.amount')), '10');
    await tester.tap(find.byKey(const Key('p14.next')));
    await tester.pumpAndSettle();
    expect(find.text(r'超过可提现金额 $0.00'), findsOneWidget);
    expect(
      be.requests.where((r) => r.url.path.endsWith('/funding/withdrawals')),
      isEmpty,
    );
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
    expect(
      jsonDecode(
        be.requests
            .lastWhere((r) => r.url.path.endsWith('/funding/withdrawals'))
            .body,
      )['method'],
      'ACH',
    );
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
    expect(
      tester.widget<Text>(find.byKey(const Key('p18.bpDate'))).data,
      '2026-11-23',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('p18.wdDate'))).data,
      '2026-12-19',
    );
    expect(find.text('Payroll ••6789'), findsOneWidget);
  });

  testWidgets('P-18：券商结果待人工核对（UNCONFIRMED）显示"未确认"与说明，不显示为失败原因（审计 FUND-P1-4）', (
    tester,
  ) async {
    await _phone(tester);
    final be = _backend(banks: [_bank])
      ..on(
        'GET /funding/transfers',
        (_) => FakeBackend.ok([
          {
            'transferId': 'tr-u',
            'type': 'WITHDRAWAL',
            'method': 'ACH',
            'amount': 50,
            'status': 'UNCONFIRMED',
            'failureReason': '对账重放被券商拒绝（E031），待人工核对',
            'submittedAt': '2026-11-19T12:00:00Z',
            'doneAt': null,
            'bankAccountId': 'bank-1',
            'buyingPowerAvailableAt': null,
            'withdrawableAt': null,
          },
        ]),
      );
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _openDrawerItem(tester, 'drawer.history');
    expect(find.text('未确认'), findsOneWidget);
    await tester.tap(find.byKey(const Key('p18.row.tr-u')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('p18.unconfirmed')), findsOneWidget);
    expect(find.textContaining('请勿重复提交'), findsOneWidget);
    expect(find.textContaining('E031'), findsNothing, reason: '内部核对原因不展示给用户');
  });

  testWidgets('P-14：ACH 出金成功 → 结果页显示"出金已提交"、金额与 transferId，带幂等键（审计 3.3 覆盖空白）', (
    tester,
  ) async {
    await _phone(tester);
    final be = _backend(banks: [_bank], withdrawable: 500)
      ..on(
        'POST /funding/withdrawals',
        (_) => FakeBackend.ok({'transferId': 'tr-w1', 'status': 'PENDING'}),
      );
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _openDrawerItem(tester, 'drawer.withdraw');
    await tester.enterText(find.byKey(const Key('p14.amount')), '120.50');
    await tester.tap(find.byKey(const Key('p14.next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('p14.submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('funding.result')), findsOneWidget);
    expect(find.text('出金已提交'), findsWidgets);
    expect(find.text('tr-w1'), findsOneWidget);
    expect(find.textContaining(r'$120.50'), findsWidgets);
    final req = be.requests.lastWhere(
      (r) => r.url.path.endsWith('/funding/withdrawals'),
    );
    expect(jsonDecode(req.body), {
      'method': 'ACH',
      'bankAccountId': 'bank-1',
      'amount': 120.5,
    });
    expect(req.headers['Idempotency-Key'], isNotNull);
  });

  for (final (code, body, want) in [
    (
      42200,
      {
        'fields': [
          {'field': 'amount', 'reason': '金额格式不正确（最多两位小数）'},
        ],
      },
      '金额格式不正确（最多两位小数）',
    ),
    (
      42201,
      {
        'limits': {'remainingToday': '5.00'},
      },
      r'超过每日入金限额 $60000.00，今日还可入金 $5.00',
    ),
  ]) {
    testWidgets('P-13：服务端 $code → 退回填写页并回填到金额输入框（审计 3.3 覆盖空白）', (tester) async {
      await _phone(tester);
      final be = _backend(banks: [_bank])
        ..on(
          'POST /funding/deposits',
          (_) => FakeBackend.err(
            422,
            code,
            code == 42201 ? want : '请检查标红的字段',
            body,
          ),
        );
      await pumpApp(tester, backend: be, storedToken: 'tok');
      await _openDrawerItem(tester, 'drawer.deposit');
      await tester.tap(find.byKey(const Key('p13.ach')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('p13.amount')), '20');
      await tester.tap(find.byKey(const Key('p13.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('p13.submit')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('p13.amount')),
        findsOneWidget,
        reason: '$code 应退回填写页',
      );
      expect(find.text(want), findsWidgets, reason: '$code 错误应显示在金额输入框');
      expect(find.byKey(const Key('funding.result')), findsNothing);
    });
  }

  testWidgets('P-13：限额与观察期取自后端 GET /funding/limits，不写死（审计 DOC-P1-4/P1-5）', (tester) async {
    await _phone(tester);
    final be = _backend(banks: [_bank])
      ..on(
        'GET /funding/limits',
        (_) => FakeBackend.ok({
          'minDeposit': 25,
          'maxDeposit': 2000,
          'dailyDeposit': 3000,
          'minWithdrawal': 1,
          'maxWithdrawal': 2000,
          'minWire': 100,
          'maxBanks': 2,
          'achCutoffET': '16:00',
          'wireCutoffET': '15:00',
          'seasoningDays': 5,
          'seasoningStart': 'CLEARED',
        }),
      );
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _openDrawerItem(tester, 'drawer.deposit');
    await tester.tap(find.byKey(const Key('p13.ach')));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 天观察期'), findsWidgets, reason: '观察期天数来自后端');
    await tester.enterText(find.byKey(const Key('p13.amount')), '20');
    await tester.tap(find.byKey(const Key('p13.next')));
    await tester.pumpAndSettle();
    expect(find.text(r'单笔最低入金 $25.00'), findsWidgets, reason: '最低入金来自后端');
    expect(be.requests.where((r) => r.url.path.endsWith('/funding/deposits')), isEmpty);
  });
}

