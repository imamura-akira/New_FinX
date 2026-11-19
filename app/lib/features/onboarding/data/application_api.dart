import 'dart:convert';
import 'dart:typed_data';

import '../../../core/api/api_client.dart';

/// GET /application 的数据（api-spec.md 第 2 节）。
class ApplicationView {
  ApplicationView({required this.status, this.applicationId, this.step, required this.data, required this.documents, this.kycStatus});

  /// NONE / DRAFT / SUBMITTED / APPROVED / DENIED
  final String status;
  final String? applicationId;
  final String? step;
  final Map<String, dynamic> data; // ApplicationData（tin 为打码值）
  final List<StagedDocument> documents;
  final String? kycStatus;

  bool get isEditable => status == 'NONE' || status == 'DRAFT';

  factory ApplicationView.fromJson(Map<String, dynamic> j) => ApplicationView(
    status: j['status'] as String? ?? 'NONE',
    applicationId: j['applicationId'] as String?,
    step: j['step'] as String?,
    data: Map<String, dynamic>.from(j['data'] as Map? ?? const {}),
    documents: [for (final d in (j['documents'] as List? ?? const [])) StagedDocument.fromJson(d as Map<String, dynamic>)],
    kycStatus: (j['kyc'] as Map?)?['status'] as String?,
  );
}

class StagedDocument {
  const StagedDocument({required this.id, required this.docType, required this.side});
  final String id;
  final String docType;
  final String side; // FRONT / BACK

  factory StagedDocument.fromJson(Map<String, dynamic> j) =>
      StagedDocument(id: j['documentId'] as String? ?? '', docType: j['docType'] as String? ?? '', side: j['side'] as String? ?? '');
}

class SubmitResult {
  const SubmitResult({required this.applicationRef, required this.submittedAt});
  final String applicationRef;
  final DateTime submittedAt;
}

/// /application/*。字段名与 openapi.yaml 一致。
class ApplicationApi {
  ApplicationApi(this._api);
  final ApiClient _api;

  Future<ApplicationView> get() async => ApplicationView.fromJson(await _api.get('/application') as Map<String, dynamic>);

  /// 草稿保存：顶层字段浅合并；值为 null 表示删除该字段。
  Future<void> saveDraft(String step, Map<String, dynamic> data) => _api.put('/application/draft', {'step': step, 'data': data});

  Future<String> uploadDocument({required String docType, required String side, required Uint8List bytes}) async {
    final d =
        await _api.post('/application/documents', {'docType': docType, 'side': side, 'image': base64Encode(bytes)}) as Map<String, dynamic>;
    return d['documentId'] as String;
  }

  Future<SubmitResult> submit({required String signatureName, required List<Map<String, dynamic>> disclosures}) async {
    final d = await _api.post('/application/submit', {'signatureName': signatureName, 'disclosures': disclosures}) as Map<String, dynamic>;
    return SubmitResult(applicationRef: d['applicationRef'] as String, submittedAt: DateTime.parse(d['submittedAt'] as String));
  }
}
