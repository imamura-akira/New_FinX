import 'package:finx_app/core/sound/ui_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

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

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(Key('tab.$label')));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, String key) => tester.getTopLeft(find.byKey(Key(key))).dy;
double _left(WidgetTester tester, String key) => tester.getTopLeft(find.byKey(Key(key))).dx;

void main() {
  testWidgets('P-23 股票大师：按收益排序、切换最近更新、个股机会筛选，底部标注演示数据', (tester) async {
    await _phone(tester);
    final (be, _, _) = await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _tab(tester, 'masters');
    expect(find.text('看看大机构在买什么'), findsOneWidget);
    // 收益最高：晨湾资管（+21.30%）排第一，北岸资本第二
    expect(find.text('+21.30%'), findsOneWidget);
    expect(_left(tester, 'p23.inst.i4'), lessThan(_left(tester, 'p23.inst.i1')));
    expect(find.byKey(const Key('p23.inst.i7')), findsNothing, reason: '收益最低的松林全球不在前 6');

    await tester.tap(find.text('最近更新'));
    await tester.pumpAndSettle();
    expect(_top(tester, 'p23.inst.i1'), lessThan(_top(tester, 'p23.inst.i4')), reason: '11-16 更新的排在第一行，11-15 的在第二行');

    await _scrollTo(tester, find.byKey(const Key('p23.filter.CONTRA')));
    expect(find.byKey(const Key('p23.opp.NVDA')), findsOneWidget);
    await tester.tap(find.byKey(const Key('p23.filter.CONTRA')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('p23.opp.AMD')), findsOneWidget);
    expect(find.byKey(const Key('p23.opp.NVDA')), findsNothing);
    // 最新价来自虚拟行情接口（不新增后端接口）
    expect(
      be.requests.any((r) => r.url.path.endsWith('/market/quotes') && (r.url.queryParameters['symbols'] ?? '').contains('AMD')),
      isTrue,
    );

    await _scrollTo(tester, find.byKey(const Key('demo.note')));
    expect(find.textContaining('演示数据'), findsWidgets);
  });

  testWidgets('P-24：全部机构按收益排序；机构详情显示前五大持仓', (tester) async {
    await _phone(tester);
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _tab(tester, 'masters');
    await tester.tap(find.byKey(const Key('p23.more')));
    await tester.pumpAndSettle();
    expect(find.text('全部机构'), findsOneWidget);
    await tester.tap(find.byKey(const Key('p24.sort.ret')));
    await tester.pumpAndSettle();
    expect(_top(tester, 'p24.row.i4'), lessThan(_top(tester, 'p24.row.i1')));
    expect(_top(tester, 'p24.row.i1'), lessThan(_top(tester, 'p24.row.i7')));

    await tester.tap(find.byKey(const Key('p24.row.i1')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('p24.name'))).data, '北岸资本');
    expect(find.text('前五大持仓（示例）'), findsOneWidget);
    for (final s in ['AAPL', 'MSFT']) {
      expect(find.byKey(Key('quote.$s')), findsOneWidget);
    }
  });

  testWidgets('P-26 Fifi（F22-d 定稿 fifi_v2）：标题副题 + 真实 XP + 头像、英雄卡即将上线、六张编号带锁卡（轻提示）、开启上线提醒（叮 + 已开启态）', (tester) async {
    await _phone(tester);
    final sounds = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(UiSound.channel, (c) async {
      sounds.add('${(c.arguments as Map)['asset']}');
      return true;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(UiSound.channel, null));
    await pumpApp(tester, backend: _backend(), storedToken: 'tok');
    await _tab(tester, 'fifi');
    expect(find.text('Fifi 量化助手'), findsOneWidget);
    expect(find.text('你的智能投资助理'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('xp.value'))).data, '1,493 XP');
    expect(find.text('即将上线'), findsOneWidget);
    expect(find.byKey(const Key('p26.fifi')), findsOneWidget);
    const titles = ['1. 持仓体检', '2. 持有或卖出', '3. 个股研究', '4. 风险预警', '5. 量化信号', '6. 跟 Fifi 学投资'];
    for (var k = 0; k < 6; k++) {
      await _scrollTo(tester, find.byKey(Key('p26.feat.$k')));
      expect(find.descendant(of: find.byKey(Key('p26.feat.$k')), matching: find.text(titles[k])), findsOneWidget);
      expect(find.byKey(Key('p26.feat.$k.lock')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('p26.feat.0')));
    await tester.pump();
    expect(find.text('持仓体检即将上线'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await _scrollTo(tester, find.byKey(const Key('p26.compliance')));
    expect(find.textContaining('首期不做，待合规评估'), findsOneWidget, reason: '合规提示保留为页脚小字');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('reminder.label'))).data, '🔔 开启上线提醒');
    await tester.tap(find.byKey(const Key('reminder.button')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('reminder.label'))).data, '✓ 已开启上线提醒');
    expect(sounds, ['assets/sounds/reminder_ding.wav']);
    await tester.tap(find.byKey(const Key('reminder.button')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('reminder.label'))).data, '🔔 开启上线提醒');
    expect(sounds, hasLength(1), reason: '取消不出声');
  });
}
