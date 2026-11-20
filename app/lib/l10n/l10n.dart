import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_ui/material_ui.dart';

import '../core/api/api_client.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

// F18 国际化：简体中文 / 北美英语（ARB：lib/l10n/app_zh.arb 为模板，app_en.arb）。
// - 默认跟随系统语言：zh → 中文，其余 → 英文；账户抽屉可改为固定中文或英文（持久化）。
// - 开户与 KYC 模块（P-03–P-06、P-30、P-34–P-36）恒为英文，不走本文件。
// - 文案统一经全局 [t] 取用（领域层规则函数没有 BuildContext 也能取）；切换语言时 App 重建页面树（保留当前路由）。

const supportedLocales = [Locale('zh'), Locale('en')];

/// 系统语言 → 支持的语言：中文（任何地区）→ zh，其余 → en。
Locale resolveLocale(Locale? device) => device?.languageCode == 'zh' ? const Locale('zh') : const Locale('en');

AppLocalizations _current = lookupAppLocalizations(const Locale('zh'));

/// 当前语言的文案。
AppLocalizations get t => _current;

/// 当前是否英文。
bool get isEnglish => _current.localeName.startsWith('en');

/// 由 App 根组件在每次构建时设置（[FinxApp] 的 MaterialApp.builder）。
void setCurrentLocalizations(AppLocalizations l) => _current = l;

/// 测试用：直接切换文案语言。
@visibleForTesting
void debugSetLocale(Locale l) => _current = lookupAppLocalizations(l);

/// 语言设置：null = 跟随系统，'zh' / 'en' = 固定。持久化在 Keychain（与会话同一存储，非敏感值）。
class LocaleController extends ValueNotifier<String?> {
  LocaleController._() : super(null);
  static final instance = LocaleController._();

  static const _key = 'app_locale';
  FlutterSecureStorage? _storage;

  /// 启动时读取已保存的选择（失败按跟随系统）。
  Future<void> load([FlutterSecureStorage? storage]) async {
    _storage = storage ?? const FlutterSecureStorage();
    try {
      final v = await _storage!.read(key: _key);
      value = (v == 'zh' || v == 'en') ? v : null;
    } catch (_) {
      value = null;
    }
  }

  /// 选择语言（null = 跟随系统）并保存。
  Future<void> select(String? code) async {
    value = code;
    try {
      final s = _storage;
      if (s == null) return;
      if (code == null) {
        await s.delete(key: _key);
      } else {
        await s.write(key: _key, value: code);
      }
    } catch (_) {
      // 保存失败只影响下次启动，不影响当前选择
    }
  }

  /// MaterialApp.locale：跟随系统时为 null。
  Locale? get locale => value == null ? null : Locale(value!);

  @visibleForTesting
  void reset() => value = null;
}

// ---------------------------------------------------------------------------
// 报错本地化：按后端错误码映射双语文案；服务器 message 只在无映射时兜底（英文模式下不显示中文原文）。

final _hanRe = RegExp(r'[一-鿿]');

/// 后端已知的业务提示（原文 → 文案），比按错误码的通用提示更具体。
Map<String, String Function()> get _known => {
  '交易账户尚未开立': () => t.srvAccountNotOpened,
  '交易账户尚未开通': () => t.srvAccountNotActive,
  '该订单当前状态不可撤单': () => t.srvOrderNotCancelable,
  '订单不存在': () => t.srvOrderNotFound,
  '银行账户不存在或已解绑': () => t.srvBankNotFound,
  '通过 Plaid 绑定银行账户暂未开通': () => t.srvPlaidNotEnabled,
  '该银行账户有处理中的出入金，完成后才能解绑': () => t.srvBankBusy,
  '未找到开户姓名，暂不能绑定银行账户': () => t.srvNoLegalNameBank,
  '未找到开户姓名，暂不能出金': () => t.srvNoLegalNameWithdraw,
  '撤单未被券商受理，订单可能已成交，请刷新查看': () => t.srvCancelNotAccepted,
  '刚刚已提交过相同金额的出金，请勿重复提交': () => t.srvDupWithdrawal,
  '刚刚已提交过相同金额的入金，请勿重复提交': () => t.srvDupDeposit,
  '刚刚已提交过相同的订单，请勿重复提交': () => t.srvDupOrder,
  'Google / Apple 登录将在后续版本开通，请先使用邮箱验证码登录': () => t.srvOauthLater,
  '账户当前仅可卖出，暂不能买入': () => t.srvRestrictedSellOnly,
  '网络超时，请稍后重试': () => t.errTimeout,
  '网络连接失败，请检查网络后重试': () => t.errNetwork,
  '服务暂时不可用，请稍后重试': () => t.errInternal,
  '请求失败，请稍后重试': () => t.errRequestFailed,
};

/// 按错误码的通用文案；无映射返回 null。
String? errorForCode(int code) => switch (code) {
  ApiCodes.unauthorized => t.errUnauthorized,
  ApiCodes.sessionExpired => t.errSessionExpired,
  ApiCodes.restricted => t.errRestricted,
  ApiCodes.conflict => t.errConflict,
  ApiCodes.validation => t.errValidation,
  ApiCodes.limit => t.errLimit,
  ApiCodes.rateLimited => t.errRateLimited,
  ApiCodes.internal => t.errInternal,
  ApiCodes.dwFailed => t.errDwFailed,
  ApiCodes.dwBadData => t.errDwBadData,
  ApiCodes.notEnabled => t.errNotEnabled,
  ApiCodes.network => t.errNetwork,
  _ => null,
};

/// 后端错误的展示文案：已知原文 → 对应文案；中文模式下保留后端的具体中文提示；
/// 英文模式下后端原文为中文时改用错误码通用文案；均无则用原文兜底。
String localizeError(int code, String serverMessage) {
  final known = _known[serverMessage.trim()];
  if (known != null) return known();
  final generic = errorForCode(code);
  if (!isEnglish) return serverMessage.isNotEmpty ? serverMessage : (generic ?? t.errRequestFailed);
  if (serverMessage.isEmpty || _hanRe.hasMatch(serverMessage)) return generic ?? t.errRequestFailed;
  return serverMessage;
}

/// 字段级错误文案：英文模式下中文原文改为通用提示。
String localizeFieldReason(String reason) {
  final known = _known[reason.trim()];
  if (known != null) return known();
  return isEnglish && _hanRe.hasMatch(reason) ? t.errFieldInvalid : reason;
}

// ---------------------------------------------------------------------------
// 日期：中文 2026-11-19 14:05；英文（美式）11/19/2026 2:05 PM。金额两种语言一致（$1,234.56）。

String _two(int n) => n.toString().padLeft(2, '0');

String _usTime(DateTime l) {
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  return '$h:${_two(l.minute)} ${l.hour < 12 ? 'AM' : 'PM'}';
}

String formatDateTime(DateTime l) =>
    isEnglish ? '${l.month}/${l.day}/${l.year} ${_usTime(l)}' : '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';

String formatDate(DateTime l) => isEnglish ? '${l.month}/${l.day}/${l.year}' : '${l.year}-${_two(l.month)}-${_two(l.day)}';

String formatClock(DateTime l) => isEnglish ? _usTime(l) : '${_two(l.hour)}:${_two(l.minute)}';

/// 图表横轴短日期：中文 11-20，英文 11/20。
String formatShortDate(DateTime d) => isEnglish ? '${d.month}/${d.day}' : '${_two(d.month)}-${_two(d.day)}';
