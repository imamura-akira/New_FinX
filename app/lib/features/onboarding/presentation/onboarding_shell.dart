import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/application_api.dart';
import '../domain/onboarding_controller.dart';

/// 向开户流程各页面提供同一个 [OnboardingController]（go_router ShellRoute 内创建）。
class OnboardingScope extends InheritedNotifier<OnboardingController> {
  const OnboardingScope({super.key, required OnboardingController controller, required super.child}) : super(notifier: controller);

  static OnboardingController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<OnboardingScope>()!.notifier!;
}

/// 创建并持有控制器；首次进入时加载 GET /application。
class OnboardingHost extends StatefulWidget {
  const OnboardingHost({super.key, required this.child});
  final Widget child;

  @override
  State<OnboardingHost> createState() => _OnboardingHostState();
}

class _OnboardingHostState extends State<OnboardingHost> {
  OnboardingController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c == null) {
      final scope = AppScope.of(context);
      final me = scope.session.me;
      _c = OnboardingController(api: ApplicationApi(scope.api), loginEmail: me?.email ?? '', loginProvider: me?.loginProvider ?? 'EMAIL')
        ..load();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnboardingScope(controller: _c!, child: widget.child);
}

/// 各步标题与说明（原型 OB_HEADS）。
const stepHeads = <String, (String, String)>{
  'b': ('Your identity', 'Enter it exactly as it appears on your government ID.'),
  'c': ('Your tax information', 'Required by the USA PATRIOT Act to verify your identity.'),
  'd': ('Your home address', 'Enter where you actually live. P.O. Boxes are not accepted.'),
  'e': ('Employment & finances', 'Used for suitability assessment and regulatory reporting.'),
  'f': ('A few compliance questions', 'Required by regulators. Please answer truthfully.'),
  'g': ('Your account type', 'Cash account, self-directed. Nothing to choose at launch.'),
  'p04': ('Upload your ID', 'International applicants upload a government-issued photo ID.'),
  'p05': ('Disclosures & signature', 'Review and agree below. Signed electronically (E-Sign).'),
  'p30': ('Review & submit', 'Check everything. FinX sends your details to DriveWealth for verification.'),
};

String routeOf(String step) => '/onboarding/$step';

/// 开户页面骨架（原型新版式）：分段进度条 + STEP X OF N + 大标题 + 说明 + 内容 + 底部按钮。
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.content,
    this.primaryLabel = 'Continue',
    this.onPrimary,
    this.primaryEnabled = true,
    this.loading = false,
    this.showSaveExit = true,
    this.trustNote = false,
    this.showHeader = true,
    this.title = 'Account opening',
  });

  final String step;
  final List<Widget> content;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryEnabled;
  final bool loading;
  final bool showSaveExit;
  final bool trustNote;
  final bool showHeader;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = OnboardingScope.of(context);
    if (c.loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title), leading: const AppBackButton()),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (c.loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title), leading: const AppBackButton()),
        body: StateView(
          icon: Icons.wifi_off_rounded,
          title: "Couldn't load your application",
          message: c.loadError!,
          actions: [AppButton('Try again', onPressed: c.load)],
        ),
      );
    }
    if (!c.editable) return const SubmittedGuard();

    final steps = c.steps;
    final i = c.indexOf(step);
    final head = stepHeads[step];
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => _back(context, c)),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  if (showHeader) ...[
                    Row(
                      children: [
                        for (var k = 0; k < steps.length; k++) ...[
                          if (k > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              key: Key('progress.$k${k <= i ? '.done' : ''}'),
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: k <= i ? null : AppColors.line,
                                gradient: k <= i ? AppGradients.gradSoft : null,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'STEP ${i + 1} OF ${steps.length}',
                      key: const Key('onboarding.stepTag'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2.2, color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    if (head != null) ...[
                      Text(head.$1, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -.3)),
                      const SizedBox(height: 8),
                      Text(head.$2, style: TextStyle(fontSize: 15, color: AppColors.muted, height: 1.55)),
                      const SizedBox(height: 18),
                    ],
                  ],
                  if (c.errors['_'] != null) Notice(c.errors['_']!, kind: NoticeKind.danger),
                  ...content,
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + (keyboardOpen ? 0 : MediaQuery.of(context).padding.bottom)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (showSaveExit && !c.returnToReview) ...[
                        AppButton(
                          'Save & exit',
                          key: const Key('onboarding.saveExit'),
                          kind: ButtonKind.ghost,
                          small: false,
                          onPressed: () => _saveExit(context, c),
                          fitContent: true,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: AppButton(
                          c.returnToReview && step != 'p30' ? 'Save & back to review' : primaryLabel,
                          key: const Key('onboarding.continue'),
                          loading: loading || c.saving,
                          onPressed: primaryEnabled ? onPrimary : null,
                        ),
                      ),
                    ],
                  ),
                  if (trustNote)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.faint),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text('Encrypted in transit and at rest', style: TextStyle(fontSize: 12, color: AppColors.faint)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _back(BuildContext context, OnboardingController c) {
    if (c.returnToReview && step != 'p30') {
      context.go(routeOf('p30'));
      return;
    }
    final i = c.indexOf(step);
    if (i == 0) {
      context.go('/home');
    } else {
      context.go(routeOf(c.steps[i - 1].$1));
    }
  }

  Future<void> _saveExit(BuildContext context, OnboardingController c) async {
    // 保存当前进度（不做完整性校验，草稿允许不完整）
    final ok = await c.saveStep(step, validate: false);
    if (!context.mounted) return;
    if (ok) {
      showToast(context, 'Progress saved. Come back anytime');
      context.go('/home');
    }
  }
}

/// 已提交后再进入开户页（原型 obSubmittedGuard）。
class SubmittedGuard extends StatelessWidget {
  const SubmittedGuard({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Account opening'), leading: const AppBackButton()),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Notice('Your application has been submitted — no need to fill it in again.'),
          AppButton('View application status', onPressed: () => context.go('/application/status')),
        ],
      ),
    ),
  );
}

/// 公共：继续到下一步（或返回 P-30）。
Future<void> continueFrom(BuildContext context, String step) async {
  final c = OnboardingScope.of(context);
  final ok = await c.saveStep(step);
  if (!context.mounted) return;
  if (!ok) {
    showToast(context, 'Please fix the highlighted fields');
    return;
  }
  if (c.returnToReview) {
    context.go(routeOf('p30'));
    return;
  }
  final next = c.nextOf(step);
  if (next != null) context.go(routeOf(next));
}
