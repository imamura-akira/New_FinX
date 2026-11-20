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
