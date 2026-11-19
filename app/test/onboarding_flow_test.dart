import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';
import 'onboarding_validators_test.dart' show validData;

FakeBackend _backend({String status = 'NONE', Map<String, dynamic>? data}) {
  final be = FakeBackend()
    ..on(
      'GET /me',
      (_) => FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': null, 'accountStatus': status}),
    )
    ..on(
      'GET /application',
      (_) => FakeBackend.ok({
        'applicationId': status == 'NONE' ? null : 'app-1',
        'status': status,
        'step': null,
        'data': data ?? {},
        'disclosures': [],
        'kyc': null,
        'documents': [],
      }),
    )
    ..on('PUT /application/draft', (_) => FakeBackend.ok({'savedAt': '2026-11-19T12:00:00Z'}));
  return be;
}

Future<void> _openOnboarding(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('home.openAccount')));
  await tester.pumpAndSettle();
}

/// 列表为懒加载：先滚动到目标再操作。
Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    // 回到顶部后向下查找（目标可能在当前位置上方）
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> _continue(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('onboarding.continue')));
  await tester.tap(find.byKey(const Key('onboarding.continue')));
  await tester.pumpAndSettle();
}

bool _hasHan(WidgetTester tester) {
  final han = RegExp(r'[一-鿿]');
  const allowed = {'简体中文', '繁體中文'}; // 语言选项以各语言自称显示（同原型）
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    final s = t.data ?? t.textSpan?.toPlainText() ?? '';
    if (han.hasMatch(s) && !allowed.contains(s)) return true;
  }
  return false;
}

void main() {
  testWidgets('从首页进入开户：P-03a 英文、STEP 进度、Continue 保存草稿', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final be = _backend();
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _openOnboarding(tester);
    expect(find.text("Let's open your account"), findsOneWidget);
    expect(find.text('Start application'), findsOneWidget);
    expect(_hasHan(tester), isFalse, reason: '开户模块界面一律英文');

    await _continue(tester);
    expect(be.lastBody('PUT /application/draft')['step'], 'a');
    expect(find.text('Your identity'), findsOneWidget);
    expect(find.text('STEP 2 OF 10'), findsOneWidget, reason: '尚未确定美国纳税人身份时含证件上传步骤（共 10 步）');
  });

  testWidgets('P-03b 空表 Continue：显示英文字段错误且不保存', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final be = _backend(status: 'DRAFT');
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _openOnboarding(tester);
    expect(find.text('Resume application'), findsOneWidget);
    await _continue(tester); // a → b
    final putsBefore = be.requests.where((r) => r.method == 'PUT').length;

    await _continue(tester); // b 校验失败
    expect(find.text('Use standard ASCII letters only (no é, и, Chinese, etc.)'), findsNWidgets(2));
    expect(find.text('Select your date of birth'), findsOneWidget);
    expect(find.text('Select your citizenship'), findsOneWidget);
    expect(be.requests.where((r) => r.method == 'PUT').length, putsBefore, reason: '校验失败不应保存');
    expect(_hasHan(tester), isFalse);

    // 输入非 ASCII 名后错误仍在；改为合法后该字段错误消失
    await tester.enterText(find.byKey(const Key('f.firstName')), 'Jane');
    await tester.pump();
    expect(find.text('Use standard ASCII letters only (no é, и, Chinese, etc.)'), findsOneWidget);
  });

  testWidgets('服务端字段错误（42200）映射到输入框', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final data = validData();
    final be = _backend(status: 'DRAFT', data: data)
      ..on('PUT /application/draft', (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body['step'] == 'b') {
          return FakeBackend.err(422, 42200, 'Please fix the highlighted fields', {
            'fields': [
              {'field': 'phone', 'reason': 'Enter a valid phone number with country code'},
            ],
          });
        }
        return FakeBackend.ok({'savedAt': '2026-11-19T12:00:00Z'});
      });
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _openOnboarding(tester);
    await _continue(tester); // a → b（资料完整）
    await _continue(tester); // b → 服务端拒绝
    expect(find.text('Enter a valid phone number with country code'), findsOneWidget);
    expect(find.text('Your identity'), findsOneWidget, reason: '应停留在当前步');
  });

  testWidgets('完整资料：P-05 全部确认后 P-30 提交，请求体含披露与签名', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final be = _backend(status: 'DRAFT', data: validData())
      ..on('POST /application/submit', (_) => FakeBackend.ok({'applicationRef': 'FX261119-TEST', 'submittedAt': '2026-11-19T12:00:00Z'}));
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await _openOnboarding(tester);
    for (final title in [
      'Your identity',
      'Your tax information',
      'Your home address',
      'Employment & finances',
      'A few compliance questions',
      'Your account type',
    ]) {
      await _continue(tester);
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('STEP 7 OF 9'), findsOneWidget, reason: '美国纳税人无证件上传步骤');
    await _continue(tester); // g → p05（美国纳税人跳过 P-04）
    expect(find.text('Disclosures & signature'), findsOneWidget);
    expect(_hasHan(tester), isFalse);

    // 未全部确认时 Continue 不可用
    final btn = tester.widget<TextButton>(
      find.descendant(of: find.byKey(const Key('onboarding.continue')), matching: find.byType(TextButton)),
    );
    expect(btn.onPressed, isNull);

    for (final id in [
      'termsOfUse',
      'customerAgreement',
      'marketDataAgreement',
      'privacyPolicy',
      'dataSharing',
      'p_terms',
      'p_privacy',
      'p_risk',
      'esign',
    ]) {
      await _scrollTo(tester, find.byKey(Key('d.$id')));
      await tester.tap(find.descendant(of: find.byKey(Key('d.$id')), matching: find.byType(Checkbox)));
      await tester.pump();
    }
    await _scrollTo(tester, find.byKey(const Key('d.rule14b.no')));
    await tester.tap(find.byKey(const Key('d.rule14b.no')));
    await _scrollTo(tester, find.byKey(const Key('d.signature')));
    await tester.enterText(find.byKey(const Key('d.signature')), 'Someone Else');
    await tester.pump();
    expect(find.text('Signature must match your legal name'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('d.signature')), 'demo tester');
    await tester.pump();
    await _continue(tester); // → P-30
    expect(find.text('Review & submit'), findsWidgets);
    expect(find.text('•••-••-7890'), findsOneWidget, reason: '税号打码显示');
    await _scrollTo(tester, find.text('Professional, scientific & technical services'));
    expect(find.text('Professional, scientific & technical services'), findsOneWidget);
    expect(find.text('Employment income'), findsOneWidget);

    await _continue(tester); // Submit
    final body = be.lastBody('POST /application/submit');
    expect(body['signatureName'], 'demo tester');
    final ds = (body['disclosures'] as List).cast<Map>();
    expect(ds.firstWhere((x) => x['id'] == 'termsOfUse')['accepted'], true);
    expect(ds.firstWhere((x) => x['id'] == 'rule14b')['accepted'], false);
    expect(ds.firstWhere((x) => x['id'] == 'esign')['accepted'], true);
    expect(ds.any((x) => x['id'] == 'extendedHoursAgreement'), isFalse, reason: '未勾选的可选协议不发送');
    expect(find.text('Application submitted'), findsOneWidget);
  });

  testWidgets('已提交的申请再次进入开户页显示提示', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      backend: _backend(status: 'SUBMITTED'),
      storedToken: 'tok',
    );
    expect(find.byKey(const Key('home.openAccount')), findsNothing);
    expect(find.byKey(const Key('home.status.link')), findsOneWidget);
  });
}
