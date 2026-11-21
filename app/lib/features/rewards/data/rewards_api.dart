import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../l10n/l10n.dart';

// F22-e / F22-f 最小 XP 体系（api-spec.md 5.10）。XP 为站内成长值，与券商资金、模拟盘、预测积分完全隔离。

int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

/// 双语名称（seed 配置）。
class LText {
  const LText(this.zh, this.en);
  factory LText.fromJson(Object? j) => j is Map ? LText('${j['zh'] ?? ''}', '${j['en'] ?? ''}') : const LText('', '');
  final String zh, en;
  String get text => isEnglish ? en : zh;
}

class RewardItem {
  const RewardItem({required this.id, required this.tier, required this.unlockTier, required this.xp, required this.image, required this.name, this.desc, this.placeholder = false, this.color});
  factory RewardItem.fromJson(Map<String, dynamic> j) => RewardItem(
    id: '${j['id']}',
    tier: _i(j['tier']),
    unlockTier: _i(j['unlockTier']),
    xp: _i(j['xp']),
    image: '${j['image'] ?? ''}',
    placeholder: j['placeholder'] == true,
    color: j['color'] is String ? j['color'] as String : null,
    name: LText.fromJson(j['name']),
    desc: j['desc'] == null ? null : LText.fromJson(j['desc']),
  );
  final String id;
  final int tier, unlockTier, xp;
  final String image;
  final bool placeholder;

  /// 待配图（image 为空）时的纯色占位，#RRGGBB。
  final String? color;

  /// 是否有内置素材图；无图时按 [color] 显示纯色占位并标注"待配图"。
  bool get hasImage => image.isNotEmpty;

  final LText name;
  final LText? desc;
}

class RewardTask {
  const RewardTask(this.id, this.xp, this.enabled, {this.complianceReview = false});
  final String id;
  final int xp;
  final bool enabled;
  final bool complianceReview;
}

class RewardsCatalog {
  const RewardsCatalog({required this.tierMins, required this.items, required this.bundles, required this.comingSoon, required this.tasks});
  factory RewardsCatalog.fromJson(Map<String, dynamic> j) {
    List<RewardItem> list(String k) => [for (final e in (j[k] as List? ?? const [])) RewardItem.fromJson((e as Map).cast<String, dynamic>())];
    return RewardsCatalog(
      tierMins: {for (final t in (j['tiers'] as List? ?? const [])) _i((t as Map)['tier']): _i(t['minXp'])},
      items: list('items'),
      bundles: list('bundles'),
      comingSoon: list('comingSoon'),
      tasks: [
        for (final e in (j['tasks'] as List? ?? const []))
          RewardTask('${(e as Map)['id']}', _i(e['xp']), e['enabled'] == true, complianceReview: e['complianceReview'] == true),
      ],
    );
  }
  final Map<int, int> tierMins;
  final List<RewardItem> items, bundles, comingSoon;
  final List<RewardTask> tasks;
}

class CheckinStatus {
  const CheckinStatus({required this.today, required this.checkedIn, required this.streak, required this.week, required this.resetAt, required this.xp, required this.balance, this.granted = 0});
  factory CheckinStatus.fromJson(Map<String, dynamic> j) => CheckinStatus(
    today: '${j['today'] ?? ''}',
    checkedIn: j['checkedIn'] == true,
    streak: _i(j['streak']),
    week: [for (final w in (j['week'] as List? ?? const [])) w == true],
    resetAt: DateTime.tryParse('${j['resetAt'] ?? ''}'),
    xp: _i(j['xp']),
    granted: _i(j['granted']),
    balance: _i(j['balance']),
  );
  final String today;
  final bool checkedIn;
  final int streak;
  final List<bool> week; // 周一至周日
  final DateTime? resetAt;
  final int xp, granted, balance;
}

class RewardsApi {
  RewardsApi(this._api);
  final ApiClient _api;

  Future<(int balance, int tier)> xp() async {
    final d = await _api.get('/rewards/xp') as Map<String, dynamic>;
    return (_i(d['balance']), _i(d['tier']));
  }

  Future<RewardsCatalog> catalog() async => RewardsCatalog.fromJson(await _api.get('/rewards/catalog') as Map<String, dynamic>);
  Future<CheckinStatus> checkinStatus() async => CheckinStatus.fromJson(await _api.get('/rewards/checkin') as Map<String, dynamic>);
  Future<CheckinStatus> checkin() async => CheckinStatus.fromJson(await _api.post('/rewards/checkin') as Map<String, dynamic>);
}

/// 全局 XP 余额（Fifi 页、商店、任务页的 XP 胶囊共用；签到后更新）。null = 尚未取到。
class XpBalance extends ChangeNotifier {
  XpBalance._();
  static final instance = XpBalance._();

  int? balance;
  int tier = 1;

  Future<void> refresh(ApiClient api) async {
    try {
      final (b, t) = await RewardsApi(api).xp();
      balance = b;
      tier = t;
      notifyListeners();
    } on ApiException {
      // 取不到时胶囊显示 —，不影响页面
    }
  }

  void set(int b) {
    balance = b;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    balance = null;
    tier = 1;
  }
}
