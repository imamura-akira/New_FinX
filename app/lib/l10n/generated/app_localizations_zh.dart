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
}
