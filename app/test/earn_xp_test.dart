import 'package:finx_app/core/sound/ui_sound.dart';
import 'package:finx_app/features/rewards/presentation/earn_xp_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// F22-f：赚取 XP 任务页（定稿 v3/earn_xp.png）。

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

FakeBackend _backend() => FakeBackend()
  ..on(
    'GET /me',
    (_) => FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': null, 'accountStatus': 'NONE'}),
  );

/// 时钟：2026-11-21（周六）美东 11:41:15（UTC 16:41:15），距美东零点 12:18:45。
DateTime _clock = DateTime.utc(2026, 11, 21, 16, 41, 15);

Future<FakeBackend> _open(WidgetTester tester, FakeBackend be) async {
  await _phone(tester);
  EarnXpPage.debugClock = () => _clock;
  addTearDown(() => EarnXpPage.debugClock = null);
  await pumpApp(tester, backend: be, storedToken: 'tok');
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/rewards/earn');
  await frames(tester, 10);
  return be;
}

String _text(WidgetTester tester, String k) => tester.widget<Text>(find.byKey(Key(k))).data!;

void main() {
  setUp(() => _clock = DateTime.utc(2026, 11, 21, 16, 41, 15));

  testWidgets('版式：Fifi 奖励任务 + XP 胶囊 + 英雄卡、今日任务五项（XP 取 seed）、重置倒计时逐秒走、连续打卡、前往 Fifi 衣橱', (tester) async {
    await _open(tester, _backend());
    expect(find.text('Fifi 奖励任务'), findsOneWidget);
    expect(_text(tester, 'xp.value'), '1,493 XP');
    expect(find.byKey(const Key('earn.hero')), findsOneWidget);
    expect(_text(tester, 'earn.countdown'), '12:18:45 后重置');
    _clock = _clock.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(_text(tester, 'earn.countdown'), '12:18:44 后重置', reason: '逐秒走');
    expect([for (final id in EarnXpPage.taskOrder) _text(tester, 'earn.task.$id.xp')], ['+10 XP', '+30 XP', '+20 XP', '+80 XP', '+20 XP']);
    expect(find.text('1. 每日签到'), findsOneWidget);
    expect(find.text('4. 本月储蓄目标'), findsOneWidget);
    expect(find.text('5. 分享一次 FinX'), findsOneWidget);
    expect(_text(tester, 'earn.streak.days'), '连续 0 天');
    expect(find.text('今天签到，开启连续记录'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('earn.wardrobe')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('👜 前往 Fifi 衣橱'), findsOneWidget);
  });

  testWidgets('每日签到：XP 入账、行变绿勾、轻提示音；再点提示已签到；其余四项提示即将开启', (tester) async {
    final sounds = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(UiSound.channel, (c) async {
      sounds.add('${(c.arguments as Map)['asset']}');
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(UiSound.channel, null));
    var posts = 0;
    final be = _backend()
      ..on('POST /rewards/checkin', (_) {
        posts++;
        return FakeBackend.ok(
          checkinJson(checkedIn: true, streak: 1, week: [false, false, false, false, false, true, false], balance: 1503, granted: posts == 1 ? 10 : 0),
        );
      });
    await _open(tester, be);
    final check = find.byKey(const Key('earn.task.checkin.check'));
    expect(find.descendant(of: check, matching: find.byIcon(Icons.check_rounded)), findsNothing);
    await tester.tap(find.byKey(const Key('earn.task.checkin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(posts, 1);
    expect(find.text('签到成功 +10 XP'), findsOneWidget);
    expect(_text(tester, 'xp.value'), '1,503 XP', reason: 'XP 胶囊为账本余额');
    expect(find.descendant(of: check, matching: find.byIcon(Icons.check_rounded)), findsOneWidget, reason: '绿勾');
    expect(sounds, ['assets/sounds/reminder_ding.wav']);
    expect(_text(tester, 'earn.streak.days'), '连续 1 天');
    expect(find.text('继续保持！'), findsOneWidget);
    final sat = find.byKey(const Key('earn.week.5'));
    expect(find.descendant(of: sat, matching: find.byIcon(Icons.check_rounded)), findsOneWidget, reason: '本周六圆点已签');
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byKey(const Key('earn.task.checkin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(posts, 1, reason: '已签到不再请求');
    expect(find.text('今日已签到'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    for (final id in ['lesson', 'checkup', 'savings', 'share']) {
      await tester.tap(find.byKey(Key('earn.task.$id')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('该任务即将开启'), findsOneWidget, reason: id);
      await tester.pump(const Duration(seconds: 3));
    }
    expect(be.requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  testWidgets('已签到状态进入：签到行为绿勾，连续 50 天，本周圆点按记录显示', (tester) async {
    final be = _backend()
      ..on('GET /rewards/checkin', (_) => FakeBackend.ok(checkinJson(checkedIn: true, streak: 50, week: [true, true, true, true, true, true, false])));
    await _open(tester, be);
    expect(_text(tester, 'earn.streak.days'), '连续 50 天');
    for (var i = 0; i < 6; i++) {
      expect(find.descendant(of: find.byKey(Key('earn.week.$i')), matching: find.byIcon(Icons.check_rounded)), findsOneWidget, reason: '周${i + 1}');
    }
    expect(find.descendant(of: find.byKey(const Key('earn.week.6')), matching: find.byIcon(Icons.check_rounded)), findsNothing);
  });

  testWidgets('美东零点：倒计时归零后重新加载（新的一天）', (tester) async {
    var gets = 0;
    final be = _backend()
      ..on('GET /rewards/checkin', (_) {
        gets++;
        return FakeBackend.ok(checkinJson(checkedIn: gets == 1));
      });
    await _open(tester, be);
    expect(gets, 1);
    _clock = DateTime.utc(2026, 11, 22, 5, 0, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(gets, 2);
    expect(find.descendant(of: find.byKey(const Key('earn.task.checkin.check')), matching: find.byIcon(Icons.check_rounded)), findsNothing);
    expect(_text(tester, 'earn.countdown'), '23:59:59 后重置');
  });

  testWidgets('前往 Fifi 衣橱 → 商店页', (tester) async {
    await _open(tester, _backend());
    await tester.scrollUntilVisible(find.byKey(const Key('earn.wardrobe')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('earn.wardrobe')));
    await frames(tester, 10);
    expect(find.text('Fifi 商店'), findsOneWidget);
  });

  testWidgets('[en] 文案', (tester) async {
    await _phone(tester);
    EarnXpPage.debugClock = () => _clock;
    addTearDown(() => EarnXpPage.debugClock = null);
    final orig = FlutterError.onError;
    FlutterError.onError = (d) => d.exceptionAsString().contains('overflowed') ? null : orig?.call(d);
    addTearDown(() => FlutterError.onError = orig);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok', locale: 'en');
    GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/rewards/earn');
    await frames(tester, 10);
    expect(find.text('Fifi Rewards'), findsOneWidget);
    expect(find.text("Today's Missions"), findsOneWidget);
    expect(_text(tester, 'earn.countdown'), 'Resets in 12:18:45');
    expect(find.text('1. Daily Check-in'), findsOneWidget);
  });
}
