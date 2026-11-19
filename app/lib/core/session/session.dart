import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/auth_api.dart';
import '../api/api_client.dart';

/// 会话 token 的持久化（生产：iOS Keychain；测试：内存）。
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
    : _s = storage ?? const FlutterSecureStorage(iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device));

  final FlutterSecureStorage _s;
  static const _key = 'session_token';

  @override
  Future<String?> read() => _s.read(key: _key);
  @override
  Future<void> write(String token) => _s.write(key: _key, value: token);
  @override
  Future<void> clear() => _s.delete(key: _key);
}

class MemoryTokenStore implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
  @override
  Future<void> clear() async => value = null;
}

enum SessionStatus { unknown, signedOut, signedIn, expired }

/// 全局会话状态：路由据此重定向（未登录 → P-01，会话过期 → S-01）。
class SessionController extends ChangeNotifier {
  SessionController({required this.api, required this.store}) : _auth = AuthApi(api) {
    api.tokenProvider = () => _token;
    api.onSessionInvalid = _onInvalid;
  }

  final ApiClient api;
  final TokenStore store;
  final AuthApi _auth;

  String? _token;
  Me? _me;
  SessionStatus _status = SessionStatus.unknown;

  SessionStatus get status => _status;
  Me? get me => _me;
  bool get isSignedIn => _status == SessionStatus.signedIn;

  /// 启动时恢复会话：有 token 则取 /me 校验。
  Future<void> restore() async {
    _token = await store.read();
    if (_token == null) {
      _set(SessionStatus.signedOut);
      return;
    }
    try {
      _me = await _auth.me();
      _set(SessionStatus.signedIn);
    } on ApiException catch (e) {
      if (e.isSessionInvalid) return; // _onInvalid 已处理
      _set(SessionStatus.signedIn); // 网络错误：保留会话，页面内重试
    }
  }

  Future<void> signIn(String token) async {
    _token = token;
    await store.write(token);
    try {
      _me = await _auth.me();
    } on ApiException {
      _me = null;
    }
    _set(SessionStatus.signedIn);
  }

  Future<Me?> refreshMe() async {
    _me = await _auth.me();
    notifyListeners();
    return _me;
  }

  Future<void> signOut() async {
    try {
      await _auth.logout();
    } on ApiException {
      // 注销失败不影响本地退出
    }
    await _clear(SessionStatus.signedOut);
  }

  /// 从 S-01 返回登录。
  Future<void> acknowledgeExpired() => _clear(SessionStatus.signedOut);

  void _onInvalid() {
    if (_status == SessionStatus.signedIn || _status == SessionStatus.unknown) {
      _clear(SessionStatus.expired);
    }
  }

  Future<void> _clear(SessionStatus next) async {
    _token = null;
    _me = null;
    await store.clear();
    _set(next);
  }

  void _set(SessionStatus s) {
    _status = s;
    notifyListeners();
  }
}
