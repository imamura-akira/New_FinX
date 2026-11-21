import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/widgets.dart';
import '../data/rewards_api.dart';
import 'reward_widgets.dart';
import '../../../l10n/l10n.dart';

/// F22-e P-27 奖励 Tab = Fifi 商店（定稿 design/reward-design/v3/store_final.png，参考 store_v2.html）。
/// - 英雄横幅 st_hero_full.png：透明通道整卡 PNG，原图直接显示，不加容器裁切，仅加投影；中英文都用这张。
/// - 等级胶囊 1–4 + 梦想：高于当前等级的带锁（点按轻提示）；默认选中当前等级。
/// - 商品 / 套装 / 敬请期待与等级门槛来自后端 seed（GET /rewards/catalog）；点击商品或套装 → 详情弹层（兑换即将开启）。
/// - "在 Fifi 上预览"轻提示即将上线；"赚取 XP" → F22-f 任务页。XP 胶囊为真实余额（GET /rewards/xp）。
/// 圣诞限定版（F16）保留在 rewards_page.dart，由 AppConfig.seasonalTheme（SEASONAL_THEME，默认 off）切换。
class StorePage extends StatefulWidget {
  const StorePage({super.key});

  /// 等级页签：1–4 与"梦想"（5，代表 5 级及以上）。
  static const tabs = [1, 2, 3, 4, 5];

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  RewardsCatalog? _catalog;
  bool _failed = false;
  int? _tab; // null = 跟随当前等级

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_catalog == null && !_failed) _load();
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    try {
      final c = await RewardsApi(api).catalog();
      if (mounted) {
        setState(() {
          _catalog = c;
          _failed = false;
        });
      }
    } on ApiException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_load(), XpBalance.instance.refresh(AppScope.of(context).api)]);
  }

  int get _userTier => XpBalance.instance.tier;

  int get _selected => _tab ?? _userTier.clamp(1, 4);

  void _tapTab(int tier) {
    if (tier > _userTier) {
      showToast(context, t.storeTierLocked(tier));
      return;
    }
    setState(() => _tab = tier);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListenableBuilder(
          listenable: XpBalance.instance,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
            children: [
              RewardHeader(
                title: t.storeTitle,
                back: context.canPop(),
                trailing: IconButton(
                  key: const Key('store.search'),
                  tooltip: t.marketSearch,
                  icon: Icon(Icons.search_rounded, color: AppColors.sub),
                  onPressed: () => showToast(context, t.storeSearchSoon),
                ),
              ),
              const ShadowedImage(BrandAssets.storeHero, key: Key('store.hero')),
              const SizedBox(height: 14),
              _tiers(),
              const SizedBox(height: 14),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: TextButton(onPressed: _load, child: Text(t.homeCouldnTRefreshPlease)),
                  ),
                )
              else if (_catalog == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ..._content(_catalog!),
              const SizedBox(height: 6),
              _cta(),
              const SizedBox(height: 10),
              _cta2(),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  t.storeDemoNote,
                  key: const Key('store.note'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.faint, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _tiers() => Row(
    children: [
      for (final (i, tier) in StorePage.tabs.indexed) ...[if (i > 0) const SizedBox(width: 7), Expanded(child: _tierChip(tier))],
    ],
  );

  Widget _tierChip(int tier) {
    final locked = tier > _userTier;
    final on = !locked && tier == _selected;
    final label = tier == 5 ? t.storeDream : t.storeTier(tier);
    return GestureDetector(
      key: Key('store.tier.$tier'),
      onTap: () => _tapTab(tier),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: on ? StoreColors.grad : null,
          color: on ? null : (locked ? StoreColors.lockedBg : StoreColors.tierBg),
          borderRadius: BorderRadius.circular(999),
          boxShadow: on ? [BoxShadow(color: AppColors.primary.withValues(alpha: .3), blurRadius: 14, offset: const Offset(0, 6))] : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            locked ? '$label 🔒' : label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? AppColors.onAccent : (locked ? StoreColors.lockedFg : AppColors.primary)),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, {Key? key}) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 10),
    child: Row(
      key: key,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        const SizedBox(width: 6),
        Text('✦', style: TextStyle(fontSize: 13, color: AppColors.primary)),
      ],
    ),
  );

  List<Widget> _content(RewardsCatalog c) {
    final tier = _selected;
    final items = [
      for (final i in c.items)
        if (i.tier == tier) i,
    ];
    final bundles = [
      for (final b in c.bundles)
        if (b.tier == tier) b,
    ];
    return [
      _section(t.storeTierNew(tier), key: const Key('store.section.new')),
      if (items.isEmpty && bundles.isEmpty)
        Container(
          key: const Key('store.empty'),
          height: 120,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
          child: Text(
            t.storeTierEmpty,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.hint),
          ),
        ),
      ..._rows(items, (i) => _productCard(i)),
      if (items.isNotEmpty) const SizedBox(height: 8),
      for (final b in bundles) _bundleCard(b),
      _section(t.storeComingSoon, key: const Key('store.section.soon')),
      ..._rows(c.comingSoon, (i) => _soonCard(i)),
      const SizedBox(height: 10),
    ];
  }

  /// 每行 4 张，等高。
  List<Widget> _rows(List<RewardItem> list, Widget Function(RewardItem) card) => [
    for (var r = 0; r < list.length; r += 4)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var k = 0; k < 4; k++) ...[if (k > 0) const SizedBox(width: 8), Expanded(child: r + k < list.length ? card(list[r + k]) : const SizedBox())],
            ],
          ),
        ),
      ),
  ];

  BoxDecoration get _cardDeco => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 14, offset: const Offset(0, 5))],
  );

  (String, Color, Color) _status(RewardItem i) {
    if (i.unlockTier > _userTier) return (t.storeUnlockAt(i.unlockTier), StoreColors.mutedChipBg, StoreColors.mutedChipFg);
    if ((XpBalance.instance.balance ?? 0) < i.xp) return (t.storeNotEnoughXp, StoreColors.mutedChipBg, StoreColors.mutedChipFg);
    return (t.storeAvailable, StoreColors.availBg, AppColors.up);
  }

  Widget _productCard(RewardItem i) {
    final (label, bg, fg) = _status(i);
    return GestureDetector(
      key: Key('store.item.${i.id}'),
      onTap: () => _detail(i),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 9),
        decoration: _cardDeco,
        child: Column(
          children: [
            SizedBox(
              height: 74,
              child: Image.asset(BrandAssets.storeItem(i.image), fit: BoxFit.contain, semanticLabel: i.name.text),
            ),
            const SizedBox(height: 6),
            Text(
              i.name.text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.3),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '★ ${fmtXp(i.xp)} XP',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 5),
            Container(
              key: Key('store.item.${i.id}.status'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bundleCard(RewardItem b) => GestureDetector(
    key: Key('store.bundle.${b.id}'),
    onTap: () => _detail(b),
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: StoreColors.bundleBg),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(BrandAssets.storeItem(b.image), width: 132, fit: BoxFit.cover, semanticLabel: b.name.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.name.text,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                if (b.desc != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      b.desc!.text,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.sub),
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  t.storeBundleXp(fmtXp(b.xp)),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
                const SizedBox(height: 9),
                Container(
                  key: Key('store.bundle.${b.id}.preview'),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                  decoration: BoxDecoration(gradient: StoreColors.grad, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    t.storePreview,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.onAccent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _soonCard(RewardItem i) => GestureDetector(
    key: Key('store.soon.${i.id}'),
    onTap: () => showToast(context, t.storeTierLocked(i.unlockTier)),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: _cardDeco,
      child: Column(
        children: [
          Stack(
            children: [
              Image.asset(BrandAssets.storeItem(i.image), height: 66, width: double.infinity, fit: BoxFit.cover, semanticLabel: i.name.text),
              // 占位图自带锁标；高清图替换后由此处补锁标
              if (!i.placeholder)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(color: StoreColors.lockBadge, shape: BoxShape.circle),
                    child: Icon(Icons.lock_rounded, size: 10, color: AppColors.onAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              i.name.text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 7),
            child: Text(
              t.storeTier(i.unlockTier),
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _cta() => GestureDetector(
    key: const Key('store.previewOnFifi'),
    onTap: () => showToast(context, t.storePreviewOnFifiSoon),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: StoreColors.grad,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .32), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Text(
        '✦ ${t.storePreviewOnFifi}',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onAccent),
      ),
    ),
  );

  Widget _cta2() => GestureDetector(
    key: const Key('store.earnXp'),
    onTap: () => context.push('/rewards/earn'),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StoreColors.xpBorder, width: 1.5),
      ),
      child: Text(
        '★ ${t.storeEarnXp}',
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.primary),
      ),
    ),
  );

  /// 商品 / 套装详情弹层：本期兑换未开放（"兑换即将开启"）。
  void _detail(RewardItem i) {
    final (label, bg, fg) = _status(i);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          key: const Key('store.detail'),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(BrandAssets.storeItem(i.image), height: 150, fit: BoxFit.contain),
              ),
              if (i.placeholder)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(t.storeImagePlaceholder, style: TextStyle(fontSize: 11, color: AppColors.hint)),
                ),
              const SizedBox(height: 12),
              Text(
                i.name.text,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              if (i.desc != null) ...[const SizedBox(height: 4), Text(i.desc!.text, style: TextStyle(fontSize: 13, color: AppColors.sub))],
              const SizedBox(height: 6),
              Text(
                '★ ${fmtXp(i.xp)} XP',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
                ),
              ),
              const SizedBox(height: 18),
              AppButton(t.storeRedeemSoon, key: const Key('store.detail.redeem'), kind: ButtonKind.ghost, onPressed: null),
            ],
          ),
        ),
      ),
    );
  }
}
