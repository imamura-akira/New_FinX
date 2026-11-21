import 'package:finx_app/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

// F22-c / F22-f 美东时间：夏令时边界、零点倒计时。
void main() {
  test('夏令时边界：3 月第二个周日 02:00 起、11 月第一个周日 02:00 止', () {
    expect(isEasternDst(DateTime.utc(2026, 3, 8, 6, 59)), isFalse); // 01:59 EST
    expect(isEasternDst(DateTime.utc(2026, 3, 8, 7, 0)), isTrue); // 03:00 EDT
    expect(isEasternDst(DateTime.utc(2026, 11, 1, 5, 59)), isTrue); // 01:59 EDT
    expect(isEasternDst(DateTime.utc(2026, 11, 1, 6, 0)), isFalse); // 01:00 EST
    expect(isEasternDst(DateTime.utc(2026, 7, 1)), isTrue);
    expect(isEasternDst(DateTime.utc(2026, 12, 1)), isFalse);
  });

  test('成交时间格式：2026-11-21 · 09:32 AM ET；夏令时 UTC-4', () {
    expect(fmtEtDateTime(DateTime.utc(2026, 11, 21, 14, 32)), '2026-11-21 · 09:32 AM ET');
    expect(fmtEtDateTime(DateTime.utc(2026, 7, 6, 17, 5)), '2026-07-06 · 01:05 PM ET');
    expect(fmtEtDateTime(DateTime.utc(2026, 11, 21, 4, 0)), '2026-11-20 · 11:00 PM ET', reason: '跨日');
    expect(fmtEtDateTime(DateTime.utc(2026, 11, 21, 5, 0)), '2026-11-21 · 12:00 AM ET');
    expect(fmtEtDateTime(null), '—');
  });

  test('下一个美东零点', () {
    expect(nextEasternMidnight(DateTime.utc(2026, 11, 21, 15)), DateTime.utc(2026, 11, 22, 5));
    expect(nextEasternMidnight(DateTime.utc(2026, 11, 22, 4, 59)), DateTime.utc(2026, 11, 22, 5), reason: '23:59 ET');
    expect(nextEasternMidnight(DateTime.utc(2026, 11, 22, 5)), DateTime.utc(2026, 11, 23, 5), reason: '恰在零点：下一个');
    expect(nextEasternMidnight(DateTime.utc(2026, 7, 6, 12)), DateTime.utc(2026, 7, 7, 4));
    expect(nextEasternMidnight(DateTime.utc(2026, 10, 31, 12)), DateTime.utc(2026, 11, 1, 4), reason: '夏令时最后一晚');
    expect(nextEasternMidnight(DateTime.utc(2026, 11, 1, 12)), DateTime.utc(2026, 11, 2, 5), reason: '切换日当天');
  });
}
