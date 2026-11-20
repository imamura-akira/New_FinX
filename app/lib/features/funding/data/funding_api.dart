import '../../../core/api/api_client.dart';
import '../../../l10n/l10n.dart';

double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
DateTime? _t(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// 已绑定银行账户（GET /funding/bank-accounts）。账号只返回尾号。
class BankAccount {
  const BankAccount({
    required this.id,
    required this.bankName,
    required this.mask,
    required this.type,
    required this.ownerName,
    required this.status,
    this.nickname = '',
    this.createdAt,
  });

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
    id: j['id'] as String,
    bankName: j['bankName'] as String? ?? '',
    mask: j['mask'] as String? ?? '',
    type: j['type'] as String? ?? '',
    ownerName: j['ownerName'] as String? ?? '',
    status: j['status'] as String? ?? '',
    nickname: j['nickname'] as String? ?? '',
    createdAt: _t(j['createdAt']),
  );

  final String id;
  final String bankName;
  final String mask;
  final String type; // CHECKING / SAVINGS
  final String ownerName;
  final String status;
  final String nickname;
  final DateTime? createdAt;

  /// 显示名：DW 不返回银行名称时用备注名（沙盒实测）。
  String get displayName {
    final n = bankName.isNotEmpty ? bankName : (nickname.isNotEmpty ? nickname : t.fundBankAccount);
    return '$n ••$mask';
  }

  String get typeLabel => type == 'SAVINGS' ? t.fundSavings : t.fundChecking;
}

/// 资金流水（GET /funding/transfers）。
class Transfer {
  const Transfer({
    required this.id,
    required this.type,
    required this.method,
    required this.amount,
    required this.status,
    this.failureReason,
    this.submittedAt,
    this.doneAt,
    this.bankAccountId,
    this.buyingPowerAvailableAt,
    this.withdrawableAt,
  });

  factory Transfer.fromJson(Map<String, dynamic> j) => Transfer(
    id: j['transferId'] as String,
    type: j['type'] as String? ?? '',
    method: j['method'] as String? ?? '',
    amount: _d(j['amount']),
    status: j['status'] as String? ?? '',
    failureReason: j['failureReason'] as String?,
    submittedAt: _t(j['submittedAt']),
    doneAt: _t(j['doneAt']),
    bankAccountId: j['bankAccountId'] as String?,
    buyingPowerAvailableAt: _t(j['buyingPowerAvailableAt']),
    withdrawableAt: _t(j['withdrawableAt']),
  );

  final String id;
  final String type; // DEPOSIT / WITHDRAWAL
  final String method; // ACH / WIRE
  final double amount;
  final String status;
  final String? failureReason;
  final DateTime? submittedAt;
  final DateTime? doneAt;
  final String? bankAccountId;

  /// DW 返回的购买力可用日 / 可提现日（ui-signoff 第 3 节：优先显示 DW 日期）。
  final DateTime? buyingPowerAvailableAt;
  final DateTime? withdrawableAt;

  bool get isDeposit => type == 'DEPOSIT';
}

/// 电汇入金指引（GET /funding/deposit-instructions）。
class DepositInstructions {
  const DepositInstructions(this.fields);
  final Map<String, String> fields;
}

/// 出入金提交结果。[pending] 为 true 表示券商受理结果暂未确认（50001 附 transferId），后台会自动对账。
class TransferResult {
  const TransferResult({required this.transferId, required this.status, this.pending = false});
  final String transferId;
  final String status;
  final bool pending;
}

class FundingApi {
  FundingApi(this._api);
  final ApiClient _api;

  Future<List<BankAccount>> banks() async => [
    for (final b in (await _api.get('/funding/bank-accounts') as List? ?? const []))
      BankAccount.fromJson((b as Map).cast<String, dynamic>()),
  ];

  /// 方案 A 直接录入（BANK_LINK_METHOD=DIRECT）。户名由后端写入开户姓名，客户端不传。
  Future<String> linkBank({
    required String accountNumber,
    required String routingNumber,
    required String type,
    String nickname = '',
  }) async {
    final d = await _api.post('/funding/bank-accounts', {
      'accountNumber': accountNumber,
      'routingNumber': routingNumber,
      'type': type,
      if (nickname.isNotEmpty) 'nickname': nickname,
    }) as Map<String, dynamic>;
    return d['id'] as String;
  }

  Future<void> unlinkBank(String id) => _api.delete('/funding/bank-accounts/${Uri.encodeComponent(id)}');

  Future<TransferResult> deposit({required String bankAccountId, required double amount}) =>
      _submit('/funding/deposits', {'bankAccountId': bankAccountId, 'amount': _money(amount)});

  Future<TransferResult> withdrawAch({required String bankAccountId, required double amount}) =>
      _submit('/funding/withdrawals', {'method': 'ACH', 'bankAccountId': bankAccountId, 'amount': _money(amount)});

  Future<List<Transfer>> transfers({String? type}) async => [
    for (final t in (await _api.get('/funding/transfers', query: type == null ? null : {'type': type}) as List? ?? const []))
      Transfer.fromJson((t as Map).cast<String, dynamic>()),
  ];

  Future<DepositInstructions> instructions() async {
    final d = await _api.get('/funding/deposit-instructions') as Map<String, dynamic>;
    return DepositInstructions({for (final e in d.entries) e.key: '${e.value ?? ''}'});
  }

  Future<TransferResult> _submit(String path, Map<String, dynamic> body) async {
    try {
      final d = await _api.post(path, body) as Map<String, dynamic>;
      return TransferResult(transferId: d['transferId'] as String, status: d['status'] as String? ?? 'PENDING');
    } on ApiException catch (e) {
      // 50001：已记录、券商受理结果待确认（api-spec 第 10 节），后台对账后在资金记录中更新
      final data = e.data;
      if (e.code == ApiCodes.dwFailed && data is Map && data['transferId'] is String) {
        return TransferResult(transferId: data['transferId'] as String, status: 'SUBMITTING', pending: true);
      }
      rethrow;
    }
  }

  /// 金额按两位小数发送（契约 Money 为 JSON number）。
  static num _money(double v) => double.parse(v.toStringAsFixed(2));
}
