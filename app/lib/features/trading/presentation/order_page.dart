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

/// 交易模块错误文案（中文）。
String tradingErrorText(ApiException e) => switch (e.code) {
  ApiCodes.restricted => e.message.isNotEmpty ? e.message : '账户当前受限，暂不能交易。如有疑问请联系客服。',
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
        final t = TradingApi(api, paper: true);
        final (acct, pos) = await (t.paperAccount(), t.positions()).wait;
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
          'FROZEN' => '账户已冻结，暂不能交易。资产仍安全托管，请联系客服了解原因。',
          'CLOSED' => '账户已关闭，不能交易。',
          'OPEN_NO_NEW_TRADES' when _buy => '账户当前仅可卖出，暂不能买入。',
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
      // 交易提交成功：轻量版庆祝（同入金；结果待确认、被拒绝或仅挂单时不播放）；同一订单只播一次
      final celebrate = !r.pending && status != 'REJECTED' && !(paper && status == 'NEW');
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
    return q == null ? '—' : '${fmtQty(q)} 股';
  }

  String get _sizeLabel => !_isLimit && _mode == _Mode.amount ? '委托金额' : '委托股数';

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
      return v == null ? '—' : '约 ${fmtQty(v / p)} 股';
    }
    final q = parseQty(_input.text);
    return q == null ? '—' : '约 ${fmtUsd(q * p)}';
  }

  String get _estimateLabel => _isLimit ? (_buy ? '预估金额（冻结）' : '预估金额') : (_mode == _Mode.amount ? '预估股数' : '预估金额');

  String get _typeText => _isLimit ? '限价单 · 当日有效' : '市价单';

  @override
  Widget build(BuildContext context) {
    final title = '${_buy ? '买入' : '卖出'} ${widget.symbol}';
    if (_step == 'done' && _result != null) return _resultView();
    if (_notOpened && !_paper) {
      return Scaffold(
        appBar: AppBar(title: Text(title), leading: const AppBackButton()),
        body: StateView(
          icon: Icons.lock_outline_rounded,
          title: '开户后即可交易',
          message: '交易账户开立后才能下单。请先完成开户，或切换到模拟盘练习。',
          actions: [
            AppButton('切换到模拟盘', key: const Key('p19.toPaper'), onPressed: () => _switchAccount(TradingMode.instance.paper = true)),
            AppButton('返回资产页', kind: ButtonKind.ghost, onPressed: () => context.go('/home')),
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
          items: const [('BUY', '买入'), ('SELL', '卖出')],
          value: _side,
          onChanged: (v) => setState(() {
            _side = v;
            _inputError = _limitError = _submitError = null;
          }),
        ),
        if (_limitAllowed)
          Seg2<String>(
            key: const Key('p19.type'),
            items: const [('MARKET', '市价'), ('LIMIT', '限价')],
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
            items: const [(_Mode.amount, '按金额'), (_Mode.qty, '按股数')],
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
            label: '限价 (USD)',
            controller: _limit,
            fieldKey: const Key('p19.limitPrice'),
            hint: _refPrice == null ? '0.00' : fmtPx(_refPrice!),
            helper: '${_buy ? '买入：价格不高于限价时成交' : '卖出：价格不低于限价时成交'}；当日有效',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            error: _limitError,
            onChanged: (_) => setState(() => _limitError = null),
          ),
        AppField(
          label: !_isLimit && _mode == _Mode.amount ? '${_buy ? '买入' : '卖出'}金额 (USD)' : '${_buy ? '买入' : '卖出'}股数',
          controller: _input,
          fieldKey: const Key('p19.input'),
          hint: !_isLimit && _mode == _Mode.amount ? '0.00' : '0',
          helper: !_isLimit && _mode == _Mode.amount ? '支持碎股；$minOrderText' : '支持小数股，最多 6 位小数',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          error: _inputError,
          onChanged: (_) => setState(() => _inputError = null),
        ),
        if (!_buy && pos != null && (_isLimit || _mode == _Mode.qty))
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
              KvRow('订单类型', _typeText),
              KvRow('参考价（演示行情）', _refPrice == null ? '—' : fmtUsd(_refPrice!)),
              KvRow(_estimateLabel, _estimateText, valueKey: const Key('p19.estimate')),
              if (_buy)
                KvRow(_paper ? '模拟可用资金' : '可用购买力', fmtUsd(bp), valueKey: const Key('p19.buyingPower'))
              else
                KvRow('可卖数量', '${fmtQty(_sellable)} 股', valueKey: const Key('p19.sellable')),
            ],
          ),
        ),
        Notice(
          _paper
              ? (_isLimit ? '模拟限价单：演示行情到达限价时自动成交，未成交前冻结资金 / 股数，当日有效。' : '模拟市价单按演示行情即时成交（买入按卖一价、卖出按买一价）。')
              : _buy && bp <= 0
              ? '当前可用购买力为 \$0.00。入金结算后才计入购买力，日期以资金记录中券商返回的为准。'
              : _isLimit
              ? '限价单当日有效，价格到达限价才可能成交，未成交部分收盘后自动撤销，状态以券商返回为准。'
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

  Widget _confirmView() => _scaffold(
    '确认订单',
    [
      if (_paper) const PaperBanner(),
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
            KvRow('账户', _paper ? '模拟盘（虚拟资金）' : '实盘（DriveWealth）'),
            KvRow('股票', '${widget.symbol} · $_name'),
            KvRow('方向', _buy ? '买入' : '卖出'),
            KvRow('订单类型', _typeText),
            if (_isLimit) KvRow('限价', fmtUsd(parseLimitPrice(_limit.text) ?? 0), valueKey: const Key('p19.confirm.limit')),
            KvRow(_sizeLabel, _orderSizeText),
            KvRow('参考价（演示行情）', _refPrice == null ? '—' : fmtUsd(_refPrice!)),
            KvRow(_estimateLabel, _estimateText),
            if (!_paper) const KvRow('托管券商', 'DriveWealth'),
          ],
        ),
      ),
      if (_paper)
        const Notice(paperPriceNotice, key: Key('p19.paperNotice'), kind: NoticeKind.warn)
      else
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
    final paper = _resultPaper;
    final status = o?.status ?? r.status;
    final rejected = status == 'REJECTED';
    final resting = _isLimit && status == 'NEW';
    final (icon, head) = switch (status) {
      _ when r.pending => (Icons.schedule_rounded, '订单已记录'),
      'FILLED' => (Icons.check_rounded, paper ? '模拟订单已成交' : '订单已成交'),
      'REJECTED' => (Icons.close_rounded, '券商已拒绝该订单'),
      _ when resting => (Icons.schedule_rounded, paper ? '模拟限价单已挂单' : '限价单已提交'),
      _ => (Icons.check_rounded, '订单已提交'),
    };
    final message = switch (status) {
      _ when r.pending => '券商受理结果暂未确认，我们会自动核对，请稍后在订单列表中查看状态。请勿重复提交。',
      'FILLED' => paper ? '按演示行情模拟成交，使用虚拟资金，不产生真实交易。' : '成交价与数量以券商返回为准。',
      'REJECTED' => o?.rejectReason ?? '券商已拒绝该订单，请稍后重试或联系客服。',
      _ when resting && paper => '演示行情到达限价时自动成交；未成交前冻结资金 / 股数，可在模拟订单中撤单。当日有效。',
      _ when resting => '价格到达限价才可能成交，当日有效，可在订单列表中撤单。状态以券商返回为准。',
      _ => '订单已发送至券商，成交后状态会在订单列表中更新。休市期间提交的订单可能排队至开盘。',
    };
    return _scaffold('下单结果', [
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
        style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          children: [
            KvRow('订单号', o?.orderNo ?? r.orderId),
            KvRow('股票', widget.symbol),
            KvRow('方向', _buy ? '买入' : '卖出'),
            KvRow('订单类型', _typeText),
            if (_isLimit) KvRow('限价', fmtUsd(parseLimitPrice(_limit.text) ?? 0)),
            KvRow(_sizeLabel, _orderSizeText),
            KvRow('状态', orderStatusLabel(status, limit: _isLimit), valueKey: const Key('p19.result.status')),
            if (o?.filledQty != null && o!.filledQty! > 0) KvRow('成交数量', '${fmtQty(o.filledQty!)} 股'),
            if (o?.avgPrice != null && o!.avgPrice! > 0) KvRow('成交均价', fmtUsd(o.avgPrice!), valueKey: const Key('p19.result.avgPrice')),
            if (o?.totalAmount != null && o!.totalAmount! > 0) KvRow('成交金额', fmtUsd(o.totalAmount!)),
          ],
        ),
      ),
      Notice(paper ? paperPriceNotice : demoPriceNotice, kind: NoticeKind.info),
    ], footer: [
      Expanded(
        child: AppButton(
          paper ? '查看模拟订单' : '查看订单',
          key: const Key('p19.orders'),
          kind: ButtonKind.ghost,
          onPressed: () => context.pushReplacement('/orders${paperQuery(paper)}'),
        ),
      ),
      Expanded(
        child: AppButton('完成', key: const Key('p19.done'), onPressed: () => context.canPop() ? context.pop() : context.go('/home')),
      ),
    ]);
  }
}
