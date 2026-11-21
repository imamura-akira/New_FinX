import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/scope.dart';
import '../../../app/theme.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../../../core/widgets/celebration.dart';
import '../../../core/widgets/form_widgets.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/data/account_api.dart';
import '../data/funding_api.dart';
import '../domain/funding_rules.dart';
import 'bank_pages.dart';
import '../../../l10n/l10n.dart';

String _date(DateTime? d) => fmtDate(d);

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
          subtitle: t.bankTypeOwner(b.typeLabel, b.ownerName),
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
          decoration: BoxDecoration(color: AppColors.primaryWeak, shape: BoxShape.circle),
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
        style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          children: [
            KvRow(t.xferTransactionId, result.transferId),
            KvRow(t.xferMethod, method),
            KvRow(t.xferAmount, fmtUsd(amount)),
            KvRow(t.orderStatus, transferStatusLabels[result.status] ?? result.status),
          ],
        ),
      ),
    ],
    footer: [
      Expanded(
        child: AppButton(t.xferViewTransferHistory, kind: ButtonKind.ghost, onPressed: () => context.pushReplacement('/funding/history')),
      ),
      Expanded(
        child: AppButton(t.orderDone, key: const Key('funding.done'), onPressed: () => context.go('/home')),
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
  final _submitKey = SubmitKey(); // 同一笔申请的重试沿用同一幂等键（审计 FUND-P0-1）
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
      final fapi = FundingApi(AppScope.of(context).api);
      final (b, _) = await (fapi.banks(), fapi.loadLimits()).wait;
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
      final amount = parseAmount(_amount.text)!;
      final r = await FundingApi(AppScope.of(context).api)
          .deposit(bankAccountId: _bank!, amount: amount, idempotencyKey: _submitKey.forRequest('$_bank|$amount'));
      _submitKey.reset();
      if (!mounted) return;
      setState(() {
        _result = r;
        _step = 'done';
      });
      // 入金提交成功：轻量版庆祝（结果待确认时不播放）；同一流水只播一次
      if (!r.pending) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Celebration.show(context, key: 'deposit:${r.transferId}', level: CelebrationLevel.light);
        });
      }
    } on ApiException catch (e) {
      _submitKey.settle(e);
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
        title: _result!.pending ? t.xferDepositRecorded : t.xferDepositSubmitted,
        message: _result!.pending ? t.xferTheBrokerHasnT : t.xferTheArrivalDateIs(buyingPowerFallback),
        result: _result!,
        amount: parseAmount(_amount.text)!,
        method: 'ACH',
      );
    }
    if (banks == null) {
      return PageScaffold(
        title: t.homeDeposit,
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
        title: t.homeDeposit,
        content: [
          SectionTitle(t.xferChooseADepositMethod),
          ListGroup(
            children: [
              ListRow(
                key: const Key('p13.ach'),
                icon: Icons.account_balance_outlined,
                title: t.xferBankTransferAch,
                subtitle: banks.isEmpty ? t.xferLinkAUsBank : t.xferUsBankAccountS(banks.length),
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                onTap: _pickAch,
              ),
              ListRow(
                icon: Icons.public_rounded,
                title: t.xferWireTransfer,
                subtitle: t.xferSendFromABank,
                trailing: Icon(Icons.chevron_right_rounded, color: AppColors.faint),
                onTap: () => context.push('/funding/wire'),
              ),
            ],
          ),
          Notice(t.xferWireTimingDependsOn(buyingPowerFallback, seasoningFallback)),
          Notice(t.xferWeOnlyAcceptFunds),
        ],
      );
    }
    if (_step == 'confirm') {
      final amt = parseAmount(_amount.text)!;
      return PageScaffold(
        title: t.xferConfirmDeposit,
        content: [
          if (_submitError != null) Notice(_submitError!, kind: NoticeKind.danger),
          AppCard(
            child: Column(
              children: [
                Text(t.xferDepositAmount, style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
                KvRow(t.xferFrom, _selected?.displayName ?? '—'),
                KvRow(t.xferTo, t.xferYourBrokerageAccountHeld),
                KvRow(t.xferMethod, 'ACH'),
                KvRow(t.xferFee, r'$0.00'),
                KvRow(t.xferBuyingPowerAvailable, buyingPowerFallback),
              ],
            ),
          ),
          Text(t.xferByConfirmingYouAuthorize, style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
        footer: [
          AppButton(t.xferEdit, kind: ButtonKind.ghost, fitContent: true, onPressed: _busy ? null : () => setState(() => _step = 'form')),
          Expanded(
            child: AppButton(t.xferConfirmDeposit, key: const Key('p13.submit'), loading: _busy, onPressed: _busy ? null : _submit),
          ),
        ],
      );
    }
    // form
    return PageScaffold(
      title: t.xferAchDeposit,
      content: [
        if (_submitError != null) Notice(_submitError!, kind: NoticeKind.danger),
        SectionTitle(t.xferFromBankAccount),
        _BankPicker(banks: banks, selected: _bank, onSelect: (id) => setState(() => _bank = id)),
        LinkButton(
          t.xferManageBankAccounts(banks.length, FundingLimits.maxBanks),
          fontSize: 13,
          onPressed: () async {
            await context.push('/funding/banks');
            _load();
          },
        ),
        const SizedBox(height: 8),
        AppField(
          label: t.xferDepositAmountUsd,
          controller: _amount,
          fieldKey: const Key('p13.amount'),
          hint: '0.00',
          helper:
              t.xferPerTransferUpTo(fmtUsd(FundingLimits.minDeposit), fmtUsd(FundingLimits.maxDeposit), fmtUsd(FundingLimits.dailyDeposit)),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          error: _amountError,
          onChanged: (_) {
            if (_amountError != null) setState(() => _amountError = null);
          },
        ),
        AppCard(
          child: Column(
            children: [
              KvRow(t.xferSubmissionCutoff, t.xferBusinessDaysEtSample(FundingLimits.achCutoffEt)),
              KvRow(t.xferBuyingPowerAvailable, buyingPowerFallback),
              KvRow(t.xferWithdrawable, t.xferAfterHoldingPeriod(FundingLimits.seasoningDays)),
              KvRow(t.xferFee, r'$0.00'),
            ],
          ),
        ),
        Notice(t.xferReturnNoticeIfYour, kind: NoticeKind.warn),
      ],
      footer: [
        Expanded(
          child: AppButton(t.orderNext, key: const Key('p13.next'), onPressed: _bank == null ? null : _toConfirm),
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
  final _submitKey = SubmitKey(); // 同一笔申请的重试沿用同一幂等键（审计 FUND-P0-1）
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
      final (b, m, _) = await (FundingApi(api).banks(), AccountApi(api).money(), FundingApi(api).loadLimits()).wait;
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
      final amount = parseAmount(_amount.text)!;
      final r = await FundingApi(AppScope.of(context).api)
          .withdrawAch(bankAccountId: _bank!, amount: amount, idempotencyKey: _submitKey.forRequest('$_bank|$amount'));
      _submitKey.reset();
      if (mounted) setState(() => _result = r);
    } on ApiException catch (e) {
      _submitKey.settle(e);
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
        title: _result!.pending ? t.xferWithdrawalRecorded : t.xferWithdrawalSubmitted,
        message: _result!.pending ? t.xferTheBrokerHasnT : t.xferAchWithdrawals(achWithdrawalArrival),
        result: _result!,
        amount: parseAmount(_amount.text)!,
        method: 'ACH',
      );
    }
    final banks = _banks;
    final m = _money;
    if (banks == null || m == null) {
      return PageScaffold(
        title: t.drawerWithdraw,
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
        title: t.xferConfirmWithdrawal,
        content: [
          AppCard(
            child: Column(
              children: [
                Text(t.xferWithdrawalAmount, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(fmtUsd(amt), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          AppCard(
            child: Column(
              children: [
                KvRow(t.xferFrom, t.xferYourBrokerageAccount),
                KvRow(t.xferTo, b?.displayName ?? '—'),
                KvRow(t.xferMethod, 'ACH'),
                KvRow(t.xferFee, achWithdrawalFee),
                KvRow(t.xferEstimatedArrival, achWithdrawalArrival),
              ],
            ),
          ),
        ],
        footer: [
          AppButton(t.xferEdit, kind: ButtonKind.ghost, fitContent: true, onPressed: _busy ? null : () => setState(() => _confirm = false)),
          Expanded(
            child: AppButton(t.xferConfirmWithdrawal, key: const Key('p14.submit'), loading: _busy, onPressed: _busy ? null : _submit),
          ),
        ],
      );
    }
    return PageScaffold(
      title: t.drawerWithdraw,
      content: [
        if (_submitError != null) Notice(_submitError!, kind: NoticeKind.danger),
        AppCard(
          child: Column(
            children: [
              KvRow(t.xferAvailableToWithdraw, fmtUsd(m.cashAvailableForWithdrawal), valueKey: const Key('p14.withdrawable')),
              KvRow(t.xferAccountCash, fmtUsd(m.cash)),
              KvRow(t.xferUnsettledFunds, fmtUsd(m.unsettled)),
              KvRow(t.xferInAchHoldingPeriod, fmtUsd(m.withheldForSeasoning)),
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  t.xferYourAvailableToWithdraw(seasoningFallback),
                  style: TextStyle(fontSize: 12, color: AppColors.faint),
                ),
              ),
            ],
          ),
        ),
        Seg2<String>(items: [('ACH', t.xferBankTransferAch), ('WIRE', t.xferWireTransfer)], value: _method, onChanged: (v) => setState(() => _method = v)),
        const SizedBox(height: 12),
        if (_method == 'WIRE')
          Notice(t.xferWireWithdrawalsArenT)
        else ...[
          SectionTitle(t.xferToBankAccount),
          if (banks.isEmpty)
            Notice(t.xferNoBankAccountLinked, kind: NoticeKind.warn)
          else
            _BankPicker(banks: banks, selected: _bank, onSelect: (id) => setState(() => _bank = id)),
          LinkButton(
            t.bankLinkBankAccount,
            fontSize: 13,
            onPressed: () async {
              final linked = await context.push<bool>('/funding/banks/link');
              if (linked == true) _load();
            },
          ),
          const SizedBox(height: 8),
          AppField(
            label: t.xferWithdrawalAmountUsd,
            controller: _amount,
            fieldKey: const Key('p14.amount'),
            hint: '0.00',
            helper: t.xferPerTransferAndNo(fmtUsd(FundingLimits.minWithdrawal), fmtUsd(FundingLimits.maxWithdrawal)),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            error: _amountError,
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
          ),
          AppCard(child: Column(children: [KvRow(t.xferFee, achWithdrawalFee), KvRow(t.xferEstimatedArrival, achWithdrawalArrival)])),
        ],
      ],
      footer: [
        Expanded(
          child: AppButton(t.orderNext, key: const Key('p14.next'), onPressed: _method != 'ACH' || _bank == null ? null : _next),
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
    title: t.xferTransferHistory,
    content: [
      Seg2<String>(
        items: [('ALL', t.marketAll), ('DEPOSIT', t.xferDeposits), ('WITHDRAWAL', t.xferWithdrawals)],
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
        AppCard(
          child: Text(t.xferNoTransfersYet, style: TextStyle(color: AppColors.muted)),
        ),
      if (_list != null && _list!.isNotEmpty)
        ListGroup(
          children: [
            for (final tr in _list!)
              InkWell(
                key: Key('p18.row.${tr.id}'),
                onTap: () => _detail(tr),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.isDeposit ? t.transferTitleDeposit(tr.method) : t.transferTitleWithdrawal(tr.method),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            Text(fmtDateTime(tr.submittedAt), style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${tr.isDeposit ? '+' : '-'}${fmtUsd(tr.amount)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                          const SizedBox(height: 2),
                          _badge(tr.status),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(t.xferShowingYour50Most, style: TextStyle(fontSize: 12, color: AppColors.faint)),
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

  void _detail(Transfer tr) {
    final bank = _banks.where((b) => b.id == tr.bankAccountId).firstOrNull;
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
              Text(tr.isDeposit ? t.transferDetailDeposit(tr.method) : t.transferDetailWithdrawal(tr.method), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              KvRow(t.xferTransactionId, tr.id),
              KvRow(t.xferAmount, fmtUsd(tr.amount)),
              KvRow(t.orderStatus, transferStatusLabels[tr.status] ?? tr.status),
              if (bank != null) KvRow(tr.isDeposit ? t.xferFromAccount : t.xferToAccount, bank.displayName),
              KvRow(t.ordersSubmitted, fmtDateTime(tr.submittedAt)),
              if (tr.doneAt != null) KvRow(t.ordersCompleted, fmtDateTime(tr.doneAt)),
              if (tr.isDeposit) ...[
                KvRow(
                  t.xferBuyingPowerAvailable2,
                  tr.buyingPowerAvailableAt == null ? t.xferPendingBrokerUpdate : _date(tr.buyingPowerAvailableAt),
                  valueKey: const Key('p18.bpDate'),
                ),
                KvRow(t.xferWithdrawableOn, tr.withdrawableAt == null ? t.xferPendingBrokerUpdate : _date(tr.withdrawableAt), valueKey: const Key('p18.wdDate')),
                if (tr.buyingPowerAvailableAt == null || tr.withdrawableAt == null)
                  Text(t.xferText(buyingPowerFallback, seasoningFallback), style: TextStyle(fontSize: 12, color: AppColors.faint)),
              ],
              if (tr.status == 'UNCONFIRMED')
                Notice(t.xferUnconfirmedNotice, key: const Key('p18.unconfirmed'), kind: NoticeKind.warn)
              else if (tr.failureReason != null)
                Notice(t.xferReason(localizeServerText(tr.failureReason!, t.serverReasonTransfer)), kind: NoticeKind.danger),
            ],
          ),
        ),
      ),
    );
  }
}
