import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);
  Future<dynamic> put(String path, Object? body) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, Object? body) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: (query == null || query.isEmpty) ? null : query);
    final req = http.Request(method, uri)..headers['Accept'] = 'application/json';
    final token = tokenProvider();
    if (token != null && token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }

    http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout));
    } on TimeoutException {
      throw ApiException(code: ApiCodes.network, message: '网络超时，请稍后重试');
    } on SocketException {
      throw ApiException(code: ApiCodes.network, message: '网络连接失败，请检查网络后重试');
    } on http.ClientException {
      throw ApiException(code: ApiCodes.network, message: '网络连接失败，请检查网络后重试');
    }

    Map<String, dynamic> env;
    try {
      env = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(code: ApiCodes.network, httpStatus: res.statusCode, message: '服务暂时不可用，请稍后重试');
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
      message: (env['message'] as String?) ?? '请求失败，请稍后重试',
      data: data,
      fields: fields,
    );
    if (err.isSessionInvalid) onSessionInvalid?.call();
    throw err;
  }
}
