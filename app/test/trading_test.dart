import 'package:finx_app/core/widgets/celebration.dart';
import 'package:finx_app/core/widgets/form_widgets.dart';
import 'package:finx_app/features/trading/domain/trading_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

Map<String, dynamic> _order(String id, String status, {double? amount, double? qty, String side = 'BUY', double? filled, double? avg}) => {
  'orderId': id,
  'orderNo': 'FEAB00000${id.substring(id.length - 1)}',
  'symbol': 'AAPL',
  'side': side,
  'orderType': 'MARKET',
  'quantity': qty,
  'amount': amount,
  'status': status,
  'filledQty': filled,
  'avgPrice': avg,
  'totalAmount': filled == null || avg == null ? null : filled * avg,
  'fees': 0,
  'rejectReason': status == 'REJECTED' ? '购买力不足，券商已拒绝该订单' : null,
  'submittedAt': '2026-11-23T15:00:00Z',
  'updatedAt': '2026-11-23T15:00:01Z',
  'doneAt': status == 'FILLED' ? '2026-11-23T15:00:01Z' : null,
};

FakeBackend _backend({double buyingPower = 500, String accountStatus = 'OPEN', bool opened = true}) => FakeBackend()
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
      'accountStatus': opened ? accountStatus : null,
      'accountNo': opened ? 'TEST000001' : null,
      'applicationRef': 'FX-1',
      'submittedAt': '2026-11-19T12:00:00Z',
      'submitState': 'SUBMITTED',
    }),
  )
  ..on(
    'GET /account',
    (_) => opened
        ? FakeBackend.ok({
            'accountId': 'a',
            'accountNo': 'TEST000001',
            'status': accountStatus,
            'accountType': 'LIVE',
            'tradingType': 'CASH',
            'managementType': 'SELF',
          })
        : FakeBackend.err(409, 40901, '交易账户尚未开立'),
  )
  ..on(
    'GET /account/money',
    (_) => FakeBackend.ok({
      'cash': 1000,
      'settledCash': 1000,
      'buyingPower': buyingPower,
      'cashAvailableForWithdrawal': 0,
      'unsettled': 0,
      'pendingDeposits': 0,
      'withheldForSeasoning': 0,
      'updatedAt': '2026-11-23T15:00:00Z',
    }),
  )
  ..on(
    'GET /positions',
    (_) => FakeBackend.ok({
      'updatedAt': '2026-11-23T15:00:00Z',
      'equityValue': 1260,
      'positions': [
        {
          'symbol': 'AAPL',
          'quantity': 10.5,
          'sellableQty': 8.25,
          'avgPrice': 100,
          'costBasis': 1050,
          'marketPrice': 120,
          'marketValue': 1260,
          'unrealizedPL': 210,
          'unrealizedDayPL': -5.5,
        },
      ],
    }),
  )
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
  )
  ..on('POST /orders', (_) => FakeBackend.ok({'orderId': 'ord-1', 'status': 'FILLED'}))
  ..on('GET /orders/ord-1', (_) => FakeBackend.ok(_order('ord-1', 'FILLED', amount: 100, filled: 0.442, avg: 226.13)));

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _go(WidgetTester tester, String loc) async {
  GoRouter.of(tester.element(find.byKey(const Key('home.hero')))).push(loc);
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('p19.next')));
  await tester.pumpAndSettle();
}

void main() {
  group('交易前置校验', () {
    test('按金额', () {
      expect(validateOrderAmount('', buy: true), '请输入金额');
      expect(validateOrderAmount('abc', buy: true), contains('有效金额'));
      expect(validateOrderAmount('0.99', buy: true), minOrderText);
      expect(validateOrderAmount('500.01', buy: true, buyingPower: 500), r'超过可用购买力 $500.00');
      expect(validateOrderAmount('500', buy: true, buyingPower: 500), isNull);
      expect(validateOrderAmount('990.01', buy: false, sellableValue: 990), r'超过可卖市值 $990.00');
      expect(validateOrderAmount('1', buy: false, sellableValue: 990), isNull);
    });
    test('按股数', () {
      expect(validateOrderQty('', buy: true), '请输入股数');
      expect(validateOrderQty('0.1234567', buy: true, price: 10), contains('6 位小数'));
      expect(validateOrderQty('0', buy: false, sellableQty: 1), '股数须大于 0');
      expect(validateOrderQty('1', buy: true), '暂无报价，请按金额买入');
      expect(validateOrderQty('0.001', buy: true, price: 200), minOrderText);
      expect(validateOrderQty('3', buy: true, price: 200, buyingPower: 500), contains('超过可用购买力'));
      expect(validateOrderQty('2.5', buy: true, price: 200, buyingPower: 500), isNull);
      expect(validateOrderQty('8.26', buy: false, sellableQty: 8.25), '超过可卖数量 8.25 股');
      expect(validateOrderQty('8.25', buy: false, sellableQty: 8.25), isNull);
    });
    test('股数显示', () {
      expect(fmtQty(10.5), '10.5');
      expect(fmtQty(3), '3');
      expect(fmtQty(0.1234564), '0.123456');
    });
  });

  testWidgets('P-10 → P-19 按金额买入：前置校验 → 确认页演示行情提示 → 结果页成交数据与轻量庆祝', (tester) async {
    await _phone(tester);
    final (be, _, _) = await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _go(tester, '/market/AAPL');
    await tester.tap(find.byKey(const Key('p10.buy')));
    await tester.pumpAndSettle();
    expect(find.text('买入 AAPL'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('p19.buyingPower'))).data, r'$500.00', reason: '购买力取 DW 返回值');

    // 低于单笔最低
    await tester.enterText(find.byKey(const Key('p19.input')), '0.5');
    await _next(tester);
    expect(find.text(minOrderText), findsOneWidget);
    // 超过购买力
    await tester.enterText(find.byKey(const Key('p19.input')), '600');
    await _next(tester);
    expect(find.text(r'超过可用购买力 $500.00'), findsOneWidget);
    expect(be.requests.where((r) => r.method == 'POST'), isEmpty, reason: '前置校验失败不下单');

    await tester.enterText(find.byKey(const Key('p19.input')), '100');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('p19.estimate'))).data, startsWith('约 0.44'), reason: '按演示参考价估算股数');
    await _next(tester);
    expect(find.text('确认订单'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('p19.confirm.size'))).data, r'$100.00');
    expect(find.text('显示价格为演示行情，实际成交以券商（DriveWealth）返回为准'), findsOneWidget);

    await tester.tap(find.byKey(const Key('p19.submit')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // 逐帧推进：pumpAndSettle 会把庆祝动画跑完
    }
    expect(be.lastBody('POST /orders'), {'symbol': 'AAPL', 'side': 'BUY', 'orderType': 'MARKET', 'amount': 100});
    expect(find.text('订单已成交'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('p19.result.status'))).data, '已成交');
    expect(tester.widget<Text>(find.byKey(const Key('p19.result.avgPrice'))).data, r'$226.13');
    expect(find.byType(ConfettiBurst), findsOneWidget);
    expect(tester.widget<ConfettiBurst>(find.byType(ConfettiBurst)).level, CelebrationLevel.light);
    await tester.pumpAndSettle();
    expect(find.byType(ConfettiBurst), findsNothing);
  });

  testWidgets('P-19 按股数卖出：不超过 DW 可卖数量，"全部卖出"填入可卖数量', (tester) async {
    await _phone(tester);
    final be = _backend()
      ..on('POST /orders', (_) => FakeBackend.ok({'orderId': 'ord-2', 'status': 'NEW'}))
      ..on('GET /orders/ord-2', (_) => FakeBackend.ok(_order('ord-2', 'NEW', qty: 8.25, side: 'SELL')));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _go(tester, '/trade/AAPL?side=SELL');
    expect(find.text('卖出 AAPL'), findsOneWidget);
    await tester.tap(find.text('按股数'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('p19.sellable'))).data, '8.25 股');
    await tester.enterText(find.byKey(const Key('p19.input')), '9');
    await _next(tester);
    expect(find.text('超过可卖数量 8.25 股'), findsOneWidget);

    await tester.tap(find.byKey(const Key('p19.sellAll')));
    await tester.pump();
    await _next(tester);
    await tester.tap(find.byKey(const Key('p19.submit')));
    await tester.pumpAndSettle();
    expect(be.lastBody('POST /orders'), {'symbol': 'AAPL', 'side': 'SELL', 'orderType': 'MARKET', 'quantity': 8.25});
    expect(find.text('订单已提交'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('p19.result.status'))).data, '排队中');
  });

  testWidgets('P-19 实盘限价单：冻结金额按限价校验购买力，提交 LIMIT + 限价 + 当日有效，挂单不庆祝', (tester) async {
    await _phone(tester);
    final be = _backend()
      ..on('POST /orders', (_) => FakeBackend.ok({'orderId': 'ord-5', 'status': 'NEW'}))
      ..on(
        'GET /orders/ord-5',
        (_) => FakeBackend.ok({
          ..._order('ord-5', 'NEW', qty: 2),
          'orderType': 'LIMIT',
          'limitPrice': 200,
          'timeInForce': 'DAY',
        }),
      );
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _go(tester, '/trade/AAPL');
    await tester.tap(find.descendant(of: find.byKey(const Key('p19.type')), matching: find.text('限价')));
    await tester.pumpAndSettle();
    // 冻结金额 3 × 200 = 600 超过 DW 购买力 500
    await tester.enterText(find.byKey(const Key('p19.limitPrice')), '200');
    await tester.enterText(find.byKey(const Key('p19.input')), '3');
    await _next(tester);
    expect(find.textContaining(r'超过可用资金 $500.00'), findsOneWidget);
    expect(be.requests.where((r) => r.method == 'POST'), isEmpty);

    await tester.enterText(find.byKey(const Key('p19.input')), '2');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('p19.estimate'))).data, r'$400.00');
    await _next(tester);
    expect(find.text('限价单 · 当日有效'), findsOneWidget);
    expect(find.text('显示价格为演示行情，实际成交以券商（DriveWealth）返回为准'), findsOneWidget);
    await tester.tap(find.byKey(const Key('p19.submit')));
    await tester.pumpAndSettle();
    expect(be.lastBody('POST /orders'), {
      'symbol': 'AAPL',
      'side': 'BUY',
      'orderType': 'LIMIT',
      'quantity': 2,
      'limitPrice': 200,
      'timeInForce': 'DAY',
    });
    expect(find.text('限价单已提交'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('p19.result.status'))).data, '挂单中');
    expect(find.byType(ConfettiBurst), findsNothing);
  });

  testWidgets('P-19：服务端 42201（以 DW 购买力为准）退回填写页显示限额', (tester) async {
    await _phone(tester);
    final be = _backend()..on('POST /orders', (_) => FakeBackend.err(422, 42201, r'超过可用购买力 $50.00', {'limits': {'buyingPower': '50.00'}}));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _go(tester, '/trade/AAPL');
    await tester.enterText(find.byKey(const Key('p19.input')), '100');
    await _next(tester);
    await tester.tap(find.byKey(const Key('p19.submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('p19.input')), findsOneWidget, reason: '回到填写页');
    expect(find.text(r'超过可用购买力 $50.00'), findsWidgets);
  });

  testWidgets('P-19：券商结果不明（50001 附 orderId）显示"已记录"，不庆祝', (tester) async {
    await _phone(tester);
    final be = _backend()..on('POST /orders', (_) => FakeBackend.err(502, 50001, '订单提交结果暂未确认', {'orderId': 'ord-9'}));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _go(tester, '/trade/AAPL');
    await tester.enterText(find.byKey(const Key('p19.input')), '100');
    await _next(tester);
    await tester.tap(find.byKey(const Key('p19.submit')));
    await tester.pumpAndSettle();
    expect(find.text('订单已记录'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('p19.result.status'))).data, '提交中');
    expect(find.byType(ConfettiBurst), findsNothing);
  });

  testWidgets('P-19：被券商拒绝显示中文原因，不庆祝', (tester) async {
    await _phone(tester);
    final be = _backend()
      ..on('POST /orders', (_) => FakeBackend.ok({'orderId': 'ord-3', 'status': 'REJECTED'}))
      ..on('GET /orders/ord-3', (_) => FakeBackend.ok(_order('ord-3', 'REJECTED', amount: 100)));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _go(tester, '/trade/AAPL');
    await tester.enterText(find.byKey(const Key('p19.input')), '100');
    await _next(tester);
    await tester.tap(find.byKey(const Key('p19.submit')));
    await tester.pumpAndSettle();
    expect(find.text('券商已拒绝该订单'), findsOneWidget);
    expect(find.text('购买力不足，券商已拒绝该订单'), findsOneWidget);
    expect(find.byType(ConfettiBurst), findsNothing);
  });

  testWidgets('P-19：仅可卖出账户买入被拦截', (tester) async {
    await _phone(tester);
    final (be, _, _) = await pumpApp(tester, backend: _backend(accountStatus: 'OPEN_NO_NEW_TRADES'), storedToken: 'tok');
    await _go(tester, '/trade/AAPL');
    expect(find.text('账户当前仅可卖出，暂不能买入。'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('p19.input')), '100');
    await tester.tap(find.byKey(const Key('p19.next')));
    await tester.pumpAndSettle();
    expect(find.text('确认订单'), findsNothing);
    expect(be.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('P-19：未开户显示开户提示', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(opened: false), storedToken: 'tok');
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/trade/AAPL');
    await tester.pumpAndSettle();
    expect(find.text('开户后即可交易'), findsOneWidget);
  });

  testWidgets('P-11：订单状态与成交价取 DW 返回；未成交订单二次确认后撤单', (tester) async {
    await _phone(tester);
    var cancelled = false;
    final be = _backend()
      ..on(
        'GET /orders',
        (_) => FakeBackend.ok([
          _order('ord-1', cancelled ? 'CANCELED' : 'NEW', amount: 100),
          _order('ord-2', 'FILLED', qty: 1, filled: 1, avg: 226.13),
          _order('ord-3', 'REJECTED', amount: 50),
        ]),
      )
      ..on('POST /orders/ord-1/cancel', (_) {
        cancelled = true;
        return FakeBackend.ok({'orderId': 'ord-1', 'status': 'CANCELED'});
      });
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await tester.scrollUntilVisible(find.byKey(const Key('home.orders')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('home.orders')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<StatusBadge>(find.byKey(const Key('p11.status.ord-1'))).label, '排队中');
    expect(tester.widget<StatusBadge>(find.byKey(const Key('p11.status.ord-2'))).label, '已成交');
    expect(tester.widget<Text>(find.byKey(const Key('p11.avgPrice.ord-2'))).data, r'$226.13');
    expect(find.text('购买力不足，券商已拒绝该订单'), findsOneWidget);
    expect(find.byKey(const Key('p11.cancel.ord-2')), findsNothing, reason: '已成交不可撤');

    await tester.tap(find.byKey(const Key('p11.cancel.ord-1')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('p11.cancel.confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(be.requests.where((r) => r.method == 'POST' && r.url.path.endsWith('/orders/ord-1/cancel')), hasLength(1));
    expect(find.text('订单已撤销'), findsOneWidget);
    expect(tester.widget<StatusBadge>(find.byKey(const Key('p11.status.ord-1'))).label, '已撤单');
    await tester.pump(const Duration(seconds: 3)); // 等提示消失
  });

  testWidgets('P-12：持仓数量、市值、成本、盈亏为 DW 返回值，只计算盈亏百分比', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await tester.scrollUntilVisible(find.byKey(const Key('home.positions')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('home.positions')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('p12.equity'))).data, r'$1,260.00');
    expect(tester.widget<Text>(find.byKey(const Key('p12.qty.AAPL'))).data, '10.5 股');
    expect(tester.widget<Text>(find.byKey(const Key('p12.mv.AAPL'))).data, r'$1,260.00');
    expect(tester.widget<Text>(find.byKey(const Key('p12.cost.AAPL'))).data, r'$1,050.00');
    expect(tester.widget<Text>(find.byKey(const Key('p12.pl.AAPL'))).data, r'+$210.00  +20.00%');
    expect(find.text('8.25 股'), findsOneWidget, reason: '可卖数量与持有数量不同时显示');
  });

  testWidgets('P-08：抽屉持仓市值取 DW equityValue', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await tester.tap(find.byKey(const Key('home.avatar')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('drawer.equity'))).data, r'$1,260.00');
  });
}
