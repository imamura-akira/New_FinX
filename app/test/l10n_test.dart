import 'dart:convert';
import 'dart:io';

import 'package:finx_app/core/api/api_client.dart';
import 'package:finx_app/core/format.dart';
import 'package:finx_app/features/onboarding/presentation/step_pages.dart';
import 'package:finx_app/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'fixtures.dart';
import 'helpers.dart';

// F18：中英双语——ARB 完整性、无遗漏硬编码中文、错误码映射、日期格式、关键页面中英各渲染一次。

final _han = RegExp(r'[一-鿿]');

/// 去掉 Dart 源码中的注释，返回其余文本里的字符串字面量（含中文的）。
List<String> _hanLiterals(String src) {
  final out = <String>[];
  var i = 0;
  while (i < src.length) {
    if (src.startsWith('//', i)) {
      final e = src.indexOf('\n', i);
      i = e < 0 ? src.length : e;
      continue;
    }
    if (src.startsWith('/*', i)) {
      i = src.indexOf('*/', i) + 2;
      continue;
    }
    final c = src[i];
    if (c == "'" || c == '"') {
      var j = i + 1;
      while (j < src.length && src[j] != c) {
        j += src[j] == r'\' ? 2 : 1;
      }
      final lit = src.substring(i, j + 1);
      if (_han.hasMatch(lit)) out.add(lit);
      i = j + 1;
      continue;
    }
    i++;
  }
  return out;
}

Map<String, dynamic> _arb(String lang) => jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

Set<String> _placeholders(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

/// 当前界面上所有文字（Text / RichText / EditableText 提示等）。
List<String> _visibleTexts(WidgetTester tester) => [
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) w.text.toPlainText(),
  for (final w in tester.widgetList<EditableText>(find.byType(EditableText))) w.controller.text,
];

/// 英文页面测试：测试字体（Ahem）每个字符占满一个字号宽，英文文案在测试中会比真机宽约一倍，
/// 这里只忽略布局溢出报错（真机版式另行在模拟器上目检），其他错误照常失败。
void _ignoreOverflow() {
  final orig = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) return;
    orig?.call(d);
  };
  addTearDown(() => FlutterError.onError = orig);
}

void _expectNoChinese(WidgetTester tester, String where) {
  final bad = _visibleTexts(tester).where((s) => _han.hasMatch(s) && s != '简体中文').toList();
  expect(bad, isEmpty, reason: '$where 英文模式下仍有中文：$bad');
}



Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _go(WidgetTester tester, String loc) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(loc);
  await frames(tester, 15);
}


void main() {
  group('ARB 与源码', () {
    test('中英 ARB 键一致、占位符一致、英文无中文', () {
      final zh = _arb('zh'), en = _arb('en');
      final zk = zh.keys.where((k) => !k.startsWith('@')).toSet();
      final ek = en.keys.where((k) => !k.startsWith('@')).toSet();
      expect(ek, zk);
      for (final k in zk.where((k) => k != '@@locale')) {
        expect(_placeholders(en[k] as String), _placeholders(zh[k] as String), reason: k);
        if (k != 'langZh' && k != 'langTitle') {
          expect(_han.hasMatch(en[k] as String), isFalse, reason: '英文文案含中文：$k');
        }
      }
    });

    test('lib/ 无遗漏的硬编码中文（注释、ARB 目录、原生语言名除外）', () {
      final allowed = {
        'lib/l10n/l10n.dart', // 后端已知中文提示的映射目录（原文 → 文案键）
      };
      final leaks = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        final p = f.path.replaceAll(r'\', '/');
        if (!p.endsWith('.dart') || p.contains('/generated/') || allowed.contains(p)) continue;
        for (final lit in _hanLiterals(f.readAsStringSync())) {
          if (p.endsWith('onboarding/domain/options.dart') && (lit == "'简体中文'" || lit == "'繁體中文'")) continue; // 语言原生名称
          leaks.add('$p: $lit');
        }
      }
      expect(leaks, isEmpty, reason: leaks.join('\n'));
    });
  });

  group('规则', () {
    test('系统语言解析：zh → 中文，其余 → 英文', () {
      expect(resolveLocale(const Locale('zh', 'TW')), const Locale('zh'));
      expect(resolveLocale(const Locale('en', 'US')), const Locale('en'));
      expect(resolveLocale(const Locale('ja')), const Locale('en'));
      expect(resolveLocale(null), const Locale('en'));
    });

    test('报错：已知提示精确映射；按错误码通用文案；英文模式不显示中文原文', () {
      debugSetLocale(const Locale('en'));
      expect(ApiException(code: 40901, message: '交易账户尚未开立').message, "Your brokerage account hasn't been opened yet.");
      expect(ApiException(code: 42201, message: '超过某某限额').message, t.errLimit);
      expect(ApiException(code: 50001, message: '').message, t.errDwFailed);
      expect(ApiException(code: 40102, message: 'Session expired').message, 'Session expired', reason: '英文原文无映射时兜底');
      expect(ApiException(code: 42200, message: 'x', fields: const [FieldError('amount', '金额必须大于 0')]).fieldMap['amount'], t.errFieldInvalid);
      debugSetLocale(const Locale('zh'));
      expect(ApiException(code: 40901, message: '交易账户尚未开立').message, '交易账户尚未开立');
      expect(ApiException(code: 42201, message: '超过某某限额').message, '超过某某限额', reason: '中文模式保留后端的具体中文提示');
      expect(ApiException(code: 50001, message: '').message, '券商服务暂时不可用，请稍后重试');
    });

    test('日期：中文 2026-11-19 14:05，英文 11/19/2026 2:05 PM；金额一致', () {
      final d = DateTime(2026, 11, 19, 14, 5);
      debugSetLocale(const Locale('zh'));
      expect(fmtDateTime(d), '2026-11-19 14:05');
      expect(fmtDate(d), '2026-11-19');
      expect(fmtUsd(1234.56), r'$1,234.56');
      debugSetLocale(const Locale('en'));
      expect(fmtDateTime(d), '11/19/2026 2:05 PM');
      expect(fmtDate(d), '11/19/2026');
      expect(fmtTime(DateTime(2026, 1, 1, 0, 7)), '12:07 AM');
      expect(fmtUsd(1234.56), r'$1,234.56');
      debugSetLocale(const Locale('zh'));
    });
  });

  group('关键页面中英各渲染一次', () {
    for (final lang in ['zh', 'en']) {
      testWidgets('[$lang] 已开户用户的主要页面', (tester) async {
        await _phone(tester);
        if (lang == 'en') _ignoreOverflow();
        await pumpApp(tester, backend: openedUserBackend(), storedToken: 'tok', locale: lang);
        for (final (route, zhText, enText) in keyPages) {
          await _go(tester, route);
          final want = lang == 'zh' ? zhText : enText;
          expect(_visibleTexts(tester).any((s) => s.contains(want)), isTrue, reason: '$route 应显示"$want"');
          if (lang == 'en') _expectNoChinese(tester, route);
        }
        await _go(tester, '/home');
      });
    }

    testWidgets('[en] 未登录欢迎页与登录页、Tab 名', (tester) async {
      await _phone(tester);
      _ignoreOverflow();
      await pumpApp(tester, backend: FakeBackend(), locale: 'en');
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Browse Markets'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
      _expectNoChinese(tester, 'P-01');
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      expect(find.text('Get Code'), findsOneWidget);
      _expectNoChinese(tester, 'P-02');
    });

    testWidgets('[en] Tab 名为 Assets / Markets / Masters / Fifi / Rewards；模拟盘标识为英文', (tester) async {
      await _phone(tester);
      _ignoreOverflow();
      await pumpApp(tester, backend: openedUserBackend(opened: false), storedToken: 'tok', locale: 'en');
      for (final l in ['Assets', 'Markets', 'Masters', 'Fifi', 'Rewards']) {
        expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(l)), findsOneWidget);
      }
      await tester.tap(find.descendant(of: find.byKey(const Key('mode.switch')), matching: find.text('Paper')));
      await frames(tester, 10);
      expect(find.textContaining('Paper Trading'), findsWidgets);
      _expectNoChinese(tester, '模拟盘');
    });

    testWidgets('[en] 开户与 KYC 模块保持英文（P-03 起）', (tester) async {
      await _phone(tester);
      await pumpApp(tester, backend: openedUserBackend(opened: false), storedToken: 'tok', locale: 'zh');
      // 步骤路由为 a–g（原先误用 /onboarding/basic，渲染为空页，检查形同虚设）
      for (final step in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
        await _go(tester, '/onboarding/$step');
        expect(find.byType(OnboardingStepPage), findsOneWidget, reason: '开户步骤 $step 应渲染');
        _expectNoChinese(tester, '开户模块（中文模式）步骤 $step');
      }
    });
  });

  testWidgets('账户抽屉切换语言：立即生效并持久化选择；跟随系统按系统语言', (tester) async {
    await _phone(tester);
    _ignoreOverflow();
    await pumpApp(tester, backend: openedUserBackend(), storedToken: 'tok', locale: 'zh');
    expect(find.text('购买力'), findsWidgets);
    await tester.tap(find.byKey(const Key('home.avatar')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('drawer.language')), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('简体中文'), findsOneWidget, reason: '当前选择显示在语言项副标题');
    await tester.tap(find.byKey(const Key('drawer.language')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language.en')));
    await frames(tester, 15);
    expect(LocaleController.instance.value, 'en');
    expect(find.text('Buying Power'), findsWidgets);
    expect(find.text('购买力'), findsNothing);
    // 路由外壳（底部 Tab）与抽屉同时切换，抽屉保持打开（状态保留）
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Assets')), findsOneWidget);
    expect(find.text('资产'), findsNothing);
    expect(find.byKey(const Key('drawer.language')), findsOneWidget);
    // 跟随系统：测试环境系统语言为英文
    await LocaleController.instance.select(null);
    await frames(tester, 15);
    expect(find.text('Buying Power'), findsWidgets);
    await LocaleController.instance.select('zh');
    await frames(tester, 15);
    expect(find.text('购买力'), findsWidgets);
  });
}
