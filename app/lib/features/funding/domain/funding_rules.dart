import '../../../core/format.dart';

/// 客户端预校验用的限额（与后端 config `limits.*` 默认值一致，均为示例值）。
/// 后端强制校验（CLAUDE.md 硬性规则 5），超限返回 42201 并带实际限额，以后端为准。
abstract final class FundingLimits {
  static const minDeposit = 10.0;
  static const maxDeposit = 50000.0;
  static const dailyDeposit = 50000.0;
  static const minWithdrawal = 1.0;
  static const maxWithdrawal = 50000.0;
  static const maxBanks = 2;
  static const achCutoffEt = '16:00';
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
  if (raw.trim().isEmpty) return '请输入入金金额';
  final v = parseAmount(raw);
  if (v == null) return '请输入有效金额，最多两位小数';
  if (v < FundingLimits.minDeposit) return '单笔最低入金 ${fmtUsd(FundingLimits.minDeposit)}';
  if (v > FundingLimits.maxDeposit) return '单笔最高入金 ${fmtUsd(FundingLimits.maxDeposit)}';
  return null;
}

/// 出金金额校验（P-14）。[withdrawable] 为 DW 返回的可提现金额。
String? validateWithdrawal(String raw, double withdrawable) {
  if (raw.trim().isEmpty) return '请输入出金金额';
  final v = parseAmount(raw);
  if (v == null) return '请输入有效金额，最多两位小数';
  if (v < FundingLimits.minWithdrawal) return '单笔最低出金 ${fmtUsd(FundingLimits.minWithdrawal)}';
  if (v > withdrawable) return '超过可提现金额 ${fmtUsd(withdrawable)}';
  if (v > FundingLimits.maxWithdrawal) return '单笔最高出金 ${fmtUsd(FundingLimits.maxWithdrawal)}';
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

/// 出入金状态中文名与色调（DW Deposit Status + 我方 SUBMITTING）。
const transferStatusLabels = {
  'SUBMITTING': '提交中',
  'STARTED': '已发起',
  'PENDING': '处理中',
  'PROCESSING': '处理中',
  'APPROVED': '已批准',
  'SUCCESSFUL': '已完成',
  'FAILED': '失败',
  'RETURNED': '已退回',
  'REJECTED': '已拒绝',
  'ON_HOLD': '暂缓处理',
};

bool isTransferFailed(String s) => s == 'FAILED' || s == 'RETURNED' || s == 'REJECTED';
bool isTransferDone(String s) => s == 'SUCCESSFUL';

/// 时效说明（pages.md 3.1.5；DW 返回日期优先，以下为无返回值时的兜底文案）。
const buyingPowerFallback = '结算后授予购买力，通常 4–5 个工作日（待 DW 确认）';
const seasoningFallback = 'ACH 入金到账后默认 30 天观察期内不可提现，可由 DW 配置调整（待 DW 确认）';
const achWithdrawalArrival = '通常 4–5 个工作日（待 DW 确认）';
const achWithdrawalFee = r'$0.25（DW 文档，待 DW 确认）';
