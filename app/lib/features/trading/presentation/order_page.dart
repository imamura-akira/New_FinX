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
import '../domain/trading_mode.dart';
import '../domain/trading_rules.dart';
import 'paper_widgets.dart';
import '../../../l10n/l10n.dart';

/// 交易模块错误文案（中文）。
String tradingErrorText(ApiException e) => switch (e.code) {
  ApiCodes.restricted => e.message.isNotEmpty ? e.message : t.orderYourAccountIsCurrently,
  _ => e.message,
};

/// P-19 下单：填写（实盘 / 模拟盘、买 / 卖、市价 / 限价、按金额 / 按股数、预估信息）→ 确认 → 结果。
/// 实盘（F14）：购买力与可卖数量取 DW 返回值，实际成交以券商（DriveWealth）返回为准。
/// 模拟盘（F15）：数据来自 /paper/*，虚拟资金按演示行情撮合，不调用 DW；页面常驻"模拟盘"横幅。
class OrderPage extends StatefulWidget {
  const OrderPage({super.key, required this.symbol, this.side = 'BUY', this.paper = false});
  final String symbol;
  final String side;
  final bool paper;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

enum _Mode { amount, qty }

class _OrderPageState extends State<OrderPage> {
  late String _side = widget.side == 'SELL' ? 'SELL' : 'BUY';
  late bool _paper = widget.paper;
  String _type = 'MARKET';
  _Mode _mode = _Mode.amount;
  String _step = 'form';
  final _input = TextEditingController();
  final _limit = TextEditingController();
  String? _inputError;
  String? _limitError;
  String? _submitError;
  bool _busy = false;

  // 实盘
  AccountInfo? _account;
  bool _notOpened = false;
  AccountMoney? _money;
  // 模拟盘
  PaperAccount? _paperAccount;
  // 共用
  Positions? _positions;
  String? _loadError;
  Quote? _quote;
  Timer? _timer;

  OrderResult? _result;
  Order? _filled; // 结果页：成交数据（实盘为 DW 返回，模拟盘为模拟撮合）
  bool _resultPaper = false;

  bool get _buy => _side == 'BUY';
  bool get _isLimit => _type == 'LIMIT';
  bool get _limitAllowed => _paper || TradingFeatures.realLimitOrders;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TradingMode.instance.paper = widget.paper; // 与路由一致（构建完成后再写，避免构建期间通知其他页面）
      _load();
      _loadQuote();
      _timer = Timer.periodic(quotePollInterval, (_) => _loadQuote());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    final paper = _paper;
    try {
      if (paper) {
        final papi = TradingApi(api, paper: true);
        final (acct, pos) = await (papi.paperAccount(), papi.positions()).wait;
        if (!mounted || paper != _paper) return;
        setState(() {
          _paperAccount = acct;
          _positions = pos;
          _loadError = null;
        });
        return;
      }
      final acct = await AccountApi(api).account();
      final (money, pos) = await (AccountApi(api).money(), TradingApi(api).positions()).wait;
      if (!mounted || paper != _paper) return;
      setState(() {
        _account = acct;
        _money = money;
        _positions = pos;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (!mounted || paper != _paper) return;
      setState(() => !paper && e.code == ApiCodes.conflict ? _notOpened = true : _loadError = tradingErrorText(e));
    } on ParallelWaitError catch (e) {
      final errs = e.errors;
      final err = errs is (AsyncError?, AsyncError?) ? (errs.$1?.error ?? errs.$2?.error) : e;
      if (!mounted || paper != _paper) return;
      setState(() => _loadError = err is ApiException ? tradingErrorText(err) : '$err');
    }
  }

  /// 实盘 / 模拟盘切换：清空当前数据并重新加载。
  void _switchAccount(bool paper) {
    setState(() {
      _paper = paper;
      _notOpened = false;
      _account = null;
      _money = null;
      _paperAccount = null;
      _positions = null;
      _loadError = null;
      _inputError = _limitError = _submitError = null;
      _step = 'form';
      if (!_limitAllowed) _type = 'MARKET';
    });
    _load();
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

  double? get _buyingPower => _paper ? _paperAccount?.buyingPower : _money?.buyingPower;
  Position? get _position => _positions?.of(widget.symbol);
  double get _sellable => _position?.sellableQty ?? 0;
  double? get _sellableValue => _position == null ? 0 : _position!.sellableQty * _position!.marketPrice;

  String? get _restriction => _paper
      ? null
      : switch (_account?.status) {
          'FROZEN' => t.orderYourAccountIsFrozen,
          'CLOSED' => t.orderYourAccountIsClosed,
          'OPEN_NO_NEW_TRADES' when _buy => t.orderYourAccountIsCurrently2,
          _ => null,
        };

  bool get _loaded => _paper ? (_paperAccount != null && _positions != null) : (_account != null && _money != null && _positions != null);

  void _toConfirm() {
    String? err, lErr;
    if (_isLimit) {
      (err, lErr) = validateLimitOrder(_input.text, _limit.text, buy: _buy, buyingPower: _buyingPower, sellableQty: _buy ? null : _sellable);
    } else if (_mode == _Mode.amount) {
      err = validateOrderAmount(_input.text, buy: _buy, buyingPower: _buyingPower, sellableValue: _buy ? null : _sellableValue);
    } else {
      err = validateOrderQty(_input.text, buy: _buy, price: _refPrice, buyingPower: _buyingPower, sellableQty: _buy ? null : _sellable);
    }
    setState(() {
      _inputError = err;
      _limitError = lErr;
      _submitError = null;
    });
    if (err == null && lErr == null) setState(() => _step = 'confirm');
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _submitError = null;
    });
    final paper = _paper;
    final api = TradingApi(AppScope.of(context).api, paper: paper);
    try {
      final byAmount = !_isLimit && _mode == _Mode.amount;
      final r = await api.place(
        symbol: widget.symbol,
        side: _side,
        orderType: _type,
        amount: byAmount ? parseAmount(_input.text) : null,
        quantity: byAmount ? null : parseQty(_input.text),
        limitPrice: _isLimit ? parseLimitPrice(_limit.text) : null,
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
        _resultPaper = paper;
        _step = 'done';
      });
      final status = detail?.status ?? r.status;
      // 交易提交成功：轻量版庆祝（同入金；结果待确认、被拒绝或限价单仅挂单时不播放）；同一订单只播一次
      final celebrate = !r.pending && status != 'REJECTED' && !(_isLimit && status == 'NEW');
      if (celebrate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Celebration.show(context, key: '${paper ? 'paper-' : ''}order:${r.orderId}', level: CelebrationLevel.light);
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = tradingErrorText(e);
        _inputError = e.fieldMap['amount'] ?? e.fieldMap['quantity'] ?? (e.code == ApiCodes.limit ? e.message : null);
        _limitError = e.fieldMap['limitPrice'];
        if (e.code == ApiCodes.validation || e.code == ApiCodes.limit) _step = 'form';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- 视图 ----------

  String get _name => instrumentOf(widget.symbol)?.name ?? widget.symbol;

  String get _orderSizeText {
    if (!_isLimit && _mode == _Mode.amount) {
      final v = parseAmount(_input.text);
      return v == null ? '—' : fmtUsd(v);
    }
    final q = parseQty(_input.text);
    return q == null ? '—' : t.ordersShares(fmtQty(q));
  }

  String get _sizeLabel => !_isLimit && _mode == _Mode.amount ? t.orderOrderAmount : t.orderOrderQuantity;

  /// 预估：市价按金额 → 约多少股；市价按股数 → 约多少金额（演示参考价）；限价 → 股数 × 限价。
  String get _estimateText {
    if (_isLimit) {
      final q = parseQty(_input.text);
      final l = parseLimitPrice(_limit.text);
      return q == null || l == null ? '—' : fmtUsd(q * l);
    }
    final p = _refPrice;
    if (p == null) return '—';
    if (_mode == _Mode.amount) {
      final v = parseAmount(_input.text);
      return v == null ? '—' : t.orderShares(fmtQty(v / p));
    }
    final q = parseQty(_input.text);
    return q == null ? '—' : t.orderText(fmtUsd(q * p));
  }

  String get _estimateLabel => _isLimit ? (_buy ? t.orderEstimatedAmountOnHold : t.orderEstimatedAmount) : (_mode == _Mode.amount ? t.orderEstimatedShares : t.orderEstimatedAmount);

  String get _typeText => _isLimit ? t.orderLimitOrderDay : t.orderMarketOrder;

  @override
  Widget build(BuildContext context) {
    final title = '${_buy ? t.orderSideBuy : t.orderSideSell} ${widget.symbol}';
    if (_step == 'done' && _result != null) return _resultView();
    if (_notOpened && !_paper) {
      return Scaffold(
        appBar: AppBar(title: Text(title), leading: const AppBackButton()),
        body: StateView(
          icon: Icons.lock_outline_rounded,
          title: t.orderOpenAnAccountTo,
          message: t.orderYouCanPlaceOrders,
          actions: [
            AppButton(t.orderSwitchToPaperTrading, key: const Key('p19.toPaper'), onPressed: () => _switchAccount(TradingMode.instance.paper = true)),
            AppButton(t.ordersBackToAssets, kind: ButtonKind.ghost, onPressed: () => context.go('/home')),
          ],
        ),
      );
    }
    if (!_loaded) {
      return _scaffold(title, [
        AccountModeSwitch(onChanged: _switchAccount),
        if (_paper) const PaperBanner(),
        if (_loadError != null)
          Notice(_loadError!, kind: NoticeKind.warn)
        else
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
      ]);
    }
    return _step == 'confirm' ? _confirmView() : _formView(title);
  }

  Widget _scaffold(String title, List<Widget> content, {List<Widget>? footer}) => Scaffold(
    appBar: AppBar(title: paperTitle(title, _paper), leading: const AppBackButton()),
    resizeToAvoidBottomInset: true,
    body: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: content,
            ),
          ),
          if (footer != null) FooterBar(compactBottom: MediaQuery.of(context).viewInsets.bottom > 0, children: footer),
        ],
      ),
    ),
  );

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
                Text(_name, style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
                q == null ? t.orderDemoQuote : '${fmtSigned(q.chgPct, suffix: '%')} · ${t.orderDemoQuote}',
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
    final bp = _buyingPower ?? 0;
    return _scaffold(
      title,
      [
        AccountModeSwitch(onChanged: _switchAccount),
        if (_paper) const PaperBanner(),
        if (_submitError != null) Notice(_submitError!, kind: NoticeKind.danger),
        _header(),
        Seg2<String>(
          key: const Key('p19.side'),
          items: [('BUY', t.orderSideBuy), ('SELL', t.orderSideSell)],
          value: _side,
          onChanged: (v) => setState(() {
            _side = v;
            _inputError = _limitError = _submitError = null;
          }),
        ),
        if (_limitAllowed)
          Seg2<String>(
            key: const Key('p19.type'),
            items: [('MARKET', t.orderMarket), ('LIMIT', t.orderLimit)],
            value: _type,
            onChanged: (v) => setState(() {
              _type = v;
              _input.clear();
              _limit.clear();
              _inputError = _limitError = null;
            }),
          ),
        if (!_isLimit)
          Seg2<_Mode>(
            key: const Key('p19.mode'),
            items: [(_Mode.amount, t.orderByAmount), (_Mode.qty, t.orderByShares)],
            value: _mode,
            onChanged: (v) => setState(() {
              _mode = v;
              _input.clear();
              _inputError = null;
            }),
          ),
        if (restriction != null) Notice(restriction, kind: NoticeKind.warn),
        if (_isLimit)
          AppField(
            label: t.orderLimitPriceUsd,
            controller: _limit,
            fieldKey: const Key('p19.limitPrice'),
            hint: _refPrice == null ? '0.00' : fmtPx(_refPrice!),
            helper: _buy ? t.orderLimitHelpBuy : t.orderLimitHelpSell,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            error: _limitError,
            onChanged: (_) => setState(() => _limitError = null),
          ),
        AppField(
          label: !_isLimit && _mode == _Mode.amount ? (_buy ? t.orderBuyAmountUsd : t.orderSellAmountUsd) : (_buy ? t.orderBuyShares : t.orderSellShares),
          controller: _input,
          fieldKey: const Key('p19.input'),
          hint: !_isLimit && _mode == _Mode.amount ? '0.00' : '0',
          helper: !_isLimit && _mode == _Mode.amount ? t.orderFractionalSharesSupported(minOrderText) : t.orderFractionalSharesSupportedUp,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          error: _inputError,
          onChanged: (_) => setState(() => _inputError = null),
        ),
        if (!_buy && pos != null && (_isLimit || _mode == _Mode.qty))
          Align(
            alignment: Alignment.centerRight,
            child: LinkButton(
              t.orderSellAllShares(fmtQty(pos.sellableQty)),
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
              KvRow(t.orderOrderType, _typeText),
              KvRow(t.orderReferencePriceDemoQuote, _refPrice == null ? '—' : fmtUsd(_refPrice!)),
              KvRow(_estimateLabel, _estimateText, valueKey: const Key('p19.estimate')),
              if (_buy)
                KvRow(_paper ? t.orderPaperAvailableFunds : t.orderBuyingPower, fmtUsd(bp), valueKey: const Key('p19.buyingPower'))
              else
                KvRow(t.positionsSellable, t.ordersShares(fmtQty(_sellable)), valueKey: const Key('p19.sellable')),
            ],
          ),
        ),
        Notice(
          _paper
              ? (_isLimit ? t.orderPaperLimitOrderFills : t.orderPaperMarketOrdersFill)
              : _buy && bp <= 0
              ? t.orderYourCurrentBuyingPower
              : _isLimit
              ? t.orderLimitOrdersAreGood
              : t.orderMarketOrdersFillAt,
        ),
      ],
      footer: [
        Expanded(
          child: AppButton(t.orderNext, key: const Key('p19.next'), onPressed: restriction != null ? null : _toConfirm),
        ),
      ],
    );
  }

  Widget _confirmView() => _scaffold(
    t.orderReviewOrder,
    [
      if (_paper) const PaperBanner(),
      if (_submitError != null) Notice(_submitError!, kind: NoticeKind.danger),
      AppCard(
        child: Column(
          children: [
            Text('${_buy ? t.orderSideBuy : t.orderSideSell} ${widget.symbol}', style: TextStyle(fontSize: 13, color: AppColors.muted)),
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
            KvRow(t.homeAccount, _paper ? t.orderPaperVirtualFunds : t.orderLiveDrivewealth),
            KvRow(t.instrumentStock, '${widget.symbol} · $_name'),
            KvRow(t.orderSide, _buy ? t.orderSideBuy : t.orderSideSell),
            KvRow(t.orderOrderType, _typeText),
            if (_isLimit) KvRow(t.orderLimitPrice, fmtUsd(parseLimitPrice(_limit.text) ?? 0), valueKey: const Key('p19.confirm.limit')),
            KvRow(_sizeLabel, _orderSizeText),
            KvRow(t.orderReferencePriceDemoQuote, _refPrice == null ? '—' : fmtUsd(_refPrice!)),
            KvRow(_estimateLabel, _estimateText),
            if (!_paper) KvRow(t.orderCustodian, 'DriveWealth'),
          ],
        ),
      ),
      if (_paper)
        Notice(paperPriceNotice, key: Key('p19.paperNotice'), kind: NoticeKind.warn)
      else
        Notice(demoPriceNotice, key: Key('p19.demoNotice'), kind: NoticeKind.warn),
    ],
    footer: [
      AppButton(t.orderEditOrder, kind: ButtonKind.ghost, fitContent: true, onPressed: _busy ? null : () => setState(() => _step = 'form')),
      Expanded(
        child: AppButton(_buy ? t.orderConfirmBuy : t.orderConfirmSell, key: const Key('p19.submit'), loading: _busy, onPressed: _busy ? null : _submit),
      ),
    ],
  );

  Widget _resultView() {
    final r = _result!;
    final o = _filled;
    final paper = _resultPaper;
    final status = o?.status ?? r.status;
    final rejected = status == 'REJECTED';
    final resting = _isLimit && status == 'NEW';
    final (icon, head) = switch (status) {
      _ when r.pending => (Icons.schedule_rounded, t.orderOrderRecorded),
      'FILLED' => (Icons.check_rounded, paper ? t.orderPaperOrderFilled : t.orderOrderFilled),
      'REJECTED' => (Icons.close_rounded, t.orderOrderRejectedByThe),
      _ when resting => (Icons.schedule_rounded, paper ? t.orderPaperLimitOrderPlaced : t.orderLimitOrderSubmitted),
      _ => (Icons.check_rounded, t.orderOrderSubmitted),
    };
    final message = switch (status) {
      _ when r.pending => t.orderTheBrokerHasnT,
      'FILLED' => paper ? t.orderSimulatedFillAtDemo : t.orderFillPriceAndQuantity,
      'REJECTED' => o?.rejectReason == null ? t.orderTheBrokerRejectedThis : localizeServerText(o!.rejectReason!, t.orderTheBrokerRejectedThis),
      _ when resting && paper => t.orderFillsAutomaticallyWhenThe,
      _ when resting => t.orderMayFillOnlyWhen,
      _ => t.orderYourOrderHasBeen,
    };
    return _scaffold(t.orderOrderResult, [
      if (paper) const PaperBanner(),
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
        style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          children: [
            KvRow(t.ordersOrderNo, o?.orderNo ?? r.orderId),
            KvRow(t.instrumentStock, widget.symbol),
            KvRow(t.orderSide, _buy ? t.orderSideBuy : t.orderSideSell),
            KvRow(t.orderOrderType, _typeText),
            if (_isLimit) KvRow(t.orderLimitPrice, fmtUsd(parseLimitPrice(_limit.text) ?? 0)),
            KvRow(_sizeLabel, _orderSizeText),
            KvRow(t.orderStatus, orderStatusLabel(status, limit: _isLimit), valueKey: const Key('p19.result.status')),
            if (o?.filledQty != null && o!.filledQty! > 0) KvRow(t.orderFilledQuantity, t.ordersShares(fmtQty(o.filledQty!))),
            if (o?.avgPrice != null && o!.avgPrice! > 0) KvRow(t.ordersAvgFillPrice, fmtUsd(o.avgPrice!), valueKey: const Key('p19.result.avgPrice')),
            if (o?.totalAmount != null && o!.totalAmount! > 0) KvRow(t.ordersFilledAmount, fmtUsd(o.totalAmount!)),
          ],
        ),
      ),
      Notice(paper ? paperPriceNotice : demoPriceNotice, kind: NoticeKind.info),
    ], footer: [
      Expanded(
        child: AppButton(
          paper ? t.orderViewPaperOrders : t.orderViewOrders,
          key: const Key('p19.orders'),
          kind: ButtonKind.ghost,
          onPressed: () => context.pushReplacement('/orders${paperQuery(paper)}'),
        ),
      ),
      Expanded(
        child: AppButton(t.orderDone, key: const Key('p19.done'), onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
      ),
    ]);
  }
}
