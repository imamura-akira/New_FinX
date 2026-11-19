/// 金额与时间格式（原型 fmt.money / fmt.dt）。
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

String _two(int n) => n.toString().padLeft(2, '0');

/// 2026-11-19 14:05（本地时间）。
String fmtDateTime(DateTime? t) {
  if (t == null) return '—';
  final l = t.toLocal();
  return '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';
}

/// 14:05。
String fmtTime(DateTime? t) {
  if (t == null) return '—';
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}';
}
