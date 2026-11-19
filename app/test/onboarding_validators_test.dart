import 'package:finx_app/features/onboarding/domain/validators.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 19);

Map<String, dynamic> validData() => {
  'firstName': 'Demo',
  'lastName': 'Tester',
  'dateOfBirth': '1990-03-07',
  'citizenship': 'US',
  'taxResidency': 'US',
  'phone': '+1 415 555 0142',
  'contactEmail': 'demo@example.com',
  'language': 'en_US',
  'usTaxPayer': 'YES',
  'tinType': 'SSN',
  'tin': '234-56-7890',
  'irsBackup': 'NO',
  'tinConfirm': true,
  'residentialAddress': {'line1': '200 Market Street', 'city': 'San Francisco', 'state': 'CA', 'postalCode': '94105', 'country': 'US'},
  'employmentStatus': 'EMPLOYED',
  'employerName': 'Example Corp',
  'industry': 'PROFESSIONAL',
  'position': 'ENGINEER',
  'annualIncomeRange': '100k-200k',
  'netWorthRange': '200k-500k',
  'netWorthLiquidRange': '50k-200k',
  'investmentExperience': '3-5',
  'investmentObjective': 'GROWTH',
  'riskTolerance': 'MED',
  'fundingSources': ['EMP'],
  'isAffiliatedBD': false,
  'isPEP': false,
  'isControlPerson': false,
};

void main() {
  test('完整资料各步均通过', () {
    for (final s in ['b', 'c', 'd', 'e', 'f']) {
      expect(validateStep(s, validData(), now: _now), isEmpty, reason: 'step $s');
    }
  });

  // (名称, 步骤, 修改, 期望字段, 期望文案片段)
  final cases = <(String, String, void Function(Map<String, dynamic>), String, String)>[
    ('非 ASCII 名', 'b', (d) => d['firstName'] = 'Zoë', 'firstName', 'ASCII'),
    ('中文名', 'b', (d) => d['lastName'] = '张', 'lastName', 'ASCII'),
    ('未满 18 岁', 'b', (d) => d['dateOfBirth'] = '2010-01-01', 'dateOfBirth', '18 or older'),
    ('出生日期缺失', 'b', (d) => d.remove('dateOfBirth'), 'dateOfBirth', 'date of birth'),
    ('手机号格式', 'b', (d) => d['phone'] = 'abc', 'phone', 'country code'),
    ('联系邮箱为空时用登录邮箱（登录邮箱也为空则报错）', 'b', (d) => d.remove('contactEmail'), 'contactEmail', 'contact email'),
    ('未回答纳税人', 'c', (d) => d.remove('usTaxPayer'), 'usTaxPayer', 'answer'),
    ('SSN 格式', 'c', (d) => d['tin'] = '12-345', 'tin', '123-45-6789'),
    ('SSN 示例号码', 'c', (d) => d['tin'] = '123-45-6789', 'tin', 'not valid'),
    ('SSN 区号 9xx', 'c', (d) => d['tin'] = '912-34-5678', 'tin', 'not valid'),
    (
      'ITIN 格式',
      'c',
      (d) => d
        ..['tinType'] = 'ITIN'
        ..['tin'] = '123-45-6789',
      'tin',
      'ITIN starts with 9',
    ),
    (
      '非美国纳税人未答税收协定',
      'c',
      (d) => d
        ..['usTaxPayer'] = 'NO'
        ..['tinType'] = 'FOREIGN_TIN'
        ..['tin'] = 'S1234567D',
      'taxTreaty',
      'answer',
    ),
    ('未确认税号', 'c', (d) => d['tinConfirm'] = false, 'tinConfirm', 'file taxes'),
    ('P.O. Box', 'd', (d) => (d['residentialAddress'] as Map)['line1'] = 'PO Box 123', 'residentialAddress.line1', 'P.O. Box'),
    ('美国地址缺州', 'd', (d) => (d['residentialAddress'] as Map).remove('state'), 'residentialAddress.state', 'state'),
    ('邮寄地址为空', 'd', (d) => d['mailingAddress'] = <String, dynamic>{}, 'mailingAddress.line1', 'mailing address'),
    ('在职缺雇主', 'e', (d) => d.remove('employerName'), 'employerName', 'Employer name'),
    ('在职缺行业', 'e', (d) => d.remove('industry'), 'industry', 'industry'),
    ('职位不在列表', 'e', (d) => d['position'] = 'ASTRONAUT', 'position', 'from the list'),
    ('资金来源为空', 'e', (d) => d['fundingSources'] = <String>[], 'fundingSources', 'source of funds'),
    ('资金来源旧取值', 'e', (d) => d['fundingSources'] = ['OTHER'], 'fundingSources', 'source of funds'),
    ('PEP 缺姓名', 'f', (d) => d['isPEP'] = true, 'pepName', 'PEP'),
    (
      '券商关联缺确认',
      'f',
      (d) => d
        ..['isAffiliatedBD'] = true
        ..['affiliatedFirmName'] = 'X',
      'affiliatedAck',
      'notification',
    ),
    ('未回答控制人', 'f', (d) => d.remove('isControlPerson'), 'isControlPerson', 'answer'),
  ];
  for (final (name, step, mutate, field, fragment) in cases) {
    test(name, () {
      final d = validData();
      mutate(d);
      final e = validateStep(step, d, now: _now);
      expect(e.keys, contains(field));
      expect(e[field], contains(fragment));
      // 开户模块文案一律英文
      expect(RegExp(r'[一-鿿]').hasMatch(e[field]!), isFalse);
    });
  }

  test('已保存的打码税号视为已填写', () {
    final d = validData()..['tin'] = '•••-••-7890';
    expect(validateStep('c', d, now: _now), isEmpty);
  });

  test('无业不要求雇主与行业', () {
    final d = validData()
      ..['employmentStatus'] = 'RETIRED'
      ..remove('employerName')
      ..remove('industry')
      ..remove('position');
    expect(validateStep('e', d, now: _now), isEmpty);
  });

  test('字段归属步骤（P-30 分组标红）', () {
    expect(stepOfField('residentialAddress.line1'), 'd');
    expect(stepOfField('tin'), 'c');
    expect(stepOfField('industry'), 'e');
    expect(stepOfField('disclosures.termsOfUse'), 'p05');
    expect(stepOfField('documents'), 'p04');
    expect(stepOfField('pepName'), 'f');
  });
}
