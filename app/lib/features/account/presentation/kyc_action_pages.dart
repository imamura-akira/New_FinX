import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_api.dart';
import 'application_status_page.dart';

// P-34 / P-35 / P-36（英文）。DW 沙盒无法触发这三种 KYC 结果（Q-DW-5），
// 页面只按 /application/status 的真实返回渲染；重新提交接口（PATCH /application/remediate、
// 补证件后重跑 KYC）待沙盒验证后接入，按钮暂不可用并标注 "Pending sandbox verification"。
// 演示时这一段用原型的模拟模式（design/demo-script.md）。

const _fieldLabels = {
  'firstName': 'First name',
  'lastName': 'Last name',
  'dateOfBirth': 'Date of birth',
  'residentialAddress': 'Home address',
  'residentialAddress.line1': 'Street address',
  'residentialAddress.city': 'City',
  'residentialAddress.state': 'State',
  'residentialAddress.postalCode': 'ZIP code',
  'tin': 'Tax ID',
};

/// 状态不符时（原型 kycStateGuard）。
List<Widget> _nothingToDo(BuildContext context) => [
  const SizedBox(height: 40),
  StateView(
    icon: Icons.check_rounded,
    title: 'Nothing to do right now',
    message: 'Your application has nothing that needs attention.',
    actions: [AppButton('View application status', onPressed: () => context.go('/application/status'))],
  ),
];

Widget _sandboxNotice() => const Notice(
  'Resubmission is not yet available: DriveWealth sandbox cannot produce this result, so this step is pending sandbox verification.',
  kind: NoticeKind.warn,
);

/// P-34 补充开户资料（KYC_INFO_REQUIRED）。
class KycInfoRequiredPage extends StatefulWidget {
  const KycInfoRequiredPage({super.key});

  @override
  State<KycInfoRequiredPage> createState() => _KycInfoRequiredPageState();
}

class _KycInfoRequiredPageState extends State<KycInfoRequiredPage> with ProgressLoader {
  @override
  bool get pollWhileVisible => false;

  @override
  Widget build(BuildContext context) {
    const title = 'Update your information';
    final p = progress;
    if (p == null) return KycScaffold(title: title, content: progressPlaceholder(loadError, reload));
    if (p.kycStatus != 'KYC_INFO_REQUIRED') return KycScaffold(title: title, content: _nothingToDo(context));
    return KycScaffold(
      title: title,
      content: [
        const StateHead(
          icon: Icons.edit_outlined,
          title: 'Almost there. Please review the items below',
          message: 'Our partner broker could not verify some of your details. Update the highlighted items and resubmit for verification.',
        ),
        const Center(child: StatusBadge(sandboxPendingLabel, kind: BadgeKind.warn)),
        const SizedBox(height: 12),
        if (p.issues.isEmpty)
          const Notice('DriveWealth did not specify which items to review. Please contact support.')
        else
          for (final (n, i) in p.issues.indexed)
            AppCard(
              key: Key('p34.issue.$n'),
              borderColor: AppColors.warnWeak,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${n + 1}. ${_fieldLabels[i.field] ?? i.field ?? 'Your details'}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const StatusBadge('Review', kind: BadgeKind.warn),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Notice(i.userMessage, kind: NoticeKind.warn),
                ],
              ),
            ),
        _sandboxNotice(),
      ],
      footer: [
        AppButton('Contact support', kind: ButtonKind.ghost, fitContent: true, onPressed: () => _support(context, p)),
        const AppButton('Resubmit for verification', key: Key('p34.submit'), onPressed: null),
      ],
    );
  }
}

/// P-35 补充身份证件（KYC_DOC_REQUIRED）。
class KycDocRequiredPage extends StatefulWidget {
  const KycDocRequiredPage({super.key});

  @override
  State<KycDocRequiredPage> createState() => _KycDocRequiredPageState();
}

class _KycDocRequiredPageState extends State<KycDocRequiredPage> with ProgressLoader {
  @override
  bool get pollWhileVisible => false;

  @override
  Widget build(BuildContext context) {
    const title = 'Upload your ID';
    final p = progress;
    if (p == null) return KycScaffold(title: title, content: progressPlaceholder(loadError, reload));
    if (p.kycStatus != 'KYC_DOC_REQUIRED') return KycScaffold(title: title, content: _nothingToDo(context));
    final reason = p.issues.isNotEmpty
        ? p.issues.first.userMessage
        : 'Our partner broker needs a government-issued photo ID to finish verifying your identity.';
    return KycScaffold(
      title: title,
      content: [
        StateHead(icon: Icons.badge_outlined, title: 'Upload an ID to finish verification', message: reason),
        const Center(child: StatusBadge(sandboxPendingLabel, kind: BadgeKind.warn)),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Accepted documents (any one)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  StatusBadge('Passport'),
                  StatusBadge("Driver's license"),
                  StatusBadge('National ID card'),
                  StatusBadge('Residence permit'),
                ],
              ),
              SizedBox(height: 8),
              Text('Must be government-issued, photo-bearing and unexpired.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        const Notice('Your document is encrypted, sent to FinX and submitted to DriveWealth solely for identity verification.'),
        _sandboxNotice(),
      ],
      footer: [
        AppButton('Contact support', kind: ButtonKind.ghost, fitContent: true, onPressed: () => _support(context, p)),
        const AppButton('Submit document', key: Key('p35.submit'), onPressed: null),
      ],
    );
  }
}

/// P-36 开户未通过（KYC_DENIED）。不展示具体原因。
class KycDeniedPage extends StatefulWidget {
  const KycDeniedPage({super.key});

  @override
  State<KycDeniedPage> createState() => _KycDeniedPageState();
}

class _KycDeniedPageState extends State<KycDeniedPage> with ProgressLoader {
  @override
  bool get pollWhileVisible => false;

  @override
  Widget build(BuildContext context) {
    const title = 'Application result';
    final p = progress;
    if (p == null) return KycScaffold(title: title, content: progressPlaceholder(loadError, reload));
    if (p.kycStatus != 'KYC_DENIED') return KycScaffold(title: title, content: _nothingToDo(context));
    return KycScaffold(
      title: title,
      content: [
        const StateHead(
          icon: Icons.info_outline_rounded,
          tone: BadgeKind.neutral,
          title: "We can't open your account right now",
          message: 'This decision was made by our partner broker DriveWealth based on identity verification and compliance requirements. For compliance reasons we cannot share specifics.',
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Application reference', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  if (p.applicationRef != null) LinkButton('Copy', fontSize: 12, onPressed: () => copyText(context, p.applicationRef!)),
                ],
              ),
              const SizedBox(height: 6),
              Text(p.applicationRef ?? '—', key: const Key('p36.ref'), style: const TextStyle(fontSize: 17, letterSpacing: .5)),
              Divider(height: 24, color: AppColors.line),
              KvRow('Decided at', fmtDateTime(p.kycUpdatedAt)),
            ],
          ),
        ),
        const SectionTitle('What you can do'),
        ListGroup(
          children: [
            ListRow(
              icon: Icons.help_outline_rounded,
              title: 'Contact support',
              subtitle: 'Your reference number is attached automatically',
              onTap: () => _support(context, p),
            ),
            ListRow(
              icon: Icons.show_chart_rounded,
              title: 'Keep browsing markets',
              subtitle: 'Quotes and watchlists remain available',
              onTap: () => context.go('/market'),
            ),
            ListRow(
              icon: Icons.delete_outline_rounded,
              title: 'Request deletion of your data',
              subtitle: 'Process TBC with legal',
              onTap: () => showToast(context, 'Data deletion requests are TBC with legal'),
            ),
          ],
        ),
      ],
      footer: [AppButton('Back to home', onPressed: () => context.go('/home'))],
    );
  }
}

void _support(BuildContext context, ApplicationProgress p) =>
    showToast(context, 'Support is not part of this demo build · Ref ${p.applicationRef ?? '—'}');
