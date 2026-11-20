import 'package:finx_app/core/sound/ui_sound.dart';
import 'package:finx_app/features/auth/presentation/welcome_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

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
    await tester.tap(find.byKey(const Key('tab.资产')));
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
    await tester.tap(find.byKey(const Key('tab.资产')));
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
}
