import 'package:finx_app/features/account/data/portfolio_api.dart';
import 'package:finx_app/features/account/presentation/asset_analysis.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// F17：P-07 资产分布与资产趋势。

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
  ..on('GET /paper/account/history', (_) => FakeBackend.ok(_history([99999.5], simulated: true)));

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
    test('环形图扇区：0 金额类别不画扇区，其余按金额占比', () {
      final a = Allocation.fromJson(_alloc(etf: 0));
      final seg = donutSegments(a);
      expect([for (final s in seg) s.$1], [AssetClass.stock, AssetClass.cash]);
      expect(seg.fold<double>(0, (s, e) => s + e.$2), closeTo(1, 1e-9));
      expect(donutSegments(Allocation.fromJson(_alloc(stock: 0, etf: 0, cash: 0))), isEmpty);
    });

    test('分布解析：按 STOCK / ETF / CASH 固定顺序，缺项按 0', () {
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

    test('环心金额取整到美元', () {
      expect(fmtUsdWhole(6543.21), r'$6,543');
      expect(fmtUsdWhole(99999.5), r'$100,000');
    });

    test('横轴日期抽样：首尾必显示，最多 7 个', () {
      expect(axisLabelIndices(1), [0]);
      expect(axisLabelIndices(5), [0, 1, 2, 3, 4]);
      final idx = axisLabelIndices(30);
      expect(idx.length, 7);
      expect(idx.first, 0);
      expect(idx.last, 29);
    });

    test('折线坐标：最高值在上、最新点在最右；数值全相同时居中', () {
      const size = Size(358, 110);
      final pts = TrendPainter.layout([100, 300, 200], size);
      expect(pts[1].dy, lessThan(pts[2].dy));
      expect(pts[2].dy, lessThan(pts[0].dy));
      expect(pts.last.dx, closeTo(352, 1e-9));
      final flat = TrendPainter.layout([5, 5], size);
      expect(flat[0].dy, flat[1].dy);
    });
  });

  testWidgets('已开户：资产卡下方显示资产分布（金额、占比）与资产趋势，自选保留', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _scrollTo(tester, find.byKey(const Key('p07.alloc')));
    expect(_text(tester, 'p07.alloc.total'), r'$6,543', reason: '环心显示总资产（取整）');
    expect(_text(tester, 'p07.alloc.STOCK.amount'), r'$2,944.45');
    expect(_text(tester, 'p07.alloc.STOCK.pct'), '45.0%');
    expect(_text(tester, 'p07.alloc.ETF.amount'), r'$1,962.96');
    expect(_text(tester, 'p07.alloc.CASH.pct'), '25.0%');
    expect(find.text('按最新市值 · DW 实时'), findsOneWidget);
    // 资产分布在资产卡之后、自选之前
    await _scrollTo(tester, find.byKey(const Key('p07.trend')));
    expect(find.byKey(const Key('p07.trend.chart')), findsOneWidget);
    expect(find.text('11-20'), findsOneWidget, reason: '横轴含最新日期');
    expect(find.text('11-14'), findsOneWidget);
    final trendY = tester.getTopLeft(find.byKey(const Key('p07.trend'))).dy;
    final allocY = tester.getTopLeft(find.byKey(const Key('p07.alloc'))).dy;
    expect(allocY, lessThan(trendY));
    await _scrollTo(tester, find.text('自选股'));
    expect(tester.getTopLeft(find.text('自选股')).dy, greaterThan(tester.getTopLeft(find.byKey(const Key('p07.trend'))).dy));
  });

  testWidgets('分布中某类为 0：不画扇区但图例保留 \$0.00 与 0.0%', (tester) async {
    await _phone(tester);
    final be = _backend()..on('GET /account/allocation', (_) => FakeBackend.ok(_alloc(etf: 0)));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _scrollTo(tester, find.byKey(const Key('p07.alloc')));
    expect(_text(tester, 'p07.alloc.ETF.amount'), r'$0.00');
    expect(_text(tester, 'p07.alloc.ETF.pct'), '0.0%');
    final painter = tester.widget<CustomPaint>(find.byKey(const Key('p07.alloc.donut'))).painter! as DonutPainter;
    expect([for (final s in painter.segments) s.$1], isNot(contains(AssetClass.etf)));
  });

  testWidgets('快照少于 2 个：显示"记录积累中"，不画折线；切换区间按 range 请求', (tester) async {
    await _phone(tester);
    final be = _backend()
      ..on('GET /account/history', (req) => FakeBackend.ok(_history(req.url.queryParameters['range'] == 'ALL' ? [6500, 6543.21] : [6543.21])));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _scrollTo(tester, find.byKey(const Key('p07.trend')));
    expect(find.text('记录积累中，次日起可见趋势'), findsOneWidget);
    expect(find.byKey(const Key('p07.trend.chart')), findsNothing);
    await tester.tap(find.byKey(const Key('p07.trend.range.ALL')));
    await tester.pumpAndSettle();
    expect(be.requests.any((r) => r.url.path.endsWith('/account/history') && r.url.queryParameters['range'] == 'ALL'), isTrue);
    expect(find.byKey(const Key('p07.trend.chart')), findsOneWidget);
    expect(find.byKey(const Key('p07.trend.empty')), findsNothing);
  });

  testWidgets('接口失败：对应卡片整卡隐藏，其他区块不受影响', (tester) async {
    await _phone(tester);
    final be = _backend()
      ..on('GET /account/allocation', (_) => FakeBackend.err(502, 50001, '券商服务暂时不可用'))
      ..on('GET /account/history', (_) => FakeBackend.err(502, 50001, '券商服务暂时不可用'));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    expect(find.byKey(const Key('p07.alloc')), findsNothing);
    expect(find.byKey(const Key('p07.trend')), findsNothing);
    expect(find.textContaining('券商服务暂时不可用'), findsNothing, reason: '不弹错误提示');
    await _scrollTo(tester, find.text('自选股'));
    expect(find.text('自选股'), findsOneWidget);
  });

  testWidgets('仅分布失败：只隐藏分布卡，趋势照常', (tester) async {
    await _phone(tester);
    final be = _backend()..on('GET /account/allocation', (_) => FakeBackend.err(502, 50001, 'x'));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _scrollTo(tester, find.byKey(const Key('p07.trend')));
    expect(find.byKey(const Key('p07.alloc')), findsNothing);
    expect(find.byKey(const Key('p07.trend')), findsOneWidget);
  });

  testWidgets('未开户：页面保持现状，不显示分布与趋势，也不请求接口', (tester) async {
    await _phone(tester);
    final be = _backend(opened: false);
    await pumpApp(tester, backend: be, storedToken: 'tok');
    expect(find.byKey(const Key('p07.alloc')), findsNothing);
    expect(find.byKey(const Key('p07.trend')), findsNothing);
    expect(be.requests.any((r) => r.url.path.contains('/account/allocation') || r.url.path.contains('/account/history')), isFalse);
  });

  testWidgets('模拟盘：显示模拟账户的分布与趋势，带"模拟"角标，只请求 /paper 接口', (tester) async {
    await _phone(tester);
    final be = _backend(opened: false); // 模拟盘不依赖开户
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await tester.tap(find.descendant(of: find.byKey(const Key('mode.switch')), matching: find.text('模拟盘')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('p07.alloc')));
    expect(find.descendant(of: find.byKey(const Key('p07.alloc')), matching: find.byKey(const Key('paper.badge'))), findsOneWidget);
    expect(_text(tester, 'p07.alloc.CASH.amount'), r'$98,000.00');
    expect(find.text('虚拟行情估值'), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('p07.trend')));
    expect(find.descendant(of: find.byKey(const Key('p07.trend')), matching: find.byKey(const Key('paper.badge'))), findsOneWidget);
    expect(find.text('记录积累中，次日起可见趋势'), findsOneWidget);
    expect(be.requests.any((r) => r.url.path == '/api/v1/paper/account/allocation'), isTrue);
    expect(be.requests.any((r) => r.url.path == '/api/v1/account/allocation'), isFalse);
  });
}
