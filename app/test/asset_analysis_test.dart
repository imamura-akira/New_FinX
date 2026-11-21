import 'package:finx_app/features/account/data/portfolio_api.dart';
import 'package:finx_app/core/amount_mask.dart';
import 'package:finx_app/features/account/presentation/asset_analysis.dart';
import 'package:finx_app/features/trading/data/trading_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// F17 / F22-a：P-07 资产页（渐变大卡 + 走势线、范围胶囊、眼睛、筛选环形图、自选）。

Map<String, dynamic> _alloc({double stock = 2944.45, double etf = 1962.96, double cash = 1635.80, bool simulated = false}) {
  final total = stock + etf + cash;
  double pct(double v) => total == 0 ? 0 : double.parse((v / total * 100).toStringAsFixed(1));
  return {
    'simulated': simulated,
    'total': total,
    'items': [
      {'type': 'STOCK', 'amount': stock, 'pct': pct(stock)},
      {'type': 'ETF', 'amount': etf, 'pct': pct(etf)},
      {'type': 'CASH', 'amount': cash, 'pct': pct(cash)},
    ],
    'updatedAt': '2026-11-20T15:00:00Z',
  };
}

Map<String, dynamic> _history(List<double> totals, {String range = '7D', bool simulated = false}) => {
  'simulated': simulated,
  'range': range,
  'points': [
    for (final (i, t) in totals.indexed)
      {'date': '2026-11-${(20 - totals.length + 1 + i).toString().padLeft(2, '0')}', 'total': t, 'cash': t, 'stock': 0, 'etf': 0},
  ],
};

/// [opened] 控制实盘是否已开户。
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
  ..on('GET /account/allocation', (_) => FakeBackend.ok(_alloc()))
  ..on('GET /account/history', (_) => FakeBackend.ok(_history([6400, 6420, 6480, 6460, 6510, 6530, 6543.21])))
  ..on(
    'GET /paper/account',
    (_) => FakeBackend.ok({
      'simulated': true,
      'initialCash': 100000,
      'cash': 98000,
      'reservedCash': 0,
      'buyingPower': 98000,
      'positionsValue': 1999.5,
      'totalValue': 99999.5,
      'totalPL': -0.5,
      'totalPLPct': 0,
      'resetAt': null,
      'updatedAt': '2026-11-20T15:00:00Z',
    }),
  )
  ..on('GET /paper/account/allocation', (_) => FakeBackend.ok(_alloc(stock: 1999.5, etf: 0, cash: 98000, simulated: true)))
  ..on('GET /paper/account/history', (_) => FakeBackend.ok(_history([99999.5], simulated: true)))
  ..on('GET /positions', (_) => FakeBackend.ok(_positions(const {'AAPL': 1000, 'NVDA': 1944.45, 'SPY': 1962.96})))
  ..on('GET /paper/positions', (_) => FakeBackend.ok(_positions(const {'TSLA': 1999.5})));

Map<String, dynamic> _pos(String sym, double v) => {
  'symbol': sym,
  'quantity': 1,
  'sellableQty': 1,
  'avgPrice': v,
  'costBasis': v,
  'marketPrice': v,
  'marketValue': v,
  'unrealizedPL': 0,
  'unrealizedDayPL': 0,
};

Map<String, dynamic> _positions(Map<String, double> m) => {
  'updatedAt': '2026-11-20T15:00:00Z',
  'positions': [for (final e in m.entries) _pos(e.key, e.value)],
};

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _scrollTo(WidgetTester tester, Finder f) =>
    tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  group('纯函数', () {
    test('"全部"：现金 / 股票 / ETF 定稿顺序，金额与占比取后端', () {
      final s = classSlices(Allocation.fromJson(_alloc()));
      expect([for (final x in s) (x.id, x.amount, x.pct)], [('CASH', 1635.80, 25.0), ('STOCK', 2944.45, 45.0), ('ETF', 1962.96, 30.0)]);
    });

    test('分布解析：缺项按 0', () {
      final a = Allocation.fromJson({
        'total': 10,
        'items': [
          {'type': 'CASH', 'amount': 10, 'pct': 100.0},
        ],
      });
      expect([for (final i in a.items) (i.kind, i.amount, i.pct)], [
        (AssetClass.stock, 0, 0),
        (AssetClass.etf, 0, 0),
        (AssetClass.cash, 10, 100),
      ]);
    });

    test('"股票" / "ETF"：按市值降序，前 5 个 + 其他；目录外代码按股票计；占比合计 100', () {
      List<Position> ps(Map<String, double> m) => [for (final e in m.entries) Position.fromJson(_pos(e.key, e.value))];
      final s = holdingSlices(ps({'AAPL': 10, 'MSFT': 60, 'NVDA': 50, 'TSLA': 40, 'META': 30, 'KO': 20, 'ZZZZ': 5, 'SPY': 999}), AllocFilter.stock);
      expect([for (final x in s) x.id], ['MSFT', 'NVDA', 'TSLA', 'META', 'KO', 'OTHER']);
      expect(s.last.amount, 15, reason: 'AAPL 10 + 目录外 ZZZZ 5');
      expect(s.fold<double>(0, (a, x) => a + x.pct), closeTo(100, 1e-9));
      final etf = holdingSlices(ps({'AAPL': 10, 'SPY': 30, 'QQQ': 10}), AllocFilter.etf);
      expect([for (final x in etf) (x.id, x.pct)], [('SPY', 75.0), ('QQQ', 25.0)]);
      expect(holdingSlices(ps({'AAPL': 10}), AllocFilter.etf), isEmpty);
    });

    test('大卡走势线坐标：最高值在上、最新点在最右；数值全相同时居中', () {
      const size = Size(200, 170);
      final pts = HeroTrendPainter.layout([100, 300, 200], size);
      expect(pts[1].dy, lessThan(pts[2].dy));
      expect(pts[2].dy, lessThan(pts[0].dy));
      expect(pts.last.dx, closeTo(186, 1e-9));
      final flat = HeroTrendPainter.layout([5, 5], size);
      expect(flat[0].dy, flat[1].dy);
    });

    test('涨跌幅格式：四舍五入为 0 时不显示 -0.00%', () {
      expect(signedPctForTest(-0.0016), ' (0.00%)');
      expect(signedPctForTest(-0.006), ' (-0.01%)');
      expect(signedPctForTest(0.65), ' (+0.65%)');
    });

    test('范围：1D / 1W / 3M / 1Y / YTD，1D 为日内', () {
      expect([for (final r in HistoryRange.values) r.code], ['1D', '1W', '3M', '1Y', 'YTD']);
      expect(HistoryRange.d1.intraday, isTrue);
    });
  });

  testWidgets('已开户：大卡（总资产 / 购买力 / 今日 + 走势线）→ 范围 → 筛选 → 环形图 → 自选；无可提现', (tester) async {
    await _phone(tester);
    final (be, _, _) = await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    // D-18：大卡"总资产"与环心同源同值，不是 DW 现金
    await _scrollTo(tester, find.byKey(const Key('p07.alloc')));
    expect(_text(tester, 'home.total'), r'$6,543.21');
    expect(_text(tester, 'p07.alloc.total'), _text(tester, 'home.total'));
    expect(_text(tester, 'home.buyingPower'), r'$1,635.80');
    expect(find.byKey(const Key('home.withdrawable')), findsNothing, reason: '可提现移出大卡');
    expect(find.byKey(const Key('p07.hero.trend')), findsOneWidget, reason: '默认 1D');
    expect(be.requests.any((r) => r.url.path == '/api/v1/account/history' && r.url.queryParameters['range'] == '1D'), isTrue);
    expect(_text(tester, 'p07.alloc.CASH.amount'), r'$1,635.80');
    expect(_text(tester, 'p07.alloc.STOCK.pct'), '45.0%');
    expect(_text(tester, 'p07.alloc.ETF.amount'), r'$1,962.96');
    expect(find.text('总价值'), findsOneWidget);
    expect(find.text('Portfolio'), findsNothing);
    double y(String k) => tester.getTopLeft(find.byKey(Key(k))).dy;
    expect(y('home.hero'), lessThan(y('p07.ranges')));
    expect(y('p07.ranges'), lessThan(y('p07.filter.all')));
    expect(y('p07.filter.all'), lessThan(y('p07.alloc')));
    await _scrollTo(tester, find.byKey(const Key('home.watchlist')));
    expect(y('p07.alloc'), lessThan(y('home.watchlist')));
    expect(find.descendant(of: find.byKey(const Key('home.watchlist')), matching: find.text('自选')), findsOneWidget);
    expect(find.text('实时报价 · 3 秒刷新'), findsOneWidget);
    // 切换范围：按 range 请求，已加载的区间不重复请求
    await _scrollTo(tester, find.byKey(const Key('p07.ranges')));
    await tester.tap(find.byKey(const Key('p07.range.1W')));
    await tester.pumpAndSettle();
    expect(be.requests.where((r) => r.url.queryParameters['range'] == '1W'), hasLength(1));
    await tester.tap(find.byKey(const Key('p07.range.1D')));
    await tester.pumpAndSettle();
    expect(be.requests.where((r) => r.url.queryParameters['range'] == '1D'), hasLength(1));
  });

  testWidgets('走势线限定右侧 58%，任何金额长度下文字列不压线', (tester) async {
    await _phone(tester);
    final be = _backend()..on('GET /account/allocation', (_) => FakeBackend.ok(_alloc(stock: 987654321.98, etf: 123456789.12, cash: 55555555.55)));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    final hero = tester.getRect(find.byKey(const Key('home.hero')));
    final trend = tester.getRect(find.byKey(const Key('p07.hero.trend')));
    expect(trend.left, closeTo(hero.right - hero.width * AssetHeroCard.trendFrac, 1));
    for (final k in ['home.total', 'home.buyingPower', 'home.dayChange']) {
      expect(tester.getRect(find.byKey(Key(k))).right, lessThanOrEqualTo(trend.left), reason: '$k 不进入走势线区域');
    }
    expect(_text(tester, 'home.total'), r'$1,166,666,666.65');
  });

  testWidgets('1D 不足 2 点："日内数据积累中"；其他区间不足 2 点："记录积累中"', (tester) async {
    await _phone(tester);
    final be = _backend()..on('GET /account/history', (req) => FakeBackend.ok(_history(req.url.queryParameters['range'] == '3M' ? [6500, 6543.21] : [6543.21])));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    expect(find.text('日内数据积累中'), findsOneWidget);
    expect(find.byKey(const Key('p07.hero.trend')), findsNothing);
    await tester.tap(find.byKey(const Key('p07.range.1W')));
    await tester.pumpAndSettle();
    expect(find.text('记录积累中'), findsOneWidget);
    await tester.tap(find.byKey(const Key('p07.range.3M')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('p07.hero.trend')), findsOneWidget);
  });

  testWidgets('眼睛：全页金额变 ****（含图例），百分比保留；持久化', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await tester.tap(find.byKey(const Key('home.hide')));
    await tester.pumpAndSettle();
    expect(AmountMask.instance.value, isTrue);
    for (final k in ['home.total', 'home.buyingPower', 'home.dayChange', 'p07.alloc.total', 'p07.alloc.CASH.amount', 'p07.alloc.ETF.amount']) {
      expect(_text(tester, k), '****', reason: k);
    }
    expect(_text(tester, 'p07.alloc.STOCK.pct'), '45.0%', reason: '百分比保留');
    await tester.tap(find.byKey(const Key('p07.filter.stock')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'p07.alloc.NVDA.amount'), '****');
    await tester.tap(find.byKey(const Key('home.hide')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'home.total'), r'$6,543.21');
  });

  testWidgets('筛选 股票 / ETF：环形图按该类持仓的标的拆分；无持仓时显示说明', (tester) async {
    await _phone(tester);
    final (be, _, _) = await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    int posCalls() => be.requests.where((r) => r.url.path == '/api/v1/positions').length;
    final before = posCalls(); // 资产概览本身会取持仓（今日盈亏），筛选只在首次切到股票 / ETF 时多取一次
    await _scrollTo(tester, find.byKey(const Key('p07.alloc')));
    await tester.ensureVisible(find.byKey(const Key('p07.filter.stock')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('p07.filter.stock')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'p07.alloc.NVDA.amount'), r'$1,944.45');
    expect(_text(tester, 'p07.alloc.AAPL.pct'), '34.0%');
    expect(_text(tester, 'p07.alloc.total'), r'$2,944.45');
    expect(find.byKey(const Key('p07.alloc.SPY')), findsNothing);
    await tester.tap(find.byKey(const Key('p07.filter.etf')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'p07.alloc.SPY.pct'), '100.0%');
    expect(posCalls(), before + 1, reason: '筛选的持仓只取一次');
    be.on('GET /positions', (_) => FakeBackend.ok(_positions(const {'AAPL': 10})));
    await tester.tap(find.byKey(const Key('p07.filter.all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('p07.alloc.CASH')), findsOneWidget);
  });

  testWidgets('接口失败：分布失败隐藏筛选与环形图，走势失败只隐藏线；不弹错误', (tester) async {
    await _phone(tester);
    final be = _backend()
      ..on('GET /account/allocation', (_) => FakeBackend.err(502, 50001, '券商服务暂时不可用'))
      ..on('GET /account/history', (_) => FakeBackend.err(502, 50001, '券商服务暂时不可用'));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    expect(find.byKey(const Key('home.hero')), findsOneWidget);
    expect(find.byKey(const Key('p07.alloc')), findsNothing);
    expect(find.byKey(const Key('p07.filter.all')), findsNothing);
    expect(find.byKey(const Key('p07.hero.trend')), findsNothing);
    expect(find.byKey(const Key('p07.hero.trend.empty')), findsNothing);
    expect(find.textContaining('券商服务暂时不可用'), findsNothing);
  });

  testWidgets('未开户：只显示大卡（—），不显示范围 / 环形图，也不请求接口', (tester) async {
    await _phone(tester);
    final be = _backend(opened: false);
    await pumpApp(tester, backend: be, storedToken: 'tok');
    expect(_text(tester, 'home.total'), '—');
    expect(find.byKey(const Key('p07.ranges')), findsNothing);
    expect(find.byKey(const Key('p07.alloc')), findsNothing);
    expect(be.requests.any((r) => r.url.path.contains('/account/allocation') || r.url.path.contains('/account/history')), isFalse);
  });

  testWidgets('模拟盘：同一大卡与环形图，数据只来自 /paper/*；累计盈亏；可重置', (tester) async {
    await _phone(tester);
    final be = _backend(opened: false); // 模拟盘不依赖开户
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await tester.tap(find.descendant(of: find.byKey(const Key('mode.switch')), matching: find.text('模拟盘')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('paper.hero')), findsOneWidget);
    expect(find.text('模拟 · 总资产 (USD)'), findsOneWidget);
    expect(_text(tester, 'paper.total'), r'$99,999.50');
    expect(_text(tester, 'paper.buyingPower'), r'$98,000.00');
    expect(find.text('累计盈亏'), findsOneWidget);
    expect(find.text('日内数据积累中'), findsOneWidget);
    expect(find.byKey(const Key('paper.reset')), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('p07.alloc')));
    expect(_text(tester, 'p07.alloc.CASH.amount'), r'$98,000.00');
    await tester.tap(find.byKey(const Key('p07.filter.stock')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'p07.alloc.TSLA.pct'), '100.0%');
    expect(be.requests.any((r) => r.url.path == '/api/v1/paper/positions'), isTrue);
    expect(be.requests.any((r) => r.url.path == '/api/v1/account/allocation' || r.url.path == '/api/v1/positions'), isFalse);
  });

  testWidgets('账户抽屉资金区显示可提现（DW 返回值）', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await tester.tap(find.byKey(const Key('home.avatar')));
    await tester.pumpAndSettle();
    final list = find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('drawer.withdraw')), 200, scrollable: list);
    expect(find.descendant(of: find.byKey(const Key('drawer.withdraw')), matching: find.text(r'可提现 $1,000.00')), findsOneWidget);
  });
}
