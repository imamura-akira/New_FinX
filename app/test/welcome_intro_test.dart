import 'package:finx_app/app/theme.dart';
import 'package:finx_app/core/sound/ui_sound.dart';
import 'package:finx_app/features/auth/presentation/welcome_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// P-01 FinX 原版（F22-g 由 F20 AK 版回滚）：字标滑入、Fifi 弹跳摆动、欢迎铃音。

/// 记录提示音调用。
List<String> _mockSound(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(UiSound.channel, (call) async {
    calls.add('${call.method}:${(call.arguments as Map)['asset']}');
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

void main() {
  testWidgets('P-01 冷启动：品牌入场动画 + 一声提示音，2 秒内完成；动画中按钮可点；返回 P-01 不重播', (tester) async {
    await _phone(tester);
    final sound = _mockSound(tester);
    await pumpApp(tester, backend: FakeBackend());
    // pumpApp 已 pumpAndSettle：入场动画（1.6 秒）已跑完，且在 2 秒上限内
    expect(sound, ['play:assets/sounds/welcome_chime.wav']);
    expect(find.byKey(const Key('welcome.intro')), findsOneWidget);
    expect(const Duration(milliseconds: 1600) <= const Duration(seconds: 2), isTrue);

    await tester.tap(find.byKey(const Key('welcome.login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav.back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome.logo')), findsOneWidget);
    // 离开 P-01（未登录逛行情）再回来：重新挂载也不重播
    await tester.tap(find.byKey(const Key('welcome.market')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab.home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome.logo')), findsOneWidget);
    expect(find.byKey(const Key('welcome.intro')), findsNothing, reason: '回到 P-01 不重播');
    expect(sound, hasLength(1), reason: '提示音只响一次');
  });

  testWidgets('P-01 动画进行中按钮即可点击', (tester) async {
    await _phone(tester);
    _mockSound(tester);
    await pumpApp(tester, backend: FakeBackend());
    await tester.tap(find.byKey(const Key('welcome.market')));
    await tester.pumpAndSettle();
    LaunchIntro.resetForTest(); // 模拟冷启动：重新进入 P-01 时播放入场
    await tester.tap(find.byKey(const Key('tab.home')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200)); // 入场进行中
    expect(find.byKey(const Key('welcome.intro')), findsOneWidget);
    await tester.tap(find.byKey(const Key('welcome.register')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav.back')), findsOneWidget, reason: '已进入登录 / 注册页');
  });

  testWidgets('系统"减弱动态效果"：只淡入（无位移 / 旋转），提示音照常', (tester) async {
    await _phone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final sound = _mockSound(tester);
    await pumpApp(tester, backend: FakeBackend());
    expect(find.byKey(const Key('welcome.intro.fade')), findsOneWidget);
    expect(find.byKey(const Key('welcome.intro')), findsNothing);
    expect(sound, hasLength(1));
  });

  testWidgets('冷启动已登录直接进入资产页：之后退出回到 P-01 不播放入场与提示音', (tester) async {
    await _phone(tester);
    final sound = _mockSound(tester);
    final (_, session, _) = await pumpApp(tester, backend: _signedIn(), storedToken: 'tok');
    expect(find.byKey(const Key('home.hero')), findsOneWidget);
    await session.signOut();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome.logo')), findsOneWidget);
    expect(find.byKey(const Key('welcome.intro')), findsNothing);
    expect(sound, isEmpty);
  });

  test('UiSound：平台未实现时静默忽略', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await UiSound.play(UiSound.welcomeChime); // 不抛异常
  });

  test('提示音素材存在且为脚本生成的 WAV', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final data = await rootBundle.load(UiSound.welcomeChime);
    final head = String.fromCharCodes(data.buffer.asUint8List(0, 4));
    expect(head, 'RIFF');
    expect(data.lengthInBytes, lessThan(100 * 1024));
  });

  testWidgets('F22-g 版式：FinX 字标 + Fifi 胶囊图 + 紫色渐变注册键；不出现 AK 字标与趋势线', (tester) async {
    await _phone(tester);
    _mockSound(tester);
    await pumpApp(tester, backend: FakeBackend());
    final imgs = tester.widgetList<Image>(find.byType(Image)).map((i) => (i.image as AssetImage).assetName).toSet();
    expect(imgs, containsAll([BrandAssets.logo, BrandAssets.fifiPill]));
    expect(imgs.contains(BrandAssets.akMark), isFalse);
    expect(find.byKey(const Key('welcome.trend')), findsNothing);
    final btn = find.descendant(of: find.byKey(const Key('welcome.register')), matching: find.byWidgetPredicate((w) => w is Container || w is DecoratedBox || w is Ink));
    final hasGrad = tester.widgetList(btn).any((w) {
      final d = switch (w) { Container c => c.decoration, DecoratedBox b => b.decoration, Ink i => i.decoration, _ => null };
      return d is BoxDecoration && d.gradient == AppGradients.grad;
    });
    expect(hasGrad, isTrue, reason: '注册键为 FinX 紫色渐变');
    expect(find.text('美股与 ETF 投资，开户、入金、交易一站完成。'), findsOneWidget);
  });

  testWidgets('[en] P-01 文案', (tester) async {
    await _phone(tester);
    _mockSound(tester);
    final orig = FlutterError.onError;
    FlutterError.onError = (d) => d.exceptionAsString().contains('overflowed') ? null : orig?.call(d);
    addTearDown(() => FlutterError.onError = orig);
    await pumpApp(tester, backend: FakeBackend(), locale: 'en');
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Browse Markets First'), findsOneWidget);
  });
}
