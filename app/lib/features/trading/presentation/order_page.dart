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
import '../../funding/domain/funding_rules.dart';
import '../../market/data/market_api.dart';
import '../../market/domain/instruments.dart';
import '../../market/presentation/market_widgets.dart';
import '../data/trading_api.dart';
import '../domain/trading_rules.dart';

/// 交易模块错误文案（中文）。
String tradingErrorText(ApiException e) => switch (e.code) {
  ApiCodes.restricted => e.message.isNotEmpty ? e.message : '账户当前受限，暂不能交易。如有疑问请联系客服。',
  _ => e.message,
};

/// P-19 下单（F14，本期只做市价单）：填写（买 / 卖、按金额 / 按股数、预估信息）→ 确认 → 结果。
/// 参考价为演示行情（F11），实际成交以券商（DriveWealth）返回为准；购买力与可卖数量取 DW 返回值。
class OrderPage extends StatefulWidget {
  const OrderPage({super.key, required this.symbol, this.side = 'BUY'});
  final String symbol;
  final String side;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

enum _Mode { amount, qty }

class _OrderPageState extends State<OrderPage> {
  late String _side = widget.side == 'SELL' ? 'SELL' : 'BUY';
  _Mode _mode = _Mode.amount;
  String _step = 'form';
  final _input = TextEditingController();
  String? _inputError;
  String? _submitError;
  bool _busy = false;

  AccountInfo? _account;
  bool _notOpened = false;
  AccountMoney? _money;
  Positions? _positions;
  String? _loadError;
  Quote? _quote;
  Timer? _timer;

  OrderResult? _result;
  Order? _filled; // 结果页：DW 返回的成交数据

  bool get _buy => _side == 'BUY';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadQuote();
      _timer = Timer.periodic(quotePollInterval, (_) => _loadQuote());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    try {
      final acct = await AccountApi(api).account();
      final (money, pos) = await (AccountApi(api).money(), TradingApi(api).positions()).wait;
      if (!mounted) return;
      setState(() {
        _account = acct;
        _money = money;
        _positions = pos;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => e.code == ApiCodes.conflict ? _notOpened = true : _loadError = tradingErrorText(e));
    } on ParallelWaitError<(AccountMoney?, Positions?), (AsyncError?, AsyncError?)> catch (e) {
      final err = e.errors.$1?.error ?? e.errors.$2?.error;
      if (!mounted) return;
      setState(() => _loadError = err is ApiException ? tradingErrorText(err) : '$err');
    }
  }

  Future<void> _loadQuote() async {
    if (!mounted || _step == 'done') return;
    try {
      final b = await MarketApi(AppScope.of(context).api).quotes([widget.symbol]);
      if (mounted) setState(() => _quote = b.quotes[widget.symbol]);
    } on ApiException {
      // 行情暂不可用：按股数买入的预估不可用，提示按金额买入
    }
  }

  /// 参考价：买入用卖一价，卖出用买一价（演示行情）。
  double? get _refPrice {
    final q = _quote;
    if (q == null) return null;
    final p = _buy ? q.ask : q.bid;
    return p > 0 ? p : (q.last > 0 ? q.last : null);
  }

  Position? get _position => _positions?.of(widget.symbol);
  double get _sellable => _position?.sellableQty ?? 0;
  double? get _sellableValue => _position == null ? 0 : _position!.sellableQty * _position!.marketPrice;

  String? get _restriction => switch (_account?.status) {
    'FROZEN' => '账户已冻结，暂不能交易。资产仍安全托管，请联系客服了解原因。',
    'CLOSED' => '账户已关闭，不能交易。',
    'OPEN_NO_NEW_TRADES' when _buy => '账户当前仅可卖出，暂不能买入。',
    _ => null,
  };

  String? _validate() => _mode == _Mode.amount
      ? validateOrderAmount(_input.text, buy: _buy, buyingPower: _money?.buyingPower, sellableValue: _buy ? null : _sellableValue)
      : validateOrderQty(_input.text, buy: _buy, price: _refPrice, buyingPower: _money?.buyingPower, sellableQty: _buy ? null : _sellable);

  void _toConfirm() {
    final err = _validate();
    setState(() {
      _inputError = err;
      _submitError = null;
    });
    if (err == null) setState(() => _step = 'confirm');
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _submitError = null;
    });
    final api = TradingApi(AppScope.of(context).api);
    try {
      final r = await api.place(
        symbol: widget.symbol,
        side: _side,
        amount: _mode == _Mode.amount ? parseAmount(_input.text) : null,
        quantity: _mode == _Mode.qty ? parseQty(_input.text) : null,
      );
      Order? detail;
      if (!r.pending) {
        try {
          detail = await api.order(r.orderId);
        } on ApiException {
          // 详情暂取不到：结果页只显示提交状态
        }
      }
      if (!mounted) return;
      setState(() {
        _result = r;
        _filled = detail;
        _step = 'done';
      });
      final status = detail?.status ?? r.status;
      // 交易提交成功：轻量版庆祝（同入金；结果待确认或被拒绝时不播放）；同一订单只播一次
      if (!r.pending && status != 'REJECTED') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Celebration.show(context, key: 'order:${r.orderId}', level: CelebrationLevel.light);
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = tradingErrorText(e);
        _inputError = e.fieldMap['amount'] ?? e.fieldMap['quantity'] ?? (e.code == ApiCodes.limit ? e.message : null);
        if (e.code == ApiCodes.validation || e.code == ApiCodes.limit) _step = 'form';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- 视图 ----------

  String get _name => instrumentOf(widget.symbol)?.name ?? widget.symbol;

  String get _orderSizeText {
    if (_mode == _Mode.amount) {
      final v = parseAmount(_input.text);
      return v == null ? '—' : fmtUsd(v);
    }
    final q = parseQty(_input.text);
    return q == null ? '—' : '${fmtQty(q)} 股';
  }

  /// 预估：按金额 → 约多少股；按股数 → 约多少金额（演示参考价）。
  String get _estimateText {
    final p = _refPrice;
    if (p == null) return '—';
    if (_mode == _Mode.amount) {
      final v = parseAmount(_input.text);
      return v == null ? '—' : '约 ${fmtQty(v / p)} 股';
    }
    final q = parseQty(_input.text);
    return q == null ? '—' : '约 ${fmtUsd(q * p)}';
  }

  @override
  Widget build(BuildContext context) {
    final title = '${_buy ? '买入' : '卖出'} ${widget.symbol}';
    if (_step == 'done' && _result != null) return _resultView();
    if (_notOpened) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: StateView(
          icon: Icons.lock_outline_rounded,
          title: '开户后即可交易',
          message: '交易账户开立后才能下单。请先完成开户。',
          actions: [AppButton('返回资产页', onPressed: () => context.go('/home'))],
        ),
      );
    }
    if (_account == null || _money == null || _positions == null) {
      return PageScaffold(
        title: title,
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
    return _step == 'confirm' ? _confirmView(title) : _formView(title);
  }

  Widget _header() {
    final q = _quote;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text(_name, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                q == null ? '—' : fmtPx(q.last),
                key: const Key('p19.last'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              Text(
                q == null ? '演示行情' : '${fmtSigned(q.chgPct, suffix: '%')} · 演示行情',
                style: TextStyle(fontSize: 12, color: q == null ? AppColors.muted : chgColor(q.chg)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formView(String title) {
    final restriction = _restriction;
    final pos = _position;
    return PageScaffold(
      title: title,
      content: [
        if (_submitError != null) Notice(_submitError!, kind: NoticeKind.danger),
        _header(),
        Seg2<String>(
          key: const Key('p19.side'),
          items: const [('BUY', '买入'), ('SELL', '卖出')],
          value: _side,
          onChanged: (v) => setState(() {
            _side = v;
            _inputError = null;
            _submitError = null;
          }),
        ),
        Seg2<_Mode>(
          key: const Key('p19.mode'),
          items: const [(_Mode.amount, '按金额'), (_Mode.qty, '按股数')],
          value: _mode,
          onChanged: (v) => setState(() {
            _mode = v;
            _input.clear();
            _inputError = null;
          }),
        ),
        if (restriction != null) Notice(restriction, kind: NoticeKind.warn),
        AppField(
          label: _mode == _Mode.amount ? '${_buy ? '买入' : '卖出'}金额 (USD)' : '${_buy ? '买入' : '卖出'}股数',
          controller: _input,
          fieldKey: const Key('p19.input'),
          hint: _mode == _Mode.amount ? '0.00' : '0',
          helper: _mode == _Mode.amount ? '支持碎股；$minOrderText' : '支持小数股，最多 6 位小数',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          error: _inputError,
          onChanged: (_) => setState(() => _inputError = null),
        ),
        if (!_buy && pos != null && _mode == _Mode.qty)
          Align(
            alignment: Alignment.centerRight,
            child: LinkButton(
              '全部卖出（${fmtQty(pos.sellableQty)} 股）',
              key: const Key('p19.sellAll'),
              fontSize: 13,
              onPressed: () => setState(() {
                _input.text = fmtQty(pos.sellableQty);
                _inputError = null;
              }),
            ),
          ),
        AppCard(
          child: Column(
            children: [
              const KvRow('订单类型', '市价单'),
              KvRow('参考价（演示行情）', _refPrice == null ? '—' : fmtUsd(_refPrice!)),
              KvRow(_mode == _Mode.amount ? '预估股数' : '预估金额', _estimateText, valueKey: const Key('p19.estimate')),
              if (_buy)
                KvRow('可用购买力', fmtUsd(_money!.buyingPower), valueKey: const Key('p19.buyingPower'))
              else
                KvRow('可卖数量', '${fmtQty(_sellable)} 股', valueKey: const Key('p19.sellable')),
            ],
          ),
        ),
        Notice(
          _buy && _money!.buyingPower <= 0
              ? '当前可用购买力为 \$0.00。入金结算后才计入购买力，日期以资金记录中券商返回的为准。'
              : '市价单按券商实际成交价成交。本期不区分盘前盘后，休市时提交的订单可能排队至开盘，状态以券商返回为准。',
        ),
      ],
      footer: [
        Expanded(
          child: AppButton('下一步', key: const Key('p19.next'), onPressed: restriction != null ? null : _toConfirm),
        ),
      ],
    );
  }

  Widget _confirmView(String title) => PageScaffold(
    title: '确认订单',
    content: [
      if (_submitError != null) Notice(_submitError!, kind: NoticeKind.danger),
      AppCard(
        child: Column(
          children: [
            Text('${_buy ? '买入' : '卖出'} ${widget.symbol}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            Text(
              _orderSizeText,
              key: const Key('p19.confirm.size'),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      AppCard(
        child: Column(
          children: [
            KvRow('股票', '${widget.symbol} · $_name'),
            KvRow('方向', _buy ? '买入' : '卖出'),
            const KvRow('订单类型', '市价单'),
            KvRow(_mode == _Mode.amount ? '委托金额' : '委托股数', _orderSizeText),
            KvRow('参考价（演示行情）', _refPrice == null ? '—' : fmtUsd(_refPrice!)),
            KvRow(_mode == _Mode.amount ? '预估股数' : '预估金额', _estimateText),
            const KvRow('托管券商', 'DriveWealth'),
          ],
        ),
      ),
      const Notice(demoPriceNotice, key: Key('p19.demoNotice'), kind: NoticeKind.warn),
    ],
    footer: [
      AppButton('返回修改', kind: ButtonKind.ghost, fitContent: true, onPressed: _busy ? null : () => setState(() => _step = 'form')),
      Expanded(
        child: AppButton(_buy ? '确认买入' : '确认卖出', key: const Key('p19.submit'), loading: _busy, onPressed: _busy ? null : _submit),
      ),
    ],
  );

  Widget _resultView() {
    final r = _result!;
    final o = _filled;
    final status = o?.status ?? r.status;
    final rejected = status == 'REJECTED';
    final (icon, head) = switch (status) {
      _ when r.pending => (Icons.schedule_rounded, '订单已记录'),
      'FILLED' => (Icons.check_rounded, '订单已成交'),
      'REJECTED' => (Icons.close_rounded, '券商已拒绝该订单'),
      _ => (Icons.check_rounded, '订单已提交'),
    };
    final message = switch (status) {
      _ when r.pending => '券商受理结果暂未确认，我们会自动核对，请稍后在订单列表中查看状态。请勿重复提交。',
      'FILLED' => '成交价与数量以券商返回为准。',
      'REJECTED' => o?.rejectReason ?? '券商已拒绝该订单，请稍后重试或联系客服。',
      _ => '订单已发送至券商，成交后状态会在订单列表中更新。休市期间提交的订单可能排队至开盘。',
    };
    return PageScaffold(
      title: '下单结果',
      content: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: rejected ? AppColors.dangerWeak : AppColors.primaryWeak, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: rejected ? AppColors.danger : AppColors.primary),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            head,
            key: const Key('p19.result'),
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
              KvRow('订单号', o?.orderNo ?? r.orderId),
              KvRow('股票', widget.symbol),
              KvRow('方向', _buy ? '买入' : '卖出'),
              KvRow(_mode == _Mode.amount ? '委托金额' : '委托股数', _orderSizeText),
              KvRow('状态', orderStatusLabels[status] ?? status, valueKey: const Key('p19.result.status')),
              if (o?.filledQty != null && o!.filledQty! > 0) KvRow('成交数量', '${fmtQty(o.filledQty!)} 股'),
              if (o?.avgPrice != null && o!.avgPrice! > 0) KvRow('成交均价', fmtUsd(o.avgPrice!), valueKey: const Key('p19.result.avgPrice')),
              if (o?.totalAmount != null && o!.totalAmount! > 0) KvRow('成交金额', fmtUsd(o.totalAmount!)),
            ],
          ),
        ),
        const Notice(demoPriceNotice, kind: NoticeKind.info),
      ],
      footer: [
        Expanded(
          child: AppButton('查看订单', key: const Key('p19.orders'), kind: ButtonKind.ghost, onPressed: () => context.go('/orders')),
        ),
        Expanded(
          child: AppButton(
            '完成',
            key: const Key('p19.done'),
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
      ],
    );
  }
}
