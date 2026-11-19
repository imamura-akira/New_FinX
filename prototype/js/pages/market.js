'use strict';
/* P-09 市场、P-10 个股详情、P-19 下单、P-20 搜索、P-21 自选股、P-22 榜单详情 */

function sortedBy(type, dir = -1, list = DATA.instruments) { return list.filter((i) => !type || i.type === type).slice().sort((a, b) => dir * (Acc.chgPct(a) - Acc.chgPct(b))); }
function turnover(i) { const r = rng(i.symbol + 't'); return i.last * (2e5 + r() * 4e7); }
function bigNum(n) { return n >= 1e8 ? (n / 1e8).toFixed(2) + ' 亿' : n >= 1e4 ? (n / 1e4).toFixed(2) + ' 万' : fmt.int(Math.round(n)); }

/* ---------- P-09 市场 ---------- */
Pages.p09 = {
  render(p, ctx) {
    ctx.seg = ctx.seg || 'STOCK';
    ctx.ad = ctx.ad || 'day';
    ctx.etfCat = ctx.etfCat || '全部';
    let body = C.seg('seg', [['STOCK', '股票'], ['ETF', 'ETF']], ctx.seg, 'seg2');
    if (ctx.seg === 'STOCK') {
      const idx = ['SPY', 'QQQ', 'DIA'].map(Acc.inst);
      const ad = DATA.advDecline[ctx.ad];
      const max = Math.max(...ad);
      const bars = ad.map((v, k) => {
        const tone = k < 5 ? 'var(--down)' : k === 5 ? 'var(--faint)' : 'var(--up)';
        return `<div class="col" style="flex:1;align-items:center;gap:3px"><span class="xs num" style="color:${tone};font-size:10px">${v}</span><div style="width:60%;height:${Math.max(3, (v / max) * 90)}px;background:${tone};border-radius:3px 3px 0 0"></div><span class="faint" style="font-size:9px">${DATA.advDecline.labels[k]}</span></div>`;
      }).join('');
      const downN = ad.slice(0, 5).reduce((x, y) => x + y, 0), upN = ad.slice(6).reduce((x, y) => x + y, 0);
      body += `
        <div class="idx-grid">${idx.map((i) => `<button class="idx" data-go="#/p10?symbol=${i.symbol}"><div class="xs muted">${i.symbol}</div><div class="v num">${fmt.px(i.last)}</div>${C.chg(i)}</button>`).join('')}</div>
        <div class="sec-title"><span>涨跌分布</span>${C.seg('ad', [['day', '当日'], ['month', '近一月']], ctx.ad, 'seg')}</div>
        <div class="card"><div class="row" style="align-items:flex-end;gap:2px;height:130px">${bars}</div>
          <div class="row between xs mt8"><span class="down">下跌 ${fmt.int(downN)}</span><span class="up">上涨 ${fmt.int(upN)}</span></div></div>
        <div class="sec-title"><span>内部人增减持</span><button class="link" data-go="#/p22?type=insider">更多${Icon('right', 14)}</button></div>
        <div class="idx-grid">${DATA.insider.map((x) => `<button class="idx" data-go="#/p10?symbol=${x.symbol}"><div class="xs muted">${x.label}</div><div class="b mt8">${x.symbol}</div><div class="xs ${x.type === 'BUY' ? 'up' : x.type === 'SELL' ? 'down' : 'muted'}">${x.value}</div></button>`).join('')}</div>
        <div class="sec-title"><span>涨幅榜</span><button class="link" data-go="#/p22?type=gainers">更多${Icon('right', 14)}</button></div>
        <div class="card" style="padding:4px 16px">${sortedBy('STOCK').slice(0, 5).map((i) => C.qrow(i.symbol)).join('')}</div>
        <div class="sec-title"><span>跌幅榜</span><button class="link" data-go="#/p22?type=losers">更多${Icon('right', 14)}</button></div>
        <div class="card" style="padding:4px 16px">${sortedBy('STOCK', 1).slice(0, 3).map((i) => C.qrow(i.symbol)).join('')}</div>`;
    } else {
      const cats = ['全部', '大盘指数', '大宗商品', '债券', '行业', '海外市场'];
      const etfs = sortedBy('ETF').filter((i) => ctx.etfCat === '全部' || i.etfCategory === ctx.etfCat);
      body += `
        <div class="sec-title">今日热点</div>
        <div class="card"><div class="bubbles">${DATA.etfThemes.map(([t, sym], k) => {
          const i = Acc.inst(sym); const size = 70 + (k % 3) * 12;
          return `<button class="bubble ${clsOf(Acc.chg(i))}" style="width:${size}px;height:${size}px" data-go="#/p10?symbol=${sym}"><b>${t}</b><span class="xs muted">${sym}</span>${C.chg(i).replace('num', 'num xs')}</button>`;
        }).join('')}</div></div>
        <div class="sec-title"><span>ETF 排行</span><button class="link" data-go="#/p22?type=etf">更多${Icon('right', 14)}</button></div>
        ${C.seg('etfCat', cats.map((c) => [c, c]), ctx.etfCat)}
        <div class="card" style="padding:4px 16px"><table class="table"><tr><th>名称/代码</th><th>最新</th><th>涨跌幅</th><th>成交额</th></tr>
          ${etfs.map((i) => `<tr data-go="#/p10?symbol=${i.symbol}"><td><div class="b">${i.symbol}</div><div class="xs muted ellipsis" style="max-width:110px">${esc(i.name)}</div></td><td class="num">${fmt.px(i.last)}</td><td>${C.chg(i)}</td><td class="num small">${bigNum(turnover(i))}</td></tr>`).join('') || '<tr><td colspan="4" class="muted">暂无</td></tr>'}
        </table></div>`;
    }
    return { title: '市场', tab: 'market', right: `<button class="nav-btn" data-go="#/p20" aria-label="搜索">${Icon('search', 22)}</button>`, body: body + C.dataNote() };
  },
  actions: {
    seg(el, ctx) { ctx.seg = el.dataset.val; Router.refresh(); },
    ad(el, ctx) { ctx.ad = el.dataset.val; Router.refresh(); },
    etfCat(el, ctx) { ctx.etfCat = el.dataset.val; Router.refresh(); },
  },
};

/* ---------- P-10 个股详情 ---------- */
Pages.p10 = {
  backTo: '#/p09',
  render(p, ctx) {
    const i = Acc.inst(p.symbol);
    if (!i) return { title: '个股详情', body: C.empty('search', '该证券不在可交易清单内') };
    ctx.range = ctx.range || '1D';
    const q = Acc.quote(i.symbol);
    const ch = ChartCache.get(i.symbol, ctx.range);
    const s = Store.state;
    const inWl = s.watchlist.some((g) => g.symbols.includes(i.symbol));
    const pos = s.loggedIn && Acc.cur().status === 'ACTIVE' ? Acc.positions().find((x) => x.symbol === i.symbol) : null;
    const color = Acc.chg(i) >= 0 ? 'var(--up)' : 'var(--down)';
    return {
      title: `${i.symbol}`,
      right: `<button class="nav-btn" data-act="wl" aria-label="自选" style="color:${inWl ? 'var(--warn)' : 'inherit'}">${Icon('star', 20)}</button>`,
      body: `${C.restrict()}
        <div class="row between"><div><div class="b" style="font-size:18px">${esc(i.name)}</div><div class="xs muted">${i.symbol} · ${i.exchange} · ${i.type === 'ETF' ? 'ETF' : '股票'}</div></div>${i.isTradable ? '' : C.badge('暂不可交易', 'warn')}</div>
        <div class="row mt12" style="align-items:baseline;gap:10px"><span class="num b" style="font-size:32px">${fmt.px(i.last)}</span><span class="num ${clsOf(Acc.chg(i))}">${fmt.usd(Acc.chg(i), { sign: true }).replace('$', '')} ${fmt.pct(Acc.chgPct(i))}</span></div>
        <div class="xs muted">实时 · ${q.ts} ET · 演示数据</div>

        <div class="sec-title" style="font-size:15px"><span>报价${C.tag('13', 'PDF-5')}</span><span class="xs muted">NBBO · 全国最优买卖价</span></div>
        <div class="nbbo">
          <div><div class="lab">买一价（Bid）</div><div class="px num up">${fmt.px(q.bid)}</div><div class="xs muted num">${fmt.int(q.bidSize)} 股 · ${q.bidEx}</div></div>
          <div><div class="lab">卖一价（Ask）</div><div class="px num down">${fmt.px(q.ask)}</div><div class="xs muted num">${fmt.int(q.askSize)} 股 · ${q.askEx}</div></div>
        </div>
        <div class="card mt8" style="padding:10px 14px">${C.kv('最新成交（综合）', `<span class="num">${fmt.px(i.last)} × ${q.lastSize} · ${q.lastEx}</span>`)}${C.kv('成交量', `<span class="num">${fmt.int(q.volume)}</span>`)}</div>

        <div class="card" style="padding:12px 8px 8px">
          ${lineChart(ch.series, { h: 170, color, baseline: ctx.range === '1D' ? i.prev : null })}
          ${C.seg('range', [['1D', '分时'], ['1W', '1周'], ['1M', '1月'], ['3M', '3月'], ['1Y', '1年'], ['5Y', '5年']], ctx.range, 'seg fill')}
          <div class="xs faint" style="padding:0 8px">${ch.hit ? '命中缓存' : '已从服务端获取并缓存'} · 缓存时间 ${new Date(ch.at).toLocaleTimeString('zh-CN', { hour12: false })}${C.tag('14')}</div>
        </div>

        ${pos ? `<div class="sec-title" style="font-size:15px">我的持仓</div><div class="card">${C.kv('持有数量', fmt.qty(pos.qty) + ' 股')}${C.kv('成本价', fmt.usd(pos.avgCost))}${C.kv('市值', fmt.money(pos.mv))}${C.kv('持仓盈亏', `<span class="${clsOf(pos.pnl)}">${fmt.usd(pos.pnl, { sign: true })} (${fmt.pct(pos.pnlPct)})</span>`)}</div>` : ''}

        <div class="sec-title" style="font-size:15px">关键数据</div>
        <div class="card">${C.kv('昨收', fmt.px(i.prev))}${C.kv('市值', i.mcap)}${i.pe ? C.kv('市盈率 (TTM)', i.pe.toFixed(1)) : ''}${C.kv('52 周最高', fmt.px(i.last * 1.24))}${C.kv('52 周最低', fmt.px(i.last * 0.71))}</div>
        <div class="xs faint center">行情数据仅供参考，不构成投资建议。</div>`,
      footer: i.isTradable
        ? `<button class="btn sell" data-act="trade" data-side="SELL" ${pos ? '' : 'disabled'}>卖出</button><button class="btn buy" data-act="trade" data-side="BUY">买入</button>`
        : `<div class="small muted center grow">该证券仅提供行情展示，暂不支持交易</div>`,
    };
  },
  actions: {
    range(el, ctx) { ctx.range = el.dataset.val; Router.refresh(); },
    wl() {
      const sym = Router.current.params.symbol;
      const g = Store.state.watchlist;
      const inAny = g.some((x) => x.symbols.includes(sym));
      if (inAny) g.forEach((x) => { x.symbols = x.symbols.filter((y) => y !== sym); });
      else g[Acc.inst(sym).type === 'ETF' && g[1] ? 1 : 0].symbols.push(sym);
      Store.save(); UI.toast(inAny ? '已从自选移除' : '已加入自选'); Router.refresh();
    },
    trade(el) {
      const s = Store.state;
      const sym = Router.current.params.symbol;
      if (!s.loggedIn) return Router.go('#/p02?mode=login');
      const r = Acc.restriction();
      if (r && (el.dataset.side === 'BUY' ? r.noBuy : r.noSell)) return UI.alert(r.title, r.body);
      if (Acc.cur().status !== 'ACTIVE') {
        const ob = Onb.status();
        return UI.confirm({ title: '交易账户暂不可用', body: `${ob ? ob.title + '。' : ''}您可以先切换到模拟账户体验交易。`, ok: '切换到模拟账户', onOk: () => { s.mode = 'PAPER'; Store.save(); Router.go(`#/p19?symbol=${sym}&side=${el.dataset.side}`); } });
      }
      Router.hasHistory = true;
      Router.go(`#/p19?symbol=${sym}&side=${el.dataset.side}`);
    },
  },
};

/* ---------- P-19 下单 ---------- */
const DE_MINIMIS_USD = 1.00; // 剩余持仓价值阈值（示例，待确认）
Pages.p19 = {
  auth: true,
  render(p, ctx) {
    const i = Acc.inst(p.symbol);
    const a = Acc.cur();
    if (!i) return { title: '下单', body: C.empty('search', '证券不存在') };
    if (a.status !== 'ACTIVE') return notReady('交易');
    const f = ctx.form || (ctx.form = { side: p.side || 'BUY', orderType: 'MARKET', tif: 'DAY', qty: '', limitPrice: fmt.px(i.last).replace(/,/g, '') });
    const pos = Acc.positions().find((x) => x.symbol === i.symbol);
    if (p.all && pos && !ctx.prefilled) { f.qty = String(pos.qty); f.side = 'SELL'; ctx.prefilled = true; }
    if (ctx.step === 'confirm') return Pages.p19.confirm(i, ctx);
    if (ctx.step === 'done') return Pages.p19.done(i, ctx);
    const e = Pages.p19.calc(i, f, pos);
    ctx.calc = e;
    const r = Acc.restriction();
    if (r && (f.side === 'BUY' ? r.noBuy : r.noSell)) { e.ok = false; e.errs.push(f.side === 'BUY' ? `${r.title}：暂不能买入` : `${r.title}：暂不能交易`); }
    return {
      title: `${f.side === 'BUY' ? '买入' : '卖出'} ${i.symbol}`,
      body: `
        ${C.seg('side', [['BUY', '买入'], ['SELL', '卖出']], f.side, 'seg2')}
        <div class="card row between" style="padding:12px 14px"><div><div class="b">${i.symbol}</div><div class="xs muted">${esc(i.name)}</div></div>
          <div class="right small num"><div>买 <b class="up">${fmt.px(e.q.bid)}</b> × ${e.q.bidSize}</div><div>卖 <b class="down">${fmt.px(e.q.ask)}</b> × ${e.q.askSize}</div></div></div>
        ${C.field({ label: '订单类型', bind: 'orderType', value: f.orderType, options: [['MARKET', '市价单'], ['LIMIT', '限价单']] })}
        ${f.orderType === 'LIMIT' ? C.field({ label: '限价 (USD)', bind: 'limitPrice', value: f.limitPrice, type: 'text', attrs: 'inputmode="decimal"' }) : ''}
        <div class="field" data-field="qty"><label>数量（股，支持小数）</label>
          <div class="row"><input class="input grow" data-bind="qty" value="${esc(f.qty)}" inputmode="decimal" placeholder="0">${f.side === 'SELL' && pos ? `<button class="btn ghost sm" data-act="all">全部 ${fmt.qty(pos.qty)}</button>` : ''}</div>
          <div class="hint">${f.side === 'BUY' ? `购买力 ${fmt.usd(e.bp)}` : `可卖 ${pos ? fmt.qty(pos.qty) : 0} 股`}</div></div>
        ${f.orderType === 'LIMIT' ? C.field({ label: '有效期', bind: 'tif', value: f.tif, options: [['DAY', '当日有效'], ['GTC', '撤销前有效 (GTC)']] }) : ''}
        <div id="est">${Pages.p19.estHtml(e, f)}</div>`,
      footer: `<button class="btn ${f.side === 'BUY' ? 'buy' : 'sell'}" data-act="review" id="reviewBtn" ${e.ok ? '' : 'disabled'}>预览订单</button>`,
    };
  },
  calc(i, f, pos) {
    const q = Acc.quote(i.symbol);
    const qty = parseFloat(f.qty) || 0;
    const lp = parseFloat(String(f.limitPrice).replace(/,/g, '')) || 0;
    const px = f.orderType === 'LIMIT' ? lp : f.side === 'BUY' ? q.ask : q.bid;
    const fees = Acc.fees(f.side, qty, px);
    const feeTotal = sum(fees, (x) => x.amount);
    const notional = round2(qty * px);
    const total = f.side === 'BUY' ? notional + feeTotal : notional - feeTotal;
    const sm = Acc.summary();
    const errs = [];
    const warns = [];
    if (qty <= 0) errs.push('');
    if (f.orderType === 'LIMIT' && lp <= 0) errs.push('请输入有效的限价');
    if (f.side === 'BUY' && total > sm.buyingPower) errs.push('购买力不足');
    if (f.side === 'SELL' && (!pos || qty > pos.qty + 1e-9)) errs.push('卖出数量超过可卖数量');
    // 清单 10：卖出后剩余极小持仓
    let residual = null;
    if (f.side === 'SELL' && pos && qty > 0 && qty < pos.qty) {
      const rem = round4(pos.qty - qty);
      if (rem * px < DE_MINIMIS_USD) residual = rem;
    }
    // 清单 15：Good Faith Violation 风险（使用未结算资金买入）
    // 已结算且未被挂单占用的资金 = sm.withdrawable；超出部分即动用了未结算资金
    if (f.side === 'BUY' && Store.state.mode === 'LIVE' && qty > 0 && total > sm.withdrawable && total <= sm.buyingPower) warns.push('gfv');
    return { q, qty, px, fees, feeTotal, notional, total, errs, warns, residual, bp: sm.buyingPower, ok: errs.length === 0 };
  },
  estHtml(e, f) {
    return `<div class="card">
      ${C.kv(f.orderType === 'MARKET' ? '预估成交价' : '限价', fmt.usd(e.px))}
      ${C.kv('预估金额', fmt.usd(e.notional))}
      ${e.fees.map((x) => C.kv(x.name + (x.name === '佣金' ? C.tag('12') : ''), fmt.usd(x.amount))).join('')}
      <div class="hr"></div>${C.kv(`<b style="color:var(--text)">${f.side === 'BUY' ? '预估总支出' : '预估到账'}</b>`, `<b class="num">${fmt.usd(e.total)}</b>`)}
      ${f.orderType === 'MARKET' ? '<div class="xs faint">市价单按成交时市场价格执行，实际成交价可能与预估不同。</div>' : ''}
    </div>
    ${e.errs.filter(Boolean).map((x) => C.notice('danger', x)).join('')}
    ${e.residual != null ? C.notice('warn', `卖出后将剩余 ${fmt.qty(e.residual)} 股（价值不足 ${fmt.usd(DE_MINIMIS_USD)}），会形成极小剩余持仓。建议改为全部卖出。${C.tag('10')}<div class="mt8"><button class="btn ghost sm" data-act="all">改为全部卖出</button></div>`) : ''}
    ${e.warns.includes('gfv') ? C.notice('warn', `本次买入将使用<b>未结算资金</b>。若在该资金结算前卖出所买证券，可能构成 Good Faith Violation，多次违规将导致账户受限。${C.tag('15')}`) : ''}`;
  },
  confirm(i, ctx) {
    const f = ctx.form, e = ctx.calc;
    return {
      title: '确认订单',
      body: `<div class="card">
          <div class="row">${symAvatar(i.symbol)}<div><div class="b"><span class="${f.side === 'BUY' ? 'up' : 'down'}">${f.side === 'BUY' ? '买入' : '卖出'}</span> ${i.symbol}</div><div class="xs muted">${esc(i.name)}</div></div></div>
          <div class="hr"></div>
          ${C.kv('账户', `${Store.state.mode === 'LIVE' ? '实盘' : '模拟'} · ${esc(Acc.cur().accountNumber)}`)}
          ${C.kv('订单类型', f.orderType === 'MARKET' ? '市价单 · 当日有效' : `限价单 · ${f.tif === 'GTC' ? '撤销前有效' : '当日有效'}`)}
          ${C.kv('数量', fmt.qty(e.qty) + ' 股')}
          ${C.kv(f.orderType === 'MARKET' ? '预估价格' : '限价', fmt.usd(e.px))}
          ${C.kv('预估金额', fmt.usd(e.notional))}
          ${e.fees.map((x) => C.kv(x.name, fmt.usd(x.amount))).join('')}
          <div class="hr"></div>${C.kv('<b style="color:var(--text)">预估总计</b>', `<b>${fmt.usd(e.total)}</b>`)}
        </div>
        ${e.warns.includes('gfv') ? C.notice('warn', '提醒：本次买入使用未结算资金，结算前卖出可能构成 Good Faith Violation。') : ''}
        <div class="xs muted">提交即表示您确认上述订单信息。订单通过合作券商 DriveWealth 执行，成交后可在 文件 中查看交易确认书。</div>`,
      footer: `<button class="btn ghost" data-act="edit">返回修改</button><button class="btn ${f.side === 'BUY' ? 'buy' : 'sell'}" data-act="submit">确认${f.side === 'BUY' ? '买入' : '卖出'}</button>`,
    };
  },
  done(i, ctx) {
    const o = ctx.order;
    const [label, tone] = ORDER_STATUS[o.status];
    return {
      title: '订单已提交', noBack: true,
      body: `<div class="state" style="min-height:auto;padding-top:32px"><div class="state-ic">${Icon('check', 38)}</div><h2>订单已提交</h2><p>${o.status === 'FILLED' ? `已全部成交，成交均价 ${fmt.usd(o.avgFillPrice)}。` : '订单已进入市场，成交后会通知您。'}</p></div>
        <div class="card">${C.kv('订单号', o.orderId)}${C.kv('状态', C.badge(label, tone))}${C.kv('已成交', `${fmt.qty(o.filledQty)} / ${fmt.qty(o.qty)} 股`)}${C.kv('费用', fmt.usd(o.fees))}</div>`,
      footer: `<button class="btn ghost" data-go="#/p10?symbol=${i.symbol}">返回行情</button><button class="btn primary" data-go="#/p11?id=${o.orderId}">查看订单</button>`,
    };
  },
  onInput(el, ctx) {
    if (el.tagName === 'SELECT') return Router.refresh();
    const i = Acc.inst(Router.current.params.symbol);
    const pos = Acc.positions().find((x) => x.symbol === i.symbol);
    const e = Pages.p19.calc(i, ctx.form, pos);
    const r = Acc.restriction();
    if (r && (ctx.form.side === 'BUY' ? r.noBuy : r.noSell)) { e.ok = false; e.errs.push(`${r.title}：暂不能${ctx.form.side === 'BUY' ? '买入' : '交易'}`); }
    ctx.calc = e;
    $('#est').innerHTML = Pages.p19.estHtml(e, ctx.form);
    $('#reviewBtn').disabled = !e.ok;
  },
  actions: {
    side(el, ctx) { ctx.form.side = el.dataset.val; Router.refresh(); },
    all(el, ctx) { const pos = Acc.positions().find((x) => x.symbol === Router.current.params.symbol); if (pos) { ctx.form.qty = String(pos.qty); ctx.form.side = 'SELL'; } Router.refresh(); },
    review(el, ctx) { ctx.step = 'confirm'; Router.refresh(); },
    edit(el, ctx) { ctx.step = null; Router.refresh(); },
    submit(el, ctx) {
      const f = ctx.form;
      ctx.order = Acc.placeOrder({ symbol: Router.current.params.symbol, side: f.side, orderType: f.orderType, qty: ctx.calc.qty, limitPrice: ctx.calc.px, tif: f.orderType === 'MARKET' ? 'DAY' : f.tif });
      ctx.step = 'done'; Router.refresh();
    },
  },
};

/* ---------- P-20 搜索 ---------- */
Pages.p20 = {
  render(p, ctx) {
    ctx.q = ctx.q || '';
    return {
      title: '搜索',
      body: `<div class="row mb12"><input class="input grow" id="sq" data-bind="q" value="${esc(ctx.q)}" placeholder="输入代码或名称，如 AAPL" autocomplete="off" autocapitalize="characters"></div>
        <div id="sres">${Pages.p20.results(ctx.q)}</div>`,
    };
  },
  mount() { const el = $('#sq'); if (el) { el.focus(); el.setSelectionRange(el.value.length, el.value.length); } },
  results(q) {
    const s = Store.state;
    q = q.trim().toUpperCase();
    if (!q) {
      return `<div class="sec-title" style="font-size:15px">热门搜索</div><div class="row wrap gap8">${['NVDA', 'AAPL', 'TSLA', 'SPY', 'QQQ', 'GLD'].map((x) => `<button class="badge" style="height:30px;padding:0 12px" data-go="#/p10?symbol=${x}">${x}</button>`).join('')}</div>
        <div class="xs faint mt24">仅展示本平台证券主清单中的证券。${C.tag('23')}</div>`;
    }
    const res = DATA.instruments.filter((i) => i.symbol.startsWith(q) || i.name.toUpperCase().includes(q));
    const blocked = DATA.blocked.find((b) => b.symbol === q);
    return `${blocked ? C.notice('warn', `<b>${esc(blocked.symbol)}</b>：${esc(blocked.reason)}。${C.tag('23')}`) : ''}
      ${res.length ? `<div class="card" style="padding:4px 16px">${res.map((i) => {
        const inWl = s.watchlist.some((g) => g.symbols.includes(i.symbol));
        return `<div class="qrow"><button class="row grow" style="text-align:left" data-go="#/p10?symbol=${i.symbol}">${symAvatar(i.symbol)}<div class="grow"><div class="sym">${i.symbol} <span class="xs muted">${i.exchange}</span></div><div class="xs muted ellipsis">${esc(i.name)}</div></div></button>
          <button class="nav-btn" data-act="addWl" data-sym="${i.symbol}" style="color:${inWl ? 'var(--warn)' : 'var(--faint)'}" aria-label="加入自选">${Icon(inWl ? 'star' : 'plus', 20)}</button></div>`;
      }).join('')}</div>` : blocked ? '' : C.empty('search', '没有找到匹配的证券')}`;
  },
  onInput(el, ctx) { ctx.q = el.value; $('#sres').innerHTML = Pages.p20.results(ctx.q); },
  actions: {
    addWl(el, ctx) {
      const sym = el.dataset.sym; const g = Store.state.watchlist;
      if (g.some((x) => x.symbols.includes(sym))) return UI.toast('已在自选中');
      g[Acc.inst(sym).type === 'ETF' && g[1] ? 1 : 0].symbols.push(sym); Store.save();
      UI.toast(`已将 ${sym} 加入自选`); $('#sres').innerHTML = Pages.p20.results(ctx.q);
    },
  },
};

/* ---------- P-21 自选股 ---------- */
Pages.p21 = {
  render(p, ctx) {
    const g = Store.state.watchlist;
    ctx.gid = ctx.gid || g[0].id;
    const grp = g.find((x) => x.id === ctx.gid) || g[0];
    ctx.sort = ctx.sort || 'none';
    let syms = grp.symbols.slice();
    if (ctx.sort !== 'none') syms.sort((a, b) => (ctx.sort === 'desc' ? -1 : 1) * (Acc.chgPct(Acc.inst(a)) - Acc.chgPct(Acc.inst(b))));
    return {
      title: '自选股',
      right: `<button class="link-btn" style="padding:0 10px" data-act="edit">${ctx.edit ? '完成' : '编辑'}</button>`,
      body: `<div class="row"><div class="grow">${C.seg('gid', g.map((x) => [x.id, x.name]), grp.id)}</div><button class="nav-btn" data-act="addGroup" aria-label="新建分组">${Icon('plus', 18)}</button></div>
        <div class="row between xs muted mb8"><span>${syms.length} 只</span><button class="link-btn xs" data-act="sort">涨跌幅 ${ctx.sort === 'desc' ? '↓' : ctx.sort === 'asc' ? '↑' : '⇅'}</button></div>
        <div class="card" style="padding:4px 16px">${syms.length ? syms.map((sym) => ctx.edit
          ? `<div class="qrow">${symAvatar(sym)}<div class="grow"><div class="sym">${sym}</div><div class="xs muted">${esc(Acc.inst(sym).name)}</div></div><button class="nav-btn" data-act="up" data-sym="${sym}" aria-label="上移">${Icon('up', 18)}</button><button class="nav-btn" data-act="rm" data-sym="${sym}" style="color:var(--danger)" aria-label="删除">${Icon('trash', 18)}</button></div>`
          : C.qrow(sym)).join('') : C.empty('star', '此分组还没有股票')}</div>
        <button class="btn secondary" data-go="#/p20">${Icon('plus', 18)} 添加股票</button>
        ${ctx.edit && g.length > 1 ? `<button class="btn ghost mt12" data-act="delGroup">删除分组「${esc(grp.name)}」</button>` : ''}`,
    };
  },
  actions: {
    gid(el, ctx) { ctx.gid = el.dataset.val; Router.refresh(); },
    edit(el, ctx) { ctx.edit = !ctx.edit; Router.refresh(); },
    sort(el, ctx) { ctx.sort = { none: 'desc', desc: 'asc', asc: 'none' }[ctx.sort]; Router.refresh(); },
    rm(el, ctx) { const grp = Store.state.watchlist.find((x) => x.id === ctx.gid); grp.symbols = grp.symbols.filter((s) => s !== el.dataset.sym); Store.save(); Router.refresh(); },
    up(el, ctx) { const grp = Store.state.watchlist.find((x) => x.id === ctx.gid); const k = grp.symbols.indexOf(el.dataset.sym); if (k > 0) { [grp.symbols[k - 1], grp.symbols[k]] = [grp.symbols[k], grp.symbols[k - 1]]; Store.save(); Router.refresh(); } },
    addGroup(el, ctx) {
      UI.sheet('新建分组', `${C.field({ label: '分组名称', bind: 'gname', placeholder: '如：科技股' })}<button class="btn primary" data-act="saveGroup">创建</button>`);
    },
    saveGroup(el, ctx) {
      const name = (ctx.form?.gname || '').trim(); if (!name) return UI.toast('请输入分组名称');
      const id = 'g' + Date.now(); Store.state.watchlist.push({ id, name, symbols: [] }); Store.save(); ctx.form.gname = ''; ctx.gid = id; UI.close(); Router.refresh();
    },
    delGroup(el, ctx) {
      UI.confirm({ title: '删除分组？', body: '分组内的自选股将一并移除。', ok: '删除', danger: true, onOk: () => { Store.state.watchlist = Store.state.watchlist.filter((x) => x.id !== ctx.gid); ctx.gid = null; ctx.edit = false; Store.save(); Router.refresh(); } });
    },
  },
};

/* ---------- P-22 榜单详情 ---------- */
Pages.p22 = {
  backTo: '#/p09',
  render(p, ctx) {
    const type = ctx.type || p.type || 'gainers';
    ctx.type = type;
    const tabs = [['gainers', '涨幅榜'], ['losers', '跌幅榜'], ['etf', 'ETF 排行'], ['insider', '内部人增减持']];
    let body = C.seg('type', tabs, type);
    if (type === 'insider') {
      const rows = DATA.instruments.filter((i) => i.type === 'STOCK').map((i) => { const r = rng(i.symbol + 'ins'); return { i, net: (r() - 0.45) * 3e8, n: 1 + Math.floor(r() * 20) }; }).sort((a, b) => b.net - a.net);
      body += `<div class="card" style="padding:4px 16px"><table class="table"><tr><th>代码</th><th>净增减持</th><th>交易次数</th></tr>
        ${rows.map((x) => `<tr data-go="#/p10?symbol=${x.i.symbol}"><td><div class="b">${x.i.symbol}</div><div class="xs muted ellipsis" style="max-width:120px">${esc(x.i.name)}</div></td><td class="num ${clsOf(x.net)}">${x.net > 0 ? '+' : '-'}$${bigNum(Math.abs(x.net))}</td><td class="num">${x.n}</td></tr>`).join('')}</table></div>
        <div class="xs faint">数据来源：公开的内部人交易申报（演示数据）。</div>`;
    } else {
      const list = type === 'etf' ? sortedBy('ETF') : sortedBy('STOCK', type === 'losers' ? 1 : -1);
      ctx.sortBy = ctx.sortBy || 'chg';
      const sorted = ctx.sortBy === 'turnover' ? list.slice().sort((a, b) => turnover(b) - turnover(a)) : list;
      body += `<div class="card" style="padding:4px 16px"><table class="table"><tr><th>名称/代码</th><th>最新</th><th class="sortable" data-act="sortBy" data-val="chg">涨跌幅${ctx.sortBy === 'chg' ? ' ▾' : ''}</th><th class="sortable" data-act="sortBy" data-val="turnover">成交额${ctx.sortBy === 'turnover' ? ' ▾' : ''}</th></tr>
        ${sorted.map((i) => `<tr data-go="#/p10?symbol=${i.symbol}"><td><div class="b">${i.symbol}</div><div class="xs muted ellipsis" style="max-width:100px">${esc(i.name)}</div></td><td class="num">${fmt.px(i.last)}</td><td>${C.chg(i)}</td><td class="num small">${bigNum(turnover(i))}</td></tr>`).join('')}</table></div>`;
    }
    return { title: '榜单', body: body + `<div class="xs faint center mt8">仅包含证券主清单中的证券${C.tag('23')} · 演示数据${C.tag('13')}</div>` };
  },
  actions: {
    type(el, ctx) { ctx.type = el.dataset.val; Router.refresh(); },
    sortBy(el, ctx) { ctx.sortBy = el.dataset.val; Router.refresh(); },
  },
};
