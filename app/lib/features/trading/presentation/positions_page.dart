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

/// P-12 持仓（F14）：数量、市值、成本、盈亏全部取 DW 返回值；App 只计算盈亏百分比（DW 盈亏 / DW 成本）。
class PositionsPage extends StatefulWidget {
  const PositionsPage({super.key});

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
      final d = await TradingApi(AppScope.of(context).api).positions();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => e.code == ApiCodes.conflict ? _notOpened = true : _error = tradingErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('持仓'),
        actions: [IconButton(tooltip: '订单', icon: const Icon(Icons.receipt_long_outlined), onPressed: () => context.push('/orders'))],
      ),
      body: _notOpened
          ? StateView(
              icon: Icons.pie_chart_outline_rounded,
              title: '暂无持仓',
              message: '交易账户开立后即可买入股票。',
              actions: [AppButton('返回资产页', onPressed: () => context.go('/home'))],
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
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
                            const Text('还没有持仓。', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text('在市场页选择股票，点击"买入"即可下单。', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                            const SizedBox(height: 10),
                            AppButton('去市场', small: true, onPressed: () => context.go('/market')),
                          ],
                        ),
                      )
                    else
                      for (final p in d.positions) _row(p),
                  ],
                  Text(
                    '持仓数据来自 DriveWealth${d?.updatedAt == null ? '' : ' · 更新于 ${fmtDateTime(d!.updatedAt)}'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.faint),
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
          const Text('持仓市值', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          Text(
            d.equityValue == null ? '—' : fmtUsd(d.equityValue!),
            key: const Key('p12.equity'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '持仓盈亏 ${pl >= 0 ? '+' : ''}${fmtUsd(pl)}',
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
                      Text(instrumentOf(p.symbol)?.name ?? '', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
            const Divider(height: 18, color: AppColors.line),
            KvRow('持有数量', '${fmtQty(p.quantity)} 股', valueKey: Key('p12.qty.${p.symbol}')),
            if ((p.quantity - p.sellableQty).abs() > 1e-9) KvRow('可卖数量', '${fmtQty(p.sellableQty)} 股'),
            KvRow('成本', fmtUsd(p.costBasis), valueKey: Key('p12.cost.${p.symbol}')),
            KvRow('均价 / 现价', '${fmtUsd(p.avgPrice)} / ${fmtUsd(p.marketPrice)}'),
          ],
        ),
      ),
    );
  }
}
