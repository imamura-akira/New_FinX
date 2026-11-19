'use strict';
/* 框架：工具函数、状态、账户计算、路由、通用组件、图表、全局操作 */

const APP_NAME = '示例券商'; // 占位名称，品牌待定
const DW_DISCLOSURE_URL = 'https://apps.drivewealth.com/disclosures';

/* ---------- Utils ---------- */
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const round2 = (n) => Math.round(n * 100) / 100;
const ceilCent = (n) => (n > 0 ? Math.max(0.01, Math.ceil(n * 100 - 1e-9) / 100) : 0);
const sum = (arr, f = (x) => x) => arr.reduce((a, x) => a + f(x), 0);
const clsOf = (n) => (n > 0 ? 'up' : n < 0 ? 'down' : 'flat');

const fmt = {
  usd(n, { sign = false, dp = 2 } = {}) {
    if (n == null || isNaN(n)) return '—';
    const s = Math.abs(n).toLocaleString('en-US', { minimumFractionDigits: dp, maximumFractionDigits: dp });
    return `${n < 0 ? '-' : sign && n > 0 ? '+' : ''}$${s}`;
  },
  px(n) { return n == null ? '—' : n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: n < 1 ? 4 : 2 }); },
  pct(n, { sign = true, dp = 2 } = {}) {
    if (n == null || isNaN(n)) return '—';
    return `${n < 0 ? '-' : sign && n > 0 ? '+' : ''}${Math.abs(n * 100).toFixed(dp)}%`;
  },
  qty(n) { return n == null ? '—' : Number(n.toFixed(4)).toLocaleString('en-US', { maximumFractionDigits: 4 }); },
  int(n) { return n.toLocaleString('en-US'); },
  money(n) { return Store.state.prefs.hideBalances ? '****' : fmt.usd(n); },
  dt(iso) { return iso ? iso.replace('T', ' ').slice(0, 16) : '—'; },
};

function hashStr(s) { let h = 2166136261; for (const c of String(s)) { h ^= c.charCodeAt(0); h = Math.imul(h, 16777619); } return h >>> 0; }
function rng(seed) { let s = hashStr(seed) || 1; return () => { s = (Math.imul(s, 1664525) + 1013904223) >>> 0; return s / 4294967296; }; }
function hue(s) { return hashStr(s) % 360; }
function symAvatar(sym, extra = '') { return `<div class="ava sq ${extra}" style="background:hsl(${hue(sym)},38%,42%)">${esc(sym.slice(0, 4))}</div>`; }
function nameAvatar(name, extra = '') { return `<div class="ava ${extra}" style="background:hsl(${hue(name)},35%,48%)">${esc(name.slice(0, 1))}</div>`; }

/* ---------- Icons（自绘线性图标） ---------- */
const ICONS = {
  home: '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/>',
  market: '<path d="M3 17l6-6 4 4 8-8"/><path d="M15 7h6v6"/>',
  building: '<rect x="4" y="3" width="16" height="18" rx="1"/><path d="M9 7h1M14 7h1M9 11h1M14 11h1M9 15h1M14 15h1"/>',
  spark: '<path d="M12 3l2 5 5 2-5 2-2 5-2-5-5-2 5-2z"/>',
  gift: '<rect x="3" y="8" width="18" height="13" rx="1"/><path d="M12 8v13M3 12h18"/><path d="M12 8C10 4 6 4 6 6.5S12 8 12 8s6 0 6-1.5S14 4 12 8"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4-6 8-6s7 2 8 6"/>',
  bell: '<path d="M6 16v-5a6 6 0 0112 0v5l2 2H4z"/><path d="M10 20a2 2 0 004 0"/>',
  doc: '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4M9 12h6M9 16h6"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9L7 7M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 015 0c0 2-2.5 2-2.5 4M12 17h.01"/>',
  logout: '<path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10"/>',
  down: '<circle cx="12" cy="12" r="9"/><path d="M12 7v9M8 12l4 4 4-4"/>',
  up: '<circle cx="12" cy="12" r="9"/><path d="M12 17V8M8 12l4-4 4 4"/>',
  swap: '<path d="M4 8h14l-3-3M20 16H6l3 3"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/>',
  check: '<path d="M5 12l5 5 9-10"/>',
  right: '<path d="M9 6l6 6-6 6"/>',
  left: '<path d="M15 6l-6 6 6 6"/>',
  x: '<path d="M6 6l12 12M18 6L6 18"/>',
  eye: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
  eyeoff: '<path d="M3 3l18 18"/><path d="M10.6 6.1A10 10 0 0112 6c6 0 10 6 10 6a17 17 0 01-3.2 3.8M6.6 6.6C3.9 8.3 2 12 2 12s4 7 10 7a9 9 0 004.4-1.1"/>',
  shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
  bank: '<path d="M3 10l9-6 9 6M5 10v8M9 10v8M15 10v8M19 10v8M3 20h18"/>',
  star: '<path d="M12 3l2.8 5.8 6.2.9-4.5 4.4 1 6.3L12 17.5 6.5 20.4l1-6.3L3 9.7l6.2-.9z"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
  warn: '<path d="M12 3l10 18H2z"/><path d="M12 10v4M12 17h.01"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7h.01"/>',
  refresh: '<path d="M20 11a8 8 0 10-2.3 5.7M20 5v6h-6"/>',
  camera: '<path d="M4 7h4l2-3h4l2 3h4v13H4z"/><circle cx="12" cy="13" r="4"/>',
  trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
  copy: '<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V4H4v12h4"/>',
  pie: '<path d="M12 3v9h9A9 9 0 1112 3z"/><path d="M15 3.5A9 9 0 0120.5 9H15z"/>',
  bars: '<path d="M5 20V10M10 20V4M15 20v-7M20 20v-4"/>',
  book: '<path d="M4 4h7a3 3 0 013 3v13a2 2 0 00-2-2H4zM20 4h-5a3 3 0 00-3 3"/>',
  id: '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="11" r="2"/><path d="M6 16c.5-1.5 1.7-2 3-2s2.5.5 3 2M14 10h4M14 13h3"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3 3 15 0 18M12 3c-3 3-3 15 0 18"/>',
};
const Icon = (name, size = 20, extra = '') => `<svg class="ic ${extra}" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${ICONS[name] || ''}</svg>`;

/* ---------- Store（本地持久化，失败时退化为内存） ---------- */
const Store = {
  key: 'broker-proto-v2',
  state: null,
  ui: { showTags: true },
  load() {
    try {
      const raw = localStorage.getItem(this.key);
      if (raw) { const s = JSON.parse(raw); if (s && s.v === 2) { this.state = s; return; } }
    } catch (e) { /* ignore */ }
    this.state = DATA.initialState('fresh');
  },
  save() { try { localStorage.setItem(this.key, JSON.stringify(this.state)); } catch (e) { /* ignore */ } },
  reset(scenario) { this.state = DATA.initialState(scenario); this.save(); },
};

/* ---------- Account logic ---------- */
const Acc = {
  inst(sym) { return DATA.instruments.find((i) => i.symbol === sym); },
  cur() { return Store.state.accounts[Store.state.mode]; },
  isLive() { return Store.state.mode === 'LIVE'; },
  usable() { const a = Acc.cur(); return Store.state.loggedIn && a.status === 'ACTIVE'; },
  chg(i) { return i.last - i.prev; },
  chgPct(i) { return (i.last - i.prev) / i.prev; },
  positions(a = Acc.cur()) {
    return a.positions.filter((p) => p.qty > 0).map((p) => {
      const inst = Acc.inst(p.symbol);
      const mv = p.qty * inst.last;
      const cost = p.qty * p.avgCost;
      return { ...p, inst, mv, cost, pnl: mv - cost, pnlPct: cost ? (mv - cost) / cost : 0, dayPnl: p.qty * (inst.last - inst.prev), deMinimis: mv < 1 };
    });
  },
  openOrders(a = Acc.cur()) { return a.orders.filter((o) => o.status === 'NEW' || o.status === 'PARTIALLY_FILLED'); },
  reservedForBuys(a = Acc.cur()) { return sum(Acc.openOrders(a).filter((o) => o.side === 'BUY'), (o) => (o.qty - o.filledQty) * (o.limitPrice || Acc.inst(o.symbol).last)); },
  summary(a = Acc.cur()) {
    const ps = Acc.positions(a);
    const stock = sum(ps.filter((p) => p.inst.type === 'STOCK'), (p) => p.mv);
    const etf = sum(ps.filter((p) => p.inst.type === 'ETF'), (p) => p.mv);
    const mv = stock + etf;
    const total = mv + a.cash;
    const dayPnl = sum(ps, (p) => p.dayPnl);
    const prevTotal = total - dayPnl;
    return {
      ps, stock, etf, mv, total, cash: a.cash,
      settledCash: Math.max(0, a.cash - a.unsettled),
      buyingPower: Math.max(0, a.cash - Acc.reservedForBuys(a)),
      withdrawable: Math.max(0, a.cash - a.unsettled - Acc.reservedForBuys(a)),
      dayPnl, dayPnlPct: prevTotal ? dayPnl / prevTotal : 0,
      pnl: sum(ps, (p) => p.pnl),
    };
  },
  quote(sym) {
    const i = Acc.inst(sym);
    const r = rng(sym + 'q');
    const spread = Math.max(0.01, round2(i.last * 0.0002));
    const ex = ['NSDQ', 'ARCA', 'BATS', 'EDGX', 'IEX', 'NYSE'];
    return {
      bid: round2(i.last - spread / 2), ask: round2(i.last + spread / 2),
      bidSize: 100 * (1 + Math.floor(r() * 9)), askSize: 100 * (1 + Math.floor(r() * 9)),
      bidEx: ex[Math.floor(r() * ex.length)], askEx: ex[Math.floor(r() * ex.length)],
      lastSize: 1 + Math.floor(r() * 400), lastEx: ex[Math.floor(r() * ex.length)],
      volume: Math.floor(5e6 + r() * 6e7), ts: new Date().toLocaleTimeString('zh-CN', { hour12: false }),
    };
  },
  fees(side, qty, price) {
    const notional = qty * price;
    const list = [{ name: '佣金', amount: 0 }];
    if (side === 'SELL' && qty > 0) {
      list.push({ name: 'SEC 规费（预估）', amount: ceilCent(notional * 0.0000278) });
      list.push({ name: 'FINRA TAF（预估）', amount: Math.min(ceilCent(qty * 0.000166), 8.30) });
    }
    return list;
  },
  /** 提交订单（原型：市价单立即成交；限价单可成交则成交，否则挂单） */
  placeOrder({ symbol, side, orderType, qty, limitPrice, tif }) {
    const a = Acc.cur();
    const q = Acc.quote(symbol);
    const id = 'O-' + (10100 + a.orders.length + Math.floor(Math.random() * 900));
    const fillPx = side === 'BUY' ? q.ask : q.bid;
    const marketable = orderType === 'MARKET' || (side === 'BUY' ? limitPrice >= q.ask : limitPrice <= q.bid);
    const fees = sum(Acc.fees(side, qty, fillPx), (f) => f.amount);
    const order = { orderId: id, symbol, side, orderType, tif, qty, limitPrice: orderType === 'LIMIT' ? limitPrice : null, filledQty: 0, avgFillPrice: null, status: 'NEW', fees: 0, createdAt: new Date().toISOString().slice(0, 19), fills: [] };
    if (marketable) {
      order.status = 'FILLED'; order.filledQty = qty; order.avgFillPrice = fillPx; order.fees = fees;
      order.fills = [{ qty, price: fillPx, time: new Date().toLocaleTimeString('zh-CN', { hour12: false }) }];
      Acc.applyFill(a, symbol, side, qty, fillPx, fees);
      a.documents.unshift({ id: 'D-' + id, type: 'TRADE_CONFIRM', title: `交易确认书 · ${symbol} ${side === 'BUY' ? '买入' : '卖出'}`, date: new Date().toISOString().slice(0, 10), period: new Date().toISOString().slice(0, 7) });
    }
    a.orders.unshift(order);
    Store.save();
    return order;
  },
  applyFill(a, symbol, side, qty, px, fees) {
    let p = a.positions.find((x) => x.symbol === symbol);
    const amt = qty * px;
    if (side === 'BUY') {
      if (!p) { p = { symbol, qty: 0, avgCost: 0 }; a.positions.push(p); }
      p.avgCost = (p.avgCost * p.qty + amt) / (p.qty + qty);
      p.qty = round4(p.qty + qty);
      a.cash = round2(a.cash - amt - fees);
    } else {
      p.qty = round4(p.qty - qty);
      if (p.qty <= 0) a.positions = a.positions.filter((x) => x !== p);
      a.cash = round2(a.cash + amt - fees);
      a.unsettled = round2(a.unsettled + amt - fees);
    }
    a.transactions.unshift({ id: 'T-' + Date.now(), type: 'TRADE', symbol, side, qty, price: px, amount: round2(side === 'BUY' ? -amt : amt), fee: fees, date: new Date().toISOString().slice(0, 10), status: '已成交', desc: `${side === 'BUY' ? '买入' : '卖出'} ${symbol}` });
  },
};
function round4(n) { return Math.round(n * 10000) / 10000; }

/* ---------- Charts（内联 SVG） ---------- */
const RANGE_POINTS = { '1D': 78, '1W': 35, '1M': 22, '3M': 64, '1Y': 52, '5Y': 60, YTD: 46 };
function genSeries(seed, n, end, vol = 0.012) {
  const r = rng(seed);
  const pts = [end];
  for (let k = 1; k < n; k++) pts.push(pts[k - 1] * (1 - (r() - 0.48) * vol * 2));
  return pts.reverse();
}
/** 清单 14：历史图表缓存（内存 + sessionStorage，按区间设置 TTL） */
const ChartCache = {
  mem: {},
  ttl: { '1D': 60e3, '1W': 3600e3, '1M': 86400e3, '3M': 86400e3, '1Y': 86400e3, '5Y': 86400e3 },
  get(symbol, range) {
    const key = `chart:${symbol}:${range}`;
    const now = Date.now();
    let hit = this.mem[key];
    if (!hit) { try { const raw = sessionStorage.getItem(key); if (raw) hit = JSON.parse(raw); } catch (e) { /* ignore */ } }
    if (hit && now - hit.at < (this.ttl[range] || 60e3)) { this.mem[key] = hit; return { ...hit, hit: true }; }
    const inst = Acc.inst(symbol);
    const series = genSeries(symbol + range, RANGE_POINTS[range] || 50, inst.last, range === '1D' ? 0.003 : 0.014);
    const entry = { series, at: now };
    this.mem[key] = entry;
    try { sessionStorage.setItem(key, JSON.stringify(entry)); } catch (e) { /* ignore */ }
    return { ...entry, hit: false };
  },
};
function lineChart(series, { w = 358, h = 140, color = 'var(--primary)', fill = true, stroke = 2, baseline = null } = {}) {
  if (!series.length) return '';
  const min = Math.min(...series, baseline ?? Infinity), max = Math.max(...series, baseline ?? -Infinity);
  const pad = 6, span = max - min || 1;
  const x = (i) => (i / (series.length - 1)) * w;
  const y = (v) => pad + (1 - (v - min) / span) * (h - pad * 2);
  const d = series.map((v, i) => `${i ? 'L' : 'M'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join('');
  const gid = 'g' + Math.random().toString(36).slice(2, 8);
  return `<svg viewBox="0 0 ${w} ${h}" width="100%" height="${h}" preserveAspectRatio="none" style="display:block">
    <defs><linearGradient id="${gid}" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="${color}" stop-opacity=".22"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></linearGradient></defs>
    ${baseline != null ? `<line x1="0" x2="${w}" y1="${y(baseline)}" y2="${y(baseline)}" stroke="var(--faint)" stroke-dasharray="3 4" stroke-width="1"/>` : ''}
    ${fill ? `<path d="${d}L${w},${h}L0,${h}Z" fill="url(#${gid})"/>` : ''}
    <path d="${d}" fill="none" stroke="${color}" stroke-width="${stroke}" vector-effect="non-scaling-stroke" stroke-linejoin="round"/>
  </svg>`;
}
function donut(parts, size = 132, center = '') {
  const total = sum(parts, (p) => p.v) || 1;
  const r = size / 2 - 10, c = 2 * Math.PI * r;
  let off = 0;
  const arcs = parts.filter((p) => p.v > 0).map((p) => {
    const len = (p.v / total) * c;
    const s = `<circle r="${r}" cx="${size / 2}" cy="${size / 2}" fill="none" stroke="${p.color}" stroke-width="16" stroke-dasharray="${len} ${c - len}" stroke-dashoffset="${-off}" transform="rotate(-90 ${size / 2} ${size / 2})"/>`;
    off += len; return s;
  }).join('');
  return `<div style="position:relative;width:${size}px;height:${size}px;flex:none">
    <svg width="${size}" height="${size}"><circle r="${r}" cx="${size / 2}" cy="${size / 2}" fill="none" stroke="var(--surface-2)" stroke-width="16"/>${arcs}</svg>
    <div style="position:absolute;inset:0;display:grid;place-items:center;text-align:center;font-size:12px">${center}</div></div>`;
}
const ALLOC_COLORS = { cash: '#1F4E79', stock: '#0E7C66', etf: '#D08A1E' };

/* ---------- Components ---------- */
const C = {
  tag(...ids) { return Store.ui.showTags ? ids.map((id) => `<span class="ctag">DW-${esc(id)}</span>`).join('') : ''; },
  notice(tone, html, icon) { return `<div class="notice ${tone}">${Icon(icon || ({ warn: 'warn', danger: 'warn', ok: 'check' }[tone] || 'info'), 18)}<div>${html}</div></div>`; },
  badge(text, tone = '') { return `<span class="badge ${tone}">${esc(text)}</span>`; },
  li({ icon, title, sub, right, go, act, data = '', danger }) {
    const attrs = go ? `data-go="${go}"` : act ? `data-act="${act}" ${data}` : '';
    return `<button class="li" ${attrs}>${icon ? `<span class="li-ic" ${danger ? 'style="color:var(--danger)"' : ''}>${Icon(icon, 18)}</span>` : ''}
      <span class="grow"><div class="li-title">${title}</div>${sub ? `<div class="li-sub">${sub}</div>` : ''}</span>
      ${right ?? ''}${go || act ? `<span class="chev">${Icon('right', 16)}</span>` : ''}</button>`;
  },
  seg(act, options, value, cls = 'seg') {
    return `<div class="${cls}">${options.map(([v, label]) => `<button class="${v === value ? 'on' : ''}" data-act="${act}" data-val="${esc(v)}">${label}</button>`).join('')}</div>`;
  },
  field({ label, bind, value = '', type = 'text', placeholder = '', hint = '', error = '', options = null, attrs = '', pair = false }) {
    let input;
    if (options) {
      input = `<select class="input" data-bind="${bind}" ${attrs}><option value="">请选择</option>${options.map(([v, l]) => `<option value="${esc(v)}" ${String(v) === String(value) ? 'selected' : ''}>${esc(l)}</option>`).join('')}</select>`;
    } else if (type === 'textarea') {
      input = `<textarea class="input" data-bind="${bind}" placeholder="${esc(placeholder)}" ${attrs}>${esc(value)}</textarea>`;
    } else {
      input = `<input class="input" type="${type}" data-bind="${bind}" value="${esc(value)}" placeholder="${esc(placeholder)}" ${attrs}>`;
    }
    const below = error ? `<div class="err-msg">${esc(error)}</div>` : hint ? `<div class="hint">${hint}</div>` : pair ? '<div class="hint hint-empty" aria-hidden="true"></div>' : '';
    return `<div class="field ${error ? 'err' : ''}" data-field="${bind}"><label>${label}</label>${input}${below}</div>`;
  },
  /** 两列字段：标签行、输入框、提示行结构一致，无提示时保留占位，保证左右对齐 */
  two(a, b) { return `<div class="two">${C.field({ ...a, pair: true })}${C.field({ ...b, pair: true })}</div>`; },
  yn(bind, value) {
    return `<div class="yn"><button class="${value === 'YES' ? 'on' : ''}" data-act="setYN" data-bind="${bind}" data-val="YES">是</button><button class="${value === 'NO' ? 'on' : ''}" data-act="setYN" data-bind="${bind}" data-val="NO">否</button></div>`;
  },
  kv(k, v) { return `<div class="kv"><span>${k}</span><span>${v}</span></div>`; },
  chg(i) { const c = Acc.chg(i); return `<span class="${clsOf(c)} num">${fmt.pct(Acc.chgPct(i))}</span>`; },
  qrow(sym, right) {
    const i = Acc.inst(sym);
    return `<button class="qrow" data-go="#/p10?symbol=${sym}">${symAvatar(sym)}<div class="grow"><div class="sym">${sym}</div><div class="xs muted ellipsis">${esc(i.name)}</div></div>
      ${right ?? `<div class="right num"><div class="b">${fmt.px(i.last)}</div></div><div class="chg-pill ${clsOf(Acc.chg(i))} num">${fmt.pct(Acc.chgPct(i))}</div>`}</button>`;
  },
  dataNote() { return `<div class="xs faint center mt12">演示数据 · 非真实行情 · 实时报价（按合同确定）${C.tag('13', 'PDF-5')}</div>`; },
  empty(icon, text, action = '') { return `<div class="empty">${Icon(icon, 40)}<div>${text}</div>${action ? `<div class="mt12">${action}</div>` : ''}</div>`; },
};

/* ---------- Overlay UI ---------- */
const UI = {
  stack: [],
  root() { return $('#overlay'); },
  open(html, { onClose } = {}) {
    const el = document.createElement('div');
    el.className = 'ov-layer';
    el.innerHTML = `<div class="backdrop" data-act="closeOverlay"></div>${html}`;
    this.root().appendChild(el);
    this.stack.push({ el, onClose });
    return el;
  },
  close() { const top = this.stack.pop(); if (top) { top.el.remove(); top.onClose && top.onClose(); } },
  closeAll() { while (this.stack.length) this.close(); },
  sheet(title, body, opts) { return this.open(`<div class="sheet"><button class="nav-btn sheet-x" data-act="closeOverlay">${Icon('x', 18)}</button>${title ? `<h3>${title}</h3>` : ''}${body}</div>`, opts); },
  confirm({ title, body = '', ok = '确认', cancel = '取消', danger = false, onOk }) {
    UI._onOk = onOk;
    this.open(`<div class="dialog"><h3>${title}</h3><div class="small muted">${body}</div><div class="btns">${cancel ? `<button class="btn ghost" data-act="closeOverlay">${cancel}</button>` : ''}<button class="btn ${danger ? 'danger' : 'primary'}" data-act="dialogOk">${ok}</button></div></div>`);
  },
  alert(title, body) { this.confirm({ title, body, ok: '知道了', cancel: null, onOk: () => {} }); },
  toast(msg) {
    const t = document.createElement('div');
    t.className = 'toast'; t.textContent = msg;
    $('.device').appendChild(t);
    setTimeout(() => t.remove(), 2200);
  },
};

/* ---------- Router ---------- */
const Pages = {};
const Router = {
  current: null,
  parse() {
    const raw = location.hash.replace(/^#\/?/, '');
    const [id, qs] = raw.split('?');
    return { id: id || '', params: Object.fromEntries(new URLSearchParams(qs || '')) };
  },
  go(h) { if (location.hash === h) Router.render(); else location.hash = h; },
  back(fallback) { if (history.length > 1 && Router.hasHistory) history.back(); else Router.go(fallback || Router.current?.page?.backTo || '#/p07'); },
  hasHistory: false,
  render(keepScroll = false) {
    let { id, params } = Router.parse();
    if (!id) { id = Store.state.loggedIn ? 'p07' : 'p01'; history.replaceState(null, '', '#/' + id); }
    const page = Pages[id] || Pages.s01;
    if (!Pages[id]) params = { type: 'notfound' };
    // 访问守卫：需要登录的页面
    if (page.auth && !Store.state.loggedIn) { history.replaceState(null, '', '#/p02'); return Router.render(); }
    const same = Router.current && Router.current.id === id && JSON.stringify(Router.current.params) === JSON.stringify(params);
    const ctx = same ? Router.current.ctx : {};
    const prevScroll = keepScroll && same ? ($('#content')?.scrollTop || 0) : 0;
    Router.current = { id, params, page, ctx };
    if (!same) UI.closeAll();
    const out = page.render(params, ctx);
    const header = out.headerless ? '' : out.tab
      ? `<header class="nav big"><h1>${out.title}</h1><div class="nav-right">${out.right || ''}<button class="ava-btn" data-act="drawer" aria-label="账户">${Icon('user', 20)}</button></div></header>`
      : `<header class="nav">${out.noBack ? '<span class="nav-btn"></span>' : `<button class="nav-btn" data-back aria-label="返回">${Icon('left', 22)}</button>`}<h1>${out.title || ''}</h1><div class="nav-right">${out.right || ''}</div></header>`;
    $('#app').innerHTML = `<div class="screen ${out.cls || ''}">${header}<main class="content ${out.flush ? 'flush' : ''}" id="content">${out.body}</main>${out.footer ? `<div class="footer">${out.footer}</div>` : ''}${out.tab ? tabbar(out.tab) : ''}</div>`;
    if (prevScroll) $('#content').scrollTop = prevScroll;
    page.mount && page.mount(params, ctx);
    Console.render();
  },
  refresh() { Router.render(true); },
};
function tabbar(active) {
  const tabs = [['assets', '#/p07', 'home', '资产'], ['market', '#/p09', 'market', '市场'], ['inst', '#/p23', 'building', '机构追踪'], ['ai', '#/p26', 'spark', 'AI 助手'], ['rewards', '#/p27', 'gift', '奖励']];
  return `<nav class="tabbar">${tabs.map(([k, h, ic, l]) => `<button class="tab ${k === active ? 'on' : ''}" data-go="${h}">${Icon(ic, 22)}<span>${l}</span></button>`).join('')}</nav>`;
}

/* ---------- Global actions ---------- */
const GlobalActions = {
  closeOverlay() { UI.close(); },
  dialogOk() { const fn = UI._onOk; UI.close(); fn && fn(); },
  drawer() { Drawer.open(); },
  toggleConsole() { $('#console').classList.toggle('open'); },
  toggleHide() { Store.state.prefs.hideBalances = !Store.state.prefs.hideBalances; Store.save(); Router.refresh(); Drawer.refreshIfOpen(); },
  setMode(el) {
    Store.state.mode = el.dataset.val; Store.save();
    Drawer.refreshIfOpen(); Router.refresh();
    UI.toast(el.dataset.val === 'LIVE' ? '已切换到实盘账户' : '已切换到模拟账户');
  },
  copy(el) { try { navigator.clipboard.writeText(el.dataset.val); } catch (e) { /* ignore */ } UI.toast('已复制'); },
  logout() {
    UI.confirm({ title: '退出登录？', body: '退出后需要重新登录才能查看账户和交易。', ok: '退出登录', danger: true, onOk: () => { UI.closeAll(); Store.state.loggedIn = false; Store.save(); Router.go('#/p01'); } });
  },
  scenario(el) { Store.reset(el.dataset.val); UI.closeAll(); applyPrefs(); Router.go(Store.state.loggedIn ? '#/p07' : '#/p01'); UI.toast('已切换场景'); },
  approve() { DWSim.setKyc('KYC_APPROVED'); },
  kyc(el) { DWSim.setKyc(el.dataset.val); },
  acctStatus(el) { DWSim.setAccount(el.dataset.val); },
  toggleTags() { Store.ui.showTags = !Store.ui.showTags; document.body.classList.toggle('hide-tags', !Store.ui.showTags); Router.refresh(); },
  setYN(el) { const ctx = Router.current.ctx; const form = ctx.form || (ctx.form = {}); form[el.dataset.bind] = el.dataset.val; (Router.current.page.onInput || (() => {}))(el, ctx); Router.refresh(); },
};
/* ---------- DW 开户模拟（实际由后端调用 DW 并同步状态，App 只读取） ---------- */
const nowStr = () => new Date().toISOString().slice(0, 16).replace('T', ' ');
function notify(category, title, body, link) {
  Store.state.notifications.unshift({ id: 'n' + Date.now() + Math.floor(Math.random() * 99), category, title, body, at: nowStr(), read: false, link });
}
const KYC_LABEL = {
  KYC_NOT_READY: ['资料未齐', ''], KYC_READY: ['等待核验', 'info'], KYC_PROCESSING: ['身份核验中', 'info'],
  KYC_INFO_REQUIRED: ['需要修改资料', 'warn'], KYC_DOC_REQUIRED: ['需要上传证件', 'warn'], KYC_MANUAL_REVIEW: ['人工复核中', 'info'],
  KYC_APPROVED: ['核验通过', 'ok'], KYC_DENIED: ['无法开户', 'danger'],
};
const ACCT_LABEL = {
  PENDING: ['开立中', 'info'], OPEN: ['已开通', 'ok'], OPEN_NO_NEW_TRADES: ['仅可卖出', 'warn'], FROZEN: ['已冻结', 'danger'], CLOSED: ['已关闭', ''],
};
// 原型中"需补资料"的示例问题（实际来自 DW kyc-status 返回的 errors / details）
const KYC_SAMPLE_ISSUES = [
  { code: 'ADDRESS_UNVERIFIED', step: 'd', field: 'line1', reason: '居住地址无法核实，请确认门牌号、街道和邮编完整准确' },
  { code: 'DOB_MISMATCH', step: 'b', field: 'dateOfBirth', reason: '出生日期与身份记录不一致，请核对' },
];
const KYC_DOC_REASON = '我们未能通过公共记录核实您的身份，请上传一份政府签发、带照片的有效证件。';
const DWSim = {
  timer: null,
  later(fn, ms) { clearTimeout(this.timer); this.timer = setTimeout(() => { this.timer = null; fn(); }, ms); },
  /** 美国纳税人（SSN / ITIN）由 DW 数据库自动核验；其他用户需上传证件 */
  isUS() { return Store.state.application.data.usTaxPayer === 'YES'; },
  /** P-30 提交：后端先 POST /users（BASIC_INFO、IDENTIFICATION_INFO、PERSONAL_INFO、ADDRESS_INFO），
      再 PATCH /users/{userID} 补充其余 documents（已核实 creating-a-user；能否一次提交全部待 Q-DW-3）。
      对用户仍是一次提交。Do KYC 模式下 DW 随后自动发起 KYC（模式待 Q-DW-1）。 */
  submitUser() {
    const s = Store.state;
    s.dw.userID = 'usr_' + Math.random().toString(36).slice(2, 12);
    s.application.ref = 'APP-' + Math.random().toString(36).slice(2, 6).toUpperCase() + '-' + Math.random().toString(36).slice(2, 6).toUpperCase();
    s.application.submittedAt = new Date().toISOString().slice(0, 19);
    s.application.disclosures.signedAt = s.application.submittedAt;
    s.application.returnTo = null;
    s.accountStatus = 'SUBMITTED';
    if (s.scenario === 'loggedIn' || s.scenario === 'fresh') s.scenario = 'review';
    this.setKyc('KYC_PROCESSING', { silent: true });
    this.autoResolve();
  },
  /** 原型：自动给出 KYC 结果。美国用户 → 通过；非美国用户 → 人工复核。可在原型控制台改成其他结果。 */
  autoResolve() { this.later(() => { if (Store.state.dw.kyc === 'KYC_PROCESSING') this.setKyc(this.isUS() ? 'KYC_APPROVED' : 'KYC_MANUAL_REVIEW'); }, 2600); },
  /** 修改资料后 PATCH /users 或补证件后 POST /documents：DW 重跑 KYC */
  resubmit() {
    const s = Store.state;
    s.application.returnTo = null;
    this.setKyc('KYC_PROCESSING', { silent: true });
    this.later(() => { if (Store.state.dw.kyc === 'KYC_PROCESSING') this.setKyc('KYC_APPROVED'); }, 2600);
  },
  setKyc(status, { silent = false } = {}) {
    const s = Store.state;
    if (!s.dw.userID) { s.dw.userID = 'usr_' + Math.random().toString(36).slice(2, 12); s.accountStatus = 'SUBMITTED'; }
    if (status !== 'KYC_PROCESSING') clearTimeout(this.timer);
    s.dw.kyc = status;
    s.dw.kycUpdatedAt = nowStr();
    s.dw.issues = status === 'KYC_INFO_REQUIRED' ? KYC_SAMPLE_ISSUES.map((x) => ({ ...x })) : [];
    s.dw.docReason = status === 'KYC_DOC_REQUIRED' ? KYC_DOC_REASON : null;
    if (status === 'KYC_DOC_REQUIRED') s.dw.docUpload = { docType: 'PASSPORT' };
    const msg = {
      KYC_INFO_REQUIRED: ['开户资料需要修改', '部分资料未能通过核验，请按提示修改后重新提交。'],
      KYC_DOC_REQUIRED: ['请上传身份证件', '我们需要您上传政府签发的身份证件以完成核验。'],
      KYC_MANUAL_REVIEW: ['开户申请进入人工复核', '结果会通过通知告知（预计时长待 DW 确认）。'],
      KYC_DENIED: ['开户申请结果', '很抱歉，暂时无法为您开立证券账户。如有疑问请联系客服。'],
      KYC_APPROVED: ['身份核验通过', '正在为您开立交易账户。'],
    }[status];
    const link = { KYC_INFO_REQUIRED: '#/p34', KYC_DOC_REQUIRED: '#/p35', KYC_DENIED: '#/p36' }[status] || '#/p06';
    if (msg && !silent) notify('ACCOUNT', msg[0], msg[1], link);
    Store.save();
    if (status === 'KYC_APPROVED') this.createAccount();
    this.rerender();
  },
  /** KYC_APPROVED 后：POST /accounts（LIVE / SELF / CASH），状态 PENDING → OPEN */
  createAccount() {
    const s = Store.state;
    if (s.accountStatus === 'APPROVED') return; // 已有账户（如资料变更后重跑 KYC）
    s.dw.account = 'PENDING'; Store.save();
    setTimeout(() => this.openAccount(), 1800);
  },
  openAccount() {
    const s = Store.state;
    if (s.dw.account !== 'PENDING') return;
    const d = s.application.data;
    s.dw.account = 'OPEN';
    s.accountStatus = 'APPROVED';
    s.accounts.LIVE = DATA.liveNew();
    s.profile = { ...s.profile, phone: d.phone || s.profile.phone, line1: d.line1 || s.profile.line1, line2: d.line2 || '', city: d.city || '', state: d.state || '', postalCode: d.postalCode || '', employmentStatus: d.employmentStatus || '', employerName: d.employerName || '' };
    s.profileSync = { status: 'SYNCED', at: nowStr() };
    s.mode = 'LIVE';
    notify('ACCOUNT', '交易账户已开通', `您的实盘账户 ${s.accounts.LIVE.accountNumber} 已开通。绑定银行账户或通过电汇即可入金。`, '#/p06');
    Store.save();
    this.rerender();
  },
  /** 原型：模拟 DW 账户状态变化（OPEN / OPEN_NO_NEW_TRADES / FROZEN） */
  setAccount(st) {
    const s = Store.state;
    if (s.accounts.LIVE.status !== 'ACTIVE') return UI.toast('尚无已开通的实盘账户');
    s.accounts.LIVE.dwStatus = st; s.dw.account = st;
    if (st !== 'OPEN') notify('ACCOUNT', '账户状态变更', st === 'FROZEN' ? '您的账户已被冻结，暂不能交易或出入金。请联系客服。' : '您的账户目前仅可卖出，暂不能买入新证券。', '#/s01?type=restricted');
    Store.save(); UI.toast('DW 账户状态：' + st); this.rerender();
  },
  rerender() { if (Router.current) Router.refresh(); Drawer.refreshIfOpen(); },
};

/* 开户进度入口文案（P-07、P-08、notReady 等共用） */
const Onb = {
  status() {
    const s = Store.state;
    const k = s.dw.kyc;
    if (s.accountStatus === 'NONE') return { title: '开通证券账户', sub: '验证身份即可入金交易，约需 5 分钟', go: '#/p03', cta: '去开户', icon: 'shield' };
    if (s.accountStatus === 'DRAFT') return { title: '继续开通您的账户', sub: '进度已保存，可从上次中断处继续', go: Onb.resumeHref(), cta: '继续开户', icon: 'shield' };
    if (s.accountStatus === 'APPROVED') return null;
    if (k === 'KYC_APPROVED') return { title: '交易账户开立中', sub: '身份核验已通过（预计时长待 DW 确认）', go: '#/p06', cta: '查看进度', icon: 'clock' };
    const map = {
      KYC_INFO_REQUIRED: ['开户资料需要修改', '请按提示修改后重新提交', 'edit', '#/p34', '去修改资料'],
      KYC_DOC_REQUIRED: ['需要上传身份证件', '上传后将重新核验', 'id', '#/p35', '去上传证件'],
      KYC_MANUAL_REVIEW: ['开户申请人工复核中', '预计时长待 DW 确认', 'clock', '#/p06', '查看申请进度'],
      KYC_DENIED: ['开户未通过', '查看结果与后续可选操作', 'info', '#/p36', '查看结果'],
    }[k] || ['身份核验中', `参考号 ${s.application.ref || '—'}`, 'clock', '#/p06', '查看申请进度'];
    return { title: map[0], sub: map[1], icon: map[2], go: map[3], cta: map[4], tone: ['KYC_INFO_REQUIRED', 'KYC_DOC_REQUIRED'].includes(k) ? 'warn' : '' };
  },
  resumeHref() {
    const st = Store.state.application.step;
    if (!st || st === 'a') return '#/p03';
    if (['p04', 'p05', 'p30'].includes(st)) return '#/' + st;
    return '#/p03?step=' + st;
  },
};

/* 资金方式（仅 DW 支持的方式）：ACH（Plaid 绑定本人美国银行账户）与电汇。
   没有美国银行账户的用户（多为非美国纳税人）默认推荐电汇。 */
const Fund = {
  preferWire() { return !DWSim.isUS(); },
  linked() { return Store.state.linkedBanks; },
  bindHref(from) { return '#/p32' + (from ? '?from=' + from : ''); },
  max: 2,
};

/* 账户受限（DW 账户状态 OPEN_NO_NEW_TRADES / FROZEN），仅实盘 */
Acc.restriction = function () {
  const s = Store.state;
  if (s.mode !== 'LIVE') return null;
  const st = s.accounts.LIVE.dwStatus;
  if (st === 'FROZEN') return { code: st, title: '账户已冻结', body: '暂不能交易、入金或出金。资产仍安全托管，请联系客服了解原因。', noBuy: true, noSell: true, noFunds: true };
  if (st === 'OPEN_NO_NEW_TRADES') return { code: st, title: '账户仅可卖出', body: '暂不能买入新证券，可卖出现有持仓、入金和出金。', noBuy: true };
  return null;
};
C.restrict = function () {
  const r = Acc.restriction();
  return r ? `<button class="notice danger" style="width:100%;text-align:left" data-go="#/s01?type=restricted">${Icon('warn', 18)}<div><b>${r.title}</b><br>${r.body}</div></button>` : '';
};
function applyPrefs() { document.body.classList.toggle('red-up', !!Store.state.prefs.redUp); }

/* ---------- P-08 账户抽屉 ---------- */
const Drawer = {
  el: null,
  open() { this.el = UI.open(`<div class="drawer" id="drawer">${this.html()}</div>`, { onClose: () => { this.el = null; } }); },
  refreshIfOpen() { if (this.el) { const d = $('#drawer', this.el); if (d) d.innerHTML = this.html(); } },
  html() {
    const s = Store.state;
    const a = Acc.cur();
    const live = s.mode === 'LIVE';
    const usable = a.status === 'ACTIVE';
    const sm = usable ? Acc.summary(a) : null;
    const ob = Onb.status();
    const unread = s.notifications.filter((n) => !n.read).length;
    const card = usable ? `
      <div class="row between"><span class="b" style="color:var(--primary-2)">${live ? '实盘账户' : '模拟账户'}</span>${live && a.dwStatus && a.dwStatus !== 'OPEN' ? C.badge(ACCT_LABEL[a.dwStatus][0], ACCT_LABEL[a.dwStatus][1]) : C.badge(a.type === 'CASH' ? '现金 · 自主' : a.type, 'ok')}</div>
      <div class="row mt8 small"><span class="muted">账户号码${C.tag('PDF-6')}</span><span class="grow b num right" style="white-space:nowrap;font-size:13px">${esc(a.accountNumber)}</span><button class="nav-btn" style="width:28px;height:28px" data-act="copy" data-val="${esc(a.accountNumber)}" aria-label="复制">${Icon('copy', 16)}</button></div>
      ${live ? '<div class="xs faint">账户类型 LIVE · CASH · SELF</div>' : ''}
      <div class="hr"></div>
      ${C.kv('市值', fmt.money(sm.mv))}${C.kv('购买力', fmt.money(sm.buyingPower))}${C.kv('现金', fmt.money(sm.cash))}
      <div class="row mt12"><button class="btn primary sm grow" data-go="#/p13">入金</button><button class="btn ghost sm grow" data-go="#/p28">转入</button></div>`
      : `
      <div class="b" style="color:var(--warn)">交易账户暂不可用</div>
      <div class="row mt8 small"><span class="muted">账户号码</span><span class="grow right">--</span></div>
      ${C.kv('市值', '—')}${C.kv('购买力', '—')}${C.kv('现金', '—')}
      <div class="small muted mt8">${!s.loggedIn ? '请先登录' : ob ? ob.title : ''}</div>
      ${s.loggedIn && live && ob ? `<button class="btn primary sm mt12" style="width:100%" data-go="${ob.go}">${ob.cta}</button>` : ''}`;
    return `
      <button class="nav-btn drawer-x" data-act="closeOverlay" aria-label="关闭">${Icon('x', 18)}</button>
      <div class="center">${nameAvatar(s.user.email, 'lg')}<div class="small muted mt8">${s.loggedIn ? esc(s.user.email) : '未登录'}</div><div class="b mt8" style="font-size:17px">切换账户</div></div>
      <div class="seg2 mt12">
        <button class="${live ? 'on' : ''}" data-act="setMode" data-val="LIVE"><span class="dot" style="background:var(--up)"></span>实盘</button>
        <button class="${!live ? 'on' : ''}" data-act="setMode" data-val="PAPER"><span class="dot" style="background:var(--accent)"></span>模拟</button>
      </div>
      <div class="card" style="border:1.5px solid var(--primary-weak)">${card}</div>
      <div class="group-label">资金</div>
      <div class="list">${C.li({ icon: 'down', title: '入金', go: '#/p13' })}${C.li({ icon: 'up', title: '出金', go: '#/p14' })}${C.li({ icon: 'bank', title: '银行账户', go: '#/p31', right: Fund.linked().length ? `<span class="small muted">${Fund.linked().length} 个</span>` : '' })}${C.li({ icon: 'swap', title: '转入其他券商账户', go: '#/p28' })}</div>
      <div class="group-label">动态</div>
      <div class="list">${C.li({ icon: 'bell', title: '通知', go: '#/p17', right: unread ? C.badge(String(unread), 'danger') : '' })}${C.li({ icon: 'clock', title: '历史记录', go: '#/p18' })}${C.li({ icon: 'doc', title: '文件', go: '#/p15' })}</div>
      <div class="group-label">管理</div>
      <div class="list">${C.li({ icon: 'gear', title: '设置', go: '#/p16' })}${C.li({ icon: 'help', title: '帮助中心', go: '#/p29' })}${s.loggedIn ? C.li({ icon: 'logout', title: '退出登录', act: 'logout' }) : C.li({ icon: 'user', title: '登录', go: '#/p02' })}</div>
      <div class="xs faint center mt16">${APP_NAME} 原型 v0.2</div>`;
  },
};

/* ---------- 原型控制台（不属于 App 页面） ---------- */
const PAGE_INDEX = [
  ['p01', '欢迎页'], ['p02', '登录 / 注册'], ['p03', '开户信息填写'], ['p04', '身份验证'], ['p05', '披露确认'], ['p30', '开户资料确认'], ['p06', '开户进度'],
  ['p07', '资产首页'], ['p08', '账户抽屉'], ['p09', '市场'], ['p10', '个股详情'], ['p11', '订单列表'], ['p12', '持仓'],
  ['p13', '入金'], ['p14', '出金'], ['p15', '文件'], ['p16', '设置与个人资料'], ['p17', '通知与提示'], ['p18', '历史记录'],
  ['p19', '下单'], ['p20', '搜索'], ['p21', '自选股'], ['p22', '榜单详情'], ['p23', '机构持仓追踪'], ['p24', '机构列表'],
  ['p25', '智能组合问卷'], ['p26', 'AI 助手'], ['p27', '奖励中心'], ['p28', 'ACATS 转入'], ['p29', '帮助中心'], ['p31', '资金账户管理'], ['p32', '绑定银行（Plaid）'], ['p33', '电汇入金指引'], ['p34', '补充开户资料'], ['p35', '补充身份证件'], ['p36', '开户未通过'], ['s01', '全局状态页'],
];
const Console = {
  render() {
    const s = Store.state;
    const cur = Router.current?.id;
    const scn = [['fresh', '未登录'], ['loggedIn', '已登录 · 未开户'], ['review', '开户审核中（KYC 处理中）'], ['newAccount', '已开户 · 美国 · 未绑卡'], ['newAccountIntl', '已开户 · 非美国 · 未入金'], ['seasoning', '已开户 · ACH 观察期中（可提现 $0）'], ['approved', '已开户（有持仓）']];
    const kycBtns = [['KYC_APPROVED', '通过'], ['KYC_INFO_REQUIRED', '需补资料'], ['KYC_DOC_REQUIRED', '需补证件'], ['KYC_MANUAL_REVIEW', '人工复核'], ['KYC_DENIED', '拒绝']];
    const acctBtns = [['OPEN', '正常'], ['OPEN_NO_NEW_TRADES', '仅可卖出'], ['FROZEN', '冻结']];
    $('#console').innerHTML = `
      <h4>场景</h4>${scn.map(([k, l]) => `<button class="cbtn ${s.scenario === k ? 'on' : ''}" data-act="scenario" data-val="${k}">${l}</button>`).join('')}
      ${s.accountStatus === 'SUBMITTED' ? `<h4>模拟 DW 返回 KYC 结果</h4>${kycBtns.map(([k, l]) => `<button class="cbtn ${s.dw.kyc === k ? 'on' : ''}" data-act="kyc" data-val="${k}">${l}<span class="pid" style="margin-left:6px">${k.replace('KYC_', '')}</span></button>`).join('')}` : ''}
      ${s.accountStatus === 'APPROVED' ? `<h4>模拟 DW 账户状态</h4>${acctBtns.map(([k, l]) => `<button class="cbtn ${(s.accounts.LIVE.dwStatus || 'OPEN') === k ? 'on' : ''}" data-act="acctStatus" data-val="${k}">${l}<span class="pid" style="margin-left:6px">${k}</span></button>`).join('')}` : ''}
      <h4>标注</h4><button class="cbtn" data-act="toggleTags">${Store.ui.showTags ? '隐藏' : '显示'}合规编号标注</button>
      <h4>页面</h4>${PAGE_INDEX.map(([id, n]) => `<button class="cbtn ${cur === id ? 'on' : ''}" ${id === 'p08' ? 'data-act="drawer"' : `data-go="${defaultHref(id)}"`}><span class="pid">${id.toUpperCase().replace('P', 'P-').replace('S', 'S-')}</span>${n}</button>`).join('')}
      <div class="xs faint mt12">状态：${s.loggedIn ? '已登录' : '未登录'} · ${s.accountStatus} · ${s.mode}<br>DW：${s.dw.userID || '无 User'} · ${s.dw.kyc} · 账户 ${s.dw.account || '—'} · 银行 ${Fund.linked().length}<br>数据保存在本浏览器，切换场景即重置。</div>`;
  },
};
function defaultHref(id) { return { p10: '#/p10?symbol=AAPL', p19: '#/p19?symbol=AAPL&side=BUY', p22: '#/p22?type=gainers', s01: '#/s01?type=expired', p32: '#/p32?from=p31', p33: '#/p33' }[id] || '#/' + id; }

/* ---------- Event delegation ---------- */
document.addEventListener('click', (e) => {
  const t = e.target.closest('[data-go],[data-back],[data-act]');
  if (!t || t.disabled) return;
  if (t.dataset.go) {
    e.preventDefault();
    if ($('#console').contains(t)) $('#console').classList.remove('open');
    UI.closeAll(); Router.hasHistory = true; Router.go(t.dataset.go);
  } else if (t.hasAttribute('data-back')) {
    Router.back();
  } else {
    const name = t.dataset.act;
    const fn = (Router.current?.page.actions || {})[name] || GlobalActions[name];
    if (fn) { e.preventDefault(); fn(t, Router.current.ctx, e); }
  }
});
function bindHandler(e) {
  const el = e.target;
  if (!el.dataset || !el.dataset.bind) return;
  const ctx = Router.current.ctx;
  const form = ctx.form || (ctx.form = {});
  form[el.dataset.bind] = el.type === 'checkbox' ? el.checked : el.value;
  const p = Router.current.page;
  p.onInput && p.onInput(el, ctx, e);
}
document.addEventListener('input', bindHandler);
document.addEventListener('change', (e) => { if (e.target.tagName === 'SELECT' || e.target.type === 'checkbox' || e.target.type === 'file' || e.target.type === 'date') bindHandler(e); });
window.addEventListener('hashchange', () => Router.render());
