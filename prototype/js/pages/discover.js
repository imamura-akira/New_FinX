'use strict';
/* P-23 机构持仓追踪、P-24 机构列表、P-25 智能组合问卷、P-26 AI 助手、P-27 奖励中心、S-01 状态页 */

/* ---------- P-23 机构持仓追踪 ---------- */
Pages.p23 = {
  render(p, ctx) {
    ctx.g = ctx.g || 'hot';
    ctx.f = ctx.f || 'INC';
    const inst = ctx.g === 'recent' ? DATA.institutions.slice().sort((a, b) => b.updated.localeCompare(a.updated)) : DATA.institutions.slice().sort((a, b) => b.ret - a.ret);
    const rows = DATA.opportunities[ctx.f];
    return {
      title: '机构追踪', tab: 'inst',
      body: `<div class="card" style="background:linear-gradient(120deg,#4A43E8,#8A3FE0 55%,#D63AA8);color:#fff"><div class="b" style="font-size:18px">看看大机构在买什么</div><div class="small" style="opacity:.75;margin-top:4px">基于公开的 13F 持仓申报，按季度更新</div></div>
        <div class="row between">${C.seg('g', [['hot', '收益最高'], ['recent', '最近更新']], ctx.g)}<button class="link-btn small" data-go="#/p24">更多</button></div>
        <div class="inst-grid">
          ${inst.slice(0, 6).map((x) => `<button class="card center" data-go="#/p24?id=${x.id}">${nameAvatar(x.name)}<div class="b small mt8 ellipsis">${esc(x.name)}</div><div class="xs muted">年收益</div><div class="badge ${x.ret >= 0 ? 'ok' : 'danger'} mt8 num">${fmt.pct(x.ret)}</div></button>`).join('')}
        </div>
        <div class="sec-title"><span>个股机会</span><span class="xs muted">2026 年第三季度</span></div>
        ${C.seg('f', [['INC', '增持最多'], ['CONTRA', '逆势增持'], ['MOST', '持股最多'], ['NEW', '新进持股']], ctx.f, 'seg wrap')}
        <div class="card" style="padding:4px 12px"><table class="table"><tr><th>代码</th><th>增持占总股本</th><th>增 / 平 / 减 家数</th></tr>
          ${rows.map(([sym, pct, inc, flat, dec]) => `<tr data-go="#/p10?symbol=${sym}"><td><div class="row" style="gap:4px"><span class="b">${sym}</span><span class="badge info" style="height:16px;font-size:10px">US</span></div><div class="xs muted num">最新价 ${fmt.px(Acc.inst(sym).last)}</div></td><td class="num">${fmt.pct(pct, { sign: false })}</td><td class="num"><span class="up">${inc}</span> : ${flat} : <span class="down">${dec}</span></td></tr>`).join('')}
        </table></div>
        ${C.notice('info', '数据来源于机构公开申报（演示数据），存在披露滞后，不代表机构当前持仓，不构成投资建议。仅展示主清单内证券。' + C.tag('23'))}`,
    };
  },
  actions: { g(el, ctx) { ctx.g = el.dataset.val; Router.refresh(); }, f(el, ctx) { ctx.f = el.dataset.val; Router.refresh(); } },
};

/* ---------- P-24 机构列表 ---------- */
Pages.p24 = {
  backTo: '#/p23',
  render(p, ctx) {
    if (p.id) {
      const x = DATA.institutions.find((i) => i.id === p.id);
      return {
        title: esc(x.name),
        body: `<div class="card center">${nameAvatar(x.name, 'lg')}<div class="b mt8" style="font-size:18px">${esc(x.name)}</div><div class="xs muted">${esc(x.firm)}</div>
            <div class="row mt16" style="justify-content:space-around"><div><div class="xs muted">年收益</div><div class="b num ${clsOf(x.ret)}">${fmt.pct(x.ret)}</div></div><div><div class="xs muted">资产增速</div><div class="b num ${clsOf(x.aum)}">${fmt.pct(x.aum)}</div></div><div><div class="xs muted">更新</div><div class="b">${x.updated}</div></div></div></div>
          ${C.notice('warn', '机构详情页结构未在参考截图中提供，以下为占位内容，待补充设计。')}
          <div class="sec-title" style="font-size:15px">前五大持仓（示例）</div>
          <div class="card" style="padding:4px 16px">${['AAPL', 'MSFT', 'AMZN', 'JPM', 'KO'].map((s) => C.qrow(s)).join('')}</div>`,
      };
    }
    ctx.sort = ctx.sort || 'updated';
    const list = DATA.institutions.slice().sort((a, b) => ctx.sort === 'ret' ? b.ret - a.ret : ctx.sort === 'aum' ? b.aum - a.aum : b.updated.localeCompare(a.updated));
    return {
      title: '全部机构',
      body: `<div class="card" style="padding:4px 12px"><table class="table"><tr><th>名称/公司</th><th class="sortable" data-act="sort" data-val="ret">收益${ctx.sort === 'ret' ? ' ▾' : ''}</th><th class="sortable" data-act="sort" data-val="aum">资产增速${ctx.sort === 'aum' ? ' ▾' : ''}</th><th class="sortable" data-act="sort" data-val="updated">更新${ctx.sort === 'updated' ? ' ▾' : ''}</th></tr>
        ${list.map((x) => `<tr data-go="#/p24?id=${x.id}"><td><div class="row" style="gap:8px">${nameAvatar(x.name)}<div><div class="b small">${esc(x.name)}</div><div class="xs muted ellipsis" style="max-width:96px">${esc(x.firm)}</div></div></div></td><td class="num ${clsOf(x.ret)}">${fmt.pct(x.ret, { dp: 1 })}</td><td class="num ${clsOf(x.aum)}">${fmt.pct(x.aum, { dp: 1 })}</td><td class="small">${x.updated}</td></tr>`).join('')}</table></div>
        <div class="xs faint center">机构名称均为虚构示例</div>`,
    };
  },
  actions: { sort(el, ctx) { ctx.sort = el.dataset.val; Router.refresh(); } },
};

/* ---------- P-25 智能组合问卷 ---------- */
const QUIZ = [
  ['您的主要投资目标是？', [['保本为主', 1], ['稳健增值', 2], ['长期增长', 3], ['追求高回报', 4]]],
  ['计划投资多长时间？', [['1 年以内', 1], ['1–3 年', 2], ['3–10 年', 3], ['10 年以上', 4]]],
  ['如果组合一个月下跌 20%，您会？', [['全部卖出', 1], ['卖出一部分', 2], ['继续持有', 3], ['加仓', 4]]],
  ['您的投资经验？', [['没有', 1], ['1–2 年', 2], ['3–5 年', 3], ['5 年以上', 4]]],
  ['这笔资金占您可投资资产的比例？', [['超过 75%', 1], ['50–75%', 2], ['25–50%', 3], ['低于 25%', 4]]],
  ['您的收入稳定性？', [['不稳定', 1], ['一般', 2], ['稳定', 3], ['非常稳定', 4]]],
  ['您更看重？', [['避免亏损', 1], ['收益与风险平衡', 2], ['较高收益', 3], ['最大化收益', 4]]],
  ['您是否需要这笔钱应急？', [['很可能需要', 1], ['可能需要', 2], ['不太需要', 3], ['完全不需要', 4]]],
  ['您对单只股票的看法？', [['只买指数', 1], ['少量配置', 2], ['适度配置', 3], ['集中持有', 4]]],
  ['您希望多久查看一次组合？', [['每天', 2], ['每周', 3], ['每月', 3], ['很少', 4]]],
];
const STYLES = [
  { max: 17, name: '稳健型', desc: '以债券和大盘指数为主，波动较小。', holdings: [['TLT', 0.45], ['SPY', 0.35], ['GLD', 0.20]] },
  { max: 25, name: '平衡型', desc: '股债平衡，兼顾收益与回撤。', holdings: [['SPY', 0.45], ['TLT', 0.25], ['QQQ', 0.15], ['GLD', 0.15]] },
  { max: 33, name: '成长型', desc: '以宽基与科技指数为主，追求长期增长。', holdings: [['SPY', 0.40], ['QQQ', 0.35], ['IWM', 0.15], ['EEM', 0.10]] },
  { max: 99, name: '积极型', desc: '偏重科技与小盘，波动较大。', holdings: [['QQQ', 0.45], ['XLK', 0.25], ['IWM', 0.20], ['EEM', 0.10]] },
];
Pages.p25 = {
  render(p, ctx) {
    ctx.ans = ctx.ans || [];
    if (ctx.stage === 'quiz') {
      const k = ctx.ans.length;
      if (k >= QUIZ.length) { ctx.stage = 'result'; return Pages.p25.render(p, ctx); }
      const [q, opts] = QUIZ[k];
      return {
        title: '投资问卷',
        body: `<div class="progress"><i style="width:${(k / QUIZ.length) * 100}%"></i></div><div class="xs muted mb16">${k + 1} / ${QUIZ.length}</div>
          <div class="b" style="font-size:20px;margin-bottom:16px">${q}</div>
          ${opts.map(([l, v]) => `<button class="opt" data-act="answer" data-val="${v}"><span class="radio"></span><span class="grow">${l}</span></button>`).join('')}`,
        footer: k ? '<button class="btn ghost" data-act="prev">上一题</button>' : '',
      };
    }
    if (ctx.stage === 'result') {
      const score = sum(ctx.ans);
      const st = STYLES.find((x) => score <= x.max);
      ctx.style = st;
      return {
        title: '您的组合',
        body: `${C.notice('warn', '<b>合规待确认：</b>根据问卷生成个性化组合并一键执行，可能被认定为投资顾问服务，与"自主账户"定位冲突。上线前需合规评估（pages.md 问题 3）。' + C.tag('6'))}
          <div class="card"><div class="xs muted">风险评分 ${score} / 40</div><div class="b" style="font-size:22px">${st.name}</div><div class="small muted mt8">${st.desc}</div></div>
          <div class="card row" style="gap:16px">${donut(st.holdings.map(([s, w], k) => ({ v: w, color: ['#6C5BF5', '#D63AA8', '#F0A13C', '#3B82F6'][k] })), 110, `<span class="b">${st.holdings.length} 只</span>`)}
            <div class="grow">${st.holdings.map(([s, w], k) => `<div class="row between small" style="padding:4px 0"><span class="row" style="gap:6px"><i style="width:8px;height:8px;border-radius:50%;background:${['#6C5BF5', '#D63AA8', '#F0A13C', '#3B82F6'][k]};display:inline-block"></i>${s}</span><b class="num">${fmt.pct(w, { sign: false, dp: 0 })}</b></div>`).join('')}</div></div>
          <div class="sec-title" style="font-size:15px">配置理由</div>
          <div class="list">${st.holdings.map(([s]) => C.li({ title: `${s} · ${esc(Acc.inst(s).name)}`, sub: Acc.inst(s).etfCategory ? `${Acc.inst(s).etfCategory}类 ETF，用于分散配置` : '核心持仓', go: `#/p10?symbol=${s}` })).join('')}</div>
          <div class="xs faint">过往表现不代表未来收益。此结果仅供参考。</div>`,
        footer: '<button class="btn ghost" data-act="restart">重新测试</button><button class="btn primary" data-act="basket">一键加入</button>',
      };
    }
    return {
      title: '智能组合',
      body: `<div class="card"><div class="xs muted">智能组合</div><div class="b" style="font-size:20px;margin-top:4px">不知道买什么？</div><div class="small muted mt8">回答 10 个问题，根据您的目标、期限和风险偏好，生成一份组合建议，并说明每项配置的理由。</div></div>
        <div class="list">${C.li({ icon: 'book', title: '01 · 问卷', sub: '目标、期限与对波动的感受' })}${C.li({ icon: 'pie', title: '02 · 匹配', sub: '与您风险评分匹配的组合风格' })}${C.li({ icon: 'check', title: '03 · 一键加入', sub: '一次性提交组合内全部订单' })}</div>
        <div class="row wrap gap8 mb16">${STYLES.map((s) => `<span class="badge">${s.name}</span>`).join('')}</div>
        ${C.notice('warn', '此功能需合规评估后才能上线（清单 6）。' + C.tag('6'))}`,
      footer: '<button class="btn primary" data-act="start">开始问卷</button>',
    };
  },
  actions: {
    start(el, ctx) { ctx.stage = 'quiz'; ctx.ans = []; Router.refresh(); },
    answer(el, ctx) { ctx.ans.push(Number(el.dataset.val)); Router.refresh(); },
    prev(el, ctx) { ctx.ans.pop(); Router.refresh(); },
    restart(el, ctx) { ctx.stage = 'quiz'; ctx.ans = []; Router.refresh(); },
    basket(el, ctx) {
      const s = Store.state;
      if (!s.loggedIn) return Router.go('#/p02?mode=login');
      if (Acc.cur().status !== 'ACTIVE') return UI.alert('交易账户暂不可用', '请先开户，或切换到模拟账户。');
      const sm = Acc.summary();
      const budget = Math.min(1000, Math.floor(sm.buyingPower));
      ctx.basket = ctx.style.holdings.map(([sym, w]) => { const px = Acc.quote(sym).ask; return { sym, w, qty: round4((budget * w) / px), px }; });
      UI.sheet('确认组合订单', `<div class="small muted mb12">按 ${fmt.usd(budget)} 投资金额、市价单买入以下 ETF（支持小数股）。</div>
        <div class="card" style="padding:4px 14px"><table class="table"><tr><th>代码</th><th>权重</th><th>数量</th><th>预估金额</th></tr>${ctx.basket.map((b) => `<tr><td class="b">${b.sym}</td><td>${fmt.pct(b.w, { sign: false, dp: 0 })}</td><td class="num">${fmt.qty(b.qty)}</td><td class="num">${fmt.usd(b.qty * b.px)}</td></tr>`).join('')}</table></div>
        ${C.kv('佣金及费用' + C.tag('12'), '$0.00')}
        <button class="btn primary mt12" data-act="placeBasket">确认提交 ${ctx.basket.length} 笔订单</button>`);
    },
    placeBasket(el, ctx) {
      ctx.basket.forEach((b) => Acc.placeOrder({ symbol: b.sym, side: 'BUY', orderType: 'MARKET', qty: b.qty, tif: 'DAY' }));
      UI.closeAll(); UI.toast('组合订单已提交'); Router.go('#/p11');
    },
  },
};

/* ---------- P-26 AI 助手（即将推出） ---------- */
const DECO = `<svg class="deco" width="150" height="150" viewBox="0 0 150 150" fill="none"><circle cx="90" cy="90" r="58" stroke="rgba(255,255,255,.18)" stroke-width="2"/><circle cx="90" cy="90" r="36" stroke="rgba(255,255,255,.25)" stroke-width="2"/><path d="M48 104l20-22 16 12 28-36" stroke="#fff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/><circle cx="112" cy="58" r="6" fill="#fff"/></svg>`;
Pages.p26 = {
  render() {
    const sub = Store.state.subs.ai;
    const feats = [['pie', '持仓体检', '分析持仓结构与未实现盈亏'], ['swap', '持有或卖出', '对比趋势、风险与仓位'], ['search', '个股研究', '汇总价格、基本面与新闻'], ['warn', '风险提醒', '识别波动、集中度与回撤'], ['bars', '量化信号', '动量、反转、成交量等因子'], ['book', '投资课堂', '用简单的语言理解投资逻辑']];
    return {
      title: 'AI 助手', tab: 'ai',
      right: `<span class="badge" style="margin-right:6px">${Icon('lock', 12)}&nbsp;XP</span>`,
      body: `<div class="soon"><div class="xs" style="opacity:.7">Fifi 量化助手</div><h2>即将推出</h2><p>Fifi 正在学习分析图表、风险和持仓，敬请期待。</p><img class="mascot-side" src="assets/fifi_paw.png" alt="Fifi"></div>
        <div class="feat-grid">${feats.map(([ic, t, d], k) => `<div class="feat"><span class="li-ic">${Icon(ic, 18)}</span><span class="lk">${Icon('lock', 14)}</span><div class="t">${k + 1}. ${t}</div><div class="d">${d}</div></div>`).join('')}</div>
        ${C.notice('warn', '上线前需评估是否构成投资建议（参见清单 6）。' + C.tag('6'))}
        <button class="btn ${sub ? 'ghost' : 'secondary'} mt8" data-act="sub">${Icon('bell', 18)} ${sub ? '已订阅上线提醒' : '上线提醒我'}</button>
        <div class="xs faint center mt8">上线后我们会通知您</div>`,
    };
  },
  actions: { sub() { const s = Store.state; s.subs.ai = !s.subs.ai; Store.save(); UI.toast(s.subs.ai ? '已订阅上线提醒' : '已取消提醒'); Router.refresh(); } },
};

/* ---------- P-27 奖励中心（即将推出） ---------- */
Pages.p27 = {
  render(p, ctx) {
    ctx.lv = ctx.lv || '1';
    const sub = Store.state.subs.rewards;
    const items = { 1: [['新手徽章', 200], ['主题皮肤', 300], ['专属头像框', 250], ['学习卡片', 150]], 2: [['高级图表主题', 600], ['动态头像框', 800]], 3: [['年度纪念徽章', 1500]], 4: [['神秘奖励', 3000]] };
    return {
      title: '奖励', tab: 'rewards',
      right: `<span class="badge" style="margin-right:6px">${Icon('lock', 12)}&nbsp;0 XP</span>`,
      body: `<div class="soon" style="background:linear-gradient(120deg,#8A3FE0,#D63AA8 60%,#F0A13C)"><div class="xs" style="opacity:.7">奖励中心</div><h2>即将推出</h2><p>完成学习任务赚取积分，解锁徽章、主题与更多奖励。</p>${DECO}</div>
        ${C.seg('lv', [['1', '等级 1'], ['2', '等级 2 🔒'], ['3', '等级 3 🔒'], ['4', '等级 4 🔒']], ctx.lv)}
        <div class="reward-grid">${(items[ctx.lv] || []).map(([n, xp]) => `<div class="feat center"><span class="lk">${Icon('lock', 14)}</span><div class="state-ic" style="width:56px;height:56px;margin:4px auto 8px">${Icon('gift', 26)}</div><div class="t">${n}</div><div class="xs muted">${xp} XP</div><div class="badge mt8">即将推出</div></div>`).join('')}</div>
        ${C.notice('info', '若积分获取与入金或交易行为挂钩，需确认相关激励合规要求。')}
        <button class="btn ${sub ? 'ghost' : 'secondary'} mt8" data-act="sub">${Icon('bell', 18)} ${sub ? '已订阅上线提醒' : '上线提醒我'}</button>`,
    };
  },
  actions: {
    lv(el, ctx) { ctx.lv = el.dataset.val; Router.refresh(); },
    sub() { const s = Store.state; s.subs.rewards = !s.subs.rewards; Store.save(); UI.toast(s.subs.rewards ? '已订阅上线提醒' : '已取消提醒'); Router.refresh(); },
  },
};

/* ---------- S-01 全局状态页 ---------- */
Pages.s01 = {
  render(p) {
    const t = p.type || 'expired';
    const map = {
      loading: { ic: null, h: '正在加载您的申请', d: '正在为您准备，请稍候。', btns: '' },
      expired: { ic: 'lock', h: '请重新登录', d: '登录已过期或尚未登录。返回 App 登录后即可继续您的申请。', btns: '<button class="btn primary" data-act="relogin">返回登录</button><button class="btn ghost" data-act="retry">重试</button>' },
      error: { ic: 'warn', h: '网络开小差了', d: '请检查网络连接后重试。', btns: '<button class="btn primary" data-act="retry">重试</button>' },
      empty: { ic: 'doc', h: '这里还没有内容', d: '稍后再来看看。', btns: '<button class="btn ghost" data-go="#/p07">返回首页</button>' },
      unavailable: { ic: 'shield', h: '交易账户暂不可用', d: '系统维护中，预计 30 分钟内恢复。资金和持仓安全不受影响。', btns: '<button class="btn ghost" data-go="#/p07">返回首页</button>' },
      restricted: (() => { const r = Acc.restriction() || { title: '账户受限', body: '您的账户目前受到限制。' }; return { ic: 'lock', h: r.title, d: `${r.body}<br><span class="xs muted">账户状态由合作券商 DriveWealth 设定。限制期间资产仍安全托管，可继续查看持仓、订单和文件。</span>`, btns: '<button class="btn primary" data-act="cs">联系客服</button><button class="btn ghost" data-go="#/p07">返回首页</button>' }; })(),
      notfound: { ic: 'search', h: '页面不存在', d: '链接可能已失效。', btns: '<button class="btn primary" data-go="#/p07">返回首页</button>' },
    }[t] || {};
    const types = [['loading', '加载中'], ['expired', '会话过期'], ['error', '网络错误'], ['empty', '空状态'], ['unavailable', '不可用'], ['restricted', '账户受限']];
    return {
      title: '',
      body: `<div class="state" style="min-height:85%">${map.ic ? `<div class="state-ic">${Icon(map.ic, 36)}</div>` : '<div class="spinner" style="margin-bottom:22px"></div>'}<h2>${map.h}</h2><p>${map.d}</p><div class="col gap8 mt24" style="width:100%">${map.btns}</div></div>
        <div class="xs faint center">原型：切换状态类型 ${types.map(([k, l]) => `<button class="link-btn xs" data-go="#/s01?type=${k}">${l}</button>`).join(' · ')}</div>`,
    };
  },
  actions: { cs() { UI.toast('（原型）已转接客服'); }, relogin() { Store.state.loggedIn = false; Store.save(); Router.go('#/p02?mode=login'); }, retry() { UI.toast('正在重试…'); setTimeout(() => Router.go('#/p07'), 600); } },
};

/* 第 4 版：P-25、P-26 首期不做，待合规评估（页面规格保留，仅供评估） */
['p25', 'p26'].forEach((id) => {
  const base = Pages[id].render;
  Pages[id].render = function (p, ctx) {
    const out = base.call(this, p, ctx);
    out.body = C.notice('warn', `<b>首期不做，待合规评估</b><br>以下为保留的页面规格，仅供评估，不会在首期上线。${C.tag('6')}`) + out.body;
    return out;
  };
});
