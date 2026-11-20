// 测试共用假数据（F18 页面巡检、F21 深浅色巡检）。
import 'helpers.dart';

// ---------------------------------------------------------------------------
// 夹具：已开户用户 + 交易 / 资金 / 行情数据

Map<String, dynamic> _order(String id, String status, {String type = 'MARKET'}) => {
  'orderId': id,
  'orderNo': 'FEAB0000$id',
  'symbol': 'AAPL',
  'side': 'BUY',
  'orderType': type,
  'quantity': type == 'LIMIT' ? 2 : null,
  'amount': type == 'LIMIT' ? null : 100,
  'limitPrice': type == 'LIMIT' ? 200 : null,
  'timeInForce': type == 'LIMIT' ? 'DAY' : null,
  'status': status,
  'filledQty': status == 'FILLED' ? 0.44 : null,
  'avgPrice': status == 'FILLED' ? 226.13 : null,
  'totalAmount': status == 'FILLED' ? 99.5 : null,
  'fees': 0,
  'rejectReason': status == 'REJECTED' ? '购买力不足，券商已拒绝该订单' : null,
  'submittedAt': '2026-11-23T15:00:00Z',
  'updatedAt': '2026-11-23T15:00:01Z',
  'doneAt': status == 'FILLED' ? '2026-11-23T15:00:01Z' : null,
};

/// 已开户用户（opened = false 为未开户）的完整假后端：资产、持仓、订单、银行卡、资金记录、个股。
FakeBackend openedUserBackend({bool opened = true}) => FakeBackend()
  ..on(
    'GET /application',
    (_) => FakeBackend.ok({
      'applicationId': opened ? 'app-1' : null,
      'status': opened ? 'APPROVED' : 'NONE',
      'step': null,
      'data': <String, dynamic>{},
      'disclosures': [],
      'kyc': null,
      'documents': [],
    }),
  )
  ..on('PUT /application/draft', (_) => FakeBackend.ok({'savedAt': '2026-11-19T12:00:00Z'}))
  ..on(
    'GET /me',
    (_) => FakeBackend.ok({
      'email': 'demo@example.com',
      'loginProvider': 'EMAIL',
      'applicationId': opened ? 'app-1' : null,
      'accountStatus': opened ? 'APPROVED' : 'NONE',
    }),
  )
  ..on(
    'GET /application/status',
    (_) => FakeBackend.ok({
      'kycStatus': 'KYC_APPROVED',
      'issues': [],
      'requiredDocs': [],
      'accountStatus': 'OPEN',
      'accountNo': 'TEST000001',
      'applicationRef': 'FX-1',
      'submittedAt': '2026-10-01T12:00:00Z',
      'submitState': 'SUBMITTED',
    }),
  )
  ..on(
    'GET /account',
    (_) => FakeBackend.ok({
      'accountId': 'a',
      'accountNo': 'TEST000001',
      'status': 'OPEN',
      'accountType': 'LIVE',
      'tradingType': 'CASH',
      'managementType': 'SELF',
    }),
  )
  ..on(
    'GET /account/money',
    (_) => FakeBackend.ok({
      'cash': 1635.80,
      'settledCash': 1635.80,
      'buyingPower': 1635.80,
      'cashAvailableForWithdrawal': 1000,
      'unsettled': 10,
      'pendingDeposits': 5,
      'withheldForSeasoning': 635.8,
      'updatedAt': '2026-11-20T15:00:00Z',
    }),
  )
  ..on(
    'GET /account/allocation',
    (_) => FakeBackend.ok({
      'simulated': false,
      'total': 6543.21,
      'items': [
        {'type': 'STOCK', 'amount': 2944.45, 'pct': 45.0},
        {'type': 'ETF', 'amount': 1962.96, 'pct': 30.0},
        {'type': 'CASH', 'amount': 1635.80, 'pct': 25.0},
      ],
      'updatedAt': '2026-11-20T15:00:00Z',
    }),
  )
  ..on(
    'GET /account/history',
    (_) => FakeBackend.ok({
      'simulated': false,
      'range': '7D',
      'points': [
        {'date': '2026-11-19', 'total': 6500, 'cash': 6500, 'stock': 0, 'etf': 0},
        {'date': '2026-11-20', 'total': 6543.21, 'cash': 6543.21, 'stock': 0, 'etf': 0},
      ],
    }),
  )
  ..on(
    'GET /positions',
    (_) => FakeBackend.ok({
      'updatedAt': '2026-11-23T15:00:00Z',
      'equityValue': 1260,
      'positions': [
        {
          'symbol': 'AAPL',
          'quantity': 10.5,
          'sellableQty': 8.25,
          'avgPrice': 100,
          'costBasis': 1050,
          'marketPrice': 120,
          'marketValue': 1260,
          'unrealizedPL': 210,
          'unrealizedDayPL': -5.5,
        },
      ],
    }),
  )
  ..on('GET /orders', (_) => FakeBackend.ok([_order('1', 'NEW', type: 'LIMIT'), _order('2', 'FILLED'), _order('3', 'REJECTED')]))
  ..on(
    'GET /funding/bank-accounts',
    (_) => FakeBackend.ok([
      {
        'id': 'bank-1',
        'bankName': '',
        'nickname': 'Payroll',
        'mask': '6789',
        'type': 'CHECKING',
        'ownerName': 'Demo Tester',
        'status': 'APPROVED',
        'createdAt': '2026-11-19T12:00:00Z',
      },
    ]),
  )
  ..on(
    'GET /funding/transfers',
    (_) => FakeBackend.ok([
      {
        'transferId': 'tr-1',
        'type': 'DEPOSIT',
        'method': 'ACH',
        'amount': 1000,
        'status': 'FAILED',
        'failureReason': '银行退回：余额不足',
        'submittedAt': '2026-11-19T12:00:00Z',
        'doneAt': '2026-11-19T12:00:05Z',
        'bankAccountId': 'bank-1',
        'buyingPowerAvailableAt': null,
        'withdrawableAt': null,
      },
    ]),
  )
  ..on(
    'GET /market/instruments/AAPL',
    (_) => FakeBackend.ok({
      'simulated': true,
      'symbol': 'AAPL',
      'name': 'Apple Inc.',
      'exchange': 'NASDAQ',
      'type': 'STOCK',
      'last': 226.1,
      'chg': 1.0,
      'chgPct': 0.4,
      'dayHigh': 227.0,
      'dayLow': 225.0,
      'prevClose': 225.1,
      'candles': [
        for (var i = 0; i < 5; i++) {'t': '2026-11-23T14:0$i:00Z', 'o': 226.0, 'h': 226.5, 'l': 225.5, 'c': 226.0 + i * 0.1},
      ],
    }),
  );

/// 关键页面（已开户用户）：路由 → 该页面必定出现的中文 / 英文文案。
const keyPages = <(String, String, String)>[
  ('/home', '购买力', 'Buying Power'),
  ('/market', '市场情绪', 'Market Sentiment'),
  ('/market/AAPL', '关键数据', 'Key Stats'),
  ('/trade/AAPL', '订单类型', 'Order Type'),
  ('/orders', '订单', 'Orders'),
  ('/positions', '持仓', 'Positions'),
  ('/funding/deposit', '选择入金方式', 'Choose a deposit method'),
  ('/funding/withdraw', '可提现金额', 'Available to Withdraw'),
  ('/funding/banks', '银行账户', 'Bank Accounts'),
  ('/funding/banks/link', '绑定银行账户', 'Link Bank Account'),
  ('/funding/history', '资金记录', 'Transfer History'),
  ('/masters', '股票大师', 'Masters'),
  ('/masters/all', '全部机构', 'All Institutions'),
  ('/fifi', 'AI 助手', 'AI Assistant'),
  ('/rewards', 'Fifi 奖励', 'Fifi Rewards'),
];
