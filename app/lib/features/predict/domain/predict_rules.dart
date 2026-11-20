import 'dart:math' as math;

import '../../../l10n/l10n.dart';

// F19 预测规则（与后端 internal/predict 一致；后端为准）。

const predictMinStake = 10;
const predictMaxStake = 5000;

/// 若正确可得（含本金）：floor(stake ÷ p)，p 夹在 [2%, 98%]。与后端 Payout 一致。
int predictPayout(int stake, double p) => (stake / math.max(.02, math.min(.98, p)) + 1e-9).floor();

/// 下注积分校验：null 为通过。
String? validateStake(String raw, int balance) {
  final v = int.tryParse(raw.trim());
  if (v == null || v < predictMinStake || v > predictMaxStake) {
    return t.predictStakeInvalid;
  }
  if (v > balance) return t.predictStakeInsufficient;
  return null;
}

/// 12,400。
String fmtPoints(int v) {
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}$b';
}

/// 带符号的积分：+120 / -80 / 0。
String fmtPointsSigned(int v) => v > 0 ? '+${fmtPoints(v)}' : fmtPoints(v);

/// 倒计时 mm:ss（超过 1 小时 h:mm:ss；到期 00:00）。
String fmtCountdown(Duration d) {
  if (d.isNegative) return '00:00';
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// 截止日期：中文 12月18日，英文 Dec 18（本地时间）。
String fmtMonthDay(DateTime d) {
  final l = d.toLocal();
  return t.predictMonthDay(isEnglish ? _months[l.month - 1] : l.month, l.day);
}

/// 分类代码 → 文案（全部 / 加密 / 美股 / 宏观 / 体育 / 热点）。
const predictCategories = ['ALL', 'CRYPTO', 'STOCKS', 'MACRO', 'SPORTS', 'TRENDING'];

String predictCategoryLabel(String c) => switch (c) {
  'CRYPTO' => t.predictCatCrypto,
  'STOCKS' => t.predictCatStocks,
  'MACRO' => t.predictCatMacro,
  'SPORTS' => t.predictCatSports,
  'TRENDING' => t.predictCatTrending,
  _ => t.predictCatAll,
};

String predictStatusLabel(String s) => switch (s) {
  'WON' => t.predictStatusWon,
  'LOST' => t.predictStatusLost,
  'VOID' => t.predictStatusVoid,
  _ => t.predictStatusOpen,
};
