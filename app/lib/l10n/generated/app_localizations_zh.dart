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

  @override
  String get commonBack => '返回';

  @override
  String get expiredPleaseSignInAgain => '请重新登录';

  @override
  String get expiredYourSessionHasExpired => '登录已过期或尚未登录。返回 App 登录后即可继续您的申请。';

  @override
  String get expiredBackToSignIn => '返回登录';

  @override
  String get welcomeInvestInUsStocks => '美股与 ETF 投资，开户、入金、交易一站完成。';

  @override
  String get welcomeSignUp => '注册';

  @override
  String get welcomeSignIn => '登录';

  @override
  String get welcomeBrowseMarketsFirst => '先逛逛行情';

  @override
  String get welcomeBrokerageServicesAreProvided => '证券服务由合作券商提供。投资有风险。';

  @override
  String get loginPleaseEnterAValid => '请输入有效的邮箱地址';

  @override
  String get loginVerificationCodeSent => '验证码已发送';

  @override
  String get loginPleaseEnterThe6 => '请输入 6 位验证码';

  @override
  String get loginPleaseAgreeToThe => '请先同意平台条款';

  @override
  String loginSignInWithIs(Object provider) {
    return '$provider 登录将在后续版本开通，请先使用邮箱验证码登录';
  }

  @override
  String get loginEmail => '邮箱';

  @override
  String get loginVerificationCode => '验证码';

  @override
  String get login6DigitCode => '6 位验证码';

  @override
  String get loginDemoVerificationCode000000 => '演示环境验证码：000000';

  @override
  String loginResendInS(Object _countdown) {
    return '${_countdown}s 后重发';
  }

  @override
  String get loginResendCode => '重新获取';

  @override
  String get loginGetCode => '获取验证码';

  @override
  String get loginOr => '或';

  @override
  String get loginContinueWithGoogle => '使用 Google 登录';

  @override
  String get loginContinueWithApple => '通过 Apple 登录';

  @override
  String get loginSignInWithGoogle =>
      'Google / Apple 登录将在后续版本开通。提供 Google 登录时同时提供 Apple 登录。';

  @override
  String get loginIHaveReadAnd => '我已阅读并同意平台《用户服务协议》与《隐私政策》\n';

  @override
  String get loginTheseAreThePlatform => '此为平台自有条款，券商（DriveWealth）披露将在开户时单独展示。';

  @override
  String get loginSignUpSignIn => '注册并登录';

  @override
  String get assetStock => '股票';

  @override
  String get assetEtf => 'ETF';

  @override
  String get assetCash => '现金';

  @override
  String get rangeAll => '全部';

  @override
  String rangeDays(Object days) {
    return '$days 天';
  }

  @override
  String cueReferenceNo(Object ref) {
    return '参考号 $ref';
  }

  @override
  String get homePaperAccountHasBeen => '模拟账户已重置';

  @override
  String get homeCouldnTRefreshPlease => '刷新失败，请稍后重试';

  @override
  String get homeAccount => '账户';

  @override
  String homeCouldnTRefreshYour(Object error) {
    return '资产数据暂时无法刷新：$error';
  }

  @override
  String homeAccountDataFromDrivewealth(Object v0) {
    return '资金数据来自 DriveWealth · 更新于 $v0';
  }

  @override
  String get homeDepositsInTransitNot => '在途入金（尚未计入购买力）';

  @override
  String get homeNotYetWithdrawableHolding => '观察期内暂不可提现';

  @override
  String get homePendingSettlement => '待交收';

  @override
  String get homeFundYourAccountTo => '入金开始投资';

  @override
  String get homeLinkYourOwnUs => '绑定本人美国银行账户（ACH）后转入资金';

  @override
  String get homeDeposit => '入金';

  @override
  String get homeBrowseMarketsFirst => '先看看行情';

  @override
  String get homeTrading => '交易';

  @override
  String get homePositions => '持仓';

  @override
  String get homeQuantityMarketValueCost => '数量、市值、成本与盈亏（券商返回）';

  @override
  String get homeOrders => '订单';

  @override
  String get homeCheckOrderStatusAnd => '查看订单状态，撤销未成交订单';

  @override
  String get homeWatchlist => '自选股';

  @override
  String get homeGoToMarkets => '去市场';

  @override
  String get homeYourWatchlistIsEmpty => '还没有自选股。在个股页点击右上角星标即可加入。';

  @override
  String homeCouldnTRefreshYour2(Object _paperError) {
    return '模拟账户暂时无法刷新：$_paperError';
  }

  @override
  String get homePaperTrading => '模拟交易';

  @override
  String get homePaperPositions => '模拟持仓';

  @override
  String get homePaperPositionsAndP => '按演示行情估值的模拟持仓与盈亏';

  @override
  String get homePaperOrders => '模拟订单';

  @override
  String get homeMarketOrdersFillInstantly => '市价单即时成交，限价单到价成交，可撤单';

  @override
  String get homePickAStockOn => '在市场页选择股票，点\"买入 / 卖出\"即可模拟下单。';

  @override
  String get homeLiveTotalAssetsUsd => '实盘 · 总资产 (USD)';

  @override
  String get homeBuyingPower => '购买力';

  @override
  String get homeAvailableToWithdraw => '可提现';

  @override
  String get homePendingSandboxVerification => '待沙盒验证';

  @override
  String get drawerSwitchAccount => '切换账户';

  @override
  String get drawerLive => '实盘';

  @override
  String get drawerPaper => '模拟';

  @override
  String get drawerPaperAccountIsnT => '模拟账户暂未开放';

  @override
  String get drawerFunds => '资金';

  @override
  String get drawerWithdraw => '出金';

  @override
  String get drawerBankAccounts => '银行账户';

  @override
  String get drawerTransferFromAnotherBroker => '转入其他券商账户';

  @override
  String get drawerActivity => '动态';

  @override
  String get drawerNotifications => '通知';

  @override
  String get drawerHistory => '历史记录';

  @override
  String get drawerDocuments => '文件';

  @override
  String get drawerManage => '管理';

  @override
  String get drawerSettings => '设置';

  @override
  String get drawerHelpCenter => '帮助中心';

  @override
  String get drawerSignOut => '退出登录';

  @override
  String get drawerBrokerageAccountUnavailable => '交易账户暂不可用';

  @override
  String get drawerAccountNumber => '账户号码';

  @override
  String get drawerMarketValue => '市值';

  @override
  String get drawerSellOnly => '仅可卖出';

  @override
  String get drawerFrozen => '已冻结';

  @override
  String get drawerClosed => '已关闭';

  @override
  String get drawerOpening => '开立中';

  @override
  String get drawerLiveAccount => '实盘账户';

  @override
  String get drawerCashSelfDirected => '现金 · 自主';

  @override
  String get drawerAccountNumberCopied => '账户号码已复制';

  @override
  String drawerAccountType(
    Object accountType,
    Object tradingType,
    Object managementType,
  ) {
    return '账户类型 $accountType · $tradingType · $managementType';
  }

  @override
  String get drawerPositionsValue => '持仓市值';

  @override
  String get drawerTransferIn => '转入';

  @override
  String get drawerThisFeatureIsnT => '该功能不在本次演示范围';

  @override
  String get drawerSignOut2 => '退出登录？';

  @override
  String get drawerYouLlNeedTo => '退出后需重新验证邮箱登录。';

  @override
  String get drawerCancel => '取消';

  @override
  String get drawerSignOut3 => '退出';

  @override
  String get drawerKycStatus => 'KYC 状态';

  @override
  String get drawerLastSynced => '最近同步';

  @override
  String get drawerDwSandboxIds => 'DW 沙盒凭证';

  @override
  String get drawerDemoOnly => '仅演示';

  @override
  String get drawerNoDwIdsYet => '暂无 DW 编号：账户尚未开立，或后端未开启演示环境（OTP_DEV_LOG）。';

  @override
  String drawerCopied(Object k) {
    return '已复制 $k';
  }

  @override
  String get drawerTheseAreTheValues =>
      '以上为 DW 沙盒返回值，可与 demoreset verify 的输出逐项对照。';

  @override
  String get cueYourAccountIsFrozen => '账户已冻结：暂不能交易、入金或出金。资产仍安全托管，请联系客服了解原因。';

  @override
  String get cueYourAccountIsLimited => '账户仅可卖出：暂不能买入新证券，可卖出现有持仓、入金和出金。';

  @override
  String get cueYourAccountIsClosed => '账户已关闭。如有疑问请联系客服。';

  @override
  String get cueOpenABrokerageAccount => '开通证券账户';

  @override
  String get cueVerifyYourIdentityTo => '验证身份即可入金交易，约需 5 分钟';

  @override
  String get cueOpenAnAccount => '去开户';

  @override
  String get cueContinueOpeningYourAccount => '继续开通您的账户';

  @override
  String get cueYourProgressIsSaved => '进度已保存，可从上次中断处继续';

  @override
  String get cueContinueApplication => '继续开户';

  @override
  String get cueApplicationSubmitted => '开户申请已提交';

  @override
  String get cueCheckYourApplicationStatus => '查看开户进度';

  @override
  String get cueViewStatus => '查看进度';

  @override
  String get cueYourApplicationNeedsManual => '开户申请需要人工处理';

  @override
  String get cueWeLlBeIn => '我们会尽快联系您';

  @override
  String get cueOpeningYourBrokerageAccount => '交易账户开立中';

  @override
  String get cueIdentityVerifiedTimingTo => '身份核验已通过（预计时长待 DW 确认）';

  @override
  String get cueYourApplicationNeedsChanges => '开户资料需要修改';

  @override
  String get cuePleaseUpdateTheRequested => '请按提示修改后重新提交';

  @override
  String get cueUpdateApplication => '去修改资料';

  @override
  String get cueIdDocumentRequired => '需要上传身份证件';

  @override
  String get cueWeLlReVerify => '上传后将重新核验';

  @override
  String get cueUploadId => '去上传证件';

  @override
  String get cueApplicationUnderManualReview => '开户申请人工复核中';

  @override
  String get cueTimingToBeConfirmed => '预计时长待 DW 确认';

  @override
  String get cueViewApplicationStatus => '查看申请进度';

  @override
  String get cueApplicationNotApproved => '开户未通过';

  @override
  String get cueSeeTheResultAnd => '查看结果与后续可选操作';

  @override
  String get cueViewResult => '查看结果';

  @override
  String get cueVerifyingYourIdentity => '身份核验中';

  @override
  String get allocAssetAllocation => '资产分布';

  @override
  String get allocValuedAtDemoPrices => '虚拟行情估值';

  @override
  String get allocByLatestMarketValue => '按最新市值 · DW 实时';

  @override
  String get allocTotalAssets => '总资产';

  @override
  String get allocAssetTrend => '资产趋势';

  @override
  String get allocDailySnapshots => '每日快照';

  @override
  String get allocDailySnapshotsSinceAccount => '每日快照 · 自开户起记录';

  @override
  String get allocBuildingYourHistoryThe => '记录积累中，次日起可见趋势';
}
