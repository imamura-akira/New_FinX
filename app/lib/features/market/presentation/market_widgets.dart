import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../data/market_api.dart';
import '../domain/instruments.dart';

/// 行情轮询间隔（api-spec.md 5.5：3–5 秒）。
const quotePollInterval = Duration(seconds: 3);

/// 批量报价轮询：页面可见期间每 3 秒刷新；记录每只证券最近一次价格变动方向（用于涨跌闪色）。
class QuoteFeed extends ChangeNotifier {
  QuoteFeed(this._api, {List<String>? symbols}) : _symbols = symbols == null ? null : List.of(symbols);
  final MarketApi _api;
  List<String>? _symbols; // null = 全部

  Map<String, Quote> quotes = {};
  Map<String, int> moved = {}; // 本次刷新相对上次的方向：1 上涨 / -1 下跌
  DateTime? ts;
  bool simulated = true;
  String? error;
  Timer? _timer;
  bool _disposed = false;

  void start() {
    _load();
    _timer?.cancel();
    _timer = Timer.periodic(quotePollInterval, (_) => _load());
  }

  set symbols(List<String>? s) {
    _symbols = s;
    _load();
  }

  Future<void> _load() async {
    final s = _symbols;
    if (s != null && s.isEmpty) {
      quotes = {};
      if (!_disposed) notifyListeners();
      return;
    }
    try {
      final b = await _api.quotes(s);
      if (_disposed) return;
      final mv = <String, int>{};
      b.quotes.forEach((k, q) {
        final prev = quotes[k];
        if (prev != null && q.last != prev.last) mv[k] = q.last > prev.last ? 1 : -1;
      });
      quotes = b.quotes;
      moved = mv;
      ts = b.ts;
      simulated = b.simulated;
      error = null;
    } on ApiException catch (e) {
      if (_disposed) return;
      error = e.isSessionInvalid ? null : e.message;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

Color chgColor(double v) => v > 0
    ? AppColors.up
    : v < 0
    ? AppColors.down
    : AppColors.muted;

String fmtPx(double v) => v.toStringAsFixed(2);

String fmtSigned(double v, {String suffix = ''}) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}$suffix';

/// 涨跌幅色块（原型 C.chg）。
class ChgPill extends StatelessWidget {
  const ChgPill(this.pct, {super.key});
  final double pct;

  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: chgColor(pct), borderRadius: BorderRadius.circular(8)),
    child: Text(
      fmtSigned(pct, suffix: '%'),
      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
    ),
  );
}

/// 报价行（原型 C.qrow）：代码 / 名称 / 最新价 / 涨跌幅；价格变动时短暂闪色。
class QuoteRow extends StatelessWidget {
  const QuoteRow({super.key, required this.symbol, this.quote, this.moved = 0});
  final String symbol;
  final Quote? quote;
  final int moved;

  @override
  Widget build(BuildContext context) {
    final info = instrumentOf(symbol);
    final q = quote;
    final flash = moved == 0 ? Colors.transparent : (moved > 0 ? AppColors.up : AppColors.down).withValues(alpha: .10);
    return InkWell(
      key: Key('quote.$symbol'),
      onTap: () => context.push('/market/$symbol'),
      child: TweenAnimationBuilder<Color?>(
        key: ValueKey('${q?.last}'), // 每次价格变化重新播放闪色
        tween: ColorTween(begin: flash, end: Colors.transparent),
        duration: const Duration(milliseconds: 900),
        builder: (context, c, child) => Container(color: c, child: child),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(symbol, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                      info?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Text(
                q == null ? '—' : fmtPx(q.last),
                key: Key('quote.$symbol.last'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const SizedBox(width: 12),
              q == null ? const SizedBox(width: 76) : ChgPill(q.chgPct),
            ],
          ),
        ),
      ),
    );
  }
}

/// 数据来源说明（原型 C.dataNote）。
class MarketDataNote extends StatelessWidget {
  const MarketDataNote({super.key, this.ts});
  final DateTime? ts;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      '演示数据：虚拟行情（随机模拟，非真实报价）${ts == null ? '' : ' · 更新于 ${fmtTime(ts)}'}\n行情数据仅供参考，不构成投资建议。',
      key: const Key('market.note'),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12, color: AppColors.faint, height: 1.5),
    ),
  );
}
