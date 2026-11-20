import '../l10n/l10n.dart';

/// 金额与时间格式（原型 fmt.money / fmt.dt）。金额两种语言一致（$1,234.56）；时间按语言（F18）。
String fmtUsd(double v) {
  final neg = v < 0;
  final fixed = v.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return '${neg ? '-' : ''}\$$buf.${parts[1]}';
}

/// 中文 2026-11-19 14:05 / 英文 11/19/2026 2:05 PM（本地时间）。
String fmtDateTime(DateTime? time) => time == null ? '—' : formatDateTime(time.toLocal());

/// 中文 14:05 / 英文 2:05 PM。
String fmtTime(DateTime? time) => time == null ? '—' : formatClock(time.toLocal());

/// 中文 2026-11-19 / 英文 11/19/2026。
String fmtDate(DateTime? time) => time == null ? '—' : formatDate(time.toLocal());
