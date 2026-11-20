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
}
