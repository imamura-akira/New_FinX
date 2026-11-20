import '../../../core/api/api_client.dart';
import '../../../l10n/l10n.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// 资产类别（F17；顺序与后端 items 一致：股票、ETF、现金）。
enum AssetClass {
  stock('STOCK'),
  etf('ETF'),
  cash('CASH');

  const AssetClass(this.code);
  final String code;

  String get label => switch (this) {
    AssetClass.stock => t.assetStock,
    AssetClass.etf => t.assetEtf,
    AssetClass.cash => t.assetCash,
  };
}

class AllocationItem {
  const AllocationItem(this.kind, this.amount, this.pct);
  final AssetClass kind;
  final double amount;
  final double pct; // 百分数，后端计算（一位小数）
}

/// GET /account/allocation（或 /paper/account/allocation）。
class Allocation {
  const Allocation({required this.simulated, required this.total, required this.items});
  factory Allocation.fromJson(Map<String, dynamic> j) {
    final byCode = {
      for (final i in (j['items'] as List? ?? const [])) '${(i as Map)['type']}': (_d(i['amount']), _d(i['pct'])),
    };
    return Allocation(
      simulated: j['simulated'] == true,
      total: _d(j['total']),
      items: [
        for (final c in AssetClass.values) AllocationItem(c, byCode[c.code]?.$1 ?? 0, byCode[c.code]?.$2 ?? 0),
      ],
    );
  }
  final bool simulated;
  final double total;
  final List<AllocationItem> items;
}

/// 资产趋势区间。
enum HistoryRange {
  d7('7D', 7),
  d30('30D', 30),
  d90('90D', 90),
  all('ALL', 0);

  const HistoryRange(this.code, this.days);
  final String code;
  final int days; // 0 = 全部

  String get label => days == 0 ? t.rangeAll : t.rangeDays(days);
}

class AssetPoint {
  const AssetPoint(this.date, this.total);
  final DateTime date; // 美东日期
  final double total;
}

/// 资产分布与趋势接口（api-spec.md 第 3 节 / 5.7；paper=true 走模拟盘）。
class PortfolioApi {
  PortfolioApi(this._api, {this.paper = false});
  final ApiClient _api;
  final bool paper;
  String get _base => paper ? '/paper/account' : '/account';

  Future<Allocation> allocation() async => Allocation.fromJson(await _api.get('$_base/allocation') as Map<String, dynamic>);

  Future<List<AssetPoint>> history(HistoryRange range) async {
    final d = await _api.get('$_base/history', query: {'range': range.code}) as Map<String, dynamic>;
    return [
      for (final p in (d['points'] as List? ?? const []))
        if (DateTime.tryParse('${(p as Map)['date']}') case final t?) AssetPoint(t, _d(p['total'])),
    ];
  }
}
