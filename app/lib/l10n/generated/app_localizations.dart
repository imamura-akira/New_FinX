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
  /// **'自选'**
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

  /// No description provided for @fundAchFee.
  ///
  /// In zh, this message translates to:
  /// **'\$0.25（DW 文档，待 DW 确认）'**
  String get fundAchFee;

  /// No description provided for @bankSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{type} · 户名 {owner} · 绑定于 {date}'**
  String bankSubtitle(Object type, Object owner, Object date);

  /// No description provided for @transferTitleDeposit.
  ///
  /// In zh, this message translates to:
  /// **'{method} 入金'**
  String transferTitleDeposit(Object method);

  /// No description provided for @transferTitleWithdrawal.
  ///
  /// In zh, this message translates to:
  /// **'{method} 出金'**
  String transferTitleWithdrawal(Object method);

  /// No description provided for @transferDetailDeposit.
  ///
  /// In zh, this message translates to:
  /// **'{method} 入金详情'**
  String transferDetailDeposit(Object method);

  /// No description provided for @transferDetailWithdrawal.
  ///
  /// In zh, this message translates to:
  /// **'{method} 出金详情'**
  String transferDetailWithdrawal(Object method);

  /// No description provided for @bankTypeOwner.
  ///
  /// In zh, this message translates to:
  /// **'{type} · 户名 {owner}'**
  String bankTypeOwner(Object type, Object owner);

  /// No description provided for @fundPleaseEnterADeposit.
  ///
  /// In zh, this message translates to:
  /// **'请输入入金金额'**
  String get fundPleaseEnterADeposit;

  /// No description provided for @fundMinimumDepositIs.
  ///
  /// In zh, this message translates to:
  /// **'单笔最低入金 {v0}'**
  String fundMinimumDepositIs(Object v0);

  /// No description provided for @fundMaximumDepositIs.
  ///
  /// In zh, this message translates to:
  /// **'单笔最高入金 {v0}'**
  String fundMaximumDepositIs(Object v0);

  /// No description provided for @fundPleaseEnterAWithdrawal.
  ///
  /// In zh, this message translates to:
  /// **'请输入出金金额'**
  String get fundPleaseEnterAWithdrawal;

  /// No description provided for @fundMinimumWithdrawalIs.
  ///
  /// In zh, this message translates to:
  /// **'单笔最低出金 {v0}'**
  String fundMinimumWithdrawalIs(Object v0);

  /// No description provided for @fundExceedsYourAvailableTo.
  ///
  /// In zh, this message translates to:
  /// **'超过可提现金额 {v0}'**
  String fundExceedsYourAvailableTo(Object v0);

  /// No description provided for @fundMaximumWithdrawalIs.
  ///
  /// In zh, this message translates to:
  /// **'单笔最高出金 {v0}'**
  String fundMaximumWithdrawalIs(Object v0);

  /// No description provided for @fundInitiated.
  ///
  /// In zh, this message translates to:
  /// **'已发起'**
  String get fundInitiated;

  /// No description provided for @fundPending.
  ///
  /// In zh, this message translates to:
  /// **'处理中'**
  String get fundPending;

  /// No description provided for @fundProcessing.
  ///
  /// In zh, this message translates to:
  /// **'处理中'**
  String get fundProcessing;

  /// No description provided for @fundApproved.
  ///
  /// In zh, this message translates to:
  /// **'已批准'**
  String get fundApproved;

  /// No description provided for @fundCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get fundCompleted;

  /// No description provided for @fundFailed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get fundFailed;

  /// No description provided for @fundReturned.
  ///
  /// In zh, this message translates to:
  /// **'已退回'**
  String get fundReturned;

  /// No description provided for @fundOnHold.
  ///
  /// In zh, this message translates to:
  /// **'暂缓处理'**
  String get fundOnHold;

  /// No description provided for @fundBuyingPowerIsGranted.
  ///
  /// In zh, this message translates to:
  /// **'结算后授予购买力，通常 4–5 个工作日（待 DW 确认）'**
  String get fundBuyingPowerIsGranted;

  /// No description provided for @fundUsually45Business.
  ///
  /// In zh, this message translates to:
  /// **'通常 4–5 个工作日（待 DW 确认）'**
  String get fundUsually45Business;

  /// No description provided for @fundBankAccount.
  ///
  /// In zh, this message translates to:
  /// **'银行账户'**
  String get fundBankAccount;

  /// No description provided for @fundSavings.
  ///
  /// In zh, this message translates to:
  /// **'储蓄账户'**
  String get fundSavings;

  /// No description provided for @fundChecking.
  ///
  /// In zh, this message translates to:
  /// **'支票账户'**
  String get fundChecking;

  /// No description provided for @bankYourAccountIsCurrently.
  ///
  /// In zh, this message translates to:
  /// **'账户当前受限，暂不能进行资金操作。如有疑问请联系客服。'**
  String get bankYourAccountIsCurrently;

  /// No description provided for @bankUnlinkBankAccount.
  ///
  /// In zh, this message translates to:
  /// **'解绑银行账户？'**
  String get bankUnlinkBankAccount;

  /// No description provided for @bankOnceUnlinkedCanNo.
  ///
  /// In zh, this message translates to:
  /// **'{displayName} 解绑后不能再用于入金和出金。'**
  String bankOnceUnlinkedCanNo(Object displayName);

  /// No description provided for @bankUnlink.
  ///
  /// In zh, this message translates to:
  /// **'解绑'**
  String get bankUnlink;

  /// No description provided for @bankUnlinked.
  ///
  /// In zh, this message translates to:
  /// **'已解绑'**
  String get bankUnlinked;

  /// No description provided for @bankLinked.
  ///
  /// In zh, this message translates to:
  /// **'已绑定（{length}/{maxBanks}）'**
  String bankLinked(Object length, Object maxBanks);

  /// No description provided for @bankNoBankAccountsLinked.
  ///
  /// In zh, this message translates to:
  /// **'还没有绑定银行账户。绑定本人名下的美国银行账户后，即可通过 ACH 入金和出金。'**
  String get bankNoBankAccountsLinked;

  /// No description provided for @bankYouCanLinkUp.
  ///
  /// In zh, this message translates to:
  /// **'每个账户最多绑定 {maxBanks} 个银行账户。如需更换，请先解绑。'**
  String bankYouCanLinkUp(Object maxBanks);

  /// No description provided for @bankYouCanOnlyLink.
  ///
  /// In zh, this message translates to:
  /// **'只能绑定本人名下的美国银行账户。没有美国银行账户？可以改用电汇入金。'**
  String get bankYouCanOnlyLink;

  /// No description provided for @bankViewWireInstructions.
  ///
  /// In zh, this message translates to:
  /// **'查看电汇入金信息'**
  String get bankViewWireInstructions;

  /// No description provided for @bankLinkANewBank.
  ///
  /// In zh, this message translates to:
  /// **'绑定新银行账户'**
  String get bankLinkANewBank;

  /// No description provided for @bankEnterAValid9.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 9 位 ABA 路由号码'**
  String get bankEnterAValid9;

  /// No description provided for @bankEnterA417.
  ///
  /// In zh, this message translates to:
  /// **'请输入 4–17 位银行账号'**
  String get bankEnterA417;

  /// No description provided for @bankNicknameCanBeUp.
  ///
  /// In zh, this message translates to:
  /// **'备注名最多 30 个字'**
  String get bankNicknameCanBeUp;

  /// No description provided for @bankNicknameCanTBe.
  ///
  /// In zh, this message translates to:
  /// **'备注名不能与账号相同'**
  String get bankNicknameCanTBe;

  /// No description provided for @bankBankAccountLinked.
  ///
  /// In zh, this message translates to:
  /// **'银行账户绑定成功'**
  String get bankBankAccountLinked;

  /// No description provided for @bankLinkBankAccount.
  ///
  /// In zh, this message translates to:
  /// **'绑定银行账户'**
  String get bankLinkBankAccount;

  /// No description provided for @bankAccountsInYourOwn.
  ///
  /// In zh, this message translates to:
  /// **'只能绑定本人名下的账户'**
  String get bankAccountsInYourOwn;

  /// No description provided for @bankTheAccountHolderIs.
  ///
  /// In zh, this message translates to:
  /// **'户名按开户姓名登记，第三方账户的转账会被退回'**
  String get bankTheAccountHolderIs;

  /// No description provided for @bankUsBankAccountsOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅支持美国银行账户'**
  String get bankUsBankAccountsOnly;

  /// No description provided for @bankNoUsBankAccount.
  ///
  /// In zh, this message translates to:
  /// **'没有美国银行账户？请改用电汇'**
  String get bankNoUsBankAccount;

  /// No description provided for @bankAccountNumberEncryptedIn.
  ///
  /// In zh, this message translates to:
  /// **'账号加密传输'**
  String get bankAccountNumberEncryptedIn;

  /// No description provided for @bankWeOnlyShowThe.
  ///
  /// In zh, this message translates to:
  /// **'我们只显示账号尾号'**
  String get bankWeOnlyShowThe;

  /// No description provided for @bankRoutingNumberAba.
  ///
  /// In zh, this message translates to:
  /// **'路由号码（ABA Routing Number）'**
  String get bankRoutingNumberAba;

  /// No description provided for @bank9Digits.
  ///
  /// In zh, this message translates to:
  /// **'9 位数字'**
  String get bank9Digits;

  /// No description provided for @bankAccountNumber.
  ///
  /// In zh, this message translates to:
  /// **'银行账号'**
  String get bankAccountNumber;

  /// No description provided for @bank417Digits.
  ///
  /// In zh, this message translates to:
  /// **'4–17 位数字'**
  String get bank417Digits;

  /// No description provided for @bankAccountType.
  ///
  /// In zh, this message translates to:
  /// **'账户类型'**
  String get bankAccountType;

  /// No description provided for @bankNicknameOptional.
  ///
  /// In zh, this message translates to:
  /// **'备注名（选填）'**
  String get bankNicknameOptional;

  /// No description provided for @bankEGPaycheckAccount.
  ///
  /// In zh, this message translates to:
  /// **'如：工资卡'**
  String get bankEGPaycheckAccount;

  /// No description provided for @bankLink.
  ///
  /// In zh, this message translates to:
  /// **'绑定'**
  String get bankLink;

  /// No description provided for @bankBeneficiary.
  ///
  /// In zh, this message translates to:
  /// **'收款人'**
  String get bankBeneficiary;

  /// No description provided for @bankBeneficiaryBank.
  ///
  /// In zh, this message translates to:
  /// **'收款银行'**
  String get bankBeneficiaryBank;

  /// No description provided for @bankBankAddress.
  ///
  /// In zh, this message translates to:
  /// **'银行地址'**
  String get bankBankAddress;

  /// No description provided for @bankAccountNumber2.
  ///
  /// In zh, this message translates to:
  /// **'收款账号'**
  String get bankAccountNumber2;

  /// No description provided for @bankAbaRoutingNumber.
  ///
  /// In zh, this message translates to:
  /// **'ABA 路由号码'**
  String get bankAbaRoutingNumber;

  /// No description provided for @bankReferenceRequired.
  ///
  /// In zh, this message translates to:
  /// **'附言（必填）'**
  String get bankReferenceRequired;

  /// No description provided for @bankWireDeposit.
  ///
  /// In zh, this message translates to:
  /// **'电汇入金'**
  String get bankWireDeposit;

  /// No description provided for @bankSendTheWireFrom.
  ///
  /// In zh, this message translates to:
  /// **'请从本人名下的银行账户汇款，并在附言中填写下方内容（含您的账户号码），否则可能无法入账。'**
  String get bankSendTheWireFrom;

  /// No description provided for @bankCopied.
  ///
  /// In zh, this message translates to:
  /// **'{value}已复制'**
  String bankCopied(Object value);

  /// No description provided for @bankIntermediaryBankFeesAre.
  ///
  /// In zh, this message translates to:
  /// **'中转行费用由汇款方承担；到账时间以银行实际到账为准（待 DW 确认）。电汇入金不受 ACH 观察期限制。'**
  String get bankIntermediaryBankFeesAre;

  /// No description provided for @xferTransactionId.
  ///
  /// In zh, this message translates to:
  /// **'流水号'**
  String get xferTransactionId;

  /// No description provided for @xferMethod.
  ///
  /// In zh, this message translates to:
  /// **'方式'**
  String get xferMethod;

  /// No description provided for @xferAmount.
  ///
  /// In zh, this message translates to:
  /// **'金额'**
  String get xferAmount;

  /// No description provided for @xferViewTransferHistory.
  ///
  /// In zh, this message translates to:
  /// **'查看资金记录'**
  String get xferViewTransferHistory;

  /// No description provided for @xferDepositRecorded.
  ///
  /// In zh, this message translates to:
  /// **'入金已记录'**
  String get xferDepositRecorded;

  /// No description provided for @xferDepositSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'入金已提交'**
  String get xferDepositSubmitted;

  /// No description provided for @xferTheBrokerHasnT.
  ///
  /// In zh, this message translates to:
  /// **'券商受理结果暂未确认，我们会自动核对，请稍后在资金记录中查看状态。请勿重复提交。'**
  String get xferTheBrokerHasnT;

  /// No description provided for @xferTheArrivalDateIs.
  ///
  /// In zh, this message translates to:
  /// **'{buyingPowerFallback}。到账日期以资金记录中券商返回的日期为准。'**
  String xferTheArrivalDateIs(Object buyingPowerFallback);

  /// No description provided for @xferChooseADepositMethod.
  ///
  /// In zh, this message translates to:
  /// **'选择入金方式'**
  String get xferChooseADepositMethod;

  /// No description provided for @xferBankTransferAch.
  ///
  /// In zh, this message translates to:
  /// **'银行转账（ACH）'**
  String get xferBankTransferAch;

  /// No description provided for @xferLinkAUsBank.
  ///
  /// In zh, this message translates to:
  /// **'需先绑定本人名下的美国银行账户'**
  String get xferLinkAUsBank;

  /// No description provided for @xferUsBankAccountS.
  ///
  /// In zh, this message translates to:
  /// **'已绑定 {length} 个本人美国银行账户 · 免手续费'**
  String xferUsBankAccountS(Object length);

  /// No description provided for @xferWireTransfer.
  ///
  /// In zh, this message translates to:
  /// **'电汇'**
  String get xferWireTransfer;

  /// No description provided for @xferSendFromABank.
  ///
  /// In zh, this message translates to:
  /// **'从本人名下银行账户汇款，适用于境外银行或大额入金'**
  String get xferSendFromABank;

  /// No description provided for @xferWireTimingDependsOn.
  ///
  /// In zh, this message translates to:
  /// **'{buyingPowerFallback}。{seasoningFallback}。电汇以银行实际到账时间为准，不受观察期限制。每笔入金的实际日期以券商返回为准（见资金记录）。'**
  String xferWireTimingDependsOn(
    Object buyingPowerFallback,
    Object seasoningFallback,
  );

  /// No description provided for @xferWeOnlyAcceptFunds.
  ///
  /// In zh, this message translates to:
  /// **'只接受来自本人名下账户的资金，第三方转账将被退回。'**
  String get xferWeOnlyAcceptFunds;

  /// No description provided for @xferConfirmDeposit.
  ///
  /// In zh, this message translates to:
  /// **'确认入金'**
  String get xferConfirmDeposit;

  /// No description provided for @xferDepositAmount.
  ///
  /// In zh, this message translates to:
  /// **'入金金额'**
  String get xferDepositAmount;

  /// No description provided for @xferFrom.
  ///
  /// In zh, this message translates to:
  /// **'从'**
  String get xferFrom;

  /// No description provided for @xferTo.
  ///
  /// In zh, this message translates to:
  /// **'到'**
  String get xferTo;

  /// No description provided for @xferYourBrokerageAccountHeld.
  ///
  /// In zh, this message translates to:
  /// **'本人证券账户（DriveWealth 托管）'**
  String get xferYourBrokerageAccountHeld;

  /// No description provided for @xferFee.
  ///
  /// In zh, this message translates to:
  /// **'手续费'**
  String get xferFee;

  /// No description provided for @xferBuyingPowerAvailable.
  ///
  /// In zh, this message translates to:
  /// **'购买力到账'**
  String get xferBuyingPowerAvailable;

  /// No description provided for @xferByConfirmingYouAuthorize.
  ///
  /// In zh, this message translates to:
  /// **'确认即授权从上述银行账户扣款。资金由 DriveWealth 托管。'**
  String get xferByConfirmingYouAuthorize;

  /// No description provided for @xferEdit.
  ///
  /// In zh, this message translates to:
  /// **'返回修改'**
  String get xferEdit;

  /// No description provided for @xferAchDeposit.
  ///
  /// In zh, this message translates to:
  /// **'ACH 入金'**
  String get xferAchDeposit;

  /// No description provided for @xferFromBankAccount.
  ///
  /// In zh, this message translates to:
  /// **'转出银行账户'**
  String get xferFromBankAccount;

  /// No description provided for @xferManageBankAccounts.
  ///
  /// In zh, this message translates to:
  /// **'管理银行账户（{length}/{maxBanks}）'**
  String xferManageBankAccounts(Object length, Object maxBanks);

  /// No description provided for @xferDepositAmountUsd.
  ///
  /// In zh, this message translates to:
  /// **'入金金额 (USD)'**
  String get xferDepositAmountUsd;

  /// No description provided for @xferPerTransferUpTo.
  ///
  /// In zh, this message translates to:
  /// **'单笔 {v0} – {v1}，每日上限 {v2}（示例值，以券商为准）'**
  String xferPerTransferUpTo(Object v0, Object v1, Object v2);

  /// No description provided for @xferSubmissionCutoff.
  ///
  /// In zh, this message translates to:
  /// **'提交截止时间'**
  String get xferSubmissionCutoff;

  /// No description provided for @xferBusinessDaysEtSample.
  ///
  /// In zh, this message translates to:
  /// **'工作日 {achCutoffEt} ET（示例，待 DW 确认）'**
  String xferBusinessDaysEtSample(Object achCutoffEt);

  /// No description provided for @xferWithdrawable.
  ///
  /// In zh, this message translates to:
  /// **'可提现时间'**
  String get xferWithdrawable;

  /// No description provided for @xferReturnNoticeIfYour.
  ///
  /// In zh, this message translates to:
  /// **'退回提示：如银行退回此笔转账（如余额不足），使用该笔资金买入的证券可能被限制卖出，并可能产生退回费用；账户入金功能也可能被暂停。'**
  String get xferReturnNoticeIfYour;

  /// No description provided for @xferWithdrawalRecorded.
  ///
  /// In zh, this message translates to:
  /// **'出金已记录'**
  String get xferWithdrawalRecorded;

  /// No description provided for @xferWithdrawalSubmitted.
  ///
  /// In zh, this message translates to:
  /// **'出金已提交'**
  String get xferWithdrawalSubmitted;

  /// No description provided for @xferAchWithdrawals.
  ///
  /// In zh, this message translates to:
  /// **'ACH 出金{achWithdrawalArrival}。'**
  String xferAchWithdrawals(Object achWithdrawalArrival);

  /// No description provided for @xferConfirmWithdrawal.
  ///
  /// In zh, this message translates to:
  /// **'确认出金'**
  String get xferConfirmWithdrawal;

  /// No description provided for @xferWithdrawalAmount.
  ///
  /// In zh, this message translates to:
  /// **'出金金额'**
  String get xferWithdrawalAmount;

  /// No description provided for @xferYourBrokerageAccount.
  ///
  /// In zh, this message translates to:
  /// **'本人证券账户'**
  String get xferYourBrokerageAccount;

  /// No description provided for @xferEstimatedArrival.
  ///
  /// In zh, this message translates to:
  /// **'预计到账'**
  String get xferEstimatedArrival;

  /// No description provided for @xferAvailableToWithdraw.
  ///
  /// In zh, this message translates to:
  /// **'可提现金额'**
  String get xferAvailableToWithdraw;

  /// No description provided for @xferAccountCash.
  ///
  /// In zh, this message translates to:
  /// **'账户现金'**
  String get xferAccountCash;

  /// No description provided for @xferUnsettledFunds.
  ///
  /// In zh, this message translates to:
  /// **'未结算资金'**
  String get xferUnsettledFunds;

  /// No description provided for @xferInAchHoldingPeriod.
  ///
  /// In zh, this message translates to:
  /// **'ACH 入金观察期内金额'**
  String get xferInAchHoldingPeriod;

  /// No description provided for @xferYourAvailableToWithdraw.
  ///
  /// In zh, this message translates to:
  /// **'可提现金额以券商（DriveWealth）返回为准。{seasoningFallback}；电汇入金不受此限制。'**
  String xferYourAvailableToWithdraw(Object seasoningFallback);

  /// No description provided for @xferWireWithdrawalsArenT.
  ///
  /// In zh, this message translates to:
  /// **'电汇出金暂不在本次演示范围（后端已支持，待沙盒实测后开放）。电汇只能汇入本人名下的银行账户，收款人固定为账户持有人。'**
  String get xferWireWithdrawalsArenT;

  /// No description provided for @xferToBankAccount.
  ///
  /// In zh, this message translates to:
  /// **'收款银行账户'**
  String get xferToBankAccount;

  /// No description provided for @xferNoBankAccountLinked.
  ///
  /// In zh, this message translates to:
  /// **'尚未绑定银行账户。'**
  String get xferNoBankAccountLinked;

  /// No description provided for @xferWithdrawalAmountUsd.
  ///
  /// In zh, this message translates to:
  /// **'出金金额 (USD)'**
  String get xferWithdrawalAmountUsd;

  /// No description provided for @xferPerTransferAndNo.
  ///
  /// In zh, this message translates to:
  /// **'单笔 {v0} – {v1}，且不超过可提现金额'**
  String xferPerTransferAndNo(Object v0, Object v1);

  /// No description provided for @xferTransferHistory.
  ///
  /// In zh, this message translates to:
  /// **'资金记录'**
  String get xferTransferHistory;

  /// No description provided for @xferDeposits.
  ///
  /// In zh, this message translates to:
  /// **'入金'**
  String get xferDeposits;

  /// No description provided for @xferWithdrawals.
  ///
  /// In zh, this message translates to:
  /// **'出金'**
  String get xferWithdrawals;

  /// No description provided for @xferNoTransfersYet.
  ///
  /// In zh, this message translates to:
  /// **'暂无资金记录'**
  String get xferNoTransfersYet;

  /// No description provided for @xferShowingYour50Most.
  ///
  /// In zh, this message translates to:
  /// **'显示最近 50 条资金记录。交易、分红与公司行动记录不在本次演示范围。'**
  String get xferShowingYour50Most;

  /// No description provided for @xferFromAccount.
  ///
  /// In zh, this message translates to:
  /// **'转出账户'**
  String get xferFromAccount;

  /// No description provided for @xferToAccount.
  ///
  /// In zh, this message translates to:
  /// **'收款账户'**
  String get xferToAccount;

  /// No description provided for @xferBuyingPowerAvailable2.
  ///
  /// In zh, this message translates to:
  /// **'购买力可用日'**
  String get xferBuyingPowerAvailable2;

  /// No description provided for @xferPendingBrokerUpdate.
  ///
  /// In zh, this message translates to:
  /// **'待券商返回'**
  String get xferPendingBrokerUpdate;

  /// No description provided for @xferWithdrawableOn.
  ///
  /// In zh, this message translates to:
  /// **'可提现日'**
  String get xferWithdrawableOn;

  /// No description provided for @xferText.
  ///
  /// In zh, this message translates to:
  /// **'{buyingPowerFallback}；{seasoningFallback}。'**
  String xferText(Object buyingPowerFallback, Object seasoningFallback);

  /// No description provided for @xferReason.
  ///
  /// In zh, this message translates to:
  /// **'原因：{failureReason}'**
  String xferReason(Object failureReason);

  /// No description provided for @featureComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'{title}即将上线'**
  String featureComingSoon(Object title);

  /// No description provided for @mastersLastPrice.
  ///
  /// In zh, this message translates to:
  /// **'最新价 {price}'**
  String mastersLastPrice(Object price);

  /// No description provided for @demoNorthshoreCapital.
  ///
  /// In zh, this message translates to:
  /// **'北岸资本'**
  String get demoNorthshoreCapital;

  /// No description provided for @demoNorthshoreCapitalSample.
  ///
  /// In zh, this message translates to:
  /// **'Northshore Capital (示例)'**
  String get demoNorthshoreCapitalSample;

  /// No description provided for @demoLongbridgeFund.
  ///
  /// In zh, this message translates to:
  /// **'长桥基金'**
  String get demoLongbridgeFund;

  /// No description provided for @demoLongbridgeFundSample.
  ///
  /// In zh, this message translates to:
  /// **'Longbridge Fund (示例)'**
  String get demoLongbridgeFundSample;

  /// No description provided for @demoFarhillInvestments.
  ///
  /// In zh, this message translates to:
  /// **'远山投资'**
  String get demoFarhillInvestments;

  /// No description provided for @demoFarhillInvestmentsSample.
  ///
  /// In zh, this message translates to:
  /// **'Farhill Investments (示例)'**
  String get demoFarhillInvestmentsSample;

  /// No description provided for @demoMorningBayAm.
  ///
  /// In zh, this message translates to:
  /// **'晨湾资管'**
  String get demoMorningBayAm;

  /// No description provided for @demoMorningBayAmSample.
  ///
  /// In zh, this message translates to:
  /// **'Morning Bay AM (示例)'**
  String get demoMorningBayAmSample;

  /// No description provided for @demoBluestonePartners.
  ///
  /// In zh, this message translates to:
  /// **'青石合伙'**
  String get demoBluestonePartners;

  /// No description provided for @demoBluestonePartnersSample.
  ///
  /// In zh, this message translates to:
  /// **'Bluestone Partners (示例)'**
  String get demoBluestonePartnersSample;

  /// No description provided for @demoCoastlineValue.
  ///
  /// In zh, this message translates to:
  /// **'海岸价值'**
  String get demoCoastlineValue;

  /// No description provided for @demoCoastlineValueSample.
  ///
  /// In zh, this message translates to:
  /// **'Coastline Value (示例)'**
  String get demoCoastlineValueSample;

  /// No description provided for @demoPinewoodGlobal.
  ///
  /// In zh, this message translates to:
  /// **'松林全球'**
  String get demoPinewoodGlobal;

  /// No description provided for @demoPinewoodGlobalSample.
  ///
  /// In zh, this message translates to:
  /// **'Pinewood Global (示例)'**
  String get demoPinewoodGlobalSample;

  /// No description provided for @demoGalaxyQuant.
  ///
  /// In zh, this message translates to:
  /// **'星河量化'**
  String get demoGalaxyQuant;

  /// No description provided for @demoGalaxyQuantSample.
  ///
  /// In zh, this message translates to:
  /// **'Galaxy Quant (示例)'**
  String get demoGalaxyQuantSample;

  /// No description provided for @demoMostIncreased.
  ///
  /// In zh, this message translates to:
  /// **'增持最多'**
  String get demoMostIncreased;

  /// No description provided for @demoContrarianBuys.
  ///
  /// In zh, this message translates to:
  /// **'逆势增持'**
  String get demoContrarianBuys;

  /// No description provided for @demoMostHeld.
  ///
  /// In zh, this message translates to:
  /// **'持股最多'**
  String get demoMostHeld;

  /// No description provided for @demoNewPositions.
  ///
  /// In zh, this message translates to:
  /// **'新进持股'**
  String get demoNewPositions;

  /// No description provided for @demoPortfolioCheckup.
  ///
  /// In zh, this message translates to:
  /// **'持仓体检'**
  String get demoPortfolioCheckup;

  /// No description provided for @demoAnalyzeYourHoldingsAnd.
  ///
  /// In zh, this message translates to:
  /// **'分析持仓结构与未实现盈亏'**
  String get demoAnalyzeYourHoldingsAnd;

  /// No description provided for @demoHoldOrSell.
  ///
  /// In zh, this message translates to:
  /// **'持有或卖出'**
  String get demoHoldOrSell;

  /// No description provided for @demoCompareTrendsRiskAnd.
  ///
  /// In zh, this message translates to:
  /// **'对比趋势、风险与仓位'**
  String get demoCompareTrendsRiskAnd;

  /// No description provided for @demoStockResearch.
  ///
  /// In zh, this message translates to:
  /// **'个股研究'**
  String get demoStockResearch;

  /// No description provided for @demoPricesFundamentalsAndNews.
  ///
  /// In zh, this message translates to:
  /// **'汇总价格、基本面与新闻'**
  String get demoPricesFundamentalsAndNews;

  /// No description provided for @demoRiskAlerts.
  ///
  /// In zh, this message translates to:
  /// **'风险提醒'**
  String get demoRiskAlerts;

  /// No description provided for @demoSpotVolatilityConcentrationAnd.
  ///
  /// In zh, this message translates to:
  /// **'识别波动、集中度与回撤'**
  String get demoSpotVolatilityConcentrationAnd;

  /// No description provided for @demoQuantSignals.
  ///
  /// In zh, this message translates to:
  /// **'量化信号'**
  String get demoQuantSignals;

  /// No description provided for @demoMomentumReversalVolumeAnd.
  ///
  /// In zh, this message translates to:
  /// **'动量、反转、成交量等因子'**
  String get demoMomentumReversalVolumeAnd;

  /// No description provided for @demoInvesting101.
  ///
  /// In zh, this message translates to:
  /// **'投资课堂'**
  String get demoInvesting101;

  /// No description provided for @demoUnderstandInvestingInPlain.
  ///
  /// In zh, this message translates to:
  /// **'用简单的语言理解投资逻辑'**
  String get demoUnderstandInvestingInPlain;

  /// No description provided for @demoFinxSportsBottle.
  ///
  /// In zh, this message translates to:
  /// **'FinX 运动水壶'**
  String get demoFinxSportsBottle;

  /// No description provided for @demoFifiHolidayBeanie.
  ///
  /// In zh, this message translates to:
  /// **'Fifi 圣诞绒帽'**
  String get demoFifiHolidayBeanie;

  /// No description provided for @demoWirelessHeadphones.
  ///
  /// In zh, this message translates to:
  /// **'无线耳机'**
  String get demoWirelessHeadphones;

  /// No description provided for @demoFifiCrossbodyBag.
  ///
  /// In zh, this message translates to:
  /// **'Fifi 斜挎包'**
  String get demoFifiCrossbodyBag;

  /// No description provided for @mastersComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将上线'**
  String get mastersComingSoon;

  /// No description provided for @mastersSeeWhatTheBig.
  ///
  /// In zh, this message translates to:
  /// **'看看大机构在买什么'**
  String get mastersSeeWhatTheBig;

  /// No description provided for @mastersBasedOnPublic13f.
  ///
  /// In zh, this message translates to:
  /// **'基于公开的 13F 持仓申报，按季度更新'**
  String get mastersBasedOnPublic13f;

  /// No description provided for @mastersTopReturns.
  ///
  /// In zh, this message translates to:
  /// **'收益最高'**
  String get mastersTopReturns;

  /// No description provided for @mastersRecentlyUpdated.
  ///
  /// In zh, this message translates to:
  /// **'最近更新'**
  String get mastersRecentlyUpdated;

  /// No description provided for @mastersMore.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get mastersMore;

  /// No description provided for @mastersStockIdeas.
  ///
  /// In zh, this message translates to:
  /// **'个股机会'**
  String get mastersStockIdeas;

  /// No description provided for @mastersQ32026.
  ///
  /// In zh, this message translates to:
  /// **'2026 年第三季度'**
  String get mastersQ32026;

  /// No description provided for @mastersDataComesFromPublic.
  ///
  /// In zh, this message translates to:
  /// **'数据来源于机构公开申报（演示数据），存在披露滞后，不代表机构当前持仓，不构成投资建议。'**
  String get mastersDataComesFromPublic;

  /// No description provided for @mastersDemoDataInstitutionNames.
  ///
  /// In zh, this message translates to:
  /// **'演示数据：机构名称、收益与持仓均为虚构，仅供展示'**
  String get mastersDemoDataInstitutionNames;

  /// No description provided for @masters1YrReturn.
  ///
  /// In zh, this message translates to:
  /// **'年收益'**
  String get masters1YrReturn;

  /// No description provided for @mastersSymbol.
  ///
  /// In zh, this message translates to:
  /// **'代码'**
  String get mastersSymbol;

  /// No description provided for @mastersIncreaseAsOfShares.
  ///
  /// In zh, this message translates to:
  /// **'增持占总股本'**
  String get mastersIncreaseAsOfShares;

  /// No description provided for @mastersIncreasedUnchangedDecreased.
  ///
  /// In zh, this message translates to:
  /// **'增 / 平 / 减 家数'**
  String get mastersIncreasedUnchangedDecreased;

  /// No description provided for @mastersAllInstitutions.
  ///
  /// In zh, this message translates to:
  /// **'全部机构'**
  String get mastersAllInstitutions;

  /// No description provided for @mastersNameFirm.
  ///
  /// In zh, this message translates to:
  /// **'名称 / 公司'**
  String get mastersNameFirm;

  /// No description provided for @mastersReturn.
  ///
  /// In zh, this message translates to:
  /// **'收益'**
  String get mastersReturn;

  /// No description provided for @mastersAumGrowth.
  ///
  /// In zh, this message translates to:
  /// **'资产增速'**
  String get mastersAumGrowth;

  /// No description provided for @mastersUpdated.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get mastersUpdated;

  /// No description provided for @mastersDemoDataAllInstitution.
  ///
  /// In zh, this message translates to:
  /// **'演示数据：机构名称均为虚构示例'**
  String get mastersDemoDataAllInstitution;

  /// No description provided for @mastersInstitutionDetails.
  ///
  /// In zh, this message translates to:
  /// **'机构详情'**
  String get mastersInstitutionDetails;

  /// No description provided for @mastersInstitutionNotFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到该机构'**
  String get mastersInstitutionNotFound;

  /// No description provided for @mastersPleaseGoBackAnd.
  ///
  /// In zh, this message translates to:
  /// **'请返回列表重新选择'**
  String get mastersPleaseGoBackAnd;

  /// No description provided for @mastersTop5HoldingsSample.
  ///
  /// In zh, this message translates to:
  /// **'前五大持仓（示例）'**
  String get mastersTop5HoldingsSample;

  /// No description provided for @mastersDemoDataInstitutionsAnd.
  ///
  /// In zh, this message translates to:
  /// **'演示数据：机构与持仓均为虚构；个股价格为虚拟行情'**
  String get mastersDemoDataInstitutionsAnd;

  /// No description provided for @mastersAiAssistant.
  ///
  /// In zh, this message translates to:
  /// **'AI 助手'**
  String get mastersAiAssistant;

  /// No description provided for @mastersNotIncludedInThe.
  ///
  /// In zh, this message translates to:
  /// **'首期不做，待合规评估。以下为保留的页面规格，仅供评估，不会在首期上线。'**
  String get mastersNotIncludedInThe;

  /// No description provided for @mastersFifiQuantAssistant.
  ///
  /// In zh, this message translates to:
  /// **'Fifi 量化助手'**
  String get mastersFifiQuantAssistant;

  /// No description provided for @mastersComingSoon2.
  ///
  /// In zh, this message translates to:
  /// **'即将推出'**
  String get mastersComingSoon2;

  /// No description provided for @mastersFifiIsLearningTo.
  ///
  /// In zh, this message translates to:
  /// **'Fifi 正在学习分析图表、风险和持仓，敬请期待。'**
  String get mastersFifiIsLearningTo;

  /// No description provided for @mastersBeforeLaunchWeNeed.
  ///
  /// In zh, this message translates to:
  /// **'上线前需评估是否构成投资建议。'**
  String get mastersBeforeLaunchWeNeed;

  /// No description provided for @mastersLaunchReminderOn.
  ///
  /// In zh, this message translates to:
  /// **'已订阅上线提醒'**
  String get mastersLaunchReminderOn;

  /// No description provided for @mastersRemindMeAtLaunch.
  ///
  /// In zh, this message translates to:
  /// **'上线提醒我'**
  String get mastersRemindMeAtLaunch;

  /// No description provided for @mastersReminderCanceled.
  ///
  /// In zh, this message translates to:
  /// **'已取消提醒'**
  String get mastersReminderCanceled;

  /// No description provided for @mastersDemoDataFeaturesShown.
  ///
  /// In zh, this message translates to:
  /// **'演示数据：功能为规划展示，暂未上线'**
  String get mastersDemoDataFeaturesShown;

  /// No description provided for @rewardsLevel.
  ///
  /// In zh, this message translates to:
  /// **'等级 {lv} {rewardSoon}'**
  String rewardsLevel(Object lv, Object rewardSoon);

  /// No description provided for @rewardsHolidayStarterGifts.
  ///
  /// In zh, this message translates to:
  /// **'圣诞新手礼'**
  String get rewardsHolidayStarterGifts;

  /// No description provided for @rewardsUnlocksAtLevel1.
  ///
  /// In zh, this message translates to:
  /// **'等级 1 解锁'**
  String get rewardsUnlocksAtLevel1;

  /// No description provided for @rewardsRewardsShownAreDemo.
  ///
  /// In zh, this message translates to:
  /// **'奖励内容为演示示例，正式奖品与兑换规则以上线公告为准'**
  String get rewardsRewardsShownAreDemo;

  /// No description provided for @rewardsFifiRewards.
  ///
  /// In zh, this message translates to:
  /// **'Fifi 奖励'**
  String get rewardsFifiRewards;

  /// No description provided for @rewardsHolidayFifi.
  ///
  /// In zh, this message translates to:
  /// **'圣诞 Fifi'**
  String get rewardsHolidayFifi;

  /// No description provided for @rewardsHolidayNewYearLimited.
  ///
  /// In zh, this message translates to:
  /// **'圣诞 · 新年限定'**
  String get rewardsHolidayNewYearLimited;

  /// No description provided for @rewardsFifiHolidayShop.
  ///
  /// In zh, this message translates to:
  /// **'Fifi 圣诞商店\n'**
  String get rewardsFifiHolidayShop;

  /// No description provided for @rewardsOpeningSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将开启'**
  String get rewardsOpeningSoon;

  /// No description provided for @rewardsCompleteTasksToEarn.
  ///
  /// In zh, this message translates to:
  /// **'完成任务赚取 XP，解锁节日服饰、房间与新年梦想好礼。'**
  String get rewardsCompleteTasksToEarn;

  /// No description provided for @rewardsLevel2.
  ///
  /// In zh, this message translates to:
  /// **'等级 {level}'**
  String rewardsLevel2(Object level);

  /// No description provided for @rewardsReminderOn.
  ///
  /// In zh, this message translates to:
  /// **'✓ 已开启提醒'**
  String get rewardsReminderOn;

  /// No description provided for @rewardsRemindMeAtLaunch.
  ///
  /// In zh, this message translates to:
  /// **'🔔 开启上线提醒'**
  String get rewardsRemindMeAtLaunch;

  /// No description provided for @serverReasonRejected.
  ///
  /// In zh, this message translates to:
  /// **'券商已拒绝该订单'**
  String get serverReasonRejected;

  /// No description provided for @serverReasonCanceled.
  ///
  /// In zh, this message translates to:
  /// **'订单已撤销'**
  String get serverReasonCanceled;

  /// No description provided for @serverReasonTransfer.
  ///
  /// In zh, this message translates to:
  /// **'券商返回了失败原因，请联系客服了解详情'**
  String get serverReasonTransfer;

  /// No description provided for @tradeMinOrder.
  ///
  /// In zh, this message translates to:
  /// **'单笔最低 \$1.00（示例值，以券商为准）'**
  String get tradeMinOrder;

  /// 总资产卡今日变动：DW 持仓今日盈亏之和与百分比，如"今日 +$42.18 (+0.65%)"
  ///
  /// In zh, this message translates to:
  /// **'今日 {amount}{pct}'**
  String homeTodayChange(Object amount, Object pct);

  /// No description provided for @homeTodayHidden.
  ///
  /// In zh, this message translates to:
  /// **'今日 ****'**
  String get homeTodayHidden;

  /// No description provided for @tabPredict.
  ///
  /// In zh, this message translates to:
  /// **'预测'**
  String get tabPredict;

  /// No description provided for @predictTitle.
  ///
  /// In zh, this message translates to:
  /// **'预测'**
  String get predictTitle;

  /// No description provided for @predictPoints.
  ///
  /// In zh, this message translates to:
  /// **'{points} 分'**
  String predictPoints(Object points);

  /// No description provided for @predictDemoBadge.
  ///
  /// In zh, this message translates to:
  /// **'积分预测 · 演示模式，非真实资金'**
  String get predictDemoBadge;

  /// No description provided for @predictCatAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get predictCatAll;

  /// No description provided for @predictCatCrypto.
  ///
  /// In zh, this message translates to:
  /// **'加密'**
  String get predictCatCrypto;

  /// No description provided for @predictCatStocks.
  ///
  /// In zh, this message translates to:
  /// **'美股'**
  String get predictCatStocks;

  /// No description provided for @predictCatMacro.
  ///
  /// In zh, this message translates to:
  /// **'宏观'**
  String get predictCatMacro;

  /// No description provided for @predictCatSports.
  ///
  /// In zh, this message translates to:
  /// **'体育'**
  String get predictCatSports;

  /// No description provided for @predictCatTrending.
  ///
  /// In zh, this message translates to:
  /// **'热点'**
  String get predictCatTrending;

  /// No description provided for @predictUpOrDownSymbol.
  ///
  /// In zh, this message translates to:
  /// **'涨 或 跌 · {symbol}'**
  String predictUpOrDownSymbol(Object symbol);

  /// No description provided for @predictUpOrDown.
  ///
  /// In zh, this message translates to:
  /// **'涨 或 跌'**
  String get predictUpOrDown;

  /// No description provided for @predictTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标 {price} · 窗口结束时结算'**
  String predictTarget(Object price);

  /// No description provided for @predictUpPct.
  ///
  /// In zh, this message translates to:
  /// **'上涨 · {pct}%'**
  String predictUpPct(Object pct);

  /// No description provided for @predictDownPct.
  ///
  /// In zh, this message translates to:
  /// **'下跌 · {pct}%'**
  String predictDownPct(Object pct);

  /// No description provided for @predictUp.
  ///
  /// In zh, this message translates to:
  /// **'上涨'**
  String get predictUp;

  /// No description provided for @predictDown.
  ///
  /// In zh, this message translates to:
  /// **'下跌'**
  String get predictDown;

  /// No description provided for @predict15m.
  ///
  /// In zh, this message translates to:
  /// **'15 分钟市场'**
  String get predict15m;

  /// No description provided for @predictSeeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get predictSeeAll;

  /// No description provided for @predictTrending.
  ///
  /// In zh, this message translates to:
  /// **'热门市场'**
  String get predictTrending;

  /// No description provided for @predictLive.
  ///
  /// In zh, this message translates to:
  /// **'Live'**
  String get predictLive;

  /// No description provided for @predictLiveSettle.
  ///
  /// In zh, this message translates to:
  /// **'Live · {date}结算'**
  String predictLiveSettle(Object date);

  /// No description provided for @predictCloses.
  ///
  /// In zh, this message translates to:
  /// **'{date} 截止'**
  String predictCloses(Object date);

  /// No description provided for @predictDisclaimer.
  ///
  /// In zh, this message translates to:
  /// **'预测为用户观点聚合，仅供参考，不构成投资建议'**
  String get predictDisclaimer;

  /// No description provided for @predictMine.
  ///
  /// In zh, this message translates to:
  /// **'我的预测'**
  String get predictMine;

  /// No description provided for @predictNoMarkets.
  ///
  /// In zh, this message translates to:
  /// **'该分类暂无进行中的市场'**
  String get predictNoMarkets;

  /// No description provided for @predictLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'预测市场暂时无法加载：{error}'**
  String predictLoadFailed(Object error);

  /// No description provided for @predictYourPick.
  ///
  /// In zh, this message translates to:
  /// **'你的预测：{label}'**
  String predictYourPick(Object label);

  /// No description provided for @predictStake.
  ///
  /// In zh, this message translates to:
  /// **'下注积分'**
  String get predictStake;

  /// No description provided for @predictStakeHint.
  ///
  /// In zh, this message translates to:
  /// **'10–5,000 的整数'**
  String get predictStakeHint;

  /// No description provided for @predictAvailable.
  ///
  /// In zh, this message translates to:
  /// **'可用 {points} 分'**
  String predictAvailable(Object points);

  /// No description provided for @predictPotential.
  ///
  /// In zh, this message translates to:
  /// **'若正确可得 {points} 分'**
  String predictPotential(Object points);

  /// No description provided for @predictProbNow.
  ///
  /// In zh, this message translates to:
  /// **'当前概率 {pct}%'**
  String predictProbNow(Object pct);

  /// No description provided for @predictPricingNote.
  ///
  /// In zh, this message translates to:
  /// **'赔率按下注时的比例确定，比例随双边下注实时变化（演示用简化模型）。'**
  String get predictPricingNote;

  /// No description provided for @predictConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认预测'**
  String get predictConfirm;

  /// No description provided for @predictPlaced.
  ///
  /// In zh, this message translates to:
  /// **'预测已提交，若正确可得 {points} 分'**
  String predictPlaced(Object points);

  /// No description provided for @predictStakeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入 10–5,000 的整数积分'**
  String get predictStakeInvalid;

  /// No description provided for @predictStakeInsufficient.
  ///
  /// In zh, this message translates to:
  /// **'积分不足'**
  String get predictStakeInsufficient;

  /// No description provided for @predictClosedNow.
  ///
  /// In zh, this message translates to:
  /// **'该市场已截止'**
  String get predictClosedNow;

  /// No description provided for @predictHitRate.
  ///
  /// In zh, this message translates to:
  /// **'命中率'**
  String get predictHitRate;

  /// No description provided for @predictNetPoints.
  ///
  /// In zh, this message translates to:
  /// **'累计盈亏'**
  String get predictNetPoints;

  /// No description provided for @predictSettledCount.
  ///
  /// In zh, this message translates to:
  /// **'已结算'**
  String get predictSettledCount;

  /// No description provided for @predictClaimable.
  ///
  /// In zh, this message translates to:
  /// **'待领取 {points} 分'**
  String predictClaimable(Object points);

  /// No description provided for @predictClaim.
  ///
  /// In zh, this message translates to:
  /// **'领取'**
  String get predictClaim;

  /// No description provided for @predictClaimedToast.
  ///
  /// In zh, this message translates to:
  /// **'已领取 {points} 分'**
  String predictClaimedToast(Object points);

  /// No description provided for @predictTabOpen.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get predictTabOpen;

  /// No description provided for @predictTabSettled.
  ///
  /// In zh, this message translates to:
  /// **'已结算'**
  String get predictTabSettled;

  /// No description provided for @predictNoBets.
  ///
  /// In zh, this message translates to:
  /// **'还没有预测，去预测页选一个市场吧。'**
  String get predictNoBets;

  /// No description provided for @predictStatusOpen.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get predictStatusOpen;

  /// No description provided for @predictStatusWon.
  ///
  /// In zh, this message translates to:
  /// **'命中'**
  String get predictStatusWon;

  /// No description provided for @predictStatusLost.
  ///
  /// In zh, this message translates to:
  /// **'未命中'**
  String get predictStatusLost;

  /// No description provided for @predictStatusVoid.
  ///
  /// In zh, this message translates to:
  /// **'作废退回'**
  String get predictStatusVoid;

  /// No description provided for @predictStakeLine.
  ///
  /// In zh, this message translates to:
  /// **'下注 {stake} 分 · 若正确可得 {payout} 分'**
  String predictStakeLine(Object stake, Object payout);

  /// No description provided for @predictPaidLine.
  ///
  /// In zh, this message translates to:
  /// **'下注 {stake} 分 · 派彩 {payout} 分'**
  String predictPaidLine(Object stake, Object payout);

  /// No description provided for @predictClaimedTag.
  ///
  /// In zh, this message translates to:
  /// **'已领取'**
  String get predictClaimedTag;

  /// No description provided for @predictSettlesAt.
  ///
  /// In zh, this message translates to:
  /// **'结算价 {price}'**
  String predictSettlesAt(Object price);

  /// No description provided for @srvPredictStake.
  ///
  /// In zh, this message translates to:
  /// **'下注积分须在 10–5,000 分之间'**
  String get srvPredictStake;

  /// No description provided for @srvPredictOutcome.
  ///
  /// In zh, this message translates to:
  /// **'请选择预测方向'**
  String get srvPredictOutcome;

  /// No description provided for @srvPredictInsufficient.
  ///
  /// In zh, this message translates to:
  /// **'预测积分不足'**
  String get srvPredictInsufficient;

  /// No description provided for @srvPredictClosed.
  ///
  /// In zh, this message translates to:
  /// **'该预测市场已截止'**
  String get srvPredictClosed;

  /// No description provided for @srvPredictNotFound.
  ///
  /// In zh, this message translates to:
  /// **'预测市场不存在'**
  String get srvPredictNotFound;

  /// No description provided for @predictMonthDay.
  ///
  /// In zh, this message translates to:
  /// **'{month}月{day}日'**
  String predictMonthDay(Object month, Object day);

  /// No description provided for @welcomeSlogan1.
  ///
  /// In zh, this message translates to:
  /// **'美股与 ETF 投资'**
  String get welcomeSlogan1;

  /// No description provided for @welcomeSlogan2.
  ///
  /// In zh, this message translates to:
  /// **'开户、入金、交易，一站完成。'**
  String get welcomeSlogan2;

  /// No description provided for @welcomeLogIn.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get welcomeLogIn;

  /// No description provided for @welcomeBrowseMarkets.
  ///
  /// In zh, this message translates to:
  /// **'先逛逛行情'**
  String get welcomeBrowseMarkets;

  /// No description provided for @appearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearanceTitle;

  /// No description provided for @appearanceSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get appearanceSystem;

  /// No description provided for @appearanceLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get appearanceDark;

  /// No description provided for @errSubmitUnconfirmedFunding.
  ///
  /// In zh, this message translates to:
  /// **'网络超时，提交结果确认中。请先到资金记录中查看；再次点击提交不会重复申请。'**
  String get errSubmitUnconfirmedFunding;

  /// No description provided for @errSubmitUnconfirmedOrder.
  ///
  /// In zh, this message translates to:
  /// **'网络超时，订单结果确认中。请先到订单中查看；再次点击提交不会重复下单。'**
  String get errSubmitUnconfirmedOrder;

  /// No description provided for @srvIdemKeyReusedTransfer.
  ///
  /// In zh, this message translates to:
  /// **'这笔申请的内容已变化，请返回后重新提交。'**
  String get srvIdemKeyReusedTransfer;

  /// No description provided for @srvIdemKeyReusedOrder.
  ///
  /// In zh, this message translates to:
  /// **'这笔订单的内容已变化，请返回后重新下单。'**
  String get srvIdemKeyReusedOrder;

  /// No description provided for @statusUnconfirmed.
  ///
  /// In zh, this message translates to:
  /// **'未确认'**
  String get statusUnconfirmed;

  /// No description provided for @xferUnconfirmedNotice.
  ///
  /// In zh, this message translates to:
  /// **'券商结果待人工核对。请勿重复提交，我们核对后会更新这笔记录；如有疑问请联系客服。'**
  String get xferUnconfirmedNotice;

  /// No description provided for @ordersUnconfirmedNotice.
  ///
  /// In zh, this message translates to:
  /// **'券商结果待人工核对，该订单不能撤单。请勿重复下单，我们核对后会更新这笔订单；如有疑问请联系客服。'**
  String get ordersUnconfirmedNotice;

  /// No description provided for @fundAchHoldingPeriod.
  ///
  /// In zh, this message translates to:
  /// **'ACH 入金到账后默认 {days} 天观察期内不可提现，可由 DW 配置调整（待 DW 确认）'**
  String fundAchHoldingPeriod(int days);

  /// No description provided for @xferAfterHoldingPeriod.
  ///
  /// In zh, this message translates to:
  /// **'到账后 {days} 天观察期结束（默认，待 DW 确认）'**
  String xferAfterHoldingPeriod(int days);

  /// No description provided for @assetHeroTotal.
  ///
  /// In zh, this message translates to:
  /// **'总资产 (USD)'**
  String get assetHeroTotal;

  /// No description provided for @assetHeroTotalPaper.
  ///
  /// In zh, this message translates to:
  /// **'模拟 · 总资产 (USD)'**
  String get assetHeroTotalPaper;

  /// No description provided for @assetHeroToday.
  ///
  /// In zh, this message translates to:
  /// **'今日'**
  String get assetHeroToday;

  /// No description provided for @assetHeroTotalPL.
  ///
  /// In zh, this message translates to:
  /// **'累计盈亏'**
  String get assetHeroTotalPL;

  /// No description provided for @assetIntradayBuilding.
  ///
  /// In zh, this message translates to:
  /// **'日内数据积累中'**
  String get assetIntradayBuilding;

  /// No description provided for @assetHistoryBuilding.
  ///
  /// In zh, this message translates to:
  /// **'记录积累中'**
  String get assetHistoryBuilding;

  /// No description provided for @assetFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get assetFilterAll;

  /// No description provided for @assetFilterStock.
  ///
  /// In zh, this message translates to:
  /// **'股票'**
  String get assetFilterStock;

  /// No description provided for @assetFilterEtf.
  ///
  /// In zh, this message translates to:
  /// **'ETF'**
  String get assetFilterEtf;

  /// No description provided for @assetTotalValue.
  ///
  /// In zh, this message translates to:
  /// **'总价值'**
  String get assetTotalValue;

  /// No description provided for @assetOthers.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get assetOthers;

  /// No description provided for @assetNoStockHoldings.
  ///
  /// In zh, this message translates to:
  /// **'暂无股票持仓'**
  String get assetNoStockHoldings;

  /// No description provided for @assetNoEtfHoldings.
  ///
  /// In zh, this message translates to:
  /// **'暂无 ETF 持仓'**
  String get assetNoEtfHoldings;

  /// No description provided for @assetShowAmounts.
  ///
  /// In zh, this message translates to:
  /// **'显示金额'**
  String get assetShowAmounts;

  /// No description provided for @assetHideAmounts.
  ///
  /// In zh, this message translates to:
  /// **'隐藏金额'**
  String get assetHideAmounts;

  /// No description provided for @watchLiveNote.
  ///
  /// In zh, this message translates to:
  /// **'实时报价 · 3 秒刷新'**
  String get watchLiveNote;

  /// No description provided for @drawerWithdrawable.
  ///
  /// In zh, this message translates to:
  /// **'可提现 {amount}'**
  String drawerWithdrawable(String amount);

  /// No description provided for @marketUsMarket.
  ///
  /// In zh, this message translates to:
  /// **'美国市场'**
  String get marketUsMarket;

  /// No description provided for @marketSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get marketSearch;

  /// No description provided for @marketSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索代码或名称'**
  String get marketSearchHint;

  /// No description provided for @marketSearchNoResults.
  ///
  /// In zh, this message translates to:
  /// **'未找到相关标的'**
  String get marketSearchNoResults;

  /// No description provided for @marketStats.
  ///
  /// In zh, this message translates to:
  /// **'市场统计'**
  String get marketStats;

  /// No description provided for @marketStatsToday.
  ///
  /// In zh, this message translates to:
  /// **'今日'**
  String get marketStatsToday;

  /// No description provided for @marketStats30d.
  ///
  /// In zh, this message translates to:
  /// **'近 30 日'**
  String get marketStats30d;

  /// No description provided for @marketStatsBuilding.
  ///
  /// In zh, this message translates to:
  /// **'数据积累中'**
  String get marketStatsBuilding;

  /// No description provided for @marketStatsBuildingSince.
  ///
  /// In zh, this message translates to:
  /// **'数据积累中 · 自 {date} 起记录'**
  String marketStatsBuildingSince(String date);

  /// No description provided for @marketStatsDown.
  ///
  /// In zh, this message translates to:
  /// **'下跌 {n}'**
  String marketStatsDown(int n);

  /// No description provided for @marketStatsUp.
  ///
  /// In zh, this message translates to:
  /// **'上涨 {n}'**
  String marketStatsUp(int n);

  /// No description provided for @marketStatsNote.
  ///
  /// In zh, this message translates to:
  /// **'统计标的池全部股票与 ETF（虚拟行情）'**
  String get marketStatsNote;

  /// No description provided for @marketInsiders.
  ///
  /// In zh, this message translates to:
  /// **'内部人交易'**
  String get marketInsiders;

  /// No description provided for @demoDataBadge.
  ///
  /// In zh, this message translates to:
  /// **'演示数据'**
  String get demoDataBadge;

  /// No description provided for @insiderTopBuy.
  ///
  /// In zh, this message translates to:
  /// **'买入最多'**
  String get insiderTopBuy;

  /// No description provided for @insiderTopSell.
  ///
  /// In zh, this message translates to:
  /// **'卖出最多'**
  String get insiderTopSell;

  /// No description provided for @insiderMostActive.
  ///
  /// In zh, this message translates to:
  /// **'最活跃'**
  String get insiderMostActive;

  /// No description provided for @insiderBought.
  ///
  /// In zh, this message translates to:
  /// **'买入 {amount}'**
  String insiderBought(String amount);

  /// No description provided for @insiderSold.
  ///
  /// In zh, this message translates to:
  /// **'卖出 {amount}'**
  String insiderSold(String amount);

  /// No description provided for @insiderTrades.
  ///
  /// In zh, this message translates to:
  /// **'交易 {n} 次'**
  String insiderTrades(int n);

  /// No description provided for @insiderMoreComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'内部人交易明细即将上线'**
  String get insiderMoreComingSoon;

  /// No description provided for @orderDoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'下单成功'**
  String get orderDoneTitle;

  /// No description provided for @orderDoneSummary.
  ///
  /// In zh, this message translates to:
  /// **'成交摘要'**
  String get orderDoneSummary;

  /// No description provided for @orderDoneSymbol.
  ///
  /// In zh, this message translates to:
  /// **'代码'**
  String get orderDoneSymbol;

  /// No description provided for @orderDonePrice.
  ///
  /// In zh, this message translates to:
  /// **'成交价'**
  String get orderDonePrice;

  /// No description provided for @orderDoneQty.
  ///
  /// In zh, this message translates to:
  /// **'数量'**
  String get orderDoneQty;

  /// No description provided for @orderDoneTotal.
  ///
  /// In zh, this message translates to:
  /// **'总金额'**
  String get orderDoneTotal;

  /// No description provided for @orderDoneTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get orderDoneTime;

  /// No description provided for @orderDoneBackHome.
  ///
  /// In zh, this message translates to:
  /// **'返回首页'**
  String get orderDoneBackHome;

  /// No description provided for @xpPill.
  ///
  /// In zh, this message translates to:
  /// **'{xp} XP'**
  String xpPill(String xp);

  /// No description provided for @fifiTitle.
  ///
  /// In zh, this message translates to:
  /// **'Fifi 量化助手'**
  String get fifiTitle;

  /// No description provided for @fifiSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'你的智能投资助理'**
  String get fifiSubtitle;

  /// No description provided for @fifiHeroTitle.
  ///
  /// In zh, this message translates to:
  /// **'即将上线'**
  String get fifiHeroTitle;

  /// No description provided for @fifiHeroBody.
  ///
  /// In zh, this message translates to:
  /// **'Fifi 正在学习为你解读图表、风险与持仓。'**
  String get fifiHeroBody;

  /// No description provided for @fifiFeat1.
  ///
  /// In zh, this message translates to:
  /// **'持仓体检'**
  String get fifiFeat1;

  /// No description provided for @fifiFeat1Desc.
  ///
  /// In zh, this message translates to:
  /// **'分析你的持仓与未实现盈亏。'**
  String get fifiFeat1Desc;

  /// No description provided for @fifiFeat2.
  ///
  /// In zh, this message translates to:
  /// **'持有或卖出'**
  String get fifiFeat2;

  /// No description provided for @fifiFeat2Desc.
  ///
  /// In zh, this message translates to:
  /// **'行动前对比趋势、风险与仓位。'**
  String get fifiFeat2Desc;

  /// No description provided for @fifiFeat3.
  ///
  /// In zh, this message translates to:
  /// **'个股研究'**
  String get fifiFeat3;

  /// No description provided for @fifiFeat3Desc.
  ///
  /// In zh, this message translates to:
  /// **'汇总价格走势、基本面与新闻信号。'**
  String get fifiFeat3Desc;

  /// No description provided for @fifiFeat4.
  ///
  /// In zh, this message translates to:
  /// **'风险预警'**
  String get fifiFeat4;

  /// No description provided for @fifiFeat4Desc.
  ///
  /// In zh, this message translates to:
  /// **'提示波动、集中度与下行压力。'**
  String get fifiFeat4Desc;

  /// No description provided for @fifiFeat5.
  ///
  /// In zh, this message translates to:
  /// **'量化信号'**
  String get fifiFeat5;

  /// No description provided for @fifiFeat5Desc.
  ///
  /// In zh, this message translates to:
  /// **'跟踪动量、反转、成交量与因子分。'**
  String get fifiFeat5Desc;

  /// No description provided for @fifiFeat6.
  ///
  /// In zh, this message translates to:
  /// **'跟 Fifi 学投资'**
  String get fifiFeat6;

  /// No description provided for @fifiFeat6Desc.
  ///
  /// In zh, this message translates to:
  /// **'用简单清晰的语言理解投资逻辑。'**
  String get fifiFeat6Desc;

  /// No description provided for @fifiRemind.
  ///
  /// In zh, this message translates to:
  /// **'开启上线提醒'**
  String get fifiRemind;

  /// No description provided for @fifiRemindOn.
  ///
  /// In zh, this message translates to:
  /// **'已开启上线提醒'**
  String get fifiRemindOn;

  /// No description provided for @fifiRemindCaption.
  ///
  /// In zh, this message translates to:
  /// **'Fifi 量化助手就绪时，我们会第一时间通知你。'**
  String get fifiRemindCaption;

  /// No description provided for @storeTitle.
  ///
  /// In zh, this message translates to:
  /// **'Fifi 商店'**
  String get storeTitle;

  /// No description provided for @storeTier.
  ///
  /// In zh, this message translates to:
  /// **'等级 {n}'**
  String storeTier(int n);

  /// No description provided for @storeDream.
  ///
  /// In zh, this message translates to:
  /// **'梦想'**
  String get storeDream;

  /// No description provided for @storeTierNew.
  ///
  /// In zh, this message translates to:
  /// **'等级 {n} 上新'**
  String storeTierNew(int n);

  /// No description provided for @storeTierEmpty.
  ///
  /// In zh, this message translates to:
  /// **'该等级商品即将上新'**
  String get storeTierEmpty;

  /// No description provided for @storeTierLocked.
  ///
  /// In zh, this message translates to:
  /// **'达到等级 {n} 后解锁'**
  String storeTierLocked(int n);

  /// No description provided for @storeAvailable.
  ///
  /// In zh, this message translates to:
  /// **'可兑换'**
  String get storeAvailable;

  /// No description provided for @storeNotEnoughXp.
  ///
  /// In zh, this message translates to:
  /// **'XP 不足'**
  String get storeNotEnoughXp;

  /// No description provided for @storeUnlockAt.
  ///
  /// In zh, this message translates to:
  /// **'等级 {n} 解锁'**
  String storeUnlockAt(int n);

  /// No description provided for @storeBundleXp.
  ///
  /// In zh, this message translates to:
  /// **'套装 · {xp} XP'**
  String storeBundleXp(String xp);

  /// No description provided for @storePreview.
  ///
  /// In zh, this message translates to:
  /// **'预 览'**
  String get storePreview;

  /// No description provided for @storeComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'敬请期待'**
  String get storeComingSoon;

  /// No description provided for @storePreviewOnFifi.
  ///
  /// In zh, this message translates to:
  /// **'在 Fifi 上预览'**
  String get storePreviewOnFifi;

  /// No description provided for @storePreviewOnFifiSoon.
  ///
  /// In zh, this message translates to:
  /// **'在 Fifi 上预览即将上线'**
  String get storePreviewOnFifiSoon;

  /// No description provided for @storeEarnXp.
  ///
  /// In zh, this message translates to:
  /// **'赚取 XP'**
  String get storeEarnXp;

  /// No description provided for @storeRedeemSoon.
  ///
  /// In zh, this message translates to:
  /// **'兑换即将开启'**
  String get storeRedeemSoon;

  /// No description provided for @storeSearchSoon.
  ///
  /// In zh, this message translates to:
  /// **'商店搜索即将上线'**
  String get storeSearchSoon;

  /// No description provided for @storeImagePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'示意图，正式图片即将更新'**
  String get storeImagePlaceholder;

  /// No description provided for @storeDemoNote.
  ///
  /// In zh, this message translates to:
  /// **'XP 为站内成长值，不可兑换现金；商品与兑换规则以上线公告为准。'**
  String get storeDemoNote;

  /// No description provided for @earnTitle.
  ///
  /// In zh, this message translates to:
  /// **'Fifi 奖励任务'**
  String get earnTitle;

  /// No description provided for @earnToday.
  ///
  /// In zh, this message translates to:
  /// **'今日任务'**
  String get earnToday;

  /// No description provided for @earnResetIn.
  ///
  /// In zh, this message translates to:
  /// **'{time} 后重置'**
  String earnResetIn(String time);

  /// No description provided for @earnTask1.
  ///
  /// In zh, this message translates to:
  /// **'每日签到'**
  String get earnTask1;

  /// No description provided for @earnTask1Desc.
  ///
  /// In zh, this message translates to:
  /// **'保持你的连续记录'**
  String get earnTask1Desc;

  /// No description provided for @earnTask2.
  ///
  /// In zh, this message translates to:
  /// **'跟 Fifi 学一课'**
  String get earnTask2;

  /// No description provided for @earnTask2Desc.
  ///
  /// In zh, this message translates to:
  /// **'完成一节市场小课堂'**
  String get earnTask2Desc;

  /// No description provided for @earnTask3.
  ///
  /// In zh, this message translates to:
  /// **'运行持仓体检'**
  String get earnTask3;

  /// No description provided for @earnTask3Desc.
  ///
  /// In zh, this message translates to:
  /// **'检查你的资金健康度'**
  String get earnTask3Desc;

  /// No description provided for @earnTask4.
  ///
  /// In zh, this message translates to:
  /// **'本月储蓄目标'**
  String get earnTask4;

  /// No description provided for @earnTask4Desc.
  ///
  /// In zh, this message translates to:
  /// **'完成本月入金小目标'**
  String get earnTask4Desc;

  /// No description provided for @earnTask5.
  ///
  /// In zh, this message translates to:
  /// **'分享一次 FinX'**
  String get earnTask5;

  /// No description provided for @earnTask5Desc.
  ///
  /// In zh, this message translates to:
  /// **'邀请一位朋友一起学习'**
  String get earnTask5Desc;

  /// No description provided for @earnXpPlus.
  ///
  /// In zh, this message translates to:
  /// **'+{xp} XP'**
  String earnXpPlus(int xp);

  /// No description provided for @earnTaskSoon.
  ///
  /// In zh, this message translates to:
  /// **'该任务即将开启'**
  String get earnTaskSoon;

  /// No description provided for @earnCheckedIn.
  ///
  /// In zh, this message translates to:
  /// **'签到成功 +{xp} XP'**
  String earnCheckedIn(int xp);

  /// No description provided for @earnAlreadyCheckedIn.
  ///
  /// In zh, this message translates to:
  /// **'今日已签到'**
  String get earnAlreadyCheckedIn;

  /// No description provided for @earnStreak.
  ///
  /// In zh, this message translates to:
  /// **'连续 {n} 天'**
  String earnStreak(int n);

  /// No description provided for @earnKeepGoing.
  ///
  /// In zh, this message translates to:
  /// **'继续保持！'**
  String get earnKeepGoing;

  /// No description provided for @earnStartStreak.
  ///
  /// In zh, this message translates to:
  /// **'今天签到，开启连续记录'**
  String get earnStartStreak;

  /// No description provided for @earnWeekdays.
  ///
  /// In zh, this message translates to:
  /// **'一,二,三,四,五,六,日'**
  String get earnWeekdays;

  /// No description provided for @earnGoWardrobe.
  ///
  /// In zh, this message translates to:
  /// **'前往 Fifi 衣橱'**
  String get earnGoWardrobe;

  /// No description provided for @earnLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'任务加载失败，请下拉重试'**
  String get earnLoadFailed;

  /// No description provided for @searchTypeStock.
  ///
  /// In zh, this message translates to:
  /// **'股票'**
  String get searchTypeStock;
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
