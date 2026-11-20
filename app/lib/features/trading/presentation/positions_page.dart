import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../market/domain/instruments.dart';
import '../../market/presentation/market_widgets.dart';
import '../data/trading_api.dart';
import '../domain/trading_rules.dart';
import 'order_page.dart';
import '../domain/trading_mode.dart';
import 'paper_widgets.dart';
import '../../../l10n/l10n.dart';

/// P-12 持仓（F14）：数量、市值、成本、盈亏全部取 DW 返回值；App 只计算盈亏百分比（DW 盈亏 / DW 成本）。
class PositionsPage extends StatefulWidget {
  const PositionsPage({super.key, this.paper = false});

  /// 模拟持仓（F15，/paper/positions，按演示行情估值）。
  final bool paper;

  @override
  State<PositionsPage> createState() => _PositionsPageState();
}

class _PositionsPageState extends State<PositionsPage> {
  Positions? _data;
  String? _error;
  bool _notOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final d = await TradingApi(AppScope.of(context).api, paper: widget.paper).positions();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => !widget.paper && e.code == ApiCodes.conflict ? _notOpened = true : _error = tradingErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: paperTitle(widget.paper ? t.homePaperPositions : t.homePositions, widget.paper),
        actions: [
          IconButton(
            tooltip: t.homeOrders,
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/orders${paperQuery(widget.paper)}'),
          ),
        ],
      ),
      body: _notOpened
          ? StateView(
              icon: Icons.pie_chart_outline_rounded,
              title: t.positionsNoPositionsYet,
              message: t.positionsYouCanBuyStocks,
              actions: [AppButton(t.ordersBackToAssets, onPressed: () => context.go('/home'))],
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  if (widget.paper) const PaperBanner(),
                  if (_error != null) Notice(_error!, kind: NoticeKind.warn),
                  if (d == null && _error == null)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (d != null) ...[
                    _summary(d),
                    if (d.positions.isEmpty)
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.positionsNoPositionsYet2, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(t.positionsPickAStockOn, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                            const SizedBox(height: 10),
                            AppButton(t.homeGoToMarkets, small: true, onPressed: () => context.go('/market')),
                          ],
                        ),
                      )
                    else
                      for (final p in d.positions) _row(p),
                  ],
                  Text(
                    widget.paper
                        ? t.positionsPaperPositionsAreValued
                        : (d?.updatedAt == null ? t.positionsFromDw : t.positionsFromDwUpdated(fmtDateTime(d!.updatedAt))),
                    style: TextStyle(fontSize: 12, color: AppColors.faint),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summary(Positions d) {
    final pl = d.positions.fold<double>(0, (s, p) => s + p.unrealizedPL);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.paper ? t.positionsPaperPositionsValue : t.drawerPositionsValue, style: TextStyle(fontSize: 12, color: AppColors.muted)),
          Text(
            d.equityValue == null ? '—' : fmtUsd(d.equityValue!),
            key: const Key('p12.equity'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            t.positionsTotalPl('${pl >= 0 ? '+' : ''}${fmtUsd(pl)}'),
            key: const Key('p12.totalPL'),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: chgColor(pl)),
          ),
        ],
      ),
    );
  }

  Widget _row(Position p) {
    final pct = p.unrealizedPLPct;
    final color = chgColor(p.unrealizedPL);
    return InkWell(
      key: Key('p12.pos.${p.symbol}'),
      onTap: () => context.push('/market/${p.symbol}'),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.symbol, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(instrumentOf(p.symbol)?.name ?? '', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmtUsd(p.marketValue), key: Key('p12.mv.${p.symbol}'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(
                      '${p.unrealizedPL >= 0 ? '+' : ''}${fmtUsd(p.unrealizedPL)}${pct == null ? '' : '  ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%'}',
                      key: Key('p12.pl.${p.symbol}'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 18, color: AppColors.line),
            KvRow(t.positionsSharesHeld, t.ordersShares(fmtQty(p.quantity)), valueKey: Key('p12.qty.${p.symbol}')),
            if ((p.quantity - p.sellableQty).abs() > 1e-9) KvRow(t.positionsSellable, t.ordersShares(fmtQty(p.sellableQty))),
            KvRow(t.positionsCostBasis, fmtUsd(p.costBasis), valueKey: Key('p12.cost.${p.symbol}')),
            KvRow(t.positionsAvgCurrentPrice, '${fmtUsd(p.avgPrice)} / ${fmtUsd(p.marketPrice)}'),
          ],
        ),
      ),
    );
  }
}
