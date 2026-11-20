import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../funding/domain/funding_rules.dart';

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

const minOrderText = r'单笔最低 $1.00（示例值，以券商为准）';

/// 按金额下单校验。买入不超过 [buyingPower]；卖出不超过 [sellableValue]（可卖数量 × DW 市价）。
String? validateOrderAmount(String raw, {required bool buy, double? buyingPower, double? sellableValue}) {
  if (raw.trim().isEmpty) return '请输入金额';
  final v = parseAmount(raw);
  if (v == null) return '请输入有效金额，最多两位小数';
  if (v < TradingLimits.minOrder) return minOrderText;
  if (buy && buyingPower != null && v > buyingPower) return '超过可用购买力 ${fmtUsd(buyingPower)}';
  if (!buy && sellableValue != null && v > sellableValue) return '超过可卖市值 ${fmtUsd(sellableValue)}';
  return null;
}

/// 按股数下单校验。买入按演示参考价 [price] 估算金额；卖出不超过 [sellableQty]。
String? validateOrderQty(String raw, {required bool buy, double? price, double? buyingPower, double? sellableQty}) {
  if (raw.trim().isEmpty) return '请输入股数';
  final q = parseQty(raw);
  if (q == null) return '请输入有效股数，最多 6 位小数';
  if (q <= 0) return '股数须大于 0';
  if (buy) {
    if (price == null || price <= 0) return '暂无报价，请按金额买入';
    final est = q * price;
    if (est < TradingLimits.minOrder) return minOrderText;
    if (buyingPower != null && est > buyingPower) return '预估金额 ${fmtUsd(est)} 超过可用购买力 ${fmtUsd(buyingPower)}';
  } else {
    if (sellableQty != null && q > sellableQty + 1e-9) return '超过可卖数量 ${fmtQty(sellableQty)} 股';
  }
  return null;
}

/// 订单状态中文名（api-spec.md 5.6）。
const orderStatusLabels = {
  'SUBMITTING': '提交中',
  'NEW': '排队中',
  'PARTIAL_FILL': '部分成交',
  'FILLED': '已成交',
  'REJECTED': '已拒绝',
  'CANCELED': '已撤单',
  'PENDING_CANCEL': '撤单中',
};

BadgeKind orderStatusKind(String s) => switch (s) {
  'FILLED' => BadgeKind.ok,
  'REJECTED' => BadgeKind.danger,
  'CANCELED' => BadgeKind.neutral,
  _ => BadgeKind.info,
};

bool isOrderOpen(String s) => const {'SUBMITTING', 'NEW', 'PARTIAL_FILL', 'PENDING_CANCEL'}.contains(s);
bool isOrderCancellable(String s) => s == 'NEW' || s == 'PARTIAL_FILL';

String sideLabel(String side) => side == 'SELL' ? '卖出' : '买入';

/// 演示行情与成交价差异提示（P-19 确认页 / 结果页，F14 需求原文）。
const demoPriceNotice = '显示价格为演示行情，实际成交以券商（DriveWealth）返回为准';
