import '../../../core/api/api_client.dart';

double? _dn(Object? v) => v is num ? v.toDouble() : (v == null ? null : double.tryParse('$v'));
double _d(Object? v) => _dn(v) ?? 0;
DateTime? _t(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// 订单（api-spec.md 5.6 Order）。委托值二选一；成交数据为 DW 返回（未成交为 null）。
class Order {
  const Order({
    required this.id,
    required this.symbol,
    required this.side,
    required this.status,
    this.orderNo,
    this.orderType = 'MARKET',
    this.quantity,
    this.amount,
    this.filledQty,
    this.avgPrice,
    this.totalAmount,
    this.fees,
    this.rejectReason,
    this.submittedAt,
    this.updatedAt,
    this.doneAt,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id: j['orderId'] as String,
    orderNo: j['orderNo'] as String?,
    symbol: j['symbol'] as String? ?? '',
    side: j['side'] as String? ?? '',
    orderType: j['orderType'] as String? ?? 'MARKET',
    quantity: _dn(j['quantity']),
    amount: _dn(j['amount']),
    status: j['status'] as String? ?? '',
    filledQty: _dn(j['filledQty']),
    avgPrice: _dn(j['avgPrice']),
    totalAmount: _dn(j['totalAmount']),
    fees: _dn(j['fees']),
    rejectReason: j['rejectReason'] as String?,
    submittedAt: _t(j['submittedAt']),
    updatedAt: _t(j['updatedAt']),
    doneAt: _t(j['doneAt']),
  );

  final String id;
  final String? orderNo;
  final String symbol;
  final String side; // BUY / SELL
  final String orderType;
  final double? quantity;
  final double? amount;
  final String status;
  final double? filledQty;
  final double? avgPrice;
  final double? totalAmount;
  final double? fees;
  final String? rejectReason;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
  final DateTime? doneAt;

  bool get isBuy => side == 'BUY';
}

/// 持仓（api-spec.md 5.6 Position；全部为 DW 返回值）。
class Position {
  const Position({
    required this.symbol,
    required this.quantity,
    required this.sellableQty,
    required this.avgPrice,
    required this.costBasis,
    required this.marketPrice,
    required this.marketValue,
    required this.unrealizedPL,
    required this.unrealizedDayPL,
  });

  factory Position.fromJson(Map<String, dynamic> j) => Position(
    symbol: j['symbol'] as String? ?? '',
    quantity: _d(j['quantity']),
    sellableQty: _d(j['sellableQty']),
    avgPrice: _d(j['avgPrice']),
    costBasis: _d(j['costBasis']),
    marketPrice: _d(j['marketPrice']),
    marketValue: _d(j['marketValue']),
    unrealizedPL: _d(j['unrealizedPL']),
    unrealizedDayPL: _d(j['unrealizedDayPL']),
  );

  final String symbol;
  final double quantity;
  final double sellableQty;
  final double avgPrice;
  final double costBasis;
  final double marketPrice;
  final double marketValue;
  final double unrealizedPL;
  final double unrealizedDayPL;

  /// 持仓盈亏百分比（App 唯一自行计算的数字：DW 盈亏 / DW 成本）。
  double? get unrealizedPLPct => costBasis == 0 ? null : unrealizedPL / costBasis * 100;
}

class Positions {
  const Positions({required this.positions, this.equityValue, this.updatedAt});
  factory Positions.fromJson(Map<String, dynamic> j) => Positions(
    equityValue: _dn(j['equityValue']),
    updatedAt: _t(j['updatedAt']),
    positions: [for (final p in (j['positions'] as List? ?? const [])) Position.fromJson((p as Map).cast<String, dynamic>())],
  );
  final double? equityValue;
  final DateTime? updatedAt;
  final List<Position> positions;

  Position? of(String symbol) => positions.where((p) => p.symbol == symbol).firstOrNull;
}

/// 下单结果。[pending] 为 true 表示券商受理结果暂未确认（50001 / 50002 附 orderId），后台会自动核对。
class OrderResult {
  const OrderResult({required this.orderId, required this.status, this.pending = false});
  final String orderId;
  final String status;
  final bool pending;
}

class TradingApi {
  TradingApi(this._api);
  final ApiClient _api;

  /// 市价单：[amount]（美元）与 [quantity]（股数）二选一。
  Future<OrderResult> place({required String symbol, required String side, double? amount, double? quantity}) async {
    try {
      final d = await _api.post('/orders', {
        'symbol': symbol,
        'side': side,
        'orderType': 'MARKET',
        if (amount != null) 'amount': double.parse(amount.toStringAsFixed(2)),
        if (quantity != null) 'quantity': double.parse(quantity.toStringAsFixed(6)),
      }) as Map<String, dynamic>;
      return OrderResult(orderId: d['orderId'] as String, status: d['status'] as String? ?? 'NEW');
    } on ApiException catch (e) {
      final data = e.data;
      if ((e.code == ApiCodes.dwFailed || e.code == ApiCodes.dwBadData) && data is Map && data['orderId'] is String) {
        return OrderResult(orderId: data['orderId'] as String, status: 'SUBMITTING', pending: true);
      }
      rethrow;
    }
  }

  /// [filter]：null 全部 / OPEN 未完成 / CLOSED 已结束。
  Future<List<Order>> orders({String? filter}) async => [
    for (final o in (await _api.get('/orders', query: filter == null ? null : {'status': filter}) as List? ?? const []))
      Order.fromJson((o as Map).cast<String, dynamic>()),
  ];

  Future<Order> order(String id) async => Order.fromJson(await _api.get('/orders/${Uri.encodeComponent(id)}') as Map<String, dynamic>);

  Future<String> cancel(String id) async {
    final d = await _api.post('/orders/${Uri.encodeComponent(id)}/cancel') as Map<String, dynamic>;
    return d['status'] as String? ?? 'PENDING_CANCEL';
  }

  Future<Positions> positions() async => Positions.fromJson(await _api.get('/positions') as Map<String, dynamic>);
}
