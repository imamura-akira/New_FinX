import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../data/application_api.dart';
import 'options.dart';
import 'validators.dart';

/// 开户流程状态（P-03a–g、P-04、P-05、P-30）。
///
/// - 草稿以接口字段名保存在 [data]，每步 Continue / Save & exit 时调用 PUT /application/draft；
/// - P-05 的披露勾选只在本次流程内保存，提交时随 POST /application/submit 发送（契约无草稿字段）；
/// - 服务端 42200 的字段错误合并进 [errors]，字段名与本地校验一致。
class OnboardingController extends ChangeNotifier {
  OnboardingController({required this.api, required this.loginEmail, required this.loginProvider, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ApplicationApi api;
  final String loginEmail;
  final String loginProvider;
  final DateTime Function() _now;

  bool loading = true;
  String? loadError;
  String status = 'NONE';
  Map<String, dynamic> data = {};
  List<StagedDocument> documents = [];
  Map<String, String> errors = {};
  bool saving = false;
  bool submitting = false;

  /// P-30 "Edit" 进入某步后，Continue 直接回到 P-30。
  bool returnToReview = false;

  // P-05 本地状态
  final Map<String, bool> agreed = {};
  final Map<String, DateTime> agreedAt = {};
  String? rule14b; // YES / NO
  bool extendedHours = false;
  bool eSign = false;
  String signature = '';

  // P-04 本地状态
  String docType = 'PASSPORT';

  bool get isUsTaxPayer => data['usTaxPayer'] == 'YES';
  bool get editable => status == 'NONE' || status == 'DRAFT';

  /// 步骤顺序（美国纳税人无 P-04）。
  List<(String, String)> get steps => [
    ('a', 'Prepare'),
    ('b', 'Identity'),
    ('c', 'Tax'),
    ('d', 'Address'),
    ('e', 'Finances'),
    ('f', 'Compliance'),
    ('g', 'Account type'),
    if (!isUsTaxPayer) ('p04', 'ID upload'),
    ('p05', 'Disclosures'),
    ('p30', 'Review'),
  ];

  int indexOf(String step) => steps.indexWhere((s) => s.$1 == step).clamp(0, steps.length - 1);

  String? nextOf(String step) {
    final i = indexOf(step);
    return i + 1 < steps.length ? steps[i + 1].$1 : null;
  }

  String get fullName => '${(data['firstName'] as String? ?? '').trim()} ${(data['lastName'] as String? ?? '').trim()}'.trim();

  String get contactEmail {
    final ce = (data['contactEmail'] as String? ?? '').trim();
    return ce.isEmpty ? loginEmail : ce;
  }

  Future<void> load() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final v = await api.get();
      status = v.status;
      data = v.data;
      documents = v.documents;
      if (documents.isNotEmpty) docType = documents.first.docType;
    } on ApiException catch (e) {
      loadError = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 更新字段（含联动规则，同原型 onInput）。
  void set(String field, Object? value) {
    if (value == null) {
      data.remove(field);
    } else {
      data[field] = value;
    }
    // 国籍 / 税务居民变化时预填"是否美国纳税人"（用户仍可修改）
    if (field == 'citizenship' || field == 'taxResidency') {
      data['usTaxPayer'] = (data['citizenship'] == 'US' || data['taxResidency'] == 'US') ? 'YES' : 'NO';
      _resetTin();
    }
    if (field == 'usTaxPayer') _resetTin();
    if (field == 'employmentStatus' && !isEmployed(value as String?)) {
      for (final k in ['employerName', 'industry', 'position']) {
        data.remove(k);
      }
    }
    errors.remove(field);
    notifyListeners();
  }

  void _resetTin() {
    final opts = tinTypesFor(data['usTaxPayer'] as String?);
    if (!opts.any((o) => o.$1 == data['tinType'])) {
      data['tinType'] = opts.first.$1;
      data.remove('tin');
    }
  }

  /// 嵌套地址字段。
  void setAddress(String which, String field, String value) {
    final a = Map<String, dynamic>.from((data[which] as Map?) ?? const {});
    a[field] = value;
    data[which] = a;
    errors.remove('$which.$field');
    notifyListeners();
  }

  void toggleFundingSource(String v) {
    final list = List<String>.from((data['fundingSources'] as List?) ?? const []);
    list.contains(v) ? list.remove(v) : list.add(v);
    data['fundingSources'] = list;
    errors.remove('fundingSources');
    notifyListeners();
  }

  /// 校验当前步；通过则保存草稿。返回是否成功（失败时 [errors] 已更新）。
  Future<bool> saveStep(String step, {bool validate = true}) async {
    if (validate) {
      errors = validateStep(step, data, loginEmail: loginEmail, now: _now());
      if (errors.isNotEmpty) {
        notifyListeners();
        return false;
      }
    }
    saving = true;
    notifyListeners();
    try {
      await api.saveDraft(step, _payload());
      if (status == 'NONE') status = 'DRAFT';
      return true;
    } on ApiException catch (e) {
      errors = e.fieldMap.isNotEmpty ? e.fieldMap : {'_': e.message};
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  /// 发送给后端的草稿：固定账户类型由后端写入，这里不发送；未填写邮寄地址时删除该字段。
  Map<String, dynamic> _payload() {
    final p = Map<String, dynamic>.from(data)
      ..removeWhere((k, _) => const {'accountType', 'tradingType', 'accountManagementType'}.contains(k));
    if (!p.containsKey('mailingAddress')) p['mailingAddress'] = null;
    return p;
  }

  // ---------- P-04 ----------

  bool get needsBack => docType != 'PASSPORT';
  bool hasDoc(String side) => documents.any((d) => d.side == side && d.docType == docType);
  bool get docsReady => hasDoc('FRONT') && (!needsBack || hasDoc('BACK'));

  void setDocType(String t) {
    docType = t;
    notifyListeners();
  }

  Future<String?> uploadDoc(String side, Uint8List bytes) async {
    try {
      final id = await api.uploadDocument(docType: docType, side: side, bytes: bytes);
      documents = [...documents.where((d) => d.side != side), StagedDocument(id: id, docType: docType, side: side)];
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.fieldMap['image'] ?? e.fieldMap.values.firstOrNull ?? e.message;
    }
  }

  // ---------- P-05 ----------

  void setAgreed(String id, bool v) {
    agreed[id] = v;
    if (v) agreedAt[id] = _now().toUtc();
    notifyListeners();
  }

  void setRule14b(String v) {
    rule14b = v;
    agreedAt['rule14b'] = _now().toUtc();
    notifyListeners();
  }

  void setExtendedHours(bool v) {
    extendedHours = v;
    if (v) agreedAt['extendedHoursAgreement'] = _now().toUtc();
    notifyListeners();
  }

  void setESign(bool v) {
    eSign = v;
    if (v) agreedAt['esign'] = _now().toUtc();
    notifyListeners();
  }

  void setSignature(String v) {
    signature = v;
    notifyListeners();
  }

  bool get signatureMatches => fullName.isNotEmpty && signature.trim().toLowerCase() == fullName.toLowerCase();

  bool get disclosuresReady =>
      [...dwDisclosures, ...partnerDisclosures].every((o) => agreed[o.$1] == true) && rule14b != null && eSign && signatureMatches;

  int get agreedCount => [...dwDisclosures, ...partnerDisclosures].where((o) => agreed[o.$1] == true).length;

  List<Map<String, dynamic>> _disclosurePayload() {
    String? at(String id) => agreedAt[id]?.toIso8601String();
    return [
      for (final (id, _) in dwDisclosures) {'id': id, 'source': 'DW', 'accepted': agreed[id] == true, 'acceptedAt': at(id)},
      {'id': 'rule14b', 'source': 'DW', 'accepted': rule14b == 'YES', 'acceptedAt': at('rule14b')},
      if (extendedHours) {'id': 'extendedHoursAgreement', 'source': 'DW', 'accepted': true, 'acceptedAt': at('extendedHoursAgreement')},
      for (final (id, _) in partnerDisclosures) {'id': id, 'source': 'PARTNER', 'accepted': agreed[id] == true, 'acceptedAt': at(id)},
      {'id': 'esign', 'source': 'PARTNER', 'accepted': eSign, 'acceptedAt': at('esign')},
    ].map((m) => m..removeWhere((_, v) => v == null)).toList();
  }

  // ---------- P-30 ----------

  /// 各分组是否不完整（P-30 标红）。
  Set<String> get incompleteSections {
    final bad = <String>{};
    for (final s in ['b', 'c', 'd', 'e', 'f']) {
      if (validateStep(s, data, loginEmail: loginEmail, now: _now()).isNotEmpty) bad.add(s);
    }
    if (!isUsTaxPayer && !docsReady) bad.add('p04');
    if (!disclosuresReady) bad.add('p05');
    for (final f in errors.keys) {
      bad.add(stepOfField(f));
    }
    return bad;
  }

  /// 提交开户申请。成功返回参考号；失败时 [errors] 含服务端字段错误、返回 null 并给出可展示信息。
  Future<(SubmitResult?, String?)> submit() async {
    submitting = true;
    errors = {};
    notifyListeners();
    try {
      // 先保存最新草稿，确保后端校验的是当前资料
      await api.saveDraft('p30', _payload());
      final r = await api.submit(signatureName: signature.trim(), disclosures: _disclosurePayload());
      status = 'SUBMITTED';
      return (r, null);
    } on ApiException catch (e) {
      errors = e.fieldMap;
      if (e.code == ApiCodes.conflict) status = 'SUBMITTED';
      return (null, e.message);
    } finally {
      submitting = false;
      notifyListeners();
    }
  }
}
