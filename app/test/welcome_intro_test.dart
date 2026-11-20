import 'dart:typed_data';

import 'package:finx_app/core/sound/ui_sound.dart';
import 'package:finx_app/features/auth/presentation/welcome_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// F20 P-01 AK 品牌版：冷启动入场（字标与 slogan 淡入、趋势线描画、5 个高点"滴"声音调递增、光点呼吸、注册按钮放大一次）。

/// 记录提示音调用。
List<String> _mockSound(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(UiSound.channel, (call) async {
    calls.add('${(call.arguments as Map)['asset']}');
    return true;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(UiSound.channel, null));
  return calls;
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

FakeBackend _signedIn() => FakeBackend()
  ..on(
    'GET /me',
    (_) => FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': null, 'accountStatus': 'NONE'}),
  )
  ..on('POST /auth/logout', (_) => FakeBackend.ok());

TrendLinePainter _painter(WidgetTester tester) => tester.widget<CustomPaint>(find.byKey(const Key('welcome.trend'))).painter! as TrendLinePainter;

void main() {
  test('高点：3 个局部高点 + 拐点 + 终点共 5 个，按路径长度递增，终点为 1', () {
    final p = trendPeakFractions();
    expect(p, hasLength(5));
    for (var i = 1; i < p.length; i++) {
      expect(p[i], greaterThan(p[i - 1]));
    }
    expect(p.last, closeTo(1, 1e-9));
    expect(UiSound.peakTicks, hasLength(5));
  });

  testWidgets('冷启动：描线时 5 个高点依次"滴"（音调递增），只播一次；返回 P-01 不重播', (tester) async {
    await _phone(tester);
    final sound = _mockSound(tester);
    await pumpApp(tester, backend: FakeBackend());
    // pumpApp 已 pumpAndSettle：入场（约 2 秒）与呼吸（3 次）均已结束
    expect(sound, UiSound.peakTicks, reason: '按 peak_1 → peak_5 顺序各一次');
    expect(find.byKey(const Key('welcome.intro')), findsOneWidget);
    expect(_painter(tester).progress, 1);

    await tester.tap(find.byKey(const Key('welcome.login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome.logo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('welcome.market')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab.home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome.static')), findsOneWidget, reason: '回到 P-01 直接显示完整线，不重播');
    expect(_painter(tester).progress, 1);
    expect(sound, hasLength(5), reason: '提示音不重复');
  });

  testWidgets('描画过程：线从左向右推进，"滴"声随高点逐个出现；画完后注册按钮放大一次', (tester) async {
    await _phone(tester);
    final sound = _mockSound(tester);
    await pumpApp(tester, backend: FakeBackend());
    await tester.tap(find.byKey(const Key('welcome.market')));
    await tester.pumpAndSettle();
    sound.clear();
    LaunchIntro.resetForTest(); // 模拟冷启动
    await tester.tap(find.byKey(const Key('tab.home')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // 描线尚未开始
    expect(_painter(tester).progress, 0);
    expect(sound, isEmpty);
    await tester.pump(const Duration(milliseconds: 700)); // ≈ 0.95 s：描画中段
    final mid = _painter(tester).progress;
    expect(mid > 0 && mid < 1, isTrue, reason: '描画中：$mid');
    expect(sound.length, inInclusiveRange(1, 4));
    expect(sound, UiSound.peakTicks.take(sound.length).toList(), reason: '音调按顺序递增');
    // 动画中按钮可点（不等动画结束）
    expect(find.byKey(const Key('welcome.register')).hitTestable(), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900)); // ≈ 1.85 s：注册按钮放大中
    expect(_painter(tester).progress, 1);
    expect(sound, UiSound.peakTicks);
    final scale = tester.widget<Transform>(find.ancestor(of: find.byKey(const Key('welcome.register')), matching: find.byType(Transform)).first);
    expect(scale.transform.getMaxScaleOnAxis(), greaterThan(1.01));
    await tester.pumpAndSettle();
    final done = tester.widget<Transform>(find.ancestor(of: find.byKey(const Key('welcome.register')), matching: find.byType(Transform)).first);
    expect(done.transform.getMaxScaleOnAxis(), closeTo(1, 1e-6));
  });

  testWidgets('系统"减弱动态效果"：直接显示完整静态线，不播声音，光点不呼吸', (tester) async {
    await _phone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final sound = _mockSound(tester);
    await pumpApp(tester, backend: FakeBackend());
    expect(find.byKey(const Key('welcome.static')), findsOneWidget);
    expect(_painter(tester).progress, 1);
    expect(_painter(tester).breath, 0);
    expect(sound, isEmpty);
  });

  testWidgets('冷启动已登录直接进入资产页：之后退出回到 P-01 不播放入场与声音', (tester) async {
    await _phone(tester);
    final sound = _mockSound(tester);
    final (_, session, _) = await pumpApp(tester, backend: _signedIn(), storedToken: 'tok');
    expect(find.byKey(const Key('home.hero')), findsOneWidget);
    await session.signOut();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome.static')), findsOneWidget);
    expect(sound, isEmpty);
  });

  testWidgets('双语：slogan 与按钮文案', (tester) async {
    await _phone(tester);
    _mockSound(tester);
    await pumpApp(tester, backend: FakeBackend());
    expect(find.text('美股与 ETF 投资\n开户、入金、交易，一站完成。'), findsOneWidget);
    expect(find.text('注册'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('先逛逛行情'), findsOneWidget);
  });

  testWidgets('[en] 双语：Invest in U.S. stocks & ETFs / Sign Up / Log In / Browse Markets', (tester) async {
    await _phone(tester);
    _mockSound(tester);
    final orig = FlutterError.onError;
    FlutterError.onError = (d) => d.exceptionAsString().contains('overflowed') ? null : orig?.call(d); // 测试字体宽，见 l10n_test
    addTearDown(() => FlutterError.onError = orig);
    await pumpApp(tester, backend: FakeBackend(), locale: 'en');
    expect(find.text('Invest in U.S. stocks & ETFs\nOpen, fund, and trade — all in one place.'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Browse Markets'), findsOneWidget);
  });

  test('UiSound：平台未实现时静默忽略', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await UiSound.play(UiSound.peakTicks.first); // 不抛异常
  });

  test('"滴"声素材：5 个脚本生成的短 WAV（约 100 ms）', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final a in UiSound.peakTicks) {
      final data = await rootBundle.load(a);
      expect(String.fromCharCodes(data.buffer.asUint8List(0, 4)), 'RIFF');
      final seconds = (data.lengthInBytes - 44) / data.getUint32(28, Endian.little);
      expect(seconds, inInclusiveRange(.08, .12), reason: a);
    }
  });
}
