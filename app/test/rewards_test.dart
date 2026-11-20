import 'dart:typed_data';

import 'package:finx_app/core/sound/ui_sound.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// F16：P-27 奖励 Tab 圣诞季限定版式。

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

/// 记录提示音与触感反馈调用。
(List<String>, List<String>) _mockPlatform(WidgetTester tester) {
  final sounds = <String>[];
  final haptics = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(UiSound.channel, (call) async {
    sounds.add('${(call.arguments as Map)['asset']}');
    return true;
  });
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') haptics.add('${call.arguments}');
    return null;
  });
  addTearDown(() {
    messenger.setMockMethodCallHandler(UiSound.channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return (sounds, haptics);
}

Future<void> _openRewards(WidgetTester tester) async {
  await _phone(tester);
  await pumpApp(tester, backend: _backend(), storedToken: 'tok');
  await tester.tap(find.byKey(const Key('tab.奖励')));
  await tester.pumpAndSettle();
}

Future<void> _showNotify(WidgetTester tester) =>
    tester.scrollUntilVisible(find.byKey(const Key('p27.notify')), 200, scrollable: find.byType(Scrollable).first);

Future<void> _tapNotify(WidgetTester tester) async {
  await _showNotify(tester);
  await tester.tap(find.byKey(const Key('p27.notify')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('P-27 版式：标题、英雄区、四个等级胶囊、圣诞新手礼四张奖品卡与底部说明', (tester) async {
    await _openRewards(tester);
    expect(find.text('Fifi 奖励'), findsOneWidget);
    expect(find.byKey(const Key('p27.xp')), findsOneWidget);
    expect(find.text('圣诞 · 新年限定'), findsOneWidget);
    expect(find.textContaining('Fifi 圣诞商店'), findsOneWidget);
    expect(find.byKey(const Key('p27.cat')), findsOneWidget);
    for (var lv = 1; lv <= 4; lv++) {
      expect(find.byKey(Key('p27.level.$lv')), findsOneWidget);
    }
    expect(find.textContaining('梦想', findRichText: true), findsOneWidget); // 仅英雄区说明文字，无"梦想"等级
    expect(find.text('圣诞新手礼'), findsOneWidget);
    expect(find.text('等级 1 解锁'), findsOneWidget);
    for (final (name, xp) in [('FinX 运动水壶', 150), ('Fifi 圣诞绒帽', 200), ('无线耳机', 600), ('Fifi 斜挎包', 250)]) {
      final card = find.byKey(Key('p27.item.$name'));
      await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
      expect(find.descendant(of: card, matching: find.text('$xp XP')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('即将推出')), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.byKey(const Key('p27.note')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('奖励内容为演示示例，正式奖品与兑换规则以上线公告为准'), findsOneWidget);
  });

  testWidgets('P-27 展示态：奖品卡与等级 2–4 点击只轻提示"即将推出"，不切换内容', (tester) async {
    await _openRewards(tester);
    await tester.tap(find.byKey(const Key('p27.level.3')));
    await tester.pump();
    expect(find.text('等级 3 即将推出'), findsOneWidget);
    expect(find.byKey(const Key('p27.item.FinX 运动水壶')), findsOneWidget); // 仍是等级 1 的奖品
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await tester.tap(find.byKey(const Key('p27.item.FinX 运动水壶')));
    await tester.pump();
    expect(find.text('即将推出'), findsWidgets);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('P-27 开启上线提醒：切换已开启 / 未开启，开启时提示音与触感各一次，取消不出声', (tester) async {
    await _openRewards(tester);
    final (sounds, haptics) = _mockPlatform(tester); // 页面就绪后再拦截平台通道
    await _showNotify(tester);
    expect(find.text('🔔 开启上线提醒'), findsOneWidget);

    await _tapNotify(tester);
    expect(find.text('✓ 已开启提醒'), findsOneWidget);
    expect(find.text('🔔 开启上线提醒'), findsNothing);
    expect(sounds, [UiSound.reminderDing]);
    expect(haptics, ['HapticFeedbackType.lightImpact']);

    await _tapNotify(tester); // 再按一次取消
    expect(find.text('🔔 开启上线提醒'), findsOneWidget);
    expect(sounds, hasLength(1));

    await _tapNotify(tester); // 再次开启：再播一次
    expect(find.text('✓ 已开启提醒'), findsOneWidget);
    expect(sounds, [UiSound.reminderDing, UiSound.reminderDing]);
    expect(haptics.where((h) => h == 'HapticFeedbackType.lightImpact'), hasLength(2));
  });

  testWidgets('P-27 提醒状态仅本地：重建页面后恢复未开启', (tester) async {
    await _openRewards(tester);
    _mockPlatform(tester);
    await _tapNotify(tester);
    expect(find.text('✓ 已开启提醒'), findsOneWidget);
    // 模拟重启：先卸载再重新挂载整个 App
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await tester.tap(find.byKey(const Key('tab.奖励')));
    await tester.pumpAndSettle();
    await _showNotify(tester);
    expect(find.text('🔔 开启上线提醒'), findsOneWidget);
  });

  test('提示音资源：reminder_ding.wav 为短促 WAV（< 0.5 秒）', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final data = await rootBundle.load(UiSound.reminderDing);
    final b = data.buffer.asUint8List();
    expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF');
    final rate = data.getUint32(24, Endian.little);
    final bytesPerSec = data.getUint32(28, Endian.little);
    final seconds = (b.length - 44) / bytesPerSec;
    expect(rate, 44100);
    expect(seconds, inInclusiveRange(0.3, 0.5));
  });
}
