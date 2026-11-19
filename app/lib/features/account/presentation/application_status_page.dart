import 'dart:async';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_api.dart';

/// DW KYC 状态英文名（原型 KYC_EN）。
const kycLabels = {
  'KYC_NOT_READY': 'Information incomplete',
  'KYC_READY': 'Queued for verification',
  'KYC_PROCESSING': 'Verifying your identity',
  'KYC_INFO_REQUIRED': 'Information needs review',
  'KYC_DOC_REQUIRED': 'Document required',
  'KYC_MANUAL_REVIEW': 'Manual review',
  'KYC_APPROVED': 'Verified',
  'KYC_DENIED': 'Could not open account',
};

/// DW 账户状态英文名（原型 ACCT_EN）。
const accountLabels = {'PENDING': 'Opening', 'OPEN': 'Open', 'OPEN_NO_NEW_TRADES': 'Sell only', 'FROZEN': 'Frozen', 'CLOSED': 'Closed'};

/// P-34/P-35/P-36 在沙盒无法触发（Q-DW-5），入口统一标注。
const sandboxPendingLabel = 'Pending sandbox verification';

/// 轮询间隔（api-spec.md 第 7 节：KYC 非终态 5–10s）。
const progressPollInterval = Duration(seconds: 5);

/// 加载 /application/status 并在非终态时轮询；P-06、P-34、P-35、P-36 共用。
mixin ProgressLoader<T extends StatefulWidget> on State<T> {
  ApplicationProgress? progress;
  String? loadError;
  Timer? _timer;
  bool _busy = false;

  bool get pollWhileVisible => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  Future<void> reload() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final p = await AccountApi(AppScope.of(context).api).progress();
      if (!mounted) return;
      setState(() {
        progress = p;
        loadError = null;
      });
      _schedule(p.shouldPoll && pollWhileVisible);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => loadError = e.isSessionInvalid ? null : e.message);
      _schedule(pollWhileVisible); // 网络抖动时继续尝试
    } finally {
      _busy = false;
    }
  }

  void _schedule(bool on) {
    _timer?.cancel();
    _timer = on ? Timer(progressPollInterval, reload) : null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// 英文状态页公共骨架（返回 → 首页）。
class KycScaffold extends StatelessWidget {
  const KycScaffold({super.key, required this.title, required this.content, this.footer});
  final String title;
  final List<Widget> content;
  final List<Widget>? footer;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: IconButton(
        key: const Key('kyc.back'),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.go('/home'),
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: content),
        ),
        if (footer != null) FooterBar(children: [for (final f in footer!) f is AppButton && !f.fitContent ? Expanded(child: f) : f]),
      ],
    ),
  );
}

/// 状态头（原型 .state 紧凑版：图标 + 标题 + 说明）。
class StateHead extends StatelessWidget {
  const StateHead({super.key, required this.icon, required this.title, required this.message, this.tone = BadgeKind.warn});
  final IconData icon;
  final String title;
  final String message;
  final BadgeKind tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeKind.warn => (AppColors.warnWeak, AppColors.warn),
      BadgeKind.neutral => (AppColors.surface2, AppColors.muted),
      _ => (AppColors.primaryWeak, AppColors.primary),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: fg),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// 加载中 / 加载失败。
List<Widget> progressPlaceholder(String? error, VoidCallback retry) => [
  if (error == null)
    const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(child: CircularProgressIndicator()),
    )
  else ...[
    const SizedBox(height: 40),
    StateView(
      icon: Icons.wifi_off_rounded,
      title: "Couldn't load your status",
      message: error,
      actions: [AppButton('Try again', onPressed: retry)],
    ),
  ],
];

void copyText(BuildContext context, String text, {String done = 'Copied'}) {
  Clipboard.setData(ClipboardData(text: text));
  showToast(context, done);
}

enum _StepState { done, active, action, fail, todo }

class _Stepper extends StatelessWidget {
  const _Stepper(this.items);
  final List<(String, String?, _StepState)> items;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dot(i, items[i].$3),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].$1,
                        key: Key('p06.step.$i.${items[i].$3.name}'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: items[i].$3 == _StepState.todo ? FontWeight.w400 : FontWeight.w600,
                          color: items[i].$3 == _StepState.todo ? AppColors.muted : AppColors.text,
                        ),
                      ),
                      if (items[i].$2 != null) Text(items[i].$2!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _dot(int i, _StepState st) {
    final color = switch (st) {
      _StepState.done => AppColors.up,
      _StepState.active => AppColors.primary,
      _StepState.action => AppColors.warn,
      _StepState.fail => AppColors.faint,
      _StepState.todo => AppColors.line,
    };
    final child = switch (st) {
      _StepState.done => const Icon(Icons.check_rounded, size: 14, color: Colors.white),
      _StepState.fail => const Icon(Icons.close_rounded, size: 14, color: Colors.white),
      _StepState.action => const Text(
        '!',
        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
      _StepState.todo => Text(
        '${i + 1}',
        style: const TextStyle(color: AppColors.faint, fontSize: 12, fontWeight: FontWeight.w700),
      ),
      _StepState.active => Text(
        '${i + 1}',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    };
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: st == _StepState.todo ? null : color,
        border: st == _StepState.todo ? Border.all(color: color, width: 2) : null,
      ),
      child: child,
    );
  }
}

/// P-06 开户进度（英文；只展示 DW 真实返回的状态，不做假进度）。
class ApplicationStatusPage extends StatefulWidget {
  const ApplicationStatusPage({super.key});

  @override
  State<ApplicationStatusPage> createState() => _ApplicationStatusPageState();
}

class _ApplicationStatusPageState extends State<ApplicationStatusPage> with ProgressLoader {
  @override
  Widget build(BuildContext context) {
    final p = progress;
    if (p == null) return KycScaffold(title: 'Application status', content: progressPlaceholder(loadError, reload));
    if (p.submitState == 'NOT_SUBMITTED') {
      return KycScaffold(
        title: 'Application status',
        content: [
          const SizedBox(height: 40),
          StateView(
            icon: Icons.description_outlined,
            title: 'No application yet',
            message: 'Finish the application form to submit.',
            actions: [AppButton('Continue application', onPressed: () => context.go('/onboarding/a'))],
          ),
        ],
      );
    }

    final k = p.kycStatus;
    final opened = p.accountOpened;
    final attention = p.submitState == 'NEEDS_ATTENTION';
    final submitting = p.submitState == 'SUBMITTING';
    final kycState = attention
        ? _StepState.action
        : switch (k) {
            'KYC_APPROVED' => _StepState.done,
            'KYC_DENIED' => _StepState.fail,
            'KYC_INFO_REQUIRED' || 'KYC_DOC_REQUIRED' => _StepState.action,
            _ => _StepState.active,
          };
    final kycSub = attention
        ? 'Needs attention from our team'
        : submitting
        ? 'Sending your details to DriveWealth'
        : '${kycLabels[k] ?? k}${p.kycUpdatedAt != null ? ' · ${fmtDateTime(p.kycUpdatedAt)}' : ''}';
    final steps = [
      ('Application submitted', 'Ref ${p.applicationRef ?? '—'} · ${fmtDateTime(p.submittedAt)}', _StepState.done),
      ('Identity verification (by DriveWealth)', kycSub, kycState),
      (
        'Account opening',
        p.accountStatus != null ? accountLabels[p.accountStatus] ?? p.accountStatus : 'Opens automatically after verification',
        opened
            ? _StepState.done
            : p.accountStatus == 'PENDING' || k == 'KYC_APPROVED'
            ? _StepState.active
            : _StepState.todo,
      ),
      (
        'Fund your account',
        opened ? 'Link a bank or wire funds' : 'Available once your account is open',
        opened ? _StepState.active : _StepState.todo,
      ),
    ];

    final content = <Widget>[_Stepper(steps)];
    var footer = <Widget>[AppButton('Back to home', key: const Key('p06.home'), onPressed: () => context.go('/home'))];

    if (attention) {
      content.add(
        const Notice(
          "We hit a problem sending your application to our partner broker. Our team has been notified and will follow up. There's no need to resubmit.",
          kind: NoticeKind.warn,
        ),
      );
    } else if (opened) {
      content.add(_accountCard(p));
      final restricted = p.accountStatus != 'OPEN';
      if (restricted) {
        content.add(
          Notice(
            p.accountStatus == 'FROZEN'
                ? 'Your account is frozen. Trading, deposits and withdrawals are unavailable. Your assets remain safely held; contact support for details.'
                : p.accountStatus == 'OPEN_NO_NEW_TRADES'
                ? 'Your account is sell-only. You cannot buy new securities, but you can sell, deposit and withdraw.'
                : 'Your account is closed. Contact support if you have questions.',
            kind: NoticeKind.danger,
          ),
        );
      } else {
        content.addAll([
          const SectionTitle('Funding options'),
          ListGroup(
            children: [
              ListRow(
                key: const Key('p06.linkBank'),
                icon: Icons.account_balance_outlined,
                title: 'Link a bank account (ACH)',
                subtitle: 'U.S. bank account in your own name. No fee.',
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                onTap: () => context.push('/funding/banks/link'),
              ),
              ListRow(
                icon: Icons.public_rounded,
                title: 'Wire transfer',
                subtitle: 'For large amounts or international banks',
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                onTap: () => context.push('/funding/wire'),
              ),
            ],
          ),
        ]);
        footer = [AppButton('Later', kind: ButtonKind.ghost, key: const Key('p06.later'), onPressed: () => context.go('/home'))];
      }
    } else if (k == 'KYC_APPROVED') {
      content.add(_spinnerCard('Identity verified. Opening your account', 'Timing TBC by DW. This page updates automatically.'));
    } else if (k == 'KYC_INFO_REQUIRED' || k == 'KYC_DOC_REQUIRED') {
      final info = k == 'KYC_INFO_REQUIRED';
      final route = info ? '/application/info' : '/application/document';
      content.add(
        _actionCard(
          key: const Key('p06.action'),
          icon: info ? Icons.edit_outlined : Icons.badge_outlined,
          title: info ? 'Update your information' : 'Upload your ID',
          sub: info ? 'Our partner broker could not verify some details' : 'An ID document is needed to finish verification',
          onTap: () => context.go(route),
        ),
      );
      footer = [AppButton(info ? 'Review my information' : 'Upload document', onPressed: () => context.go(route))];
    } else if (k == 'KYC_DENIED') {
      content.add(
        _actionCard(
          key: const Key('p06.action'),
          icon: Icons.info_outline_rounded,
          title: 'Application unsuccessful',
          sub: 'See the result and your options',
          warn: false,
          onTap: () => context.go('/application/result'),
        ),
      );
      footer = [AppButton('View result', onPressed: () => context.go('/application/result'))];
    } else if (k == 'KYC_MANUAL_REVIEW') {
      content.addAll([
        const Notice(
          'Manual review. Our partner broker is reviewing your application (timing TBC by DW). We will notify you. No need to resubmit.',
        ),
        AppButton('Contact support', kind: ButtonKind.ghost, onPressed: () => _support(p)),
      ]);
    } else {
      content.add(
        _spinnerCard(
          submitting ? 'Submitting your application' : 'Verifying your identity',
          'Timing TBC by DW. This page updates automatically.',
        ),
      );
    }
    content.add(
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Identity verification is performed by our partner broker DriveWealth.',
          style: TextStyle(fontSize: 12, color: AppColors.faint),
        ),
      ),
    );
    if (loadError != null) content.insert(0, Notice(loadError!, kind: NoticeKind.warn));
    return KycScaffold(title: 'Application status', content: content, footer: footer);
  }

  void _support(ApplicationProgress p) => showToast(context, 'Support is not part of this demo build · Ref ${p.applicationRef ?? '—'}');

  Widget _accountCard(ApplicationProgress p) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Your live account is open', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            StatusBadge(accountLabels[p.accountStatus] ?? '', kind: p.accountStatus == 'OPEN' ? BadgeKind.ok : BadgeKind.danger),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('Account number', style: TextStyle(fontSize: 14, color: AppColors.muted)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.accountNo ?? '—',
                key: const Key('p06.accountNo'),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
            if (p.accountNo != null)
              IconButton(
                key: const Key('p06.copy'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.muted),
                onPressed: () => copyText(context, p.accountNo!, done: 'Account number copied'),
              ),
          ],
        ),
        const KvRow('Account type', 'Cash account · Self-directed'),
      ],
    ),
  );

  Widget _spinnerCard(String title, String sub) => AppCard(
    child: Column(
      children: [
        const SizedBox(height: 6),
        const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(height: 12),
        Text(
          title,
          key: const Key('p06.waiting'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );

  Widget _actionCard({
    required Key key,
    required IconData icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
    bool warn = true,
  }) => InkWell(
    key: key,
    onTap: onTap,
    child: AppCard(
      borderColor: warn ? AppColors.warn : null,
      child: Row(
        children: [
          Icon(icon, color: warn ? AppColors.warn : AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 6),
                const StatusBadge(sandboxPendingLabel, kind: BadgeKind.warn),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
        ],
      ),
    ),
  );
}
