import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/onboarding_controller.dart';
import '../domain/options.dart';
import '../domain/validators.dart';
import 'onboarding_shell.dart';

/// 文本输入：自持 TextEditingController，变化写回控制器。
class OText extends StatefulWidget {
  const OText({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.error,
    this.hint,
    this.placeholder,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.fieldKey,
    this.capitalization = TextCapitalization.none,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? error;
  final String? hint;
  final String? placeholder;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final Key? fieldKey;
  final TextCapitalization capitalization;

  @override
  State<OText> createState() => _OTextState();
}

class _OTextState extends State<OText> {
  late final TextEditingController _c = TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(OText old) {
    super.didUpdateWidget(old);
    // 外部重置（如切换纳税人身份清空税号）时同步
    if ((widget.value ?? '') != _c.text && (widget.value == null || widget.value!.isEmpty)) _c.text = '';
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = TextField(
      key: widget.fieldKey,
      controller: _c,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscure,
      autocorrect: false,
      enableSuggestions: !widget.obscure,
      textCapitalization: widget.capitalization,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: widget.placeholder,
        enabledBorder: widget.error == null
            ? null
            : OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppShape.inputRadius),
                borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
              ),
      ),
    );
    return FieldShell(
      label: widget.label,
      error: widget.error,
      hint: widget.hint,
      child: widget.suffix == null
          ? input
          : Row(
              children: [
                Expanded(child: input),
                const SizedBox(width: 8),
                widget.suffix!,
              ],
            ),
    );
  }
}

/// 是/否问题卡片（原型 yesno）。
Widget yesNoCard({
  required String question,
  String? help,
  required bool? value,
  required ValueChanged<bool> onChanged,
  String? error,
  List<Widget> whenYes = const [],
  required String keyPrefix,
}) => AppCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      if (help != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(help, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ),
      YesNo(value: value, onChanged: onChanged, keyPrefix: keyPrefix),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(error, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ),
      if (value == true && whenYes.isNotEmpty) ...[const SizedBox(height: 12), ...whenYes],
    ],
  ),
);

bool? _yn(String? v) => v == 'YES' ? true : (v == 'NO' ? false : null);
String _ynStr(bool v) => v ? 'YES' : 'NO';

/// P-03a–g。
class OnboardingStepPage extends StatefulWidget {
  const OnboardingStepPage({super.key, required this.step});
  final String step;

  @override
  State<OnboardingStepPage> createState() => _OnboardingStepPageState();
}

class _OnboardingStepPageState extends State<OnboardingStepPage> {
  bool _showTin = false;

  @override
  Widget build(BuildContext context) {
    final c = OnboardingScope.of(context);
    final e = c.errors;
    final d = c.data;
    String? s(String k) => d[k] as String?;
    Map<String, dynamic> addr() => Map<String, dynamic>.from((d['residentialAddress'] as Map?) ?? const {});

    switch (widget.step) {
      case 'a':
        final resumed = c.status == 'DRAFT';
        return OnboardingScaffold(
          step: 'a',
          showHeader: false,
          showSaveExit: false,
          primaryLabel: resumed ? 'Resume application' : 'Start application',
          onPrimary: () => continueFrom(context, 'a'),
          content: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: AppGradients.hero, borderRadius: BorderRadius.circular(AppShape.radiusLarge)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INDIVIDUAL BROKERAGE ACCOUNT', style: TextStyle(fontSize: 13, color: Color(0xB8FFFFFF))),
                  SizedBox(height: 4),
                  Text(
                    "Let's open your account",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Opened and held by our partner broker DriveWealth. Most U.S. taxpayers verify with a tax ID, no ID photos needed; '
                    'international applicants upload one. Verification time TBC by DW.',
                    style: TextStyle(fontSize: 13, color: Color(0xB8FFFFFF)),
                  ),
                ],
              ),
            ),
            const SectionTitle("What you'll need"),
            const ListGroup(
              children: [
                ListRow(
                  icon: Icons.shield_outlined,
                  title: 'Your SSN / ITIN / national tax ID',
                  subtitle: 'Used to verify your identity and for tax reporting',
                ),
                ListRow(
                  icon: Icons.badge_outlined,
                  title: 'A government-issued photo ID',
                  subtitle: 'International applicants upload a passport or ID card',
                ),
                ListRow(icon: Icons.schedule_rounded, title: 'About 5 minutes', subtitle: 'You can pause and come back anytime'),
              ],
            ),
            const Notice('Your information is encrypted, sent to FinX, then submitted to DriveWealth for identity verification.'),
          ],
        );

      case 'b':
        return OnboardingScaffold(
          step: 'b',
          onPrimary: () => continueFrom(context, 'b'),
          content: [
            TwoColumns(
              left: OText(
                label: 'First name',
                fieldKey: const Key('f.firstName'),
                value: s('firstName'),
                placeholder: 'Jane',
                error: e['firstName'],
                capitalization: TextCapitalization.words,
                onChanged: (v) => c.set('firstName', v),
              ),
              right: OText(
                label: 'Last name',
                fieldKey: const Key('f.lastName'),
                value: s('lastName'),
                placeholder: 'Doe',
                error: e['lastName'],
                capitalization: TextCapitalization.words,
                onChanged: (v) => c.set('lastName', v),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Use standard ASCII characters only, exactly as on your government ID.',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
            ),
            DateField(
              label: 'Date of birth',
              fieldKey: const Key('f.dateOfBirth'),
              value: s('dateOfBirth'),
              error: e['dateOfBirth'],
              hint: 'You must be 18 or older to open an account.',
              onChanged: (v) => c.set('dateOfBirth', v),
            ),
            SelectField(
              label: 'Citizenship',
              fieldKey: const Key('f.citizenship'),
              options: countries,
              value: s('citizenship'),
              error: e['citizenship'],
              onChanged: (v) => c.set('citizenship', v),
            ),
            SelectField(
              label: 'Country of tax residence',
              fieldKey: const Key('f.taxResidency'),
              options: countries,
              value: s('taxResidency'),
              error: e['taxResidency'],
              onChanged: (v) => c.set('taxResidency', v),
            ),
            OText(
              label: 'Phone number (with country code)',
              fieldKey: const Key('f.phone'),
              value: s('phone'),
              placeholder: '+1 415 555 0142',
              keyboardType: TextInputType.phone,
              error: e['phone'],
              onChanged: (v) => c.set('phone', v),
            ),
            OText(
              label: 'Contact email',
              fieldKey: const Key('f.contactEmail'),
              value: s('contactEmail') ?? c.loginEmail,
              keyboardType: TextInputType.emailAddress,
              error: e['contactEmail'],
              hint: 'Defaults to your sign-in email. Used for broker notices and documents.',
              onChanged: (v) => c.set('contactEmail', v),
            ),
            SelectField(
              label: 'Language for documents & notices',
              fieldKey: const Key('f.language'),
              options: languages,
              value: s('language'),
              error: e['language'],
              onChanged: (v) => c.set('language', v),
            ),
          ],
        );

      case 'c':
        final us = s('usTaxPayer');
        final tinTypes = tinTypesFor(us);
        final masked = (s('tin') ?? '').contains('•');
        return OnboardingScaffold(
          step: 'c',
          trustNote: true,
          onPrimary: () => continueFrom(context, 'c'),
          content: [
            yesNoCard(
              question: 'Are you a U.S. taxpayer?',
              help: 'U.S. citizens, green-card holders and other U.S. tax residents.',
              value: _yn(us),
              error: e['usTaxPayer'],
              keyPrefix: 'f.usTaxPayer',
              onChanged: (v) => c.set('usTaxPayer', _ynStr(v)),
            ),
            if (us != null) ...[
              SelectField(
                label: 'Tax ID type',
                fieldKey: const Key('f.tinType'),
                options: tinTypes,
                value: s('tinType'),
                error: e['tinType'],
                onChanged: (v) => c.set('tinType', v),
              ),
              OText(
                key: ValueKey('tin-$us'),
                label: 'Tax ID',
                fieldKey: const Key('f.tin'),
                value: s('tin'),
                placeholder: s('tinType') == 'SSN' ? '123-45-6789' : '',
                obscure: !_showTin && !masked,
                error: e['tin'],
                hint: masked
                    ? 'Saved. Enter a new number only if you need to change it.'
                    : 'We encrypt it and never display it in full again.',
                onChanged: (v) => c.set('tin', v),
                suffix: masked
                    ? null
                    : AppButton(
                        _showTin ? 'Hide' : 'Show',
                        key: const Key('f.tin.toggle'),
                        kind: ButtonKind.ghost,
                        small: true,
                        onPressed: () => setState(() => _showTin = !_showTin),
                      ),
              ),
              if (us == 'YES')
                yesNoCard(
                  question: 'Has the IRS notified you that your account is subject to backup withholding?',
                  value: _yn(s('irsBackup')),
                  keyPrefix: 'f.irsBackup',
                  onChanged: (v) => c.set('irsBackup', _ynStr(v)),
                )
              else
                yesNoCard(
                  question: 'Does your country of tax residence have a tax treaty with the U.S., and do you want to claim treaty rates?',
                  help: 'Used to prepare your W-8BEN. Final form per DriveWealth requirements.',
                  value: _yn(s('taxTreaty')),
                  error: e['taxTreaty'],
                  keyPrefix: 'f.taxTreaty',
                  onChanged: (v) => c.set('taxTreaty', _ynStr(v)),
                ),
              CheckRow(
                key: const Key('f.tinConfirm'),
                value: d['tinConfirm'] == true,
                error: e['tinConfirm'],
                onChanged: (v) => c.set('tinConfirm', v),
                child: const Text('I confirm this is my own government-issued number, used to file taxes.'),
              ),
            ],
          ],
        );

      case 'd':
        final a = addr();
        final hasMailing = d['mailingAddress'] is Map;
        return OnboardingScaffold(
          step: 'd',
          onPrimary: () => continueFrom(context, 'd'),
          content: [
            const Notice('Enter the address where you actually live. P.O. Boxes are not accepted.', kind: NoticeKind.warn),
            SelectField(
              label: 'Country/region',
              fieldKey: const Key('f.country'),
              options: countries,
              value: a['country'] as String?,
              error: e['residentialAddress.country'],
              onChanged: (v) => c.setAddress('residentialAddress', 'country', v),
            ),
            OText(
              label: 'Street address',
              fieldKey: const Key('f.line1'),
              value: a['line1'] as String?,
              placeholder: '200 Market Street',
              error:
                  e['residentialAddress.line1'] ??
                  (poBoxRe.hasMatch(a['line1'] as String? ?? '') ? 'Home address cannot be a P.O. Box' : null),
              onChanged: (v) => c.setAddress('residentialAddress', 'line1', v),
            ),
            OText(
              label: 'Apt, suite, floor (optional)',
              fieldKey: const Key('f.line2'),
              value: a['line2'] as String?,
              placeholder: 'Apt 5B',
              onChanged: (v) => c.setAddress('residentialAddress', 'line2', v),
            ),
            TwoColumns(
              left: OText(
                label: 'City',
                fieldKey: const Key('f.city'),
                value: a['city'] as String?,
                error: e['residentialAddress.city'],
                onChanged: (v) => c.setAddress('residentialAddress', 'city', v),
              ),
              right: OText(
                label: 'State/Province',
                fieldKey: const Key('f.state'),
                value: a['state'] as String?,
                error: e['residentialAddress.state'],
                onChanged: (v) => c.setAddress('residentialAddress', 'state', v),
              ),
            ),
            OText(
              label: 'ZIP / Postal code',
              fieldKey: const Key('f.postalCode'),
              value: a['postalCode'] as String?,
              error: e['residentialAddress.postalCode'],
              onChanged: (v) => c.setAddress('residentialAddress', 'postalCode', v),
            ),
            CheckRow(
              key: const Key('f.hasMailing'),
              value: hasMailing,
              onChanged: (v) => c.set('mailingAddress', v ? <String, dynamic>{} : null),
              child: const Text('My mailing address is different'),
            ),
            if (hasMailing)
              OText(
                label: 'Mailing address (P.O. Box allowed)',
                fieldKey: const Key('f.mailLine1'),
                value: (d['mailingAddress'] as Map)['line1'] as String?,
                error: e['mailingAddress.line1'],
                onChanged: (v) => c.setAddress('mailingAddress', 'line1', v),
              ),
          ],
        );

      case 'e':
        final status = s('employmentStatus');
        final employed = isEmployed(status);
        final fs = (d['fundingSources'] as List?)?.cast<String>() ?? const <String>[];
        return OnboardingScaffold(
          step: 'e',
          onPrimary: () => continueFrom(context, 'e'),
          content: [
            SelectField(
              label: 'Employment status',
              fieldKey: const Key('f.employmentStatus'),
              options: employmentStatuses,
              value: status,
              error: e['employmentStatus'],
              onChanged: (v) => c.set('employmentStatus', v),
            ),
            if (employed) ...[
              OText(
                label: status == 'SELF_EMPLOYED' ? 'Business name' : 'Employer name',
                fieldKey: const Key('f.employerName'),
                value: s('employerName'),
                error: e['employerName'],
                onChanged: (v) => c.set('employerName', v),
              ),
              // 行业与职位下拉：DW 开户必需（pages.md 3.1.6，ui-signoff 第 3 节登记）
              SelectField(
                label: 'Industry',
                fieldKey: const Key('f.industry'),
                options: industries,
                value: s('industry'),
                error: e['industry'],
                onChanged: (v) => c.set('industry', v),
              ),
              SelectField(
                label: 'Position (optional)',
                fieldKey: const Key('f.position'),
                options: positions,
                value: s('position'),
                error: e['position'],
                onChanged: (v) => c.set('position', v),
              ),
            ],
            SelectField(
              label: 'Annual income',
              fieldKey: const Key('f.annualIncomeRange'),
              options: incomeRanges,
              value: s('annualIncomeRange'),
              error: e['annualIncomeRange'],
              onChanged: (v) => c.set('annualIncomeRange', v),
            ),
            SelectField(
              label: 'Net worth',
              fieldKey: const Key('f.netWorthRange'),
              options: netWorthRanges,
              value: s('netWorthRange'),
              error: e['netWorthRange'],
              onChanged: (v) => c.set('netWorthRange', v),
            ),
            SelectField(
              label: 'Liquid net worth',
              fieldKey: const Key('f.netWorthLiquidRange'),
              options: netWorthRanges,
              value: s('netWorthLiquidRange'),
              error: e['netWorthLiquidRange'],
              hint: 'Assets you can quickly convert to cash: deposits, stocks, etc.',
              onChanged: (v) => c.set('netWorthLiquidRange', v),
            ),
            FieldShell(
              label: 'Sources of funds (select all that apply)',
              error: e['fundingSources'],
              hint: 'For anti-money-laundering checks.',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (v, l) in fundingSources)
                    ChipToggle(key: Key('f.fund.$v'), label: l, selected: fs.contains(v), onTap: () => c.toggleFundingSource(v)),
                ],
              ),
            ),
            const SectionTitle('Investor profile'),
            SelectField(
              label: 'Investment experience',
              fieldKey: const Key('f.investmentExperience'),
              options: experiences,
              value: s('investmentExperience'),
              error: e['investmentExperience'],
              onChanged: (v) => c.set('investmentExperience', v),
            ),
            SelectField(
              label: 'Investment objective',
              fieldKey: const Key('f.investmentObjective'),
              options: objectives,
              value: s('investmentObjective'),
              error: e['investmentObjective'],
              onChanged: (v) => c.set('investmentObjective', v),
            ),
            SelectField(
              label: 'Risk tolerance',
              fieldKey: const Key('f.riskTolerance'),
              options: riskLevels,
              value: s('riskTolerance'),
              error: e['riskTolerance'],
              onChanged: (v) => c.set('riskTolerance', v),
            ),
            const Text(
              'All fields above are required by DriveWealth to open your account.',
              style: TextStyle(fontSize: 12, color: AppColors.faint),
            ),
          ],
        );

      case 'f':
        final roles = (d['pepRoles'] as List?)?.cast<Map>() ?? const [];
        return OnboardingScaffold(
          step: 'f',
          onPrimary: () => continueFrom(context, 'f'),
          content: [
            yesNoCard(
              question: '1. Are you, or anyone with a beneficial interest in this account, employed by a registered broker-dealer, FINRA or a securities exchange?',
              value: d['isAffiliatedBD'] as bool?,
              error: e['isAffiliatedBD'],
              keyPrefix: 'f.isAffiliatedBD',
              onChanged: (v) => c.set('isAffiliatedBD', v),
              whenYes: [
                OText(
                  label: 'Firm name',
                  fieldKey: const Key('f.affiliatedFirmName'),
                  value: s('affiliatedFirmName'),
                  error: e['affiliatedFirmName'],
                  onChanged: (v) => c.set('affiliatedFirmName', v),
                ),
                const Notice(
                  'Under FINRA rules you may need to notify your employer in writing, and your employer may request duplicate account statements.',
                ),
                CheckRow(
                  key: const Key('f.affiliatedAck'),
                  value: d['affiliatedAck'] == true,
                  error: e['affiliatedAck'],
                  onChanged: (v) => c.set('affiliatedAck', v),
                  child: const Text('I understand the notification requirements above'),
                ),
              ],
            ),
            yesNoCard(
              question: '2. Are you a politically exposed person (PEP)?',
              help:
                  'Someone who holds or has held a prominent public position: heads of state, senior government, judicial or military officials, '
                  'senior executives of state-owned enterprises, important party officials, plus their immediate family and close associates.',
              value: d['isPEP'] as bool?,
              error: e['isPEP'],
              keyPrefix: 'f.isPEP',
              onChanged: (v) => c.set('isPEP', v),
              whenYes: [
                OText(
                  label: 'Name of the PEP',
                  fieldKey: const Key('f.pepName'),
                  value: s('pepName'),
                  error: e['pepName'],
                  onChanged: (v) => c.set('pepName', v),
                ),
                SelectField(label: 'Country/region', options: countries, value: s('pepCountry'), onChanged: (v) => c.set('pepCountry', v)),
                OText(
                  label: 'Role and years held',
                  value: roles.isNotEmpty ? roles.first['role'] as String? : null,
                  placeholder: 'e.g. City council member, 2015–2020',
                  onChanged: (v) => c.set(
                    'pepRoles',
                    v.trim().isEmpty
                        ? null
                        : [
                            {'role': v},
                          ],
                  ),
                ),
              ],
            ),
            yesNoCard(
              question: '3. Are you a director, 10% shareholder or policy-making officer of a publicly traded company?',
              value: d['isControlPerson'] as bool?,
              error: e['isControlPerson'],
              keyPrefix: 'f.isControlPerson',
              onChanged: (v) => c.set('isControlPerson', v),
              whenYes: [
                OText(
                  label: 'Company name or ticker',
                  fieldKey: const Key('f.controlCompanyName'),
                  value: s('controlCompanyName'),
                  error: e['controlCompanyName'],
                  onChanged: (v) => c.set('controlCompanyName', v),
                ),
              ],
            ),
          ],
        );

      case 'g':
        return OnboardingScaffold(
          step: 'g',
          primaryLabel: c.isUsTaxPayer ? 'Continue: Disclosures' : 'Continue: Upload ID',
          onPrimary: () => continueFrom(context, 'g'),
          content: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text("The account you'll open", style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
            const AppCard(
              borderColor: AppColors.primaryWeak,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Cash account · Self-directed', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      StatusBadge('Only type at launch', kind: BadgeKind.ok),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Trade with settled funds only, no margin. You make all investment decisions.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  Divider(height: 24, color: AppColors.line),
                  KvRow('accountType', 'LIVE'),
                  KvRow('tradingType', 'CASH'),
                  KvRow('accountManagementType', 'SELF'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text('Not yet available', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 8),
            for (final (t, sub) in const [
              ('Margin account (MARGIN)', 'Not yet available · TBC by DW'),
              ('Advisor-managed (RIA_MANAGED)', 'Not yet available · TBC by DW'),
            ])
              Opacity(
                opacity: .5,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radio_button_unchecked, size: 20, color: AppColors.faint),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Notice(
              'Account type is fixed. Whether riaID / riaProductID must be omitted for SELF accounts is TBC with DW; '
              'final combinations subject to DW sandbox testing.',
            ),
          ],
        );
    }
    return const SizedBox.shrink();
  }
}

/// 供 P-30 汇总展示使用的标签。
String yesNoLabel(Object? v) => switch (v) {
  'YES' || true => 'Yes',
  'NO' || false => 'No',
  _ => '—',
};

/// 打码显示税号（与原型 maskTin 一致：除后 4 位外替换为 •）。
String maskTin(String? t) {
  if (t == null || t.isEmpty) return '—';
  if (t.contains('•')) return t;
  final chars = t.split('');
  var alnum = chars.where((c) => RegExp(r'[A-Za-z0-9]').hasMatch(c)).length;
  return chars.map((c) {
    if (!RegExp(r'[A-Za-z0-9]').hasMatch(c)) return c;
    return alnum-- > 4 ? '•' : c;
  }).join();
}

/// 对外暴露：控制器类型别名，便于页面测试注入。
typedef OnboardingState = OnboardingController;
