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
}
