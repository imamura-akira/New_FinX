import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

FakeBackend _backend() => FakeBackend()
  ..on(
    'GET /me',
    (_) => FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': null, 'accountStatus': 'NONE'}),
  );

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(Key('tab.$label')));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
double _left(WidgetTester tester, String key) => tester.getTopLeft(find.byKey(Key(key))).dx;

void main() {
  testWidgets('P-23 股票大师：按收益排序、切换最近更新、个股机会筛选，底部标注演示数据', (tester) async {
    await _phone(tester);
    final (be, _, _) = await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _tab(tester, '股票大师');
    expect(find.text('看看大机构在买什么'), findsOneWidget);
    // 收益最高：晨湾资管（+21.30%）排第一，北岸资本第二
    expect(find.text('+21.30%'), findsOneWidget);
    expect(_left(tester, 'p23.inst.i4'), lessThan(_left(tester, 'p23.inst.i1')));
    expect(find.byKey(const Key('p23.inst.i7')), findsNothing, reason: '收益最低的松林全球不在前 6');

    await tester.tap(find.text('最近更新'));
    await tester.pumpAndSettle();
    expect(_top(tester, 'p23.inst.i1'), lessThan(_top(tester, 'p23.inst.i4')), reason: '11-16 更新的排在第一行，11-15 的在第二行');

    await _scrollTo(tester, find.byKey(const Key('p23.filter.CONTRA')));
    expect(find.byKey(const Key('p23.opp.NVDA')), findsOneWidget);
    await tester.tap(find.byKey(const Key('p23.filter.CONTRA')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('p23.opp.AMD')), findsOneWidget);
    expect(find.byKey(const Key('p23.opp.NVDA')), findsNothing);
    // 最新价来自虚拟行情接口（不新增后端接口）
    expect(
      be.requests.any((r) => r.url.path.endsWith('/market/quotes') && (r.url.queryParameters['symbols'] ?? '').contains('AMD')),
      isTrue,
    );

    await _scrollTo(tester, find.byKey(const Key('demo.note')));
    expect(find.textContaining('演示数据'), findsWidgets);
  });

  testWidgets('P-24：全部机构按收益排序；机构详情显示前五大持仓', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _tab(tester, '股票大师');
    await tester.tap(find.byKey(const Key('p23.more')));
    await tester.pumpAndSettle();
    expect(find.text('全部机构'), findsOneWidget);
    await tester.tap(find.byKey(const Key('p24.sort.ret')));
    await tester.pumpAndSettle();
    expect(_top(tester, 'p24.row.i4'), lessThan(_top(tester, 'p24.row.i1')));
    expect(_top(tester, 'p24.row.i1'), lessThan(_top(tester, 'p24.row.i7')));

    await tester.tap(find.byKey(const Key('p24.row.i1')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('p24.name'))).data, '北岸资本');
    expect(find.text('前五大持仓（示例）'), findsOneWidget);
    for (final s in ['AAPL', 'MSFT']) {
      expect(find.byKey(Key('quote.$s')), findsOneWidget);
    }
  });

  testWidgets('P-26 Fifi：六个功能卡，点击提示即将上线；保留合规提示', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _tab(tester, 'Fifi');
    expect(find.textContaining('首期不做，待合规评估'), findsOneWidget);
    for (var k = 0; k < 6; k++) {
      await _scrollTo(tester, find.byKey(Key('p26.feat.$k')));
      expect(find.byKey(Key('p26.feat.$k')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('p26.feat.0')));
    await tester.pump();
    expect(find.text('持仓体检即将上线'), findsOneWidget);
  });

  testWidgets('P-27 奖励：等级切换显示对应商品，兑换提示即将上线', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _tab(tester, '奖励');
    expect(find.text('0 XP'), findsOneWidget);
    expect(find.byKey(const Key('p27.item.新手徽章')), findsOneWidget);
    await tester.tap(find.byKey(const Key('p27.level.2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('p27.item.高级图表主题')), findsOneWidget);
    expect(find.byKey(const Key('p27.item.新手徽章')), findsNothing);
    await tester.tap(find.byKey(const Key('p27.item.高级图表主题')));
    await tester.pump();
    expect(find.text('兑换即将上线'), findsOneWidget);
  });
}
