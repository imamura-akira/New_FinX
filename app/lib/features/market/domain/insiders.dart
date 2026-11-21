/// F22-b P-09 内部人交易三卡：**演示数据（seed）**，界面带"演示数据"角标。
/// 上线门槛：需接入真实数据源（如 SEC Form 4）或移除本区块（design/audit-20261121.md 门槛清单登记）。
class InsiderHighlight {
  const InsiderHighlight(this.kind, this.symbol, {this.amountB, this.trades});
  final InsiderKind kind;
  final String symbol;
  final double? amountB; // 金额（十亿美元）
  final int? trades;
}

enum InsiderKind { topBuy, topSell, mostActive }

const insiderHighlights = [
  InsiderHighlight(InsiderKind.topBuy, 'NVDA', amountB: 6.2),
  InsiderHighlight(InsiderKind.topSell, 'TSLA', amountB: 1.8),
  InsiderHighlight(InsiderKind.mostActive, 'AAPL', trades: 64),
];
