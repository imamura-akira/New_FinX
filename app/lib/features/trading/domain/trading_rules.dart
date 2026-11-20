import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../funding/domain/funding_rules.dart';
import '../../../l10n/l10n.dart';

/// 交易前置校验（F14）。后端强制校验（以 DW 购买力 / 可卖数量为准），App 只做提示。
abstract final class TradingLimits {
  /// 单笔最低下单金额（与后端 LIMIT_MIN_ORDER 默认值一致，示例值，以券商为准）。
  static const minOrder = 1.0;

  /// 股数最多 6 位小数（sandbox-log T-4，待实测）。
  static const qtyDecimals = 6;
}

final _qtyRe = RegExp(r'^\d{1,9}(\.\d{0,6})?$');

/// 解析股数（最多 6 位小数）；格式不对返回 null。
double? parseQty(String raw) {
  final s = raw.trim().replaceAll(',', '');
  if (!_qtyRe.hasMatch(s)) return null;
  return double.parse(s);
}

/// 股数显示：最多 6 位小数，去掉多余的零。
String fmtQty(double v) {
  var s = v.toStringAsFixed(TradingLimits.qtyDecimals);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return s;
}

String get minOrderText => t.tradeMinOrder;

/// 按金额下单校验。买入不超过 [buyingPower]；卖出不超过 [sellableValue]（可卖数量 × DW 市价）。
String? validateOrderAmount(String raw, {required bool buy, double? buyingPower, double? sellableValue}) {
  if (raw.trim().isEmpty) return t.tradePleaseEnterAnAmount;
  final v = parseAmount(raw);
  if (v == null) return t.tradeEnterAValidAmount;
  if (v < TradingLimits.minOrder) return minOrderText;
  if (buy && buyingPower != null && v > buyingPower) return t.tradeExceedsYourAvailableBuying(fmtUsd(buyingPower));
  if (!buy && sellableValue != null && v > sellableValue) return t.tradeExceedsTheSellableMarket(fmtUsd(sellableValue));
  return null;
}

/// 按股数下单校验。买入按演示参考价 [price] 估算金额；卖出不超过 [sellableQty]。
String? validateOrderQty(String raw, {required bool buy, double? price, double? buyingPower, double? sellableQty}) {
  if (raw.trim().isEmpty) return t.tradePleaseEnterTheNumber;
  final q = parseQty(raw);
  if (q == null) return t.tradeEnterAValidNumber;
  if (q <= 0) return t.tradeSharesMustBeGreater;
  if (buy) {
    if (price == null || price <= 0) return t.tradeNoQuoteAvailablePlease;
    final est = q * price;
    if (est < TradingLimits.minOrder) return minOrderText;
    if (buyingPower != null && est > buyingPower) return t.tradeEstimatedAmountExceedsYour(fmtUsd(est), fmtUsd(buyingPower));
  } else {
    if (sellableQty != null && q > sellableQty + 1e-9) return t.tradeExceedsYourSellableQuantity(fmtQty(sellableQty));
  }
  return null;
}

/// 订单状态文案（api-spec.md 5.6）。
Map<String, String> get orderStatusLabels => {
  'SUBMITTING': t.tradeSubmitting,
  'NEW': t.tradeQueued,
  'PARTIAL_FILL': t.tradePartiallyFilled,
  'FILLED': t.tradeFilled,
  'REJECTED': t.tradeRejected,
  'CANCELED': t.tradeCanceled,
  'PENDING_CANCEL': t.tradePendingCancel,
};

BadgeKind orderStatusKind(String s) => switch (s) {
  'FILLED' => BadgeKind.ok,
  'REJECTED' => BadgeKind.danger,
  'CANCELED' => BadgeKind.neutral,
  _ => BadgeKind.info,
};

bool isOrderOpen(String s) => const {'SUBMITTING', 'NEW', 'PARTIAL_FILL', 'PENDING_CANCEL'}.contains(s);
bool isOrderCancellable(String s) => s == 'NEW' || s == 'PARTIAL_FILL';

String sideLabel(String side) => side == 'SELL' ? t.instrumentSell : t.instrumentBuy;

/// 演示行情与成交价差异提示（P-19 确认页 / 结果页，F14 需求原文）。
String get demoPriceNotice => t.tradePricesShownAreDemo;

/// 限价单开关：实盘限价单（F14 扩展，当日有效）已开放；模拟盘始终支持。
abstract final class TradingFeatures {
  static const realLimitOrders = true;
}

final _limitRe = RegExp(r'^\d{1,7}(\.\d{1,4})?$');

/// 解析限价：> 0；$1 以上最多两位小数，$1 以下最多四位小数。格式不对返回 null。
double? parseLimitPrice(String raw) {
  final s = raw.trim().replaceAll(',', '');
  if (!_limitRe.hasMatch(s)) return null;
  final v = double.parse(s);
  if (v <= 0) return null;
  final dot = s.indexOf('.');
  if (v >= 1 && dot >= 0 && s.length - dot - 1 > 2) return null;
  return v;
}

/// 限价单校验（按股数）。买入冻结金额 = 股数 × 限价，不低于单笔最低、不超过可用资金；卖出不超过可卖数量。
/// 返回 (股数错误, 限价错误)。
(String?, String?) validateLimitOrder(String qtyRaw, String limitRaw, {required bool buy, double? buyingPower, double? sellableQty}) {
  String? qErr, lErr;
  final q = parseQty(qtyRaw);
  if (qtyRaw.trim().isEmpty) {
    qErr = t.tradePleaseEnterTheNumber;
  } else if (q == null) {
    qErr = t.tradeEnterAValidNumber;
  } else if (q <= 0) {
    qErr = t.tradeSharesMustBeGreater;
  }
  final l = parseLimitPrice(limitRaw);
  if (limitRaw.trim().isEmpty) {
    lErr = t.tradePleaseEnterALimit;
  } else if (l == null) {
    lErr = t.tradeLimitPriceMustBe;
  }
  if (qErr != null || lErr != null) return (qErr, lErr);
  if (buy) {
    final reserve = q! * l!;
    if (reserve < TradingLimits.minOrder) return (minOrderText, null);
    if (buyingPower != null && reserve > buyingPower) return (t.tradeAmountOnHoldExceeds(fmtUsd(reserve), fmtUsd(buyingPower)), null);
  } else if (sellableQty != null && q! > sellableQty + 1e-9) {
    return (t.tradeExceedsYourSellableQuantity(fmtQty(sellableQty)), null);
  }
  return (null, null);
}

/// 订单状态文案：限价单未成交显示"挂单中"。
String orderStatusLabel(String status, {bool limit = false}) =>
    limit && status == 'NEW' ? t.tradeWorking : (orderStatusLabels[status] ?? status);

/// 模拟盘撮合说明（P-19 确认页 / 结果页）。
String get paperPriceNotice => t.tradePaperTradingOrdersFill;
