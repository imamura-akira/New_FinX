import 'package:finx_app/app/appearance.dart';
import 'package:finx_app/app/theme.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'fixtures.dart';
import 'helpers.dart';

// F21 深色模式：外观选择（跟随系统 / 浅色 / 深色）、色板令牌、关键页面深浅两套渲染、双语 × 双主题抽查。

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void _ignoreOverflow() {
  final orig = FlutterError.onError;
  FlutterError.onError = (d) => d.exceptionAsString().contains('overflowed') ? null : orig?.call(d); // 测试字体宽，见 l10n_test
  addTearDown(() => FlutterError.onError = orig);
}

Future<void> _go(WidgetTester tester, String loc) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(loc);
  await frames(tester, 15);
}

Color get _scaffoldBg => Theme.of(find.byType(Scaffold).evaluate().last).scaffoldBackgroundColor;

/// 页面上明显的浅色块（卡片 / 面板 / 输入框底等）：亮度高且基本不透明。深色下不应出现。
/// 渐变按钮、图片、白色文字不在此列（只检查实色填充的背景）。
List<String> _lightSurfaces(WidgetTester tester) {
  final bad = <String>[];
  void check(Color? c, String what) {
    if (c == null || c.a < .6) return;
    if (c.computeLuminance() > .6) bad.add('$what $c');
  }

  for (final w in tester.widgetList<Container>(find.byType(Container))) {
    final d = w.decoration;
    if (d is BoxDecoration && d.gradient == null) check(d.color, 'Container');
    check(w.color, 'Container.color');
  }
  for (final w in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    final d = w.decoration;
    if (d is BoxDecoration && d.gradient == null) check(d.color, 'DecoratedBox');
  }
  for (final w in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
    check(w.color, 'ColoredBox');
  }
  for (final w in tester.widgetList<Material>(find.byType(Material))) {
    if (w.type != MaterialType.transparency) check(w.color, 'Material');
  }
  return bad;
}

const _dark = AppPalette.dark;

void main() {
  test('深色色板与 theme.md 第 10 节一致', () {
    expect(_dark.bg, const Color(0xFF141220));
    expect(_dark.surface, const Color(0xFF1E1B2E));
    expect(_dark.line, const Color(0xFF2A2740));
    expect(_dark.text, const Color(0xFFF2F0FA));
    expect(_dark.muted, const Color(0xFF9B95B5));
    expect(_dark.primary, const Color(0xFF8F7BF8));
    expect(_dark.up, const Color(0xFF22C55E));
    expect(_dark.down, const Color(0xFFF87171));
    // 浅色保持原值
    expect(AppPalette.light.bg, const Color(0xFFF6F5FC));
    expect(AppPalette.light.primary, const Color(0xFF6C5BF5));
    // 渐变与主按钮两套不变
    expect(AppGradients.grad.colors.first, const Color(0xFF5A57EE));
  });

  test('AppColors.apply 切换色板；模块令牌随之变化', () {
    addTearDown(() => AppColors.apply(Brightness.light));
    expect(AppColors.apply(Brightness.light), isFalse);
    final lightPaper = PaperColors.bg;
    expect(AppColors.apply(Brightness.dark), isTrue);
    expect(AppColors.isDark, isTrue);
    expect(AppColors.bg, _dark.bg);
    expect(PaperColors.bg, isNot(lightPaper));
    expect(WelcomeColors.orangeDeep, const Color(0xFFF58500), reason: '欢迎页橙色不变');
    expect(AppColors.apply(Brightness.dark), isFalse);
  });

  test('外观选择持久化：默认跟随系统，选深色后下次启动读取为深色', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    final c = AppearanceController.instance;
    addTearDown(c.reset);
    await c.load();
    expect(c.value, ThemeMode.system);
    await c.select(ThemeMode.dark);
    c.reset();
    await c.load();
    expect(c.value, ThemeMode.dark);
    await c.select(ThemeMode.system);
    c.reset();
    await c.load();
    expect(c.value, ThemeMode.system);
  });

  testWidgets('跟随系统：iOS 切换深浅色时实时生效', (tester) async {
    await _phone(tester);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await pumpApp(tester, backend: openedUserBackend(), storedToken: 'tok', appearance: ThemeMode.system);
    expect(_scaffoldBg, AppPalette.light.bg);
    expect(AppColors.isDark, isFalse);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await frames(tester, 5);
    expect(AppColors.isDark, isTrue);
    expect(_scaffoldBg, _dark.bg);
    expect(_lightSurfaces(tester), isEmpty);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await frames(tester, 5);
    expect(AppColors.isDark, isFalse);
    expect(_scaffoldBg, AppPalette.light.bg);
  });

  testWidgets('账户抽屉"外观"：跟随系统 / 浅色 / 深色，选择后立即生效', (tester) async {
    await _phone(tester);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await pumpApp(tester, backend: openedUserBackend(), storedToken: 'tok', appearance: ThemeMode.system);
    await tester.tap(find.byKey(const Key('home.avatar')));
    await tester.pumpAndSettle();
    final drawerList = find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('drawer.appearance')), 200, scrollable: drawerList);
    await tester.drag(drawerList, const Offset(0, -300)); // 移出底部 Tab 栏遮挡区
    await tester.pumpAndSettle();
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('跟随系统'), findsWidgets, reason: '当前选择显示在副标题');
    await tester.tap(find.byKey(const Key('drawer.appearance')));
    await tester.pumpAndSettle();
    for (final m in ['system', 'light', 'dark']) {
      expect(find.byKey(Key('appearance.$m')), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('appearance.dark')));
    await frames(tester, 15);
    expect(AppearanceController.instance.value, ThemeMode.dark);
    expect(AppColors.isDark, isTrue, reason: '系统为浅色时手动选深色仍为深色');
    expect(_scaffoldBg, _dark.bg);
    expect(find.text('深色'), findsWidgets, reason: '副标题更新为深色');
    expect(_lightSurfaces(tester), isEmpty, reason: '抽屉在深色下无浅色块');

    await AppearanceController.instance.select(ThemeMode.light);
    await frames(tester, 15);
    expect(AppColors.isDark, isFalse);
    expect(_scaffoldBg, AppPalette.light.bg);
  });

  group('关键页面深浅两套渲染', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('[${mode.name}] 已开户用户的主要页面', (tester) async {
        await _phone(tester);
        await pumpApp(tester, backend: openedUserBackend(), storedToken: 'tok', appearance: mode);
        final want = mode == ThemeMode.dark ? _dark.bg : AppPalette.light.bg;
        for (final (route, zhText, _) in keyPages) {
          await _go(tester, route);
          expect(find.textContaining(zhText), findsWidgets, reason: '$route 应显示"$zhText"');
          expect(_scaffoldBg, want, reason: '$route 背景');
          if (mode == ThemeMode.dark) expect(_lightSurfaces(tester), isEmpty, reason: '$route 深色下出现浅色块');
          if (mode == ThemeMode.light && route == '/home') expect(_lightSurfaces(tester), isNotEmpty, reason: '检测本身有效：浅色下能检出白色卡片');
        }
        await _go(tester, '/home');
      });
    }

    testWidgets('[dark] 未登录欢迎页与登录页、开户 / KYC 英文模块', (tester) async {
      await _phone(tester);
      await pumpApp(tester, backend: openedUserBackend(opened: false), storedToken: 'tok', appearance: ThemeMode.dark);
      for (final step in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
        await _go(tester, '/onboarding/$step');
        expect(_scaffoldBg, _dark.bg, reason: '开户步骤 $step');
        expect(_lightSurfaces(tester), isEmpty, reason: '开户步骤 $step 深色下出现浅色块');
      }
    });

    testWidgets('[dark] 欢迎页：深底，字标与橙色趋势线不变', (tester) async {
      await _phone(tester);
      await pumpApp(tester, backend: FakeBackend(), appearance: ThemeMode.dark);
      expect(find.byKey(const Key('welcome.logo')), findsOneWidget);
      expect(_scaffoldBg, _dark.bg);
      expect(WelcomeColors.markHalo.computeLuminance(), greaterThan(.5), reason: '深色下字标外为浅色光晕');
      expect(_lightSurfaces(tester), isEmpty);
      await tester.tap(find.byKey(const Key('welcome.login')));
      await tester.pumpAndSettle();
      expect(_scaffoldBg, _dark.bg);
      expect(_lightSurfaces(tester), isEmpty, reason: '登录页输入框为深色');
    });
  });

  group('双语 × 双主题抽查 4 个核心页', () {
    const core = [
      ('/home', '购买力', 'Buying Power'),
      ('/market', '市场情绪', 'Market Sentiment'),
      ('/trade/AAPL', '订单类型', 'Order Type'),
      ('/funding/deposit', '选择入金方式', 'Choose a deposit method'),
    ];
    for (final lang in ['zh', 'en']) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('[$lang · ${mode.name}]', (tester) async {
          await _phone(tester);
          if (lang == 'en') _ignoreOverflow();
          await pumpApp(tester, backend: openedUserBackend(), storedToken: 'tok', locale: lang, appearance: mode);
          for (final (route, zh, en) in core) {
            await _go(tester, route);
            expect(find.textContaining(lang == 'zh' ? zh : en), findsWidgets, reason: route);
            expect(_scaffoldBg, mode == ThemeMode.dark ? _dark.bg : AppPalette.light.bg);
            if (mode == ThemeMode.dark) expect(_lightSurfaces(tester), isEmpty, reason: route);
          }
          await _go(tester, '/home');
        });
      }
    }
  });
}
