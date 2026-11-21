import 'dart:async';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/sound/ui_sound.dart';
import '../../../core/widgets/widgets.dart';
import '../data/rewards_api.dart';
import 'reward_widgets.dart';
import '../../../l10n/l10n.dart';

/// F22-f 赚取 XP 任务页（定稿 design/reward-design/v3/earn_xp.png，参考 earn_xp.html）。
/// - 页头"Fifi 奖励任务" + XP 胶囊 + 头像；英雄卡 xp_hero.png（透明整卡，原图显示，仅投影）。
/// - 今日任务 + 重置倒计时（距下一个美东零点，逐秒走；归零后刷新状态）。
/// - 五项任务（XP 取后端 seed）：本期只有"每日签到"可完成——点击 → POST /rewards/checkin，XP 入账、行变绿勾、轻提示音；
///   其余四项点击提示"即将开启"。"本月储蓄目标"为入金类任务，上线前需合规审核（上线门槛登记）。
/// - 连续打卡：签到驱动，真实连续天数与本周（周一至周日）七圆点。
/// - "前往 Fifi 衣橱" → 商店页。
class EarnXpPage extends StatefulWidget {
  const EarnXpPage({super.key});

  /// 测试用时钟（倒计时）；null = 系统时间。
  @visibleForTesting
  static DateTime Function()? debugClock;

  static const taskOrder = ['checkin', 'lesson', 'checkup', 'savings', 'share'];

  @override
  State<EarnXpPage> createState() => _EarnXpPageState();
}

class _EarnXpPageState extends State<EarnXpPage> {
  RewardsApi? _api;
  CheckinStatus? _status;
  Map<String, RewardTask> _tasks = const {};
  bool _failed = false;
  bool _busy = false;
  Timer? _tick;
  DateTime? _resetAt;

  DateTime _now() => (EarnXpPage.debugClock ?? DateTime.now)();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api == null) {
      _api = RewardsApi(AppScope.of(context).api);
      _load();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    final r = _resetAt;
    if (r != null && !_now().isBefore(r)) {
      _resetAt = null;
      _load(); // 美东零点：新的一天，任务重置
    }
    setState(() {});
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_api!.checkinStatus(), _api!.catalog()]);
      if (!mounted) return;
      final s = results[0] as CheckinStatus;
      final c = results[1] as RewardsCatalog;
      setState(() {
        _status = s;
        _tasks = {for (final t in c.tasks) t.id: t};
        _resetAt = nextEasternMidnight(_now());
        _failed = false;
      });
      XpBalance.instance.set(s.balance);
    } on ApiException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _checkin() async {
    final s = _status;
    if (s == null || _busy) return;
    if (s.checkedIn) {
      showToast(context, t.earnAlreadyCheckedIn);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await _api!.checkin();
      if (!mounted) return;
      setState(() => _status = r);
      XpBalance.instance.set(r.balance);
      if (r.granted > 0) {
        UiSound.play(UiSound.reminderDing);
        HapticFeedback.lightImpact();
        showToast(context, t.earnCheckedIn(r.granted));
      } else {
        showToast(context, t.earnAlreadyCheckedIn);
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _countdown() {
    final r = _resetAt ?? nextEasternMidnight(_now());
    var d = r.difference(_now());
    if (d.isNegative) d = Duration.zero;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            RewardHeader(title: t.earnTitle, onEarnPage: true, back: context.canPop(), trailing: const FifiAvatar(size: 36)),
            const ShadowedImage(BrandAssets.xpHero, key: Key('earn.hero')),
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(t.earnToday, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const Spacer(),
                  Text(
                    t.earnResetIn(_countdown()),
                    key: const Key('earn.countdown'),
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.sub, fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.timer_outlined, size: 13, color: AppColors.sub),
                ],
              ),
            ),
            if (_failed && _status == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: TextButton(onPressed: _load, child: Text(t.earnLoadFailed)),
                ),
              )
            else if (_status == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              for (final (i, id) in EarnXpPage.taskOrder.indexed) _taskRow(i, id),
              _streak(_status!),
            ],
            const SizedBox(height: 4),
            _cta(),
          ],
        ),
      ),
    ),
  );

  (String, String) _taskText(String id) => switch (id) {
    'checkin' => (t.earnTask1, t.earnTask1Desc),
    'lesson' => (t.earnTask2, t.earnTask2Desc),
    'checkup' => (t.earnTask3, t.earnTask3Desc),
    'savings' => (t.earnTask4, t.earnTask4Desc),
    _ => (t.earnTask5, t.earnTask5Desc),
  };

  Widget _taskRow(int i, String id) {
    final task = _tasks[id];
    final (title, desc) = _taskText(id);
    final done = id == 'checkin' && _status!.checkedIn;
    final xp = task?.xp ?? 0;
    return GestureDetector(
      key: Key('earn.task.$id'),
      onTap: () {
        if (id == 'checkin' && (task?.enabled ?? false)) {
          _checkin();
        } else {
          showToast(context, t.earnTaskSoon);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: done ? StoreColors.doneRowBg : AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              key: Key('earn.task.$id.check'),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.primary : null,
                border: done ? null : Border.all(color: StoreColors.ring, width: 2.5),
              ),
              child: done ? Icon(Icons.check_rounded, size: 16, color: AppColors.onAccent) : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}. $title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(color: done ? StoreColors.xpDoneBg : StoreColors.remindBg, borderRadius: BorderRadius.circular(999)),
              child: Text(
                t.earnXpPlus(xp),
                key: Key('earn.task.$id.xp'),
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: done ? AppColors.up : AppColors.primary),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: StoreColors.ring),
          ],
        ),
      ),
    );
  }

  Widget _streak(CheckinStatus s) {
    final labels = t.earnWeekdays.split(',');
    // 今日在本周中的序号（周一 = 0），用于区分"今日未签"（描边）与"已过未签"（灰）
    final todayIdx = (toEastern(_now()).weekday + 6) % 7;
    return Container(
      key: const Key('earn.streak'),
      margin: const EdgeInsets.only(top: 5, bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: StoreColors.fireBg, borderRadius: BorderRadius.circular(12)),
            child: const Text('🔥', style: TextStyle(fontSize: 19)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(t.earnStreak(s.streak), key: const Key('earn.streak.days'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
                ),
                const SizedBox(height: 1),
                Text(
                  s.streak > 0 ? t.earnKeepGoing : t.earnStartStreak,
                  maxLines: 2,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.sub),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Column(
              key: Key('earn.week.$i'),
              children: [
                _dot(i < s.week.length && s.week[i], i == todayIdx, i < todayIdx),
                const SizedBox(height: 3),
                Text(labels.length == 7 ? labels[i] : '', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.sub)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 已签：实心紫 + ✓；今日未签：紫描边；已过未签 / 未到：灰描边。
  Widget _dot(bool checked, bool today, bool past) => Container(
    width: 19,
    height: 19,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: checked ? AppColors.primary : null,
      border: checked ? null : Border.all(color: today ? AppColors.primary : StoreColors.ring, width: 2),
    ),
    child: checked ? Icon(Icons.check_rounded, size: 11, color: AppColors.onAccent) : null,
  );

  Widget _cta() => GestureDetector(
    key: const Key('earn.wardrobe'),
    onTap: () => context.go('/rewards'), // 商店页（Tab），无论从商店还是 XP 胶囊进入
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: StoreColors.grad,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .32), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Text('👜 ${t.earnGoWardrobe}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onAccent)),
    ),
  );
}
