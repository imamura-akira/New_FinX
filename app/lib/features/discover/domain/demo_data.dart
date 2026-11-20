import 'package:material_ui/material_ui.dart';

/// F13 演示数据（纯客户端模拟，不调用后端）。机构名称与持仓均为虚构，来源 prototype/js/data.js。
class Institution {
  const Institution({
    required this.id,
    required this.name,
    required this.firm,
    required this.ret,
    required this.aum,
    required this.updated,
    required this.holdings,
  });
  final String id;
  final String name;
  final String firm;
  final double ret; // 年收益（小数）
  final double aum; // 资产增速（小数）
  final String updated; // MM-DD
  final List<String> holdings; // 前五大持仓（示例）
}

const institutions = <Institution>[
  Institution(
    id: 'i1',
    name: '北岸资本',
    firm: 'Northshore Capital (示例)',
    ret: .142,
    aum: .031,
    updated: '11-16',
    holdings: ['AAPL', 'MSFT', 'AMZN', 'JPM', 'KO'],
  ),
  Institution(
    id: 'i2',
    name: '长桥基金',
    firm: 'Longbridge Fund (示例)',
    ret: .087,
    aum: -.022,
    updated: '11-16',
    holdings: ['MSFT', 'GOOGL', 'META', 'SPY', 'TLT'],
  ),
  Institution(
    id: 'i3',
    name: '远山投资',
    firm: 'Farhill Investments (示例)',
    ret: -.018,
    aum: .054,
    updated: '11-15',
    holdings: ['KO', 'DIS', 'JPM', 'GLD', 'XLE'],
  ),
  Institution(
    id: 'i4',
    name: '晨湾资管',
    firm: 'Morning Bay AM (示例)',
    ret: .213,
    aum: .118,
    updated: '11-15',
    holdings: ['NVDA', 'AMD', 'TSLA', 'QQQ', 'XLK'],
  ),
  Institution(
    id: 'i5',
    name: '青石合伙',
    firm: 'Bluestone Partners (示例)',
    ret: .061,
    aum: -.047,
    updated: '11-14',
    holdings: ['AMZN', 'NFLX', 'DIS', 'IWM', 'EEM'],
  ),
  Institution(
    id: 'i6',
    name: '海岸价值',
    firm: 'Coastline Value (示例)',
    ret: .034,
    aum: .009,
    updated: '11-14',
    holdings: ['JPM', 'KO', 'TLT', 'GLD', 'SPY'],
  ),
  Institution(
    id: 'i7',
    name: '松林全球',
    firm: 'Pinewood Global (示例)',
    ret: -.072,
    aum: -.131,
    updated: '11-12',
    holdings: ['EEM', 'USO', 'SLV', 'DIA', 'KO'],
  ),
  Institution(
    id: 'i8',
    name: '星河量化',
    firm: 'Galaxy Quant (示例)',
    ret: .119,
    aum: .076,
    updated: '11-12',
    holdings: ['NVDA', 'MSFT', 'META', 'AAPL', 'VXX'],
  ),
];

Institution? institutionOf(String id) {
  for (final i in institutions) {
    if (i.id == id) return i;
  }
  return null;
}

/// 个股机会：代码、增持占总股本、增 / 平 / 减 家数（2026 年第三季度，演示数据）。
typedef Opportunity = (String symbol, double pct, int inc, int flat, int dec);

const opportunityFilters = <(String, String)>[('INC', '增持最多'), ('CONTRA', '逆势增持'), ('MOST', '持股最多'), ('NEW', '新进持股')];

const opportunities = <String, List<Opportunity>>{
  'INC': [('NVDA', .0412, 9, 3, 2), ('AMZN', .0365, 8, 4, 1), ('JPM', .0291, 6, 5, 1), ('DIS', .0218, 5, 2, 3), ('KO', .0144, 4, 6, 0)],
  'CONTRA': [('AMD', .0198, 5, 2, 4), ('GOOGL', .0172, 6, 3, 3), ('DIS', .0133, 4, 4, 2)],
  'MOST': [('AAPL', .0611, 7, 12, 3), ('MSFT', .0583, 8, 10, 2), ('AMZN', .0477, 8, 7, 1)],
  'NEW': [('NFLX', .0089, 4, 0, 0), ('TSLA', .0071, 3, 0, 0), ('XLK', .0052, 2, 0, 0)],
};

/// Fifi 功能中心（P-26）六个功能。
const fifiFeatures = <(IconData, String, String)>[
  (Icons.pie_chart_outline_rounded, '持仓体检', '分析持仓结构与未实现盈亏'),
  (Icons.swap_horiz_rounded, '持有或卖出', '对比趋势、风险与仓位'),
  (Icons.search_rounded, '个股研究', '汇总价格、基本面与新闻'),
  (Icons.warning_amber_rounded, '风险提醒', '识别波动、集中度与回撤'),
  (Icons.bar_chart_rounded, '量化信号', '动量、反转、成交量等因子'),
  (Icons.menu_book_outlined, '投资课堂', '用简单的语言理解投资逻辑'),
];

/// 奖励中心（P-27）各等级商品：名称、所需 XP。
/// F16 P-27 圣诞新手礼（等级 1 解锁；演示示例，正式奖品以上线公告为准）。顺序对应 rewards_page.dart 的奖品图。
const xmasRewards = <(String, int)>[('FinX 运动水壶', 150), ('Fifi 圣诞绒帽', 200), ('无线耳机', 600), ('Fifi 斜挎包', 250)];

/// 头像底色（按名称稳定取色，原型 nameAvatar）。
const _avatarColors = [
  Color(0xFFA34D5B),
  Color(0xFF6B4FA5),
  Color(0xFF7FA05A),
  Color(0xFF8C9A4E),
  Color(0xFF4A9EA3),
  Color(0xFF4E9A79),
  Color(0xFF5B6FB0),
  Color(0xFFB0785B),
];

Color avatarColor(String name) => _avatarColors[name.runes.fold<int>(0, (a, b) => a + b) % _avatarColors.length];
