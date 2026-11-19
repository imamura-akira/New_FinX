import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../market/data/market_api.dart';
import '../../market/presentation/market_widgets.dart';
import '../domain/demo_data.dart';

// F13：股票大师（P-23 / P-24）、Fifi（P-26）、奖励（P-27）。纯客户端模拟数据，不调用新接口；
// 个股最新价取自虚拟行情（F11）。版式参照 prototype/js/pages/discover.js 与 design/screens/。

const comingSoon = '即将上线';

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
      style: const TextStyle(fontSize: 12, color: AppColors.faint, height: 1.5),
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
      style: TextStyle(color: Colors.white, fontSize: size * .4, fontWeight: FontWeight.w700),
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
              if (kicker != null) Text(kicker!, style: const TextStyle(fontSize: 12, color: Color(0xB3FFFFFF))),
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(sub, style: const TextStyle(fontSize: 13, color: Color(0xD9FFFFFF), height: 1.5)),
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
        const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
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
      appBar: AppBar(title: const Text('股票大师')),
      body: ListenableBuilder(
        listenable: _feed!,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            const _Banner(gradient: AppGradients.soon, title: '看看大机构在买什么', sub: '基于公开的 13F 持仓申报，按季度更新'),
            Row(
              children: [
                ChipToggle(label: '收益最高', selected: _group == 'hot', onTap: () => setState(() => _group = 'hot')),
                const SizedBox(width: 8),
                ChipToggle(label: '最近更新', selected: _group == 'recent', onTap: () => setState(() => _group = 'recent')),
                const Spacer(),
                LinkButton('更多', key: const Key('p23.more'), fontSize: 13, onPressed: () => context.push('/masters/all')),
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
              '个股机会',
              trailing: const Text('2026 年第三季度', style: TextStyle(fontSize: 13, color: AppColors.muted)),
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
            const Notice('数据来源于机构公开申报（演示数据），存在披露滞后，不代表机构当前持仓，不构成投资建议。'),
            const DemoDataNote('演示数据：机构名称、收益与持仓均为虚构，仅供展示'),
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
          const Text('年收益', style: TextStyle(fontSize: 11, color: AppColors.muted)),
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
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text('代码', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '增持占总股本',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  '增 / 平 / 减 家数',
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
              decoration: const BoxDecoration(
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
                          '最新价 ${_feed!.quotes[sym] == null ? '—' : fmtPx(_feed!.quotes[sym]!.last)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
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
                            style: const TextStyle(color: AppColors.up),
                          ),
                          TextSpan(text: ' : $flat : '),
                          TextSpan(
                            text: '$dec',
                            style: const TextStyle(color: AppColors.down),
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
      title: '全部机构',
      content: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 5,
                      child: Text('名称 / 公司', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                    Expanded(flex: 3, child: head('ret', '收益')),
                    Expanded(flex: 3, child: head('aum', '资产增速')),
                    Expanded(flex: 2, child: head('updated', '更新')),
                  ],
                ),
              ),
              for (final x in list)
                InkWell(
                  key: Key('p24.row.${x.id}'),
                  onTap: () => context.push('/masters/${x.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
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
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
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
        const DemoDataNote('演示数据：机构名称均为虚构示例'),
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
      return const PageScaffold(
        title: '机构详情',
        content: [
          SizedBox(height: 40),
          StateView(icon: Icons.search_off_rounded, title: '未找到该机构', message: '请返回列表重新选择'),
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
                Text(x.firm, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('年收益', _pctText(x.ret, size: 16)),
                    _stat('资产增速', _pctText(x.aum, size: 16)),
                    _stat('更新', Text(x.updated, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                  ],
                ),
              ],
            ),
          ),
          const SectionTitle('前五大持仓（示例）'),
          ListGroup(
            children: [for (final s in x.holdings) QuoteRow(symbol: s, quote: _feed!.quotes[s], moved: _feed!.moved[s] ?? 0)],
          ),
          const DemoDataNote('演示数据：机构与持仓均为虚构；个股价格为虚拟行情'),
        ],
      ),
    );
  }

  Widget _stat(String label, Widget value) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
    appBar: AppBar(title: const Text('AI 助手'), actions: [_xpBadge('XP')]),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        const Notice('首期不做，待合规评估。以下为保留的页面规格，仅供评估，不会在首期上线。', kind: NoticeKind.warn),
        const _Banner(
          gradient: AppGradients.soon,
          kicker: 'Fifi 量化助手',
          title: '即将推出',
          sub: 'Fifi 正在学习分析图表、风险和持仓，敬请期待。',
          image: BrandAssets.fifiPaw,
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.45,
          children: [
            for (final (k, (icon, title, desc)) in fifiFeatures.indexed)
              _LockedCard(
                key: Key('p26.feat.$k'),
                icon: icon,
                title: '${k + 1}. $title',
                sub: desc,
                onTap: () => showToast(context, '$title$comingSoon'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Notice('上线前需评估是否构成投资建议。', kind: NoticeKind.warn),
        AppButton(
          _subscribed ? '已订阅上线提醒' : '上线提醒我',
          key: const Key('p26.sub'),
          kind: _subscribed ? ButtonKind.ghost : ButtonKind.secondary,
          icon: const Icon(Icons.notifications_none_rounded, size: 18),
          onPressed: () {
            setState(() => _subscribed = !_subscribed);
            showToast(context, _subscribed ? '已订阅上线提醒' : '已取消提醒');
          },
        ),
        const DemoDataNote('演示数据：功能为规划展示，暂未上线'),
      ],
    ),
  );
}

/// 带锁的功能 / 商品卡（原型 .feat）。
class _LockedCard extends StatelessWidget {
  const _LockedCard({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.centered = false,
    this.badge,
  });
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool centered;
  final String? badge;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppShape.radius),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppShape.radius), boxShadow: AppShape.shadow),
      child: Stack(
        children: [
          const Positioned(right: 0, top: 0, child: Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.faint)),
          Column(
            crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: centered ? 52 : 34,
                height: centered ? 52 : 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryWeak,
                  shape: centered ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: centered ? null : BorderRadius.circular(10),
                ),
                child: Icon(icon, size: centered ? 24 : 18, color: AppColors.primary),
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
                textAlign: centered ? TextAlign.center : TextAlign.start,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (badge != null) ...[const SizedBox(height: 6), StatusBadge(badge!)],
            ],
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// P-27 奖励中心

const _rewardGradient = LinearGradient(
  begin: Alignment(-1, -0.6),
  end: Alignment(1, 0.6),
  colors: [Color(0xFF8A3FE0), Color(0xFFD63AA8), Color(0xFFF0A13C)],
  stops: [0, .6, 1],
);

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  int _level = 1;
  bool _subscribed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('奖励'), actions: [_xpBadge('0 XP')]),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        const _Banner(gradient: _rewardGradient, kicker: '奖励中心', title: '即将推出', sub: '完成学习任务赚取积分，解锁徽章、主题与更多奖励。'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var lv = 1; lv <= 4; lv++)
              ChipToggle(
                key: Key('p27.level.$lv'),
                label: '等级 $lv${lv > 1 ? ' 🔒' : ''}',
                selected: _level == lv,
                onTap: () => setState(() => _level = lv),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
          children: [
            for (final (name, xp) in rewardItems[_level]!)
              _LockedCard(
                key: Key('p27.item.$name'),
                icon: Icons.card_giftcard_rounded,
                title: name,
                sub: '$xp XP',
                centered: true,
                badge: '即将推出',
                onTap: () => showToast(context, '兑换$comingSoon'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const Notice('若积分获取与入金或交易行为挂钩，需确认相关激励合规要求。'),
        AppButton(
          _subscribed ? '已订阅上线提醒' : '上线提醒我',
          key: const Key('p27.sub'),
          kind: _subscribed ? ButtonKind.ghost : ButtonKind.secondary,
          icon: const Icon(Icons.notifications_none_rounded, size: 18),
          onPressed: () {
            setState(() => _subscribed = !_subscribed);
            showToast(context, _subscribed ? '已订阅上线提醒' : '已取消提醒');
          },
        ),
        const DemoDataNote('演示数据：积分与奖励为模拟展示，暂不可兑换'),
      ],
    ),
  );
}
