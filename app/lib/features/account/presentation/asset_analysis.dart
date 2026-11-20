import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../trading/presentation/paper_widgets.dart';
import '../data/portfolio_api.dart';
import '../../../l10n/l10n.dart';

// F17：P-07 资产分布与资产趋势（design/reward-design/assets_mock.png 定稿；版式参考 assets_reference.html）。
// 数据全部来自后端：分布与占比后端计算（DW 持仓 + 现金 / 模拟账户），趋势为后端每日资产快照，有几天画几天。
// 两张卡各自加载，接口失败时整卡隐藏，不影响页面其他区块。

const _ink = Color(0xFF1B1830);
const _sub = Color(0xFF7A7490);
const _faint = Color(0xFFA7A1BC);
const _line = Color(0xFFF4F2FA);
const _pill = Color(0xFFF1EFFA);
const _grid = Color(0xFFF1EFF8);

/// 类别颜色（theme.md ALLOC_COLORS：股票 #D63AA8 / ETF #F0A13C / 现金 #6C5BF5）。
Color assetColor(AssetClass c) => switch (c) {
  AssetClass.stock => AppColors.allocStock,
  AssetClass.etf => AppColors.allocEtf,
  AssetClass.cash => AppColors.allocCash,
};

/// 环形图扇区：金额 > 0 的类别按金额占比（某类为 0 时不画扇区，图例保留）。
List<(AssetClass, double)> donutSegments(Allocation a) {
  final parts = [for (final i in a.items) if (i.amount > 0) (i.kind, i.amount)];
  final sum = parts.fold<double>(0, (s, p) => s + p.$2);
  return sum <= 0 ? const [] : [for (final (k, v) in parts) (k, v / sum)];
}

/// 环心金额：取整到美元（$6,543）。
String fmtUsdWhole(double v) {
  final s = fmtUsd(v.roundToDouble());
  return s.substring(0, s.length - 3);
}

/// 横轴最多显示 [max] 个日期：首、尾必显示，其余均匀抽取。
List<int> axisLabelIndices(int n, {int max = 7}) {
  if (n <= 0) return const [];
  if (n <= max) return [for (var i = 0; i < n; i++) i];
  return {for (var k = 0; k < max; k++) ((n - 1) * k / (max - 1)).round()}.toList();
}

String _mmdd(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 资产分布 + 资产趋势两张卡。[generation] 变化时重新加载（下拉刷新、模拟盘重置）。
class AssetAnalysis extends StatefulWidget {
  const AssetAnalysis({super.key, required this.paper, this.generation = 0});
  final bool paper;
  final int generation;

  @override
  State<AssetAnalysis> createState() => _AssetAnalysisState();
}

class _AssetAnalysisState extends State<AssetAnalysis> {
  Allocation? _alloc;
  bool _allocFailed = false;
  List<AssetPoint>? _points;
  bool _historyFailed = false;
  HistoryRange _range = HistoryRange.d7;
  PortfolioApi? _api;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api == null) {
      _api = PortfolioApi(AppScope.of(context).api, paper: widget.paper);
      _loadAll();
    }
  }

  @override
  void didUpdateWidget(AssetAnalysis old) {
    super.didUpdateWidget(old);
    if (old.paper != widget.paper || old.generation != widget.generation) {
      _api = PortfolioApi(AppScope.of(context).api, paper: widget.paper);
      _loadAll();
    }
  }

  void _loadAll() {
    _loadAllocation();
    _loadHistory();
  }

  Future<void> _loadAllocation() async {
    try {
      final a = await _api!.allocation();
      if (!mounted) return;
      setState(() {
        _alloc = a;
        _allocFailed = false;
      });
    } on ApiException {
      if (mounted) setState(() => _allocFailed = true);
    }
  }

  Future<void> _loadHistory() async {
    final range = _range;
    try {
      final p = await _api!.history(range);
      if (!mounted || range != _range) return;
      setState(() {
        _points = p;
        _historyFailed = false;
      });
    } on ApiException {
      if (mounted && range == _range) setState(() => _historyFailed = true);
    }
  }

  void _setRange(HistoryRange r) {
    if (r == _range) return;
    setState(() => _range = r);
    _loadHistory();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (!_allocFailed && _alloc != null) AllocationCard(data: _alloc!, paper: widget.paper),
      if (!_historyFailed && _points != null) TrendCard(points: _points!, range: _range, paper: widget.paper, onRange: _setRange),
    ],
  );
}

class _CardShell extends StatelessWidget {
  const _CardShell({super.key, required this.title, required this.note, required this.paper, required this.child});
  final String title;
  final String note;
  final bool paper;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x0F1B1830), blurRadius: 18, offset: Offset(0, 6))],
      border: paper ? Border.all(color: PaperColors.border, width: 1.5) : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _ink),
            ),
            if (paper) ...[const SizedBox(width: 8), const PaperBadge()],
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note,
                maxLines: 1,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _faint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 资产分布

class AllocationCard extends StatelessWidget {
  const AllocationCard({super.key, required this.data, required this.paper});
  final Allocation data;
  final bool paper;

  @override
  Widget build(BuildContext context) => _CardShell(
    key: const Key('p07.alloc'),
    title: t.allocAssetAllocation,
    note: paper ? t.allocValuedAtDemoPrices : t.allocByLatestMarketValue,
    paper: paper,
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
                painter: DonutPainter(donutSegments(data)),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.allocTotalAssets,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _sub),
                  ),
                  SizedBox(
                    width: 84,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        fmtUsdWhole(data.total),
                        key: const Key('p07.alloc.total'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: [
              for (final (k, i) in data.items.indexed) ...[
                if (k > 0) const Divider(height: 1, thickness: 1, color: _line),
                _legendRow(i),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  /// 色点 + 类别名与金额同一行基线对齐，占比小字在金额下方。
  Widget _legendRow(AllocationItem i) => Padding(
    key: Key('p07.alloc.${i.kind.code}'),
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: assetColor(i.kind), borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 9),
            Text(
              i.kind.label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _ink),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  fmtUsd(i.amount),
                  key: Key('p07.alloc.${i.kind.code}.amount'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${i.pct.toStringAsFixed(1)}%',
                key: Key('p07.alloc.${i.kind.code}.pct'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _sub),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// 环形图（viewBox 120：半径 48、描边 15，自 12 点方向顺时针：股票 → ETF → 现金）。
class DonutPainter extends CustomPainter {
  const DonutPainter(this.segments);
  final List<(AssetClass, double)> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 120;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 48 * s);
    Paint stroke(Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15 * s
      ..color = c;
    if (segments.isEmpty) {
      canvas.drawArc(rect, 0, math.pi * 2, false, stroke(_grid));
      return;
    }
    var start = -math.pi / 2;
    for (final (k, frac) in segments) {
      final sweep = frac * math.pi * 2;
      canvas.drawArc(rect, start, sweep, false, stroke(assetColor(k)));
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter old) => old.segments.toString() != segments.toString();
}

// ---------------------------------------------------------------------------
// 资产趋势

class TrendCard extends StatelessWidget {
  const TrendCard({super.key, required this.points, required this.range, required this.paper, required this.onRange});
  final List<AssetPoint> points;
  final HistoryRange range;
  final bool paper;
  final ValueChanged<HistoryRange> onRange;

  @override
  Widget build(BuildContext context) {
    final labels = axisLabelIndices(points.length);
    return _CardShell(
      key: const Key('p07.trend'),
      title: t.allocAssetTrend,
      note: paper ? t.allocDailySnapshots : t.allocDailySnapshotsSinceAccount,
      paper: paper,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (final r in HistoryRange.values)
                GestureDetector(
                  key: Key('p07.trend.range.${r.code}'),
                  onTap: () => onRange(r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: r == range ? AppColors.primary : _pill, borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      r.label,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: r == range ? Colors.white : _sub),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (points.length < 2)
            Container(
              key: const Key('p07.trend.empty'),
              height: 110,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFFAF9FE), borderRadius: BorderRadius.circular(12)),
              child: Text(
                t.allocBuildingYourHistoryThe,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _faint),
              ),
            )
          else ...[
            SizedBox(
              height: 110,
              child: CustomPaint(
                key: const Key('p07.trend.chart'),
                size: Size.infinite,
                painter: TrendPainter([for (final p in points) p.total]),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: labels.length == 1 ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                for (final i in labels)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _mmdd(points[i].date),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _faint),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 紫色渐变面积折线（viewBox 358×110 的版式：三条网格线，最新点高亮）。
class TrendPainter extends CustomPainter {
  const TrendPainter(this.values);
  final List<double> values;

  /// 各点坐标（按序号等距；纵向留白，数值全相同时居中）。
  static List<Offset> layout(List<double> values, Size size) {
    if (values.isEmpty) return const [];
    const left = 6.0, right = 6.0, top = 18.0, bottom = 20.0;
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final w = size.width - left - right, h = size.height - top - bottom;
    return [
      for (final (i, v) in values.indexed)
        Offset(
          left + (values.length == 1 ? w : w * i / (values.length - 1)),
          hi == lo ? top + h / 2 : top + h * (1 - (v - lo) / (hi - lo)),
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = _grid
      ..strokeWidth = 1;
    for (final y in [18.0, 52.0, 86.0]) {
      final yy = y / 110 * size.height;
      canvas.drawLine(Offset(0, yy), Offset(size.width, yy), grid);
    }
    final pts = layout(values, size);
    if (pts.length < 2) return;
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height - 2)
      ..lineTo(pts.first.dx, size.height - 2)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary.withValues(alpha: .25), AppColors.primary.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primary,
    );
    canvas.drawCircle(pts.last, 7, Paint()..color = AppColors.primary.withValues(alpha: .2));
    canvas.drawCircle(pts.last, 4, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant TrendPainter old) => old.values.toString() != values.toString();
}
