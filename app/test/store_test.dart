import 'dart:io';

import 'package:finx_app/app/theme.dart';
import 'package:finx_app/core/widgets/widgets.dart';
import 'package:finx_app/features/rewards/data/rewards_api.dart';
import 'package:finx_app/features/rewards/presentation/store_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

// F22-e：P-27 奖励 Tab = Fifi 商店（定稿 v3/store_final.png）。

FakeBackend _backend({int balance = 1493, int tier = 3, Map<String, dynamic>? catalog}) => FakeBackend()
  ..on('GET /rewards/catalog', (_) => FakeBackend.ok(catalog ?? rewardsCatalogSeed()))
  ..on('GET /me', (_) => FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': null, 'accountStatus': 'NONE'}))
  ..on('GET /rewards/xp', (_) => FakeBackend.ok({'balance': balance, 'tier': tier}));

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<FakeBackend> _open(WidgetTester tester, {int balance = 1493, int tier = 3, String locale = 'zh', Map<String, dynamic>? catalog}) async {
  await _phone(tester);
  final be = _backend(balance: balance, tier: tier, catalog: catalog);
  await pumpApp(tester, backend: be, storedToken: 'tok', locale: locale);
  await tester.tap(find.byKey(const Key('tab.rewards')));
  await tester.pumpAndSettle();
  return be;
}

Future<void> _selectTier(WidgetTester tester, int tier) async {
  await tester.tap(find.byKey(Key('store.tier.$tier')));
  await tester.pumpAndSettle();
}

String _status(WidgetTester tester, String id) => tester.widget<Text>(find.descendant(of: find.byKey(Key('store.item.$id.status')), matching: find.byType(Text))).data!;

void main() {
  test('seed 素材都已内置：商品、套装、敬请期待图片存在于 assets/brand/store/', () {
    final c = RewardsCatalog.fromJson(rewardsCatalogSeed());
    for (final i in [...c.items, ...c.bundles, ...c.comingSoon]) {
      if (i.hasImage) {
        expect(File(BrandAssets.storeItem(i.image)).existsSync(), isTrue, reason: i.image);
      } else {
        expect(i.placeholder, isTrue, reason: '无图商品须标占位（待配图）');
        expect(i.color, matches(RegExp(r'^#[0-9A-Fa-f]{6}$')), reason: i.id);
      }
      expect(i.name.zh.isNotEmpty && i.name.en.isNotEmpty, isTrue);
    }
    expect(File(BrandAssets.storeHero).existsSync(), isTrue);
    expect(
      [for (final i in c.items) (i.id, i.tier, i.xp)],
      [('stickers', 1, 100), ('badge', 1, 150), ('case', 2, 300), ('cap', 2, 400), ('jacket', 3, 800), ('vest', 3, 1200), ('bag', 3, 950), ('phones', 3, 2200)],
    );
    // 等级 1、2 各 2–4 件，真机不再空页
    for (final tier in [1, 2]) {
      expect(c.items.where((i) => i.tier == tier).length, inInclusiveRange(2, 4));
    }
    // 套装 = 整条横幅高清图；敬请期待 = 高清成品卡图（不再是占位）
    expect((c.bundles.single.xp, c.bundles.single.image, c.bundles.single.placeholder), (2600, 'bundle_banner', false));
    expect(
      [for (final i in c.comingSoon) (i.id, i.unlockTier, i.image, i.placeholder)],
      [('garage', 4, 'garage', false), ('home', 5, 'home', false), ('yacht', 5, 'yacht', false), ('jet', 6, 'jet', false)],
    );
    // 旧占位图保留备查
    for (final id in ['bundle', 'garage', 'home', 'yacht', 'jet']) {
      expect(File(BrandAssets.storeItem('${id}_placeholder')).existsSync(), isTrue, reason: id);
    }
  });

  test('待配图纯色：取 seed 色值，缺省 / 非法回落等级胶囊底色', () {
    expect(pendingArtColor('#FFC857'), const Color(0xFFFFC857));
    expect(pendingArtColor(null), StoreColors.tierBg);
    expect(pendingArtColor('red'), StoreColors.tierBg);
  });

  testWidgets('版式：Fifi 商店 + 真实 XP 胶囊、英雄横幅、默认选中有商品的最低等级（1）、切到等级 3 看四件商品、套装横幅、敬请期待、两个按钮', (tester) async {
    final be = await _open(tester);
    expect(find.text('Fifi 商店'), findsOneWidget);
    expect(find.text('Fifi 奖励'), findsNothing, reason: '圣诞版已撤下（SEASONAL_THEME 默认 off）');
    expect(tester.widget<Text>(find.byKey(const Key('xp.value'))).data, '1,493 XP');
    expect(be.requests.any((r) => r.url.path.endsWith('/rewards/xp')), isTrue);
    // 英雄横幅：原图直接显示（无容器裁切），只有投影
    final hero = find.byKey(const Key('store.hero'));
    expect(find.descendant(of: hero, matching: find.byType(ClipRRect)), findsNothing);
    expect(
      find.descendant(of: hero, matching: find.byType(ImageFiltered)),
      findsOneWidget,
      reason: '沿图形轮廓的投影',
    );
    expect(find.text('等级 4 🔒'), findsOneWidget);
    expect(find.text('梦想 🔒'), findsOneWidget);
    // 默认选中有商品的最低等级 = 等级 1：两件待配图小商品
    expect(find.text('等级 1 上新'), findsOneWidget);
    expect(find.byKey(const Key('store.empty')), findsNothing);
    expect(find.text('Fifi 贴纸包'), findsOneWidget);
    expect(find.text('★ 100 XP'), findsOneWidget);
    expect(find.byKey(const Key('store.art.pending.stickers')), findsOneWidget);
    expect(find.byKey(const Key('store.art.pending.badge')), findsOneWidget);
    expect(find.text('待配图'), findsNWidgets(2));
    expect(_status(tester, 'stickers'), '可兑换');
    await _selectTier(tester, 2);
    expect(find.text('Fifi 手机壳'), findsOneWidget);
    expect(find.text('棒球帽'), findsOneWidget);
    await _selectTier(tester, 3);
    expect(find.text('等级 3 上新'), findsOneWidget);
    expect(find.text('棒球夹克'), findsOneWidget);
    expect(find.text('待配图'), findsNothing);
    expect(find.text('★ 800 XP'), findsWidgets);
    expect(_status(tester, 'jacket'), '可兑换');
    expect(_status(tester, 'vest'), '可兑换');
    expect(_status(tester, 'bag'), '可兑换');
    expect(_status(tester, 'phones'), '等级 4 解锁');
    await tester.scrollUntilVisible(find.byKey(const Key('store.earnXp')), 200, scrollable: find.byType(Scrollable).first);
    // 套装：整条横幅原图，不再原生渲染标题 / 价格 / 按钮
    final bundle = find.byKey(const Key('store.bundle.analyst'));
    expect(find.descendant(of: bundle, matching: find.byKey(const Key('store.bundle.analyst.banner'))), findsOneWidget);
    expect((tester.widget<Image>(find.byKey(const Key('store.bundle.analyst.banner'))).image as AssetImage).assetName, BrandAssets.storeItem('bundle_banner'));
    expect(find.text('限定分析师套装'), findsNothing);
    expect(find.text('套装 · 2,600 XP'), findsNothing);
    expect(find.text('预 览'), findsNothing);
    expect(find.descendant(of: bundle, matching: find.byType(ClipRRect)), findsNothing);
    // 敬请期待：高清成品卡图原图显示（容器不裁切），锁角标叠加在图上
    for (final id in ['garage', 'home', 'yacht', 'jet']) {
      final card = find.byKey(Key('store.soon.$id'));
      expect(card, findsOneWidget);
      expect((tester.widget<Image>(find.byKey(Key('store.soon.$id.image'))).image as AssetImage).assetName, BrandAssets.storeItem(id));
      expect(find.descendant(of: card, matching: find.byType(ClipRRect)), findsNothing);
      expect(find.descendant(of: card, matching: find.byType(ClipRect)), findsNothing);
      final img = tester.getRect(find.byKey(Key('store.soon.$id.image')));
      final lock = tester.getRect(find.byKey(Key('store.soon.$id.lock')));
      expect(img.contains(lock.topLeft) && img.contains(lock.bottomRight), isTrue, reason: '锁角标叠在图内');
    }
    expect(find.text('✦ 在 Fifi 上预览'), findsOneWidget);
    expect(find.text('★ 赚取 XP'), findsOneWidget);
  });

  testWidgets('商品 / 套装点击 → 详情弹层"兑换即将开启"（不可兑换）；在 Fifi 上预览、锁定等级轻提示', (tester) async {
    await _open(tester);
    await _selectTier(tester, 3);
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
    expect(find.byKey(const Key('store.detail')), findsOneWidget, reason: '整张横幅可点 → 预览弹层');
    expect(find.descendant(of: find.byKey(const Key('store.detail')), matching: find.text('限定分析师套装')), findsOneWidget);
    expect(find.text('示意图，正式图片即将更新'), findsNothing, reason: '套装已换高清图');
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

  testWidgets('新用户 0 XP（真机空页回归）：等级 1 选中且有商品，2–4 带锁；待配图商品点开详情标注占位', (tester) async {
    await _open(tester, balance: 0, tier: 1);
    expect(tester.widget<Text>(find.byKey(const Key('xp.value'))).data, '0 XP');
    expect(find.text('等级 2 🔒'), findsOneWidget);
    expect(find.text('等级 1 上新'), findsOneWidget);
    expect(find.byKey(const Key('store.empty')), findsNothing);
    expect(find.byKey(const Key('store.item.stickers')), findsOneWidget);
    expect(find.byKey(const Key('store.item.badge')), findsOneWidget);
    expect(_status(tester, 'stickers'), 'XP 不足');
    expect(find.byKey(const Key('store.item.jacket')), findsNothing);
    await tester.tap(find.byKey(const Key('store.item.badge')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('store.detail')), matching: find.byKey(const Key('store.art.pending.badge'))), findsOneWidget);
    expect(find.text('示意图，正式图片即将更新'), findsOneWidget);
  });

  testWidgets('默认等级取有商品的最低等级；无商品等级显示空态"该等级商品即将上架"（中英）', (tester) async {
    final seed = rewardsCatalogSeed();
    final noLow = {
      ...seed,
      'items': [
        for (final i in seed['items'] as List)
          if ((i as Map)['tier'] == 3) i,
      ],
    };
    await _open(tester, balance: 5000, tier: 4, catalog: noLow);
    expect(find.text('等级 3 上新'), findsOneWidget, reason: '等级 1、2 无商品时默认跳到等级 3');
    expect(find.byKey(const Key('store.item.jacket')), findsOneWidget);
    await _selectTier(tester, 4);
    expect(find.byKey(const Key('store.empty')), findsOneWidget);
    expect(find.text('该等级商品即将上架'), findsOneWidget);
    await _selectTier(tester, 1);
    expect(find.text('该等级商品即将上架'), findsOneWidget);
  });

  testWidgets('英文：空态与待配图文案', (tester) async {
    await _open(tester, balance: 0, tier: 1, locale: 'en');
    expect(find.text('Fifi Sticker Pack'), findsOneWidget);
    expect(find.text('Art coming soon'), findsNWidgets(2));
  });

  testWidgets('英文：无商品等级空态', (tester) async {
    final seed = rewardsCatalogSeed();
    final noLow = {
      ...seed,
      'items': [
        for (final i in seed['items'] as List)
          if ((i as Map)['tier'] == 3) i,
      ],
    };
    await _open(tester, balance: 5000, tier: 4, locale: 'en', catalog: noLow);
    await _selectTier(tester, 4);
    expect(find.text('Items for this tier are coming soon'), findsOneWidget);
  });

  testWidgets('XP 不足：已解锁等级的商品显示"XP 不足"', (tester) async {
    await _open(tester, balance: 1000, tier: 3);
    await _selectTier(tester, 3);
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
