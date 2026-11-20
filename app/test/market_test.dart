import 'package:finx_app/features/market/domain/instruments.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

FakeBackend _backend() => FakeBackend()
  ..on(
    'GET /me',
    (_) => FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': null, 'accountStatus': 'NONE'}),
  )
  ..on(
    'GET /market/instruments/NVDA',
    (_) => FakeBackend.ok({
      'simulated': true,
      'symbol': 'NVDA',
      'name': 'NVIDIA Corp.',
      'exchange': 'NASDAQ',
      'type': 'STOCK',
      'last': 132.1,
      'chg': 2.7,
      'chgPct': 2.1,
      'bid': 132.05,
      'ask': 132.15,
      'dayHigh': 133.0,
      'dayLow': 129.0,
      'prevClose': 129.4,
      'candles': [
        for (var i = 0; i < 10; i++) {'t': '2026-11-19T14:0$i:00Z', 'o': 130.0, 'h': 131.0, 'l': 129.0, 'c': 130.0 + i * 0.2},
      ],
    }),
  );

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

String _last(WidgetTester tester, String symbol) => tester.widget<Text>(find.byKey(Key('quote.$symbol.last'))).data!;

void main() {
  testWidgets('P-07 自选股显示虚拟行情并每 3 秒刷新', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await tester.scrollUntilVisible(find.byKey(const Key('quote.AAPL')), 200, scrollable: find.byType(Scrollable).first);
    final before = _last(tester, 'AAPL');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_last(tester, 'AAPL'), isNot(before), reason: '轮询后价格变化');
    expect(find.textContaining('演示数据：虚拟行情'), findsOneWidget);
  });

  testWidgets('P-09：涨幅榜按涨跌幅排序，跌幅为红色；ETF 分类筛选', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await tester.tap(find.byKey(const Key('tab.market')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market.index.SPY')), findsOneWidget);
    // 涨幅榜第一名是 NVDA（+2.10%）
    final rows = tester
        .widgetList<InkWell>(
          find.byWidgetPredicate((w) => w is InkWell && w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('quote.')),
        )
        .toList();
    expect((rows.first.key as ValueKey).value, 'quote.NVDA');
    expect(find.text('-0.62%'), findsWidgets);

    await tester.tap(find.text('ETF').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('债券'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quote.TLT')), findsOneWidget);
    expect(find.byKey(const Key('quote.GLD')), findsNothing);
  });

  testWidgets('P-10：个股详情、加入/移出自选', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await tester.tap(find.byKey(const Key('tab.market')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quote.NVDA')).first);
    await tester.pumpAndSettle();
    expect(find.text('NVIDIA Corp.'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('p10.last'))).data, '132.10');
    expect(find.byKey(const Key('p10.chart')), findsOneWidget);
    expect(find.text('129.37'), findsOneWidget, reason: '买一价来自批量报价接口');
    expect(find.byKey(const Key('p10.buy')), findsOneWidget, reason: 'F14：个股页提供买入 / 卖出入口');
    expect(find.byKey(const Key('p10.sell')), findsOneWidget);

    expect(Watchlist.instance.contains('NVDA'), isTrue);
    await tester.tap(find.byKey(const Key('p10.watch')));
    await tester.pump();
    expect(Watchlist.instance.contains('NVDA'), isFalse);
  });

  testWidgets('未登录：欢迎页"先逛逛行情"进入 P-09', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend());
    await tester.tap(find.byKey(const Key('welcome.market')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market.index.QQQ')), findsOneWidget);
  });
}
