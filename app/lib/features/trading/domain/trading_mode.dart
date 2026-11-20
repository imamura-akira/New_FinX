import 'package:material_ui/material_ui.dart';

/// 实盘 / 模拟盘（F15）当前选择：资产页与交易页的切换共用；本次运行内有效，默认实盘。
/// 模拟盘数据全部来自 /paper/*，绝不与 DW 资金数字混用。
class TradingMode extends ValueNotifier<bool> {
  TradingMode() : super(false);

  static final instance = TradingMode();

  bool get paper => value;
  set paper(bool v) => value = v;

  @visibleForTesting
  void reset() => value = false;
}

/// 路由查询参数：模拟盘页面带 `paper=1`。
String paperQuery(bool paper, [String sep = '?']) => paper ? '${sep}paper=1' : '';
