import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../market/domain/instruments.dart';
import '../data/trading_api.dart';
import '../domain/trading_rules.dart';
import 'order_page.dart';

/// P-11 订单列表（F14）：状态、成交数量、成交均价、时间均取 DW 返回；未成交订单可撤单（二次确认）。
/// 有未完结订单时每 5 秒刷新一次。
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String? _filter; // null 全部 / OPEN / CLOSED
  List<Order>? _orders;
  String? _error;
  bool _notOpened = false;
  Timer? _timer;
  final _cancelling = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _timer?.cancel();
    try {
      final list = await TradingApi(AppScope.of(context).api).orders(filter: _filter);
      if (!mounted) return;
      setState(() {
        _orders = list;
        _error = null;
      });
      if (list.any((o) => isOrderOpen(o.status))) {
        _timer = Timer(const Duration(seconds: 5), () {
          if (mounted) _load();
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => e.code == ApiCodes.conflict ? _notOpened = true : _error = tradingErrorText(e));
    }
  }

  Future<void> _cancel(Order o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('撤销订单？'),
        content: Text('${sideLabel(o.side)} ${o.symbol} ${_size(o)}。撤单结果以券商返回为准，已成交部分不会撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('再想想')),
          TextButton(key: const Key('p11.cancel.confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('撤单')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling.add(o.id));
    try {
      final st = await TradingApi(AppScope.of(context).api).cancel(o.id);
      if (mounted) showToast(context, st == 'CANCELED' ? '订单已撤销' : '撤单已提交，等待券商确认');
    } on ApiException catch (e) {
      if (mounted) showToast(context, tradingErrorText(e));
    } finally {
      if (mounted) setState(() => _cancelling.remove(o.id));
    }
    await _load();
  }

  static String _size(Order o) => o.amount != null ? fmtUsd(o.amount!) : (o.quantity != null ? '${fmtQty(o.quantity!)} 股' : '—');

  @override
  Widget build(BuildContext context) {
    final list = _orders;
    return Scaffold(
      appBar: AppBar(title: const Text('订单')),
      body: _notOpened
          ? StateView(
              icon: Icons.receipt_long_outlined,
              title: '暂无订单',
              message: '交易账户开立后即可下单。',
              actions: [AppButton('返回资产页', onPressed: () => context.go('/home'))],
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Seg2<String?>(
                    key: const Key('p11.filter'),
                    items: const [(null, '全部'), ('OPEN', '未完成'), ('CLOSED', '已结束')],
                    value: _filter,
                    onChanged: (v) {
                      setState(() {
                        _filter = v;
                        _orders = null;
                      });
                      _load();
                    },
                  ),
                  if (_error != null) Notice(_error!, kind: NoticeKind.warn),
                  if (list == null && _error == null)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (list != null && list.isEmpty)
                    const AppCard(
                      child: Text('暂无订单。在个股页点击"买入"或"卖出"即可下单。', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    )
                  else if (list != null)
                    for (final o in list) _card(o),
                  const Text('订单状态、成交数量与成交价均以券商（DriveWealth）返回为准。', style: TextStyle(fontSize: 12, color: AppColors.faint)),
                ],
              ),
            ),
    );
  }

  Widget _card(Order o) {
    final name = instrumentOf(o.symbol)?.name;
    final filled = o.filledQty != null && o.filledQty! > 0;
    return AppCard(
      key: Key('p11.order.${o.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(sideLabel(o.side), kind: o.isBuy ? BadgeKind.ok : BadgeKind.warn),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/market/${o.symbol}'),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: o.symbol, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        if (name != null) TextSpan(text: '  $name', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              StatusBadge(orderStatusLabels[o.status] ?? o.status, key: Key('p11.status.${o.id}'), kind: orderStatusKind(o.status)),
            ],
          ),
          const SizedBox(height: 6),
          KvRow('委托', '市价单 · ${_size(o)}'),
          KvRow('已成交', filled ? '${fmtQty(o.filledQty!)} 股' : '—'),
          KvRow('成交均价', o.avgPrice != null && o.avgPrice! > 0 ? fmtUsd(o.avgPrice!) : '—', valueKey: Key('p11.avgPrice.${o.id}')),
          if (o.totalAmount != null && o.totalAmount! > 0) KvRow('成交金额', fmtUsd(o.totalAmount!)),
          if (o.fees != null && o.fees! > 0) KvRow('费用', fmtUsd(o.fees!)),
          KvRow('提交时间', fmtDateTime(o.submittedAt)),
          if (o.doneAt != null) KvRow('完成时间', fmtDateTime(o.doneAt)),
          if (o.orderNo != null) KvRow('订单号', o.orderNo!),
          if (o.rejectReason != null) Notice(o.rejectReason!, kind: NoticeKind.danger),
          if (o.status == 'SUBMITTING') const Notice('券商受理结果暂未确认，我们会自动核对，请勿重复下单。'),
          if (isOrderCancellable(o.status))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: AppButton(
                '撤单',
                key: Key('p11.cancel.${o.id}'),
                kind: ButtonKind.ghost,
                small: true,
                loading: _cancelling.contains(o.id),
                onPressed: () => _cancel(o),
              ),
            ),
        ],
      ),
    );
  }
}
