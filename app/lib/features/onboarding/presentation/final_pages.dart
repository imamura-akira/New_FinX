import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/onboarding_controller.dart';
import '../domain/options.dart';
import '../domain/validators.dart';
import 'onboarding_shell.dart';
import 'step_pages.dart';

/// 选图：可注入，便于测试。
typedef ImageSource2Picker = Future<XFile?> Function(ImageSource source);
ImageSource2Picker pickImage = (source) => ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 85);

/// P-04 证件上传（仅非美国纳税人）。
class IdUploadPage extends StatefulWidget {
  const IdUploadPage({super.key});

  @override
  State<IdUploadPage> createState() => _IdUploadPageState();
}

class _IdUploadPageState extends State<IdUploadPage> {
  final Map<String, bool> _busy = {};
  final Map<String, String> _err = {};

  Future<void> _pick(OnboardingController c, String side) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await pickImage(source);
    if (file == null) return;
    setState(() {
      _busy[side] = true;
      _err.remove(side);
    });
    final err = await c.uploadDoc(side, await file.readAsBytes());
    if (!mounted) return;
    setState(() {
      _busy[side] = false;
      if (err != null) _err[side] = err;
    });
  }

  Widget _box(OnboardingController c, String side, String label) {
    final done = c.hasDoc(side);
    final busy = _busy[side] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: Key('upload.$side'),
            borderRadius: BorderRadius.circular(12),
            onTap: busy ? null : () => _pick(c, side),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: done ? AppColors.primaryWeak : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: done ? AppColors.primary : AppColors.faint, width: 1.5),
              ),
              child: Column(
                children: [
                  busy
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(done ? Icons.check_rounded : Icons.photo_camera_outlined, color: done ? AppColors.primary2 : AppColors.muted),
                  const SizedBox(height: 8),
                  Text(
                    done ? 'Uploaded · Tap to retake' : 'Take a photo or upload · $label',
                    style: TextStyle(fontSize: 13, color: done ? AppColors.primary2 : AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          if (_err[side] != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(_err[side]!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = OnboardingScope.of(context);
    if (!c.loading && c.isUsTaxPayer) {
      // 美国纳税人：DW 用税号核验，无需上传证件
      return OnboardingScaffold(
        step: 'p05',
        title: 'Identity verification',
        showHeader: false,
        primaryLabel: 'Continue: Disclosures',
        onPrimary: () => context.go(routeOf('p05')),
        content: const [
          Notice(
            'U.S. taxpayers are verified by DriveWealth with their tax ID after submission, so no ID upload is needed. '
            'We will notify you if a document is required.',
            kind: NoticeKind.ok,
          ),
        ],
      );
    }
    return OnboardingScaffold(
      step: 'p04',
      title: 'Identity document',
      primaryLabel: 'Continue: Disclosures',
      primaryEnabled: c.docsReady,
      onPrimary: () {
        if (!c.docsReady) {
          showToast(context, 'Please upload your ID photos first');
          return;
        }
        context.go(routeOf(c.returnToReview ? 'p30' : 'p05'));
      },
      content: [
        const Notice(
          'Upload a valid government-issued photo ID. It is encrypted and submitted to DriveWealth with your application for identity verification.',
        ),
        SelectField(label: 'Document type', fieldKey: const Key('f.docType'), options: idTypes, value: c.docType, onChanged: c.setDocType),
        _box(c, 'FRONT', c.docType == 'PASSPORT' ? 'Passport photo page (FRONT)' : 'Front of ID (FRONT)'),
        if (c.needsBack) _box(c, 'BACK', 'Back of ID (BACK)'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Photo requirements', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final t in const [
                'All four corners visible, nothing covered or cropped',
                'Even lighting, no glare or shadows',
                'Document is not expired',
                'Name matches your application',
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_rounded, size: 16, color: AppColors.up),
                      const SizedBox(width: 8),
                      Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Text(
          'Whether a selfie / liveness check is required is TBC by DriveWealth.',
          style: TextStyle(fontSize: 12, color: AppColors.faint),
        ),
      ],
    );
  }
}

/// P-05 披露确认（DW 披露与平台条款分开呈现）。
class DisclosuresPage extends StatelessWidget {
  const DisclosuresPage({super.key});

  void _openDoc(BuildContext context, String title, bool isDw) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isDw
                      ? 'The full official DriveWealth document appears here.\n\nOfficial address:\n$dwDisclosureUrl'
                      : 'The full FinX platform terms appear here.',
                  style: const TextStyle(fontSize: 12, fontFamily: 'Menlo', height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _docRow(BuildContext context, OnboardingController c, String id, String title, bool isDw) => Container(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: CheckRow(
            key: Key('d.$id'),
            value: c.agreed[id] == true,
            onChanged: (v) => c.setAgreed(id, v),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'I have read and agree to the '),
                  TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        LinkButton('View', fontSize: 12, onPressed: () => _openDoc(context, title, isDw)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = OnboardingScope.of(context);
    final name = c.fullName;
    final sigBad = c.signature.trim().isNotEmpty && !c.signatureMatches;
    return OnboardingScaffold(
      step: 'p05',
      title: 'Disclosures',
      primaryLabel: 'Continue: Review',
      showSaveExit: false,
      primaryEnabled: c.disclosuresReady,
      onPrimary: () => context.go(routeOf('p30')),
      content: [
        AppCard(
          borderColor: AppColors.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text('DriveWealth disclosures', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  StatusBadge('Broker', kind: BadgeKind.info),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Your brokerage account is opened and held by DriveWealth, LLC. Please read these documents before opening. Full documents: $dwDisclosureUrl',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              for (final (id, t) in dwDisclosures) _docRow(context, c, id, t, true),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Rule 14b-1(c) shareholder disclosure',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: ': When an issuer requests it, do you consent to the broker sharing your name, address and positions for shareholder communications?',
                          ),
                        ],
                      ),
                      style: TextStyle(fontSize: 13),
                    ),
                    YesNo(
                      value: c.rule14b == null ? null : c.rule14b == 'YES',
                      keyPrefix: 'd.rule14b',
                      onChanged: (v) => c.setRule14b(v ? 'YES' : 'NO'),
                    ),
                    const SizedBox(height: 4),
                    Text('Choosing No does not affect your application.', style: TextStyle(fontSize: 12, color: AppColors.faint)),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: CheckRow(
                  key: const Key('d.extendedHoursAgreement'),
                  value: c.extendedHours,
                  onChanged: c.setExtendedHours,
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '(Optional) I agree to the '),
                        TextSpan(
                          text: 'Extended Hours Trading Agreement',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                'Document names and fields per official DriveWealth materials.',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text('FinX platform terms', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  StatusBadge('Platform'),
                ],
              ),
              const SizedBox(height: 8),
              for (final (id, t) in partnerDisclosures) _docRow(context, c, id, t, false),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Electronic signature consent', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              CheckRow(
                key: const Key('d.esign'),
                value: c.eSign,
                onChanged: c.setESign,
                child: const Text(
                  'I agree to receive documents and sign agreements electronically under the E-Sign Act of 2000, and confirm my electronic '
                  'signature has the same legal effect as a handwritten one. I may withdraw this consent or request paper copies at any time.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              OText(
                label: 'Type your legal name to sign (${name.isEmpty ? '—' : name})',
                fieldKey: const Key('d.signature'),
                value: c.signature,
                placeholder: name,
                capitalization: TextCapitalization.words,
                error: sigBad ? 'Signature must match your legal name' : null,
                onChanged: c.setSignature,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// P-30 资料确认与提交（提交即由我方后端创建 DW User）。
class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  Widget _group(BuildContext context, OnboardingController c, Set<String> bad, String title, String step, List<(String, String)> rows) =>
      AppCard(
        key: Key('review.$step'),
        borderColor: bad.contains(step) ? AppColors.danger : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (bad.contains(step)) ...[const StatusBadge('Incomplete', kind: BadgeKind.danger), const SizedBox(width: 6)],
                LinkButton(
                  'Edit',
                  key: Key('review.$step.edit'),
                  fontSize: 12,
                  onPressed: () {
                    c.returnToReview = true;
                    context.go(routeOf(step));
                  },
                ),
              ],
            ),
            for (final (k, v) in rows) KvRow(k, v.isEmpty ? '—' : v),
            for (final f in c.errors.entries.where((x) => x.key != '_' && stepOfField(x.key) == step))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(f.value, style: TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = OnboardingScope.of(context);
    final d = c.data;
    final bad = c.incompleteSections;
    final addr = (d['residentialAddress'] as Map?) ?? const {};
    final employed = isEmployed(d['employmentStatus'] as String?);
    final fs = (d['fundingSources'] as List?)?.cast<String>() ?? const <String>[];
    final provider = AppScope.of(context).session.me?.loginProvider ?? c.loginProvider;
    String s(String k) => (d[k] as String?) ?? '';
    final total = dwDisclosures.length + partnerDisclosures.length;

    if (c.submitting) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review & submit'), automaticallyImplyLeading: false),
        body: const StateView(
          icon: Icons.cloud_upload_outlined,
          title: 'Submitting',
          message: 'Securely sending your application to our partner broker. Please keep this page open.',
        ),
      );
    }

    return OnboardingScaffold(
      step: 'p30',
      title: 'Review & submit',
      primaryLabel: 'Submit application',
      showSaveExit: false,
      primaryEnabled: bad.isEmpty,
      onPrimary: () async {
        final (result, message) = await c.submit();
        if (!context.mounted) return;
        if (result != null) {
          c.returnToReview = false;
          context.go('/application/status');
        } else if (message != null) {
          showToast(context, message);
        }
      },
      content: [
        _group(context, c, bad, 'Identity', 'b', [
          ('Name', c.fullName),
          ('Date of birth', s('dateOfBirth')),
          ('Citizenship', labelOf(countries, d['citizenship'] as String?)),
          ('Tax residence', labelOf(countries, d['taxResidency'] as String?)),
          ('Phone', s('phone')),
          ('Contact email', c.contactEmail),
          ('Sign-in method', const {'EMAIL': 'Email code', 'GOOGLE': 'Google', 'APPLE': 'Apple'}[provider] ?? '—'),
          ('Language', labelOf(languages, d['language'] as String?)),
        ]),
        _group(context, c, bad, 'Tax', 'c', [
          ('U.S. taxpayer', yesNoLabel(d['usTaxPayer'])),
          ('Tax ID type', labelOf(tinTypesFor(d['usTaxPayer'] as String?), d['tinType'] as String?)),
          ('Tax ID', maskTin(d['tin'] as String?)),
          if (c.isUsTaxPayer)
            ('IRS backup withholding', yesNoLabel(d['irsBackup']))
          else
            ('Tax treaty claimed', yesNoLabel(d['taxTreaty'])),
        ]),
        _group(context, c, bad, 'Home address', 'd', [
          ('Address', [addr['line1'], addr['line2']].whereType<String>().where((x) => x.isNotEmpty).join(', ')),
          ('City / State', [addr['city'], addr['state']].whereType<String>().where((x) => x.isNotEmpty).join(', ')),
          ('ZIP', (addr['postalCode'] as String?) ?? ''),
          ('Country', labelOf(countries, addr['country'] as String?)),
        ]),
        _group(context, c, bad, 'Employment & finances', 'e', [
          ('Employment status', labelOf(employmentStatuses, d['employmentStatus'] as String?)),
          if (employed) ('Employer', s('employerName')),
          if (employed) ('Industry', labelOf(industries, d['industry'] as String?)),
          if (employed && s('position').isNotEmpty) ('Position', labelOf(positions, d['position'] as String?)),
          ('Annual income', labelOf(incomeRanges, d['annualIncomeRange'] as String?)),
          ('Net worth', labelOf(netWorthRanges, d['netWorthRange'] as String?)),
          ('Liquid net worth', labelOf(netWorthRanges, d['netWorthLiquidRange'] as String?)),
          ('Experience', labelOf(experiences, d['investmentExperience'] as String?)),
          ('Objective', labelOf(objectives, d['investmentObjective'] as String?)),
          ('Risk tolerance', labelOf(riskLevels, d['riskTolerance'] as String?)),
          ('Sources of funds', fs.map((v) => labelOf(fundingSources, v)).join(', ')),
        ]),
        _group(context, c, bad, 'Compliance', 'f', [
          ('Broker-dealer / FINRA / exchange', yesNoLabel(d['isAffiliatedBD'])),
          ('Politically exposed person', yesNoLabel(d['isPEP'])),
          ('Public company control person', yesNoLabel(d['isControlPerson'])),
        ]),
        _group(context, c, bad, 'Account type', 'g', const [
          ('Type', 'Cash account · Self-directed'),
          ('accountType', 'LIVE'),
          ('tradingType', 'CASH'),
          ('accountManagementType', 'SELF'),
          ('riaID / riaProductID', 'Omission TBC with DW'),
        ]),
        if (!c.isUsTaxPayer)
          _group(context, c, bad, 'Identity document', 'p04', [
            ('Document type', labelOf(idTypes, c.docType)),
            ('Front', c.hasDoc('FRONT') ? 'Uploaded' : ''),
            if (c.needsBack) ('Back', c.hasDoc('BACK') ? 'Uploaded' : ''),
          ]),
        _group(context, c, bad, 'Signed disclosures', 'p05', [
          ('Documents agreed', '${c.agreedCount} / $total'),
          ('Rule 14b-1(c)', c.rule14b == 'YES' ? 'Consent' : (c.rule14b == 'NO' ? 'No consent' : '—')),
          ('Extended hours agreement', c.extendedHours ? 'Agreed' : 'Not selected'),
          ('E-signature', c.signature.trim()),
        ]),
        if (bad.isNotEmpty)
          const Notice('Sections marked in red are incomplete. Please fix them before submitting.', kind: NoticeKind.danger),
      ],
    );
  }
}
