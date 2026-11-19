import 'package:material_ui/material_ui.dart';

import '../../../core/api/api_client.dart';
import '../data/account_api.dart';

/// 首页资产卡（P-07）与账户抽屉（P-08）共用的数据：开户进度、账户、资金汇总。
/// 资金一律取 DW money summary（F12）；加载失败时保留上次数据并给出错误。
class AccountOverview extends ChangeNotifier {
  AccountOverview(this._api);
  final AccountApi _api;

  ApplicationProgress? progress;
  AccountInfo? account;
  AccountMoney? money;
  String? error;
  bool loading = false;

  /// [applicationStatus]：/me 的 accountStatus（NONE/DRAFT/SUBMITTED/APPROVED/DENIED）。
  Future<void> load(String? applicationStatus) async {
    if (applicationStatus == null || applicationStatus == 'NONE' || applicationStatus == 'DRAFT') {
      progress = null;
      account = null;
      money = null;
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
      } else {
        account = null;
        money = null;
      }
    } on ApiException catch (e) {
      error = e.isSessionInvalid ? null : e.message; // 会话失效由 ApiClient.onSessionInvalid 统一处理
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 账户可用（已开立）。
  bool get opened => account != null || (progress?.accountOpened ?? false);

  /// DW 账户受限状态（pages.md 第 2 版补充）。
  String? get restriction {
    final s = account?.status ?? progress?.accountStatus;
    return switch (s) {
      'FROZEN' => '账户已冻结：暂不能交易、入金或出金。资产仍安全托管，请联系客服了解原因。',
      'OPEN_NO_NEW_TRADES' => '账户仅可卖出：暂不能买入新证券，可卖出现有持仓、入金和出金。',
      'CLOSED' => '账户已关闭。如有疑问请联系客服。',
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
        return const OnboardingCue(
          title: '开通证券账户',
          sub: '验证身份即可入金交易，约需 5 分钟',
          icon: Icons.shield_outlined,
          route: '/onboarding/a',
          cta: '去开户',
        );
      case 'DRAFT':
        return const OnboardingCue(
          title: '继续开通您的账户',
          sub: '进度已保存，可从上次中断处继续',
          icon: Icons.shield_outlined,
          route: '/onboarding/a',
          cta: '继续开户',
        );
    }
    if (p == null) {
      return const OnboardingCue(title: '开户申请已提交', sub: '查看开户进度', icon: Icons.schedule_rounded, route: '/application/status', cta: '查看进度');
    }
    if (p.accountOpened) return null;
    if (p.submitState == 'NEEDS_ATTENTION') {
      return const OnboardingCue(
        title: '开户申请需要人工处理',
        sub: '我们会尽快联系您',
        icon: Icons.support_agent_rounded,
        route: '/application/status',
        cta: '查看进度',
        warn: true,
      );
    }
    return switch (p.kycStatus) {
      'KYC_APPROVED' => const OnboardingCue(
        title: '交易账户开立中',
        sub: '身份核验已通过（预计时长待 DW 确认）',
        icon: Icons.schedule_rounded,
        route: '/application/status',
        cta: '查看进度',
      ),
      'KYC_INFO_REQUIRED' => const OnboardingCue(
        title: '开户资料需要修改',
        sub: '请按提示修改后重新提交',
        icon: Icons.edit_outlined,
        route: '/application/info',
        cta: '去修改资料',
        warn: true,
        sandboxPending: true,
      ),
      'KYC_DOC_REQUIRED' => const OnboardingCue(
        title: '需要上传身份证件',
        sub: '上传后将重新核验',
        icon: Icons.badge_outlined,
        route: '/application/document',
        cta: '去上传证件',
        warn: true,
        sandboxPending: true,
      ),
      'KYC_MANUAL_REVIEW' => const OnboardingCue(
        title: '开户申请人工复核中',
        sub: '预计时长待 DW 确认',
        icon: Icons.schedule_rounded,
        route: '/application/status',
        cta: '查看申请进度',
      ),
      'KYC_DENIED' => const OnboardingCue(
        title: '开户未通过',
        sub: '查看结果与后续可选操作',
        icon: Icons.info_outline_rounded,
        route: '/application/result',
        cta: '查看结果',
        sandboxPending: true,
      ),
      _ => OnboardingCue(
        title: '身份核验中',
        sub: '参考号 ${p.applicationRef ?? '—'}',
        icon: Icons.schedule_rounded,
        route: '/application/status',
        cta: '查看申请进度',
      ),
    };
  }
}
