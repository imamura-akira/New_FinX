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

// ---------------------------------------------------------------------------
// 美东时间（F22-c 成交时间、F22-f 任务重置倒计时）。美国夏令时：3 月第二个周日 02:00 至 11 月第一个周日 02:00（当地时间）。

DateTime _nthSunday(int year, int month, int n) {
  final first = DateTime.utc(year, month, 1);
  final offset = (DateTime.sunday - first.weekday) % 7;
  return DateTime.utc(year, month, 1 + offset + 7 * (n - 1));
}

/// [t] 所在时刻美东是否为夏令时（EDT，UTC-4）。
bool isEasternDst(DateTime t) {
  final u = t.toUtc();
  final start = _nthSunday(u.year, 3, 2).add(const Duration(hours: 7)); // 02:00 EST = 07:00 UTC
  final end = _nthSunday(u.year, 11, 1).add(const Duration(hours: 6)); // 02:00 EDT = 06:00 UTC
  return !u.isBefore(start) && u.isBefore(end);
}

/// 美东墙上时间（返回值的年月日时分即美东当地时间，以 UTC 标记承载，勿再转换时区）。
DateTime toEastern(DateTime t) => t.toUtc().subtract(Duration(hours: isEasternDst(t) ? 4 : 5));

/// 下一个美东零点（UTC 时刻）。
DateTime nextEasternMidnight(DateTime now) {
  final et = toEastern(now);
  final midnightWall = DateTime.utc(et.year, et.month, et.day + 1);
  // 墙上时间 → UTC：先按当前偏移估算，再按该时刻的偏移校正（跨越夏令时切换日）
  var utc = midnightWall.add(Duration(hours: isEasternDst(now) ? 4 : 5));
  utc = midnightWall.add(Duration(hours: isEasternDst(utc) ? 4 : 5));
  return utc;
}

/// 2026-11-21 · 09:32 AM ET
String fmtEtDateTime(DateTime? t) {
  if (t == null) return '—';
  final e = toEastern(t);
  String two(int v) => v.toString().padLeft(2, '0');
  final h12 = e.hour % 12 == 0 ? 12 : e.hour % 12;
  return '${e.year}-${two(e.month)}-${two(e.day)} · ${two(h12)}:${two(e.minute)} ${e.hour < 12 ? 'AM' : 'PM'} ET';
}
