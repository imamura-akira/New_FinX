import '../../../core/api/api_client.dart';

/// GET /me（api-spec.md 第 1 节）。
class Me {
  const Me({required this.email, required this.loginProvider, this.applicationId, required this.accountStatus});

  final String email;
  final String loginProvider; // EMAIL / GOOGLE / APPLE
  final String? applicationId;

  /// 开户申请状态：NONE / DRAFT / SUBMITTED / APPROVED / DENIED。
  final String accountStatus;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
    email: j['email'] as String? ?? '',
    loginProvider: j['loginProvider'] as String? ?? 'EMAIL',
    applicationId: j['applicationId'] as String?,
    accountStatus: j['accountStatus'] as String? ?? 'NONE',
  );
}

class OtpSent {
  const OtpSent({required this.ttl, required this.resendAfter});
  final int ttl;
  final int resendAfter;
}

class SignInResult {
  const SignInResult({required this.sessionToken, required this.isNewUser});
  final String sessionToken;
  final bool isNewUser;
}

/// /auth/* 与 /me。字段名与 openapi.yaml 一致。
class AuthApi {
  AuthApi(this._api);
  final ApiClient _api;

  Future<OtpSent> requestOtp(String email) async {
    final d = await _api.post('/auth/otp/request', {'email': email}) as Map<String, dynamic>;
    return OtpSent(ttl: (d['ttl'] as num).toInt(), resendAfter: (d['resendAfter'] as num).toInt());
  }

  Future<SignInResult> verifyOtp(String email, String code) async {
    final d = await _api.post('/auth/otp/verify', {'email': email, 'code': code}) as Map<String, dynamic>;
    return SignInResult(sessionToken: d['sessionToken'] as String, isNewUser: d['isNewUser'] as bool? ?? false);
  }

  Future<void> logout() => _api.post('/auth/logout');

  Future<Me> me() async => Me.fromJson(await _api.get('/me') as Map<String, dynamic>);
}
