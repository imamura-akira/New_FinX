// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get langTitle => '语言 / Language';

  @override
  String get langSystem => '跟随系统';

  @override
  String get langZh => '简体中文';

  @override
  String get langEn => 'English';

  @override
  String get tabAssets => '资产';

  @override
  String get tabMarkets => '市场';

  @override
  String get tabMasters => '股票大师';

  @override
  String get tabFifi => 'Fifi';

  @override
  String get tabRewards => '奖励';

  @override
  String get errUnauthorized => '请先登录';

  @override
  String get errSessionExpired => '登录已过期，请重新登录';

  @override
  String get errRestricted => '账户当前受限，暂不能进行此操作';

  @override
  String get errConflict => '当前状态下无法完成此操作，请刷新后重试';

  @override
  String get errValidation => '请检查标红的字段';

  @override
  String get errLimit => '金额超出允许范围';

  @override
  String get errRateLimited => '操作过于频繁，请稍后再试';

  @override
  String get errInternal => '服务暂时不可用，请稍后重试';

  @override
  String get errDwFailed => '券商服务暂时不可用，请稍后重试';

  @override
  String get errDwBadData => '券商返回的数据异常，请稍后重试';

  @override
  String get errNotEnabled => '该功能暂未开通';

  @override
  String get errNetwork => '网络连接失败，请检查网络后重试';

  @override
  String get errTimeout => '请求超时，请稍后重试';

  @override
  String get errBadResponse => '服务器响应无法解析，请稍后重试';

  @override
  String get srvAccountNotOpened => '交易账户尚未开立';

  @override
  String get srvAccountNotActive => '交易账户尚未开通';

  @override
  String get srvOrderNotCancelable => '该订单当前状态不可撤单';

  @override
  String get srvOrderNotFound => '订单不存在';

  @override
  String get srvBankNotFound => '银行账户不存在或已解绑';

  @override
  String get srvPlaidNotEnabled => '通过 Plaid 绑定银行账户暂未开通';

  @override
  String get srvBankBusy => '该银行账户有处理中的出入金，完成后才能解绑';

  @override
  String get srvNoLegalNameBank => '未找到开户姓名，暂不能绑定银行账户';

  @override
  String get srvNoLegalNameWithdraw => '未找到开户姓名，暂不能出金';

  @override
  String get srvCancelNotAccepted => '撤单未被券商受理，订单可能已成交，请刷新查看';

  @override
  String get srvDupWithdrawal => '刚刚已提交过相同金额的出金，请勿重复提交';

  @override
  String get srvDupDeposit => '刚刚已提交过相同金额的入金，请勿重复提交';

  @override
  String get srvDupOrder => '刚刚已提交过相同的订单，请勿重复提交';

  @override
  String get srvOauthLater => 'Google / Apple 登录将在后续版本开通，请先使用邮箱验证码登录';

  @override
  String get srvRestrictedSellOnly => '账户当前仅可卖出，暂不能买入';

  @override
  String get errRequestFailed => '请求失败，请稍后重试';

  @override
  String get errFieldInvalid => '请检查此项';
}
