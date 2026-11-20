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
  String get drawerPaperAccountIsnT => 'Paper account isn\'t available yet';

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
}
