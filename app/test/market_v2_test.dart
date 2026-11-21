import 'package:finx_app/features/market/domain/sentiment.dart';
import 'package:finx_app/features/market/domain/instruments.dart';
import 'package:finx_app/features/market/presentation/market_page.dart';
import 'package:finx_app/features/market/presentation/search_page.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// F22-b：P-09 市场页（定稿 v3/market_v2）——指数渐变卡、市场统计、内部人交易（演示数据）、搜索页。
// 恐慌贪婪 UI 已移除；接口与档位映射（domain）保留。

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

Future<void> _openMarket(WidgetTester tester, FakeBackend be) async {
  await _phone(tester);
  await pumpApp(tester, backend: be, storedToken: 'tok');
  await tester.tap(find.byKey(const Key('tab.market')));
  await tester.pumpAndSettle();
}

void main() {
  group('恐慌贪婪档位映射', () {
    for (final (v, label) in [
      (0, '极度恐慌'),
      (24, '极度恐慌'),
      (25, '恐慌'),
      (44, '恐慌'),
      (45, '中性'),
      (55, '中性'),
      (56, '贪婪'),
      (62, '贪婪'),
      (75, '贪婪'),
      (76, '极度贪婪'),
      (100, '极度贪婪'),
      (-5, '极度恐慌'),
      (130, '极度贪婪'),
    ]) {
      test('$v → $label', () => expect(FearGreedLevel.of(v).label, label));
    }
  });

  test('涨跌家数比例条权重', () {
    const b = Breadth(up: 18, down: 9, flat: 3);
    expect(b.total, 30);
    expect(b.flexes, (18, 3, 9));
    expect(const Breadth(up: 0, down: 0, flat: 0).flexes, (1, 1, 1));
  });

  test('搜索：代码精确 > 前缀 > 包含 > 名称；不区分大小写；空串返回全部股票与 ETF', () {
    expect([for (final i in searchInstruments('aapl')) i.symbol], ['AAPL']);
    expect(searchInstruments('A').first.symbol, 'AAPL', reason: '前缀匹配优先');
    expect([for (final i in searchInstruments('apple')) i.symbol], ['AAPL']);
    expect([for (final i in searchInstruments('gold')) i.symbol], contains('GLD'));
    expect(searchInstruments('zzzz'), isEmpty);
    expect(searchInstruments('').length, instruments.where((i) => i.type == 'STOCK' || i.type == 'ETF').length);
    expect(searchInstruments('').any((i) => i.symbol == 'BTC'), isFalse, reason: '加密标的仅用于预测，不在搜索范围');
  });

  test('迷你走势平滑：60 根分时按段均值为 24 点；不足 24 点原样', () {
    final v = [for (var i = 0; i < 60; i++) i.toDouble()];
    final s = smoothSpark(v);
    expect(s, hasLength(24));
    expect(s.first, closeTo(.5, 1e-9));
    expect(s.last, closeTo(58, 1e-9)); // 末段 57–59
    expect(smoothSpark([1, 2, 3]), [1, 2, 3]);
  });

  testWidgets('P-09 版式：美国市场纯文字标签 → QQQ / SPY / DIA 渐变卡 → 市场统计 → 内部人交易 → 涨幅榜；无 IWM、无恐慌贪婪', (tester) async {
    final be = _backend()
      ..on('GET /market/instruments/QQQ', (_) => FakeBackend.ok(_inst('QQQ')))
      ..on('GET /market/instruments/SPY', (_) => FakeBackend.ok(_inst('SPY')))
      ..on('GET /market/instruments/DIA', (_) => FakeBackend.ok(_inst('DIA')));
    await _openMarket(tester, be);
    final region = tester.widget<Text>(find.byKey(const Key('market.region')));
    expect(region.data, '美国市场');
    expect(region.style?.decoration, anyOf(isNull, TextDecoration.none), reason: '无下划线');
    expect(indexSymbols, ['QQQ', 'SPY', 'DIA']);
    for (final s in indexSymbols) {
      expect(find.byKey(Key('market.index.$s')), findsOneWidget);
      expect(find.byKey(Key('market.index.$s.spark')), findsOneWidget, reason: '$s 迷你走势');
    }
    expect(find.byKey(const Key('market.index.IWM')), findsNothing);
    expect(find.byKey(const Key('market.sentiment')), findsNothing);
    expect(find.text('市场情绪'), findsNothing);
    expect(be.requests.any((r) => r.url.path.endsWith('/market/sentiment')), isFalse, reason: 'UI 移除后不再轮询（接口保留）');
    double y(Finder f) => tester.getTopLeft(f).dy;
    expect(y(find.byKey(const Key('market.index.QQQ'))), lessThan(y(find.byKey(const Key('market.stats')))));
    await tester.scrollUntilVisible(find.text('涨幅榜'), 200, scrollable: find.byType(Scrollable).first);
    expect(y(find.byKey(const Key('market.stats'))), lessThan(y(find.byKey(const Key('market.insider.topBuy')))));
    expect(y(find.byKey(const Key('market.insider.topBuy'))), lessThan(y(find.text('涨幅榜'))));
  });

  testWidgets('市场统计：9 档柱数与比例条；今日 / 近 30 日切换；30 日不足显示"数据积累中"', (tester) async {
    final be = _backend()..on('GET /market/stats', fakeStats(since: '2026-11-20'));
    await _openMarket(tester, be);
    expect(find.descendant(of: find.byKey(const Key('market.stats.bar.5')), matching: find.text('6')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('market.stats.down'))).data, '下跌 11');
    expect(tester.widget<Text>(find.byKey(const Key('market.stats.up'))).data, '上涨 11');
    expect(tester.widget<Expanded>(find.byKey(const Key('market.stats.ratio.flat'))).flex, 2);
    for (final k in ['down', 'flat', 'up']) {
      expect(tester.getSize(find.byKey(Key('market.stats.ratio.$k'))).height, 7, reason: '比例条 $k 段可见（有高度）');
    }
    await tester.tap(find.byKey(const Key('market.stats.30D')));
    await tester.pumpAndSettle();
    expect(be.requests.any((r) => r.url.path.endsWith('/market/stats') && r.url.queryParameters['period'] == '30D'), isTrue);
    expect(find.byKey(const Key('market.stats.building')), findsOneWidget);
    expect(find.text('数据积累中 · 自 2026-11-20 起记录'), findsOneWidget);
    expect(find.byKey(const Key('market.stats.bar.0')), findsNothing);
    be.on('GET /market/stats', fakeStats(counts30: const [0, 0, 1, 2, 0, 3, 1, 0, 0]));
    await tester.tap(find.byKey(const Key('market.stats.TODAY')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market.stats.30D')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('market.stats.up'))).data, '上涨 4');
    expect(find.byKey(const Key('market.stats.ratio.flat')), findsNothing, reason: '无平盘时不画平盘段');
  });

  testWidgets('内部人交易：演示数据角标、三卡、> 轻提示；点卡进个股页', (tester) async {
    await _openMarket(tester, _backend());
    await tester.scrollUntilVisible(find.byKey(const Key('market.insider.topBuy')), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('market.insiders.demo')), findsOneWidget);
    expect(find.text('买入 \$6.2B'), findsOneWidget);
    expect(find.text('卖出 \$1.8B'), findsOneWidget);
    expect(find.text('交易 64 次'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 250)); // 标题回到 AppBar 下方
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market.insiders.more')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('内部人交易明细即将上线'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.ensureVisible(find.byKey(const Key('market.insider.topBuy')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('market.insider.topBuy')));
    await tester.pumpAndSettle();
    expect(GoRouter.of(tester.element(find.byType(Scaffold).last)).state.matchedLocation, '/market/NVDA');
  });

  testWidgets('搜索入口 → 搜索页：输入过滤，点击进入个股页；无结果提示', (tester) async {
    await _openMarket(tester, _backend());
    await tester.tap(find.byKey(const Key('market.search')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search.input')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search.input')), 'nflx');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search.hit.NFLX')), findsOneWidget);
    expect(find.byKey(const Key('search.hit.AAPL')), findsNothing);
    await tester.enterText(find.byKey(const Key('search.input')), 'qqqqqq');
    await tester.pumpAndSettle();
    expect(find.text('未找到相关标的'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search.input')), 'spy');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('search.hit.SPY')));
    await tester.pumpAndSettle();
    expect(GoRouter.of(tester.element(find.byType(Scaffold).last)).state.matchedLocation, '/market/SPY');
  });

  testWidgets('统计接口失败：卡内提示，不影响指数卡与榜单', (tester) async {
    final be = _backend()..on('GET /market/stats', (_) => FakeBackend.err(500, 50001, '暂不可用'));
    await _openMarket(tester, be);
    expect(find.byKey(const Key('market.index.SPY')), findsOneWidget);
    expect(find.byKey(const Key('market.stats.bar.0')), findsNothing);
    expect(find.textContaining('暂不可用'), findsNothing);
  });
}

Map<String, dynamic> _inst(String s) => {
  'simulated': true,
  'symbol': s,
  'name': s,
  'exchange': 'NYSE Arca',
  'type': 'ETF',
  'last': 500.0,
  'chg': 1.0,
  'chgPct': 0.2,
  'dayHigh': 501.0,
  'dayLow': 499.0,
  'prevClose': 499.0,
  'candles': [
    for (var i = 0; i < 5; i++) {'t': '2026-11-21T15:0$i:00Z', 'o': 500.0, 'h': 501.0, 'l': 499.0, 'c': 500.0 + i},
  ],
};
