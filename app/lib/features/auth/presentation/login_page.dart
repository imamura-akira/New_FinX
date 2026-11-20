import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_api.dart';
import '../../../l10n/l10n.dart';

enum LoginMode { login, register }

final _emailRE = RegExp(r'^\S+@\S+\.\S+$');

/// P-02 登录 / 注册（邮箱 + 验证码）。登录成功由路由重定向到首页。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialMode = LoginMode.login});
  final LoginMode initialMode;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late LoginMode _mode = widget.initialMode;
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _terms = false;
  bool _sending = false;
  bool _submitting = false;
  bool _sent = false;
  int _countdown = 0;
  Timer? _timer;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  AuthApi get _auth => AuthApi(AppScope.of(context).api);

  String? _validateEmail() => _emailRE.hasMatch(_email.text.trim()) ? null : t.loginPleaseEnterAValid;

  Future<void> _sendCode() async {
    final e = _validateEmail();
    if (e != null) {
      setState(() => _errors = {'email': e});
      return;
    }
    setState(() {
      _sending = true;
      _errors = {};
    });
    try {
      final sent = await _auth.requestOtp(_email.text.trim());
      if (!mounted) return;
      _startCountdown(sent.resendAfter);
      setState(() => _sent = true);
      showToast(context, t.loginVerificationCodeSent);
    } on ApiException catch (err) {
      if (!mounted) return;
      if (err.code == ApiCodes.rateLimited && err.data is Map) {
        final retry = ((err.data as Map)['retryAfter'] as num?)?.toInt() ?? 60;
        _startCountdown(retry);
      }
      setState(() => _errors = err.fields.isNotEmpty ? err.fieldMap : {'email': err.message});
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _countdown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
  }

  Future<void> _submit() async {
    final errs = <String, String>{};
    final emailErr = _validateEmail();
    if (emailErr != null) errs['email'] = emailErr;
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) errs['code'] = t.loginPleaseEnterThe6;
    if (_mode == LoginMode.register && !_terms) errs['terms'] = t.loginPleaseAgreeToThe;
    setState(() => _errors = errs);
    if (errs.isNotEmpty) return;

    setState(() => _submitting = true);
    final scope = AppScope.of(context);
    try {
      final r = await _auth.verifyOtp(_email.text.trim(), _code.text.trim());
      await scope.session.signIn(r.sessionToken); // 路由监听会话状态，自动进入首页
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _errors = err.fields.isNotEmpty ? err.fieldMap : {'code': err.message});
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _social(String provider) {
    if (_mode == LoginMode.register && !_terms) {
      setState(() => _errors = {'terms': t.loginPleaseAgreeToThe});
      return;
    }
    // 阶段 1.5（api-spec.md：/auth/oauth 当前返回 50003）
    showToast(context, t.loginSignInWithIs(provider));
  }

  @override
  Widget build(BuildContext context) {
    final demo = AppScope.of(context).config.demoMode;
    final isLogin = _mode == LoginMode.login;
    return PageScaffold(
      title: isLogin ? t.welcomeSignIn : t.welcomeSignUp,
      content: [
        Seg2<LoginMode>(
          items: [(LoginMode.login, t.welcomeSignIn), (LoginMode.register, t.welcomeSignUp)],
          value: _mode,
          onChanged: (m) => setState(() {
            _mode = m;
            _errors = {};
          }),
        ),
        AppField(
          label: t.loginEmail,
          fieldKey: const Key('login.email'),
          controller: _email,
          hint: 'name@example.com',
          keyboardType: TextInputType.emailAddress,
          error: _errors['email'],
        ),
        AppField(
          label: t.loginVerificationCode,
          fieldKey: const Key('login.code'),
          controller: _code,
          hint: t.login6DigitCode,
          keyboardType: TextInputType.number,
          maxLength: 6,
          error: _errors['code'],
          helper: _sent && demo ? t.loginDemoVerificationCode000000 : null,
          suffix: AppButton(
            _countdown > 0 ? t.loginResendInS(_countdown) : (_sent ? t.loginResendCode : t.loginGetCode),
            key: const Key('login.send'),
            kind: ButtonKind.ghost,
            small: true,
            loading: _sending,
            onPressed: _countdown > 0 ? null : _sendCode,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.line)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(t.loginOr, style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
            Expanded(child: Divider(color: AppColors.line)),
          ],
        ),
        const SizedBox(height: 12),
        AppButton(t.loginContinueWithGoogle, kind: ButtonKind.ghost, onPressed: () => _social('Google')),
        const SizedBox(height: 8),
        AppButton(t.loginContinueWithApple, kind: ButtonKind.ghost, onPressed: () => _social('Apple')),
        const SizedBox(height: 6),
        Text(
          t.loginSignInWithGoogle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.faint),
        ),
        if (!isLogin) ...[
          const SizedBox(height: 12),
          InkWell(
            key: const Key('login.terms'),
            onTap: () => setState(() => _terms = !_terms),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: _terms, onChanged: (v) => setState(() => _terms = v ?? false)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: t.loginIHaveReadAnd, style: TextStyle(fontSize: 14)),
                          TextSpan(
                            text: t.loginTheseAreThePlatform,
                            style: TextStyle(fontSize: 12, color: AppColors.faint),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_errors['terms'] != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(_errors['terms']!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
        ],
      ],
      footer: [
        Expanded(
          child: AppButton(isLogin ? t.welcomeSignIn : t.loginSignUpSignIn, key: const Key('login.submit'), loading: _submitting, onPressed: _submit),
        ),
      ],
    );
  }
}
