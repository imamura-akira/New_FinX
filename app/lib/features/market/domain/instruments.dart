import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// 证券目录（与后端 marketsim.DefaultInstruments 一致；报价接口不含名称与类型，列表页用本目录补全）。
class InstrumentInfo {
  const InstrumentInfo(this.symbol, this.name, this.type, [this.etfCategory]);
  final String symbol;
  final String name;
  final String type; // STOCK / ETF
  final String? etfCategory; // ETF 分类代码（INDEX / COMMODITY / BOND / SECTOR / INTL / VOLATILITY），显示文案见 [etfCategoryLabel]
}

/// ETF 分类代码（P-09 筛选顺序）。
const etfCategories = ['INDEX', 'COMMODITY', 'BOND', 'SECTOR', 'INTL', 'VOLATILITY'];

String etfCategoryLabel(String code) => switch (code) {
  'INDEX' => t.etfCatIndex,
  'COMMODITY' => t.etfCatCommodity,
  'BOND' => t.etfCatBond,
  'SECTOR' => t.etfCatSector,
  'INTL' => t.etfCatIntl,
  'VOLATILITY' => t.etfCatVolatility,
  _ => code,
};

const instruments = <InstrumentInfo>[
  InstrumentInfo('AAPL', 'Apple Inc.', 'STOCK'),
  InstrumentInfo('MSFT', 'Microsoft Corp.', 'STOCK'),
  InstrumentInfo('NVDA', 'NVIDIA Corp.', 'STOCK'),
  InstrumentInfo('AMZN', 'Amazon.com Inc.', 'STOCK'),
  InstrumentInfo('GOOGL', 'Alphabet Inc. Cl A', 'STOCK'),
  InstrumentInfo('TSLA', 'Tesla Inc.', 'STOCK'),
  InstrumentInfo('META', 'Meta Platforms Inc.', 'STOCK'),
  InstrumentInfo('JPM', 'JPMorgan Chase & Co.', 'STOCK'),
  InstrumentInfo('KO', 'Coca-Cola Co.', 'STOCK'),
  InstrumentInfo('DIS', 'Walt Disney Co.', 'STOCK'),
  InstrumentInfo('NFLX', 'Netflix Inc.', 'STOCK'),
  InstrumentInfo('AMD', 'Advanced Micro Devices', 'STOCK'),
  InstrumentInfo('SPY', 'SPDR S&P 500 ETF', 'ETF', 'INDEX'),
  InstrumentInfo('QQQ', 'Invesco QQQ Trust', 'ETF', 'INDEX'),
  InstrumentInfo('DIA', 'SPDR Dow Jones Industrial ETF', 'ETF', 'INDEX'),
  InstrumentInfo('IWM', 'iShares Russell 2000 ETF', 'ETF', 'INDEX'),
  InstrumentInfo('GLD', 'SPDR Gold Shares', 'ETF', 'COMMODITY'),
  InstrumentInfo('SLV', 'iShares Silver Trust', 'ETF', 'COMMODITY'),
  InstrumentInfo('USO', 'United States Oil Fund', 'ETF', 'COMMODITY'),
  InstrumentInfo('TLT', 'iShares 20+ Year Treasury Bond ETF', 'ETF', 'BOND'),
  InstrumentInfo('XLK', 'Technology Select Sector SPDR', 'ETF', 'SECTOR'),
  InstrumentInfo('XLE', 'Energy Select Sector SPDR', 'ETF', 'SECTOR'),
  InstrumentInfo('EEM', 'iShares MSCI Emerging Markets ETF', 'ETF', 'INTL'),
  InstrumentInfo('VXX', 'iPath S&P 500 VIX ST Futures ETN', 'ETF', 'VOLATILITY'),
];

InstrumentInfo? instrumentOf(String symbol) {
  for (final i in instruments) {
    if (i.symbol == symbol) return i;
  }
  return null;
}

/// 自选股（Demo-1 无自选接口：保存在本次运行内存中，默认几只演示股票）。
class Watchlist extends ChangeNotifier {
  Watchlist([List<String>? initial]) : _symbols = [...(initial ?? defaults)];

  static const defaults = ['AAPL', 'NVDA', 'TSLA', 'SPY', 'QQQ'];
  static final instance = Watchlist();

  final List<String> _symbols;
  List<String> get symbols => List.unmodifiable(_symbols);
  bool contains(String s) => _symbols.contains(s);

  void toggle(String s) {
    contains(s) ? _symbols.remove(s) : _symbols.add(s);
    notifyListeners();
  }

  void reset() {
    _symbols
      ..clear()
      ..addAll(defaults);
    notifyListeners();
  }
}
