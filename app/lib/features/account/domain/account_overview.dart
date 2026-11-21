import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../data/account_api.dart';
import '../data/portfolio_api.dart';
import '../../../l10n/l10n.dart';

/// 首页资产卡（P-07）与账户抽屉（P-08）共用的数据：开户进度、账户、资金汇总。
/// 资金一律取 DW money summary（F12）；加载失败时保留上次数据并给出错误。
class AccountOverview extends ChangeNotifier {
  AccountOverview(this._api, {this.portfolio});
  final AccountApi _api;
  final PortfolioApi? portfolio;

  /// 实盘资产分布（GET /account/allocation：现金 + 股票 + ETF，均为 DW 返回值）。
  /// 首页"总资产"与资产分布卡共用这一份数据，两处数字必然一致（D-18 定案，审计 FUND-P0-3）。
  Allocation? allocation;

  /// 总资产 = 现金 + 持仓市值（取自 [allocation]）；取不到时为 null（显示"—"，不以现金冒充总资产）。
  double? get totalAssets => allocation?.total;

  ApplicationProgress? progress;
  AccountInfo? account;
  AccountMoney? money;

  /// 持仓市值（DW summary/positions 的 equityValue，F14）；取不到时为 null（不影响资金展示）。
  double? equityValue;

  /// 今日持仓盈亏（DW 各持仓 unrealizedDayPL 之和）；持仓接口失败时为 null（不显示今日变动）。
  double? dayPL;
  String? error;
  bool loading = false;

  /// [applicationStatus]：/me 的 accountStatus（NONE/DRAFT/SUBMITTED/APPROVED/DENIED）。
  Future<void> load(String? applicationStatus) async {
    if (applicationStatus == null || applicationStatus == 'NONE' || applicationStatus == 'DRAFT') {
      progress = null;
      account = null;
      money = null;
      allocation = null;
      equityValue = null;
      dayPL = null;
      error = null;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      progress = await _api.progress();
      error = null;
      if (progress!.accountOpened) {
        account = await _api.account();
        money = await _api.money();
        try {
          allocation = await portfolio?.allocation();
        } on ApiException {
          allocation = null; // 资产分布失败：总资产显示"—"，资产分布卡显示加载失败
        }
        try {
          final s = await _api.positionsSummary();
          equityValue = s.equityValue;
          dayPL = s.dayPL;
        } on ApiException {
          equityValue = null; // 持仓接口失败不影响资金展示
          dayPL = null;
        }
      } else {
        account = null;
        money = null;
        allocation = null;
        equityValue = null;
        dayPL = null;
      }
    } on ApiException catch (e) {
      error = e.isSessionInvalid ? null : e.message; // 会话失效由 ApiClient.onSessionInvalid 统一处理
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 今日变动百分比：今日持仓盈亏 ÷ 昨日资产（总资产 − 今日盈亏）；无法计算时为 null。
  double? get dayPLPct {
    final d = dayPL, m = money;
    if (d == null || m == null) return null;
    final base = (totalAssets ?? m.cash + (equityValue ?? 0)) - d;
    return base > 0 ? d / base * 100 : null;
  }

  /// 账户可用（已开立）。
  bool get opened => account != null || (progress?.accountOpened ?? false);

  /// DW 账户受限状态（pages.md 第 2 版补充）。
  String? get restriction {
    final s = account?.status ?? progress?.accountStatus;
    return switch (s) {
      'FROZEN' => t.cueYourAccountIsFrozen,
      'OPEN_NO_NEW_TRADES' => t.cueYourAccountIsLimited,
      'CLOSED' => t.cueYourAccountIsClosed,
      _ => null,
    };
  }
}

/// 开户进度提示卡（原型 Onb.status，中文；用于 P-07 首页与 P-08 抽屉）。
class OnboardingCue {
  const OnboardingCue({
    required this.title,
    required this.sub,
    required this.icon,
    required this.route,
    required this.cta,
    this.warn = false,
    this.sandboxPending = false,
  });
  final String title;
  final String sub;
  final IconData icon;
  final String route;
  final String cta;
  final bool warn;

  /// P-34/35/36 入口：沙盒无法触发，标注"待沙盒验证"。
  final bool sandboxPending;

  static OnboardingCue? of(String? appStatus, ApplicationProgress? p) {
    switch (appStatus) {
      case null:
        return null;
      case 'NONE':
        return OnboardingCue(
          title: t.cueOpenABrokerageAccount,
          sub: t.cueVerifyYourIdentityTo,
          icon: Icons.shield_outlined,
          route: '/onboarding/a',
          cta: t.cueOpenAnAccount,
        );
      case 'DRAFT':
        return OnboardingCue(
          title: t.cueContinueOpeningYourAccount,
          sub: t.cueYourProgressIsSaved,
          icon: Icons.shield_outlined,
          route: '/onboarding/a',
          cta: t.cueContinueApplication,
        );
    }
    if (p == null) {
      return OnboardingCue(title: t.cueApplicationSubmitted, sub: t.cueCheckYourApplicationStatus, icon: Icons.schedule_rounded, route: '/application/status', cta: t.cueViewStatus);
    }
    if (p.accountOpened) return null;
    if (p.submitState == 'NEEDS_ATTENTION') {
      return OnboardingCue(
        title: t.cueYourApplicationNeedsManual,
        sub: t.cueWeLlBeIn,
        icon: Icons.support_agent_rounded,
        route: '/application/status',
        cta: t.cueViewStatus,
        warn: true,
      );
    }
    return switch (p.kycStatus) {
      'KYC_APPROVED' => OnboardingCue(
        title: t.cueOpeningYourBrokerageAccount,
        sub: t.cueIdentityVerifiedTimingTo,
        icon: Icons.schedule_rounded,
        route: '/application/status',
        cta: t.cueViewStatus,
      ),
      'KYC_INFO_REQUIRED' => OnboardingCue(
        title: t.cueYourApplicationNeedsChanges,
        sub: t.cuePleaseUpdateTheRequested,
        icon: Icons.edit_outlined,
        route: '/application/info',
        cta: t.cueUpdateApplication,
        warn: true,
        sandboxPending: true,
      ),
      'KYC_DOC_REQUIRED' => OnboardingCue(
        title: t.cueIdDocumentRequired,
        sub: t.cueWeLlReVerify,
        icon: Icons.badge_outlined,
        route: '/application/document',
        cta: t.cueUploadId,
        warn: true,
        sandboxPending: true,
      ),
      'KYC_MANUAL_REVIEW' => OnboardingCue(
        title: t.cueApplicationUnderManualReview,
        sub: t.cueTimingToBeConfirmed,
        icon: Icons.schedule_rounded,
        route: '/application/status',
        cta: t.cueViewApplicationStatus,
      ),
      'KYC_DENIED' => OnboardingCue(
        title: t.cueApplicationNotApproved,
        sub: t.cueSeeTheResultAnd,
        icon: Icons.info_outline_rounded,
        route: '/application/result',
        cta: t.cueViewResult,
        sandboxPending: true,
      ),
      _ => OnboardingCue(
        title: t.cueVerifyingYourIdentity,
        sub: t.cueReferenceNo(p.applicationRef ?? '—'),
        icon: Icons.schedule_rounded,
        route: '/application/status',
        cta: t.cueViewApplicationStatus,
      ),
    };
  }
}
