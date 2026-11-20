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
import 'paper_widgets.dart';
import '../../../l10n/l10n.dart';

/// P-11 订单列表（F14）：状态、成交数量、成交均价、时间均取 DW 返回；未成交订单可撤单（二次确认）。
/// 有未完结订单时每 5 秒刷新一次。
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, this.paper = false});

  /// 模拟盘订单（F15，/paper/orders）。
  final bool paper;

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
      final list = await TradingApi(AppScope.of(context).api, paper: widget.paper).orders(filter: _filter);
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
      setState(() => !widget.paper && e.code == ApiCodes.conflict ? _notOpened = true : _error = tradingErrorText(e));
    }
  }

  Future<void> _cancel(Order o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.ordersCancelOrder),
        content: Text(
          widget.paper
              ? t.ordersCancelingReleasesTheVirtual(sideLabel(o.side), o.symbol, _size(o))
              : t.ordersTheCancellationResultIs(sideLabel(o.side), o.symbol, _size(o)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.ordersKeepOrder)),
          TextButton(key: const Key('p11.cancel.confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(t.ordersCancelOrder2)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _cancelling.add(o.id));
    try {
      final st = await TradingApi(AppScope.of(context).api, paper: widget.paper).cancel(o.id);
      if (mounted) showToast(context, st == 'CANCELED' ? t.ordersOrderCanceled : t.ordersCancelRequestSubmittedWaiting);
    } on ApiException catch (e) {
      if (mounted) showToast(context, tradingErrorText(e));
    } finally {
      if (mounted) setState(() => _cancelling.remove(o.id));
    }
    await _load();
  }

  static String _size(Order o) => o.amount != null ? fmtUsd(o.amount!) : (o.quantity != null ? t.ordersShares(fmtQty(o.quantity!)) : '—');

  @override
  Widget build(BuildContext context) {
    final list = _orders;
    return Scaffold(
      appBar: AppBar(title: paperTitle(widget.paper ? t.homePaperOrders : t.homeOrders, widget.paper), leading: const AppBackButton()),
      body: _notOpened
          ? StateView(
              icon: Icons.receipt_long_outlined,
              title: t.ordersNoOrdersYet,
              message: t.ordersYouCanPlaceOrders,
              actions: [AppButton(t.ordersBackToAssets, onPressed: () => context.go('/home'))],
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  if (widget.paper) const PaperBanner(),
                  Seg2<String?>(
                    key: const Key('p11.filter'),
                    items: [(null, t.marketAll), ('OPEN', t.ordersOpen), ('CLOSED', t.ordersClosed)],
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
                    AppCard(
                      child: Text(t.ordersNoOrdersYetTap, style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    )
                  else if (list != null)
                    for (final o in list) _card(o),
                  Text(
                    widget.paper ? t.ordersPaperOrdersAreFilled : t.ordersOrderStatusFilledQuantity,
                    style: const TextStyle(fontSize: 12, color: AppColors.faint),
                  ),
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
              StatusBadge(orderStatusLabel(o.status, limit: o.isLimit), key: Key('p11.status.${o.id}'), kind: orderStatusKind(o.status)),
            ],
          ),
          const SizedBox(height: 6),
          KvRow(
            t.ordersOrder,
            o.isLimit ? t.ordersLimitDay(fmtUsd(o.limitPrice ?? 0), _size(o)) : t.ordersMarket(_size(o)),
            valueKey: Key('p11.order.desc.${o.id}'),
          ),
          KvRow(t.tradeFilled, filled ? t.ordersShares(fmtQty(o.filledQty!)) : '—'),
          KvRow(t.ordersAvgFillPrice, o.avgPrice != null && o.avgPrice! > 0 ? fmtUsd(o.avgPrice!) : '—', valueKey: Key('p11.avgPrice.${o.id}')),
          if (o.totalAmount != null && o.totalAmount! > 0) KvRow(t.ordersFilledAmount, fmtUsd(o.totalAmount!)),
          if (o.fees != null && o.fees! > 0) KvRow(t.ordersFees, fmtUsd(o.fees!)),
          KvRow(t.ordersSubmitted, fmtDateTime(o.submittedAt)),
          if (o.doneAt != null) KvRow(t.ordersCompleted, fmtDateTime(o.doneAt)),
          if (o.orderNo != null) KvRow(t.ordersOrderNo, o.orderNo!),
          if (o.rejectReason != null) Notice(localizeServerText(o.rejectReason!, o.status == 'CANCELED' ? t.serverReasonCanceled : t.serverReasonRejected), kind: o.status == 'CANCELED' ? NoticeKind.info : NoticeKind.danger),
          if (o.status == 'SUBMITTING') Notice(t.ordersTheBrokerHasnT),
          if (isOrderCancellable(o.status))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: AppButton(
                t.ordersCancelOrder2,
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
