import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import 'reward_widgets.dart';

/// F22-d P-26 Fifi 页（定稿 design/reward-design/v3/fifi_v2.png，参考 fifi_v2.html）。
/// "Fifi 量化助手 / Fifi Quant Agent" + 副题 + XP 胶囊（真实余额）+ 头像；紫粉英雄卡"即将上线" + fifi_quant.png；
/// 六张编号带锁功能卡（点击轻提示即将上线）；"开启上线提醒"复用提醒逻辑（"叮" + 已开启态，仅本次运行有效）。
/// 合规：功能为规划展示，上线前需评估是否构成投资建议（页脚小字保留）。
class FifiPage extends StatefulWidget {
  const FifiPage({super.key});

  @override
  State<FifiPage> createState() => _FifiPageState();
}

class _FifiPageState extends State<FifiPage> {
  bool _reminder = false;

  List<(IconData, String, String)> get _features => [
    (Icons.bar_chart_rounded, t.fifiFeat1, t.fifiFeat1Desc),
    (Icons.swap_vert_rounded, t.fifiFeat2, t.fifiFeat2Desc),
    (Icons.search_rounded, t.fifiFeat3, t.fifiFeat3Desc),
    (Icons.warning_amber_rounded, t.fifiFeat4, t.fifiFeat4Desc),
    (Icons.show_chart_rounded, t.fifiFeat5, t.fifiFeat5Desc),
    (Icons.menu_book_rounded, t.fifiFeat6, t.fifiFeat6Desc),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          RewardHeader(title: t.fifiTitle, subtitle: t.fifiSubtitle, trailing: const FifiAvatar()),
          _hero(),
          const SizedBox(height: 16),
          for (var r = 0; r < 3; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _feature(r * 2)),
                    const SizedBox(width: 11),
                    Expanded(child: _feature(r * 2 + 1)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 7),
          LaunchReminderButton(
            key: const Key('p26.sub'),
            on: _reminder,
            label: t.fifiRemind,
            onLabel: t.fifiRemindOn,
            onChanged: (v) => setState(() => _reminder = v),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Text(
              t.fifiRemindCaption,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.hint),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '${t.mastersNotIncludedInThe}\n${t.mastersBeforeLaunchWeNeed}',
              key: const Key('p26.compliance'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, color: AppColors.faint, height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _hero() => Container(
    key: const Key('p26.hero'),
    constraints: const BoxConstraints(minHeight: 210),
    decoration: BoxDecoration(
      gradient: StoreColors.fifiHero,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .3), blurRadius: 30, offset: const Offset(0, 14))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned(
            right: 4,
            bottom: 0,
            child: Image.asset(BrandAssets.fifiQuant, key: const Key('p26.fifi'), height: 200, semanticLabel: 'Fifi'),
          ),
          Positioned(top: 22, right: 170, child: _spark(14)),
          Positioned(bottom: 46, right: 12, child: _spark(11)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: LayoutBuilder(
              builder: (context, c) => SizedBox(
                width: c.maxWidth * .55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(t.fifiHeroTitle, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.onAccent, height: 1.25)),
                    ),
                    const SizedBox(height: 12),
                    Text(t.fifiHeroBody, style: TextStyle(fontSize: 13.5, color: AppColors.onAccent.withValues(alpha: .95), height: 1.7)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _spark(double size) => Text('✦', style: TextStyle(fontSize: size, color: AppColors.onAccent.withValues(alpha: .9)));

  Widget _feature(int k) {
    final (icon, title, desc) = _features[k];
    return GestureDetector(
      key: Key('p26.feat.$k'),
      onTap: () => showToast(context, t.featureComingSoon(title)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppColors.pill, shape: BoxShape.circle),
              child: Icon(icon, size: 19, color: AppColors.primary),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${k + 1}. $title',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.4),
                  ),
                ),
                Icon(Icons.lock_rounded, key: Key('p26.feat.$k.lock'), size: 13, color: AppColors.allocEtf),
              ],
            ),
            const SizedBox(height: 4),
            Text(desc, style: TextStyle(fontSize: 11, color: AppColors.sub, height: 1.55)),
          ],
        ),
      ),
    );
  }
}
