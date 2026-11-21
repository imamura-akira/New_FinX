import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../l10n/l10n.dart';

/// 我方后端业务错误码（api-spec.md 第 8 节）。
abstract final class ApiCodes {
  static const unauthorized = 40101;
  static const sessionExpired = 40102;
  static const restricted = 40301;
  static const conflict = 40901;
  static const validation = 42200;
  static const limit = 42201;
  static const rateLimited = 42901;
  static const internal = 50000;
  static const dwFailed = 50001;
  static const dwBadData = 50002;
  static const notEnabled = 50003;

  /// 客户端自定义：网络不可达 / 超时 / 响应无法解析（不会出现在服务端）。
  static const network = -1;
}

/// 字段级错误（422xx 的 data.fields[]）。
class FieldError {
  const FieldError(this.field, this.reason);
  final String field;
  final String reason;
}

/// 后端返回的业务错误或网络错误。[message] 为按当前语言本地化后的展示文案（F18：按错误码映射，
/// 服务器原文 [serverMessage] 只在无映射时兜底）。
class ApiException implements Exception {
  ApiException({required this.code, required String message, this.httpStatus, this.data, this.fields = const []})
    : serverMessage = message;

  final int code;
  final String serverMessage;
  String get message => localizeError(code, serverMessage);
  final int? httpStatus;
  final Object? data;
  final List<FieldError> fields;

  bool get isSessionInvalid => code == ApiCodes.unauthorized || code == ApiCodes.sessionExpired;

  /// 字段名 → 错误文案（同一字段取第一条）。
  Map<String, String> get fieldMap => {for (final f in fields.reversed) f.field: localizeFieldReason(f.reason)};

  @override
  String toString() => 'ApiException($code, $serverMessage)';
}

/// 统一的后端客户端：信封解包、错误映射、Bearer token、会话失效回调。
class ApiClient {
  ApiClient({required String baseUrl, http.Client? httpClient, this.timeout = const Duration(seconds: 15)})
    : _base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
      _http = httpClient ?? http.Client();

  final String _base;
  final http.Client _http;
  final Duration timeout;

  /// 当前会话 token（由 SessionController 提供）。
  String? Function() tokenProvider = () => null;

  /// 收到 401xx 时调用（SessionController 据此清除会话并跳转 S-01）。
  void Function()? onSessionInvalid;

  Future<dynamic> get(String path, {Map<String, String>? query}) => _send('GET', path, query: query);
  /// [headers]：附加请求头（如资金类申请的 Idempotency-Key）；[timeout]：覆盖默认超时（资金类提交需长于后端提交券商的最长耗时）。
  Future<dynamic> post(String path, [Object? body, Map<String, String>? headers, Duration? timeout]) =>
      _send('POST', path, body: body, headers: headers, timeout: timeout);
  Future<dynamic> put(String path, Object? body) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, Object? body) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query, Map<String, String>? headers, Duration? timeout}) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: (query == null || query.isEmpty) ? null : query);
    final req = http.Request(method, uri)..headers['Accept'] = 'application/json';
    final token = tokenProvider();
    if (token != null && token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
    if (headers != null) req.headers.addAll(headers);
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout ?? this.timeout));
    } on TimeoutException {
      throw ApiException(code: ApiCodes.network, message: t.errTimeout);
    } on SocketException {
      throw ApiException(code: ApiCodes.network, message: t.errNetwork);
    } on http.ClientException {
      throw ApiException(code: ApiCodes.network, message: t.errNetwork);
    }

    Map<String, dynamic> env;
    try {
      env = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(code: ApiCodes.network, httpStatus: res.statusCode, message: t.errBadResponse);
    }
    final code = (env['code'] as num?)?.toInt() ?? ApiCodes.internal;
    if (code == 0) return env['data'];

    final data = env['data'];
    final fields = <FieldError>[];
    if (data is Map && data['fields'] is List) {
      for (final f in data['fields'] as List) {
        if (f is Map) fields.add(FieldError('${f['field']}', '${f['reason']}'));
      }
    }
    final err = ApiException(
      code: code,
      httpStatus: res.statusCode,
      message: (env['message'] as String?) ?? t.errRequestFailed,
      data: data,
      fields: fields,
    );
    if (err.isSessionInvalid) onSessionInvalid?.call();
    throw err;
  }
}

/// 资金类申请（入金、出金、下单）的提交超时：须长于后端向券商提交的最长耗时（最多 4 次尝试 × 10 秒 + 退避），
/// 避免 App 先超时、用户重试（审计 FUND-P0-1）。
const submitTimeout = Duration(seconds: 60);

/// 新的幂等键（UUID v4）。
String newIdempotencyKey() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int from, int to) => b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h(0, 4)}-${h(4, 6)}-${h(6, 8)}-${h(8, 10)}-${h(10, 16)}';
}

/// 一笔资金类申请的幂等键：内容（[fingerprint]）不变的重试沿用同一个键，后端据此去重、不会重复提交；
/// 内容变化或得到明确结果后换新键（审计 FUND-P0-1）。
class SubmitKey {
  String? _key;
  String? _fingerprint;

  String forRequest(String fingerprint) {
    if (_key == null || _fingerprint != fingerprint) {
      _key = newIdempotencyKey();
      _fingerprint = fingerprint;
    }
    return _key!;
  }

  /// 已得到明确结果（成功、校验失败、券商明确拒绝）：下一次提交视为新申请。
  void reset() => _key = _fingerprint = null;

  /// 网络超时 / 断网时保留键（结果不明，重试必须是同一笔）；其余错误换新键。
  void settle(Object error) {
    if (error is ApiException && error.code == ApiCodes.network) return;
    reset();
  }
}
