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
  String get homeWatchlist => '自选';

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

  @override
  String get etfCatIndex => '大盘指数';

  @override
  String get etfCatCommodity => '大宗商品';

  @override
  String get etfCatBond => '债券';

  @override
  String get etfCatSector => '行业';

  @override
  String get etfCatIntl => '海外市场';

  @override
  String get etfCatVolatility => '波动率';

  @override
  String get marketAll => '全部';

  @override
  String get marketDataNote => '演示数据：虚拟行情（随机模拟，非真实报价）\n行情数据仅供参考，不构成投资建议。';

  @override
  String marketDataNoteUpdated(Object time) {
    return '演示数据：虚拟行情（随机模拟，非真实报价） · 更新于 $time\n行情数据仅供参考，不构成投资建议。';
  }

  @override
  String get instrumentStock => '股票';

  @override
  String get instrumentSimulated => '虚拟行情（演示数据）';

  @override
  String get instrumentRealtime => '实时';

  @override
  String instrumentUpdated(Object source, Object time) {
    return '$source · 更新于 $time';
  }

  @override
  String get fgExtremeFear => '极度恐慌';

  @override
  String get fgFear => '恐慌';

  @override
  String get fgNeutral => '中性';

  @override
  String get fgGreed => '贪婪';

  @override
  String get fgExtremeGreed => '极度贪婪';

  @override
  String marketCouldnTRefreshQuotes(Object error) {
    return '行情暂时无法刷新：$error';
  }

  @override
  String get marketTopGainers => '涨幅榜';

  @override
  String get marketTopLosers => '跌幅榜';

  @override
  String get marketEtfRankings => 'ETF 排行';

  @override
  String get marketNone => '暂无';

  @override
  String get instrumentWatchlist => '自选';

  @override
  String get instrumentRemovedFromWatchlist => '已从自选移除';

  @override
  String get instrumentAddedToWatchlist => '已加入自选';

  @override
  String get instrumentSell => '卖出';

  @override
  String get instrumentBuy => '买入';

  @override
  String get instrumentUnavailableRightNow => '暂时无法查看';

  @override
  String instrumentCouldnTRefreshQuotes(Object _error) {
    return '行情暂时无法刷新：$_error';
  }

  @override
  String get instrumentQuote => '报价';

  @override
  String get instrumentBid => '买一价（Bid）';

  @override
  String get instrumentAsk => '卖一价（Ask）';

  @override
  String get instrumentIntraday1MinDashed => '分时（1 分钟） · 虚线为昨收';

  @override
  String get instrumentKeyStats => '关键数据';

  @override
  String get instrumentPrevClose => '昨收';

  @override
  String get instrumentDayHigh => '今日最高';

  @override
  String get instrumentDayLow => '今日最低';

  @override
  String get moodMarketSentiment => '市场情绪';

  @override
  String get moodDemoDataUpdatesEvery => '演示数据 · 每 3 秒更新';

  @override
  String get moodDerivedFromSimulatedPrice => '由虚拟行情的涨跌幅、动量与波动合成';

  @override
  String get moodAdvancersDecliners => '涨跌家数';

  @override
  String moodUp(Object up) {
    return '$up 涨';
  }

  @override
  String moodDown(Object down) {
    return '$down 跌';
  }

  @override
  String moodFlat(Object flat) {
    return '$flat 平';
  }

  @override
  String moodUp2(Object up) {
    return '上涨 $up';
  }

  @override
  String moodFlat2(Object flat) {
    return '平盘 $flat';
  }

  @override
  String moodDown2(Object down) {
    return '下跌 $down';
  }

  @override
  String paperPlValue(Object pl, Object pct) {
    return '模拟盈亏 $pl（$pct）';
  }

  @override
  String get positionsFromDw => '持仓数据来自 DriveWealth';

  @override
  String positionsFromDwUpdated(Object time) {
    return '持仓数据来自 DriveWealth · 更新于 $time';
  }

  @override
  String positionsTotalPl(Object pl) {
    return '持仓盈亏 $pl';
  }

  @override
  String get tradePleaseEnterAnAmount => '请输入金额';

  @override
  String get tradeEnterAValidAmount => '请输入有效金额，最多两位小数';

  @override
  String tradeExceedsYourAvailableBuying(Object v0) {
    return '超过可用购买力 $v0';
  }

  @override
  String tradeExceedsTheSellableMarket(Object v0) {
    return '超过可卖市值 $v0';
  }

  @override
  String get tradePleaseEnterTheNumber => '请输入股数';

  @override
  String get tradeEnterAValidNumber => '请输入有效股数，最多 6 位小数';

  @override
  String get tradeSharesMustBeGreater => '股数须大于 0';

  @override
  String get tradeNoQuoteAvailablePlease => '暂无报价，请按金额买入';

  @override
  String tradeEstimatedAmountExceedsYour(Object v0, Object v1) {
    return '预估金额 $v0 超过可用购买力 $v1';
  }

  @override
  String tradeExceedsYourSellableQuantity(Object v0) {
    return '超过可卖数量 $v0 股';
  }

  @override
  String get tradeSubmitting => '提交中';

  @override
  String get tradeQueued => '排队中';

  @override
  String get tradePartiallyFilled => '部分成交';

  @override
  String get tradeFilled => '已成交';

  @override
  String get tradeRejected => '已拒绝';

  @override
  String get tradeCanceled => '已撤单';

  @override
  String get tradePendingCancel => '撤单中';

  @override
  String get tradePricesShownAreDemo => '显示价格为演示行情，实际成交以券商（DriveWealth）返回为准';

  @override
  String get tradePleaseEnterALimit => '请输入限价';

  @override
  String get tradeLimitPriceMustBe => '限价须大于 0（\$1 以上最多两位小数）';

  @override
  String tradeAmountOnHoldExceeds(Object v0, Object v1) {
    return '冻结金额 $v0 超过可用资金 $v1';
  }

  @override
  String get tradeWorking => '挂单中';

  @override
  String get tradePaperTradingOrdersFill =>
      '模拟盘：按演示行情撮合（市价买入按卖一价、卖出按买一价），使用虚拟资金，不产生真实交易';

  @override
  String get paperPaperTradingVirtualFunds => '模拟盘 · 虚拟资金，按演示行情撮合，不产生真实交易';

  @override
  String get paperPaper => '模拟盘';

  @override
  String get paperPaperAccountTotalValue => '模拟账户总资产';

  @override
  String get paperReset => '重置';

  @override
  String get paperPaperPL => '模拟盈亏 ••••';

  @override
  String get paperAvailableFunds => '可用资金';

  @override
  String get paperOnHoldForOrders => '挂单冻结';

  @override
  String get paperStartingBalance => '初始资金';

  @override
  String get paperResetPaperAccount => '重置模拟账户？';

  @override
  String get paperYourVirtualFundsWill =>
      '模拟资金将恢复为初始金额，模拟持仓与订单全部清空。此操作只影响模拟盘，不影响实盘账户。';

  @override
  String get ordersCancelOrder => '撤销订单？';

  @override
  String ordersCancelingReleasesTheVirtual(
    Object v0,
    Object symbol,
    Object v2,
  ) {
    return '$v0 $symbol $v2。撤单后释放冻结的模拟资金 / 股数。';
  }

  @override
  String ordersTheCancellationResultIs(Object v0, Object symbol, Object v2) {
    return '$v0 $symbol $v2。撤单结果以券商返回为准，已成交部分不会撤销。';
  }

  @override
  String get ordersKeepOrder => '再想想';

  @override
  String get ordersCancelOrder2 => '撤单';

  @override
  String get ordersOrderCanceled => '订单已撤销';

  @override
  String get ordersCancelRequestSubmittedWaiting => '撤单已提交，等待券商确认';

  @override
  String ordersShares(Object v0) {
    return '$v0 股';
  }

  @override
  String get ordersNoOrdersYet => '暂无订单';

  @override
  String get ordersYouCanPlaceOrders => '交易账户开立后即可下单。';

  @override
  String get ordersBackToAssets => '返回资产页';

  @override
  String get ordersOpen => '未完成';

  @override
  String get ordersClosed => '已结束';

  @override
  String get ordersNoOrdersYetTap => '暂无订单。在个股页点击\"买入\"或\"卖出\"即可下单。';

  @override
  String get ordersPaperOrdersAreFilled => '模拟订单按演示行情撮合，不产生真实交易。';

  @override
  String get ordersOrderStatusFilledQuantity =>
      '订单状态、成交数量与成交价均以券商（DriveWealth）返回为准。';

  @override
  String get ordersOrder => '委托';

  @override
  String ordersLimitDay(Object v0, Object v1) {
    return '限价 $v0 · $v1 · 当日有效';
  }

  @override
  String ordersMarket(Object v0) {
    return '市价单 · $v0';
  }

  @override
  String get ordersAvgFillPrice => '成交均价';

  @override
  String get ordersFilledAmount => '成交金额';

  @override
  String get ordersFees => '费用';

  @override
  String get ordersSubmitted => '提交时间';

  @override
  String get ordersCompleted => '完成时间';

  @override
  String get ordersOrderNo => '订单号';

  @override
  String get ordersTheBrokerHasnT => '券商受理结果暂未确认，我们会自动核对，请勿重复下单。';

  @override
  String get positionsNoPositionsYet => '暂无持仓';

  @override
  String get positionsYouCanBuyStocks => '交易账户开立后即可买入股票。';

  @override
  String get positionsNoPositionsYet2 => '还没有持仓。';

  @override
  String get positionsPickAStockOn => '在市场页选择股票，点击\"买入\"即可下单。';

  @override
  String get positionsPaperPositionsAreValued => '模拟持仓按演示行情估值，不代表真实资产。';

  @override
  String get positionsPaperPositionsValue => '模拟持仓市值';

  @override
  String get positionsSharesHeld => '持有数量';

  @override
  String get positionsSellable => '可卖数量';

  @override
  String get positionsCostBasis => '成本';

  @override
  String get positionsAvgCurrentPrice => '均价 / 现价';

  @override
  String get orderSideBuy => '买入';

  @override
  String get orderSideSell => '卖出';

  @override
  String get orderDemoQuote => '演示行情';

  @override
  String get orderLimitHelpBuy => '买入：价格不高于限价时成交；当日有效';

  @override
  String get orderLimitHelpSell => '卖出：价格不低于限价时成交；当日有效';

  @override
  String get orderBuyAmountUsd => '买入金额 (USD)';

  @override
  String get orderSellAmountUsd => '卖出金额 (USD)';

  @override
  String get orderBuyShares => '买入股数';

  @override
  String get orderSellShares => '卖出股数';

  @override
  String get orderYourAccountIsCurrently => '账户当前受限，暂不能交易。如有疑问请联系客服。';

  @override
  String get orderYourAccountIsFrozen => '账户已冻结，暂不能交易。资产仍安全托管，请联系客服了解原因。';

  @override
  String get orderYourAccountIsClosed => '账户已关闭，不能交易。';

  @override
  String get orderYourAccountIsCurrently2 => '账户当前仅可卖出，暂不能买入。';

  @override
  String get orderOrderAmount => '委托金额';

  @override
  String get orderOrderQuantity => '委托股数';

  @override
  String orderShares(Object v0) {
    return '约 $v0 股';
  }

  @override
  String orderText(Object v0) {
    return '约 $v0';
  }

  @override
  String get orderEstimatedAmountOnHold => '预估金额（冻结）';

  @override
  String get orderEstimatedAmount => '预估金额';

  @override
  String get orderEstimatedShares => '预估股数';

  @override
  String get orderLimitOrderDay => '限价单 · 当日有效';

  @override
  String get orderMarketOrder => '市价单';

  @override
  String get orderOpenAnAccountTo => '开户后即可交易';

  @override
  String get orderYouCanPlaceOrders => '交易账户开立后才能下单。请先完成开户，或切换到模拟盘练习。';

  @override
  String get orderSwitchToPaperTrading => '切换到模拟盘';

  @override
  String get orderMarket => '市价';

  @override
  String get orderLimit => '限价';

  @override
  String get orderByAmount => '按金额';

  @override
  String get orderByShares => '按股数';

  @override
  String get orderLimitPriceUsd => '限价 (USD)';

  @override
  String orderFractionalSharesSupported(Object minOrderText) {
    return '支持碎股；$minOrderText';
  }

  @override
  String get orderFractionalSharesSupportedUp => '支持小数股，最多 6 位小数';

  @override
  String orderSellAllShares(Object v0) {
    return '全部卖出（$v0 股）';
  }

  @override
  String get orderOrderType => '订单类型';

  @override
  String get orderReferencePriceDemoQuote => '参考价（演示行情）';

  @override
  String get orderPaperAvailableFunds => '模拟可用资金';

  @override
  String get orderBuyingPower => '可用购买力';

  @override
  String get orderPaperLimitOrderFills =>
      '模拟限价单：演示行情到达限价时自动成交，未成交前冻结资金 / 股数，当日有效。';

  @override
  String get orderPaperMarketOrdersFill => '模拟市价单按演示行情即时成交（买入按卖一价、卖出按买一价）。';

  @override
  String get orderYourCurrentBuyingPower =>
      '当前可用购买力为 \$0.00。入金结算后才计入购买力，日期以资金记录中券商返回的为准。';

  @override
  String get orderLimitOrdersAreGood =>
      '限价单当日有效，价格到达限价才可能成交，未成交部分收盘后自动撤销，状态以券商返回为准。';

  @override
  String get orderMarketOrdersFillAt =>
      '市价单按券商实际成交价成交。本期不区分盘前盘后，休市时提交的订单可能排队至开盘，状态以券商返回为准。';

  @override
  String get orderNext => '下一步';

  @override
  String get orderReviewOrder => '确认订单';

  @override
  String get orderPaperVirtualFunds => '模拟盘（虚拟资金）';

  @override
  String get orderLiveDrivewealth => '实盘（DriveWealth）';

  @override
  String get orderSide => '方向';

  @override
  String get orderLimitPrice => '限价';

  @override
  String get orderCustodian => '托管券商';

  @override
  String get orderEditOrder => '返回修改';

  @override
  String get orderConfirmBuy => '确认买入';

  @override
  String get orderConfirmSell => '确认卖出';

  @override
  String get orderOrderRecorded => '订单已记录';

  @override
  String get orderPaperOrderFilled => '模拟订单已成交';

  @override
  String get orderOrderFilled => '订单已成交';

  @override
  String get orderOrderRejectedByThe => '券商已拒绝该订单';

  @override
  String get orderPaperLimitOrderPlaced => '模拟限价单已挂单';

  @override
  String get orderLimitOrderSubmitted => '限价单已提交';

  @override
  String get orderOrderSubmitted => '订单已提交';

  @override
  String get orderTheBrokerHasnT => '券商受理结果暂未确认，我们会自动核对，请稍后在订单列表中查看状态。请勿重复提交。';

  @override
  String get orderSimulatedFillAtDemo => '按演示行情模拟成交，使用虚拟资金，不产生真实交易。';

  @override
  String get orderFillPriceAndQuantity => '成交价与数量以券商返回为准。';

  @override
  String get orderTheBrokerRejectedThis => '券商已拒绝该订单，请稍后重试或联系客服。';

  @override
  String get orderFillsAutomaticallyWhenThe =>
      '演示行情到达限价时自动成交；未成交前冻结资金 / 股数，可在模拟订单中撤单。当日有效。';

  @override
  String get orderMayFillOnlyWhen => '价格到达限价才可能成交，当日有效，可在订单列表中撤单。状态以券商返回为准。';

  @override
  String get orderYourOrderHasBeen =>
      '订单已发送至券商，成交后状态会在订单列表中更新。休市期间提交的订单可能排队至开盘。';

  @override
  String get orderOrderResult => '下单结果';

  @override
  String get orderStatus => '状态';

  @override
  String get orderFilledQuantity => '成交数量';

  @override
  String get orderViewPaperOrders => '查看模拟订单';

  @override
  String get orderViewOrders => '查看订单';

  @override
  String get orderDone => '完成';

  @override
  String get fundAchFee => '\$0.25（DW 文档，待 DW 确认）';

  @override
  String bankSubtitle(Object type, Object owner, Object date) {
    return '$type · 户名 $owner · 绑定于 $date';
  }

  @override
  String transferTitleDeposit(Object method) {
    return '$method 入金';
  }

  @override
  String transferTitleWithdrawal(Object method) {
    return '$method 出金';
  }

  @override
  String transferDetailDeposit(Object method) {
    return '$method 入金详情';
  }

  @override
  String transferDetailWithdrawal(Object method) {
    return '$method 出金详情';
  }

  @override
  String bankTypeOwner(Object type, Object owner) {
    return '$type · 户名 $owner';
  }

  @override
  String get fundPleaseEnterADeposit => '请输入入金金额';

  @override
  String fundMinimumDepositIs(Object v0) {
    return '单笔最低入金 $v0';
  }

  @override
  String fundMaximumDepositIs(Object v0) {
    return '单笔最高入金 $v0';
  }

  @override
  String get fundPleaseEnterAWithdrawal => '请输入出金金额';

  @override
  String fundMinimumWithdrawalIs(Object v0) {
    return '单笔最低出金 $v0';
  }

  @override
  String fundExceedsYourAvailableTo(Object v0) {
    return '超过可提现金额 $v0';
  }

  @override
  String fundMaximumWithdrawalIs(Object v0) {
    return '单笔最高出金 $v0';
  }

  @override
  String get fundInitiated => '已发起';

  @override
  String get fundPending => '处理中';

  @override
  String get fundProcessing => '处理中';

  @override
  String get fundApproved => '已批准';

  @override
  String get fundCompleted => '已完成';

  @override
  String get fundFailed => '失败';

  @override
  String get fundReturned => '已退回';

  @override
  String get fundOnHold => '暂缓处理';

  @override
  String get fundBuyingPowerIsGranted => '结算后授予购买力，通常 4–5 个工作日（待 DW 确认）';

  @override
  String get fundUsually45Business => '通常 4–5 个工作日（待 DW 确认）';

  @override
  String get fundBankAccount => '银行账户';

  @override
  String get fundSavings => '储蓄账户';

  @override
  String get fundChecking => '支票账户';

  @override
  String get bankYourAccountIsCurrently => '账户当前受限，暂不能进行资金操作。如有疑问请联系客服。';

  @override
  String get bankUnlinkBankAccount => '解绑银行账户？';

  @override
  String bankOnceUnlinkedCanNo(Object displayName) {
    return '$displayName 解绑后不能再用于入金和出金。';
  }

  @override
  String get bankUnlink => '解绑';

  @override
  String get bankUnlinked => '已解绑';

  @override
  String bankLinked(Object length, Object maxBanks) {
    return '已绑定（$length/$maxBanks）';
  }

  @override
  String get bankNoBankAccountsLinked =>
      '还没有绑定银行账户。绑定本人名下的美国银行账户后，即可通过 ACH 入金和出金。';

  @override
  String bankYouCanLinkUp(Object maxBanks) {
    return '每个账户最多绑定 $maxBanks 个银行账户。如需更换，请先解绑。';
  }

  @override
  String get bankYouCanOnlyLink => '只能绑定本人名下的美国银行账户。没有美国银行账户？可以改用电汇入金。';

  @override
  String get bankViewWireInstructions => '查看电汇入金信息';

  @override
  String get bankLinkANewBank => '绑定新银行账户';

  @override
  String get bankEnterAValid9 => '请输入有效的 9 位 ABA 路由号码';

  @override
  String get bankEnterA417 => '请输入 4–17 位银行账号';

  @override
  String get bankNicknameCanBeUp => '备注名最多 30 个字';

  @override
  String get bankNicknameCanTBe => '备注名不能与账号相同';

  @override
  String get bankBankAccountLinked => '银行账户绑定成功';

  @override
  String get bankLinkBankAccount => '绑定银行账户';

  @override
  String get bankAccountsInYourOwn => '只能绑定本人名下的账户';

  @override
  String get bankTheAccountHolderIs => '户名按开户姓名登记，第三方账户的转账会被退回';

  @override
  String get bankUsBankAccountsOnly => '仅支持美国银行账户';

  @override
  String get bankNoUsBankAccount => '没有美国银行账户？请改用电汇';

  @override
  String get bankAccountNumberEncryptedIn => '账号加密传输';

  @override
  String get bankWeOnlyShowThe => '我们只显示账号尾号';

  @override
  String get bankRoutingNumberAba => '路由号码（ABA Routing Number）';

  @override
  String get bank9Digits => '9 位数字';

  @override
  String get bankAccountNumber => '银行账号';

  @override
  String get bank417Digits => '4–17 位数字';

  @override
  String get bankAccountType => '账户类型';

  @override
  String get bankNicknameOptional => '备注名（选填）';

  @override
  String get bankEGPaycheckAccount => '如：工资卡';

  @override
  String get bankLink => '绑定';

  @override
  String get bankBeneficiary => '收款人';

  @override
  String get bankBeneficiaryBank => '收款银行';

  @override
  String get bankBankAddress => '银行地址';

  @override
  String get bankAccountNumber2 => '收款账号';

  @override
  String get bankAbaRoutingNumber => 'ABA 路由号码';

  @override
  String get bankReferenceRequired => '附言（必填）';

  @override
  String get bankWireDeposit => '电汇入金';

  @override
  String get bankSendTheWireFrom =>
      '请从本人名下的银行账户汇款，并在附言中填写下方内容（含您的账户号码），否则可能无法入账。';

  @override
  String bankCopied(Object value) {
    return '$value已复制';
  }

  @override
  String get bankIntermediaryBankFeesAre =>
      '中转行费用由汇款方承担；到账时间以银行实际到账为准（待 DW 确认）。电汇入金不受 ACH 观察期限制。';

  @override
  String get xferTransactionId => '流水号';

  @override
  String get xferMethod => '方式';

  @override
  String get xferAmount => '金额';

  @override
  String get xferViewTransferHistory => '查看资金记录';

  @override
  String get xferDepositRecorded => '入金已记录';

  @override
  String get xferDepositSubmitted => '入金已提交';

  @override
  String get xferTheBrokerHasnT => '券商受理结果暂未确认，我们会自动核对，请稍后在资金记录中查看状态。请勿重复提交。';

  @override
  String xferTheArrivalDateIs(Object buyingPowerFallback) {
    return '$buyingPowerFallback。到账日期以资金记录中券商返回的日期为准。';
  }

  @override
  String get xferChooseADepositMethod => '选择入金方式';

  @override
  String get xferBankTransferAch => '银行转账（ACH）';

  @override
  String get xferLinkAUsBank => '需先绑定本人名下的美国银行账户';

  @override
  String xferUsBankAccountS(Object length) {
    return '已绑定 $length 个本人美国银行账户 · 免手续费';
  }

  @override
  String get xferWireTransfer => '电汇';

  @override
  String get xferSendFromABank => '从本人名下银行账户汇款，适用于境外银行或大额入金';

  @override
  String xferWireTimingDependsOn(
    Object buyingPowerFallback,
    Object seasoningFallback,
  ) {
    return '$buyingPowerFallback。$seasoningFallback。电汇以银行实际到账时间为准，不受观察期限制。每笔入金的实际日期以券商返回为准（见资金记录）。';
  }

  @override
  String get xferWeOnlyAcceptFunds => '只接受来自本人名下账户的资金，第三方转账将被退回。';

  @override
  String get xferConfirmDeposit => '确认入金';

  @override
  String get xferDepositAmount => '入金金额';

  @override
  String get xferFrom => '从';

  @override
  String get xferTo => '到';

  @override
  String get xferYourBrokerageAccountHeld => '本人证券账户（DriveWealth 托管）';

  @override
  String get xferFee => '手续费';

  @override
  String get xferBuyingPowerAvailable => '购买力到账';

  @override
  String get xferByConfirmingYouAuthorize =>
      '确认即授权从上述银行账户扣款。资金由 DriveWealth 托管。';

  @override
  String get xferEdit => '返回修改';

  @override
  String get xferAchDeposit => 'ACH 入金';

  @override
  String get xferFromBankAccount => '转出银行账户';

  @override
  String xferManageBankAccounts(Object length, Object maxBanks) {
    return '管理银行账户（$length/$maxBanks）';
  }

  @override
  String get xferDepositAmountUsd => '入金金额 (USD)';

  @override
  String xferPerTransferUpTo(Object v0, Object v1, Object v2) {
    return '单笔 $v0 – $v1，每日上限 $v2（示例值，以券商为准）';
  }

  @override
  String get xferSubmissionCutoff => '提交截止时间';

  @override
  String xferBusinessDaysEtSample(Object achCutoffEt) {
    return '工作日 $achCutoffEt ET（示例，待 DW 确认）';
  }

  @override
  String get xferWithdrawable => '可提现时间';

  @override
  String get xferReturnNoticeIfYour =>
      '退回提示：如银行退回此笔转账（如余额不足），使用该笔资金买入的证券可能被限制卖出，并可能产生退回费用；账户入金功能也可能被暂停。';

  @override
  String get xferWithdrawalRecorded => '出金已记录';

  @override
  String get xferWithdrawalSubmitted => '出金已提交';

  @override
  String xferAchWithdrawals(Object achWithdrawalArrival) {
    return 'ACH 出金$achWithdrawalArrival。';
  }

  @override
  String get xferConfirmWithdrawal => '确认出金';

  @override
  String get xferWithdrawalAmount => '出金金额';

  @override
  String get xferYourBrokerageAccount => '本人证券账户';

  @override
  String get xferEstimatedArrival => '预计到账';

  @override
  String get xferAvailableToWithdraw => '可提现金额';

  @override
  String get xferAccountCash => '账户现金';

  @override
  String get xferUnsettledFunds => '未结算资金';

  @override
  String get xferInAchHoldingPeriod => 'ACH 入金观察期内金额';

  @override
  String xferYourAvailableToWithdraw(Object seasoningFallback) {
    return '可提现金额以券商（DriveWealth）返回为准。$seasoningFallback；电汇入金不受此限制。';
  }

  @override
  String get xferWireWithdrawalsArenT =>
      '电汇出金暂不在本次演示范围（后端已支持，待沙盒实测后开放）。电汇只能汇入本人名下的银行账户，收款人固定为账户持有人。';

  @override
  String get xferToBankAccount => '收款银行账户';

  @override
  String get xferNoBankAccountLinked => '尚未绑定银行账户。';

  @override
  String get xferWithdrawalAmountUsd => '出金金额 (USD)';

  @override
  String xferPerTransferAndNo(Object v0, Object v1) {
    return '单笔 $v0 – $v1，且不超过可提现金额';
  }

  @override
  String get xferTransferHistory => '资金记录';

  @override
  String get xferDeposits => '入金';

  @override
  String get xferWithdrawals => '出金';

  @override
  String get xferNoTransfersYet => '暂无资金记录';

  @override
  String get xferShowingYour50Most => '显示最近 50 条资金记录。交易、分红与公司行动记录不在本次演示范围。';

  @override
  String get xferFromAccount => '转出账户';

  @override
  String get xferToAccount => '收款账户';

  @override
  String get xferBuyingPowerAvailable2 => '购买力可用日';

  @override
  String get xferPendingBrokerUpdate => '待券商返回';

  @override
  String get xferWithdrawableOn => '可提现日';

  @override
  String xferText(Object buyingPowerFallback, Object seasoningFallback) {
    return '$buyingPowerFallback；$seasoningFallback。';
  }

  @override
  String xferReason(Object failureReason) {
    return '原因：$failureReason';
  }

  @override
  String featureComingSoon(Object title) {
    return '$title即将上线';
  }

  @override
  String mastersLastPrice(Object price) {
    return '最新价 $price';
  }

  @override
  String get demoNorthshoreCapital => '北岸资本';

  @override
  String get demoNorthshoreCapitalSample => 'Northshore Capital (示例)';

  @override
  String get demoLongbridgeFund => '长桥基金';

  @override
  String get demoLongbridgeFundSample => 'Longbridge Fund (示例)';

  @override
  String get demoFarhillInvestments => '远山投资';

  @override
  String get demoFarhillInvestmentsSample => 'Farhill Investments (示例)';

  @override
  String get demoMorningBayAm => '晨湾资管';

  @override
  String get demoMorningBayAmSample => 'Morning Bay AM (示例)';

  @override
  String get demoBluestonePartners => '青石合伙';

  @override
  String get demoBluestonePartnersSample => 'Bluestone Partners (示例)';

  @override
  String get demoCoastlineValue => '海岸价值';

  @override
  String get demoCoastlineValueSample => 'Coastline Value (示例)';

  @override
  String get demoPinewoodGlobal => '松林全球';

  @override
  String get demoPinewoodGlobalSample => 'Pinewood Global (示例)';

  @override
  String get demoGalaxyQuant => '星河量化';

  @override
  String get demoGalaxyQuantSample => 'Galaxy Quant (示例)';

  @override
  String get demoMostIncreased => '增持最多';

  @override
  String get demoContrarianBuys => '逆势增持';

  @override
  String get demoMostHeld => '持股最多';

  @override
  String get demoNewPositions => '新进持股';

  @override
  String get demoPortfolioCheckup => '持仓体检';

  @override
  String get demoAnalyzeYourHoldingsAnd => '分析持仓结构与未实现盈亏';

  @override
  String get demoHoldOrSell => '持有或卖出';

  @override
  String get demoCompareTrendsRiskAnd => '对比趋势、风险与仓位';

  @override
  String get demoStockResearch => '个股研究';

  @override
  String get demoPricesFundamentalsAndNews => '汇总价格、基本面与新闻';

  @override
  String get demoRiskAlerts => '风险提醒';

  @override
  String get demoSpotVolatilityConcentrationAnd => '识别波动、集中度与回撤';

  @override
  String get demoQuantSignals => '量化信号';

  @override
  String get demoMomentumReversalVolumeAnd => '动量、反转、成交量等因子';

  @override
  String get demoInvesting101 => '投资课堂';

  @override
  String get demoUnderstandInvestingInPlain => '用简单的语言理解投资逻辑';

  @override
  String get demoFinxSportsBottle => 'FinX 运动水壶';

  @override
  String get demoFifiHolidayBeanie => 'Fifi 圣诞绒帽';

  @override
  String get demoWirelessHeadphones => '无线耳机';

  @override
  String get demoFifiCrossbodyBag => 'Fifi 斜挎包';

  @override
  String get mastersComingSoon => '即将上线';

  @override
  String get mastersSeeWhatTheBig => '看看大机构在买什么';

  @override
  String get mastersBasedOnPublic13f => '基于公开的 13F 持仓申报，按季度更新';

  @override
  String get mastersTopReturns => '收益最高';

  @override
  String get mastersRecentlyUpdated => '最近更新';

  @override
  String get mastersMore => '更多';

  @override
  String get mastersStockIdeas => '个股机会';

  @override
  String get mastersQ32026 => '2026 年第三季度';

  @override
  String get mastersDataComesFromPublic =>
      '数据来源于机构公开申报（演示数据），存在披露滞后，不代表机构当前持仓，不构成投资建议。';

  @override
  String get mastersDemoDataInstitutionNames => '演示数据：机构名称、收益与持仓均为虚构，仅供展示';

  @override
  String get masters1YrReturn => '年收益';

  @override
  String get mastersSymbol => '代码';

  @override
  String get mastersIncreaseAsOfShares => '增持占总股本';

  @override
  String get mastersIncreasedUnchangedDecreased => '增 / 平 / 减 家数';

  @override
  String get mastersAllInstitutions => '全部机构';

  @override
  String get mastersNameFirm => '名称 / 公司';

  @override
  String get mastersReturn => '收益';

  @override
  String get mastersAumGrowth => '资产增速';

  @override
  String get mastersUpdated => '更新';

  @override
  String get mastersDemoDataAllInstitution => '演示数据：机构名称均为虚构示例';

  @override
  String get mastersInstitutionDetails => '机构详情';

  @override
  String get mastersInstitutionNotFound => '未找到该机构';

  @override
  String get mastersPleaseGoBackAnd => '请返回列表重新选择';

  @override
  String get mastersTop5HoldingsSample => '前五大持仓（示例）';

  @override
  String get mastersDemoDataInstitutionsAnd => '演示数据：机构与持仓均为虚构；个股价格为虚拟行情';

  @override
  String get mastersAiAssistant => 'AI 助手';

  @override
  String get mastersNotIncludedInThe => '首期不做，待合规评估。以下为保留的页面规格，仅供评估，不会在首期上线。';

  @override
  String get mastersFifiQuantAssistant => 'Fifi 量化助手';

  @override
  String get mastersComingSoon2 => '即将推出';

  @override
  String get mastersFifiIsLearningTo => 'Fifi 正在学习分析图表、风险和持仓，敬请期待。';

  @override
  String get mastersBeforeLaunchWeNeed => '上线前需评估是否构成投资建议。';

  @override
  String get mastersLaunchReminderOn => '已订阅上线提醒';

  @override
  String get mastersRemindMeAtLaunch => '上线提醒我';

  @override
  String get mastersReminderCanceled => '已取消提醒';

  @override
  String get mastersDemoDataFeaturesShown => '演示数据：功能为规划展示，暂未上线';

  @override
  String rewardsLevel(Object lv, Object rewardSoon) {
    return '等级 $lv $rewardSoon';
  }

  @override
  String get rewardsHolidayStarterGifts => '圣诞新手礼';

  @override
  String get rewardsUnlocksAtLevel1 => '等级 1 解锁';

  @override
  String get rewardsRewardsShownAreDemo => '奖励内容为演示示例，正式奖品与兑换规则以上线公告为准';

  @override
  String get rewardsFifiRewards => 'Fifi 奖励';

  @override
  String get rewardsHolidayFifi => '圣诞 Fifi';

  @override
  String get rewardsHolidayNewYearLimited => '圣诞 · 新年限定';

  @override
  String get rewardsFifiHolidayShop => 'Fifi 圣诞商店\n';

  @override
  String get rewardsOpeningSoon => '即将开启';

  @override
  String get rewardsCompleteTasksToEarn => '完成任务赚取 XP，解锁节日服饰、房间与新年梦想好礼。';

  @override
  String rewardsLevel2(Object level) {
    return '等级 $level';
  }

  @override
  String get rewardsReminderOn => '✓ 已开启提醒';

  @override
  String get rewardsRemindMeAtLaunch => '🔔 开启上线提醒';

  @override
  String get serverReasonRejected => '券商已拒绝该订单';

  @override
  String get serverReasonCanceled => '订单已撤销';

  @override
  String get serverReasonTransfer => '券商返回了失败原因，请联系客服了解详情';

  @override
  String get tradeMinOrder => '单笔最低 \$1.00（示例值，以券商为准）';

  @override
  String homeTodayChange(Object amount, Object pct) {
    return '今日 $amount$pct';
  }

  @override
  String get homeTodayHidden => '今日 ****';

  @override
  String get tabPredict => '预测';

  @override
  String get predictTitle => '预测';

  @override
  String predictPoints(Object points) {
    return '$points 分';
  }

  @override
  String get predictDemoBadge => '积分预测 · 演示模式，非真实资金';

  @override
  String get predictCatAll => '全部';

  @override
  String get predictCatCrypto => '加密';

  @override
  String get predictCatStocks => '美股';

  @override
  String get predictCatMacro => '宏观';

  @override
  String get predictCatSports => '体育';

  @override
  String get predictCatTrending => '热点';

  @override
  String predictUpOrDownSymbol(Object symbol) {
    return '涨 或 跌 · $symbol';
  }

  @override
  String get predictUpOrDown => '涨 或 跌';

  @override
  String predictTarget(Object price) {
    return '目标 $price · 窗口结束时结算';
  }

  @override
  String predictUpPct(Object pct) {
    return '上涨 · $pct%';
  }

  @override
  String predictDownPct(Object pct) {
    return '下跌 · $pct%';
  }

  @override
  String get predictUp => '上涨';

  @override
  String get predictDown => '下跌';

  @override
  String get predict15m => '15 分钟市场';

  @override
  String get predictSeeAll => '全部';

  @override
  String get predictTrending => '热门市场';

  @override
  String get predictLive => 'Live';

  @override
  String predictLiveSettle(Object date) {
    return 'Live · $date结算';
  }

  @override
  String predictCloses(Object date) {
    return '$date 截止';
  }

  @override
  String get predictDisclaimer => '预测为用户观点聚合，仅供参考，不构成投资建议';

  @override
  String get predictMine => '我的预测';

  @override
  String get predictNoMarkets => '该分类暂无进行中的市场';

  @override
  String predictLoadFailed(Object error) {
    return '预测市场暂时无法加载：$error';
  }

  @override
  String predictYourPick(Object label) {
    return '你的预测：$label';
  }

  @override
  String get predictStake => '下注积分';

  @override
  String get predictStakeHint => '10–5,000 的整数';

  @override
  String predictAvailable(Object points) {
    return '可用 $points 分';
  }

  @override
  String predictPotential(Object points) {
    return '若正确可得 $points 分';
  }

  @override
  String predictProbNow(Object pct) {
    return '当前概率 $pct%';
  }

  @override
  String get predictPricingNote => '赔率按下注时的比例确定，比例随双边下注实时变化（演示用简化模型）。';

  @override
  String get predictConfirm => '确认预测';

  @override
  String predictPlaced(Object points) {
    return '预测已提交，若正确可得 $points 分';
  }

  @override
  String get predictStakeInvalid => '请输入 10–5,000 的整数积分';

  @override
  String get predictStakeInsufficient => '积分不足';

  @override
  String get predictClosedNow => '该市场已截止';

  @override
  String get predictHitRate => '命中率';

  @override
  String get predictNetPoints => '累计盈亏';

  @override
  String get predictSettledCount => '已结算';

  @override
  String predictClaimable(Object points) {
    return '待领取 $points 分';
  }

  @override
  String get predictClaim => '领取';

  @override
  String predictClaimedToast(Object points) {
    return '已领取 $points 分';
  }

  @override
  String get predictTabOpen => '进行中';

  @override
  String get predictTabSettled => '已结算';

  @override
  String get predictNoBets => '还没有预测，去预测页选一个市场吧。';

  @override
  String get predictStatusOpen => '进行中';

  @override
  String get predictStatusWon => '命中';

  @override
  String get predictStatusLost => '未命中';

  @override
  String get predictStatusVoid => '作废退回';

  @override
  String predictStakeLine(Object stake, Object payout) {
    return '下注 $stake 分 · 若正确可得 $payout 分';
  }

  @override
  String predictPaidLine(Object stake, Object payout) {
    return '下注 $stake 分 · 派彩 $payout 分';
  }

  @override
  String get predictClaimedTag => '已领取';

  @override
  String predictSettlesAt(Object price) {
    return '结算价 $price';
  }

  @override
  String get srvPredictStake => '下注积分须在 10–5,000 分之间';

  @override
  String get srvPredictOutcome => '请选择预测方向';

  @override
  String get srvPredictInsufficient => '预测积分不足';

  @override
  String get srvPredictClosed => '该预测市场已截止';

  @override
  String get srvPredictNotFound => '预测市场不存在';

  @override
  String predictMonthDay(Object month, Object day) {
    return '$month月$day日';
  }

  @override
  String get welcomeSlogan1 => '美股与 ETF 投资';

  @override
  String get welcomeSlogan2 => '开户、入金、交易，一站完成。';

  @override
  String get welcomeLogIn => '登录';

  @override
  String get welcomeBrowseMarkets => '先逛逛行情';

  @override
  String get appearanceTitle => '外观';

  @override
  String get appearanceSystem => '跟随系统';

  @override
  String get appearanceLight => '浅色';

  @override
  String get appearanceDark => '深色';

  @override
  String get errSubmitUnconfirmedFunding =>
      '网络超时，提交结果确认中。请先到资金记录中查看；再次点击提交不会重复申请。';

  @override
  String get errSubmitUnconfirmedOrder => '网络超时，订单结果确认中。请先到订单中查看；再次点击提交不会重复下单。';

  @override
  String get srvIdemKeyReusedTransfer => '这笔申请的内容已变化，请返回后重新提交。';

  @override
  String get srvIdemKeyReusedOrder => '这笔订单的内容已变化，请返回后重新下单。';

  @override
  String get statusUnconfirmed => '未确认';

  @override
  String get xferUnconfirmedNotice =>
      '券商结果待人工核对。请勿重复提交，我们核对后会更新这笔记录；如有疑问请联系客服。';

  @override
  String get ordersUnconfirmedNotice =>
      '券商结果待人工核对，该订单不能撤单。请勿重复下单，我们核对后会更新这笔订单；如有疑问请联系客服。';

  @override
  String fundAchHoldingPeriod(int days) {
    return 'ACH 入金到账后默认 $days 天观察期内不可提现，可由 DW 配置调整（待 DW 确认）';
  }

  @override
  String xferAfterHoldingPeriod(int days) {
    return '到账后 $days 天观察期结束（默认，待 DW 确认）';
  }

  @override
  String get assetHeroTotal => '总资产 (USD)';

  @override
  String get assetHeroTotalPaper => '模拟 · 总资产 (USD)';

  @override
  String get assetHeroToday => '今日';

  @override
  String get assetHeroTotalPL => '累计盈亏';

  @override
  String get assetIntradayBuilding => '日内数据积累中';

  @override
  String get assetHistoryBuilding => '记录积累中';

  @override
  String get assetFilterAll => '全部';

  @override
  String get assetFilterStock => '股票';

  @override
  String get assetFilterEtf => 'ETF';

  @override
  String get assetTotalValue => '总价值';

  @override
  String get assetOthers => '其他';

  @override
  String get assetNoStockHoldings => '暂无股票持仓';

  @override
  String get assetNoEtfHoldings => '暂无 ETF 持仓';

  @override
  String get assetShowAmounts => '显示金额';

  @override
  String get assetHideAmounts => '隐藏金额';

  @override
  String get watchLiveNote => '实时报价 · 3 秒刷新';

  @override
  String drawerWithdrawable(String amount) {
    return '可提现 $amount';
  }

  @override
  String get marketUsMarket => '美国市场';

  @override
  String get marketSearch => '搜索';

  @override
  String get marketSearchHint => '搜索代码或名称';

  @override
  String get marketSearchNoResults => '未找到相关标的';

  @override
  String get marketStats => '市场统计';

  @override
  String get marketStatsToday => '今日';

  @override
  String get marketStats30d => '近 30 日';

  @override
  String get marketStatsBuilding => '数据积累中';

  @override
  String marketStatsBuildingSince(String date) {
    return '数据积累中 · 自 $date 起记录';
  }

  @override
  String marketStatsDown(int n) {
    return '下跌 $n';
  }

  @override
  String marketStatsUp(int n) {
    return '上涨 $n';
  }

  @override
  String get marketStatsNote => '统计标的池全部股票与 ETF（虚拟行情）';

  @override
  String get marketInsiders => '内部人交易';

  @override
  String get demoDataBadge => '演示数据';

  @override
  String get insiderTopBuy => '买入最多';

  @override
  String get insiderTopSell => '卖出最多';

  @override
  String get insiderMostActive => '最活跃';

  @override
  String insiderBought(String amount) {
    return '买入 $amount';
  }

  @override
  String insiderSold(String amount) {
    return '卖出 $amount';
  }

  @override
  String insiderTrades(int n) {
    return '交易 $n 次';
  }

  @override
  String get insiderMoreComingSoon => '内部人交易明细即将上线';

  @override
  String get orderDoneTitle => '下单成功';

  @override
  String get orderDoneSummary => '成交摘要';

  @override
  String get orderDoneSymbol => '代码';

  @override
  String get orderDonePrice => '成交价';

  @override
  String get orderDoneQty => '数量';

  @override
  String get orderDoneTotal => '总金额';

  @override
  String get orderDoneTime => '时间';

  @override
  String get orderDoneBackHome => '返回首页';

  @override
  String xpPill(String xp) {
    return '$xp XP';
  }

  @override
  String get fifiTitle => 'Fifi 量化助手';

  @override
  String get fifiSubtitle => '你的智能投资助理';

  @override
  String get fifiHeroTitle => '即将上线';

  @override
  String get fifiHeroBody => 'Fifi 正在学习为你解读图表、风险与持仓。';

  @override
  String get fifiFeat1 => '持仓体检';

  @override
  String get fifiFeat1Desc => '分析你的持仓与未实现盈亏。';

  @override
  String get fifiFeat2 => '持有或卖出';

  @override
  String get fifiFeat2Desc => '行动前对比趋势、风险与仓位。';

  @override
  String get fifiFeat3 => '个股研究';

  @override
  String get fifiFeat3Desc => '汇总价格走势、基本面与新闻信号。';

  @override
  String get fifiFeat4 => '风险预警';

  @override
  String get fifiFeat4Desc => '提示波动、集中度与下行压力。';

  @override
  String get fifiFeat5 => '量化信号';

  @override
  String get fifiFeat5Desc => '跟踪动量、反转、成交量与因子分。';

  @override
  String get fifiFeat6 => '跟 Fifi 学投资';

  @override
  String get fifiFeat6Desc => '用简单清晰的语言理解投资逻辑。';

  @override
  String get fifiRemind => '开启上线提醒';

  @override
  String get fifiRemindOn => '已开启上线提醒';

  @override
  String get fifiRemindCaption => 'Fifi 量化助手就绪时，我们会第一时间通知你。';

  @override
  String get storeTitle => 'Fifi 商店';

  @override
  String storeTier(int n) {
    return '等级 $n';
  }

  @override
  String get storeDream => '梦想';

  @override
  String storeTierNew(int n) {
    return '等级 $n 上新';
  }

  @override
  String get storeTierEmpty => '该等级商品即将上新';

  @override
  String storeTierLocked(int n) {
    return '达到等级 $n 后解锁';
  }

  @override
  String get storeAvailable => '可兑换';

  @override
  String get storeNotEnoughXp => 'XP 不足';

  @override
  String storeUnlockAt(int n) {
    return '等级 $n 解锁';
  }

  @override
  String storeBundleXp(String xp) {
    return '套装 · $xp XP';
  }

  @override
  String get storePreview => '预 览';

  @override
  String get storeComingSoon => '敬请期待';

  @override
  String get storePreviewOnFifi => '在 Fifi 上预览';

  @override
  String get storePreviewOnFifiSoon => '在 Fifi 上预览即将上线';

  @override
  String get storeEarnXp => '赚取 XP';

  @override
  String get storeRedeemSoon => '兑换即将开启';

  @override
  String get storeSearchSoon => '商店搜索即将上线';

  @override
  String get storeImagePlaceholder => '示意图，正式图片即将更新';

  @override
  String get storeDemoNote => 'XP 为站内成长值，不可兑换现金；商品与兑换规则以上线公告为准。';

  @override
  String get earnTitle => 'Fifi 奖励任务';

  @override
  String get earnToday => '今日任务';

  @override
  String earnResetIn(String time) {
    return '$time 后重置';
  }

  @override
  String get earnTask1 => '每日签到';

  @override
  String get earnTask1Desc => '保持你的连续记录';

  @override
  String get earnTask2 => '跟 Fifi 学一课';

  @override
  String get earnTask2Desc => '完成一节市场小课堂';

  @override
  String get earnTask3 => '运行持仓体检';

  @override
  String get earnTask3Desc => '检查你的资金健康度';

  @override
  String get earnTask4 => '本月储蓄目标';

  @override
  String get earnTask4Desc => '完成本月入金小目标';

  @override
  String get earnTask5 => '分享一次 FinX';

  @override
  String get earnTask5Desc => '邀请一位朋友一起学习';

  @override
  String earnXpPlus(int xp) {
    return '+$xp XP';
  }

  @override
  String get earnTaskSoon => '该任务即将开启';

  @override
  String earnCheckedIn(int xp) {
    return '签到成功 +$xp XP';
  }

  @override
  String get earnAlreadyCheckedIn => '今日已签到';

  @override
  String earnStreak(int n) {
    return '连续 $n 天';
  }

  @override
  String get earnKeepGoing => '继续保持！';

  @override
  String get earnStartStreak => '今天签到，开启连续记录';

  @override
  String get earnWeekdays => '一,二,三,四,五,六,日';

  @override
  String get earnGoWardrobe => '前往 Fifi 衣橱';

  @override
  String get earnLoadFailed => '任务加载失败，请下拉重试';

  @override
  String get searchTypeStock => '股票';
}
