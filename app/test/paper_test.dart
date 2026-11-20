import 'package:finx_app/core/widgets/celebration.dart';
import 'package:finx_app/core/widgets/form_widgets.dart';
import 'package:finx_app/features/trading/domain/trading_mode.dart';
import 'package:finx_app/features/trading/domain/trading_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

Map<String, dynamic> _paperAccount({double cash = 100000, double reserved = 0, double posValue = 0}) => {
  'simulated': true,
  'initialCash': 100000,
  'cash': cash,
  'reservedCash': reserved,
  'buyingPower': cash - reserved,
  'positionsValue': posValue,
  'totalValue': cash + posValue,
  'totalPL': cash + posValue - 100000,
  'totalPLPct': (cash + posValue - 100000) / 1000,
  'resetAt': null,
  'updatedAt': '2026-11-20T15:00:00Z',
};

Map<String, dynamic> _paperOrder(String id, String status, {String type = 'MARKET', double? qty, double? amount, double? limit}) => {
  'orderId': id,
  'orderNo': null,
  'symbol': 'AAPL',
  'side': 'BUY',
  'orderType': type,
  'quantity': qty,
  'amount': amount,
  'limitPrice': limit,
  'timeInForce': 'DAY',
  'status': status,
  'filledQty': status == 'FILLED' ? 4.42 : null,
  'avgPrice': status == 'FILLED' ? 226.13 : null,
  'totalAmount': status == 'FILLED' ? 999.49 : null,
  'fees': 0,
  'rejectReason': null,
  'submittedAt': '2026-11-20T15:00:00Z',
  'updatedAt': '2026-11-20T15:00:00Z',
  'doneAt': status == 'FILLED' ? '2026-11-20T15:00:00Z' : null,
  'simulated': true,
};

/// 已登录；[opened] 控制实盘是否已开户（模拟盘不依赖开户）。
FakeBackend _backend({bool opened = true}) => FakeBackend()
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
    (_) => opened
        ? FakeBackend.ok({
            'accountId': 'a',
            'accountNo': 'TEST000001',
            'status': 'OPEN',
            'accountType': 'LIVE',
            'tradingType': 'CASH',
            'managementType': 'SELF',
          })
        : FakeBackend.err(409, 40901, '交易账户尚未开立'),
  )
  ..on(
    'GET /account/money',
    (_) => FakeBackend.ok({
      'cash': 1234.56,
      'settledCash': 1234.56,
      'buyingPower': 0,
      'cashAvailableForWithdrawal': 0,
      'unsettled': 0,
      'pendingDeposits': 0,
      'withheldForSeasoning': 0,
      'updatedAt': '2026-11-20T15:00:00Z',
    }),
  )
  ..on('GET /positions', (_) => FakeBackend.ok({'equityValue': 0, 'positions': []}))
  ..on('GET /paper/account', (_) => FakeBackend.ok(_paperAccount()))
  ..on('POST /paper/account/reset', (_) => FakeBackend.ok(_paperAccount()))
  ..on(
    'GET /paper/positions',
    (_) => FakeBackend.ok({
      'simulated': true,
      'updatedAt': '2026-11-20T15:00:00Z',
      'equityValue': 2261.3,
      'positions': [
        {
          'symbol': 'AAPL',
          'quantity': 10,
          'sellableQty': 8,
          'avgPrice': 200,
          'costBasis': 2000,
          'marketPrice': 226.13,
          'marketValue': 2261.3,
          'unrealizedPL': 261.3,
          'unrealizedDayPL': 10,
        },
      ],
    }),
  )
  ..on('POST /paper/orders', (_) => FakeBackend.ok({'orderId': 'p-1', 'status': 'FILLED'}))
  ..on('GET /paper/orders/p-1', (_) => FakeBackend.ok(_paperOrder('p-1', 'FILLED', amount: 1000)))
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
        for (var i = 0; i < 5; i++) {'t': '2026-11-20T14:0$i:00Z', 'o': 226.0, 'h': 226.5, 'l': 225.5, 'c': 226.0 + i * 0.1},
      ],
    }),
  );

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _push(WidgetTester tester, String loc) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(loc);
  await tester.pumpAndSettle();
}

Future<void> _toPaper(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byKey(const Key('mode.switch')), matching: find.text('模拟盘')));
  await tester.pumpAndSettle();
}

bool _hit(FakeBackend be, String method, String path) => be.requests.any((r) => r.method == method && r.url.path == '/api/v1$path');

void main() {
  group('限价单前置校验', () {
    test('限价', () {
      expect(parseLimitPrice('195'), 195);
      expect(parseLimitPrice('0.1234'), 0.1234);
      expect(parseLimitPrice('0'), isNull);
      expect(parseLimitPrice('195.123'), isNull, reason: r'$1 以上最多两位小数');
      expect(validateLimitOrder('', '', buy: true), ('请输入股数', '请输入限价'));
      expect(validateLimitOrder('1', '0', buy: true).$2, isNotNull);
      expect(validateLimitOrder('1000', '100.01', buy: true, buyingPower: 100000).$1, contains('超过可用资金'));
      expect(validateLimitOrder('10', '100', buy: true, buyingPower: 100000), (null, null));
      expect(validateLimitOrder('9', '300', buy: false, sellableQty: 8).$1, '超过可卖数量 8 股');
      expect(orderStatusLabel('NEW', limit: true), '挂单中');
      expect(orderStatusLabel('NEW'), '排队中');
    });
  });

  testWidgets('P-07：切换模拟盘只显示模拟账户（不混入 DW 资金），可一键重置；切回实盘恢复 DW 数据', (tester) async {
    await _phone(tester);
    final (be, _, _) = await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    expect(find.text(r'$1,234.56'), findsWidgets, reason: '实盘显示 DW 现金');
    expect(find.byKey(const Key('paper.banner')), findsNothing);

    await _toPaper(tester);
    expect(TradingMode.instance.paper, isTrue);
    expect(find.byKey(const Key('paper.banner')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('paper.total'))).data, r'$100,000.00');
    expect(tester.widget<Text>(find.byKey(const Key('paper.buyingPower'))).data, r'$100,000.00');
    expect(find.byKey(const Key('home.hero')), findsNothing, reason: '模拟模式不显示 DW 资产卡');
    expect(find.text(r'$1,234.56'), findsNothing, reason: 'DW 资金数字不得出现在模拟盘');
    expect(find.textContaining('DriveWealth'), findsNothing);

    await tester.tap(find.byKey(const Key('paper.reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('paper.reset.confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_hit(be, 'POST', '/paper/account/reset'), isTrue);
    expect(find.text('模拟账户已重置'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    await tester.tap(find.descendant(of: find.byKey(const Key('mode.switch')), matching: find.text('实盘')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paper.banner')), findsNothing);
    expect(find.byKey(const Key('home.hero')), findsOneWidget);
  });

  testWidgets('模拟盘：P-10 → P-19 市价买入，使用模拟资金，不调 DW 下单；结果页"模拟订单已成交"并庆祝', (tester) async {
    await _phone(tester);
    final (be, _, _) = await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _toPaper(tester);
    await _push(tester, '/market/AAPL');
    await tester.tap(find.byKey(const Key('p10.buy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paper.banner')).hitTestable(), findsOneWidget);
    expect(find.byKey(const Key('paper.badge')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('p19.buyingPower'))).data, r'$100,000.00', reason: '模拟可用资金');

    await tester.enterText(find.byKey(const Key('p19.input')), '1000');
    await tester.tap(find.byKey(const Key('p19.next')));
    await tester.pumpAndSettle();
    expect(find.text('模拟盘（虚拟资金）'), findsOneWidget);
    expect(find.text(paperPriceNotice), findsOneWidget);
    expect(find.text(demoPriceNotice), findsNothing);

    await tester.tap(find.byKey(const Key('p19.submit')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(be.lastBody('POST /paper/orders'), {'symbol': 'AAPL', 'side': 'BUY', 'orderType': 'MARKET', 'amount': 1000});
    expect(_hit(be, 'POST', '/orders'), isFalse, reason: '模拟盘不走实盘下单');
    expect(_hit(be, 'GET', '/account/money'), isTrue, reason: '仅资产页实盘加载过');
    expect(find.text('模拟订单已成交'), findsOneWidget);
    expect(find.byType(ConfettiBurst), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('模拟盘限价单：限价 + 股数，冻结金额预估，挂单不庆祝，状态"挂单中"', (tester) async {
    await _phone(tester);
    final be = _backend()
      ..on('POST /paper/orders', (_) => FakeBackend.ok({'orderId': 'p-2', 'status': 'NEW'}))
      ..on('GET /paper/orders/p-2', (_) => FakeBackend.ok(_paperOrder('p-2', 'NEW', type: 'LIMIT', qty: 2, limit: 200)));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _push(tester, '/trade/AAPL?side=BUY&paper=1');
    await tester.tap(find.descendant(of: find.byKey(const Key('p19.type')), matching: find.text('限价')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('p19.mode')), findsNothing, reason: '限价单只按股数');

    await tester.enterText(find.byKey(const Key('p19.limitPrice')), '0');
    await tester.enterText(find.byKey(const Key('p19.input')), '2');
    await tester.tap(find.byKey(const Key('p19.next')));
    await tester.pumpAndSettle();
    expect(find.textContaining('限价须大于 0'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('p19.limitPrice')), '200');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('p19.estimate'))).data, r'$400.00', reason: '冻结金额按限价计算');
    await tester.tap(find.byKey(const Key('p19.next')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('p19.confirm.limit'))).data, r'$200.00');
    expect(find.text('限价单 · 当日有效'), findsOneWidget);
    await tester.tap(find.byKey(const Key('p19.submit')));
    await tester.pumpAndSettle();
    expect(be.lastBody('POST /paper/orders'), {
      'symbol': 'AAPL',
      'side': 'BUY',
      'orderType': 'LIMIT',
      'quantity': 2,
      'limitPrice': 200,
      'timeInForce': 'DAY',
    });
    expect(find.text('模拟限价单已挂单'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('p19.result.status'))).data, '挂单中');
    expect(find.byType(ConfettiBurst), findsNothing);
  });

  testWidgets('实盘下单页：显示"市价 / 限价"切换，无模拟盘横幅', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _push(tester, '/trade/AAPL');
    expect(find.byKey(const Key('p19.input')), findsOneWidget);
    expect(find.byKey(const Key('p19.type')), TradingFeatures.realLimitOrders ? findsOneWidget : findsNothing);
    expect(find.byKey(const Key('paper.banner')), findsNothing);
  });

  testWidgets('未开户：P-19 可一键切换到模拟盘练习', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(opened: false), storedToken: 'tok');
    await _push(tester, '/trade/AAPL');
    expect(find.text('开户后即可交易'), findsOneWidget);
    await tester.tap(find.byKey(const Key('p19.toPaper')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paper.banner')).hitTestable(), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('p19.buyingPower'))).data, r'$100,000.00');
  });

  testWidgets('P-11 模拟订单：横幅、限价描述、撤销挂单走 /paper', (tester) async {
    await _phone(tester);
    var cancelled = false;
    final be = _backend()
      ..on(
        'GET /paper/orders',
        (_) => FakeBackend.ok([
          _paperOrder('p-2', cancelled ? 'CANCELED' : 'NEW', type: 'LIMIT', qty: 2, limit: 200),
          _paperOrder('p-1', 'FILLED', amount: 1000),
        ]),
      )
      ..on('POST /paper/orders/p-2/cancel', (_) {
        cancelled = true;
        return FakeBackend.ok({'orderId': 'p-2', 'status': 'CANCELED'});
      });
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _toPaper(tester);
    await tester.tap(find.byKey(const Key('home.paper.orders')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('paper.banner')).hitTestable(), findsOneWidget);
    expect(tester.widget<StatusBadge>(find.byKey(const Key('p11.status.p-2'))).label, '挂单中');
    expect(tester.widget<Text>(find.byKey(const Key('p11.order.desc.p-2'))).data, r'限价 $200.00 · 2 股 · 当日有效');
    await tester.tap(find.byKey(const Key('p11.cancel.p-2')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('p11.cancel.confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_hit(be, 'POST', '/paper/orders/p-2/cancel'), isTrue);
    expect(_hit(be, 'POST', '/orders/p-2/cancel'), isFalse);
    expect(tester.widget<StatusBadge>(find.byKey(const Key('p11.status.p-2'))).label, '已撤单');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('P-12 模拟持仓：横幅与模拟估值', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _toPaper(tester);
    await tester.tap(find.byKey(const Key('home.paper.positions')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paper.banner')).hitTestable(), findsOneWidget);
    expect(find.text('模拟持仓'), findsWidgets);
    expect(tester.widget<Text>(find.byKey(const Key('p12.equity'))).data, r'$2,261.30');
    expect(tester.widget<Text>(find.byKey(const Key('p12.pl.AAPL'))).data, r'+$261.30  +13.07%');
    expect(find.textContaining('DriveWealth'), findsNothing);
  });
}
