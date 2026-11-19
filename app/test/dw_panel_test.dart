import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

FakeBackend _backend({bool withDw = true}) => FakeBackend()
  ..on(
    'GET /me',
    (_) => FakeBackend.ok({'email': 'demo@example.com', 'loginProvider': 'EMAIL', 'applicationId': 'app-1', 'accountStatus': 'APPROVED'}),
  )
  ..on(
    'GET /application/status',
    (_) => FakeBackend.ok({
      'kycStatus': 'KYC_APPROVED',
      'issues': [],
      'requiredDocs': [],
      'accountStatus': 'OPEN',
      'accountNo': 'TEST000001',
      'applicationRef': 'FX-1',
      'submittedAt': '2026-11-19T12:00:00Z',
      'submitState': 'SUBMITTED',
    }),
  )
  ..on(
    'GET /account',
    (_) => FakeBackend.ok({
      'accountId': 'a1',
      'accountNo': 'TEST000001',
      'status': 'OPEN',
      'accountType': 'LIVE',
      'tradingType': 'CASH',
      'managementType': 'SELF',
      if (withDw)
        'dw': {
          'userId': 'dw-user-test-1',
          'accountId': 'dw-acc-test-1',
          'accountNo': 'TEST000001',
          'kycStatus': 'KYC_APPROVED',
          'syncedAt': '2026-11-20T01:02:03Z',
        },
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

Future<void> _openDrawer(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.tap(find.byKey(const Key('home.avatar')));
  await tester.pumpAndSettle();
}

Future<void> _scrollDrawerTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first,
  );
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('DEMO_MODE：抽屉底部显示 DW 沙盒凭证，展开后可逐项复制', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpApp(tester, backend: _backend(), storedToken: 'tok', demo: true);
    await _openDrawer(tester);
    await _scrollDrawerTo(tester, find.byKey(const Key('drawer.dwPanel')));
    expect(find.text('DW 沙盒凭证'), findsOneWidget);
    expect(find.text('dw-user-test-1'), findsNothing, reason: '默认折叠');

    await tester.tap(find.byKey(const Key('drawer.dwPanel.toggle')));
    await tester.pumpAndSettle();
    await _scrollDrawerTo(tester, find.byKey(const Key('drawer.dw.最近同步')));
    for (final v in ['dw-user-test-1', 'dw-acc-test-1', 'KYC_APPROVED']) {
      expect(find.text(v), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('drawer.dw.userID')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('drawer.dw.accountID')));
    await tester.pump();
    expect(copied, ['dw-user-test-1', 'dw-acc-test-1']);
  });

  testWidgets('DEMO_MODE 但后端未返回 dw：展开后提示，不报错', (tester) async {
    await pumpApp(tester, backend: _backend(withDw: false), storedToken: 'tok', demo: true);
    await _openDrawer(tester);
    await _scrollDrawerTo(tester, find.byKey(const Key('drawer.dwPanel')));
    await tester.tap(find.byKey(const Key('drawer.dwPanel.toggle')));
    await tester.pumpAndSettle();
    expect(find.textContaining('暂无 DW 编号'), findsOneWidget);
  });

  testWidgets('正式构建（DEMO_MODE 未开）：完全不渲染 DW 沙盒凭证', (tester) async {
    await pumpApp(tester, backend: _backend(), storedToken: 'tok', demo: false);
    await _openDrawer(tester);
    await _scrollDrawerTo(tester, find.byKey(const Key('drawer.logout')));
    expect(find.byKey(const Key('drawer.dwPanel')), findsNothing);
    expect(find.text('DW 沙盒凭证'), findsNothing);
  });
}
