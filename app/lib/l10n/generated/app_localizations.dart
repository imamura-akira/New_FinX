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

  /// No description provided for @commonBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get commonBack;

  /// No description provided for @expiredPleaseSignInAgain.
  ///
  /// In zh, this message translates to:
  /// **'请重新登录'**
  String get expiredPleaseSignInAgain;

  /// No description provided for @expiredYourSessionHasExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录已过期或尚未登录。返回 App 登录后即可继续您的申请。'**
  String get expiredYourSessionHasExpired;

  /// No description provided for @expiredBackToSignIn.
  ///
  /// In zh, this message translates to:
  /// **'返回登录'**
  String get expiredBackToSignIn;

  /// No description provided for @welcomeInvestInUsStocks.
  ///
  /// In zh, this message translates to:
  /// **'美股与 ETF 投资，开户、入金、交易一站完成。'**
  String get welcomeInvestInUsStocks;

  /// No description provided for @welcomeSignUp.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get welcomeSignUp;

  /// No description provided for @welcomeSignIn.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get welcomeSignIn;

  /// No description provided for @welcomeBrowseMarketsFirst.
  ///
  /// In zh, this message translates to:
  /// **'先逛逛行情'**
  String get welcomeBrowseMarketsFirst;

  /// No description provided for @welcomeBrokerageServicesAreProvided.
  ///
  /// In zh, this message translates to:
  /// **'证券服务由合作券商提供。投资有风险。'**
  String get welcomeBrokerageServicesAreProvided;

  /// No description provided for @loginPleaseEnterAValid.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的邮箱地址'**
  String get loginPleaseEnterAValid;

  /// No description provided for @loginVerificationCodeSent.
  ///
  /// In zh, this message translates to:
  /// **'验证码已发送'**
  String get loginVerificationCodeSent;

  /// No description provided for @loginPleaseEnterThe6.
  ///
  /// In zh, this message translates to:
  /// **'请输入 6 位验证码'**
  String get loginPleaseEnterThe6;

  /// No description provided for @loginPleaseAgreeToThe.
  ///
  /// In zh, this message translates to:
  /// **'请先同意平台条款'**
  String get loginPleaseAgreeToThe;

  /// No description provided for @loginSignInWithIs.
  ///
  /// In zh, this message translates to:
  /// **'{provider} 登录将在后续版本开通，请先使用邮箱验证码登录'**
  String loginSignInWithIs(Object provider);

  /// No description provided for @loginEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get loginEmail;

  /// No description provided for @loginVerificationCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get loginVerificationCode;

  /// No description provided for @login6DigitCode.
  ///
  /// In zh, this message translates to:
  /// **'6 位验证码'**
  String get login6DigitCode;

  /// No description provided for @loginDemoVerificationCode000000.
  ///
  /// In zh, this message translates to:
  /// **'演示环境验证码：000000'**
  String get loginDemoVerificationCode000000;

  /// No description provided for @loginResendInS.
  ///
  /// In zh, this message translates to:
  /// **'{_countdown}s 后重发'**
  String loginResendInS(Object _countdown);

  /// No description provided for @loginResendCode.
  ///
  /// In zh, this message translates to:
  /// **'重新获取'**
  String get loginResendCode;

  /// No description provided for @loginGetCode.
  ///
  /// In zh, this message translates to:
  /// **'获取验证码'**
  String get loginGetCode;

  /// No description provided for @loginOr.
  ///
  /// In zh, this message translates to:
  /// **'或'**
  String get loginOr;

  /// No description provided for @loginContinueWithGoogle.
  ///
  /// In zh, this message translates to:
  /// **'使用 Google 登录'**
  String get loginContinueWithGoogle;

  /// No description provided for @loginContinueWithApple.
  ///
  /// In zh, this message translates to:
  /// **'通过 Apple 登录'**
  String get loginContinueWithApple;

  /// No description provided for @loginSignInWithGoogle.
  ///
  /// In zh, this message translates to:
  /// **'Google / Apple 登录将在后续版本开通。提供 Google 登录时同时提供 Apple 登录。'**
  String get loginSignInWithGoogle;

  /// No description provided for @loginIHaveReadAnd.
  ///
  /// In zh, this message translates to:
  /// **'我已阅读并同意平台《用户服务协议》与《隐私政策》\n'**
  String get loginIHaveReadAnd;

  /// No description provided for @loginTheseAreThePlatform.
  ///
  /// In zh, this message translates to:
  /// **'此为平台自有条款，券商（DriveWealth）披露将在开户时单独展示。'**
  String get loginTheseAreThePlatform;

  /// No description provided for @loginSignUpSignIn.
  ///
  /// In zh, this message translates to:
  /// **'注册并登录'**
  String get loginSignUpSignIn;

  /// No description provided for @assetStock.
  ///
  /// In zh, this message translates to:
  /// **'股票'**
  String get assetStock;

  /// No description provided for @assetEtf.
  ///
  /// In zh, this message translates to:
  /// **'ETF'**
  String get assetEtf;

  /// No description provided for @assetCash.
  ///
  /// In zh, this message translates to:
  /// **'现金'**
  String get assetCash;

  /// No description provided for @rangeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get rangeAll;

  /// No description provided for @rangeDays.
  ///
  /// In zh, this message translates to:
  /// **'{days} 天'**
  String rangeDays(Object days);

  /// No description provided for @cueReferenceNo.
  ///
  /// In zh, this message translates to:
  /// **'参考号 {ref}'**
  String cueReferenceNo(Object ref);

  /// No description provided for @homePaperAccountHasBeen.
  ///
  /// In zh, this message translates to:
  /// **'模拟账户已重置'**
  String get homePaperAccountHasBeen;

  /// No description provided for @homeCouldnTRefreshPlease.
  ///
  /// In zh, this message translates to:
  /// **'刷新失败，请稍后重试'**
  String get homeCouldnTRefreshPlease;

  /// No description provided for @homeAccount.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get homeAccount;

  /// No description provided for @homeCouldnTRefreshYour.
  ///
  /// In zh, this message translates to:
  /// **'资产数据暂时无法刷新：{error}'**
  String homeCouldnTRefreshYour(Object error);

  /// No description provided for @homeAccountDataFromDrivewealth.
  ///
  /// In zh, this message translates to:
  /// **'资金数据来自 DriveWealth · 更新于 {v0}'**
  String homeAccountDataFromDrivewealth(Object v0);

  /// No description provided for @homeDepositsInTransitNot.
  ///
  /// In zh, this message translates to:
  /// **'在途入金（尚未计入购买力）'**
  String get homeDepositsInTransitNot;

  /// No description provided for @homeNotYetWithdrawableHolding.
  ///
  /// In zh, this message translates to:
  /// **'观察期内暂不可提现'**
  String get homeNotYetWithdrawableHolding;

  /// No description provided for @homePendingSettlement.
  ///
  /// In zh, this message translates to:
  /// **'待交收'**
  String get homePendingSettlement;

  /// No description provided for @homeFundYourAccountTo.
  ///
  /// In zh, this message translates to:
  /// **'入金开始投资'**
  String get homeFundYourAccountTo;

  /// No description provided for @homeLinkYourOwnUs.
  ///
  /// In zh, this message translates to:
  /// **'绑定本人美国银行账户（ACH）后转入资金'**
  String get homeLinkYourOwnUs;

  /// No description provided for @homeDeposit.
  ///
  /// In zh, this message translates to:
  /// **'入金'**
  String get homeDeposit;

  /// No description provided for @homeBrowseMarketsFirst.
  ///
  /// In zh, this message translates to:
  /// **'先看看行情'**
  String get homeBrowseMarketsFirst;

  /// No description provided for @homeTrading.
  ///
  /// In zh, this message translates to:
  /// **'交易'**
  String get homeTrading;

  /// No description provided for @homePositions.
  ///
  /// In zh, this message translates to:
  /// **'持仓'**
  String get homePositions;

  /// No description provided for @homeQuantityMarketValueCost.
  ///
  /// In zh, this message translates to:
  /// **'数量、市值、成本与盈亏（券商返回）'**
  String get homeQuantityMarketValueCost;

  /// No description provided for @homeOrders.
  ///
  /// In zh, this message translates to:
  /// **'订单'**
  String get homeOrders;

  /// No description provided for @homeCheckOrderStatusAnd.
  ///
  /// In zh, this message translates to:
  /// **'查看订单状态，撤销未成交订单'**
  String get homeCheckOrderStatusAnd;

  /// No description provided for @homeWatchlist.
  ///
  /// In zh, this message translates to:
  /// **'自选股'**
  String get homeWatchlist;

  /// No description provided for @homeGoToMarkets.
  ///
  /// In zh, this message translates to:
  /// **'去市场'**
  String get homeGoToMarkets;

  /// No description provided for @homeYourWatchlistIsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有自选股。在个股页点击右上角星标即可加入。'**
  String get homeYourWatchlistIsEmpty;

  /// No description provided for @homeCouldnTRefreshYour2.
  ///
  /// In zh, this message translates to:
  /// **'模拟账户暂时无法刷新：{_paperError}'**
  String homeCouldnTRefreshYour2(Object _paperError);

  /// No description provided for @homePaperTrading.
  ///
  /// In zh, this message translates to:
  /// **'模拟交易'**
  String get homePaperTrading;

  /// No description provided for @homePaperPositions.
  ///
  /// In zh, this message translates to:
  /// **'模拟持仓'**
  String get homePaperPositions;

  /// No description provided for @homePaperPositionsAndP.
  ///
  /// In zh, this message translates to:
  /// **'按演示行情估值的模拟持仓与盈亏'**
  String get homePaperPositionsAndP;

  /// No description provided for @homePaperOrders.
  ///
  /// In zh, this message translates to:
  /// **'模拟订单'**
  String get homePaperOrders;

  /// No description provided for @homeMarketOrdersFillInstantly.
  ///
  /// In zh, this message translates to:
  /// **'市价单即时成交，限价单到价成交，可撤单'**
  String get homeMarketOrdersFillInstantly;

  /// No description provided for @homePickAStockOn.
  ///
  /// In zh, this message translates to:
  /// **'在市场页选择股票，点\"买入 / 卖出\"即可模拟下单。'**
  String get homePickAStockOn;

  /// No description provided for @homeLiveTotalAssetsUsd.
  ///
  /// In zh, this message translates to:
  /// **'实盘 · 总资产 (USD)'**
  String get homeLiveTotalAssetsUsd;

  /// No description provided for @homeBuyingPower.
  ///
  /// In zh, this message translates to:
  /// **'购买力'**
  String get homeBuyingPower;

  /// No description provided for @homeAvailableToWithdraw.
  ///
  /// In zh, this message translates to:
  /// **'可提现'**
  String get homeAvailableToWithdraw;

  /// No description provided for @homePendingSandboxVerification.
  ///
  /// In zh, this message translates to:
  /// **'待沙盒验证'**
  String get homePendingSandboxVerification;

  /// No description provided for @drawerSwitchAccount.
  ///
  /// In zh, this message translates to:
  /// **'切换账户'**
  String get drawerSwitchAccount;

  /// No description provided for @drawerLive.
  ///
  /// In zh, this message translates to:
  /// **'实盘'**
  String get drawerLive;

  /// No description provided for @drawerPaper.
  ///
  /// In zh, this message translates to:
  /// **'模拟'**
  String get drawerPaper;

  /// No description provided for @drawerPaperAccountIsnT.
  ///
  /// In zh, this message translates to:
  /// **'模拟账户暂未开放'**
  String get drawerPaperAccountIsnT;

  /// No description provided for @drawerFunds.
  ///
  /// In zh, this message translates to:
  /// **'资金'**
  String get drawerFunds;

  /// No description provided for @drawerWithdraw.
  ///
  /// In zh, this message translates to:
  /// **'出金'**
  String get drawerWithdraw;

  /// No description provided for @drawerBankAccounts.
  ///
  /// In zh, this message translates to:
  /// **'银行账户'**
  String get drawerBankAccounts;

  /// No description provided for @drawerTransferFromAnotherBroker.
  ///
  /// In zh, this message translates to:
  /// **'转入其他券商账户'**
  String get drawerTransferFromAnotherBroker;

  /// No description provided for @drawerActivity.
  ///
  /// In zh, this message translates to:
  /// **'动态'**
  String get drawerActivity;

  /// No description provided for @drawerNotifications.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get drawerNotifications;

  /// No description provided for @drawerHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史记录'**
  String get drawerHistory;

  /// No description provided for @drawerDocuments.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get drawerDocuments;

  /// No description provided for @drawerManage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get drawerManage;

  /// No description provided for @drawerSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get drawerSettings;

  /// No description provided for @drawerHelpCenter.
  ///
  /// In zh, this message translates to:
  /// **'帮助中心'**
  String get drawerHelpCenter;

  /// No description provided for @drawerSignOut.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get drawerSignOut;

  /// No description provided for @drawerBrokerageAccountUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'交易账户暂不可用'**
  String get drawerBrokerageAccountUnavailable;

  /// No description provided for @drawerAccountNumber.
  ///
  /// In zh, this message translates to:
  /// **'账户号码'**
  String get drawerAccountNumber;

  /// No description provided for @drawerMarketValue.
  ///
  /// In zh, this message translates to:
  /// **'市值'**
  String get drawerMarketValue;

  /// No description provided for @drawerSellOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅可卖出'**
  String get drawerSellOnly;

  /// No description provided for @drawerFrozen.
  ///
  /// In zh, this message translates to:
  /// **'已冻结'**
  String get drawerFrozen;

  /// No description provided for @drawerClosed.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get drawerClosed;

  /// No description provided for @drawerOpening.
  ///
  /// In zh, this message translates to:
  /// **'开立中'**
  String get drawerOpening;

  /// No description provided for @drawerLiveAccount.
  ///
  /// In zh, this message translates to:
  /// **'实盘账户'**
  String get drawerLiveAccount;

  /// No description provided for @drawerCashSelfDirected.
  ///
  /// In zh, this message translates to:
  /// **'现金 · 自主'**
  String get drawerCashSelfDirected;

  /// No description provided for @drawerAccountNumberCopied.
  ///
  /// In zh, this message translates to:
  /// **'账户号码已复制'**
  String get drawerAccountNumberCopied;

  /// No description provided for @drawerAccountType.
  ///
  /// In zh, this message translates to:
  /// **'账户类型 {accountType} · {tradingType} · {managementType}'**
  String drawerAccountType(
    Object accountType,
    Object tradingType,
    Object managementType,
  );

  /// No description provided for @drawerPositionsValue.
  ///
  /// In zh, this message translates to:
  /// **'持仓市值'**
  String get drawerPositionsValue;

  /// No description provided for @drawerTransferIn.
  ///
  /// In zh, this message translates to:
  /// **'转入'**
  String get drawerTransferIn;

  /// No description provided for @drawerThisFeatureIsnT.
  ///
  /// In zh, this message translates to:
  /// **'该功能不在本次演示范围'**
  String get drawerThisFeatureIsnT;

  /// No description provided for @drawerSignOut2.
  ///
  /// In zh, this message translates to:
  /// **'退出登录？'**
  String get drawerSignOut2;

  /// No description provided for @drawerYouLlNeedTo.
  ///
  /// In zh, this message translates to:
  /// **'退出后需重新验证邮箱登录。'**
  String get drawerYouLlNeedTo;

  /// No description provided for @drawerCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get drawerCancel;

  /// No description provided for @drawerSignOut3.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get drawerSignOut3;

  /// No description provided for @drawerKycStatus.
  ///
  /// In zh, this message translates to:
  /// **'KYC 状态'**
  String get drawerKycStatus;

  /// No description provided for @drawerLastSynced.
  ///
  /// In zh, this message translates to:
  /// **'最近同步'**
  String get drawerLastSynced;

  /// No description provided for @drawerDwSandboxIds.
  ///
  /// In zh, this message translates to:
  /// **'DW 沙盒凭证'**
  String get drawerDwSandboxIds;

  /// No description provided for @drawerDemoOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅演示'**
  String get drawerDemoOnly;

  /// No description provided for @drawerNoDwIdsYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无 DW 编号：账户尚未开立，或后端未开启演示环境（OTP_DEV_LOG）。'**
  String get drawerNoDwIdsYet;

  /// No description provided for @drawerCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制 {k}'**
  String drawerCopied(Object k);

  /// No description provided for @drawerTheseAreTheValues.
  ///
  /// In zh, this message translates to:
  /// **'以上为 DW 沙盒返回值，可与 demoreset verify 的输出逐项对照。'**
  String get drawerTheseAreTheValues;

  /// No description provided for @cueYourAccountIsFrozen.
  ///
  /// In zh, this message translates to:
  /// **'账户已冻结：暂不能交易、入金或出金。资产仍安全托管，请联系客服了解原因。'**
  String get cueYourAccountIsFrozen;

  /// No description provided for @cueYourAccountIsLimited.
  ///
  /// In zh, this message translates to:
  /// **'账户仅可卖出：暂不能买入新证券，可卖出现有持仓、入金和出金。'**
  String get cueYourAccountIsLimited;

  /// No description provided for @cueYourAccountIsClosed.
  ///
  /// In zh, this message translates to:
  /// **'账户已关闭。如有疑问请联系客服。'**
  String get cueYourAccountIsClosed;

  /// No description provided for @cueOpenABrokerageAccount.
  ///
  /// In zh, this message translates to:
  /// **'开通证券账户'**
  String get cueOpenABrokerageAccount;

  /// No description provided for @cueVerifyYourIdentityTo.
  ///
  /// In zh, this message translates to:
  /// **'验证身份即可入金交易，约需 5 分钟'**
  String get cueVerifyYourIdentityTo;

  /// No description provided for @cueOpenAnAccount.
  ///
  /// In zh, this message translates to:
  /// **'去开户'**
  String get cueOpenAnAccount;

  /// No description provided for @cueContinueOpeningYourAccount.
  ///
  /// In zh, this message translates to:
  /// **'继续开通您的账户'**
  String get cueContinueOpeningYourAccount;

  /// No description provided for @cueYourProgressIsSaved.
  ///
  /// In zh, this message translates to:
  /// **'进度已保存，可从上次中断处继续'**
  String get cueYourProgressIsSaved;

  /// No description provided for @cueContinueApplication.
  ///
  /// In zh, this message translates to:
  /// **'继续开户'**
  String get cueContinueApplication;

  /// No description provided for @cueApplicationSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'开户申请已提交'**
  String get cueApplicationSubmitted;

  /// No description provided for @cueCheckYourApplicationStatus.
  ///
  /// In zh, this message translates to:
  /// **'查看开户进度'**
  String get cueCheckYourApplicationStatus;

  /// No description provided for @cueViewStatus.
  ///
  /// In zh, this message translates to:
  /// **'查看进度'**
  String get cueViewStatus;

  /// No description provided for @cueYourApplicationNeedsManual.
  ///
  /// In zh, this message translates to:
  /// **'开户申请需要人工处理'**
  String get cueYourApplicationNeedsManual;

  /// No description provided for @cueWeLlBeIn.
  ///
  /// In zh, this message translates to:
  /// **'我们会尽快联系您'**
  String get cueWeLlBeIn;

  /// No description provided for @cueOpeningYourBrokerageAccount.
  ///
  /// In zh, this message translates to:
  /// **'交易账户开立中'**
  String get cueOpeningYourBrokerageAccount;

  /// No description provided for @cueIdentityVerifiedTimingTo.
  ///
  /// In zh, this message translates to:
  /// **'身份核验已通过（预计时长待 DW 确认）'**
  String get cueIdentityVerifiedTimingTo;

  /// No description provided for @cueYourApplicationNeedsChanges.
  ///
  /// In zh, this message translates to:
  /// **'开户资料需要修改'**
  String get cueYourApplicationNeedsChanges;

  /// No description provided for @cuePleaseUpdateTheRequested.
  ///
  /// In zh, this message translates to:
  /// **'请按提示修改后重新提交'**
  String get cuePleaseUpdateTheRequested;

  /// No description provided for @cueUpdateApplication.
  ///
  /// In zh, this message translates to:
  /// **'去修改资料'**
  String get cueUpdateApplication;

  /// No description provided for @cueIdDocumentRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要上传身份证件'**
  String get cueIdDocumentRequired;

  /// No description provided for @cueWeLlReVerify.
  ///
  /// In zh, this message translates to:
  /// **'上传后将重新核验'**
  String get cueWeLlReVerify;

  /// No description provided for @cueUploadId.
  ///
  /// In zh, this message translates to:
  /// **'去上传证件'**
  String get cueUploadId;

  /// No description provided for @cueApplicationUnderManualReview.
  ///
  /// In zh, this message translates to:
  /// **'开户申请人工复核中'**
  String get cueApplicationUnderManualReview;

  /// No description provided for @cueTimingToBeConfirmed.
  ///
  /// In zh, this message translates to:
  /// **'预计时长待 DW 确认'**
  String get cueTimingToBeConfirmed;

  /// No description provided for @cueViewApplicationStatus.
  ///
  /// In zh, this message translates to:
  /// **'查看申请进度'**
  String get cueViewApplicationStatus;

  /// No description provided for @cueApplicationNotApproved.
  ///
  /// In zh, this message translates to:
  /// **'开户未通过'**
  String get cueApplicationNotApproved;

  /// No description provided for @cueSeeTheResultAnd.
  ///
  /// In zh, this message translates to:
  /// **'查看结果与后续可选操作'**
  String get cueSeeTheResultAnd;

  /// No description provided for @cueViewResult.
  ///
  /// In zh, this message translates to:
  /// **'查看结果'**
  String get cueViewResult;

  /// No description provided for @cueVerifyingYourIdentity.
  ///
  /// In zh, this message translates to:
  /// **'身份核验中'**
  String get cueVerifyingYourIdentity;

  /// No description provided for @allocAssetAllocation.
  ///
  /// In zh, this message translates to:
  /// **'资产分布'**
  String get allocAssetAllocation;

  /// No description provided for @allocValuedAtDemoPrices.
  ///
  /// In zh, this message translates to:
  /// **'虚拟行情估值'**
  String get allocValuedAtDemoPrices;

  /// No description provided for @allocByLatestMarketValue.
  ///
  /// In zh, this message translates to:
  /// **'按最新市值 · DW 实时'**
  String get allocByLatestMarketValue;

  /// No description provided for @allocTotalAssets.
  ///
  /// In zh, this message translates to:
  /// **'总资产'**
  String get allocTotalAssets;

  /// No description provided for @allocAssetTrend.
  ///
  /// In zh, this message translates to:
  /// **'资产趋势'**
  String get allocAssetTrend;

  /// No description provided for @allocDailySnapshots.
  ///
  /// In zh, this message translates to:
  /// **'每日快照'**
  String get allocDailySnapshots;

  /// No description provided for @allocDailySnapshotsSinceAccount.
  ///
  /// In zh, this message translates to:
  /// **'每日快照 · 自开户起记录'**
  String get allocDailySnapshotsSinceAccount;

  /// No description provided for @allocBuildingYourHistoryThe.
  ///
  /// In zh, this message translates to:
  /// **'记录积累中，次日起可见趋势'**
  String get allocBuildingYourHistoryThe;

  /// No description provided for @etfCatIndex.
  ///
  /// In zh, this message translates to:
  /// **'大盘指数'**
  String get etfCatIndex;

  /// No description provided for @etfCatCommodity.
  ///
  /// In zh, this message translates to:
  /// **'大宗商品'**
  String get etfCatCommodity;

  /// No description provided for @etfCatBond.
  ///
  /// In zh, this message translates to:
  /// **'债券'**
  String get etfCatBond;

  /// No description provided for @etfCatSector.
  ///
  /// In zh, this message translates to:
  /// **'行业'**
  String get etfCatSector;

  /// No description provided for @etfCatIntl.
  ///
  /// In zh, this message translates to:
  /// **'海外市场'**
  String get etfCatIntl;

  /// No description provided for @etfCatVolatility.
  ///
  /// In zh, this message translates to:
  /// **'波动率'**
  String get etfCatVolatility;

  /// No description provided for @marketAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get marketAll;

  /// No description provided for @marketDataNote.
  ///
  /// In zh, this message translates to:
  /// **'演示数据：虚拟行情（随机模拟，非真实报价）\n行情数据仅供参考，不构成投资建议。'**
  String get marketDataNote;

  /// No description provided for @marketDataNoteUpdated.
  ///
  /// In zh, this message translates to:
  /// **'演示数据：虚拟行情（随机模拟，非真实报价） · 更新于 {time}\n行情数据仅供参考，不构成投资建议。'**
  String marketDataNoteUpdated(Object time);

  /// No description provided for @instrumentStock.
  ///
  /// In zh, this message translates to:
  /// **'股票'**
  String get instrumentStock;

  /// No description provided for @instrumentSimulated.
  ///
  /// In zh, this message translates to:
  /// **'虚拟行情（演示数据）'**
  String get instrumentSimulated;

  /// No description provided for @instrumentRealtime.
  ///
  /// In zh, this message translates to:
  /// **'实时'**
  String get instrumentRealtime;

  /// No description provided for @instrumentUpdated.
  ///
  /// In zh, this message translates to:
  /// **'{source} · 更新于 {time}'**
  String instrumentUpdated(Object source, Object time);

  /// No description provided for @fgExtremeFear.
  ///
  /// In zh, this message translates to:
  /// **'极度恐慌'**
  String get fgExtremeFear;

  /// No description provided for @fgFear.
  ///
  /// In zh, this message translates to:
  /// **'恐慌'**
  String get fgFear;

  /// No description provided for @fgNeutral.
  ///
  /// In zh, this message translates to:
  /// **'中性'**
  String get fgNeutral;

  /// No description provided for @fgGreed.
  ///
  /// In zh, this message translates to:
  /// **'贪婪'**
  String get fgGreed;

  /// No description provided for @fgExtremeGreed.
  ///
  /// In zh, this message translates to:
  /// **'极度贪婪'**
  String get fgExtremeGreed;

  /// No description provided for @marketCouldnTRefreshQuotes.
  ///
  /// In zh, this message translates to:
  /// **'行情暂时无法刷新：{error}'**
  String marketCouldnTRefreshQuotes(Object error);

  /// No description provided for @marketTopGainers.
  ///
  /// In zh, this message translates to:
  /// **'涨幅榜'**
  String get marketTopGainers;

  /// No description provided for @marketTopLosers.
  ///
  /// In zh, this message translates to:
  /// **'跌幅榜'**
  String get marketTopLosers;

  /// No description provided for @marketEtfRankings.
  ///
  /// In zh, this message translates to:
  /// **'ETF 排行'**
  String get marketEtfRankings;

  /// No description provided for @marketNone.
  ///
  /// In zh, this message translates to:
  /// **'暂无'**
  String get marketNone;

  /// No description provided for @instrumentWatchlist.
  ///
  /// In zh, this message translates to:
  /// **'自选'**
  String get instrumentWatchlist;

  /// No description provided for @instrumentRemovedFromWatchlist.
  ///
  /// In zh, this message translates to:
  /// **'已从自选移除'**
  String get instrumentRemovedFromWatchlist;

  /// No description provided for @instrumentAddedToWatchlist.
  ///
  /// In zh, this message translates to:
  /// **'已加入自选'**
  String get instrumentAddedToWatchlist;

  /// No description provided for @instrumentSell.
  ///
  /// In zh, this message translates to:
  /// **'卖出'**
  String get instrumentSell;

  /// No description provided for @instrumentBuy.
  ///
  /// In zh, this message translates to:
  /// **'买入'**
  String get instrumentBuy;

  /// No description provided for @instrumentUnavailableRightNow.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法查看'**
  String get instrumentUnavailableRightNow;

  /// No description provided for @instrumentCouldnTRefreshQuotes.
  ///
  /// In zh, this message translates to:
  /// **'行情暂时无法刷新：{_error}'**
  String instrumentCouldnTRefreshQuotes(Object _error);

  /// No description provided for @instrumentQuote.
  ///
  /// In zh, this message translates to:
  /// **'报价'**
  String get instrumentQuote;

  /// No description provided for @instrumentBid.
  ///
  /// In zh, this message translates to:
  /// **'买一价（Bid）'**
  String get instrumentBid;

  /// No description provided for @instrumentAsk.
  ///
  /// In zh, this message translates to:
  /// **'卖一价（Ask）'**
  String get instrumentAsk;

  /// No description provided for @instrumentIntraday1MinDashed.
  ///
  /// In zh, this message translates to:
  /// **'分时（1 分钟） · 虚线为昨收'**
  String get instrumentIntraday1MinDashed;

  /// No description provided for @instrumentKeyStats.
  ///
  /// In zh, this message translates to:
  /// **'关键数据'**
  String get instrumentKeyStats;

  /// No description provided for @instrumentPrevClose.
  ///
  /// In zh, this message translates to:
  /// **'昨收'**
  String get instrumentPrevClose;

  /// No description provided for @instrumentDayHigh.
  ///
  /// In zh, this message translates to:
  /// **'今日最高'**
  String get instrumentDayHigh;

  /// No description provided for @instrumentDayLow.
  ///
  /// In zh, this message translates to:
  /// **'今日最低'**
  String get instrumentDayLow;

  /// No description provided for @moodMarketSentiment.
  ///
  /// In zh, this message translates to:
  /// **'市场情绪'**
  String get moodMarketSentiment;

  /// No description provided for @moodDemoDataUpdatesEvery.
  ///
  /// In zh, this message translates to:
  /// **'演示数据 · 每 3 秒更新'**
  String get moodDemoDataUpdatesEvery;

  /// No description provided for @moodDerivedFromSimulatedPrice.
  ///
  /// In zh, this message translates to:
  /// **'由虚拟行情的涨跌幅、动量与波动合成'**
  String get moodDerivedFromSimulatedPrice;

  /// No description provided for @moodAdvancersDecliners.
  ///
  /// In zh, this message translates to:
  /// **'涨跌家数'**
  String get moodAdvancersDecliners;

  /// No description provided for @moodUp.
  ///
  /// In zh, this message translates to:
  /// **'{up} 涨'**
  String moodUp(Object up);

  /// No description provided for @moodDown.
  ///
  /// In zh, this message translates to:
  /// **'{down} 跌'**
  String moodDown(Object down);

  /// No description provided for @moodFlat.
  ///
  /// In zh, this message translates to:
  /// **'{flat} 平'**
  String moodFlat(Object flat);

  /// No description provided for @moodUp2.
  ///
  /// In zh, this message translates to:
  /// **'上涨 {up}'**
  String moodUp2(Object up);

  /// No description provided for @moodFlat2.
  ///
  /// In zh, this message translates to:
  /// **'平盘 {flat}'**
  String moodFlat2(Object flat);

  /// No description provided for @moodDown2.
  ///
  /// In zh, this message translates to:
  /// **'下跌 {down}'**
  String moodDown2(Object down);

  /// No description provided for @paperPlValue.
  ///
  /// In zh, this message translates to:
  /// **'模拟盈亏 {pl}（{pct}）'**
  String paperPlValue(Object pl, Object pct);

  /// No description provided for @positionsFromDw.
  ///
  /// In zh, this message translates to:
  /// **'持仓数据来自 DriveWealth'**
  String get positionsFromDw;

  /// No description provided for @positionsFromDwUpdated.
  ///
  /// In zh, this message translates to:
  /// **'持仓数据来自 DriveWealth · 更新于 {time}'**
  String positionsFromDwUpdated(Object time);

  /// No description provided for @positionsTotalPl.
  ///
  /// In zh, this message translates to:
  /// **'持仓盈亏 {pl}'**
  String positionsTotalPl(Object pl);

  /// No description provided for @tradePleaseEnterAnAmount.
  ///
  /// In zh, this message translates to:
  /// **'请输入金额'**
  String get tradePleaseEnterAnAmount;

  /// No description provided for @tradeEnterAValidAmount.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效金额，最多两位小数'**
  String get tradeEnterAValidAmount;

  /// No description provided for @tradeExceedsYourAvailableBuying.
  ///
  /// In zh, this message translates to:
  /// **'超过可用购买力 {v0}'**
  String tradeExceedsYourAvailableBuying(Object v0);

  /// No description provided for @tradeExceedsTheSellableMarket.
  ///
  /// In zh, this message translates to:
  /// **'超过可卖市值 {v0}'**
  String tradeExceedsTheSellableMarket(Object v0);

  /// No description provided for @tradePleaseEnterTheNumber.
  ///
  /// In zh, this message translates to:
  /// **'请输入股数'**
  String get tradePleaseEnterTheNumber;

  /// No description provided for @tradeEnterAValidNumber.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效股数，最多 6 位小数'**
  String get tradeEnterAValidNumber;

  /// No description provided for @tradeSharesMustBeGreater.
  ///
  /// In zh, this message translates to:
  /// **'股数须大于 0'**
  String get tradeSharesMustBeGreater;

  /// No description provided for @tradeNoQuoteAvailablePlease.
  ///
  /// In zh, this message translates to:
  /// **'暂无报价，请按金额买入'**
  String get tradeNoQuoteAvailablePlease;

  /// No description provided for @tradeEstimatedAmountExceedsYour.
  ///
  /// In zh, this message translates to:
  /// **'预估金额 {v0} 超过可用购买力 {v1}'**
  String tradeEstimatedAmountExceedsYour(Object v0, Object v1);

  /// No description provided for @tradeExceedsYourSellableQuantity.
  ///
  /// In zh, this message translates to:
  /// **'超过可卖数量 {v0} 股'**
  String tradeExceedsYourSellableQuantity(Object v0);

  /// No description provided for @tradeSubmitting.
  ///
  /// In zh, this message translates to:
  /// **'提交中'**
  String get tradeSubmitting;

  /// No description provided for @tradeQueued.
  ///
  /// In zh, this message translates to:
  /// **'排队中'**
  String get tradeQueued;

  /// No description provided for @tradePartiallyFilled.
  ///
  /// In zh, this message translates to:
  /// **'部分成交'**
  String get tradePartiallyFilled;

  /// No description provided for @tradeFilled.
  ///
  /// In zh, this message translates to:
  /// **'已成交'**
  String get tradeFilled;

  /// No description provided for @tradeRejected.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝'**
  String get tradeRejected;

  /// No description provided for @tradeCanceled.
  ///
  /// In zh, this message translates to:
  /// **'已撤单'**
  String get tradeCanceled;

  /// No description provided for @tradePendingCancel.
  ///
  /// In zh, this message translates to:
  /// **'撤单中'**
  String get tradePendingCancel;

  /// No description provided for @tradePricesShownAreDemo.
  ///
  /// In zh, this message translates to:
  /// **'显示价格为演示行情，实际成交以券商（DriveWealth）返回为准'**
  String get tradePricesShownAreDemo;

  /// No description provided for @tradePleaseEnterALimit.
  ///
  /// In zh, this message translates to:
  /// **'请输入限价'**
  String get tradePleaseEnterALimit;

  /// No description provided for @tradeLimitPriceMustBe.
  ///
  /// In zh, this message translates to:
  /// **'限价须大于 0（\$1 以上最多两位小数）'**
  String get tradeLimitPriceMustBe;

  /// No description provided for @tradeAmountOnHoldExceeds.
  ///
  /// In zh, this message translates to:
  /// **'冻结金额 {v0} 超过可用资金 {v1}'**
  String tradeAmountOnHoldExceeds(Object v0, Object v1);

  /// No description provided for @tradeWorking.
  ///
  /// In zh, this message translates to:
  /// **'挂单中'**
  String get tradeWorking;

  /// No description provided for @tradePaperTradingOrdersFill.
  ///
  /// In zh, this message translates to:
  /// **'模拟盘：按演示行情撮合（市价买入按卖一价、卖出按买一价），使用虚拟资金，不产生真实交易'**
  String get tradePaperTradingOrdersFill;

  /// No description provided for @paperPaperTradingVirtualFunds.
  ///
  /// In zh, this message translates to:
  /// **'模拟盘 · 虚拟资金，按演示行情撮合，不产生真实交易'**
  String get paperPaperTradingVirtualFunds;

  /// No description provided for @paperPaper.
  ///
  /// In zh, this message translates to:
  /// **'模拟盘'**
  String get paperPaper;

  /// No description provided for @paperPaperAccountTotalValue.
  ///
  /// In zh, this message translates to:
  /// **'模拟账户总资产'**
  String get paperPaperAccountTotalValue;

  /// No description provided for @paperReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get paperReset;

  /// No description provided for @paperPaperPL.
  ///
  /// In zh, this message translates to:
  /// **'模拟盈亏 ••••'**
  String get paperPaperPL;

  /// No description provided for @paperAvailableFunds.
  ///
  /// In zh, this message translates to:
  /// **'可用资金'**
  String get paperAvailableFunds;

  /// No description provided for @paperOnHoldForOrders.
  ///
  /// In zh, this message translates to:
  /// **'挂单冻结'**
  String get paperOnHoldForOrders;

  /// No description provided for @paperStartingBalance.
  ///
  /// In zh, this message translates to:
  /// **'初始资金'**
  String get paperStartingBalance;

  /// No description provided for @paperResetPaperAccount.
  ///
  /// In zh, this message translates to:
  /// **'重置模拟账户？'**
  String get paperResetPaperAccount;

  /// No description provided for @paperYourVirtualFundsWill.
  ///
  /// In zh, this message translates to:
  /// **'模拟资金将恢复为初始金额，模拟持仓与订单全部清空。此操作只影响模拟盘，不影响实盘账户。'**
  String get paperYourVirtualFundsWill;

  /// No description provided for @ordersCancelOrder.
  ///
  /// In zh, this message translates to:
  /// **'撤销订单？'**
  String get ordersCancelOrder;

  /// No description provided for @ordersCancelingReleasesTheVirtual.
  ///
  /// In zh, this message translates to:
  /// **'{v0} {symbol} {v2}。撤单后释放冻结的模拟资金 / 股数。'**
  String ordersCancelingReleasesTheVirtual(Object v0, Object symbol, Object v2);

  /// No description provided for @ordersTheCancellationResultIs.
  ///
  /// In zh, this message translates to:
  /// **'{v0} {symbol} {v2}。撤单结果以券商返回为准，已成交部分不会撤销。'**
  String ordersTheCancellationResultIs(Object v0, Object symbol, Object v2);

  /// No description provided for @ordersKeepOrder.
  ///
  /// In zh, this message translates to:
  /// **'再想想'**
  String get ordersKeepOrder;

  /// No description provided for @ordersCancelOrder2.
  ///
  /// In zh, this message translates to:
  /// **'撤单'**
  String get ordersCancelOrder2;

  /// No description provided for @ordersOrderCanceled.
  ///
  /// In zh, this message translates to:
  /// **'订单已撤销'**
  String get ordersOrderCanceled;

  /// No description provided for @ordersCancelRequestSubmittedWaiting.
  ///
  /// In zh, this message translates to:
  /// **'撤单已提交，等待券商确认'**
  String get ordersCancelRequestSubmittedWaiting;

  /// No description provided for @ordersShares.
  ///
  /// In zh, this message translates to:
  /// **'{v0} 股'**
  String ordersShares(Object v0);

  /// No description provided for @ordersNoOrdersYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无订单'**
  String get ordersNoOrdersYet;

  /// No description provided for @ordersYouCanPlaceOrders.
  ///
  /// In zh, this message translates to:
  /// **'交易账户开立后即可下单。'**
  String get ordersYouCanPlaceOrders;

  /// No description provided for @ordersBackToAssets.
  ///
  /// In zh, this message translates to:
  /// **'返回资产页'**
  String get ordersBackToAssets;

  /// No description provided for @ordersOpen.
  ///
  /// In zh, this message translates to:
  /// **'未完成'**
  String get ordersOpen;

  /// No description provided for @ordersClosed.
  ///
  /// In zh, this message translates to:
  /// **'已结束'**
  String get ordersClosed;

  /// No description provided for @ordersNoOrdersYetTap.
  ///
  /// In zh, this message translates to:
  /// **'暂无订单。在个股页点击\"买入\"或\"卖出\"即可下单。'**
  String get ordersNoOrdersYetTap;

  /// No description provided for @ordersPaperOrdersAreFilled.
  ///
  /// In zh, this message translates to:
  /// **'模拟订单按演示行情撮合，不产生真实交易。'**
  String get ordersPaperOrdersAreFilled;

  /// No description provided for @ordersOrderStatusFilledQuantity.
  ///
  /// In zh, this message translates to:
  /// **'订单状态、成交数量与成交价均以券商（DriveWealth）返回为准。'**
  String get ordersOrderStatusFilledQuantity;

  /// No description provided for @ordersOrder.
  ///
  /// In zh, this message translates to:
  /// **'委托'**
  String get ordersOrder;

  /// No description provided for @ordersLimitDay.
  ///
  /// In zh, this message translates to:
  /// **'限价 {v0} · {v1} · 当日有效'**
  String ordersLimitDay(Object v0, Object v1);

  /// No description provided for @ordersMarket.
  ///
  /// In zh, this message translates to:
  /// **'市价单 · {v0}'**
  String ordersMarket(Object v0);

  /// No description provided for @ordersAvgFillPrice.
  ///
  /// In zh, this message translates to:
  /// **'成交均价'**
  String get ordersAvgFillPrice;

  /// No description provided for @ordersFilledAmount.
  ///
  /// In zh, this message translates to:
  /// **'成交金额'**
  String get ordersFilledAmount;

  /// No description provided for @ordersFees.
  ///
  /// In zh, this message translates to:
  /// **'费用'**
  String get ordersFees;

  /// No description provided for @ordersSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'提交时间'**
  String get ordersSubmitted;

  /// No description provided for @ordersCompleted.
  ///
  /// In zh, this message translates to:
  /// **'完成时间'**
  String get ordersCompleted;

  /// No description provided for @ordersOrderNo.
  ///
  /// In zh, this message translates to:
  /// **'订单号'**
  String get ordersOrderNo;

  /// No description provided for @ordersTheBrokerHasnT.
  ///
  /// In zh, this message translates to:
  /// **'券商受理结果暂未确认，我们会自动核对，请勿重复下单。'**
  String get ordersTheBrokerHasnT;

  /// No description provided for @positionsNoPositionsYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无持仓'**
  String get positionsNoPositionsYet;

  /// No description provided for @positionsYouCanBuyStocks.
  ///
  /// In zh, this message translates to:
  /// **'交易账户开立后即可买入股票。'**
  String get positionsYouCanBuyStocks;

  /// No description provided for @positionsNoPositionsYet2.
  ///
  /// In zh, this message translates to:
  /// **'还没有持仓。'**
  String get positionsNoPositionsYet2;

  /// No description provided for @positionsPickAStockOn.
  ///
  /// In zh, this message translates to:
  /// **'在市场页选择股票，点击\"买入\"即可下单。'**
  String get positionsPickAStockOn;

  /// No description provided for @positionsPaperPositionsAreValued.
  ///
  /// In zh, this message translates to:
  /// **'模拟持仓按演示行情估值，不代表真实资产。'**
  String get positionsPaperPositionsAreValued;

  /// No description provided for @positionsPaperPositionsValue.
  ///
  /// In zh, this message translates to:
  /// **'模拟持仓市值'**
  String get positionsPaperPositionsValue;

  /// No description provided for @positionsSharesHeld.
  ///
  /// In zh, this message translates to:
  /// **'持有数量'**
  String get positionsSharesHeld;

  /// No description provided for @positionsSellable.
  ///
  /// In zh, this message translates to:
  /// **'可卖数量'**
  String get positionsSellable;

  /// No description provided for @positionsCostBasis.
  ///
  /// In zh, this message translates to:
  /// **'成本'**
  String get positionsCostBasis;

  /// No description provided for @positionsAvgCurrentPrice.
  ///
  /// In zh, this message translates to:
  /// **'均价 / 现价'**
  String get positionsAvgCurrentPrice;

  /// No description provided for @orderSideBuy.
  ///
  /// In zh, this message translates to:
  /// **'买入'**
  String get orderSideBuy;

  /// No description provided for @orderSideSell.
  ///
  /// In zh, this message translates to:
  /// **'卖出'**
  String get orderSideSell;

  /// No description provided for @orderDemoQuote.
  ///
  /// In zh, this message translates to:
  /// **'演示行情'**
  String get orderDemoQuote;

  /// No description provided for @orderLimitHelpBuy.
  ///
  /// In zh, this message translates to:
  /// **'买入：价格不高于限价时成交；当日有效'**
  String get orderLimitHelpBuy;

  /// No description provided for @orderLimitHelpSell.
  ///
  /// In zh, this message translates to:
  /// **'卖出：价格不低于限价时成交；当日有效'**
  String get orderLimitHelpSell;

  /// No description provided for @orderBuyAmountUsd.
  ///
  /// In zh, this message translates to:
  /// **'买入金额 (USD)'**
  String get orderBuyAmountUsd;

  /// No description provided for @orderSellAmountUsd.
  ///
  /// In zh, this message translates to:
  /// **'卖出金额 (USD)'**
  String get orderSellAmountUsd;

  /// No description provided for @orderBuyShares.
  ///
  /// In zh, this message translates to:
  /// **'买入股数'**
  String get orderBuyShares;

  /// No description provided for @orderSellShares.
  ///
  /// In zh, this message translates to:
  /// **'卖出股数'**
  String get orderSellShares;

  /// No description provided for @orderYourAccountIsCurrently.
  ///
  /// In zh, this message translates to:
  /// **'账户当前受限，暂不能交易。如有疑问请联系客服。'**
  String get orderYourAccountIsCurrently;

  /// No description provided for @orderYourAccountIsFrozen.
  ///
  /// In zh, this message translates to:
  /// **'账户已冻结，暂不能交易。资产仍安全托管，请联系客服了解原因。'**
  String get orderYourAccountIsFrozen;

  /// No description provided for @orderYourAccountIsClosed.
  ///
  /// In zh, this message translates to:
  /// **'账户已关闭，不能交易。'**
  String get orderYourAccountIsClosed;

  /// No description provided for @orderYourAccountIsCurrently2.
  ///
  /// In zh, this message translates to:
  /// **'账户当前仅可卖出，暂不能买入。'**
  String get orderYourAccountIsCurrently2;

  /// No description provided for @orderOrderAmount.
  ///
  /// In zh, this message translates to:
  /// **'委托金额'**
  String get orderOrderAmount;

  /// No description provided for @orderOrderQuantity.
  ///
  /// In zh, this message translates to:
  /// **'委托股数'**
  String get orderOrderQuantity;

  /// No description provided for @orderShares.
  ///
  /// In zh, this message translates to:
  /// **'约 {v0} 股'**
  String orderShares(Object v0);

  /// No description provided for @orderText.
  ///
  /// In zh, this message translates to:
  /// **'约 {v0}'**
  String orderText(Object v0);

  /// No description provided for @orderEstimatedAmountOnHold.
  ///
  /// In zh, this message translates to:
  /// **'预估金额（冻结）'**
  String get orderEstimatedAmountOnHold;

  /// No description provided for @orderEstimatedAmount.
  ///
  /// In zh, this message translates to:
  /// **'预估金额'**
  String get orderEstimatedAmount;

  /// No description provided for @orderEstimatedShares.
  ///
  /// In zh, this message translates to:
  /// **'预估股数'**
  String get orderEstimatedShares;

  /// No description provided for @orderLimitOrderDay.
  ///
  /// In zh, this message translates to:
  /// **'限价单 · 当日有效'**
  String get orderLimitOrderDay;

  /// No description provided for @orderMarketOrder.
  ///
  /// In zh, this message translates to:
  /// **'市价单'**
  String get orderMarketOrder;

  /// No description provided for @orderOpenAnAccountTo.
  ///
  /// In zh, this message translates to:
  /// **'开户后即可交易'**
  String get orderOpenAnAccountTo;

  /// No description provided for @orderYouCanPlaceOrders.
  ///
  /// In zh, this message translates to:
  /// **'交易账户开立后才能下单。请先完成开户，或切换到模拟盘练习。'**
  String get orderYouCanPlaceOrders;

  /// No description provided for @orderSwitchToPaperTrading.
  ///
  /// In zh, this message translates to:
  /// **'切换到模拟盘'**
  String get orderSwitchToPaperTrading;

  /// No description provided for @orderMarket.
  ///
  /// In zh, this message translates to:
  /// **'市价'**
  String get orderMarket;

  /// No description provided for @orderLimit.
  ///
  /// In zh, this message translates to:
  /// **'限价'**
  String get orderLimit;

  /// No description provided for @orderByAmount.
  ///
  /// In zh, this message translates to:
  /// **'按金额'**
  String get orderByAmount;

  /// No description provided for @orderByShares.
  ///
  /// In zh, this message translates to:
  /// **'按股数'**
  String get orderByShares;

  /// No description provided for @orderLimitPriceUsd.
  ///
  /// In zh, this message translates to:
  /// **'限价 (USD)'**
  String get orderLimitPriceUsd;

  /// No description provided for @orderFractionalSharesSupported.
  ///
  /// In zh, this message translates to:
  /// **'支持碎股；{minOrderText}'**
  String orderFractionalSharesSupported(Object minOrderText);

  /// No description provided for @orderFractionalSharesSupportedUp.
  ///
  /// In zh, this message translates to:
  /// **'支持小数股，最多 6 位小数'**
  String get orderFractionalSharesSupportedUp;

  /// No description provided for @orderSellAllShares.
  ///
  /// In zh, this message translates to:
  /// **'全部卖出（{v0} 股）'**
  String orderSellAllShares(Object v0);

  /// No description provided for @orderOrderType.
  ///
  /// In zh, this message translates to:
  /// **'订单类型'**
  String get orderOrderType;

  /// No description provided for @orderReferencePriceDemoQuote.
  ///
  /// In zh, this message translates to:
  /// **'参考价（演示行情）'**
  String get orderReferencePriceDemoQuote;

  /// No description provided for @orderPaperAvailableFunds.
  ///
  /// In zh, this message translates to:
  /// **'模拟可用资金'**
  String get orderPaperAvailableFunds;

  /// No description provided for @orderBuyingPower.
  ///
  /// In zh, this message translates to:
  /// **'可用购买力'**
  String get orderBuyingPower;

  /// No description provided for @orderPaperLimitOrderFills.
  ///
  /// In zh, this message translates to:
  /// **'模拟限价单：演示行情到达限价时自动成交，未成交前冻结资金 / 股数，当日有效。'**
  String get orderPaperLimitOrderFills;

  /// No description provided for @orderPaperMarketOrdersFill.
  ///
  /// In zh, this message translates to:
  /// **'模拟市价单按演示行情即时成交（买入按卖一价、卖出按买一价）。'**
  String get orderPaperMarketOrdersFill;

  /// No description provided for @orderYourCurrentBuyingPower.
  ///
  /// In zh, this message translates to:
  /// **'当前可用购买力为 \$0.00。入金结算后才计入购买力，日期以资金记录中券商返回的为准。'**
  String get orderYourCurrentBuyingPower;

  /// No description provided for @orderLimitOrdersAreGood.
  ///
  /// In zh, this message translates to:
  /// **'限价单当日有效，价格到达限价才可能成交，未成交部分收盘后自动撤销，状态以券商返回为准。'**
  String get orderLimitOrdersAreGood;

  /// No description provided for @orderMarketOrdersFillAt.
  ///
  /// In zh, this message translates to:
  /// **'市价单按券商实际成交价成交。本期不区分盘前盘后，休市时提交的订单可能排队至开盘，状态以券商返回为准。'**
  String get orderMarketOrdersFillAt;

  /// No description provided for @orderNext.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get orderNext;

  /// No description provided for @orderReviewOrder.
  ///
  /// In zh, this message translates to:
  /// **'确认订单'**
  String get orderReviewOrder;

  /// No description provided for @orderPaperVirtualFunds.
  ///
  /// In zh, this message translates to:
  /// **'模拟盘（虚拟资金）'**
  String get orderPaperVirtualFunds;

  /// No description provided for @orderLiveDrivewealth.
  ///
  /// In zh, this message translates to:
  /// **'实盘（DriveWealth）'**
  String get orderLiveDrivewealth;

  /// No description provided for @orderSide.
  ///
  /// In zh, this message translates to:
  /// **'方向'**
  String get orderSide;

  /// No description provided for @orderLimitPrice.
  ///
  /// In zh, this message translates to:
  /// **'限价'**
  String get orderLimitPrice;

  /// No description provided for @orderCustodian.
  ///
  /// In zh, this message translates to:
  /// **'托管券商'**
  String get orderCustodian;

  /// No description provided for @orderEditOrder.
  ///
  /// In zh, this message translates to:
  /// **'返回修改'**
  String get orderEditOrder;

  /// No description provided for @orderConfirmBuy.
  ///
  /// In zh, this message translates to:
  /// **'确认买入'**
  String get orderConfirmBuy;

  /// No description provided for @orderConfirmSell.
  ///
  /// In zh, this message translates to:
  /// **'确认卖出'**
  String get orderConfirmSell;

  /// No description provided for @orderOrderRecorded.
  ///
  /// In zh, this message translates to:
  /// **'订单已记录'**
  String get orderOrderRecorded;

  /// No description provided for @orderPaperOrderFilled.
  ///
  /// In zh, this message translates to:
  /// **'模拟订单已成交'**
  String get orderPaperOrderFilled;

  /// No description provided for @orderOrderFilled.
  ///
  /// In zh, this message translates to:
  /// **'订单已成交'**
  String get orderOrderFilled;

  /// No description provided for @orderOrderRejectedByThe.
  ///
  /// In zh, this message translates to:
  /// **'券商已拒绝该订单'**
  String get orderOrderRejectedByThe;

  /// No description provided for @orderPaperLimitOrderPlaced.
  ///
  /// In zh, this message translates to:
  /// **'模拟限价单已挂单'**
  String get orderPaperLimitOrderPlaced;

  /// No description provided for @orderLimitOrderSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'限价单已提交'**
  String get orderLimitOrderSubmitted;

  /// No description provided for @orderOrderSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'订单已提交'**
  String get orderOrderSubmitted;

  /// No description provided for @orderTheBrokerHasnT.
  ///
  /// In zh, this message translates to:
  /// **'券商受理结果暂未确认，我们会自动核对，请稍后在订单列表中查看状态。请勿重复提交。'**
  String get orderTheBrokerHasnT;

  /// No description provided for @orderSimulatedFillAtDemo.
  ///
  /// In zh, this message translates to:
  /// **'按演示行情模拟成交，使用虚拟资金，不产生真实交易。'**
  String get orderSimulatedFillAtDemo;

  /// No description provided for @orderFillPriceAndQuantity.
  ///
  /// In zh, this message translates to:
  /// **'成交价与数量以券商返回为准。'**
  String get orderFillPriceAndQuantity;

  /// No description provided for @orderTheBrokerRejectedThis.
  ///
  /// In zh, this message translates to:
  /// **'券商已拒绝该订单，请稍后重试或联系客服。'**
  String get orderTheBrokerRejectedThis;

  /// No description provided for @orderFillsAutomaticallyWhenThe.
  ///
  /// In zh, this message translates to:
  /// **'演示行情到达限价时自动成交；未成交前冻结资金 / 股数，可在模拟订单中撤单。当日有效。'**
  String get orderFillsAutomaticallyWhenThe;

  /// No description provided for @orderMayFillOnlyWhen.
  ///
  /// In zh, this message translates to:
  /// **'价格到达限价才可能成交，当日有效，可在订单列表中撤单。状态以券商返回为准。'**
  String get orderMayFillOnlyWhen;

  /// No description provided for @orderYourOrderHasBeen.
  ///
  /// In zh, this message translates to:
  /// **'订单已发送至券商，成交后状态会在订单列表中更新。休市期间提交的订单可能排队至开盘。'**
  String get orderYourOrderHasBeen;

  /// No description provided for @orderOrderResult.
  ///
  /// In zh, this message translates to:
  /// **'下单结果'**
  String get orderOrderResult;

  /// No description provided for @orderStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get orderStatus;

  /// No description provided for @orderFilledQuantity.
  ///
  /// In zh, this message translates to:
  /// **'成交数量'**
  String get orderFilledQuantity;

  /// No description provided for @orderViewPaperOrders.
  ///
  /// In zh, this message translates to:
  /// **'查看模拟订单'**
  String get orderViewPaperOrders;

  /// No description provided for @orderViewOrders.
  ///
  /// In zh, this message translates to:
  /// **'查看订单'**
  String get orderViewOrders;

  /// No description provided for @orderDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get orderDone;
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
