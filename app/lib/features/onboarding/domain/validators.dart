import 'options.dart';

/// 分步校验（文案与原型 OB_VALIDATE、后端 validate.go 一致；字段名为接口字段名，嵌套字段用 "a.b"）。
/// 返回 字段 → 错误文案；空表示通过。服务端 42200 的 fields[] 使用同样的字段名，可直接合并显示。

final asciiNameRe = RegExp(r"^[A-Za-z]+(?:[ '\-][A-Za-z]+)*$");
final _phoneRe = RegExp(r'^\+?[\d\s\-()]{7,20}$');
final _emailRe = RegExp(r'^\S+@\S+\.\S+$');
final poBoxRe = RegExp(r'\b(p\.?\s*o\.?\s*box|p\.?\s*o\.?\s*b\.?\s*\d|post\s+office\s+box|pmb\s*\d|po\s*box)\b', caseSensitive: false);
final _ssnRe = RegExp(r'^\d{3}-?\d{2}-?\d{4}$');
final _itinRe = RegExp(r'^9\d{2}-?\d{2}-?\d{4}$');

String _s(Map<String, dynamic> d, String k) => (d[k] as String? ?? '').trim();
Map<String, dynamic> _m(Map<String, dynamic> d, String k) => (d[k] as Map?)?.cast<String, dynamic>() ?? const {};

int? ageOn(String dob, DateTime now) {
  final d = DateTime.tryParse(dob);
  if (d == null) return null;
  var a = now.year - d.year;
  if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
  return a;
}

/// SSA 结构规则与常见示例号码（DW 拒绝无效 SSN，见 sandbox-log.md）。
bool plausibleSsn(String s) {
  final d = s.replaceAll(RegExp(r'[\s-]'), '');
  if (d.length != 9) return false;
  final area = d.substring(0, 3), group = d.substring(3, 5), serial = d.substring(5);
  if (area == '000' || area == '666' || area.startsWith('9') || group == '00' || serial == '0000') return false;
  return !const {'123456789', '078051120', '219099999'}.contains(d);
}

bool _in(List<Option> opts, String? v) => opts.any((o) => o.$1 == v);

Map<String, String> validateStep(String step, Map<String, dynamic> d, {String loginEmail = '', DateTime? now}) {
  final e = <String, String>{};
  switch (step) {
    case 'b':
      if (!asciiNameRe.hasMatch(_s(d, 'firstName'))) e['firstName'] = 'Use standard ASCII letters only (no é, и, Chinese, etc.)';
      if (!asciiNameRe.hasMatch(_s(d, 'lastName'))) e['lastName'] = 'Use standard ASCII letters only (no é, и, Chinese, etc.)';
      final age = ageOn(_s(d, 'dateOfBirth'), now ?? DateTime.now());
      if (age == null) {
        e['dateOfBirth'] = 'Select your date of birth';
      } else if (age < 18) {
        e['dateOfBirth'] = 'You must be 18 or older to open an account';
      } else if (age > 120) {
        e['dateOfBirth'] = 'Check your date of birth';
      }
      if (!_in(countries, d['citizenship'] as String?)) e['citizenship'] = 'Select your citizenship';
      if (!_in(countries, d['taxResidency'] as String?)) e['taxResidency'] = 'Select your country of tax residence';
      if (!_phoneRe.hasMatch(_s(d, 'phone'))) e['phone'] = 'Enter a valid phone number with country code';
      if (!_in(languages, d['language'] as String?)) e['language'] = 'Select a language';
      final ce = _s(d, 'contactEmail').isEmpty ? loginEmail : _s(d, 'contactEmail');
      if (!_emailRe.hasMatch(ce)) e['contactEmail'] = 'Enter a valid contact email';
    case 'c':
      final us = d['usTaxPayer'] as String?;
      if (us != 'YES' && us != 'NO') {
        e['usTaxPayer'] = 'Please answer this question';
        break;
      }
      final tinType = d['tinType'] as String?;
      final tin = _s(d, 'tin');
      final masked = tin.contains('•'); // 已保存过的税号（服务端打码返回），视为已填写
      if (!_in(tinTypesFor(us), tinType)) {
        e['tinType'] = 'Select a tax ID type';
      } else if (!masked && tinType == 'SSN' && !_ssnRe.hasMatch(tin)) {
        e['tin'] = 'SSN format: 123-45-6789';
      } else if (!masked && tinType == 'SSN' && !plausibleSsn(tin)) {
        e['tin'] = 'This SSN is not valid. Check it and try again';
      } else if (!masked && tinType == 'ITIN' && !_itinRe.hasMatch(tin)) {
        e['tin'] = 'ITIN starts with 9: 9XX-XX-XXXX';
      } else if (tin.length < 5) {
        e['tin'] = 'Enter your full tax ID';
      }
      if (us == 'NO' && d['taxTreaty'] != 'YES' && d['taxTreaty'] != 'NO') e['taxTreaty'] = 'Please answer this question';
      if (d['tinConfirm'] != true) e['tinConfirm'] = 'Confirm this is the number you use to file taxes';
    case 'd':
      final a = _m(d, 'residentialAddress');
      final line1 = (a['line1'] as String? ?? '').trim();
      if (line1.isEmpty) {
        e['residentialAddress.line1'] = 'Enter your street address';
      } else if (poBoxRe.hasMatch('$line1 ${a['line2'] ?? ''}')) {
        e['residentialAddress.line1'] = 'Home address cannot be a P.O. Box — enter where you actually live';
      }
      if ((a['city'] as String? ?? '').trim().isEmpty) e['residentialAddress.city'] = 'Enter your city';
      if ((a['postalCode'] as String? ?? '').trim().isEmpty) e['residentialAddress.postalCode'] = 'Enter your ZIP / postal code';
      if (a['country'] == 'US' && (a['state'] as String? ?? '').trim().isEmpty) e['residentialAddress.state'] = 'Enter your state';
      if (!_in(countries, a['country'] as String?)) e['residentialAddress.country'] = 'Select your country or region';
      final mail = d['mailingAddress'];
      if (mail is Map && ((mail['line1'] as String?) ?? '').trim().isEmpty) e['mailingAddress.line1'] = 'Enter your mailing address';
    case 'e':
      final status = d['employmentStatus'] as String?;
      if (!_in(employmentStatuses, status)) e['employmentStatus'] = 'Select your employment status';
      if (isEmployed(status)) {
        if (_s(d, 'employerName').isEmpty) e['employerName'] = 'Employer name is required when employed';
        if (!_in(industries, d['industry'] as String?)) e['industry'] = 'Select your industry';
        final pos = d['position'] as String?;
        if (pos != null && pos.isNotEmpty && !_in(positions, pos)) e['position'] = 'Select a position from the list';
      }
      if (!_in(incomeRanges, d['annualIncomeRange'] as String?)) e['annualIncomeRange'] = 'Select your annual income';
      if (!_in(netWorthRanges, d['netWorthRange'] as String?)) e['netWorthRange'] = 'Select your net worth';
      if (!_in(netWorthRanges, d['netWorthLiquidRange'] as String?)) e['netWorthLiquidRange'] = 'Select your liquid net worth';
      if (!_in(experiences, d['investmentExperience'] as String?)) e['investmentExperience'] = 'Select your investment experience';
      if (!_in(objectives, d['investmentObjective'] as String?)) e['investmentObjective'] = 'Select your investment objective';
      if (!_in(riskLevels, d['riskTolerance'] as String?)) e['riskTolerance'] = 'Select your risk tolerance';
      final fs = (d['fundingSources'] as List?)?.cast<String>() ?? const [];
      if (fs.isEmpty || fs.any((v) => !_in(fundingSources, v))) e['fundingSources'] = 'Select at least one source of funds';
    case 'f':
      if (d['isAffiliatedBD'] is! bool) {
        e['isAffiliatedBD'] = 'Please answer this question';
      } else if (d['isAffiliatedBD'] == true) {
        if (_s(d, 'affiliatedFirmName').isEmpty) e['affiliatedFirmName'] = 'Enter the firm name';
        if (d['affiliatedAck'] != true) e['affiliatedAck'] = 'Confirm you understand the notification requirements';
      }
      if (d['isPEP'] is! bool) {
        e['isPEP'] = 'Please answer this question';
      } else if (d['isPEP'] == true && _s(d, 'pepName').isEmpty) {
        e['pepName'] = 'Enter the name of the PEP';
      }
      if (d['isControlPerson'] is! bool) {
        e['isControlPerson'] = 'Please answer this question';
      } else if (d['isControlPerson'] == true && _s(d, 'controlCompanyName').isEmpty) {
        e['controlCompanyName'] = 'Enter the company name or ticker';
      }
  }
  return e;
}

/// 字段所属步骤（P-30 把服务端字段错误归到对应分组）。
String stepOfField(String field) {
  final root = field.split('.').first;
  const b = {'firstName', 'lastName', 'dateOfBirth', 'citizenship', 'taxResidency', 'phone', 'contactEmail', 'language'};
  const c = {'usTaxPayer', 'tinType', 'tin', 'taxTreaty', 'irsBackup', 'tinConfirm'};
  const d = {'residentialAddress', 'mailingAddress'};
  const f = {
    'isAffiliatedBD',
    'affiliatedFirmName',
    'affiliatedAck',
    'isPEP',
    'pepName',
    'pepCountry',
    'pepRoles',
    'isControlPerson',
    'controlCompanyName',
    'controlCompanySymbol',
  };
  if (b.contains(root)) return 'b';
  if (c.contains(root)) return 'c';
  if (d.contains(root)) return 'd';
  if (f.contains(root)) return 'f';
  if (root == 'documents') return 'p04';
  if (root == 'disclosures' || root == 'signatureName') return 'p05';
  return 'e';
}
