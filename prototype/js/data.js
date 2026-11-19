'use strict';
/* 演示数据：全部为虚构数值，非真实行情或真实账户。 */

const DATA = (() => {
  // 证券主清单（清单 23：只有清单内证券可被搜索、展示、交易）
  const instruments = [
    ['AAPL', 'Apple Inc.', 'NASDAQ', 'STOCK', 228.52, 226.10, '3.47T', 34.8],
    ['MSFT', 'Microsoft Corp.', 'NASDAQ', 'STOCK', 415.30, 418.02, '3.09T', 35.2],
    ['NVDA', 'NVIDIA Corp.', 'NASDAQ', 'STOCK', 132.85, 129.40, '3.26T', 52.6],
    ['AMZN', 'Amazon.com Inc.', 'NASDAQ', 'STOCK', 201.12, 199.80, '2.11T', 42.9],
    ['GOOGL', 'Alphabet Inc. Cl A', 'NASDAQ', 'STOCK', 172.40, 173.95, '2.13T', 22.7],
    ['TSLA', 'Tesla Inc.', 'NASDAQ', 'STOCK', 248.60, 241.20, '794B', 68.1],
    ['META', 'Meta Platforms Inc.', 'NASDAQ', 'STOCK', 563.10, 560.00, '1.42T', 27.4],
    ['JPM', 'JPMorgan Chase & Co.', 'NYSE', 'STOCK', 221.75, 222.90, '624B', 12.3],
    ['KO', 'Coca-Cola Co.', 'NYSE', 'STOCK', 63.20, 63.05, '272B', 25.9],
    ['DIS', 'Walt Disney Co.', 'NYSE', 'STOCK', 112.40, 110.10, '204B', 41.0],
    ['NFLX', 'Netflix Inc.', 'NASDAQ', 'STOCK', 760.50, 752.00, '325B', 43.1],
    ['AMD', 'Advanced Micro Devices', 'NASDAQ', 'STOCK', 145.20, 149.80, '235B', 128.4],
    ['SPY', 'SPDR S&P 500 ETF', 'NYSE Arca', 'ETF', 590.20, 592.00, '—', null],
    ['QQQ', 'Invesco QQQ Trust', 'NASDAQ', 'ETF', 505.40, 508.70, '—', null],
    ['DIA', 'SPDR Dow Jones Industrial ETF', 'NYSE Arca', 'ETF', 438.10, 440.90, '—', null],
    ['IWM', 'iShares Russell 2000 ETF', 'NYSE Arca', 'ETF', 228.30, 226.90, '—', null],
    ['GLD', 'SPDR Gold Shares', 'NYSE Arca', 'ETF', 245.60, 241.20, '—', null],
    ['SLV', 'iShares Silver Trust', 'NYSE Arca', 'ETF', 29.40, 28.50, '—', null],
    ['USO', 'United States Oil Fund', 'NYSE Arca', 'ETF', 76.20, 75.40, '—', null],
    ['TLT', 'iShares 20+ Year Treasury Bond ETF', 'NASDAQ', 'ETF', 92.10, 92.60, '—', null],
    ['XLK', 'Technology Select Sector SPDR', 'NYSE Arca', 'ETF', 232.30, 230.10, '—', null],
    ['XLE', 'Energy Select Sector SPDR', 'NYSE Arca', 'ETF', 91.00, 91.80, '—', null],
    ['EEM', 'iShares MSCI Emerging Markets ETF', 'NYSE Arca', 'ETF', 43.40, 42.90, '—', null],
    ['VXX', 'iPath S&P 500 VIX ST Futures ETN', 'CBOE', 'ETF', 48.00, 49.60, '—', null],
  ].map(([symbol, name, exchange, type, last, prev, mcap, pe]) => ({
    symbol, name, exchange, type, last, prev, mcap, pe,
    // VXX：清单内仅展示行情、暂不开放交易（演示"不可交易"状态）
    isTradable: symbol !== 'VXX',
    etfCategory: { SPY: '大盘指数', QQQ: '大盘指数', DIA: '大盘指数', IWM: '大盘指数', GLD: '大宗商品', SLV: '大宗商品', USO: '大宗商品', TLT: '债券', XLK: '行业', XLE: '行业', EEM: '海外市场', VXX: '波动率' }[symbol] || null,
  }));

  // 不在主清单内的代码（搜索时展示"不可用"而非结果）
  const blocked = [
    { symbol: 'ABCDF', reason: '场外交易证券，不在本平台可交易清单内' },
    { symbol: 'ZZTX', reason: '已退市证券，不在本平台可交易清单内' },
  ];

  const etfThemes = [
    ['黄金', 'GLD'], ['白银', 'SLV'], ['原油', 'USO'], ['波动率', 'VXX'],
    ['标普', 'SPY'], ['纳指', 'QQQ'], ['道指', 'DIA'], ['新兴市场', 'EEM'],
  ];

  const advDecline = {
    day: [58, 64, 150, 290, 2810, 340, 3020, 310, 120, 70, 55],
    month: [210, 260, 480, 900, 2100, 120, 2350, 980, 520, 290, 240],
    labels: ['>10%', '10~7', '7~5', '5~3', '3~0', '0', '0~3', '3~5', '5~7', '7~10', '>10%'],
  };

  const insider = [
    { symbol: 'AMZN', type: 'BUY', label: '增持最多', value: '净增持 2.40 亿美元' },
    { symbol: 'META', type: 'SELL', label: '减持最多', value: '净减持 1.15 亿美元' },
    { symbol: 'NVDA', type: 'ACTIVE', label: '最活跃', value: '内部人交易 18 次' },
  ];

  // 机构（虚构名称）
  const institutions = [
    { id: 'i1', name: '北岸资本', firm: 'Northshore Capital (示例)', ret: 0.142, aum: 0.031, updated: '11-16' },
    { id: 'i2', name: '长桥基金', firm: 'Longbridge Fund (示例)', ret: 0.087, aum: -0.022, updated: '11-16' },
    { id: 'i3', name: '远山投资', firm: 'Farhill Investments (示例)', ret: -0.018, aum: 0.054, updated: '11-15' },
    { id: 'i4', name: '晨湾资管', firm: 'Morning Bay AM (示例)', ret: 0.213, aum: 0.118, updated: '11-15' },
    { id: 'i5', name: '青石合伙', firm: 'Bluestone Partners (示例)', ret: 0.061, aum: -0.047, updated: '11-14' },
    { id: 'i6', name: '海岸价值', firm: 'Coastline Value (示例)', ret: 0.034, aum: 0.009, updated: '11-14' },
    { id: 'i7', name: '松林全球', firm: 'Pinewood Global (示例)', ret: -0.072, aum: -0.131, updated: '11-12' },
    { id: 'i8', name: '星河量化', firm: 'Galaxy Quant (示例)', ret: 0.119, aum: 0.076, updated: '11-12' },
  ];

  const opportunities = {
    INC: [['NVDA', 0.0412, 9, 3, 2], ['AMZN', 0.0365, 8, 4, 1], ['JPM', 0.0291, 6, 5, 1], ['DIS', 0.0218, 5, 2, 3], ['KO', 0.0144, 4, 6, 0]],
    CONTRA: [['AMD', 0.0198, 5, 2, 4], ['GOOGL', 0.0172, 6, 3, 3], ['DIS', 0.0133, 4, 4, 2]],
    MOST: [['AAPL', 0.0611, 7, 12, 3], ['MSFT', 0.0583, 8, 10, 2], ['AMZN', 0.0477, 8, 7, 1]],
    NEW: [['NFLX', 0.0089, 4, 0, 0], ['TSLA', 0.0071, 3, 0, 0], ['XLK', 0.0052, 2, 0, 0]],
  };

  const faqs = [
    ['开户需要多久？', '提交后由合作券商 DriveWealth 核验身份，结果会通过通知告知。具体时长待 DW 确认。'],
    // 出处（待 DW 确认）：https://developer.drivewealth.com/apis/docs/depositing-1 ；https://info.drivewealth.com/funding-withdrawal-policies
    ['入金多久到账？', 'ACH 入金结算后授予购买力，通常 4–5 个工作日；到账后默认有 30 天观察期，期间不可提现。电汇入金不受观察期限制。具体以 DW 配置为准（待 DW 确认）。'],
    ['什么是 Good Faith Violation？', '在现金账户中，使用尚未结算的资金买入证券，并在该资金结算前卖出，可能构成 Good Faith Violation。多次违规可能导致账户被限制。'],
    ['如何查看我的账户号码？', '点击右上角头像打开账户抽屉，账户卡片中即显示完整账户号码，可一键复制。'],
    ['如何关闭账户？', '需先卖出全部持仓、取消待处理订单并提取全部现金，或将资产转出至其他券商，之后可在 设置 → 关闭账户 中申请。'],
  ];

  // 相对今天的日期（演示数据用，保证观察期演示不随时间失效）
  const daysAgo = (n) => { const d = new Date(); d.setDate(d.getDate() - n); return d.toISOString().slice(0, 10); };

  // 新开立的实盘账户（无资金、无持仓）
  function liveNew() {
    return { accountNumber: 'DEMO-LV-' + String(Math.floor(10000000 + Math.random() * 89999999)), status: 'ACTIVE', dwStatus: 'OPEN', type: 'CASH', management: 'SELF', cash: 0, unsettled: 0, positions: [], orders: [], transactions: [], documents: [], violations: [] };
  }

  function liveApproved() {
    return {
      accountNumber: 'DEMO-LV-00042817',
      status: 'ACTIVE',
      dwStatus: 'OPEN', // DW 账户状态：PENDING / OPEN / OPEN_NO_NEW_TRADES / FROZEN / CLOSED
      type: 'CASH', management: 'SELF',
      cash: 4210.55, unsettled: 820.00,
      positions: [
        { symbol: 'AAPL', qty: 12, avgCost: 190.10 },
        { symbol: 'NVDA', qty: 30, avgCost: 118.40 },
        { symbol: 'SPY', qty: 5, avgCost: 540.00 },
        { symbol: 'TSLA', qty: 4, avgCost: 262.75 },
        { symbol: 'KO', qty: 0.0042, avgCost: 61.90 }, // 极小剩余持仓示例（清单 10）
      ],
      orders: [
        { orderId: 'O-10031', symbol: 'MSFT', side: 'BUY', orderType: 'LIMIT', tif: 'GTC', qty: 5, limitPrice: 400.00, filledQty: 0, avgFillPrice: null, status: 'NEW', fees: 0, createdAt: '2026-11-19T10:02:00', fills: [] },
        { orderId: 'O-10029', symbol: 'NVDA', side: 'SELL', orderType: 'LIMIT', tif: 'DAY', qty: 20, limitPrice: 140.00, filledQty: 8, avgFillPrice: 140.02, status: 'PARTIALLY_FILLED', fees: 0.05, createdAt: '2026-11-19T09:41:00', fills: [{ qty: 5, price: 140.00, time: '09:52:11' }, { qty: 3, price: 140.05, time: '10:15:40' }] },
        { orderId: 'O-10024', symbol: 'AAPL', side: 'BUY', orderType: 'MARKET', tif: 'DAY', qty: 2, filledQty: 2, avgFillPrice: 226.30, status: 'FILLED', fees: 0, createdAt: '2026-11-18T14:20:00', fills: [{ qty: 2, price: 226.30, time: '14:20:02' }] },
        { orderId: 'O-10019', symbol: 'TSLA', side: 'BUY', orderType: 'LIMIT', tif: 'DAY', qty: 3, limitPrice: 230.00, filledQty: 0, status: 'CANCELED', cancelReason: '用户主动取消', fees: 0, createdAt: '2026-11-17T11:05:00', fills: [] },
        { orderId: 'O-10012', symbol: 'DIS', side: 'BUY', orderType: 'LIMIT', tif: 'GTC', qty: 10, limitPrice: 95.00, filledQty: 0, status: 'CANCELED', cancelReason: '公司行动：证券发生股票分割，未成交的 GTC 订单已由系统取消', fees: 0, createdAt: '2026-11-10T10:00:00', fills: [] },
        { orderId: 'O-10008', symbol: 'META', side: 'BUY', orderType: 'MARKET', tif: 'DAY', qty: 10, filledQty: 0, status: 'REJECTED', rejectReason: '购买力不足', fees: 0, createdAt: '2026-11-06T15:30:00', fills: [] },
      ],
      transactions: [
        { id: 'T-9', type: 'TRADE', symbol: 'NVDA', side: 'SELL', qty: 8, price: 140.02, amount: 1120.11, fee: 0.05, date: '2026-11-19', status: '已成交', desc: '卖出 NVDA（部分成交）' },
        { id: 'T-8', type: 'TRADE', symbol: 'AAPL', side: 'BUY', qty: 2, price: 226.30, amount: -452.60, fee: 0, date: '2026-11-18', status: '已成交', desc: '买入 AAPL' },
        { id: 'T-8b', type: 'DEPOSIT', amount: 500, date: '2026-11-16', status: '被退回', dwStatus: 'RETURNED', failureReason: 'R01 账户余额不足', desc: 'ACH 入金 · 示例银行 ••6789' },
        // 已过 30 天观察期的 ACH 入金（可提现）
        { id: 'T-7', type: 'DEPOSIT', method: 'ACH', amount: 2000, date: daysAgo(40), status: '已到账', dwStatus: 'SUCCESSFUL', desc: 'ACH 入金 · 示例银行 ••6789' },
        // 仍在 30 天观察期内的 ACH 入金（演示扣减：可提现 = 现金 − 未结算 − 挂单占用 − 本笔）
        { id: 'T-7b', type: 'DEPOSIT', method: 'ACH', amount: 300, date: daysAgo(5), status: '已到账', dwStatus: 'SUCCESSFUL', desc: 'ACH 入金 · 示例银行 ••6789' },
        { id: 'T-6', type: 'CORP_ACTION', symbol: 'NVDA', amount: 0, date: '2026-11-12', status: '已处理', desc: '股票分割 2:1，持仓由 15 股变为 30 股，成本价同步调整', ca: { type: 'SPLIT', ratio: '2:1', before: 15, after: 30 } },
        { id: 'T-5', type: 'CORP_ACTION', symbol: 'DIS', amount: 0, date: '2026-11-10', status: '已处理', desc: '公司行动导致未成交订单 O-10012 被取消', ca: { type: 'ORDER_CANCEL', orderId: 'O-10012' } },
        { id: 'T-4', type: 'DIVIDEND', symbol: 'KO', amount: 0.01, date: '2026-10-01', status: '已入账', desc: 'KO 现金分红' },
        { id: 'T-3', type: 'FEE', amount: -0.02, date: '2026-09-28', status: '已扣除', desc: '监管费用（SEC/FINRA）' },
        { id: 'T-2', type: 'WITHDRAWAL', amount: -500, date: '2026-09-20', status: '已完成', desc: 'ACH 出金 · 示例银行 ••6789' },
        { id: 'T-1', type: 'DEPOSIT', amount: 10000, date: '2026-09-02', status: '已到账', desc: 'ACH 入金 · 示例银行 ••6789' },
      ],
      documents: [
        { id: 'D-1', type: 'TRADE_CONFIRM', title: '交易确认书 · NVDA 卖出', date: '2026-11-19', period: '2026-11' },
        { id: 'D-2', type: 'TRADE_CONFIRM', title: '交易确认书 · AAPL 买入', date: '2026-11-18', period: '2026-11' },
        { id: 'D-3', type: 'STATEMENT', title: '月度对账单 · 2026 年 10 月', date: '2026-11-05', period: '2026-10' },
        { id: 'D-4', type: 'STATEMENT', title: '月度对账单 · 2026 年 9 月', date: '2026-10-05', period: '2026-09' },
        { id: 'D-5', type: 'TAX', title: '税务表格 1099 综合表 · 2025 年度', date: '2026-02-15', period: '2025' },
      ],
      violations: [
        { type: 'Good Faith Violation', occurredAt: '2026-11-03', count: 1, restriction: '暂无限制（12 个月内累计 4 次将限制 90 天仅可使用已结算资金买入）', restrictionUntil: null },
      ],
    };
  }

  function liveUnavailable() {
    return { accountNumber: null, status: 'UNAVAILABLE', type: 'CASH', management: 'SELF', cash: 0, unsettled: 0, positions: [], orders: [], transactions: [], documents: [], violations: [] };
  }

  function paper() {
    return { accountNumber: 'DEMO-PP-00099120', status: 'ACTIVE', type: 'CASH', management: 'SELF', cash: 1000000, unsettled: 0, positions: [], orders: [], transactions: [], documents: [], violations: [] };
  }

  const notifications = [
    { id: 'n1', category: 'TRADE', title: '订单部分成交', body: 'NVDA 限价卖出 20 股，已成交 8 股，剩余 12 股仍在委托中。', at: '2026-11-19 10:15', read: false, link: '#/p11' },
    { id: 'n2', category: 'VIOLATION', title: '交易违规提醒：Good Faith Violation', body: '您于 11-03 使用未结算资金买入并在结算前卖出，记 1 次违规。12 个月内累计 4 次将限制账户 90 天。', at: '2026-11-04 09:00', read: false, link: '#/p17?tab=VIOLATION' },
    { id: 'n3', category: 'FUNDS', title: '入金已到账', body: 'ACH 入金 $2,000.00 已到账，可用于交易。', at: '2026-11-15 08:30', read: true, link: '#/p18' },
    { id: 'n4', category: 'ACCOUNT', title: '新文件可查看', body: '2026 年 10 月对账单已生成。', at: '2026-11-05 08:00', read: true, link: '#/p15?type=STATEMENT' },
    { id: 'n5', category: 'SYSTEM', title: '感恩节休市安排', body: '11 月 27 日美股休市，11 月 28 日提前收盘。入金与结算时间相应顺延。', at: '2026-11-18 12:00', read: true, link: null },
  ];

  function initialState(scenario = 'fresh') {
    const s = {
      v: 2,
      scenario,
      loggedIn: scenario !== 'fresh',
      // App 登录账户（与 DW User 分开，通过 applicationId 关联）。所有标识均为占位示例。
      user: { email: 'demo.user@example.com', loginProvider: 'EMAIL', providerUserId: null, emailIsRelay: false },
      accountStatus: 'NONE', // NONE / DRAFT / SUBMITTED / APPROVED
      mode: 'LIVE',
      application: { id: 'APPID-DEMO-0001', step: 'a', data: { citizenship: 'US', taxResidency: 'US', tinType: 'SSN', accountType: 'CASH', managementType: 'SELF', country: 'US', language: 'zh_CN', usTaxPayer: 'YES', irsBackup: 'NO' }, kyc: { status: 'NOT_STARTED' }, disclosures: {}, ref: null, submittedAt: null, returnTo: null },
      // DW 侧状态（由后端同步，原型中模拟）
      dw: { userID: null, kyc: 'KYC_NOT_READY', issues: [], account: null, kycUpdatedAt: null },
      accounts: { LIVE: liveUnavailable(), PAPER: paper() },
      watchlist: [{ id: 'g1', name: '美股', symbols: [] }, { id: 'g2', name: 'ETF', symbols: [] }],
      prefs: { redUp: false, hideBalances: false, notifTrade: true, notifFunds: true, notifMarketing: false, biometric: true },
      notifications: [],
      linkedBanks: [],
      profile: { email: 'demo.user@example.com', phone: '+1 415 555 0142', line1: '', line2: '', city: '', state: '', postalCode: '', employmentStatus: '', employerName: '' },
      profileSync: { status: 'SYNCED', at: null },
      subs: { ai: false, rewards: false },
      acats: [],
      deposits: [],
    };
    if (scenario === 'review' || scenario === 'approved' || scenario === 'newAccount' || scenario === 'newAccountIntl' || scenario === 'seasoning') {
      Object.assign(s.application.data, {
        firstName: 'Alex', lastName: 'Chen', dateOfBirth: '1992-05-14', tin: '123-45-6789',
        line1: '200 Market Street', line2: 'Apt 5B', city: 'San Francisco', state: 'CA', postalCode: '94105',
        employmentStatus: 'EMPLOYED', employerName: 'Example Corp', occupation: '工程师', annualIncome: '100k-200k', netWorth: '200k-500k',
        isAffiliated: 'NO', isPEP: 'NO', isControl: 'NO', phone: '+1 415 555 0142', tinConfirm: true,
        experience: '3-5', netWorthLiquid: '50k-200k', risk: 'MED', objective: 'GROWTH',
        contactEmail: 'demo.user@example.com', fundingSources: ['EMPLOYMENT', 'SAVINGS'],
      });
      s.application.step = 'p30';
      s.application.disclosures = { termsOfUse: true, customerAgreement: true, marketDataAgreement: true, privacyPolicy: true, dataSharing: true, rule14b: 'YES', p_terms: true, p_privacy: true, p_risk: true, esign: true, signature: 'Alex Chen' };
      s.dw = { userID: 'usr_demo_7q2k91xm', kyc: 'KYC_PROCESSING', issues: [], account: null, kycUpdatedAt: '2026-11-18 20:10' };
      s.application.ref = 'APP-7Q2K-91XM';
      s.application.submittedAt = '2026-11-18T20:10:00';
      s.accountStatus = 'SUBMITTED';
      s.profile = { ...s.profile, line1: '200 Market Street', line2: 'Apt 5B', city: 'San Francisco', state: 'CA', postalCode: '94105', employmentStatus: 'EMPLOYED', employerName: 'Example Corp' };
    }
    if (scenario === 'newAccountIntl') {
      Object.assign(s.application.data, {
        firstName: 'Mei', lastName: 'Lin', dateOfBirth: '1990-08-21', citizenship: 'SG', taxResidency: 'SG', usTaxPayer: 'NO', taxTreaty: 'YES', irsBackup: 'NO',
        tinType: 'FOREIGN_TIN', tin: 'S9012345D', country: 'SG', line1: '10 Example Road', line2: '#08-01', city: 'Singapore', state: '', postalCode: '238888', phone: '+65 8123 4567',
      });
      s.application.kyc = { docType: 'PASSPORT', front: 'passport_front.jpg' };
      s.application.disclosures.signature = 'Mei Lin';
      s.profile = { ...s.profile, phone: '+65 8123 4567', line1: '10 Example Road', line2: '#08-01', city: 'Singapore', state: '', postalCode: '238888' };
    }
    // 演示 ACH 30 天观察期：唯一一笔入金 3 天前到账，可提现金额为 $0.00
    if (scenario === 'seasoning') {
      s.accountStatus = 'APPROVED';
      s.dw.kyc = 'KYC_APPROVED'; s.dw.account = 'OPEN';
      s.accounts.LIVE = liveNew();
      Object.assign(s.accounts.LIVE, {
        accountNumber: 'DEMO-LV-00071122', cash: 1500,
        transactions: [{ id: 'T-S1', type: 'DEPOSIT', method: 'ACH', amount: 1500, date: daysAgo(3), status: '已到账', dwStatus: 'SUCCESSFUL', desc: 'ACH 入金 · 示例银行 A ••6789' }],
      });
      s.linkedBanks = [{ id: 'b1', name: '示例银行 A', type: 'CHECKING', mask: '6789', status: 'VERIFIED', owner: 'Alex Chen', createdAt: daysAgo(10) }];
      s.notifications = [{ id: 'n0', category: 'FUNDS', title: '入金已到账', body: 'ACH 入金 $1,500.00 已到账。到账后 30 天观察期内不可提现（默认，待 DW 确认）。', at: daysAgo(3) + ' 09:00', read: false, link: '#/p14' }];
      s.profileSync.at = daysAgo(10) + ' 09:12';
    }
    if (scenario === 'newAccount' || scenario === 'newAccountIntl') {
      s.accountStatus = 'APPROVED';
      s.dw.kyc = 'KYC_APPROVED'; s.dw.account = 'OPEN';
      s.accounts.LIVE = liveNew();
      s.accounts.LIVE.accountNumber = scenario === 'newAccount' ? 'DEMO-LV-00051204' : 'DEMO-LV-00063390';
      s.notifications = [{ id: 'n0', category: 'ACCOUNT', title: '交易账户已开通', body: `您的实盘账户 ${s.accounts.LIVE.accountNumber} 已开通。${scenario === 'newAccount' ? '绑定银行账户后即可入金' : '可通过电汇入金'}。`, at: '2026-11-19 09:12', read: false, link: '#/p06' }];
      s.profileSync.at = '2026-11-19 09:12';
    }
    if (scenario === 'approved') {
      s.accountStatus = 'APPROVED';
      s.dw.kyc = 'KYC_APPROVED'; s.dw.account = 'OPEN';
      s.accounts.LIVE = liveApproved();
      s.watchlist[0].symbols = ['AAPL', 'MSFT', 'AMZN'];
      s.watchlist[1].symbols = ['QQQ', 'GLD'];
      s.notifications = JSON.parse(JSON.stringify(notifications));
      s.linkedBanks = [{ id: 'b1', name: '示例银行 A', type: 'CHECKING', mask: '6789', status: 'VERIFIED', owner: 'Alex Chen', createdAt: '2026-09-01' }];
      s.profileSync.at = '2026-11-18 20:12';
    }
    return s;
  }

  return { instruments, blocked, etfThemes, advDecline, insider, institutions, opportunities, faqs, initialState, liveApproved, liveNew };
})();
