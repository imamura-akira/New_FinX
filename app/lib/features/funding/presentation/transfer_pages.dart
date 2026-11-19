import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/data/account_api.dart';
import '../data/funding_api.dart';
import '../domain/funding_rules.dart';
import 'bank_pages.dart';

String _date(DateTime? t) => t == null ? '—' : fmtDateTime(t).split(' ').first;

/// 银行账户单选列表（P-13 / P-14 共用）。
class _BankPicker extends StatelessWidget {
  const _BankPicker({required this.banks, required this.selected, required this.onSelect});
  final List<BankAccount> banks;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => ListGroup(
    children: [
      for (final b in banks)
        ListRow(
          key: Key('bank.pick.${b.id}'),
          icon: Icons.account_balance_outlined,
          title: b.displayName,
          subtitle: '${b.typeLabel} · 户名 ${b.ownerName}',
          trailing: Icon(
            b.id == selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: b.id == selected ? AppColors.primary : AppColors.faint,
          ),
          onTap: () => onSelect(b.id),
        ),
    ],
  );
}

/// 提交结果页（P-13 / P-14 共用）。
class _ResultView extends StatelessWidget {
  const _ResultView({required this.title, required this.message, required this.result, required this.amount, required this.method});
  final String title;
  final String message;
  final TransferResult result;
  final double amount;
  final String method;

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: title,
    content: [
      const SizedBox(height: 16),
      Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(color: AppColors.primaryWeak, shape: BoxShape.circle),
          child: Icon(result.pending ? Icons.schedule_rounded : Icons.check_rounded, size: 36, color: AppColors.primary),
        ),
      ),
      const SizedBox(height: 14),
      Center(
        child: Text(
          title,
          key: const Key('funding.result'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          children: [
            KvRow('流水号', result.transferId),
            KvRow('方式', method),
            KvRow('金额', fmtUsd(amount)),
            KvRow('状态', transferStatusLabels[result.status] ?? result.status),
          ],
        ),
      ),
    ],
    footer: [
      Expanded(
        child: AppButton('查看资金记录', kind: ButtonKind.ghost, onPressed: () => context.go('/funding/history')),
      ),
      Expanded(
        child: AppButton('完成', key: const Key('funding.done'), onPressed: () => context.go('/home')),
      ),
    ],
  );
}

/// P-13 入金（ACH；电汇 → P-33）。步骤：方式 → 填写 → 确认 → 结果。
class DepositPage extends StatefulWidget {
  const DepositPage({super.key});

  @override
  State<DepositPage> createState() => _DepositPageState();
}

class _DepositPageState extends State<DepositPage> {
  List<BankAccount>? _banks;
  String? _bank;
  String? _loadError;
  String _step = 'method';
  final _amount = TextEditingController();
  String? _amountError;
  String? _submitError;
  bool _busy = false;
  TransferResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final b = await FundingApi(AppScope.of(context).api).banks();
      if (!mounted) return;
      setState(() {
        _banks = b;
        _bank ??= b.isEmpty ? null : b.first.id;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = fundingErrorText(e));
    }
  }

  Future<void> _pickAch() async {
    if ((_banks ?? const []).isEmpty) {
      final linked = await context.push<bool>('/funding/banks/link');
      if (linked == true) await _load();
      if (!mounted || (_banks ?? const []).isEmpty) return;
    }
    setState(() => _step = 'form');
  }

  void _toConfirm() {
    final err = validateDeposit(_amount.text);
    setState(() => _amountError = err);
    if (err == null && _bank != null) setState(() => _step = 'confirm');
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _submitError = null;
    });
    try {
      final r = await FundingApi(AppScope.of(context).api).deposit(bankAccountId: _bank!, amount: parseAmount(_amount.text)!);
      if (!mounted) return;
      setState(() {
        _result = r;
        _step = 'done';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = fundingErrorText(e);
        _amountError = e.fieldMap['amount'] ?? (e.code == ApiCodes.limit ? e.message : null);
        if (e.code == ApiCodes.validation || e.code == ApiCodes.limit) _step = 'form';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  BankAccount? get _selected => _banks?.where((b) => b.id == _bank).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final banks = _banks;
    if (_step == 'done' && _result != null) {
      return _ResultView(
        title: _result!.pending ? '入金已记录' : '入金已提交',
        message: _result!.pending ? '券商受理结果暂未确认，我们会自动核对，请稍后在资金记录中查看状态。请勿重复提交。' : '$buyingPowerFallback。到账日期以资金记录中券商返回的日期为准。',
        result: _result!,
        amount: parseAmount(_amount.text)!,
        method: 'ACH',
      );
    }
    if (banks == null) {
      return PageScaffold(
        title: '入金',
        content: [
          if (_loadError != null)
            Notice(_loadError!, kind: NoticeKind.warn)
          else
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }
    if (_step == 'method') {
      return PageScaffold(
        title: '入金',
        content: [
          const SectionTitle('选择入金方式'),
          ListGroup(
            children: [
              ListRow(
                key: const Key('p13.ach'),
                icon: Icons.account_balance_outlined,
                title: '银行转账（ACH）',
                subtitle: banks.isEmpty ? '需先绑定本人名下的美国银行账户' : '已绑定 ${banks.length} 个本人美国银行账户 · 免手续费',
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                onTap: _pickAch,
              ),
              ListRow(
                icon: Icons.public_rounded,
                title: '电汇',
                subtitle: '从本人名下银行账户汇款，适用于境外银行或大额入金',
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                onTap: () => context.push('/funding/wire'),
              ),
            ],
          ),
          const Notice('$buyingPowerFallback。$seasoningFallback。电汇以银行实际到账时间为准，不受观察期限制。每笔入金的实际日期以券商返回为准（见资金记录）。'),
          const Notice('只接受来自本人名下账户的资金，第三方转账将被退回。'),
        ],
      );
    }
    if (_step == 'confirm') {
      final amt = parseAmount(_amount.text)!;
      return PageScaffold(
        title: '确认入金',
        content: [
          if (_submitError != null) Notice(_submitError!, kind: NoticeKind.danger),
          AppCard(
            child: Column(
              children: [
                const Text('入金金额', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(
                  fmtUsd(amt),
                  key: const Key('p13.confirm.amount'),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          AppCard(
            child: Column(
              children: [
                KvRow('从', _selected?.displayName ?? '—'),
                const KvRow('到', '本人证券账户（DriveWealth 托管）'),
                const KvRow('方式', 'ACH'),
                const KvRow('手续费', r'$0.00'),
                const KvRow('购买力到账', buyingPowerFallback),
              ],
            ),
          ),
          const Text('确认即授权从上述银行账户扣款。资金由 DriveWealth 托管。', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
        footer: [
          AppButton('返回修改', kind: ButtonKind.ghost, fitContent: true, onPressed: _busy ? null : () => setState(() => _step = 'form')),
          Expanded(
            child: AppButton('确认入金', key: const Key('p13.submit'), loading: _busy, onPressed: _busy ? null : _submit),
          ),
        ],
      );
    }
    // form
    return PageScaffold(
      title: 'ACH 入金',
      content: [
        if (_submitError != null) Notice(_submitError!, kind: NoticeKind.danger),
        const SectionTitle('转出银行账户'),
        _BankPicker(banks: banks, selected: _bank, onSelect: (id) => setState(() => _bank = id)),
        LinkButton(
          '管理银行账户（${banks.length}/${FundingLimits.maxBanks}）',
          fontSize: 13,
          onPressed: () async {
            await context.push('/funding/banks');
            _load();
          },
        ),
        const SizedBox(height: 8),
        AppField(
          label: '入金金额 (USD)',
          controller: _amount,
          fieldKey: const Key('p13.amount'),
          hint: '0.00',
          helper:
              '单笔 ${fmtUsd(FundingLimits.minDeposit)} – ${fmtUsd(FundingLimits.maxDeposit)}，每日上限 ${fmtUsd(FundingLimits.dailyDeposit)}（示例值，以券商为准）',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          error: _amountError,
          onChanged: (_) {
            if (_amountError != null) setState(() => _amountError = null);
          },
        ),
        const AppCard(
          child: Column(
            children: [
              KvRow('提交截止时间', '工作日 ${FundingLimits.achCutoffEt} ET（示例，待 DW 确认）'),
              KvRow('购买力到账', buyingPowerFallback),
              KvRow('可提现时间', '到账后 30 天观察期结束（默认，待 DW 确认）'),
              KvRow('手续费', r'$0.00'),
            ],
          ),
        ),
        const Notice('退回提示：如银行退回此笔转账（如余额不足），使用该笔资金买入的证券可能被限制卖出，并可能产生退回费用；账户入金功能也可能被暂停。', kind: NoticeKind.warn),
      ],
      footer: [
        Expanded(
          child: AppButton('下一步', key: const Key('p13.next'), onPressed: _bank == null ? null : _toConfirm),
        ),
      ],
    );
  }
}

/// P-14 出金（Demo-1：ACH；可提现一律取 DW 返回值，后端强制校验）。
class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  List<BankAccount>? _banks;
  AccountMoney? _money;
  String? _bank;
  String? _loadError;
  String _method = 'ACH';
  bool _confirm = false;
  final _amount = TextEditingController();
  String? _amountError;
  String? _submitError;
  bool _busy = false;
  TransferResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    try {
      final (b, m) = await (FundingApi(api).banks(), AccountApi(api).money()).wait;
      if (!mounted) return;
      setState(() {
        _banks = b;
        _money = m;
        _bank ??= b.isEmpty ? null : b.first.id;
        _loadError = null;
      });
    } on ParallelWaitError<(List<BankAccount>?, AccountMoney?), (AsyncError?, AsyncError?)> catch (e) {
      final err = e.errors.$1?.error ?? e.errors.$2?.error;
      if (mounted) setState(() => _loadError = err is ApiException ? fundingErrorText(err) : '$err');
    }
  }

  void _next() {
    final err = validateWithdrawal(_amount.text, _money!.cashAvailableForWithdrawal);
    setState(() => _amountError = err);
    if (err == null && _bank != null) setState(() => _confirm = true);
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _submitError = null;
    });
    try {
      final r = await FundingApi(AppScope.of(context).api).withdrawAch(bankAccountId: _bank!, amount: parseAmount(_amount.text)!);
      if (mounted) setState(() => _result = r);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = fundingErrorText(e);
        _amountError = e.fieldMap['amount'] ?? (e.code == ApiCodes.limit ? e.message : null);
        _confirm = false;
      });
      if (e.code == ApiCodes.limit) _load(); // 可提现金额可能已变化
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _ResultView(
        title: _result!.pending ? '出金已记录' : '出金已提交',
        message: _result!.pending ? '券商受理结果暂未确认，我们会自动核对，请稍后在资金记录中查看状态。请勿重复提交。' : 'ACH 出金$achWithdrawalArrival。',
        result: _result!,
        amount: parseAmount(_amount.text)!,
        method: 'ACH',
      );
    }
    final banks = _banks;
    final m = _money;
    if (banks == null || m == null) {
      return PageScaffold(
        title: '出金',
        content: [
          if (_loadError != null)
            Notice(_loadError!, kind: NoticeKind.warn)
          else
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      );
    }
    if (_confirm) {
      final amt = parseAmount(_amount.text)!;
      final b = banks.where((x) => x.id == _bank).firstOrNull;
      return PageScaffold(
        title: '确认出金',
        content: [
          AppCard(
            child: Column(
              children: [
                const Text('出金金额', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(fmtUsd(amt), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          AppCard(
            child: Column(
              children: [
                const KvRow('从', '本人证券账户'),
                KvRow('到', b?.displayName ?? '—'),
                const KvRow('方式', 'ACH'),
                const KvRow('手续费', achWithdrawalFee),
                const KvRow('预计到账', achWithdrawalArrival),
              ],
            ),
          ),
        ],
        footer: [
          AppButton('返回修改', kind: ButtonKind.ghost, fitContent: true, onPressed: _busy ? null : () => setState(() => _confirm = false)),
          Expanded(
            child: AppButton('确认出金', key: const Key('p14.submit'), loading: _busy, onPressed: _busy ? null : _submit),
          ),
        ],
      );
    }
    return PageScaffold(
      title: '出金',
      content: [
        if (_submitError != null) Notice(_submitError!, kind: NoticeKind.danger),
        AppCard(
          child: Column(
            children: [
              KvRow('可提现金额', fmtUsd(m.cashAvailableForWithdrawal), valueKey: const Key('p14.withdrawable')),
              KvRow('账户现金', fmtUsd(m.cash)),
              KvRow('未结算资金', fmtUsd(m.unsettled)),
              KvRow('ACH 入金观察期内金额', fmtUsd(m.withheldForSeasoning)),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '可提现金额以券商（DriveWealth）返回为准。$seasoningFallback；电汇入金不受此限制。',
                  style: TextStyle(fontSize: 12, color: AppColors.faint),
                ),
              ),
            ],
          ),
        ),
        Seg2<String>(items: const [('ACH', '银行转账（ACH）'), ('WIRE', '电汇')], value: _method, onChanged: (v) => setState(() => _method = v)),
        const SizedBox(height: 12),
        if (_method == 'WIRE')
          const Notice('电汇出金暂不在本次演示范围（后端已支持，待沙盒实测后开放）。电汇只能汇入本人名下的银行账户，收款人固定为账户持有人。')
        else ...[
          const SectionTitle('收款银行账户'),
          if (banks.isEmpty)
            const Notice('尚未绑定银行账户。', kind: NoticeKind.warn)
          else
            _BankPicker(banks: banks, selected: _bank, onSelect: (id) => setState(() => _bank = id)),
          LinkButton(
            '绑定银行账户',
            fontSize: 13,
            onPressed: () async {
              final linked = await context.push<bool>('/funding/banks/link');
              if (linked == true) _load();
            },
          ),
          const SizedBox(height: 8),
          AppField(
            label: '出金金额 (USD)',
            controller: _amount,
            fieldKey: const Key('p14.amount'),
            hint: '0.00',
            helper: '单笔 ${fmtUsd(FundingLimits.minWithdrawal)} – ${fmtUsd(FundingLimits.maxWithdrawal)}，且不超过可提现金额',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            error: _amountError,
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
          ),
          const AppCard(child: Column(children: [KvRow('手续费', achWithdrawalFee), KvRow('预计到账', achWithdrawalArrival)])),
        ],
      ],
      footer: [
        Expanded(
          child: AppButton('下一步', key: const Key('p14.next'), onPressed: _method != 'ACH' || _bank == null ? null : _next),
        ),
      ],
    );
  }
}

/// P-18 历史记录（Demo-1：资金进出；交易、分红、公司行动不在范围）。
class TransfersPage extends StatefulWidget {
  const TransfersPage({super.key});

  @override
  State<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends State<TransfersPage> {
  List<Transfer>? _list;
  List<BankAccount> _banks = const [];
  String? _error;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = FundingApi(AppScope.of(context).api);
    try {
      final list = await api.transfers(type: _filter == 'ALL' ? null : _filter);
      List<BankAccount> banks = const [];
      try {
        banks = await api.banks();
      } on ApiException {
        // 银行名称仅用于显示，取不到不影响列表
      }
      if (!mounted) return;
      setState(() {
        _list = list;
        _banks = banks;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = fundingErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: '资金记录',
    content: [
      Seg2<String>(
        items: const [('ALL', '全部'), ('DEPOSIT', '入金'), ('WITHDRAWAL', '出金')],
        value: _filter,
        onChanged: (v) {
          setState(() {
            _filter = v;
            _list = null;
          });
          _load();
        },
      ),
      const SizedBox(height: 12),
      if (_error != null) Notice(_error!, kind: NoticeKind.warn),
      if (_list == null && _error == null)
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (_list != null && _list!.isEmpty)
        const AppCard(
          child: Text('暂无资金记录', style: TextStyle(color: AppColors.muted)),
        ),
      if (_list != null && _list!.isNotEmpty)
        ListGroup(
          children: [
            for (final t in _list!)
              InkWell(
                key: Key('p18.row.${t.id}'),
                onTap: () => _detail(t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${t.method} ${t.isDeposit ? '入金' : '出金'}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            Text(fmtDateTime(t.submittedAt), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${t.isDeposit ? '+' : '-'}${fmtUsd(t.amount)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                          const SizedBox(height: 2),
                          _badge(t.status),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text('显示最近 50 条资金记录。交易、分红与公司行动记录不在本次演示范围。', style: TextStyle(fontSize: 12, color: AppColors.faint)),
      ),
    ],
  );

  Widget _badge(String s) => StatusBadge(
    transferStatusLabels[s] ?? s,
    kind: isTransferFailed(s)
        ? BadgeKind.danger
        : isTransferDone(s)
        ? BadgeKind.ok
        : BadgeKind.warn,
  );

  void _detail(Transfer t) {
    final bank = _banks.where((b) => b.id == t.bankAccountId).firstOrNull;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${t.method} ${t.isDeposit ? '入金' : '出金'}详情', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              KvRow('流水号', t.id),
              KvRow('金额', fmtUsd(t.amount)),
              KvRow('状态', transferStatusLabels[t.status] ?? t.status),
              if (bank != null) KvRow(t.isDeposit ? '转出账户' : '收款账户', bank.displayName),
              KvRow('提交时间', fmtDateTime(t.submittedAt)),
              if (t.doneAt != null) KvRow('完成时间', fmtDateTime(t.doneAt)),
              if (t.isDeposit) ...[
                KvRow(
                  '购买力可用日',
                  t.buyingPowerAvailableAt == null ? '待券商返回' : _date(t.buyingPowerAvailableAt),
                  valueKey: const Key('p18.bpDate'),
                ),
                KvRow('可提现日', t.withdrawableAt == null ? '待券商返回' : _date(t.withdrawableAt), valueKey: const Key('p18.wdDate')),
                if (t.buyingPowerAvailableAt == null || t.withdrawableAt == null)
                  const Text('$buyingPowerFallback；$seasoningFallback。', style: TextStyle(fontSize: 12, color: AppColors.faint)),
              ],
              if (t.failureReason != null) Notice('原因：${t.failureReason}', kind: NoticeKind.danger),
            ],
          ),
        ),
      ),
    );
  }
}
