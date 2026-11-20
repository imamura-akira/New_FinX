import 'package:finx_app/features/market/domain/sentiment.dart';
import 'package:finx_app/features/market/presentation/sentiment_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// F11 扩展：P-09 第四张指数卡 IWM、市场情绪卡（恐慌贪婪仪表盘 + 涨跌家数）。

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

int _flex(WidgetTester tester, String name) => tester.widget<Expanded>(find.byKey(Key('market.breadth.bar.$name'))).flex;

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

  test('仪表盘指针角度：0 指向左、50 竖直、100 指向右', () {
    expect(FearGreedGaugePainter.needleDegrees(0), -90);
    expect(FearGreedGaugePainter.needleDegrees(50), 0);
    expect(FearGreedGaugePainter.needleDegrees(100), 90);
    expect(FearGreedGaugePainter.needleDegrees(62), closeTo(21.6, 1e-9));
    expect(FearGreedGaugePainter.needleDegrees(110), 90, reason: '回弹超出时夹紧');
  });

  test('涨跌家数比例条权重', () {
    const b = Breadth(up: 18, down: 9, flat: 3);
    expect(b.total, 30);
    expect(b.flexes, (18, 3, 9));
    expect(const Breadth(up: 0, down: 0, flat: 0).flexes, (1, 1, 1));
  });

  testWidgets('P-09：四张指数卡（含 IWM），情绪卡在指数卡与涨幅榜之间', (tester) async {
    await _openMarket(tester, _backend());
    for (final s in ['SPY', 'QQQ', 'DIA', 'IWM']) {
      expect(find.byKey(Key('market.index.$s')), findsOneWidget);
    }
    final card = find.byKey(const Key('market.sentiment'));
    expect(card, findsOneWidget);
    expect(find.text('演示数据 · 每 3 秒更新'), findsOneWidget);
    expect(find.text('由虚拟行情的涨跌幅、动量与波动合成'), findsOneWidget);
    final idxY = tester.getBottomLeft(find.byKey(const Key('market.index.SPY'))).dy;
    final cardTop = tester.getTopLeft(card).dy;
    final cardBottom = tester.getBottomLeft(card).dy;
    final rankY = tester.getTopLeft(find.text('涨幅榜')).dy;
    expect(idxY < cardTop && cardBottom < rankY, isTrue, reason: '情绪卡位于指数卡行与涨幅榜之间');
    // 四张等宽
    final w = tester.getSize(find.byKey(const Key('market.index.SPY'))).width;
    expect(tester.getSize(find.byKey(const Key('market.index.IWM'))).width, closeTo(w, 0.5));
  });

  testWidgets('情绪卡：指数、档位与涨跌家数统计显示（18 涨 · 9 跌 · 3 平）', (tester) async {
    await _openMarket(tester, _backend());
    expect(tester.widget<Text>(find.byKey(const Key('market.fg.value'))).data, '62');
    expect(find.descendant(of: find.byKey(const Key('market.fg.label')), matching: find.text('贪婪')), findsOneWidget);
    expect(find.text('18 涨 · 9 跌 · 3 平', findRichText: true), findsOneWidget);
    expect(find.text('上涨 18'), findsOneWidget);
    expect(find.text('平盘 3'), findsOneWidget);
    expect(find.text('下跌 9'), findsOneWidget);
    expect((_flex(tester, 'up'), _flex(tester, 'flat'), _flex(tester, 'down')), (18, 3, 9));
  });

  testWidgets('情绪卡每 3 秒刷新：指针动画到新值，档位随之变化；无平盘时不画平盘段', (tester) async {
    final be = _backend()..on('GET /market/sentiment', fakeSentiment(values: [20, 80], up: 20, down: 4, flat: 0));
    await _openMarket(tester, be);
    expect(tester.widget<Text>(find.byKey(const Key('market.fg.value'))).data, '20');
    expect(find.text('极度恐慌'), findsOneWidget);
    expect(find.byKey(const Key('market.breadth.bar.flat')), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Text>(find.byKey(const Key('market.fg.value'))).data, '80');
    expect(find.text('极度贪婪'), findsOneWidget);
    // 指针在动画中：尚未到达 80
    final mid = tester.widget<CustomPaint>(find.byKey(const Key('market.gauge'))).painter! as FearGreedGaugePainter;
    expect(mid.value, lessThan(80));
    await tester.pump(const Duration(seconds: 1));
    final end = tester.widget<CustomPaint>(find.byKey(const Key('market.gauge'))).painter! as FearGreedGaugePainter;
    expect(end.value, closeTo(80, 0.01));
  });

  testWidgets('情绪接口失败：不显示情绪卡，其余行情照常', (tester) async {
    final be = _backend()..on('GET /market/sentiment', (_) => FakeBackend.err(500, 50001, '暂不可用'));
    await _openMarket(tester, be);
    expect(find.byKey(const Key('market.sentiment')), findsNothing);
    expect(find.byKey(const Key('market.index.IWM')), findsOneWidget);
    expect(find.text('涨幅榜'), findsOneWidget);
  });
}
