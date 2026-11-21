import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/amount_mask.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../market/domain/instruments.dart';
import '../../trading/data/trading_api.dart';
import '../data/portfolio_api.dart';
import '../../../l10n/l10n.dart';

// F22-a：P-07 资产页（定稿 design/reward-design/v3/asset_v2.png，版式参考 asset_v2.html）。
// - 渐变大卡：文字列占左约 42%（总资产 / 购买力 / 今日），白色走势线限定右侧 58% 区域；金额过长时缩小字号，不压线。
// - 眼睛：全页金额变 ****（含图例金额，百分比保留），持久化（AmountMask）。
// - 范围胶囊 1D / 1W / 3M / 1Y / YTD 控制大卡走势线；1D 为后端日内快照，不足 2 点显示"日内数据积累中"。
// - 筛选 全部 / 股票 / ETF 作用于环形图：全部 = 现金 / 股票 / ETF（后端分布，与"总资产"同源 D-18）；
//   股票 / ETF = 该类持仓按标的拆分（前 5 个 + 其他）。
// 实盘与模拟盘同一组件（paper=true 时数据来自 /paper/*）。各数据块独立加载，失败时只隐藏该块。

/// 类别颜色（theme.md ALLOC_COLORS：股票 #D63AA8 / ETF #F0A13C / 现金 #6C5BF5）。
Color assetColor(AssetClass c) => switch (c) {
  AssetClass.stock => AppColors.allocStock,
  AssetClass.etf => AppColors.allocEtf,
  AssetClass.cash => AppColors.allocCash,
};

/// 环形图 / 图例的一段。
class DonutSlice {
  const DonutSlice(this.id, this.label, this.amount, this.pct, this.color);
  final String id; // CASH / STOCK / ETF 或标的代码；"其他"为 OTHER
  final String label;
  final double amount;
  final double pct; // 百分数
  final Color color;
}

/// 环形图筛选。
enum AllocFilter {
  all('all'),
  stock('stock'),
  etf('etf');

  const AllocFilter(this.code);
  final String code;

  String get label => switch (this) {
    AllocFilter.all => t.assetFilterAll,
    AllocFilter.stock => t.assetFilterStock,
    AllocFilter.etf => t.assetFilterEtf,
  };
}

/// "全部"：现金、股票、ETF（定稿图例顺序），金额与占比取后端分布。
List<DonutSlice> classSlices(Allocation a) {
  final by = {for (final i in a.items) i.kind: i};
  return [
    for (final k in const [AssetClass.cash, AssetClass.stock, AssetClass.etf]) DonutSlice(k.code, k.label, by[k]?.amount ?? 0, by[k]?.pct ?? 0, assetColor(k)),
  ];
}

/// "股票" / "ETF"：该类持仓按市值从大到小，前 5 个单列，其余合并为"其他"；占比按该类合计计算。
/// 目录外的代码按股票计（与后端分类一致）。
List<DonutSlice> holdingSlices(List<Position> positions, AllocFilter f) {
  final want = f == AllocFilter.etf ? 'ETF' : 'STOCK';
  final list = [
    for (final p in positions)
      if ((instrumentOf(p.symbol)?.type ?? 'STOCK') == want && p.marketValue > 0) p,
  ]..sort((a, b) => b.marketValue.compareTo(a.marketValue));
  final sum = list.fold<double>(0, (s, p) => s + p.marketValue);
  if (sum <= 0) return const [];
  final colors = AssetHeroColors.series;
  final out = <DonutSlice>[for (final (i, p) in list.take(5).indexed) DonutSlice(p.symbol, p.symbol, p.marketValue, p.marketValue / sum * 100, colors[i])];
  if (list.length > 5) {
    final rest = list.skip(5).fold<double>(0, (s, p) => s + p.marketValue);
    out.add(DonutSlice('OTHER', t.assetOthers, rest, rest / sum * 100, colors.last));
  }
  return out;
}

/// 大卡数据（实盘取 DW 资金汇总；模拟盘取模拟账户）。
class HeroData {
  const HeroData({
    required this.title,
    required this.total,
    required this.buyingPower,
    required this.deltaLabel,
    this.delta,
    this.deltaPct,
    this.paper = false,
  });
  final String title;
  final double? total; // null = 尚无数据（显示 —）
  final double? buyingPower;
  final String deltaLabel; // 今日 / 累计盈亏
  final double? delta;
  final double? deltaPct;
  final bool paper;
}

String _signedUsd(double v) => v > 0 ? '+${fmtUsd(v)}' : fmtUsd(v);
String _signedPct(double? p) => p == null ? '' : ' (${p > 0 ? '+' : ''}${p.toStringAsFixed(2)}%)';

/// P-07 资产总览：大卡 + 范围胶囊 + 筛选 + 环形图。[analysis] 为 false（未开户）时只显示大卡。
/// [generation] 变化时重新加载（下拉刷新、模拟盘重置）。
class AssetOverview extends StatefulWidget {
  const AssetOverview({super.key, required this.hero, required this.paper, this.analysis = true, this.generation = 0, this.allocation});
  final HeroData hero;
  final bool paper;
  final bool analysis;
  final int generation;

  /// 实盘：由首页同一份数据传入（与"总资产"同源，D-18）；为 null 时自行加载。
  final Allocation? allocation;

  @override
  State<AssetOverview> createState() => _AssetOverviewState();
}

class _AssetOverviewState extends State<AssetOverview> {
  PortfolioApi? _api;
  HistoryRange _range = HistoryRange.d1;
  final _points = <HistoryRange, List<AssetPoint>>{};
  bool _historyFailed = false;
  Allocation? _alloc;
  bool _allocFailed = false;
  AllocFilter _filter = AllocFilter.all;
  List<Position>? _positions;
  bool _positionsFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api == null) _reset();
  }

  @override
  void didUpdateWidget(AssetOverview old) {
    super.didUpdateWidget(old);
    if (old.paper != widget.paper || old.generation != widget.generation || old.analysis != widget.analysis) {
      _reset();
    } else if (widget.allocation != null && !identical(widget.allocation, old.allocation)) {
      setState(() {
        _alloc = widget.allocation;
        _allocFailed = false;
      });
    }
  }

  void _reset() {
    _api = PortfolioApi(AppScope.of(context).api, paper: widget.paper);
    _points.clear();
    _historyFailed = false;
    _positions = null;
    _positionsFailed = false;
    if (!widget.analysis) return;
    _loadAllocation();
    _loadHistory();
    if (_filter != AllocFilter.all) _loadPositions();
  }

  Future<void> _loadAllocation() async {
    if (widget.allocation != null) {
      _alloc = widget.allocation;
      _allocFailed = false;
      return;
    }
    try {
      final a = await _api!.allocation();
      if (mounted) {
        setState(() {
          _alloc = a;
          _allocFailed = false;
        });
      }
    } on ApiException {
      if (mounted) setState(() => _allocFailed = true);
    }
  }

  Future<void> _loadHistory() async {
    final range = _range, api = _api;
    try {
      final p = await api!.history(range);
      if (!mounted || !identical(api, _api)) return;
      setState(() {
        _points[range] = p;
        if (range == _range) _historyFailed = false;
      });
    } on ApiException {
      if (mounted && range == _range && identical(api, _api)) setState(() => _historyFailed = true);
    }
  }

  Future<void> _loadPositions() async {
    final api = _api;
    try {
      final p = await TradingApi(AppScope.of(context).api, paper: widget.paper).positions();
      if (mounted && identical(api, _api)) {
        setState(() {
          _positions = p.positions;
          _positionsFailed = false;
        });
      }
    } on ApiException {
      if (mounted && identical(api, _api)) setState(() => _positionsFailed = true);
    }
  }

  void _setRange(HistoryRange r) {
    if (r == _range) return;
    setState(() {
      _range = r;
      _historyFailed = false;
    });
    if (!_points.containsKey(r)) _loadHistory();
  }

  void _setFilter(AllocFilter f) {
    if (f == _filter) return;
    setState(() => _filter = f);
    if (f != AllocFilter.all && _positions == null) _loadPositions();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AmountMask.instance,
    builder: (context, _) {
      final a = widget.analysis;
      final pts = a ? _points[_range] : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AssetHeroCard(data: widget.hero, points: pts, range: _range, showTrend: a && !_historyFailed),
          if (a) RangeCapsules(value: _range, onChanged: _setRange),
          if (a && !_allocFailed && _alloc != null) ...[FilterPills(value: _filter, onChanged: _setFilter), _donutCard()],
        ],
      );
    },
  );

  Widget _donutCard() {
    if (_filter == AllocFilter.all) {
      return AllocationCard(slices: classSlices(_alloc!), total: _alloc!.total, paper: widget.paper);
    }
    if (_positionsFailed) {
      return AllocationCard(slices: const [], total: 0, paper: widget.paper, empty: t.homeCouldnTRefreshPlease);
    }
    if (_positions == null) {
      return const SizedBox(height: 172, child: Center(child: CircularProgressIndicator()));
    }
    final slices = holdingSlices(_positions!, _filter);
    return AllocationCard(
      slices: slices,
      total: slices.fold<double>(0, (s, e) => s + e.amount),
      paper: widget.paper,
      empty: _filter == AllocFilter.stock ? t.assetNoStockHoldings : t.assetNoEtfHoldings,
    );
  }
}

// ---------------------------------------------------------------------------
// 渐变大卡

class AssetHeroCard extends StatelessWidget {
  const AssetHeroCard({super.key, required this.data, required this.points, required this.range, required this.showTrend});
  final HeroData data;
  final List<AssetPoint>? points;
  final HistoryRange range;
  final bool showTrend;

  /// 文字列宽度占比与走势线区域占比（两者不重叠）。
  static const textFrac = .42, trendFrac = .58;

  @override
  Widget build(BuildContext context) {
    final mask = AmountMask.instance;
    final p = data.paper ? 'paper' : 'home';
    // 已有资金数据（购买力）而总资产暂缺时，隐藏状态下同样显示 ****（不暴露"有无数据"）
    String money(double? v) => v == null ? (mask.value && data.buyingPower != null ? AmountMask.masked : '—') : mask.apply(fmtUsd(v));
    final d = data.delta;
    final deltaText = d == null ? '—' : (mask.value ? AmountMask.masked : '${_signedUsd(d)}${_signedPct(data.deltaPct)}');
    final pts = points;
    return Container(
      key: Key('$p.hero'),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: AppGradients.assetHero,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: AssetHeroColors.shadow, blurRadius: 30, offset: Offset(0, 14))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              if (showTrend && pts != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: c.maxWidth * trendFrac,
                  child: pts.length < 2
                      ? Align(
                          alignment: const Alignment(.1, .45),
                          child: Text(
                            range.intraday ? t.assetIntradayBuilding : t.assetHistoryBuilding,
                            key: const Key('p07.hero.trend.empty'),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onAccent.withValues(alpha: .75)),
                          ),
                        )
                      : CustomPaint(key: const Key('p07.hero.trend'), painter: HeroTrendPainter([for (final x in pts) x.total])),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                child: SizedBox(
                  width: c.maxWidth * textFrac - 18 - 4, // 扣除左内边距与 4pt 间隙：右缘不越过走势线区域
                  child: DefaultTextStyle(
                    style: TextStyle(color: AppColors.onAccent),
                    child: Column(
                      key: const Key('p07.hero.text'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                data.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onAccent.withValues(alpha: .92)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Semantics(
                              button: true,
                              label: mask.value ? t.assetShowAmounts : t.assetHideAmounts,
                              child: GestureDetector(
                                key: const Key('home.hide'),
                                onTap: mask.toggle,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(color: AssetHeroColors.eyeBg, shape: BoxShape.circle),
                                  child: Icon(mask.value ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 14, color: AppColors.onAccent),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _fit(money(data.total), Key('$p.total'), 33, FontWeight.w800),
                        const SizedBox(height: 12),
                        _label(t.homeBuyingPower),
                        const SizedBox(height: 3),
                        _fit(money(data.buyingPower), Key('$p.buyingPower'), 18, FontWeight.w800),
                        const SizedBox(height: 12),
                        _label(data.deltaLabel),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(child: _fit(deltaText, Key(data.paper ? 'paper.pl' : 'home.dayChange'), 14.5, FontWeight.w800)),
                            if (d != null && d != 0 && !mask.value) ...[
                              const SizedBox(width: 4),
                              Icon(
                                d > 0 ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                                size: 22,
                                color: d > 0 ? AssetHeroColors.upOnGrad : AssetHeroColors.downOnGrad,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String s) => Text(
    s,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.onAccent.withValues(alpha: .85)),
  );

  /// 单行、过长时整体缩小（任何金额长度都不越出文字列）。
  Widget _fit(String s, Key key, double size, FontWeight w) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      s,
      key: key,
      maxLines: 1,
      style: TextStyle(fontSize: size, fontWeight: w, color: AppColors.onAccent, fontFeatures: const [FontFeature.tabularFigures()]),
    ),
  );
}

/// 大卡白色走势线（viewBox 220×170 的版式：线占下方约 2/3，面积渐隐，终点光点）。
class HeroTrendPainter extends CustomPainter {
  const HeroTrendPainter(this.values);
  final List<double> values;

  /// 各点坐标（按序号等距；数值全相同时居中）。
  static List<Offset> layout(List<double> values, Size size) {
    if (values.isEmpty) return const [];
    final left = 6.0, right = 14.0, top = size.height * .22, bottom = size.height * .12;
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final w = size.width - left - right, h = size.height - top - bottom;
    return [
      for (final (i, v) in values.indexed)
        Offset(left + (values.length == 1 ? w : w * i / (values.length - 1)), hi == lo ? top + h / 2 : top + h * (1 - (v - lo) / (hi - lo))),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pts = layout(values, size);
    if (pts.length < 2) return;
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    final white = AppColors.onAccent;
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [white.withValues(alpha: .2), white.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = white.withValues(alpha: .95),
    );
    canvas.drawCircle(pts.last, 9, Paint()..color = white.withValues(alpha: .3));
    canvas.drawCircle(pts.last, 4.5, Paint()..color = white);
  }

  @override
  bool shouldRepaint(covariant HeroTrendPainter old) => old.values.toString() != values.toString();
}

// ---------------------------------------------------------------------------
// 范围胶囊 / 筛选

class RangeCapsules extends StatelessWidget {
  const RangeCapsules({super.key, required this.value, required this.onChanged});
  final HistoryRange value;
  final ValueChanged<HistoryRange> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('p07.ranges'),
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 14, offset: const Offset(0, 4))],
    ),
    child: Row(
      children: [
        for (final r in HistoryRange.values)
          Expanded(
            child: GestureDetector(
              key: Key('p07.range.${r.code}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(r),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: r == value
                    ? BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .35), blurRadius: 10, offset: const Offset(0, 4))],
                      )
                    : null,
                child: Text(
                  r.label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: r == value ? AppColors.onAccent : AppColors.sub),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class FilterPills extends StatelessWidget {
  const FilterPills({super.key, required this.value, required this.onChanged});
  final AllocFilter value;
  final ValueChanged<AllocFilter> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        for (final (i, f) in AllocFilter.values.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              key: Key('p07.filter.${f.code}'),
              onTap: () => onChanged(f),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: f == value
                    ? BoxDecoration(
                        gradient: AppGradients.filterOn,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .3), blurRadius: 14, offset: const Offset(0, 6))],
                      )
                    : BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                child: Text(
                  f.label,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: f == value ? AppColors.onAccent : AppColors.sub),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 环形图

class AllocationCard extends StatelessWidget {
  const AllocationCard({super.key, required this.slices, required this.total, required this.paper, this.empty});
  final List<DonutSlice> slices;
  final double total;
  final bool paper;
  final String? empty; // 无数据时的说明（股票 / ETF 无持仓）

  @override
  Widget build(BuildContext context) {
    final mask = AmountMask.instance;
    return Container(
      key: const Key('p07.alloc'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  key: const Key('p07.alloc.donut'),
                  size: const Size.square(132),
                  painter: DonutPainter([
                    for (final s in slices)
                      if (s.amount > 0) (s.color, s.amount),
                  ]),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 88,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          mask.apply(fmtUsd(total)),
                          key: const Key('p07.alloc.total'),
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.assetTotalValue,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.sub),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: slices.isEmpty
                ? Text(
                    empty ?? '',
                    key: const Key('p07.alloc.empty'),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.hint),
                  )
                : Column(
                    children: [
                      for (final (k, s) in slices.indexed) ...[if (k > 0) Divider(height: 1, thickness: 1, color: AppColors.divider), _legendRow(s, mask)],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 色点 + 名称；右侧金额（可隐藏）与占比（保留）。
  Widget _legendRow(DonutSlice s, AmountMask mask) => Padding(
    key: Key('p07.alloc.${s.id}'),
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(top: 5, right: 9),
          decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
        ),
        Expanded(
          child: Text(
            s.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.4),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  mask.apply(fmtUsd(s.amount)),
                  key: Key('p07.alloc.${s.id}.amount'),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    height: 1.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${s.pct.toStringAsFixed(1)}%',
                key: Key('p07.alloc.${s.id}.pct'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s.color),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 环形图（viewBox 120：半径 47、描边 16，自 12 点方向顺时针）；无数据时画灰色底环。
class DonutPainter extends CustomPainter {
  const DonutPainter(this.parts);
  final List<(Color, double)> parts;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 120;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 47 * s);
    Paint stroke(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16 * s
      ..color = c;
    final sum = parts.fold<double>(0, (a, p) => a + p.$2);
    if (sum <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, stroke(AppColors.track));
      return;
    }
    var start = -math.pi / 2;
    for (final (c, v) in parts) {
      final sweep = v / sum * math.pi * 2;
      canvas.drawArc(rect, start, sweep, false, stroke(c));
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter old) => old.parts.toString() != parts.toString();
}
