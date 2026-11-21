import 'dart:typed_data';

import 'package:finx_app/core/sound/ui_sound.dart';
import 'package:finx_app/app/theme.dart';
import 'package:finx_app/features/auth/presentation/welcome_ak_page.dart';
import 'package:finx_app/features/auth/presentation/welcome_page.dart' show LaunchIntro;
import 'package:finx_app/l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';


// 【F22-g 归档】F20 P-01 AK 品牌版（已撤下，代码与素材留档）。保留单元测试与独立挂载渲染，防止归档代码腐坏。
// 原说明：冷启动入场（字标与 slogan 淡入、趋势线描画、5 个高点"滴"声音调递增、光点呼吸、注册按钮放大一次）。

/// 记录提示音调用。
List<String> _mockSound(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(UiSound.channel, (call) async {
    calls.add('${(call.arguments as Map)['asset']}');
    return true;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(UiSound.channel, null));
  return calls;
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

TrendLinePainter _painter(WidgetTester tester) => tester.widget<CustomPaint>(find.byKey(const Key('welcome.trend'))).painter! as TrendLinePainter;

void main() {
  test('高点：3 个局部高点 + 拐点 + 终点共 5 个，按路径长度递增，终点为 1', () {
    final p = trendPeakFractions();
    expect(p, hasLength(5));
    for (var i = 1; i < p.length; i++) {
      expect(p[i], greaterThan(p[i - 1]));
    }
    expect(p.last, closeTo(1, 1e-9));
    expect(UiSound.peakTicks, hasLength(5));
  });

  testWidgets('归档页独立挂载：冷启动描线 5 声"滴"，画完 progress = 1', (tester) async {
    await _phone(tester);
    final sound = _mockSound(tester);
    LaunchIntro.resetForTest();
    AppColors.apply(Brightness.light);
    debugSetLocale(const Locale('zh'));
    await tester.pumpWidget(MaterialApp(home: const AkWelcomePage(), theme: buildTheme(AppPalette.light)));
    await tester.pumpAndSettle();
    expect(sound, UiSound.peakTicks);
    expect(_painter(tester).progress, 1);
    expect(find.text('美股与 ETF 投资\n开户、入金、交易，一站完成。'), findsOneWidget);
  });

  test('"滴"声素材：5 个脚本生成的短 WAV（约 100 ms）', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final a in UiSound.peakTicks) {
      final data = await rootBundle.load(a);
      expect(String.fromCharCodes(data.buffer.asUint8List(0, 4)), 'RIFF');
      final seconds = (data.lengthInBytes - 44) / data.getUint32(28, Endian.little);
      expect(seconds, inInclusiveRange(.08, .12), reason: a);
    }
  });
}
