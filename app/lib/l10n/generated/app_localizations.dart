import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @langTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言 / Language'**
  String get langTitle;

  /// No description provided for @langSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get langSystem;

  /// No description provided for @langZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get langZh;

  /// No description provided for @langEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @tabAssets.
  ///
  /// In zh, this message translates to:
  /// **'资产'**
  String get tabAssets;

  /// No description provided for @tabMarkets.
  ///
  /// In zh, this message translates to:
  /// **'市场'**
  String get tabMarkets;

  /// No description provided for @tabMasters.
  ///
  /// In zh, this message translates to:
  /// **'股票大师'**
  String get tabMasters;

  /// No description provided for @tabFifi.
  ///
  /// In zh, this message translates to:
  /// **'Fifi'**
  String get tabFifi;

  /// No description provided for @tabRewards.
  ///
  /// In zh, this message translates to:
  /// **'奖励'**
  String get tabRewards;

  /// No description provided for @errUnauthorized.
  ///
  /// In zh, this message translates to:
  /// **'请先登录'**
  String get errUnauthorized;

  /// No description provided for @errSessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录已过期，请重新登录'**
  String get errSessionExpired;

  /// No description provided for @errRestricted.
  ///
  /// In zh, this message translates to:
  /// **'账户当前受限，暂不能进行此操作'**
  String get errRestricted;

  /// No description provided for @errConflict.
  ///
  /// In zh, this message translates to:
  /// **'当前状态下无法完成此操作，请刷新后重试'**
  String get errConflict;

  /// No description provided for @errValidation.
  ///
  /// In zh, this message translates to:
  /// **'请检查标红的字段'**
  String get errValidation;

  /// No description provided for @errLimit.
  ///
  /// In zh, this message translates to:
  /// **'金额超出允许范围'**
  String get errLimit;

  /// No description provided for @errRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'操作过于频繁，请稍后再试'**
  String get errRateLimited;

  /// No description provided for @errInternal.
  ///
  /// In zh, this message translates to:
  /// **'服务暂时不可用，请稍后重试'**
  String get errInternal;

  /// No description provided for @errDwFailed.
  ///
  /// In zh, this message translates to:
  /// **'券商服务暂时不可用，请稍后重试'**
  String get errDwFailed;

  /// No description provided for @errDwBadData.
  ///
  /// In zh, this message translates to:
  /// **'券商返回的数据异常，请稍后重试'**
  String get errDwBadData;

  /// No description provided for @errNotEnabled.
  ///
  /// In zh, this message translates to:
  /// **'该功能暂未开通'**
  String get errNotEnabled;

  /// No description provided for @errNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络后重试'**
  String get errNetwork;

  /// No description provided for @errTimeout.
  ///
  /// In zh, this message translates to:
  /// **'请求超时，请稍后重试'**
  String get errTimeout;

  /// No description provided for @errBadResponse.
  ///
  /// In zh, this message translates to:
  /// **'服务器响应无法解析，请稍后重试'**
  String get errBadResponse;

  /// No description provided for @srvAccountNotOpened.
  ///
  /// In zh, this message translates to:
  /// **'交易账户尚未开立'**
  String get srvAccountNotOpened;

  /// No description provided for @srvAccountNotActive.
  ///
  /// In zh, this message translates to:
  /// **'交易账户尚未开通'**
  String get srvAccountNotActive;

  /// No description provided for @srvOrderNotCancelable.
  ///
  /// In zh, this message translates to:
  /// **'该订单当前状态不可撤单'**
  String get srvOrderNotCancelable;

  /// No description provided for @srvOrderNotFound.
  ///
  /// In zh, this message translates to:
  /// **'订单不存在'**
  String get srvOrderNotFound;

  /// No description provided for @srvBankNotFound.
  ///
  /// In zh, this message translates to:
  /// **'银行账户不存在或已解绑'**
  String get srvBankNotFound;

  /// No description provided for @srvPlaidNotEnabled.
  ///
  /// In zh, this message translates to:
  /// **'通过 Plaid 绑定银行账户暂未开通'**
  String get srvPlaidNotEnabled;

  /// No description provided for @srvBankBusy.
  ///
  /// In zh, this message translates to:
  /// **'该银行账户有处理中的出入金，完成后才能解绑'**
  String get srvBankBusy;

  /// No description provided for @srvNoLegalNameBank.
  ///
  /// In zh, this message translates to:
  /// **'未找到开户姓名，暂不能绑定银行账户'**
  String get srvNoLegalNameBank;

  /// No description provided for @srvNoLegalNameWithdraw.
  ///
  /// In zh, this message translates to:
  /// **'未找到开户姓名，暂不能出金'**
  String get srvNoLegalNameWithdraw;

  /// No description provided for @srvCancelNotAccepted.
  ///
  /// In zh, this message translates to:
  /// **'撤单未被券商受理，订单可能已成交，请刷新查看'**
  String get srvCancelNotAccepted;

  /// No description provided for @srvDupWithdrawal.
  ///
  /// In zh, this message translates to:
  /// **'刚刚已提交过相同金额的出金，请勿重复提交'**
  String get srvDupWithdrawal;

  /// No description provided for @srvDupDeposit.
  ///
  /// In zh, this message translates to:
  /// **'刚刚已提交过相同金额的入金，请勿重复提交'**
  String get srvDupDeposit;

  /// No description provided for @srvDupOrder.
  ///
  /// In zh, this message translates to:
  /// **'刚刚已提交过相同的订单，请勿重复提交'**
  String get srvDupOrder;

  /// No description provided for @srvOauthLater.
  ///
  /// In zh, this message translates to:
  /// **'Google / Apple 登录将在后续版本开通，请先使用邮箱验证码登录'**
  String get srvOauthLater;

  /// No description provided for @srvRestrictedSellOnly.
  ///
  /// In zh, this message translates to:
  /// **'账户当前仅可卖出，暂不能买入'**
  String get srvRestrictedSellOnly;

  /// No description provided for @errRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'请求失败，请稍后重试'**
  String get errRequestFailed;

  /// No description provided for @errFieldInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请检查此项'**
  String get errFieldInvalid;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
