import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';

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

List<Institution> get institutions => <Institution>[
  Institution(
    id: 'i1',
    name: t.demoNorthshoreCapital,
    firm: t.demoNorthshoreCapitalSample,
    ret: .142,
    aum: .031,
    updated: '11-16',
    holdings: ['AAPL', 'MSFT', 'AMZN', 'JPM', 'KO'],
  ),
  Institution(
    id: 'i2',
    name: t.demoLongbridgeFund,
    firm: t.demoLongbridgeFundSample,
    ret: .087,
    aum: -.022,
    updated: '11-16',
    holdings: ['MSFT', 'GOOGL', 'META', 'SPY', 'TLT'],
  ),
  Institution(
    id: 'i3',
    name: t.demoFarhillInvestments,
    firm: t.demoFarhillInvestmentsSample,
    ret: -.018,
    aum: .054,
    updated: '11-15',
    holdings: ['KO', 'DIS', 'JPM', 'GLD', 'XLE'],
  ),
  Institution(
    id: 'i4',
    name: t.demoMorningBayAm,
    firm: t.demoMorningBayAmSample,
    ret: .213,
    aum: .118,
    updated: '11-15',
    holdings: ['NVDA', 'AMD', 'TSLA', 'QQQ', 'XLK'],
  ),
  Institution(
    id: 'i5',
    name: t.demoBluestonePartners,
    firm: t.demoBluestonePartnersSample,
    ret: .061,
    aum: -.047,
    updated: '11-14',
    holdings: ['AMZN', 'NFLX', 'DIS', 'IWM', 'EEM'],
  ),
  Institution(
    id: 'i6',
    name: t.demoCoastlineValue,
    firm: t.demoCoastlineValueSample,
    ret: .034,
    aum: .009,
    updated: '11-14',
    holdings: ['JPM', 'KO', 'TLT', 'GLD', 'SPY'],
  ),
  Institution(
    id: 'i7',
    name: t.demoPinewoodGlobal,
    firm: t.demoPinewoodGlobalSample,
    ret: -.072,
    aum: -.131,
    updated: '11-12',
    holdings: ['EEM', 'USO', 'SLV', 'DIA', 'KO'],
  ),
  Institution(
    id: 'i8',
    name: t.demoGalaxyQuant,
    firm: t.demoGalaxyQuantSample,
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

List<(String, String)> get opportunityFilters => <(String, String)>[('INC', t.demoMostIncreased), ('CONTRA', t.demoContrarianBuys), ('MOST', t.demoMostHeld), ('NEW', t.demoNewPositions)];

const opportunities = <String, List<Opportunity>>{
  'INC': [('NVDA', .0412, 9, 3, 2), ('AMZN', .0365, 8, 4, 1), ('JPM', .0291, 6, 5, 1), ('DIS', .0218, 5, 2, 3), ('KO', .0144, 4, 6, 0)],
  'CONTRA': [('AMD', .0198, 5, 2, 4), ('GOOGL', .0172, 6, 3, 3), ('DIS', .0133, 4, 4, 2)],
  'MOST': [('AAPL', .0611, 7, 12, 3), ('MSFT', .0583, 8, 10, 2), ('AMZN', .0477, 8, 7, 1)],
  'NEW': [('NFLX', .0089, 4, 0, 0), ('TSLA', .0071, 3, 0, 0), ('XLK', .0052, 2, 0, 0)],
};

/// Fifi 功能中心（P-26）六个功能。
/// 奖励中心（P-27）各等级商品：名称、所需 XP。
/// F16 P-27 圣诞新手礼（等级 1 解锁；演示示例，正式奖品以上线公告为准）。顺序对应 rewards_page.dart 的奖品图。
List<(String, int)> get xmasRewards => <(String, int)>[(t.demoFinxSportsBottle, 150), (t.demoFifiHolidayBeanie, 200), (t.demoWirelessHeadphones, 600), (t.demoFifiCrossbodyBag, 250)];

/// 头像底色（按名称稳定取色，原型 nameAvatar；色值见 theme.dart AvatarColors）。
Color avatarColor(String name) => AvatarColors.all[name.runes.fold<int>(0, (a, b) => a + b) % AvatarColors.all.length];
