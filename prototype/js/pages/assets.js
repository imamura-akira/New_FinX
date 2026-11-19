'use strict';
/* P-07 资产首页、P-08 账户抽屉路由、P-11 订单列表、P-12 持仓 */

const ORDER_STATUS = {
  NEW: ['待成交', 'info'], PARTIALLY_FILLED: ['部分成交', 'warn'], FILLED: ['已成交', 'ok'],
  CANCELED: ['已取消', ''], REJECTED: ['已拒绝', 'danger'], PENDING_CANCEL: ['取消中', 'warn'],
};
const ORDER_TYPE = { MARKET: '市价', LIMIT: '限价', STOP: '止损' };

function allocBlock(sm) {
  const parts = [{ k: 'cash', l: '现金', v: sm.cash, color: ALLOC_COLORS.cash }, { k: 'stock', l: '股票', v: sm.stock, color: ALLOC_COLORS.stock }, { k: 'etf', l: 'ETF', v: sm.etf, color: ALLOC_COLORS.etf }];
  const total = sm.total || 1;
  return `<div class="card row" style="gap:18px">
    ${donut(parts, 124, `<div><div class="b num">${fmt.money(sm.total)}</div><div class="xs muted">总资产</div></div>`)}
    <div class="grow">${parts.map((p) => `<div class="row between small" style="padding:6px 0"><span class="row" style="gap:6px"><i style="width:8px;height:8px;border-radius:50%;background:${p.color};display:inline-block"></i>${p.l}</span><span class="num right"><div>${fmt.money(p.v)}</div><div class="xs muted">${fmt.pct(p.v / total, { sign: false, dp: 1 })}</div></span></div>`).join('')}</div>
  </div>`;
}

/* ---------- P-07 资产首页 ---------- */
Pages.p07 = {
  render(p, ctx) {
    const s = Store.state;
    ctx.range = ctx.range || '1D';
    const a = Acc.cur();
    const usable = s.loggedIn && a.status === 'ACTIVE';
    const hide = s.prefs.hideBalances;
    const out = { title: '资产', tab: 'assets' };

    // 状态 1：未登录
    if (!s.loggedIn) {
      out.body = `<div class="card center" style="padding:32px 20px;margin-top:40px">
          <div class="state-ic" style="margin:0 auto 16px">${Icon('lock', 34)}</div>
          <div class="b" style="font-size:18px">请先登录</div>
          <div class="small muted mt8">登录后即可查看资产、持仓与订单。</div>
          <button class="btn primary mt24" data-go="#/p02?mode=login">登录</button>
        </div>
        <div class="row"><button class="btn ghost grow" data-go="#/p09">先看看行情</button><button class="btn ghost grow" data-act="tryPaper">模拟交易</button></div>`;
      return out;
    }

    // 状态 2：实盘未开户 / 开户中
    if (!usable) {
      const ob = Onb.status() || { title: '交易账户暂不可用', sub: '', go: '#/p06', icon: 'info' };
      const border = ob.tone === 'warn' ? 'var(--warn)' : 'var(--primary-weak)';
      const cta = `<button class="card row" style="width:100%;text-align:left;border:1.5px solid ${border}" data-go="${ob.go}"><span class="li-ic" ${ob.tone === 'warn' ? 'style="color:var(--warn)"' : ''}>${Icon(ob.icon, 18)}</span><span class="grow"><div class="b">${ob.title}</div><div class="xs muted">${ob.sub}</div></span>${Icon('right', 16, 'chev')}</button>`;
      out.body = `<div class="hero"><div class="row small muted">总资产</div><div class="hero-total">—</div><div class="hero-split"><div><div class="muted">购买力</div><div>—</div></div><div><div class="muted">今日盈亏</div><div>—</div></div></div></div>
        ${cta}
        <div class="row"><button class="btn ghost grow" data-go="#/p09">先看看行情</button><button class="btn ghost grow" data-act="tryPaper">切换到模拟账户</button></div>
        ${watchlistBlock()}`;
      return out;
    }

    // 状态 3：已开户
    const sm = Acc.summary(a);
    let series = genSeries(a.accountNumber + ctx.range, RANGE_POINTS[ctx.range === 'YTD' ? 'YTD' : ctx.range] || 40, sm.total, ctx.range === '1D' ? 0.002 : 0.01);
    if (ctx.range === '1D') { // 让分时起点等于昨日总资产，走势方向与今日盈亏一致
      const d0 = series[0] - (sm.total - sm.dayPnl);
      series = series.map((v, k) => v - d0 * (1 - k / (series.length - 1)));
    }
    const open = Acc.openOrders(a);
    out.body = `${C.restrict()}
      <div class="hero">
        <div class="row small muted" style="gap:6px">${Store.state.mode === 'LIVE' ? '实盘' : '模拟'} · 总资产 (USD)<button data-act="toggleHide" aria-label="隐藏金额" style="color:#fff">${Icon(hide ? 'eyeoff' : 'eye', 16)}</button>${C.tag('16')}</div>
        <div class="hero-total num">${fmt.money(sm.total)}</div>
        <div class="hero-split num"><div><div class="muted">购买力</div><div>${fmt.money(sm.buyingPower)}</div></div><div><div class="muted">今日盈亏</div><div>${hide ? '****' : `${fmt.usd(sm.dayPnl, { sign: true })} ${fmt.pct(sm.dayPnlPct)}`}</div></div></div>
        <div class="hero-chart">${lineChart(series, { h: 90, color: '#fff', fill: true })}</div>
      </div>
      ${C.seg('range', [['1D', '1日'], ['1W', '1周'], ['3M', '3月'], ['1Y', '1年'], ['YTD', '今年']], ctx.range, 'seg fill')}
      ${Store.state.mode === 'LIVE' && a.positions.length === 0 && a.cash === 0 ? `<div class="card row"><span class="li-ic">${Icon('down', 18)}</span><div class="grow"><div class="b">入金开始投资</div><div class="xs muted">${Fund.linked().length ? '从已绑定的银行账户转入资金' : '绑定本人美国银行账户（ACH）或通过电汇入金'}</div></div><button class="btn primary sm" data-go="#/p13">入金</button></div>` : ''}
      <button class="card row" style="width:100%;text-align:left;background:var(--info-weak)" data-go="#/p28"><span class="li-ic" style="background:#fff">${Icon('swap', 18)}</span><span class="grow"><div class="b small">从其他券商转入持仓</div><div class="xs muted">通过 ACATS 转入股票和现金，无需先卖出</div></span>${Icon('right', 16, 'chev')}</button>

      <div class="sec-title"><span>待处理订单 ${C.badge(String(open.length), open.length ? 'info' : '')}${C.tag('9')}</span><button class="link" data-go="#/p11?status=OPEN">全部订单${Icon('right', 14)}</button></div>
      <div class="card" style="padding:4px 16px">
        ${open.length ? open.slice(0, 3).map(orderRowMini).join('') : '<div class="small muted" style="padding:12px 0">当前没有待处理订单。</div>'}
        <button class="link-btn xs" style="padding:8px 0" data-act="refreshOrders">${Icon('refresh', 12)} 刷新</button>
      </div>

      <div class="sec-title"><span>持仓</span><button class="link" data-go="#/p12">查看全部${Icon('right', 14)}</button></div>
      ${allocBlock(sm)}

      <div class="sec-title"><span>智能组合</span>${C.badge('首期不做 · 待合规评估', 'warn')}</div>
      <button class="card" style="width:100%;text-align:left" data-go="#/p25">
        <div class="row"><span class="li-ic">${Icon('pie', 18)}</span><div class="grow"><div class="b">不知道买什么？回答 10 个问题</div><div class="xs muted">根据您的目标与风险偏好生成组合建议</div></div>${Icon('right', 16, 'chev')}</div>
        <div class="row mt12 xs muted" style="gap:6px">${['问卷', '匹配', '一键加入'].map((t, i) => `<span class="badge">${i + 1} · ${t}</span>`).join('')}</div>
      </button>
      ${watchlistBlock()}`;
    return out;
  },
  actions: {
    range(el, ctx) { ctx.range = el.dataset.val; Router.refresh(); },
    refreshOrders() { UI.toast('订单状态已刷新'); Router.refresh(); },
    tryPaper() {
      const s = Store.state;
      if (!s.loggedIn) { UI.toast('请先登录后使用模拟交易'); return Router.go('#/p02?mode=login'); }
      s.mode = 'PAPER'; Store.save(); UI.toast('已切换到模拟账户'); Router.refresh();
    },
  },
};
function orderRowMini(o) {
  const [label, tone] = ORDER_STATUS[o.status];
  return `<button class="qrow" data-go="#/p11?id=${o.orderId}"><div class="grow"><div class="b">${o.side === 'BUY' ? '买入' : '卖出'} ${o.symbol}</div><div class="xs muted">${ORDER_TYPE[o.orderType]} ${o.limitPrice ? '@ ' + fmt.px(o.limitPrice) : ''} · ${fmt.qty(o.filledQty)}/${fmt.qty(o.qty)} 股</div></div>${C.badge(label, tone)}</button>`;
}
function watchlistBlock() {
  const g = Store.state.watchlist[0];
  return `<div class="sec-title"><span>自选股</span><button class="link" data-go="#/p21">管理${Icon('right', 14)}</button></div>
    <div class="card" style="padding:4px 16px">${g.symbols.length ? g.symbols.map((sym) => C.qrow(sym)).join('') : C.empty('star', '此分组还没有股票', '<button class="btn secondary sm" data-go="#/p20">+ 添加股票</button>')}</div>`;
}

/* ---------- P-08：直接访问时在资产页上打开抽屉 ---------- */
Pages.p08 = {
  render(p, ctx) { const out = Pages.p07.render(p, ctx); return out; },
  mount() { history.replaceState(null, '', '#/p07'); Router.current.id = 'p07'; Router.current.page = Pages.p07; Drawer.open(); },
  actions: Pages.p07.actions,
};

/* ---------- P-11 订单列表 ---------- */
Pages.p11 = {
  auth: true,
  render(p, ctx) {
    const a = Acc.cur();
    if (a.status !== 'ACTIVE') return notReady('订单');
    if (p.id) return Pages.p11.detail(a, p.id);
    ctx.filter = ctx.filter || p.status || 'ALL';
    const f = ctx.filter;
    const list = a.orders.filter((o) => f === 'ALL' || (f === 'OPEN' ? (o.status === 'NEW' || o.status === 'PARTIALLY_FILLED') : o.status === f));
    return {
      title: '订单',
      body: `${C.seg('filter', [['ALL', '全部'], ['OPEN', '待处理'], ['PARTIALLY_FILLED', '部分成交'], ['FILLED', '已成交'], ['CANCELED', '已取消'], ['REJECTED', '已拒绝']], f)}
        ${list.length ? list.map(orderCard).join('') : C.empty('doc', '暂无订单')}
        <div class="xs faint center">${C.tag('9', '11')}</div>`,
    };
  },
  detail(a, id) {
    const o = a.orders.find((x) => x.orderId === id);
    if (!o) return { title: '订单详情', body: C.empty('doc', '订单不存在') };
    const [label, tone] = ORDER_STATUS[o.status];
    const remaining = o.qty - o.filledQty;
    const canCancel = o.status === 'NEW' || o.status === 'PARTIALLY_FILLED';
    return {
      title: '订单详情',
      body: `<div class="card">
          <div class="row between"><div class="row">${symAvatar(o.symbol)}<div><div class="b">${o.side === 'BUY' ? '买入' : '卖出'} ${o.symbol}</div><div class="xs muted">${o.orderId}</div></div></div>${C.badge(label, tone)}</div>
          <div class="hr"></div>
          ${C.kv('订单类型', `${ORDER_TYPE[o.orderType]} · ${o.tif === 'GTC' ? '撤销前有效' : '当日有效'}`)}
          ${o.limitPrice ? C.kv('限价', fmt.usd(o.limitPrice)) : ''}
          ${C.kv('委托数量', fmt.qty(o.qty) + ' 股')}
          ${C.kv('已成交' + C.tag('11'), `<b>${fmt.qty(o.filledQty)}</b> 股`)}
          ${C.kv('未成交', fmt.qty(remaining) + ' 股' + (o.status === 'CANCELED' && o.filledQty > 0 ? '（已取消）' : ''))}
          ${C.kv('成交均价', o.avgFillPrice ? fmt.usd(o.avgFillPrice) : '—')}
          ${C.kv('佣金及费用' + C.tag('12'), fmt.usd(o.fees || 0))}
          ${C.kv('下单时间', fmt.dt(o.createdAt))}
        </div>
        ${o.cancelReason ? C.notice(o.cancelReason.includes('公司行动') ? 'warn' : 'info', `<b>取消原因：</b>${esc(o.cancelReason)}${o.cancelReason.includes('公司行动') ? C.tag('18') : ''}`) : ''}
        ${o.rejectReason ? C.notice('danger', `<b>拒绝原因：</b>${esc(o.rejectReason)}`) : ''}
        ${o.fills.length ? `<div class="sec-title">成交明细</div><div class="card" style="padding:4px 16px"><table class="table"><tr><th>时间</th><th>数量</th><th>价格</th></tr>${o.fills.map((f) => `<tr><td>${f.time}</td><td class="num">${fmt.qty(f.qty)}</td><td class="num">${fmt.usd(f.price)}</td></tr>`).join('')}</table></div>` : ''}`,
      footer: canCancel ? `<button class="btn ghost" data-go="#/p10?symbol=${o.symbol}">查看行情</button><button class="btn danger" data-act="cancel" data-id="${o.orderId}">取消订单</button>` : `<button class="btn ghost" data-go="#/p10?symbol=${o.symbol}">查看 ${o.symbol} 行情</button>`,
    };
  },
  actions: {
    filter(el, ctx) { ctx.filter = el.dataset.val; Router.refresh(); },
    cancel(el) {
      const a = Acc.cur();
      const o = a.orders.find((x) => x.orderId === el.dataset.id);
      const rem = o.qty - o.filledQty;
      UI.confirm({
        title: '取消订单？',
        body: `${o.side === 'BUY' ? '买入' : '卖出'} ${o.symbol}，未成交 ${fmt.qty(rem)} 股将被取消。${o.filledQty ? `已成交的 ${fmt.qty(o.filledQty)} 股不受影响。` : ''}`,
        ok: '取消订单', danger: true,
        onOk: () => {
          o.status = 'PENDING_CANCEL'; Router.refresh();
          setTimeout(() => { o.status = 'CANCELED'; o.cancelReason = '用户主动取消'; Store.save(); UI.toast('订单已取消'); Router.refresh(); }, 900);
        },
      });
    },
  },
};
function orderCard(o) {
  const [label, tone] = ORDER_STATUS[o.status];
  const canCancel = o.status === 'NEW' || o.status === 'PARTIALLY_FILLED';
  const pct = o.qty ? o.filledQty / o.qty : 0;
  return `<div class="card">
    <button class="row between" style="width:100%;text-align:left" data-go="#/p11?id=${o.orderId}">
      <div class="row">${symAvatar(o.symbol)}<div><div class="b"><span class="${o.side === 'BUY' ? 'up' : 'down'}">${o.side === 'BUY' ? '买入' : '卖出'}</span> ${o.symbol}</div><div class="xs muted">${ORDER_TYPE[o.orderType]}${o.limitPrice ? ' @ ' + fmt.px(o.limitPrice) : ''} · ${fmt.dt(o.createdAt)}</div></div></div>
      ${C.badge(label, tone)}
    </button>
    <div class="row between small mt12"><span class="muted">已成交 / 委托</span><span class="num"><b>${fmt.qty(o.filledQty)}</b> / ${fmt.qty(o.qty)} 股${o.avgFillPrice ? ` · 均价 ${fmt.px(o.avgFillPrice)}` : ''}</span></div>
    ${o.status === 'PARTIALLY_FILLED' || (o.status === 'CANCELED' && o.filledQty) ? `<div class="progress mt8"><i style="width:${pct * 100}%"></i></div>` : ''}
    ${o.cancelReason ? `<div class="xs muted mt8">${esc(o.cancelReason)}</div>` : ''}${o.rejectReason ? `<div class="xs down mt8">${esc(o.rejectReason)}</div>` : ''}
    ${canCancel ? `<div class="row mt12" style="justify-content:flex-end"><button class="btn ghost sm" data-act="cancel" data-id="${o.orderId}">取消订单</button></div>` : ''}
  </div>`;
}
function notReady(what) {
  const s = Store.state;
  const ob = Onb.status();
  return {
    title: what,
    body: `<div class="state"><div class="state-ic">${Icon('lock', 34)}</div><h2>交易账户暂不可用</h2><p>${ob ? `${ob.title}。${s.accountStatus === 'NONE' || s.accountStatus === 'DRAFT' ? `开通实盘账户后即可使用${what}，或切换到模拟账户体验。` : ob.sub}` : ''}</p>
      <div class="col gap8 mt24" style="width:100%">${ob ? `<button class="btn primary" data-go="${ob.go}">${ob.cta}</button>` : ''}<button class="btn ghost" data-act="setMode" data-val="PAPER">切换到模拟账户</button></div></div>`,
  };
}

/* ---------- P-12 持仓 ---------- */
Pages.p12 = {
  auth: true,
  render(p, ctx) {
    const a = Acc.cur();
    if (a.status !== 'ACTIVE') return notReady('持仓');
    ctx.f = ctx.f || 'ALL';
    const sm = Acc.summary(a);
    const ps = sm.ps.filter((x) => ctx.f === 'ALL' || x.inst.type === ctx.f);
    const tiny = sm.ps.filter((x) => x.deMinimis);
    return {
      title: '持仓',
      right: `<button class="nav-btn" data-go="#/p20" aria-label="搜索">${Icon('search', 20)}</button>`,
      body: `<div class="row between mb12"><div><div class="xs muted">持仓市值 · USD${C.tag('16')}</div><div class="b num" style="font-size:24px">${fmt.money(sm.mv)}</div></div>
          <div class="right"><div class="xs muted">持仓盈亏</div><div class="b num ${clsOf(sm.pnl)}" style="font-size:20px">${Store.state.prefs.hideBalances ? '****' : fmt.usd(sm.pnl, { sign: true })}</div></div></div>
        ${C.seg('f', [['ALL', '全部'], ['STOCK', '股票'], ['ETF', 'ETF']], ctx.f, 'seg2')}
        ${allocBlock(sm)}
        ${tiny.length ? C.notice('warn', `您有 ${tiny.length} 笔价值不足 $1 的零碎剩余持仓（${tiny.map((t) => `${t.symbol} ${fmt.qty(t.qty)} 股`).join('、')}）。可一次性全部卖出，避免长期留存极小持仓。${C.tag('10')}<div class="mt8">${tiny.map((t) => `<button class="btn ghost sm" data-go="#/p19?symbol=${t.symbol}&side=SELL&all=1">全部卖出 ${t.symbol}</button>`).join(' ')}</div>`) : ''}
        <div class="card" style="padding:6px 16px">
          ${ps.length ? `<table class="table"><tr><th>名称/代码</th><th>市值/数量</th><th>成本价</th><th>持仓盈亏</th></tr>
          ${ps.map((x) => `<tr data-go="#/p10?symbol=${x.symbol}"><td><div class="b">${x.symbol}</div><div class="xs muted ellipsis" style="max-width:90px">${esc(x.inst.name)}</div></td>
            <td class="num"><div>${fmt.money(x.mv)}</div><div class="xs muted">${fmt.qty(x.qty)}</div></td>
            <td class="num">${fmt.px(x.avgCost)}</td>
            <td class="num ${clsOf(x.pnl)}"><div>${Store.state.prefs.hideBalances ? '****' : fmt.usd(x.pnl, { sign: true })}</div><div class="xs">${fmt.pct(x.pnlPct)}</div></td></tr>`).join('')}</table>`
            : C.empty('pie', '暂无持仓', '<button class="btn secondary sm" data-go="#/p09">去看看行情</button>')}
        </div>
        <div class="xs faint center">公司行动（如拆股）导致的持仓数量变化可在 历史记录 中查看。${C.tag('18')}</div>`,
    };
  },
  actions: { f(el, ctx) { ctx.f = el.dataset.val; Router.refresh(); } },
};
