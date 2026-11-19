import 'package:material_ui/material_ui.dart';

/// 证券目录（与后端 marketsim.DefaultInstruments 一致；报价接口不含名称与类型，列表页用本目录补全）。
class InstrumentInfo {
  const InstrumentInfo(this.symbol, this.name, this.type, [this.etfCategory]);
  final String symbol;
  final String name;
  final String type; // STOCK / ETF
  final String? etfCategory;
}

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
  InstrumentInfo('SPY', 'SPDR S&P 500 ETF', 'ETF', '大盘指数'),
  InstrumentInfo('QQQ', 'Invesco QQQ Trust', 'ETF', '大盘指数'),
  InstrumentInfo('DIA', 'SPDR Dow Jones Industrial ETF', 'ETF', '大盘指数'),
  InstrumentInfo('IWM', 'iShares Russell 2000 ETF', 'ETF', '大盘指数'),
  InstrumentInfo('GLD', 'SPDR Gold Shares', 'ETF', '大宗商品'),
  InstrumentInfo('SLV', 'iShares Silver Trust', 'ETF', '大宗商品'),
  InstrumentInfo('USO', 'United States Oil Fund', 'ETF', '大宗商品'),
  InstrumentInfo('TLT', 'iShares 20+ Year Treasury Bond ETF', 'ETF', '债券'),
  InstrumentInfo('XLK', 'Technology Select Sector SPDR', 'ETF', '行业'),
  InstrumentInfo('XLE', 'Energy Select Sector SPDR', 'ETF', '行业'),
  InstrumentInfo('EEM', 'iShares MSCI Emerging Markets ETF', 'ETF', '海外市场'),
  InstrumentInfo('VXX', 'iPath S&P 500 VIX ST Futures ETN', 'ETF', '波动率'),
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
