import 'package:finx_app/core/widgets/celebration.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

Map<String, dynamic> _status(String kyc, {String? account, String submittedAt = '2026-11-19T12:00:00Z'}) => {
  'kycStatus': kyc,
  'issues': [],
  'requiredDocs': [],
  'accountStatus': account,
  'accountNo': account == null ? null : 'TEST000001',
  'applicationRef': 'FX-TEST',
  'submittedAt': submittedAt,
  'submitState': 'SUBMITTED',
};

FakeBackend _backend(List<Map<String, dynamic>> statuses) {
  var n = 0;
  return FakeBackend()
    ..on(
      'GET /me',
      (_) =>
          FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': 'app-1', 'accountStatus': 'SUBMITTED'}),
    )
    ..on('GET /application/status', (_) => FakeBackend.ok(statuses[(n++).clamp(0, statuses.length - 1)]))
    ..on(
      'GET /account',
      (_) => FakeBackend.ok({
        'accountId': 'a',
        'accountNo': 'TEST000001',
        'status': 'OPEN',
        'accountType': 'LIVE',
        'tradingType': 'CASH',
        'managementType': 'SELF',
      }),
    )
    ..on(
      'GET /account/money',
      (_) => FakeBackend.ok({
        'cash': 0,
        'settledCash': 0,
        'buyingPower': 0,
        'cashAvailableForWithdrawal': 0,
        'unsettled': 0,
        'pendingDeposits': 0,
        'withheldForSeasoning': 0,
      }),
    );
}

Future<List<String>> _setup(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  Celebration.resetForTest();
  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') haptics.add('${call.arguments}');
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return haptics;
}

Future<void> _frames(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('P-06：从核验中变为账户 OPEN 时播放一次庆祝与触感，轮询刷新与重新进入不重播', (tester) async {
    final haptics = await _setup(tester);
    final be = _backend([
      _status('KYC_PROCESSING'), // 首页
      _status('KYC_PROCESSING'), // P-06 首次加载
      _status('KYC_APPROVED', account: 'OPEN'), // 轮询：开户成功
    ]);
    await pumpApp(tester, backend: be, storedToken: 'tok');
    await tester.tap(find.byKey(const Key('home.status.link')));
    await _frames(tester, 1000);
    expect(find.byType(ConfettiBurst), findsNothing, reason: '核验中不播放');

    await tester.pump(const Duration(seconds: 5)); // 轮询 → OPEN
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Your live account is open'), findsOneWidget);
    expect(find.byType(ConfettiBurst), findsOneWidget);
    expect(tester.widget<ConfettiBurst>(find.byType(ConfettiBurst)).level, CelebrationLevel.full);
    expect(
      find.descendant(of: find.byType(IgnorePointer), matching: find.byType(ConfettiBurst)),
      findsOneWidget,
      reason: '不阻挡内容',
    );
    expect(haptics, ['HapticFeedbackType.mediumImpact']);

    await _frames(tester, 2200); // 约 2 秒后自动消失
    expect(find.byType(ConfettiBurst), findsNothing);

    // 账户已开立后停止轮询；离开再进入 P-06 也不重播
    await tester.tap(find.byKey(const Key('p06.later')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home.avatar')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 400)); // 关闭抽屉
    await tester.pumpAndSettle();
    expect(find.byType(ConfettiBurst), findsNothing);
    expect(haptics.length, 1);
  });

  testWidgets('P-06：很早之前已开户（首次加载即 OPEN）不播放', (tester) async {
    final haptics = await _setup(tester);
    final be = _backend([_status('KYC_APPROVED', account: 'OPEN', submittedAt: '2026-10-01T00:00:00Z')]);
    await pumpApp(tester, backend: be, storedToken: 'tok');
    // 已开户时首页不显示进度入口，直接打开 P-06
    GoRouter.of(tester.element(find.byKey(const Key('home.hero')))).go('/application/status');
    await _frames(tester, 1000);
    expect(find.text('Your live account is open'), findsOneWidget);
    expect(find.byType(ConfettiBurst), findsNothing);
    expect(haptics, isEmpty);
  });

  testWidgets('Celebration：同一 key 只播放一次', (tester) async {
    await _setup(tester);
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const Scaffold(body: Text('page'));
          },
        ),
      ),
    );
    expect(Celebration.show(ctx, key: 'k1'), isTrue);
    await tester.pump();
    expect(find.byType(ConfettiBurst), findsOneWidget);
    expect(Celebration.show(ctx, key: 'k1'), isFalse);
    await tester.pump();
    expect(find.byType(ConfettiBurst), findsOneWidget);
    await _frames(tester, 2200);
    expect(find.byType(ConfettiBurst), findsNothing);
  });

  testWidgets('Celebration：系统"减弱动态效果"时不播放动画', (tester) async {
    await _setup(tester);
    late BuildContext ctx;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold(body: Text('page'));
            },
          ),
        ),
      ),
    );
    Celebration.show(ctx, key: 'reduced');
    await tester.pump();
    expect(find.byType(ConfettiBurst), findsNothing);
  });
}
