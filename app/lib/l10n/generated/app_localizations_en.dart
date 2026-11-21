// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get langTitle => 'Language / 语言';

  @override
  String get langSystem => 'Use System Setting';

  @override
  String get langZh => '简体中文';

  @override
  String get langEn => 'English';

  @override
  String get tabAssets => 'Assets';

  @override
  String get tabMarkets => 'Markets';

  @override
  String get tabMasters => 'Masters';

  @override
  String get tabFifi => 'Fifi';

  @override
  String get tabRewards => 'Rewards';

  @override
  String get errUnauthorized => 'Please sign in to continue.';

  @override
  String get errSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errRestricted =>
      'Your account is currently restricted, so this action isn\'t available.';

  @override
  String get errConflict =>
      'This action can\'t be completed right now. Please refresh and try again.';

  @override
  String get errValidation => 'Please check the highlighted fields.';

  @override
  String get errLimit => 'The amount is outside the allowed range.';

  @override
  String get errRateLimited =>
      'Too many requests. Please try again in a moment.';

  @override
  String get errInternal =>
      'Something went wrong on our end. Please try again later.';

  @override
  String get errDwFailed =>
      'Our brokerage partner is temporarily unavailable. Please try again later.';

  @override
  String get errDwBadData =>
      'We received unexpected data from our brokerage partner. Please try again later.';

  @override
  String get errNotEnabled => 'This feature isn\'t available yet.';

  @override
  String get errNetwork =>
      'Can\'t connect. Check your internet connection and try again.';

  @override
  String get errTimeout => 'The request timed out. Please try again.';

  @override
  String get errBadResponse =>
      'We couldn\'t read the server response. Please try again later.';

  @override
  String get srvAccountNotOpened =>
      'Your brokerage account hasn\'t been opened yet.';

  @override
  String get srvAccountNotActive => 'Your brokerage account isn\'t active yet.';

  @override
  String get srvOrderNotCancelable =>
      'This order can\'t be canceled in its current status.';

  @override
  String get srvOrderNotFound => 'Order not found.';

  @override
  String get srvBankNotFound =>
      'This bank account doesn\'t exist or has been unlinked.';

  @override
  String get srvPlaidNotEnabled =>
      'Linking a bank account through Plaid isn\'t available yet.';

  @override
  String get srvBankBusy =>
      'This bank account has a transfer in progress. You can unlink it once the transfer completes.';

  @override
  String get srvNoLegalNameBank =>
      'We couldn\'t find the name on your account, so a bank account can\'t be linked yet.';

  @override
  String get srvNoLegalNameWithdraw =>
      'We couldn\'t find the name on your account, so withdrawals aren\'t available yet.';

  @override
  String get srvCancelNotAccepted =>
      'The cancel request wasn\'t accepted by the broker. The order may have already filled. Please refresh to check.';

  @override
  String get srvDupWithdrawal =>
      'You just submitted a withdrawal for the same amount. Please don\'t submit it again.';

  @override
  String get srvDupDeposit =>
      'You just submitted a deposit for the same amount. Please don\'t submit it again.';

  @override
  String get srvDupOrder =>
      'You just submitted the same order. Please don\'t submit it again.';

  @override
  String get srvOauthLater =>
      'Sign in with Google or Apple is coming in a future release. Please sign in with an email code for now.';

  @override
  String get srvRestrictedSellOnly =>
      'Your account is currently limited to selling. Buying isn\'t available.';

  @override
  String get errRequestFailed => 'The request failed. Please try again later.';

  @override
  String get errFieldInvalid => 'Please check this field.';

  @override
  String get commonBack => 'Back';

  @override
  String get expiredPleaseSignInAgain => 'Please sign in again';

  @override
  String get expiredYourSessionHasExpired =>
      'Your session has expired or you\'re not signed in. Return to the app and sign in to continue your application.';

  @override
  String get expiredBackToSignIn => 'Back to Sign In';

  @override
  String get welcomeInvestInUsStocks =>
      'Invest in US stocks and ETFs — open an account, fund it, and trade, all in one place.';

  @override
  String get welcomeSignUp => 'Sign Up';

  @override
  String get welcomeSignIn => 'Sign In';

  @override
  String get welcomeBrowseMarketsFirst => 'Browse Markets First';

  @override
  String get welcomeBrokerageServicesAreProvided =>
      'Brokerage services are provided by our partner broker. Investing involves risk.';

  @override
  String get loginPleaseEnterAValid => 'Please enter a valid email address.';

  @override
  String get loginVerificationCodeSent => 'Verification code sent';

  @override
  String get loginPleaseEnterThe6 => 'Please enter the 6-digit code.';

  @override
  String get loginPleaseAgreeToThe => 'Please agree to the Terms first.';

  @override
  String loginSignInWithIs(Object provider) {
    return 'Sign in with $provider is coming in a future release. Please sign in with an email code for now.';
  }

  @override
  String get loginEmail => 'Email';

  @override
  String get loginVerificationCode => 'Verification Code';

  @override
  String get login6DigitCode => '6-digit code';

  @override
  String get loginDemoVerificationCode000000 =>
      'Demo verification code: 000000';

  @override
  String loginResendInS(Object _countdown) {
    return 'Resend in ${_countdown}s';
  }

  @override
  String get loginResendCode => 'Resend Code';

  @override
  String get loginGetCode => 'Get Code';

  @override
  String get loginOr => 'or';

  @override
  String get loginContinueWithGoogle => 'Continue with Google';

  @override
  String get loginContinueWithApple => 'Continue with Apple';

  @override
  String get loginSignInWithGoogle =>
      'Sign in with Google and Apple is coming in a future release. Whenever Google sign-in is offered, Apple sign-in will be offered too.';

  @override
  String get loginIHaveReadAnd =>
      'I have read and agree to the platform\'s Terms of Service and Privacy Policy\n';

  @override
  String get loginTheseAreThePlatform =>
      'These are the platform\'s own terms. DriveWealth\'s brokerage disclosures will be shown separately when you open an account.';

  @override
  String get loginSignUpSignIn => 'Sign Up & Sign In';

  @override
  String get assetStock => 'Stocks';

  @override
  String get assetEtf => 'ETFs';

  @override
  String get assetCash => 'Cash';

  @override
  String get rangeAll => 'All';

  @override
  String rangeDays(Object days) {
    return '${days}D';
  }

  @override
  String cueReferenceNo(Object ref) {
    return 'Reference No. $ref';
  }

  @override
  String get homePaperAccountHasBeen => 'Paper account has been reset';

  @override
  String get homeCouldnTRefreshPlease =>
      'Couldn\'t refresh. Please try again later.';

  @override
  String get homeAccount => 'Account';

  @override
  String homeCouldnTRefreshYour(Object error) {
    return 'Couldn\'t refresh your account data: $error';
  }

  @override
  String homeAccountDataFromDrivewealth(Object v0) {
    return 'Account data from DriveWealth · Updated $v0';
  }

  @override
  String get homeDepositsInTransitNot =>
      'Deposits in transit (not yet in buying power)';

  @override
  String get homeNotYetWithdrawableHolding =>
      'Not yet withdrawable (holding period)';

  @override
  String get homePendingSettlement => 'Pending settlement';

  @override
  String get homeFundYourAccountTo => 'Fund your account to start investing';

  @override
  String get homeLinkYourOwnUs =>
      'Link your own US bank account (ACH) and transfer funds';

  @override
  String get homeDeposit => 'Deposit';

  @override
  String get homeBrowseMarketsFirst => 'Browse Markets First';

  @override
  String get homeTrading => 'Trading';

  @override
  String get homePositions => 'Positions';

  @override
  String get homeQuantityMarketValueCost =>
      'Quantity, market value, cost, and P&L (from the broker)';

  @override
  String get homeOrders => 'Orders';

  @override
  String get homeCheckOrderStatusAnd =>
      'Check order status and cancel open orders';

  @override
  String get homeWatchlist => 'Watchlist';

  @override
  String get homeGoToMarkets => 'Go to Markets';

  @override
  String get homeYourWatchlistIsEmpty =>
      'Your watchlist is empty. Tap the star on any stock page to add it.';

  @override
  String homeCouldnTRefreshYour2(Object _paperError) {
    return 'Couldn\'t refresh your paper account: $_paperError';
  }

  @override
  String get homePaperTrading => 'Paper Trading';

  @override
  String get homePaperPositions => 'Paper Positions';

  @override
  String get homePaperPositionsAndP =>
      'Paper positions and P&L valued at demo prices';

  @override
  String get homePaperOrders => 'Paper Orders';

  @override
  String get homeMarketOrdersFillInstantly =>
      'Market orders fill instantly, limit orders fill at your price, and open orders can be canceled';

  @override
  String get homePickAStockOn =>
      'Pick a stock on the Markets tab and tap \"Buy / Sell\" to place a paper trade.';

  @override
  String get homeLiveTotalAssetsUsd => 'Live · Total Assets (USD)';

  @override
  String get homeBuyingPower => 'Buying Power';

  @override
  String get homeAvailableToWithdraw => 'Available to Withdraw';

  @override
  String get homePendingSandboxVerification => 'Pending sandbox verification';

  @override
  String get drawerSwitchAccount => 'Switch Account';

  @override
  String get drawerLive => 'Live';

  @override
  String get drawerPaper => 'Paper';

  @override
  String get drawerFunds => 'Funds';

  @override
  String get drawerWithdraw => 'Withdraw';

  @override
  String get drawerBankAccounts => 'Bank Accounts';

  @override
  String get drawerTransferFromAnotherBroker => 'Transfer from Another Broker';

  @override
  String get drawerActivity => 'Activity';

  @override
  String get drawerNotifications => 'Notifications';

  @override
  String get drawerHistory => 'History';

  @override
  String get drawerDocuments => 'Documents';

  @override
  String get drawerManage => 'Manage';

  @override
  String get drawerSettings => 'Settings';

  @override
  String get drawerHelpCenter => 'Help Center';

  @override
  String get drawerSignOut => 'Sign Out';

  @override
  String get drawerBrokerageAccountUnavailable =>
      'Brokerage account unavailable';

  @override
  String get drawerAccountNumber => 'Account Number';

  @override
  String get drawerMarketValue => 'Market Value';

  @override
  String get drawerSellOnly => 'Sell Only';

  @override
  String get drawerFrozen => 'Frozen';

  @override
  String get drawerClosed => 'Closed';

  @override
  String get drawerOpening => 'Opening';

  @override
  String get drawerLiveAccount => 'Live Account';

  @override
  String get drawerCashSelfDirected => 'Cash · Self-Directed';

  @override
  String get drawerAccountNumberCopied => 'Account number copied';

  @override
  String drawerAccountType(
    Object accountType,
    Object tradingType,
    Object managementType,
  ) {
    return 'Account type $accountType · $tradingType · $managementType';
  }

  @override
  String get drawerPositionsValue => 'Positions Value';

  @override
  String get drawerTransferIn => 'Transfer In';

  @override
  String get drawerThisFeatureIsnT => 'This feature isn\'t part of this demo';

  @override
  String get drawerSignOut2 => 'Sign out?';

  @override
  String get drawerYouLlNeedTo =>
      'You\'ll need to verify your email to sign in again.';

  @override
  String get drawerCancel => 'Cancel';

  @override
  String get drawerSignOut3 => 'Sign Out';

  @override
  String get drawerKycStatus => 'KYC Status';

  @override
  String get drawerLastSynced => 'Last Synced';

  @override
  String get drawerDwSandboxIds => 'DW Sandbox IDs';

  @override
  String get drawerDemoOnly => 'Demo Only';

  @override
  String get drawerNoDwIdsYet =>
      'No DW IDs yet: the account hasn\'t been opened, or demo mode (OTP_DEV_LOG) isn\'t enabled on the backend.';

  @override
  String drawerCopied(Object k) {
    return 'Copied $k';
  }

  @override
  String get drawerTheseAreTheValues =>
      'These are the values returned by the DW sandbox. Compare them one by one with the output of demoreset verify.';

  @override
  String get cueYourAccountIsFrozen =>
      'Your account is frozen: trading, deposits, and withdrawals are unavailable. Your assets remain safely held. Please contact support for details.';

  @override
  String get cueYourAccountIsLimited =>
      'Your account is limited to selling: you can\'t buy new securities, but you can sell existing positions, deposit, and withdraw.';

  @override
  String get cueYourAccountIsClosed =>
      'Your account is closed. Please contact support if you have any questions.';

  @override
  String get cueOpenABrokerageAccount => 'Open a Brokerage Account';

  @override
  String get cueVerifyYourIdentityTo =>
      'Verify your identity to deposit and trade. It takes about 5 minutes.';

  @override
  String get cueOpenAnAccount => 'Open an Account';

  @override
  String get cueContinueOpeningYourAccount => 'Continue Opening Your Account';

  @override
  String get cueYourProgressIsSaved =>
      'Your progress is saved. Pick up where you left off.';

  @override
  String get cueContinueApplication => 'Continue Application';

  @override
  String get cueApplicationSubmitted => 'Application submitted';

  @override
  String get cueCheckYourApplicationStatus => 'Check your application status';

  @override
  String get cueViewStatus => 'View Status';

  @override
  String get cueYourApplicationNeedsManual =>
      'Your application needs manual review';

  @override
  String get cueWeLlBeIn => 'We\'ll be in touch soon.';

  @override
  String get cueOpeningYourBrokerageAccount => 'Opening your brokerage account';

  @override
  String get cueIdentityVerifiedTimingTo =>
      'Identity verified (timing to be confirmed by DW)';

  @override
  String get cueYourApplicationNeedsChanges => 'Your application needs changes';

  @override
  String get cuePleaseUpdateTheRequested =>
      'Please update the requested items and resubmit.';

  @override
  String get cueUpdateApplication => 'Update Application';

  @override
  String get cueIdDocumentRequired => 'ID document required';

  @override
  String get cueWeLlReVerify => 'We\'ll re-verify after you upload it.';

  @override
  String get cueUploadId => 'Upload ID';

  @override
  String get cueApplicationUnderManualReview =>
      'Application under manual review';

  @override
  String get cueTimingToBeConfirmed => 'Timing to be confirmed by DW';

  @override
  String get cueViewApplicationStatus => 'View Application Status';

  @override
  String get cueApplicationNotApproved => 'Application not approved';

  @override
  String get cueSeeTheResultAnd => 'See the result and your options';

  @override
  String get cueViewResult => 'View Result';

  @override
  String get cueVerifyingYourIdentity => 'Verifying your identity';

  @override
  String get allocAssetAllocation => 'Asset Allocation';

  @override
  String get allocValuedAtDemoPrices => 'Valued at demo prices';

  @override
  String get allocByLatestMarketValue =>
      'By latest market value · DW real-time';

  @override
  String get allocTotalAssets => 'Total Assets';

  @override
  String get allocAssetTrend => 'Asset Trend';

  @override
  String get allocDailySnapshots => 'Daily snapshots';

  @override
  String get allocDailySnapshotsSinceAccount =>
      'Daily snapshots · since account opening';

  @override
  String get allocBuildingYourHistoryThe =>
      'Building your history — the trend appears starting tomorrow';

  @override
  String get etfCatIndex => 'Broad Market';

  @override
  String get etfCatCommodity => 'Commodities';

  @override
  String get etfCatBond => 'Bonds';

  @override
  String get etfCatSector => 'Sectors';

  @override
  String get etfCatIntl => 'International';

  @override
  String get etfCatVolatility => 'Volatility';

  @override
  String get marketAll => 'All';

  @override
  String get marketDataNote =>
      'Demo data: simulated quotes (randomly generated, not real prices)\nMarket data is for reference only and isn\'t investment advice.';

  @override
  String marketDataNoteUpdated(Object time) {
    return 'Demo data: simulated quotes (randomly generated, not real prices) · Updated $time\nMarket data is for reference only and isn\'t investment advice.';
  }

  @override
  String get instrumentStock => 'Stock';

  @override
  String get instrumentSimulated => 'Simulated quotes (demo data)';

  @override
  String get instrumentRealtime => 'Real-time';

  @override
  String instrumentUpdated(Object source, Object time) {
    return '$source · Updated $time';
  }

  @override
  String get fgExtremeFear => 'Extreme Fear';

  @override
  String get fgFear => 'Fear';

  @override
  String get fgNeutral => 'Neutral';

  @override
  String get fgGreed => 'Greed';

  @override
  String get fgExtremeGreed => 'Extreme Greed';

  @override
  String marketCouldnTRefreshQuotes(Object error) {
    return 'Couldn\'t refresh quotes: $error';
  }

  @override
  String get marketTopGainers => 'Top Gainers';

  @override
  String get marketTopLosers => 'Top Losers';

  @override
  String get marketEtfRankings => 'ETF Rankings';

  @override
  String get marketNone => 'None';

  @override
  String get instrumentWatchlist => 'Watchlist';

  @override
  String get instrumentRemovedFromWatchlist => 'Removed from Watchlist';

  @override
  String get instrumentAddedToWatchlist => 'Added to Watchlist';

  @override
  String get instrumentSell => 'Sell';

  @override
  String get instrumentBuy => 'Buy';

  @override
  String get instrumentUnavailableRightNow => 'Unavailable right now';

  @override
  String instrumentCouldnTRefreshQuotes(Object _error) {
    return 'Couldn\'t refresh quotes: $_error';
  }

  @override
  String get instrumentQuote => 'Quote';

  @override
  String get instrumentBid => 'Bid';

  @override
  String get instrumentAsk => 'Ask';

  @override
  String get instrumentIntraday1MinDashed =>
      'Intraday (1-min) · Dashed line is previous close';

  @override
  String get instrumentKeyStats => 'Key Stats';

  @override
  String get instrumentPrevClose => 'Prev Close';

  @override
  String get instrumentDayHigh => 'Day High';

  @override
  String get instrumentDayLow => 'Day Low';

  @override
  String get moodMarketSentiment => 'Market Sentiment';

  @override
  String get moodDemoDataUpdatesEvery => 'Demo data · Updates every 3s';

  @override
  String get moodDerivedFromSimulatedPrice =>
      'Derived from simulated price changes, momentum, and volatility';

  @override
  String get moodAdvancersDecliners => 'Advancers / Decliners';

  @override
  String moodUp(Object up) {
    return '$up up';
  }

  @override
  String moodDown(Object down) {
    return '$down down';
  }

  @override
  String moodFlat(Object flat) {
    return '$flat flat';
  }

  @override
  String moodUp2(Object up) {
    return 'Up $up';
  }

  @override
  String moodFlat2(Object flat) {
    return 'Flat $flat';
  }

  @override
  String moodDown2(Object down) {
    return 'Down $down';
  }

  @override
  String paperPlValue(Object pl, Object pct) {
    return 'Paper P&L $pl ($pct)';
  }

  @override
  String get positionsFromDw => 'Position data from DriveWealth';

  @override
  String positionsFromDwUpdated(Object time) {
    return 'Position data from DriveWealth · Updated $time';
  }

  @override
  String positionsTotalPl(Object pl) {
    return 'Unrealized P&L $pl';
  }

  @override
  String get tradePleaseEnterAnAmount => 'Please enter an amount.';

  @override
  String get tradeEnterAValidAmount =>
      'Enter a valid amount with up to 2 decimal places.';

  @override
  String tradeExceedsYourAvailableBuying(Object v0) {
    return 'Exceeds your available buying power of $v0';
  }

  @override
  String tradeExceedsTheSellableMarket(Object v0) {
    return 'Exceeds the sellable market value of $v0';
  }

  @override
  String get tradePleaseEnterTheNumber => 'Please enter the number of shares.';

  @override
  String get tradeEnterAValidNumber =>
      'Enter a valid number of shares with up to 6 decimal places.';

  @override
  String get tradeSharesMustBeGreater => 'Shares must be greater than 0.';

  @override
  String get tradeNoQuoteAvailablePlease =>
      'No quote available. Please buy by dollar amount.';

  @override
  String tradeEstimatedAmountExceedsYour(Object v0, Object v1) {
    return 'Estimated amount $v0 exceeds your available buying power of $v1';
  }

  @override
  String tradeExceedsYourSellableQuantity(Object v0) {
    return 'Exceeds your sellable quantity of $v0 shares';
  }

  @override
  String get tradeSubmitting => 'Submitting';

  @override
  String get tradeQueued => 'Queued';

  @override
  String get tradePartiallyFilled => 'Partially Filled';

  @override
  String get tradeFilled => 'Filled';

  @override
  String get tradeRejected => 'Rejected';

  @override
  String get tradeCanceled => 'Canceled';

  @override
  String get tradePendingCancel => 'Pending Cancel';

  @override
  String get tradePricesShownAreDemo =>
      'Prices shown are demo quotes. Actual execution is determined by the broker (DriveWealth).';

  @override
  String get tradePleaseEnterALimit => 'Please enter a limit price.';

  @override
  String get tradeLimitPriceMustBe =>
      'Limit price must be greater than 0 (up to 2 decimal places for prices of \$1 or more).';

  @override
  String tradeAmountOnHoldExceeds(Object v0, Object v1) {
    return 'Amount on hold $v0 exceeds your available funds of $v1';
  }

  @override
  String get tradeWorking => 'Working';

  @override
  String get tradePaperTradingOrdersFill =>
      'Paper trading: orders fill at demo prices (market buys at the ask, sells at the bid) using virtual funds. No real trades are placed.';

  @override
  String get paperPaperTradingVirtualFunds =>
      'Paper Trading · Virtual funds, filled at demo prices. No real trades are placed.';

  @override
  String get paperPaper => 'Paper';

  @override
  String get paperPaperAccountTotalValue => 'Paper Account Total Value';

  @override
  String get paperReset => 'Reset';

  @override
  String get paperPaperPL => 'Paper P&L ••••';

  @override
  String get paperAvailableFunds => 'Available Funds';

  @override
  String get paperOnHoldForOrders => 'On Hold for Orders';

  @override
  String get paperStartingBalance => 'Starting Balance';

  @override
  String get paperResetPaperAccount => 'Reset paper account?';

  @override
  String get paperYourVirtualFundsWill =>
      'Your virtual funds will return to the starting balance, and all paper positions and orders will be cleared. This only affects paper trading, not your live account.';

  @override
  String get ordersCancelOrder => 'Cancel order?';

  @override
  String ordersCancelingReleasesTheVirtual(
    Object v0,
    Object symbol,
    Object v2,
  ) {
    return '$v0 $symbol $v2. Canceling releases the virtual funds or shares on hold.';
  }

  @override
  String ordersTheCancellationResultIs(Object v0, Object symbol, Object v2) {
    return '$v0 $symbol $v2. The cancellation result is determined by the broker; any filled portion won\'t be reversed.';
  }

  @override
  String get ordersKeepOrder => 'Keep Order';

  @override
  String get ordersCancelOrder2 => 'Cancel Order';

  @override
  String get ordersOrderCanceled => 'Order canceled';

  @override
  String get ordersCancelRequestSubmittedWaiting =>
      'Cancel request submitted. Waiting for the broker to confirm.';

  @override
  String ordersShares(Object v0) {
    return '$v0 shares';
  }

  @override
  String get ordersNoOrdersYet => 'No orders yet';

  @override
  String get ordersYouCanPlaceOrders =>
      'You can place orders once your brokerage account is open.';

  @override
  String get ordersBackToAssets => 'Back to Assets';

  @override
  String get ordersOpen => 'Open';

  @override
  String get ordersClosed => 'Closed';

  @override
  String get ordersNoOrdersYetTap =>
      'No orders yet. Tap \"Buy\" or \"Sell\" on a stock page to place an order.';

  @override
  String get ordersPaperOrdersAreFilled =>
      'Paper orders are filled at demo prices. No real trades are placed.';

  @override
  String get ordersOrderStatusFilledQuantity =>
      'Order status, filled quantity, and fill prices are all as reported by the broker (DriveWealth).';

  @override
  String get ordersOrder => 'Order';

  @override
  String ordersLimitDay(Object v0, Object v1) {
    return 'Limit $v0 · $v1 · Day';
  }

  @override
  String ordersMarket(Object v0) {
    return 'Market · $v0';
  }

  @override
  String get ordersAvgFillPrice => 'Avg Fill Price';

  @override
  String get ordersFilledAmount => 'Filled Amount';

  @override
  String get ordersFees => 'Fees';

  @override
  String get ordersSubmitted => 'Submitted';

  @override
  String get ordersCompleted => 'Completed';

  @override
  String get ordersOrderNo => 'Order No.';

  @override
  String get ordersTheBrokerHasnT =>
      'The broker hasn\'t confirmed this order yet. We\'ll check it automatically, so please don\'t place it again.';

  @override
  String get positionsNoPositionsYet => 'No positions yet';

  @override
  String get positionsYouCanBuyStocks =>
      'You can buy stocks once your brokerage account is open.';

  @override
  String get positionsNoPositionsYet2 => 'No positions yet.';

  @override
  String get positionsPickAStockOn =>
      'Pick a stock on the Markets tab and tap \"Buy\" to place an order.';

  @override
  String get positionsPaperPositionsAreValued =>
      'Paper positions are valued at demo prices and don\'t represent real assets.';

  @override
  String get positionsPaperPositionsValue => 'Paper Positions Value';

  @override
  String get positionsSharesHeld => 'Shares Held';

  @override
  String get positionsSellable => 'Sellable';

  @override
  String get positionsCostBasis => 'Cost Basis';

  @override
  String get positionsAvgCurrentPrice => 'Avg / Current Price';

  @override
  String get orderSideBuy => 'Buy';

  @override
  String get orderSideSell => 'Sell';

  @override
  String get orderDemoQuote => 'Demo quote';

  @override
  String get orderLimitHelpBuy =>
      'Buy: fills at or below your limit price. Good for the day.';

  @override
  String get orderLimitHelpSell =>
      'Sell: fills at or above your limit price. Good for the day.';

  @override
  String get orderBuyAmountUsd => 'Buy Amount (USD)';

  @override
  String get orderSellAmountUsd => 'Sell Amount (USD)';

  @override
  String get orderBuyShares => 'Shares to Buy';

  @override
  String get orderSellShares => 'Shares to Sell';

  @override
  String get orderYourAccountIsCurrently =>
      'Your account is currently restricted and can\'t trade. Please contact support if you have questions.';

  @override
  String get orderYourAccountIsFrozen =>
      'Your account is frozen and can\'t trade. Your assets remain safely held. Please contact support for details.';

  @override
  String get orderYourAccountIsClosed =>
      'Your account is closed and can\'t trade.';

  @override
  String get orderYourAccountIsCurrently2 =>
      'Your account is currently limited to selling. Buying isn\'t available.';

  @override
  String get orderOrderAmount => 'Order Amount';

  @override
  String get orderOrderQuantity => 'Order Quantity';

  @override
  String orderShares(Object v0) {
    return '≈ $v0 shares';
  }

  @override
  String orderText(Object v0) {
    return '≈ $v0';
  }

  @override
  String get orderEstimatedAmountOnHold => 'Estimated Amount (on hold)';

  @override
  String get orderEstimatedAmount => 'Estimated Amount';

  @override
  String get orderEstimatedShares => 'Estimated Shares';

  @override
  String get orderLimitOrderDay => 'Limit Order · Day';

  @override
  String get orderMarketOrder => 'Market Order';

  @override
  String get orderOpenAnAccountTo => 'Open an account to start trading';

  @override
  String get orderYouCanPlaceOrders =>
      'You can place orders once your brokerage account is open. Finish opening your account, or switch to paper trading to practice.';

  @override
  String get orderSwitchToPaperTrading => 'Switch to Paper Trading';

  @override
  String get orderMarket => 'Market';

  @override
  String get orderLimit => 'Limit';

  @override
  String get orderByAmount => 'By Amount';

  @override
  String get orderByShares => 'By Shares';

  @override
  String get orderLimitPriceUsd => 'Limit Price (USD)';

  @override
  String orderFractionalSharesSupported(Object minOrderText) {
    return 'Fractional shares supported; $minOrderText';
  }

  @override
  String get orderFractionalSharesSupportedUp =>
      'Fractional shares supported, up to 6 decimal places';

  @override
  String orderSellAllShares(Object v0) {
    return 'Sell All ($v0 shares)';
  }

  @override
  String get orderOrderType => 'Order Type';

  @override
  String get orderReferencePriceDemoQuote => 'Reference Price (demo quote)';

  @override
  String get orderPaperAvailableFunds => 'Paper Available Funds';

  @override
  String get orderBuyingPower => 'Buying Power';

  @override
  String get orderPaperLimitOrderFills =>
      'Paper limit order: fills automatically when the demo price reaches your limit. Funds or shares are held until it fills. Good for the day.';

  @override
  String get orderPaperMarketOrdersFill =>
      'Paper market orders fill instantly at demo prices (buys at the ask, sells at the bid).';

  @override
  String get orderYourCurrentBuyingPower =>
      'Your current buying power is \$0.00. Deposits count toward buying power once they settle; dates are as reported by the broker in your transfer history.';

  @override
  String get orderLimitOrdersAreGood =>
      'Limit orders are good for the day and may fill only when the price reaches your limit. Any unfilled portion is canceled automatically after the close. Status is as reported by the broker.';

  @override
  String get orderMarketOrdersFillAt =>
      'Market orders fill at the broker\'s actual execution price. Extended-hours trading isn\'t separated in this release; orders placed while the market is closed may queue until the open. Status is as reported by the broker.';

  @override
  String get orderNext => 'Next';

  @override
  String get orderReviewOrder => 'Review Order';

  @override
  String get orderPaperVirtualFunds => 'Paper (virtual funds)';

  @override
  String get orderLiveDrivewealth => 'Live (DriveWealth)';

  @override
  String get orderSide => 'Side';

  @override
  String get orderLimitPrice => 'Limit Price';

  @override
  String get orderCustodian => 'Custodian';

  @override
  String get orderEditOrder => 'Edit Order';

  @override
  String get orderConfirmBuy => 'Confirm Buy';

  @override
  String get orderConfirmSell => 'Confirm Sell';

  @override
  String get orderOrderRecorded => 'Order recorded';

  @override
  String get orderPaperOrderFilled => 'Paper order filled';

  @override
  String get orderOrderFilled => 'Order filled';

  @override
  String get orderOrderRejectedByThe => 'Order rejected by the broker';

  @override
  String get orderPaperLimitOrderPlaced => 'Paper limit order placed';

  @override
  String get orderLimitOrderSubmitted => 'Limit order submitted';

  @override
  String get orderOrderSubmitted => 'Order submitted';

  @override
  String get orderTheBrokerHasnT =>
      'The broker hasn\'t confirmed this order yet. We\'ll check it automatically — please check its status in your orders shortly. Don\'t submit it again.';

  @override
  String get orderSimulatedFillAtDemo =>
      'Simulated fill at demo prices using virtual funds. No real trades are placed.';

  @override
  String get orderFillPriceAndQuantity =>
      'Fill price and quantity are as reported by the broker.';

  @override
  String get orderTheBrokerRejectedThis =>
      'The broker rejected this order. Please try again later or contact support.';

  @override
  String get orderFillsAutomaticallyWhenThe =>
      'Fills automatically when the demo price reaches your limit. Funds or shares are held until then, and you can cancel it in Paper Orders. Good for the day.';

  @override
  String get orderMayFillOnlyWhen =>
      'May fill only when the price reaches your limit. Good for the day; you can cancel it in your orders. Status is as reported by the broker.';

  @override
  String get orderYourOrderHasBeen =>
      'Your order has been sent to the broker. Its status will update in your orders once filled. Orders placed while the market is closed may queue until the open.';

  @override
  String get orderOrderResult => 'Order Result';

  @override
  String get orderStatus => 'Status';

  @override
  String get orderFilledQuantity => 'Filled Quantity';

  @override
  String get orderViewPaperOrders => 'View Paper Orders';

  @override
  String get orderViewOrders => 'View Orders';

  @override
  String get orderDone => 'Done';

  @override
  String get fundAchFee =>
      '\$0.25 (per DW documentation; to be confirmed by DW)';

  @override
  String bankSubtitle(Object type, Object owner, Object date) {
    return '$type · Account holder $owner · Linked $date';
  }

  @override
  String transferTitleDeposit(Object method) {
    return '$method Deposit';
  }

  @override
  String transferTitleWithdrawal(Object method) {
    return '$method Withdrawal';
  }

  @override
  String transferDetailDeposit(Object method) {
    return '$method Deposit Details';
  }

  @override
  String transferDetailWithdrawal(Object method) {
    return '$method Withdrawal Details';
  }

  @override
  String bankTypeOwner(Object type, Object owner) {
    return '$type · Account holder $owner';
  }

  @override
  String get fundPleaseEnterADeposit => 'Please enter a deposit amount.';

  @override
  String fundMinimumDepositIs(Object v0) {
    return 'Minimum deposit is $v0';
  }

  @override
  String fundMaximumDepositIs(Object v0) {
    return 'Maximum deposit is $v0';
  }

  @override
  String get fundPleaseEnterAWithdrawal => 'Please enter a withdrawal amount.';

  @override
  String fundMinimumWithdrawalIs(Object v0) {
    return 'Minimum withdrawal is $v0';
  }

  @override
  String fundExceedsYourAvailableTo(Object v0) {
    return 'Exceeds your available-to-withdraw amount of $v0';
  }

  @override
  String fundMaximumWithdrawalIs(Object v0) {
    return 'Maximum withdrawal is $v0';
  }

  @override
  String get fundInitiated => 'Initiated';

  @override
  String get fundPending => 'Pending';

  @override
  String get fundProcessing => 'Processing';

  @override
  String get fundApproved => 'Approved';

  @override
  String get fundCompleted => 'Completed';

  @override
  String get fundFailed => 'Failed';

  @override
  String get fundReturned => 'Returned';

  @override
  String get fundOnHold => 'On Hold';

  @override
  String get fundBuyingPowerIsGranted =>
      'Buying power is granted after settlement, usually 4–5 business days (to be confirmed by DW)';

  @override
  String get fundUsually45Business =>
      'Usually 4–5 business days (to be confirmed by DW)';

  @override
  String get fundBankAccount => 'Bank Account';

  @override
  String get fundSavings => 'Savings';

  @override
  String get fundChecking => 'Checking';

  @override
  String get bankYourAccountIsCurrently =>
      'Your account is currently restricted, so transfers aren\'t available. Please contact support if you have questions.';

  @override
  String get bankUnlinkBankAccount => 'Unlink bank account?';

  @override
  String bankOnceUnlinkedCanNo(Object displayName) {
    return 'Once unlinked, $displayName can no longer be used for deposits or withdrawals.';
  }

  @override
  String get bankUnlink => 'Unlink';

  @override
  String get bankUnlinked => 'Unlinked';

  @override
  String bankLinked(Object length, Object maxBanks) {
    return 'Linked ($length/$maxBanks)';
  }

  @override
  String get bankNoBankAccountsLinked =>
      'No bank accounts linked yet. Link a US bank account in your own name to deposit and withdraw via ACH.';

  @override
  String bankYouCanLinkUp(Object maxBanks) {
    return 'You can link up to $maxBanks bank accounts. To use a different one, unlink an existing account first.';
  }

  @override
  String get bankYouCanOnlyLink =>
      'You can only link US bank accounts in your own name. Don\'t have one? You can deposit by wire transfer instead.';

  @override
  String get bankViewWireInstructions => 'View Wire Instructions';

  @override
  String get bankLinkANewBank => 'Link a New Bank Account';

  @override
  String get bankEnterAValid9 => 'Enter a valid 9-digit ABA routing number.';

  @override
  String get bankEnterA417 => 'Enter a 4–17 digit account number.';

  @override
  String get bankNicknameCanBeUp => 'Nickname can be up to 30 characters.';

  @override
  String get bankNicknameCanTBe =>
      'Nickname can\'t be the same as the account number.';

  @override
  String get bankBankAccountLinked => 'Bank account linked';

  @override
  String get bankLinkBankAccount => 'Link Bank Account';

  @override
  String get bankAccountsInYourOwn => 'Accounts in your own name only';

  @override
  String get bankTheAccountHolderIs =>
      'The account holder is registered under the name on your brokerage account; transfers from third-party accounts will be returned';

  @override
  String get bankUsBankAccountsOnly => 'US bank accounts only';

  @override
  String get bankNoUsBankAccount =>
      'No US bank account? Please use a wire transfer';

  @override
  String get bankAccountNumberEncryptedIn =>
      'Account number encrypted in transit';

  @override
  String get bankWeOnlyShowThe => 'We only show the last digits';

  @override
  String get bankRoutingNumberAba => 'Routing Number (ABA)';

  @override
  String get bank9Digits => '9 digits';

  @override
  String get bankAccountNumber => 'Account Number';

  @override
  String get bank417Digits => '4–17 digits';

  @override
  String get bankAccountType => 'Account Type';

  @override
  String get bankNicknameOptional => 'Nickname (optional)';

  @override
  String get bankEGPaycheckAccount => 'e.g., Paycheck account';

  @override
  String get bankLink => 'Link';

  @override
  String get bankBeneficiary => 'Beneficiary';

  @override
  String get bankBeneficiaryBank => 'Beneficiary Bank';

  @override
  String get bankBankAddress => 'Bank Address';

  @override
  String get bankAccountNumber2 => 'Account Number';

  @override
  String get bankAbaRoutingNumber => 'ABA Routing Number';

  @override
  String get bankReferenceRequired => 'Reference (required)';

  @override
  String get bankWireDeposit => 'Wire Deposit';

  @override
  String get bankSendTheWireFrom =>
      'Send the wire from a bank account in your own name and include the reference below (with your account number). Otherwise, the funds may not be credited.';

  @override
  String bankCopied(Object value) {
    return '$value copied';
  }

  @override
  String get bankIntermediaryBankFeesAre =>
      'Intermediary bank fees are paid by the sender. Arrival time depends on when the bank actually receives the funds (to be confirmed by DW). Wire deposits aren\'t subject to the ACH holding period.';

  @override
  String get xferTransactionId => 'Transaction ID';

  @override
  String get xferMethod => 'Method';

  @override
  String get xferAmount => 'Amount';

  @override
  String get xferViewTransferHistory => 'View Transfer History';

  @override
  String get xferDepositRecorded => 'Deposit recorded';

  @override
  String get xferDepositSubmitted => 'Deposit submitted';

  @override
  String get xferTheBrokerHasnT =>
      'The broker hasn\'t confirmed this transfer yet. We\'ll check it automatically — please check its status in your transfer history shortly. Don\'t submit it again.';

  @override
  String xferTheArrivalDateIs(Object buyingPowerFallback) {
    return '$buyingPowerFallback. The arrival date is the one reported by the broker in your transfer history.';
  }

  @override
  String get xferChooseADepositMethod => 'Choose a deposit method';

  @override
  String get xferBankTransferAch => 'Bank Transfer (ACH)';

  @override
  String get xferLinkAUsBank => 'Link a US bank account in your own name first';

  @override
  String xferUsBankAccountS(Object length) {
    return '$length US bank account(s) in your name linked · No fees';
  }

  @override
  String get xferWireTransfer => 'Wire Transfer';

  @override
  String get xferSendFromABank =>
      'Send from a bank account in your own name; suitable for overseas banks or large deposits';

  @override
  String xferWireTimingDependsOn(
    Object buyingPowerFallback,
    Object seasoningFallback,
  ) {
    return '$buyingPowerFallback. $seasoningFallback. Wire timing depends on when the bank actually receives the funds and isn\'t subject to the holding period. Actual dates for each deposit are as reported by the broker (see transfer history).';
  }

  @override
  String get xferWeOnlyAcceptFunds =>
      'We only accept funds from accounts in your own name; third-party transfers will be returned.';

  @override
  String get xferConfirmDeposit => 'Confirm Deposit';

  @override
  String get xferDepositAmount => 'Deposit Amount';

  @override
  String get xferFrom => 'From';

  @override
  String get xferTo => 'To';

  @override
  String get xferYourBrokerageAccountHeld =>
      'Your brokerage account (held at DriveWealth)';

  @override
  String get xferFee => 'Fee';

  @override
  String get xferBuyingPowerAvailable => 'Buying power available';

  @override
  String get xferByConfirmingYouAuthorize =>
      'By confirming, you authorize a debit from the bank account above. Funds are held at DriveWealth.';

  @override
  String get xferEdit => 'Edit';

  @override
  String get xferAchDeposit => 'ACH Deposit';

  @override
  String get xferFromBankAccount => 'From Bank Account';

  @override
  String xferManageBankAccounts(Object length, Object maxBanks) {
    return 'Manage Bank Accounts ($length/$maxBanks)';
  }

  @override
  String get xferDepositAmountUsd => 'Deposit Amount (USD)';

  @override
  String xferPerTransferUpTo(Object v0, Object v1, Object v2) {
    return '$v0 – $v1 per transfer, up to $v2 per day (sample limits; the broker\'s limits apply)';
  }

  @override
  String get xferSubmissionCutoff => 'Submission cutoff';

  @override
  String xferBusinessDaysEtSample(Object achCutoffEt) {
    return 'Business days $achCutoffEt ET (sample; to be confirmed by DW)';
  }

  @override
  String get xferWithdrawable => 'Withdrawable';

  @override
  String get xferReturnNoticeIfYour =>
      'Return notice: if your bank returns this transfer (for example, due to insufficient funds), securities bought with these funds may be restricted from sale and return fees may apply; deposits to your account may also be suspended.';

  @override
  String get xferWithdrawalRecorded => 'Withdrawal recorded';

  @override
  String get xferWithdrawalSubmitted => 'Withdrawal submitted';

  @override
  String xferAchWithdrawals(Object achWithdrawalArrival) {
    return 'ACH withdrawals: $achWithdrawalArrival.';
  }

  @override
  String get xferConfirmWithdrawal => 'Confirm Withdrawal';

  @override
  String get xferWithdrawalAmount => 'Withdrawal Amount';

  @override
  String get xferYourBrokerageAccount => 'Your brokerage account';

  @override
  String get xferEstimatedArrival => 'Estimated arrival';

  @override
  String get xferAvailableToWithdraw => 'Available to Withdraw';

  @override
  String get xferAccountCash => 'Account Cash';

  @override
  String get xferUnsettledFunds => 'Unsettled Funds';

  @override
  String get xferInAchHoldingPeriod => 'In ACH holding period';

  @override
  String xferYourAvailableToWithdraw(Object seasoningFallback) {
    return 'Your available-to-withdraw amount is as reported by the broker (DriveWealth). $seasoningFallback; wire deposits aren\'t subject to this limit.';
  }

  @override
  String get xferWireWithdrawalsArenT =>
      'Wire withdrawals aren\'t part of this demo yet (supported on the backend; will be enabled after sandbox testing). Wires can only go to a bank account in your own name, and the beneficiary is always the account holder.';

  @override
  String get xferToBankAccount => 'To Bank Account';

  @override
  String get xferNoBankAccountLinked => 'No bank account linked yet.';

  @override
  String get xferWithdrawalAmountUsd => 'Withdrawal Amount (USD)';

  @override
  String xferPerTransferAndNo(Object v0, Object v1) {
    return '$v0 – $v1 per transfer, and no more than your available-to-withdraw amount';
  }

  @override
  String get xferTransferHistory => 'Transfer History';

  @override
  String get xferDeposits => 'Deposits';

  @override
  String get xferWithdrawals => 'Withdrawals';

  @override
  String get xferNoTransfersYet => 'No transfers yet';

  @override
  String get xferShowingYour50Most =>
      'Showing your 50 most recent transfers. Trades, dividends, and corporate actions aren\'t part of this demo.';

  @override
  String get xferFromAccount => 'From Account';

  @override
  String get xferToAccount => 'To Account';

  @override
  String get xferBuyingPowerAvailable2 => 'Buying Power Available';

  @override
  String get xferPendingBrokerUpdate => 'Pending broker update';

  @override
  String get xferWithdrawableOn => 'Withdrawable On';

  @override
  String xferText(Object buyingPowerFallback, Object seasoningFallback) {
    return '$buyingPowerFallback; $seasoningFallback.';
  }

  @override
  String xferReason(Object failureReason) {
    return 'Reason: $failureReason';
  }

  @override
  String featureComingSoon(Object title) {
    return '$title is coming soon';
  }

  @override
  String mastersLastPrice(Object price) {
    return 'Last $price';
  }

  @override
  String get demoNorthshoreCapital => 'Northshore Capital';

  @override
  String get demoNorthshoreCapitalSample => 'Northshore Capital (Sample)';

  @override
  String get demoLongbridgeFund => 'Longbridge Fund';

  @override
  String get demoLongbridgeFundSample => 'Longbridge Fund (Sample)';

  @override
  String get demoFarhillInvestments => 'Farhill Investments';

  @override
  String get demoFarhillInvestmentsSample => 'Farhill Investments (Sample)';

  @override
  String get demoMorningBayAm => 'Morning Bay AM';

  @override
  String get demoMorningBayAmSample => 'Morning Bay AM (Sample)';

  @override
  String get demoBluestonePartners => 'Bluestone Partners';

  @override
  String get demoBluestonePartnersSample => 'Bluestone Partners (Sample)';

  @override
  String get demoCoastlineValue => 'Coastline Value';

  @override
  String get demoCoastlineValueSample => 'Coastline Value (Sample)';

  @override
  String get demoPinewoodGlobal => 'Pinewood Global';

  @override
  String get demoPinewoodGlobalSample => 'Pinewood Global (Sample)';

  @override
  String get demoGalaxyQuant => 'Galaxy Quant';

  @override
  String get demoGalaxyQuantSample => 'Galaxy Quant (Sample)';

  @override
  String get demoMostIncreased => 'Most Increased';

  @override
  String get demoContrarianBuys => 'Contrarian Buys';

  @override
  String get demoMostHeld => 'Most Held';

  @override
  String get demoNewPositions => 'New Positions';

  @override
  String get demoPortfolioCheckup => 'Portfolio Checkup';

  @override
  String get demoAnalyzeYourHoldingsAnd =>
      'Analyze your holdings and unrealized P&L';

  @override
  String get demoHoldOrSell => 'Hold or Sell';

  @override
  String get demoCompareTrendsRiskAnd =>
      'Compare trends, risk, and position size';

  @override
  String get demoStockResearch => 'Stock Research';

  @override
  String get demoPricesFundamentalsAndNews =>
      'Prices, fundamentals, and news in one place';

  @override
  String get demoRiskAlerts => 'Risk Alerts';

  @override
  String get demoSpotVolatilityConcentrationAnd =>
      'Spot volatility, concentration, and drawdowns';

  @override
  String get demoQuantSignals => 'Quant Signals';

  @override
  String get demoMomentumReversalVolumeAnd =>
      'Momentum, reversal, volume, and other factors';

  @override
  String get demoInvesting101 => 'Investing 101';

  @override
  String get demoUnderstandInvestingInPlain =>
      'Understand investing in plain language';

  @override
  String get demoFinxSportsBottle => 'FinX Sports Bottle';

  @override
  String get demoFifiHolidayBeanie => 'Fifi Holiday Beanie';

  @override
  String get demoWirelessHeadphones => 'Wireless Headphones';

  @override
  String get demoFifiCrossbodyBag => 'Fifi Crossbody Bag';

  @override
  String get mastersComingSoon => 'Coming soon';

  @override
  String get mastersSeeWhatTheBig => 'See what the big institutions are buying';

  @override
  String get mastersBasedOnPublic13f =>
      'Based on public 13F filings, updated quarterly';

  @override
  String get mastersTopReturns => 'Top Returns';

  @override
  String get mastersRecentlyUpdated => 'Recently Updated';

  @override
  String get mastersMore => 'More';

  @override
  String get mastersStockIdeas => 'Stock Ideas';

  @override
  String get mastersQ32026 => 'Q3 2026';

  @override
  String get mastersDataComesFromPublic =>
      'Data comes from public institutional filings (demo data). Filings are reported with a lag and may not reflect current holdings. This is not investment advice.';

  @override
  String get mastersDemoDataInstitutionNames =>
      'Demo data: institution names, returns, and holdings are fictional and for display only';

  @override
  String get masters1YrReturn => '1-Yr Return';

  @override
  String get mastersSymbol => 'Symbol';

  @override
  String get mastersIncreaseAsOfShares => 'Increase as % of Shares Outstanding';

  @override
  String get mastersIncreasedUnchangedDecreased =>
      'Increased / Unchanged / Decreased';

  @override
  String get mastersAllInstitutions => 'All Institutions';

  @override
  String get mastersNameFirm => 'Name / Firm';

  @override
  String get mastersReturn => 'Return';

  @override
  String get mastersAumGrowth => 'AUM Growth';

  @override
  String get mastersUpdated => 'Updated';

  @override
  String get mastersDemoDataAllInstitution =>
      'Demo data: all institution names are fictional examples';

  @override
  String get mastersInstitutionDetails => 'Institution Details';

  @override
  String get mastersInstitutionNotFound => 'Institution not found';

  @override
  String get mastersPleaseGoBackAnd => 'Please go back and choose again';

  @override
  String get mastersTop5HoldingsSample => 'Top 5 Holdings (Sample)';

  @override
  String get mastersDemoDataInstitutionsAnd =>
      'Demo data: institutions and holdings are fictional; stock prices are simulated quotes';

  @override
  String get mastersAiAssistant => 'AI Assistant';

  @override
  String get mastersNotIncludedInThe =>
      'Not included in the first release; pending compliance review. The page spec below is kept for evaluation only and won\'t launch in the first release.';

  @override
  String get mastersFifiQuantAssistant => 'Fifi Quant Assistant';

  @override
  String get mastersComingSoon2 => 'Coming Soon';

  @override
  String get mastersFifiIsLearningTo =>
      'Fifi is learning to analyze charts, risk, and holdings. Stay tuned.';

  @override
  String get mastersBeforeLaunchWeNeed =>
      'Before launch, we need to assess whether this would constitute investment advice.';

  @override
  String get mastersLaunchReminderOn => 'Launch reminder on';

  @override
  String get mastersRemindMeAtLaunch => 'Remind Me at Launch';

  @override
  String get mastersReminderCanceled => 'Reminder canceled';

  @override
  String get mastersDemoDataFeaturesShown =>
      'Demo data: features shown are planned and not yet available';

  @override
  String rewardsLevel(Object lv, Object rewardSoon) {
    return 'Level $lv $rewardSoon';
  }

  @override
  String get rewardsHolidayStarterGifts => 'Holiday Starter Gifts';

  @override
  String get rewardsUnlocksAtLevel1 => 'Unlocks at Level 1';

  @override
  String get rewardsRewardsShownAreDemo =>
      'Rewards shown are demo examples. Actual prizes and redemption rules will be announced at launch.';

  @override
  String get rewardsFifiRewards => 'Fifi Rewards';

  @override
  String get rewardsHolidayFifi => 'Holiday Fifi';

  @override
  String get rewardsHolidayNewYearLimited => 'Holiday · New Year Limited';

  @override
  String get rewardsFifiHolidayShop => 'Fifi Holiday Shop\n';

  @override
  String get rewardsOpeningSoon => 'Opening Soon';

  @override
  String get rewardsCompleteTasksToEarn =>
      'Complete tasks to earn XP and unlock holiday outfits, rooms, and New Year wish-list gifts.';

  @override
  String rewardsLevel2(Object level) {
    return 'Level $level';
  }

  @override
  String get rewardsReminderOn => '✓ Reminder On';

  @override
  String get rewardsRemindMeAtLaunch => '🔔 Remind Me at Launch';

  @override
  String get serverReasonRejected =>
      'The broker rejected this order. Please contact support for details.';

  @override
  String get serverReasonCanceled => 'This order was canceled.';

  @override
  String get serverReasonTransfer =>
      'The broker reported a reason for this failure. Please contact support for details.';

  @override
  String get tradeMinOrder =>
      'Minimum order \$1.00 (sample value; the broker\'s minimum applies)';

  @override
  String homeTodayChange(Object amount, Object pct) {
    return 'Today $amount$pct';
  }

  @override
  String get homeTodayHidden => 'Today ****';

  @override
  String get tabPredict => 'Predict';

  @override
  String get predictTitle => 'Predict';

  @override
  String predictPoints(Object points) {
    return '$points pts';
  }

  @override
  String get predictDemoBadge =>
      'Points-based predictions · Demo mode, no real money';

  @override
  String get predictCatAll => 'All';

  @override
  String get predictCatCrypto => 'Crypto';

  @override
  String get predictCatStocks => 'US Stocks';

  @override
  String get predictCatMacro => 'Macro';

  @override
  String get predictCatSports => 'Sports';

  @override
  String get predictCatTrending => 'Trending';

  @override
  String predictUpOrDownSymbol(Object symbol) {
    return 'Up or Down · $symbol';
  }

  @override
  String get predictUpOrDown => 'Up or Down';

  @override
  String predictTarget(Object price) {
    return 'Target $price · Settles when the window closes';
  }

  @override
  String predictUpPct(Object pct) {
    return 'Up · $pct%';
  }

  @override
  String predictDownPct(Object pct) {
    return 'Down · $pct%';
  }

  @override
  String get predictUp => 'Up';

  @override
  String get predictDown => 'Down';

  @override
  String get predict15m => '15 Minute Markets';

  @override
  String get predictSeeAll => 'See All';

  @override
  String get predictTrending => 'Trending Markets';

  @override
  String get predictLive => 'Live';

  @override
  String predictLiveSettle(Object date) {
    return 'Live · Settles $date';
  }

  @override
  String predictCloses(Object date) {
    return 'Closes $date';
  }

  @override
  String get predictDisclaimer =>
      'Predictions aggregate user opinions. For reference only. Not investment advice.';

  @override
  String get predictMine => 'My Predictions';

  @override
  String get predictNoMarkets => 'No open markets in this category.';

  @override
  String predictLoadFailed(Object error) {
    return 'Couldn\'t load prediction markets: $error';
  }

  @override
  String predictYourPick(Object label) {
    return 'Your pick: $label';
  }

  @override
  String get predictStake => 'Points to Stake';

  @override
  String get predictStakeHint => 'Whole number, 10–5,000';

  @override
  String predictAvailable(Object points) {
    return 'Available: $points pts';
  }

  @override
  String predictPotential(Object points) {
    return 'Win $points pts if correct';
  }

  @override
  String predictProbNow(Object pct) {
    return 'Current probability: $pct%';
  }

  @override
  String get predictPricingNote =>
      'Odds lock in at the current ratio when you place your prediction. The ratio updates as predictions come in (simplified demo model).';

  @override
  String get predictConfirm => 'Confirm Prediction';

  @override
  String predictPlaced(Object points) {
    return 'Prediction placed. Win $points pts if correct.';
  }

  @override
  String get predictStakeInvalid => 'Enter a whole number from 10 to 5,000.';

  @override
  String get predictStakeInsufficient => 'Not enough points.';

  @override
  String get predictClosedNow => 'This market has closed.';

  @override
  String get predictHitRate => 'Hit Rate';

  @override
  String get predictNetPoints => 'Net Points';

  @override
  String get predictSettledCount => 'Settled';

  @override
  String predictClaimable(Object points) {
    return '$points pts ready to claim';
  }

  @override
  String get predictClaim => 'Claim';

  @override
  String predictClaimedToast(Object points) {
    return 'Claimed $points pts';
  }

  @override
  String get predictTabOpen => 'Open';

  @override
  String get predictTabSettled => 'Settled';

  @override
  String get predictNoBets =>
      'No predictions yet. Pick a market on the Predict tab.';

  @override
  String get predictStatusOpen => 'Open';

  @override
  String get predictStatusWon => 'Won';

  @override
  String get predictStatusLost => 'Lost';

  @override
  String get predictStatusVoid => 'Voided · Refunded';

  @override
  String predictStakeLine(Object stake, Object payout) {
    return 'Staked $stake pts · Win $payout pts if correct';
  }

  @override
  String predictPaidLine(Object stake, Object payout) {
    return 'Staked $stake pts · Paid $payout pts';
  }

  @override
  String get predictClaimedTag => 'Claimed';

  @override
  String predictSettlesAt(Object price) {
    return 'Settled at $price';
  }

  @override
  String get srvPredictStake => 'Points must be between 10 and 5,000.';

  @override
  String get srvPredictOutcome => 'Please choose a side.';

  @override
  String get srvPredictInsufficient => 'Not enough prediction points.';

  @override
  String get srvPredictClosed => 'This prediction market has closed.';

  @override
  String get srvPredictNotFound => 'Prediction market not found.';

  @override
  String predictMonthDay(Object month, Object day) {
    return '$month $day';
  }

  @override
  String get welcomeSlogan1 => 'Invest in U.S. stocks & ETFs';

  @override
  String get welcomeSlogan2 => 'Open, fund, and trade — all in one place.';

  @override
  String get welcomeLogIn => 'Log In';

  @override
  String get welcomeBrowseMarkets => 'Browse Markets';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceSystem => 'Use System Setting';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get errSubmitUnconfirmedFunding =>
      'The network timed out while we confirm your request. Check Transfer History first — tapping Submit again won\'t create a duplicate.';

  @override
  String get errSubmitUnconfirmedOrder =>
      'The network timed out while we confirm your order. Check Orders first — tapping Submit again won\'t place a duplicate.';

  @override
  String get srvIdemKeyReusedTransfer =>
      'The details of this request changed. Please go back and submit again.';

  @override
  String get srvIdemKeyReusedOrder =>
      'The details of this order changed. Please go back and place it again.';

  @override
  String get statusUnconfirmed => 'Unconfirmed';

  @override
  String get xferUnconfirmedNotice =>
      'We\'re manually confirming this with the broker. Please don\'t submit it again — we\'ll update this record once it\'s confirmed. Contact support if you have questions.';

  @override
  String get ordersUnconfirmedNotice =>
      'We\'re manually confirming this order with the broker, so it can\'t be canceled. Please don\'t place it again — we\'ll update it once it\'s confirmed. Contact support if you have questions.';

  @override
  String fundAchHoldingPeriod(int days) {
    return 'ACH deposits can\'t be withdrawn during a $days-day holding period after they arrive by default; DW may adjust this (to be confirmed by DW)';
  }

  @override
  String xferAfterHoldingPeriod(int days) {
    return 'After the $days-day holding period ends (default; to be confirmed by DW)';
  }

  @override
  String get assetHeroTotal => 'Total Assets (USD)';

  @override
  String get assetHeroTotalPaper => 'Paper · Total Assets (USD)';

  @override
  String get assetHeroToday => 'Today';

  @override
  String get assetHeroTotalPL => 'Total P&L';

  @override
  String get assetIntradayBuilding => 'Building intraday data';

  @override
  String get assetHistoryBuilding => 'Building history';

  @override
  String get assetFilterAll => 'All';

  @override
  String get assetFilterStock => 'Stocks';

  @override
  String get assetFilterEtf => 'ETFs';

  @override
  String get assetTotalValue => 'Total Value';

  @override
  String get assetOthers => 'Other';

  @override
  String get assetNoStockHoldings => 'No stock holdings yet';

  @override
  String get assetNoEtfHoldings => 'No ETF holdings yet';

  @override
  String get assetShowAmounts => 'Show amounts';

  @override
  String get assetHideAmounts => 'Hide amounts';

  @override
  String get watchLiveNote => 'Live quotes · every 3s';

  @override
  String drawerWithdrawable(String amount) {
    return 'Available to withdraw: $amount';
  }

  @override
  String get marketUsMarket => 'U.S. Market';

  @override
  String get marketSearch => 'Search';

  @override
  String get marketSearchHint => 'Search symbol or name';

  @override
  String get marketSearchNoResults => 'No matching symbols';

  @override
  String get marketStats => 'Market Stats';

  @override
  String get marketStatsToday => 'Today';

  @override
  String get marketStats30d => '30 Days';

  @override
  String get marketStatsBuilding => 'Building data';

  @override
  String marketStatsBuildingSince(String date) {
    return 'Building data · recording since $date';
  }

  @override
  String marketStatsDown(int n) {
    return 'Down $n';
  }

  @override
  String marketStatsUp(int n) {
    return 'Up $n';
  }

  @override
  String get marketStatsNote =>
      'All stocks & ETFs in the demo pool (simulated quotes)';

  @override
  String get marketInsiders => 'Insider Trading';

  @override
  String get demoDataBadge => 'Demo Data';

  @override
  String get insiderTopBuy => 'Top Buy';

  @override
  String get insiderTopSell => 'Top Sell';

  @override
  String get insiderMostActive => 'Most Active';

  @override
  String insiderBought(String amount) {
    return 'Bought $amount';
  }

  @override
  String insiderSold(String amount) {
    return 'Sold $amount';
  }

  @override
  String insiderTrades(int n) {
    return '$n trades';
  }

  @override
  String get insiderMoreComingSoon => 'Insider trading details coming soon';

  @override
  String get orderDoneTitle => 'Order Placed';

  @override
  String get orderDoneSummary => 'Fill Summary';

  @override
  String get orderDoneSymbol => 'Symbol';

  @override
  String get orderDonePrice => 'Fill Price';

  @override
  String get orderDoneQty => 'Quantity';

  @override
  String get orderDoneTotal => 'Total';

  @override
  String get orderDoneTime => 'Time';

  @override
  String get orderDoneBackHome => 'Back to Home';

  @override
  String xpPill(String xp) {
    return '$xp XP';
  }

  @override
  String get fifiTitle => 'Fifi Quant Agent';

  @override
  String get fifiSubtitle => 'Your smart investing assistant';

  @override
  String get fifiHeroTitle => 'Coming Soon';

  @override
  String get fifiHeroBody =>
      'Fifi is learning to read charts, risk, and holdings for you.';

  @override
  String get fifiFeat1 => 'Portfolio Checkup';

  @override
  String get fifiFeat1Desc => 'Analyze your holdings and unrealized P&L.';

  @override
  String get fifiFeat2 => 'Hold or Sell';

  @override
  String get fifiFeat2Desc => 'Compare trend, risk, and sizing before you act.';

  @override
  String get fifiFeat3 => 'Stock Research';

  @override
  String get fifiFeat3Desc =>
      'Price action, fundamentals, and news signals in one view.';

  @override
  String get fifiFeat4 => 'Risk Alerts';

  @override
  String get fifiFeat4Desc =>
      'Flags volatility, concentration, and downside pressure.';

  @override
  String get fifiFeat5 => 'Quant Signals';

  @override
  String get fifiFeat5Desc =>
      'Tracks momentum, reversal, volume, and factor scores.';

  @override
  String get fifiFeat6 => 'Learn with Fifi';

  @override
  String get fifiFeat6Desc => 'Understand investing in clear, simple language.';

  @override
  String get fifiRemind => 'Notify Me at Launch';

  @override
  String get fifiRemindOn => 'Launch Reminder On';

  @override
  String get fifiRemindCaption =>
      'We\'ll let you know as soon as Fifi Quant Agent is ready.';

  @override
  String get storeTitle => 'Fifi Store';

  @override
  String storeTier(int n) {
    return 'Tier $n';
  }

  @override
  String get storeDream => 'Dream';

  @override
  String storeTierNew(int n) {
    return 'New in Tier $n';
  }

  @override
  String get storeTierEmpty => 'Items for this tier are coming soon';

  @override
  String storeTierLocked(int n) {
    return 'Unlocks at Tier $n';
  }

  @override
  String get storeAvailable => 'Available';

  @override
  String get storeNotEnoughXp => 'Need more XP';

  @override
  String storeUnlockAt(int n) {
    return 'Tier $n unlock';
  }

  @override
  String storeBundleXp(String xp) {
    return 'Set · $xp XP';
  }

  @override
  String get storePreview => 'Preview';

  @override
  String get storeComingSoon => 'Coming Soon';

  @override
  String get storePreviewOnFifi => 'Preview on Fifi';

  @override
  String get storePreviewOnFifiSoon => 'Preview on Fifi is coming soon';

  @override
  String get storeEarnXp => 'Earn XP';

  @override
  String get storeRedeemSoon => 'Redemption opening soon';

  @override
  String get storeSearchSoon => 'Store search is coming soon';

  @override
  String get storeImagePlaceholder => 'Preview image — final art coming soon';

  @override
  String get storeDemoNote =>
      'XP is an in-app progress score and can\'t be exchanged for cash. Items and redemption rules are subject to the launch announcement.';

  @override
  String get earnTitle => 'Fifi Rewards';

  @override
  String get earnToday => 'Today\'s Missions';

  @override
  String earnResetIn(String time) {
    return 'Resets in $time';
  }

  @override
  String get earnTask1 => 'Daily Check-in';

  @override
  String get earnTask1Desc => 'Keep your streak going';

  @override
  String get earnTask2 => 'Learn a Lesson with Fifi';

  @override
  String get earnTask2Desc => 'Finish a quick market lesson';

  @override
  String get earnTask3 => 'Run a Portfolio Checkup';

  @override
  String get earnTask3Desc => 'Check your financial health';

  @override
  String get earnTask4 => 'Monthly Savings Goal';

  @override
  String get earnTask4Desc => 'Hit this month\'s deposit goal';

  @override
  String get earnTask5 => 'Share FinX Once';

  @override
  String get earnTask5Desc => 'Invite a friend to learn with you';

  @override
  String earnXpPlus(int xp) {
    return '+$xp XP';
  }

  @override
  String get earnTaskSoon => 'This mission is opening soon';

  @override
  String earnCheckedIn(int xp) {
    return 'Checked in! +$xp XP';
  }

  @override
  String get earnAlreadyCheckedIn => 'Already checked in today';

  @override
  String earnStreak(int n) {
    return '$n-day streak';
  }

  @override
  String get earnKeepGoing => 'Keep it up!';

  @override
  String get earnStartStreak => 'Check in today to start a streak';

  @override
  String get earnWeekdays => 'M,T,W,T,F,S,S';

  @override
  String get earnGoWardrobe => 'Go to Fifi\'s Wardrobe';

  @override
  String get earnLoadFailed => 'Couldn\'t load missions. Pull down to retry.';

  @override
  String get searchTypeStock => 'Stock';

  @override
  String tradeExceedsPaperFunds(String v0) {
    return 'Exceeds your paper account\'s available funds of $v0';
  }

  @override
  String tradeEstimatedExceedsPaperFunds(String v0, String v1) {
    return 'Estimated amount $v0 exceeds your paper account\'s available funds of $v1';
  }

  @override
  String tradeHoldExceedsPaperFunds(String v0, String v1) {
    return 'Amount on hold $v0 exceeds your paper account\'s available funds of $v1';
  }

  @override
  String orderPaperFundsUsedUp(String v0) {
    return 'Your paper account\'s available funds are used up ($v0). Sell paper positions or reset the paper account to restore the starting balance. Paper trading uses virtual funds only — it\'s separate from your live buying power, and live deposits don\'t add paper funds.';
  }

  @override
  String get orderPaperResetNow => 'Reset Paper Account';
}
