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
import '../../../l10n/l10n.dart';

/// 资金接口错误的统一展示：账户受限（40301）/ 未开户（40901）给出明确说明。
String fundingErrorText(ApiException e) => switch (e.code) {
  ApiCodes.restricted => t.bankYourAccountIsCurrently,
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
      final fapi = FundingApi(AppScope.of(context).api);
      final (b, _) = await (fapi.banks(), fapi.loadLimits()).wait;
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
        title: Text(t.bankUnlinkBankAccount),
        content: Text(t.bankOnceUnlinkedCanNo(b.displayName)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.drawerCancel)),
          TextButton(key: const Key('p31.unlink.confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(t.bankUnlink)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FundingApi(AppScope.of(context).api).unlinkBank(b.id);
      if (!mounted) return;
      showToast(context, t.bankUnlinked);
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
      title: t.drawerBankAccounts,
      content: [
        if (_error != null) Notice(_error!, kind: NoticeKind.warn),
        if (banks == null && _error == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (banks != null) ...[
          SectionTitle(t.bankLinked(banks.length, FundingLimits.maxBanks)),
          if (banks.isEmpty)
            AppCard(
              child: Text(t.bankNoBankAccountsLinked, style: TextStyle(fontSize: 13, color: AppColors.muted)),
            )
          else
            ListGroup(
              children: [
                for (final b in banks)
                  ListRow(
                    key: Key('p31.bank.${b.id}'),
                    icon: Icons.account_balance_outlined,
                    title: b.displayName,
                    subtitle: t.bankSubtitle(b.typeLabel, b.ownerName, fmtDate(b.createdAt)),
                    trailing: LinkButton(t.bankUnlink, fontSize: 13, color: AppColors.danger, onPressed: () => _unlink(b)),
                  ),
              ],
            ),
          if (full) Notice(t.bankYouCanLinkUp(FundingLimits.maxBanks), kind: NoticeKind.warn),
          Notice(t.bankYouCanOnlyLink),
          LinkButton(t.bankViewWireInstructions, onPressed: () => context.push('/funding/wire')),
        ],
      ],
      footer: [
        Expanded(
          child: AppButton(
            t.bankLinkANewBank,
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
    if (!validAba(_routing.text)) e['routingNumber'] = t.bankEnterAValid9;
    if (acct.length < 4 || acct.length > 17) e['accountNumber'] = t.bankEnterA417;
    final nick = _nickname.text.trim();
    if (nick.length > 30) e['nickname'] = t.bankNicknameCanBeUp;
    if (nick.isNotEmpty && nick.replaceAll(RegExp(r'\D'), '') == acct) e['nickname'] = t.bankNicknameCanTBe;
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
      showToast(context, t.bankBankAccountLinked);
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
    title: t.bankLinkBankAccount,
    content: [
      if (_errors['_'] != null) Notice(_errors['_']!, kind: NoticeKind.danger),
      ListGroup(
        children: [
          ListRow(icon: Icons.person_outline_rounded, title: t.bankAccountsInYourOwn, subtitle: t.bankTheAccountHolderIs),
          ListRow(icon: Icons.flag_outlined, title: t.bankUsBankAccountsOnly, subtitle: t.bankNoUsBankAccount),
          ListRow(icon: Icons.lock_outline_rounded, title: t.bankAccountNumberEncryptedIn, subtitle: t.bankWeOnlyShowThe),
        ],
      ),
      AppField(
        label: t.bankRoutingNumberAba,
        controller: _routing,
        fieldKey: const Key('p32.routing'),
        hint: t.bank9Digits,
        keyboardType: TextInputType.number,
        maxLength: 9,
        error: _errors['routingNumber'],
      ),
      AppField(
        label: t.bankAccountNumber,
        controller: _account,
        fieldKey: const Key('p32.account'),
        hint: t.bank417Digits,
        keyboardType: TextInputType.number,
        maxLength: 17,
        error: _errors['accountNumber'],
      ),
      FieldShell(
        label: t.bankAccountType,
        error: _errors['type'],
        child: Seg2<String>(
          items: [('CHECKING', t.fundChecking), ('SAVINGS', t.fundSavings)],
          value: _type,
          onChanged: (v) => setState(() => _type = v),
        ),
      ),
      AppField(label: t.bankNicknameOptional, controller: _nickname, fieldKey: const Key('p32.nickname'), hint: t.bankEGPaycheckAccount, error: _errors['nickname']),
    ],
    footer: [
      Expanded(
        child: AppButton(t.bankLink, key: const Key('p32.submit'), loading: _busy, onPressed: _busy ? null : _submit),
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

  static Map<String, String> get _labels => {
    'beneficiaryName': t.bankBeneficiary,
    'bankName': t.bankBeneficiaryBank,
    'bankAddress': t.bankBankAddress,
    'accountNumber': t.bankAccountNumber2,
    'routingNumber': t.bankAbaRoutingNumber,
    'swift': 'SWIFT',
    'reference': t.bankReferenceRequired,
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
    title: t.bankWireDeposit,
    content: [
      if (_error != null) Notice(_error!, kind: NoticeKind.warn),
      if (_d == null && _error == null)
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (_d != null) ...[
        Notice(t.bankSendTheWireFrom, kind: NoticeKind.warn),
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
                        icon: Icon(Icons.copy_rounded, size: 16, color: AppColors.muted),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _d!.fields[e.key]!));
                          showToast(context, t.bankCopied(e.value));
                        },
                      ),
                    ],
                  ),
            ],
          ),
        ),
        Notice(t.bankIntermediaryBankFeesAre),
      ],
    ],
  );
}
