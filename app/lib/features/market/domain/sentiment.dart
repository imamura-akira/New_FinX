import 'package:material_ui/material_ui.dart';

/// 市场情绪（F11 扩展，P-09）：恐慌贪婪指数档位映射。与后端 marketsim.FearGreedLabel 一致：
/// 0–24 极度恐慌，25–44 恐慌，45–55 中性，56–75 贪婪，76–100 极度贪婪。
enum FearGreedLevel {
  extremeFear('极度恐慌', Color(0xFFC2373C), Color(0xFFFDEDEE)),
  fear('恐慌', Color(0xFFC2640A), Color(0xFFFFF1E3)),
  neutral('中性', Color(0xFF6B7191), Color(0xFFF1EFFA)),
  greed('贪婪', Color(0xFFB57E0C), Color(0xFFFBF3DF)),
  extremeGreed('极度贪婪', Color(0xFF15803D), Color(0xFFE7F6EC));

  const FearGreedLevel(this.label, this.text, this.bg);
  final String label;
  final Color text;
  final Color bg;

  static FearGreedLevel of(int value) {
    final v = value.clamp(0, 100);
    if (v <= 24) return extremeFear;
    if (v <= 44) return fear;
    if (v <= 55) return neutral;
    if (v <= 75) return greed;
    return extremeGreed;
  }
}

/// 涨跌家数（后端按全部虚拟标的统计）。
class Breadth {
  const Breadth({required this.up, required this.down, required this.flat});
  final int up;
  final int down;
  final int flat;
  int get total => up + down + flat;

  /// 比例条三段（上涨 / 平盘 / 下跌）的 flex 权重；全为 0 时三段等分。
  (int, int, int) get flexes => total == 0 ? (1, 1, 1) : (up, flat, down);
}
