import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/format.dart';
import '../../../l10n/l10n.dart';

/// 客户端预校验用的限额与观察期：取自后端 `GET /funding/limits`（后端配置 limits.* / seasoning_*，Q-DW-8 / 8e），
/// 取不到时用以下默认值（与后端默认一致，均为示例值）。审计 DOC-P1-4/P1-5：不再写死。
/// 后端强制校验（CLAUDE.md 硬性规则 5），超限返回 42201 并带实际限额，以后端为准。
abstract final class FundingLimits {
  static double minDeposit = 10.0;
  static double maxDeposit = 50000.0;
  static double dailyDeposit = 50000.0;
  static double minWithdrawal = 1.0;
  static double maxWithdrawal = 50000.0;
  static int maxBanks = 2;
  static String achCutoffEt = '16:00';
  static int seasoningDays = 30;

  /// 应用后端下发的取值（字段缺失或非法时保留原值）。
  static void apply(Map<String, dynamic> j) {
    double d(String k, double v) => (j[k] is num) ? (j[k] as num).toDouble() : v;
    minDeposit = d('minDeposit', minDeposit);
    maxDeposit = d('maxDeposit', maxDeposit);
    dailyDeposit = d('dailyDeposit', dailyDeposit);
    minWithdrawal = d('minWithdrawal', minWithdrawal);
    maxWithdrawal = d('maxWithdrawal', maxWithdrawal);
    if (j['maxBanks'] is num) maxBanks = (j['maxBanks'] as num).toInt();
    if (j['achCutoffET'] is String && (j['achCutoffET'] as String).isNotEmpty) achCutoffEt = j['achCutoffET'] as String;
    if (j['seasoningDays'] is num) seasoningDays = (j['seasoningDays'] as num).toInt();
  }

  @visibleForTesting
  static void reset() => apply(const {
    'minDeposit': 10.0, 'maxDeposit': 50000.0, 'dailyDeposit': 50000.0, 'minWithdrawal': 1.0, 'maxWithdrawal': 50000.0,
    'maxBanks': 2, 'achCutoffET': '16:00', 'seasoningDays': 30,
  });
}

final _amountRe = RegExp(r'^\d{1,9}(\.\d{0,2})?$');

/// 解析金额输入（最多两位小数）；格式不对返回 null。
double? parseAmount(String raw) {
  final s = raw.trim().replaceAll(',', '');
  if (!_amountRe.hasMatch(s)) return null;
  return double.parse(s);
}

/// 入金金额校验（P-13）。返回错误文案，合法返回 null。
String? validateDeposit(String raw) {
  if (raw.trim().isEmpty) return t.fundPleaseEnterADeposit;
  final v = parseAmount(raw);
  if (v == null) return t.tradeEnterAValidAmount;
  if (v < FundingLimits.minDeposit) return t.fundMinimumDepositIs(fmtUsd(FundingLimits.minDeposit));
  if (v > FundingLimits.maxDeposit) return t.fundMaximumDepositIs(fmtUsd(FundingLimits.maxDeposit));
  return null;
}

/// 出金金额校验（P-14）。[withdrawable] 为 DW 返回的可提现金额。
String? validateWithdrawal(String raw, double withdrawable) {
  if (raw.trim().isEmpty) return t.fundPleaseEnterAWithdrawal;
  final v = parseAmount(raw);
  if (v == null) return t.tradeEnterAValidAmount;
  if (v < FundingLimits.minWithdrawal) return t.fundMinimumWithdrawalIs(fmtUsd(FundingLimits.minWithdrawal));
  if (v > withdrawable) return t.fundExceedsYourAvailableTo(fmtUsd(withdrawable));
  if (v > FundingLimits.maxWithdrawal) return t.fundMaximumWithdrawalIs(fmtUsd(FundingLimits.maxWithdrawal));
  return null;
}

/// ABA 路由号码校验（9 位 + 校验位，与后端 ValidABA 一致）。
bool validAba(String raw) {
  final s = raw.replaceAll(RegExp(r'\D'), '');
  if (s.length != 9) return false;
  const w = [3, 7, 1, 3, 7, 1, 3, 7, 1];
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    sum += (s.codeUnitAt(i) - 48) * w[i];
  }
  return sum % 10 == 0;
}

/// 出入金状态文案（DW Deposit Status + 我方 SUBMITTING / UNCONFIRMED）。
Map<String, String> get transferStatusLabels => {
  'SUBMITTING': t.tradeSubmitting,
  'UNCONFIRMED': t.statusUnconfirmed, // 券商结果待人工核对（审计 FUND-P1-4）
  'STARTED': t.fundInitiated,
  'PENDING': t.fundPending,
  'PROCESSING': t.fundProcessing,
  'APPROVED': t.fundApproved,
  'SUCCESSFUL': t.fundCompleted,
  'FAILED': t.fundFailed,
  'RETURNED': t.fundReturned,
  'REJECTED': t.tradeRejected,
  'ON_HOLD': t.fundOnHold,
};

bool isTransferFailed(String s) => s == 'FAILED' || s == 'RETURNED' || s == 'REJECTED';
bool isTransferDone(String s) => s == 'SUCCESSFUL';

/// 时效说明（pages.md 3.1.5；DW 返回日期优先，以下为无返回值时的兜底文案）。
String get buyingPowerFallback => t.fundBuyingPowerIsGranted;
String get seasoningFallback => t.fundAchHoldingPeriod(FundingLimits.seasoningDays);
String get achWithdrawalArrival => t.fundUsually45Business;
String get achWithdrawalFee => t.fundAchFee;
