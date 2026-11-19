import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../data/funding_api.dart';
import '../domain/funding_rules.dart';

/// 资金接口错误的统一展示：账户受限（40301）/ 未开户（40901）给出明确说明。
String fundingErrorText(ApiException e) => switch (e.code) {
  ApiCodes.restricted => '账户当前受限，暂不能进行资金操作。如有疑问请联系客服。',
  _ => e.message,
};

/// P-31 资金账户管理（银行账户列表、绑定上限、解绑）。
class BankAccountsPage extends StatefulWidget {
  const BankAccountsPage({super.key});

  @override
  State<BankAccountsPage> createState() => _BankAccountsPageState();
}

class _BankAccountsPageState extends State<BankAccountsPage> {
  List<BankAccount>? _banks;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final b = await FundingApi(AppScope.of(context).api).banks();
      if (!mounted) return;
      setState(() {
        _banks = b;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = fundingErrorText(e));
    }
  }

  Future<void> _unlink(BankAccount b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解绑银行账户？'),
        content: Text('${b.displayName} 解绑后不能再用于入金和出金。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(key: const Key('p31.unlink.confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('解绑')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FundingApi(AppScope.of(context).api).unlinkBank(b.id);
      if (!mounted) return;
      showToast(context, '已解绑');
      _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, fundingErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final banks = _banks;
    final full = banks != null && banks.length >= FundingLimits.maxBanks;
    return PageScaffold(
      title: '银行账户',
      content: [
        if (_error != null) Notice(_error!, kind: NoticeKind.warn),
        if (banks == null && _error == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (banks != null) ...[
          SectionTitle('已绑定（${banks.length}/${FundingLimits.maxBanks}）'),
          if (banks.isEmpty)
            const AppCard(
              child: Text('还没有绑定银行账户。绑定本人名下的美国银行账户后，即可通过 ACH 入金和出金。', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            )
          else
            ListGroup(
              children: [
                for (final b in banks)
                  ListRow(
                    key: Key('p31.bank.${b.id}'),
                    icon: Icons.account_balance_outlined,
                    title: b.displayName,
                    subtitle: '${b.typeLabel} · 户名 ${b.ownerName} · 绑定于 ${fmtDateTime(b.createdAt).split(' ').first}',
                    trailing: LinkButton('解绑', fontSize: 13, color: AppColors.danger, onPressed: () => _unlink(b)),
                  ),
              ],
            ),
          if (full) Notice('每个账户最多绑定 ${FundingLimits.maxBanks} 个银行账户。如需更换，请先解绑。', kind: NoticeKind.warn),
          const Notice('只能绑定本人名下的美国银行账户。没有美国银行账户？可以改用电汇入金。'),
          LinkButton('查看电汇入金信息', onPressed: () => context.push('/funding/wire')),
        ],
      ],
      footer: [
        Expanded(
          child: AppButton(
            '绑定新银行账户',
            key: const Key('p31.link'),
            onPressed: banks == null || full
                ? null
                : () async {
                    final linked = await context.push<bool>('/funding/banks/link');
                    if (linked == true) _load();
                  },
          ),
        ),
      ],
    );
  }
}

/// P-32 绑定银行账户（方案 A：直接录入，BANK_LINK_METHOD=DIRECT；户名由后端写入开户姓名）。
/// 成功后 pop(true) 回到来源页（P-06 / P-13 / P-31）。
class LinkBankPage extends StatefulWidget {
  const LinkBankPage({super.key});

  @override
  State<LinkBankPage> createState() => _LinkBankPageState();
}

class _LinkBankPageState extends State<LinkBankPage> {
  final _routing = TextEditingController();
  final _account = TextEditingController();
  final _nickname = TextEditingController();
  String _type = 'CHECKING';
  Map<String, String> _errors = {};
  bool _busy = false;

  @override
  void dispose() {
    _routing.dispose();
    _account.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    final acct = _account.text.replaceAll(RegExp(r'\D'), '');
    if (!validAba(_routing.text)) e['routingNumber'] = '请输入有效的 9 位 ABA 路由号码';
    if (acct.length < 4 || acct.length > 17) e['accountNumber'] = '请输入 4–17 位银行账号';
    final nick = _nickname.text.trim();
    if (nick.length > 30) e['nickname'] = '备注名最多 30 个字';
    if (nick.isNotEmpty && nick.replaceAll(RegExp(r'\D'), '') == acct) e['nickname'] = '备注名不能与账号相同';
    return e;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final e = _validate();
    setState(() => _errors = e);
    if (e.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await FundingApi(AppScope.of(context).api).linkBank(
        accountNumber: _account.text.replaceAll(RegExp(r'\D'), ''),
        routingNumber: _routing.text.replaceAll(RegExp(r'\D'), ''),
        type: _type,
        nickname: _nickname.text.trim(),
      );
      if (!mounted) return;
      showToast(context, '银行账户绑定成功');
      context.pop(true);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _errors = err.fieldMap;
        if (_errors.isEmpty) _errors = {'_': fundingErrorText(err)};
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: '绑定银行账户',
    content: [
      if (_errors['_'] != null) Notice(_errors['_']!, kind: NoticeKind.danger),
      const ListGroup(
        children: [
          ListRow(icon: Icons.person_outline_rounded, title: '只能绑定本人名下的账户', subtitle: '户名按开户姓名登记，第三方账户的转账会被退回'),
          ListRow(icon: Icons.flag_outlined, title: '仅支持美国银行账户', subtitle: '没有美国银行账户？请改用电汇'),
          ListRow(icon: Icons.lock_outline_rounded, title: '账号加密传输', subtitle: '我们只显示账号尾号'),
        ],
      ),
      AppField(
        label: '路由号码（ABA Routing Number）',
        controller: _routing,
        fieldKey: const Key('p32.routing'),
        hint: '9 位数字',
        keyboardType: TextInputType.number,
        maxLength: 9,
        error: _errors['routingNumber'],
      ),
      AppField(
        label: '银行账号',
        controller: _account,
        fieldKey: const Key('p32.account'),
        hint: '4–17 位数字',
        keyboardType: TextInputType.number,
        maxLength: 17,
        error: _errors['accountNumber'],
      ),
      FieldShell(
        label: '账户类型',
        error: _errors['type'],
        child: Seg2<String>(
          items: const [('CHECKING', '支票账户'), ('SAVINGS', '储蓄账户')],
          value: _type,
          onChanged: (v) => setState(() => _type = v),
        ),
      ),
      AppField(label: '备注名（选填）', controller: _nickname, fieldKey: const Key('p32.nickname'), hint: '如：工资卡', error: _errors['nickname']),
    ],
    footer: [
      Expanded(
        child: AppButton('绑定', key: const Key('p32.submit'), loading: _busy, onPressed: _busy ? null : _submit),
      ),
    ],
  );
}

/// P-33 电汇入金指引（来自 DW deposit-instructions；附言须含本人账户号码）。
class WireInstructionsPage extends StatefulWidget {
  const WireInstructionsPage({super.key});

  @override
  State<WireInstructionsPage> createState() => _WireInstructionsPageState();
}

class _WireInstructionsPageState extends State<WireInstructionsPage> {
  DepositInstructions? _d;
  String? _error;

  static const _labels = {
    'beneficiaryName': '收款人',
    'bankName': '收款银行',
    'bankAddress': '银行地址',
    'accountNumber': '收款账号',
    'routingNumber': 'ABA 路由号码',
    'swift': 'SWIFT',
    'reference': '附言（必填）',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final d = await FundingApi(AppScope.of(context).api).instructions();
        if (mounted) setState(() => _d = d);
      } on ApiException catch (e) {
        if (mounted) setState(() => _error = fundingErrorText(e));
      }
    });
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: '电汇入金',
    content: [
      if (_error != null) Notice(_error!, kind: NoticeKind.warn),
      if (_d == null && _error == null)
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (_d != null) ...[
        const Notice('请从本人名下的银行账户汇款，并在附言中填写下方内容（含您的账户号码），否则可能无法入账。', kind: NoticeKind.warn),
        AppCard(
          child: Column(
            children: [
              for (final e in _labels.entries)
                if ((_d!.fields[e.key] ?? '').isNotEmpty)
                  Row(
                    children: [
                      Expanded(child: KvRow(e.value, _d!.fields[e.key]!)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.muted),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _d!.fields[e.key]!));
                          showToast(context, '${e.value}已复制');
                        },
                      ),
                    ],
                  ),
            ],
          ),
        ),
        const Notice('中转行费用由汇款方承担；到账时间以银行实际到账为准（待 DW 确认）。电汇入金不受 ACH 观察期限制。'),
      ],
    ],
  );
}
