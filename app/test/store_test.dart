import 'dart:io';

import 'package:finx_app/app/theme.dart';
import 'package:finx_app/core/widgets/widgets.dart';
import 'package:finx_app/features/rewards/data/rewards_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// F22-e：P-27 奖励 Tab = Fifi 商店（定稿 v3/store_final.png）。

FakeBackend _backend({int balance = 1493, int tier = 3}) => FakeBackend()
  ..on(
    'GET /me',
    (_) => FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': null, 'accountStatus': 'NONE'}),
  )
  ..on('GET /rewards/xp', (_) => FakeBackend.ok({'balance': balance, 'tier': tier}));

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<FakeBackend> _open(WidgetTester tester, {int balance = 1493, int tier = 3, String locale = 'zh'}) async {
  await _phone(tester);
  final be = _backend(balance: balance, tier: tier);
  await pumpApp(tester, backend: be, storedToken: 'tok', locale: locale);
  await tester.tap(find.byKey(const Key('tab.rewards')));
  await tester.pumpAndSettle();
  return be;
}

String _status(WidgetTester tester, String id) =>
    tester.widget<Text>(find.descendant(of: find.byKey(Key('store.item.$id.status')), matching: find.byType(Text))).data!;

void main() {
  test('seed 素材都已内置：商品、套装、敬请期待图片存在于 assets/brand/store/', () {
    final c = RewardsCatalog.fromJson(rewardsCatalogSeed());
    for (final i in [...c.items, ...c.bundles, ...c.comingSoon]) {
      expect(File(BrandAssets.storeItem(i.image)).existsSync(), isTrue, reason: i.image);
      expect(i.name.zh.isNotEmpty && i.name.en.isNotEmpty, isTrue);
    }
    expect(File(BrandAssets.storeHero).existsSync(), isTrue);
    expect([for (final i in c.items) (i.id, i.xp)], [('jacket', 800), ('vest', 1200), ('bag', 950), ('phones', 2200)]);
    expect(c.bundles.single.xp, 2600);
    expect([for (final i in c.comingSoon) (i.id, i.unlockTier, i.placeholder)], [
      ('garage', 4, true),
      ('home', 5, true),
      ('yacht', 5, true),
      ('jet', 6, true),
    ]);
  });

  testWidgets('版式：Fifi 商店 + 真实 XP 胶囊、英雄横幅、等级 3 选中（4 / 梦想带锁）、四件商品、套装、敬请期待、两个按钮', (tester) async {
    final be = await _open(tester);
    expect(find.text('Fifi 商店'), findsOneWidget);
    expect(find.text('Fifi 奖励'), findsNothing, reason: '圣诞版已撤下（SEASONAL_THEME 默认 off）');
    expect(tester.widget<Text>(find.byKey(const Key('xp.value'))).data, '1,493 XP');
    expect(be.requests.any((r) => r.url.path.endsWith('/rewards/xp')), isTrue);
    // 英雄横幅：原图直接显示（无容器裁切），只有投影
    final hero = find.byKey(const Key('store.hero'));
    expect(find.descendant(of: hero, matching: find.byType(ClipRRect)), findsNothing);
    expect(find.descendant(of: hero, matching: find.byType(ImageFiltered)), findsOneWidget, reason: '沿图形轮廓的投影');
    expect(find.text('等级 4 🔒'), findsOneWidget);
    expect(find.text('梦想 🔒'), findsOneWidget);
    expect(find.text('等级 3 上新'), findsOneWidget);
    expect(find.text('棒球夹克'), findsOneWidget);
    expect(find.text('★ 800 XP'), findsWidgets);
    expect(_status(tester, 'jacket'), '可兑换');
    expect(_status(tester, 'vest'), '可兑换');
    expect(_status(tester, 'bag'), '可兑换');
    expect(_status(tester, 'phones'), '等级 4 解锁');
    await tester.scrollUntilVisible(find.byKey(const Key('store.earnXp')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('限定分析师套装'), findsOneWidget);
    expect(find.text('套装 · 2,600 XP'), findsOneWidget);
    for (final id in ['garage', 'home', 'yacht', 'jet']) {
      expect(find.byKey(Key('store.soon.$id')), findsOneWidget);
    }
    expect(find.text('✦ 在 Fifi 上预览'), findsOneWidget);
    expect(find.text('★ 赚取 XP'), findsOneWidget);
  });

  testWidgets('商品 / 套装点击 → 详情弹层"兑换即将开启"（不可兑换）；在 Fifi 上预览、锁定等级轻提示', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('store.item.vest')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store.detail')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('store.detail')), matching: find.text('交易马甲')), findsOneWidget);
    expect(find.text('兑换即将开启'), findsOneWidget);
    expect(tester.widget<AppButton>(find.byKey(const Key('store.detail.redeem'))).onPressed, isNull);
    await tester.tapAt(const Offset(200, 100)); // 关闭弹层
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('store.tier.4')));
    await tester.pump();
    expect(find.text('达到等级 4 后解锁'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.scrollUntilVisible(find.byKey(const Key('store.bundle.analyst')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('store.bundle.analyst')));
    await tester.pumpAndSettle();
    expect(find.text('示意图，正式图片即将更新'), findsOneWidget, reason: '套装为占位图');
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('store.previewOnFifi')), 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200)); // 移出底部 Tab 栏遮挡区
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store.detail')), findsNothing, reason: '弹层已关闭');
    await tester.tap(find.byKey(const Key('store.previewOnFifi')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('在 Fifi 上预览即将上线'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('新用户 0 XP：等级 1 选中、2–4 带锁，等级 1 商品即将上新；切换等级 2 需先解锁', (tester) async {
    await _open(tester, balance: 0, tier: 1);
    expect(tester.widget<Text>(find.byKey(const Key('xp.value'))).data, '0 XP');
    expect(find.text('等级 2 🔒'), findsOneWidget);
    expect(find.text('等级 1 上新'), findsOneWidget);
    expect(find.byKey(const Key('store.empty')), findsOneWidget);
    expect(find.byKey(const Key('store.item.jacket')), findsNothing);
  });

  testWidgets('XP 不足：已解锁等级的商品显示"XP 不足"', (tester) async {
    await _open(tester, balance: 1000, tier: 3);
    expect(_status(tester, 'jacket'), '可兑换');
    expect(_status(tester, 'vest'), 'XP 不足');
  });

  testWidgets('赚取 XP 按钮进入任务页路由', (tester) async {
    await _open(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('store.earnXp')), 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('store.earnXp')));
    await tester.pumpAndSettle();
    expect(GoRouter.of(tester.element(find.byType(Scaffold).last)).state.matchedLocation, '/rewards/earn');
  });
}
