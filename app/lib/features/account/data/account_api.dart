import '../../../core/api/api_client.dart';

double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// KYC 问题项（GET /application/status `issues[]`）。
class KycIssue {
  const KycIssue({required this.code, this.field, required this.userMessage});
  factory KycIssue.fromJson(Map<String, dynamic> j) =>
      KycIssue(code: j['code'] as String? ?? '', field: j['field'] as String?, userMessage: j['userMessage'] as String? ?? '');
  final String code;
  final String? field;
  final String userMessage;
}

/// GET /application/status（api-spec.md 第 2 节；kycStatus 只反映 DW 真实返回）。
class ApplicationProgress {
  const ApplicationProgress({
    required this.kycStatus,
    this.kycUpdatedAt,
    this.issues = const [],
    this.requiredDocs = const [],
    this.accountStatus,
    this.accountNo,
    this.applicationRef,
    this.submittedAt,
    this.submitState = 'NOT_SUBMITTED',
  });

  factory ApplicationProgress.fromJson(Map<String, dynamic> j) => ApplicationProgress(
    kycStatus: j['kycStatus'] as String? ?? 'KYC_NOT_READY',
    kycUpdatedAt: _time(j['kycUpdatedAt']),
    issues: [for (final i in (j['issues'] as List? ?? const [])) KycIssue.fromJson(i as Map<String, dynamic>)],
    requiredDocs: [for (final d in (j['requiredDocs'] as List? ?? const [])) d],
    accountStatus: j['accountStatus'] as String?,
    accountNo: j['accountNo'] as String?,
    applicationRef: j['applicationRef'] as String?,
    submittedAt: _time(j['submittedAt']),
    submitState: j['submitState'] as String? ?? 'NOT_SUBMITTED',
  );

  final String kycStatus;
  final DateTime? kycUpdatedAt;
  final List<KycIssue> issues;
  final List<Object?> requiredDocs;
  final String? accountStatus; // PENDING/OPEN/OPEN_NO_NEW_TRADES/FROZEN/CLOSED
  final String? accountNo;
  final String? applicationRef;
  final DateTime? submittedAt;
  final String submitState; // NOT_SUBMITTED/SUBMITTING/SUBMITTED/NEEDS_ATTENTION

  /// 账户已开立（含受限状态）。
  bool get accountOpened => accountStatus != null && accountStatus != 'PENDING';

  /// 是否需要继续轮询（非终态）。
  bool get shouldPoll {
    if (submitState == 'NEEDS_ATTENTION' || kycStatus == 'KYC_DENIED') return false;
    if (kycStatus == 'KYC_INFO_REQUIRED' || kycStatus == 'KYC_DOC_REQUIRED') return false;
    return !accountOpened;
  }
}

/// GET /account。
class AccountInfo {
  const AccountInfo({
    required this.accountNo,
    required this.status,
    this.accountType = 'LIVE',
    this.tradingType = 'CASH',
    this.managementType = 'SELF',
    this.openedAt,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> j) => AccountInfo(
    accountNo: j['accountNo'] as String? ?? '',
    status: j['status'] as String? ?? 'PENDING',
    accountType: j['accountType'] as String? ?? 'LIVE',
    tradingType: j['tradingType'] as String? ?? 'CASH',
    managementType: j['managementType'] as String? ?? 'SELF',
    openedAt: _time(j['openedAt']),
  );

  final String accountNo;
  final String status;
  final String accountType;
  final String tradingType;
  final String managementType;
  final DateTime? openedAt;
}

/// GET /account/money（一律展示 DW money summary 返回值，F12）。
class AccountMoney {
  const AccountMoney({
    required this.cash,
    required this.settledCash,
    required this.buyingPower,
    required this.cashAvailableForWithdrawal,
    required this.unsettled,
    required this.pendingDeposits,
    required this.withheldForSeasoning,
    this.updatedAt,
  });

  factory AccountMoney.fromJson(Map<String, dynamic> j) => AccountMoney(
    cash: _num(j['cash']),
    settledCash: _num(j['settledCash']),
    buyingPower: _num(j['buyingPower']),
    cashAvailableForWithdrawal: _num(j['cashAvailableForWithdrawal']),
    unsettled: _num(j['unsettled']),
    pendingDeposits: _num(j['pendingDeposits']),
    withheldForSeasoning: _num(j['withheldForSeasoning']),
    updatedAt: _time(j['updatedAt']),
  );

  final double cash;
  final double settledCash;
  final double buyingPower;
  final double cashAvailableForWithdrawal;
  final double unsettled;
  final double pendingDeposits;
  final double withheldForSeasoning;
  final DateTime? updatedAt;
}

class AccountApi {
  AccountApi(this._api);
  final ApiClient _api;

  Future<ApplicationProgress> progress() async =>
      ApplicationProgress.fromJson(await _api.get('/application/status') as Map<String, dynamic>);

  Future<AccountInfo> account() async => AccountInfo.fromJson(await _api.get('/account') as Map<String, dynamic>);

  Future<AccountMoney> money() async => AccountMoney.fromJson(await _api.get('/account/money') as Map<String, dynamic>);
}
