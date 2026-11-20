import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../market/data/market_api.dart';
import '../../market/presentation/market_widgets.dart';
import '../domain/demo_data.dart';
import '../../../l10n/l10n.dart';

// F13：股票大师（P-23 / P-24）、Fifi（P-26）。奖励（P-27）见 rewards_page.dart（F16）。纯客户端模拟数据，不调用新接口；
// 个股最新价取自虚拟行情（F11）。版式参照 prototype/js/pages/discover.js 与 design/screens/。

String get comingSoon => t.mastersComingSoon;

String pct(double v, {int dp = 2, bool sign = true}) => '${sign && v > 0 ? '+' : ''}${(v * 100).toStringAsFixed(dp)}%';

/// 页面底部"演示数据"标注。
class DemoDataNote extends StatelessWidget {
  const DemoDataNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Text(
      text,
      key: const Key('demo.note'),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: AppColors.faint, height: 1.5),
    ),
  );
}

/// 机构头像（名称首字 + 稳定底色）。
class InstAvatar extends StatelessWidget {
  const InstAvatar(this.name, {super.key, this.size = 36});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: avatarColor(name), shape: BoxShape.circle),
    child: Text(
      name.characters.first,
      style: TextStyle(color: AppColors.onAccent, fontSize: size * .4, fontWeight: FontWeight.w700),
    ),
  );
}

/// 渐变预告横幅（原型 .soon）。
class _Banner extends StatelessWidget {
  const _Banner({required this.gradient, required this.title, required this.sub, this.kicker, this.image});
  final Gradient gradient;
  final String? kicker;
  final String title;
  final String sub;
  final String? image;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
    decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(AppShape.radiusLarge)),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kicker != null) Text(kicker!, style: TextStyle(fontSize: 12, color: AppColors.onAccent.withValues(alpha: .7))),
              Text(
                title,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.onAccent),
              ),
              const SizedBox(height: 6),
              Text(sub, style: TextStyle(fontSize: 13, color: AppColors.onAccent.withValues(alpha: .85), height: 1.5)),
            ],
          ),
        ),
        if (image != null) ...[const SizedBox(width: 8), Image.asset(image!, width: 86, height: 86)],
      ],
    ),
  );
}

/// 顶部 XP 徽标（原型右上角 🔒 XP）。
Widget _xpBadge(String text) => Padding(
  padding: const EdgeInsets.only(right: 12),
  child: Center(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
        ),
      ],
    ),
  ),
);

// ---------------------------------------------------------------------------
// P-23 股票大师（机构持仓追踪）

class MastersPage extends StatefulWidget {
  const MastersPage({super.key});

  @override
  State<MastersPage> createState() => _MastersPageState();
}

class _MastersPageState extends State<MastersPage> {
  String _group = 'hot';
  String _filter = 'INC';
  QuoteFeed? _feed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _feed ??= QuoteFeed(MarketApi(AppScope.of(context).api), symbols: _symbols())..start();
  }

  List<String> _symbols() => [for (final o in opportunities[_filter]!) o.$1];

  @override
  void dispose() {
    _feed?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = [...institutions]..sort((a, b) => _group == 'recent' ? b.updated.compareTo(a.updated) : b.ret.compareTo(a.ret));
    return Scaffold(
      appBar: AppBar(title: Text(t.tabMasters)),
      body: ListenableBuilder(
        listenable: _feed!,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            _Banner(gradient: AppGradients.soon, title: t.mastersSeeWhatTheBig, sub: t.mastersBasedOnPublic13f),
            Row(
              children: [
                ChipToggle(label: t.mastersTopReturns, selected: _group == 'hot', onTap: () => setState(() => _group = 'hot')),
                const SizedBox(width: 8),
                ChipToggle(label: t.mastersRecentlyUpdated, selected: _group == 'recent', onTap: () => setState(() => _group = 'recent')),
                const Spacer(),
                LinkButton(t.mastersMore, key: const Key('p23.more'), fontSize: 13, onPressed: () => context.push('/masters/all')),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .82,
              children: [for (final x in list.take(6)) _instCard(x)],
            ),
            SectionTitle(
              t.mastersStockIdeas,
              trailing: Text(t.mastersQ32026, style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (k, l) in opportunityFilters)
                  ChipToggle(
                    key: Key('p23.filter.$k'),
                    label: l,
                    selected: _filter == k,
                    onTap: () {
                      setState(() => _filter = k);
                      _feed!.symbols = _symbols();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _opportunityTable(),
            Notice(t.mastersDataComesFromPublic),
            DemoDataNote(t.mastersDemoDataInstitutionNames),
          ],
        ),
      ),
    );
  }

  Widget _instCard(Institution x) => InkWell(
    key: Key('p23.inst.${x.id}'),
    onTap: () => context.push('/masters/${x.id}'),
    borderRadius: BorderRadius.circular(AppShape.radius),
    child: Container(
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppShape.radius), boxShadow: AppShape.shadow),
      child: Column(
        children: [
          InstAvatar(x.name),
          const SizedBox(height: 8),
          Text(
            x.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          Text(t.masters1YrReturn, style: TextStyle(fontSize: 11, color: AppColors.muted)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: x.ret >= 0 ? AppColors.primaryWeak : AppColors.dangerWeak,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              pct(x.ret),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: x.ret >= 0 ? AppColors.primary2 : AppColors.danger),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _opportunityTable() => AppCard(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(t.mastersSymbol, style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  t.mastersIncreaseAsOfShares,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  t.mastersIncreasedUnchangedDecreased,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        for (final (sym, p, inc, flat, dec) in opportunities[_filter]!)
          InkWell(
            key: Key('p23.opp.$sym'),
            onTap: () => context.push('/market/$sym'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                sym,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const StatusBadge('US', kind: BadgeKind.info),
                          ],
                        ),
                        Text(
                          t.mastersLastPrice(_feed!.quotes[sym] == null ? '—' : fmtPx(_feed!.quotes[sym]!.last)),
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(pct(p, sign: false), textAlign: TextAlign.right, style: const TextStyle(fontSize: 14)),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$inc',
                            style: TextStyle(color: AppColors.up),
                          ),
                          TextSpan(text: ' : $flat : '),
                          TextSpan(
                            text: '$dec',
                            style: TextStyle(color: AppColors.down),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// P-24 全部机构 / 机构详情

class InstitutionListPage extends StatefulWidget {
  const InstitutionListPage({super.key});

  @override
  State<InstitutionListPage> createState() => _InstitutionListPageState();
}

class _InstitutionListPageState extends State<InstitutionListPage> {
  String _sort = 'updated';

  @override
  Widget build(BuildContext context) {
    final list = [...institutions]
      ..sort(
        (a, b) => switch (_sort) {
          'ret' => b.ret.compareTo(a.ret),
          'aum' => b.aum.compareTo(a.aum),
          _ => b.updated.compareTo(a.updated),
        },
      );
    Widget head(String key, String label) => InkWell(
      key: Key('p24.sort.$key'),
      onTap: () => setState(() => _sort = key),
      child: Text(
        '$label${_sort == key ? ' ▾' : ''}',
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 12, color: _sort == key ? AppColors.primary : AppColors.muted, fontWeight: FontWeight.w600),
      ),
    );
    return PageScaffold(
      title: t.mastersAllInstitutions,
      content: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(t.mastersNameFirm, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                    Expanded(flex: 3, child: head('ret', t.mastersReturn)),
                    Expanded(flex: 3, child: head('aum', t.mastersAumGrowth)),
                    Expanded(flex: 2, child: head('updated', t.mastersUpdated)),
                  ],
                ),
              ),
              for (final x in list)
                InkWell(
                  key: Key('p24.row.${x.id}'),
                  onTap: () => context.push('/masters/${x.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Row(
                            children: [
                              InstAvatar(x.name, size: 30),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(x.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                    Text(
                                      x.firm,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(flex: 3, child: _pctText(x.ret, dp: 1)),
                        Expanded(flex: 3, child: _pctText(x.aum, dp: 1)),
                        Expanded(
                          flex: 2,
                          child: Text(x.updated, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        DemoDataNote(t.mastersDemoDataAllInstitution),
      ],
    );
  }
}

Widget _pctText(double v, {int dp = 2, double size = 14}) => Text(
  pct(v, dp: dp),
  textAlign: TextAlign.right,
  style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: chgColor(v)),
);

class InstitutionDetailPage extends StatefulWidget {
  const InstitutionDetailPage({super.key, required this.id});
  final String id;

  @override
  State<InstitutionDetailPage> createState() => _InstitutionDetailPageState();
}

class _InstitutionDetailPageState extends State<InstitutionDetailPage> {
  QuoteFeed? _feed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final x = institutionOf(widget.id);
    if (_feed == null && x != null) _feed = QuoteFeed(MarketApi(AppScope.of(context).api), symbols: x.holdings)..start();
  }

  @override
  void dispose() {
    _feed?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final x = institutionOf(widget.id);
    if (x == null) {
      return PageScaffold(
        title: t.mastersInstitutionDetails,
        content: [
          SizedBox(height: 40),
          StateView(icon: Icons.search_off_rounded, title: t.mastersInstitutionNotFound, message: t.mastersPleaseGoBackAnd),
        ],
      );
    }
    return ListenableBuilder(
      listenable: _feed!,
      builder: (context, _) => PageScaffold(
        title: x.name,
        content: [
          AppCard(
            child: Column(
              children: [
                InstAvatar(x.name, size: 64),
                const SizedBox(height: 10),
                Text(
                  x.name,
                  key: const Key('p24.name'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                Text(x.firm, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(t.masters1YrReturn, _pctText(x.ret, size: 16)),
                    _stat(t.mastersAumGrowth, _pctText(x.aum, size: 16)),
                    _stat(t.mastersUpdated, Text(x.updated, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                  ],
                ),
              ],
            ),
          ),
          SectionTitle(t.mastersTop5HoldingsSample),
          ListGroup(
            children: [for (final s in x.holdings) QuoteRow(symbol: s, quote: _feed!.quotes[s], moved: _feed!.moved[s] ?? 0)],
          ),
          DemoDataNote(t.mastersDemoDataInstitutionsAnd),
        ],
      ),
    );
  }

  Widget _stat(String label, Widget value) => Column(
    children: [
      Text(label, style: TextStyle(fontSize: 12, color: AppColors.muted)),
      const SizedBox(height: 2),
      value,
    ],
  );
}

// ---------------------------------------------------------------------------
// P-26 Fifi 功能中心

class FifiPage extends StatefulWidget {
  const FifiPage({super.key});

  @override
  State<FifiPage> createState() => _FifiPageState();
}

class _FifiPageState extends State<FifiPage> {
  bool _subscribed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t.mastersAiAssistant), actions: [_xpBadge('XP')]),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        Notice(t.mastersNotIncludedInThe, kind: NoticeKind.warn),
        _Banner(
          gradient: AppGradients.soon,
          kicker: t.mastersFifiQuantAssistant,
          title: t.mastersComingSoon2,
          sub: t.mastersFifiIsLearningTo,
          image: BrandAssets.fifiPaw,
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25, // F18：英文副标题两行也放得下
          children: [
            for (final (k, (icon, title, desc)) in fifiFeatures.indexed)
              _LockedCard(
                key: Key('p26.feat.$k'),
                icon: icon,
                title: '${k + 1}. $title',
                sub: desc,
                onTap: () => showToast(context, t.featureComingSoon(title)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Notice(t.mastersBeforeLaunchWeNeed, kind: NoticeKind.warn),
        AppButton(
          _subscribed ? t.mastersLaunchReminderOn : t.mastersRemindMeAtLaunch,
          key: const Key('p26.sub'),
          kind: _subscribed ? ButtonKind.ghost : ButtonKind.secondary,
          icon: const Icon(Icons.notifications_none_rounded, size: 18),
          onPressed: () {
            setState(() => _subscribed = !_subscribed);
            showToast(context, _subscribed ? t.mastersLaunchReminderOn : t.mastersReminderCanceled);
          },
        ),
        DemoDataNote(t.mastersDemoDataFeaturesShown),
      ],
    ),
  );
}

/// 带锁的功能卡（原型 .feat）。
class _LockedCard extends StatelessWidget {
  const _LockedCard({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppShape.radius),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppShape.radius), boxShadow: AppShape.shadow),
      child: Stack(
        children: [
          Positioned(right: 0, top: 0, child: Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.faint)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: AppColors.primaryWeak, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
