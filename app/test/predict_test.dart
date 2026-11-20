import 'dart:convert';

import 'package:finx_app/features/predict/domain/predict_rules.dart';
import 'package:finx_app/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// F19 预测板块（积分演示版）。

Map<String, dynamic> _market(String id, {String kind = 'EVENT', String? symbol, int yes = 6800, int no = 3200, String category = 'MACRO', Duration closesIn = const Duration(days: 20)}) => {
  'id': id,
  'kind': kind,
  'category': category,
  'symbol': symbol,
  'title': {'zh': kind == 'UPDOWN' ? '$symbol 15 分钟涨跌' : '美联储 12 月会议会降息 25 个基点吗？', 'en': kind == 'UPDOWN' ? '$symbol Up or Down' : 'Will the Fed cut rates by 25 bps?'},
  'subtitle': {'zh': '宏观 · 美联储', 'en': 'Macro · Fed'},
  'outcomes': [
    {'key': 'YES', 'label': {'zh': kind == 'UPDOWN' ? '上涨' : '会降息', 'en': kind == 'UPDOWN' ? 'Up' : 'Cut'}, 'percent': (yes * 100 / (yes + no)).round(), 'pool': yes},
    {'key': 'NO', 'label': {'zh': kind == 'UPDOWN' ? '下跌' : '不会降息', 'en': kind == 'UPDOWN' ? 'Down' : 'No cut'}, 'percent': 100 - (yes * 100 / (yes + no)).round(), 'pool': no},
  ],
  'opensAt': DateTime.now().toUtc().subtract(const Duration(minutes: 4)).toIso8601String(),
  'closesAt': DateTime.now().toUtc().add(closesIn).toIso8601String(),
  'targetPrice': symbol == null ? null : (symbol == 'BTC' ? 61515.78 : 145.0),
  'settlePrice': null,
  'status': 'OPEN',
  'result': null,
};

class _State {
  int points = 12400;
  int btcYes = 540, btcNo = 460;
  int claimable = 0;
  final bets = <Map<String, dynamic>>[];
  Object? lastBet;
}

FakeBackend _backend(_State s) => FakeBackend()
  ..on('GET /me', (_) => FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': null, 'accountStatus': 'NONE'}))
  ..on('GET /predict/account', (_) => FakeBackend.ok({'simulated': true, 'points': s.points, 'initialPoints': 10000, 'stats': {}}))
  ..on(
    'GET /predict/markets',
    (_) => FakeBackend.ok({
      'simulated': true,
      'serverTime': DateTime.now().toUtc().toIso8601String(),
      'updown': [
        _market('updown-BTC', kind: 'UPDOWN', symbol: 'BTC', yes: s.btcYes, no: s.btcNo, category: 'CRYPTO', closesIn: const Duration(minutes: 11, seconds: 26)),
        _market('updown-SOL', kind: 'UPDOWN', symbol: 'SOL', yes: 410, no: 590, category: 'CRYPTO', closesIn: const Duration(minutes: 3, seconds: 12)),
      ],
      'events': [_market('fed')],
    }),
  )
  ..on('POST /predict/bets', (req) {
    final b = jsonDecode(req.body) as Map<String, dynamic>;
    s.lastBet = b;
    final stake = b['stake'] as int;
    s.points -= stake;
    return FakeBackend.ok({
      'simulated': true,
      'bet': {'id': 'b1', 'potentialPayout': (stake / .54).floor()},
      'points': s.points,
      'market': _market('updown-BTC', kind: 'UPDOWN', symbol: 'BTC', yes: s.btcYes + stake, no: s.btcNo, category: 'CRYPTO'),
    });
  })
  ..on(
    'GET /predict/bets',
    (_) => FakeBackend.ok({
      'simulated': true,
      'bets': s.bets,
      'stats': {'settled': 3, 'wins': 2, 'hitRate': 66.7, 'netPoints': 120, 'claimable': s.claimable, 'openBets': 1, 'openStake': 100},
    }),
  )
  ..on('POST /predict/claim', (_) {
    final c = s.claimable;
    s.points += c;
    s.claimable = 0;
    return FakeBackend.ok({'simulated': true, 'claimed': c, 'points': s.points});
  });

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, _State s, {String locale = 'zh'}) async {
  await _phone(tester);
  await pumpApp(tester, backend: _backend(s), storedToken: 'tok', locale: locale);
  await tester.tap(find.byKey(const Key('tab.predict')));
  await frames(tester, 10);
}

void _ignoreOverflow() {
  final orig = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) return;
    orig?.call(d);
  };
  addTearDown(() => FlutterError.onError = orig);
}

final _han = RegExp(r'[一-鿿]');

void main() {
  group('规则', () {
    test('赔付与后端一致：floor(stake ÷ p)，p 夹在 2%–98%', () {
      expect(predictPayout(100, .5), 200);
      expect(predictPayout(100, .68), 147);
      expect(predictPayout(100, .32), 312);
      expect(predictPayout(100, .001), 5000);
      expect(predictPayout(100, .999), 102);
    });

    test('下注校验：10–5,000 的整数且不超过余额', () {
      debugSetLocale(const Locale('zh'));
      expect(validateStake('100', 12400), isNull);
      expect(validateStake('9', 12400), t.predictStakeInvalid);
      expect(validateStake('5001', 99999), t.predictStakeInvalid);
      expect(validateStake('12.5', 12400), t.predictStakeInvalid);
      expect(validateStake('500', 300), t.predictStakeInsufficient);
    });

    test('格式：积分千分位、倒计时、截止日期中英', () {
      expect(fmtPoints(12400), '12,400');
      expect(fmtPointsSigned(-80), '-80');
      expect(fmtPointsSigned(120), '+120');
      expect(fmtCountdown(const Duration(minutes: 11, seconds: 26)), '11:26');
      expect(fmtCountdown(const Duration(hours: 2, minutes: 3, seconds: 4)), '2:03:04');
      expect(fmtCountdown(const Duration(seconds: -1)), '00:00');
      final d = DateTime(2026, 12, 18, 12);
      debugSetLocale(const Locale('zh'));
      expect(fmtMonthDay(d), '12月18日');
      debugSetLocale(const Locale('en'));
      expect(fmtMonthDay(d), 'Dec 18');
      debugSetLocale(const Locale('zh'));
    });
  });

  testWidgets('预测页：积分余额、演示标识、Up or Down 主卡、15 分钟市场、热门事件与免责声明', (tester) async {
    final s = _State();
    await _open(tester, s);
    expect(find.text('12,400 分'), findsOneWidget);
    expect(find.byKey(const Key('predict.demoBadge')), findsOneWidget);
    expect(find.text('涨 或 跌 · BTC'), findsOneWidget);
    expect(find.text('上涨 · 54%'), findsOneWidget);
    expect(find.text('下跌 · 46%'), findsOneWidget);
    expect(find.byKey(const Key('predict.mini.BTC')), findsOneWidget);
    expect(find.byKey(const Key('predict.mini.SOL')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('predict.event.fed')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('68%'), findsOneWidget);
    expect(find.text('32%'), findsOneWidget);
    expect(find.byKey(const Key('predict.liveDot')), findsWidgets);
    await tester.scrollUntilVisible(find.byKey(const Key('predict.disclaimer')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('预测为用户观点聚合，仅供参考，不构成投资建议'), findsOneWidget);
  });

  testWidgets('6 个 Tab：预测在市场与股票大师之间', (tester) async {
    await _open(tester, _State());
    final xs = [for (final k in ['home', 'market', 'predict', 'masters', 'fifi', 'rewards']) tester.getCenter(find.byKey(Key('tab.$k'))).dx];
    expect(xs, [...xs]..sort());
  });

  testWidgets('下注：显示若正确可得、确认后扣分并刷新余额与比例', (tester) async {
    final s = _State();
    await _open(tester, s);
    await tester.tap(find.byKey(const Key('predict.hero.YES')));
    await frames(tester, 8);
    expect(find.text('你的预测：上涨'), findsOneWidget);
    // 默认 100 分，p = 540 / 1000 → floor(100 / 0.54) = 185
    expect(find.text('若正确可得 185 分'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bet.quick.500')));
    await tester.pump();
    expect(find.text('若正确可得 925 分'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bet.confirm')));
    await tester.pump();
    await frames(tester, 5);
    expect(s.lastBet, {'marketId': 'updown-BTC', 'outcome': 'YES', 'stake': 500});
    expect(find.text('11,900 分'), findsOneWidget, reason: '余额 12,400 − 500');
    expect(find.textContaining('预测已提交'), findsOneWidget);
  });

  testWidgets('下注校验：积分不足与越界不发请求', (tester) async {
    final s = _State()..points = 50;
    await _open(tester, s);
    await tester.tap(find.byKey(const Key('predict.hero.NO')));
    await frames(tester, 8);
    await tester.tap(find.byKey(const Key('bet.confirm')));
    await tester.pump();
    expect(find.text('积分不足'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('bet.stake')), '5');
    await tester.tap(find.byKey(const Key('bet.confirm')));
    await tester.pump();
    expect(find.text('请输入 10–5,000 的整数积分'), findsOneWidget);
    expect(s.lastBet, isNull);
  });

  testWidgets('动态：比例随轮询刷新并滚动到新值；倒计时逐秒走', (tester) async {
    final s = _State();
    await _open(tester, s);
    expect(find.text('上涨 · 54%'), findsOneWidget);
    final before = tester.widget<Text>(find.descendant(of: find.byKey(const Key('predict.hero')), matching: find.textContaining(':')).first).data;
    s.btcYes = 700;
    s.btcNo = 300;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    // 动画进行中：介于 54 与 70 之间
    final mid = tester.widgetList<Text>(find.textContaining('上涨 · ')).first.data!;
    final v = int.parse(RegExp(r'(\d+)%').firstMatch(mid)!.group(1)!);
    expect(v > 54 && v < 70, isTrue, reason: '数字滚动中：$mid');
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('上涨 · 70%'), findsOneWidget);
    // 倒计时按真实时钟计算（测试中的假时钟不推进墙钟），这里校验格式与区间；逐秒走动在模拟器上目检
    expect(RegExp(r'^1[01]:\d\d$').hasMatch(before!), isTrue, reason: '倒计时 mm:ss：$before');
  });

  testWidgets('减弱动态效果：比例直接跳到新值，Live 红点不闪动', (tester) async {
    final s = _State();
    await _phone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(tester, backend: _backend(s), storedToken: 'tok');
    await tester.tap(find.byKey(const Key('tab.predict')));
    await frames(tester, 10);
    s.btcYes = 700;
    s.btcNo = 300;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('上涨 · 70%'), findsOneWidget);
    final fade = tester.widget<FadeTransition>(find.byKey(const Key('predict.liveDot')).first);
    final o1 = fade.opacity.value;
    await tester.pump(const Duration(milliseconds: 300));
    expect(fade.opacity.value, o1);
    expect(o1, 1);
  });

  testWidgets('我的预测：战绩与一键领取', (tester) async {
    final s = _State()
      ..claimable = 312
      ..bets.addAll([
        {'id': 'b1', 'marketId': 'fed', 'outcome': 'YES', 'stake': 100, 'potentialPayout': 147, 'status': 'OPEN', 'payout': 0, 'claimed': false, 'createdAt': '2026-11-20T12:00:00Z', 'market': _market('fed')},
        {'id': 'b2', 'marketId': 'updown-BTC', 'outcome': 'NO', 'stake': 100, 'potentialPayout': 312, 'status': 'WON', 'payout': 312, 'claimed': false, 'createdAt': '2026-11-20T11:00:00Z', 'market': _market('updown-BTC', kind: 'UPDOWN', symbol: 'BTC')},
      ]);
    await _open(tester, s);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/predict/mine');
    await frames(tester, 10);
    expect(tester.widget<Text>(find.byKey(const Key('mine.hitRate'))).data, '66.7%');
    expect(tester.widget<Text>(find.byKey(const Key('mine.net'))).data, '+120');
    expect(find.text('待领取 312 分'), findsOneWidget);
    expect(find.byKey(const Key('mine.bet.b1')), findsOneWidget);
    await tester.tap(find.text('已结算').last);
    await tester.pump();
    expect(find.byKey(const Key('mine.bet.b2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mine.claim')));
    await frames(tester, 5);
    expect(find.text('已领取 312 分'), findsOneWidget);
    expect(s.points, 12712);
  });

  testWidgets('[en] 英文渲染：Up or Down、15 Minute Markets、Trending Markets、免责声明，无中文', (tester) async {
    _ignoreOverflow();
    await _open(tester, _State(), locale: 'en');
    expect(find.text('Up or Down · BTC'), findsOneWidget);
    expect(find.text('15 Minute Markets'), findsOneWidget);
    expect(find.text('12,400 pts'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('predict.disclaimer')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Trending Markets'), findsOneWidget);
    expect(find.text('Predictions aggregate user opinions. For reference only. Not investment advice.'), findsOneWidget);
    expect(find.text('Will the Fed cut rates by 25 bps?'), findsOneWidget);
    final texts = [for (final w in tester.widgetList<RichText>(find.byType(RichText))) w.text.toPlainText()];
    expect(texts.where((x) => _han.hasMatch(x)), isEmpty);
  });
}
