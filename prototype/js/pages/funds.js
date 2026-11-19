'use strict';
/* P-13 入金、P-14 出金、P-15 文件、P-16 设置、P-17 通知、P-18 历史记录、P-28 ACATS、P-29 帮助、P-31 – P-33 资金账户
   资金方式只使用 DriveWealth 支持的 ACH（Plaid 绑定本人美国银行账户）与电汇。 */

// 资金阈值：示例值，待业务与合规确认（pages.md 第 5 节问题 5、14）
const LIMITS = { minDeposit: 10, maxDeposit: 50000, dailyDeposit: 50000, minWithdrawal: 1, maxWithdrawal: 50000, minWire: 100, maxBanks: Fund.max, cutoff: '美东时间 16:00', wireCutoff: '美东时间 15:00' };
const THRESHOLD_NOTE = `<span class="badge warn">示例阈值，待确认</span>`;

function nextBizDay(n = 1) {
  const d = new Date(); let k = 0;
  while (k < n) { d.setDate(d.getDate() + 1); if (d.getDay() !== 0 && d.getDay() !== 6) k++; }
  return d.toISOString().slice(0, 10);
}
const today = () => new Date().toISOString().slice(0, 10);
/* DW 文档中的资金时效（均待 DW 确认，见 pages.md 3.1.5）
   - 购买力：结算后授予，通常 4–5 个工作日 —— https://developer.drivewealth.com/apis/docs/depositing-1
   - "即时购买力"：step-6 页面可打开但不含入金与购买力内容，'即时购买力'无 DW 出处，不采用 —— https://developer.drivewealth.com/implementation/docs/step-6-domestic-funding-overview
   - 观察期：ACH 默认 30 天、电汇无 —— https://developer.drivewealth.com/apis/docs/depositing-1 ；https://info.drivewealth.com/funding-withdrawal-policies
   - 5 个工作日法律持有期：规划不采用，待 DW 确认 —— https://legal.drivewealth.com/funding-withdrawal-policies
   - 可提现金额：以 DW 返回的 cashAvailableForWithdrawal 为准，本原型的扣减仅为模拟 —— https://developer.drivewealth.com/apis/docs/withdrawing-1
   - 入金类型示例值：ACH（depositing-1）、CASH_PROMOTION —— https://developer.drivewealth.com/apis/docs/cash-promotions
   - 出金：ACH $0.25、电汇美东 17:00 前当日处理、电汇费用金额未给出 —— https://developer.drivewealth.com/apis/docs/individual-funding */
const ACH_BP_TEXT = 'ACH 入金结算后授予购买力，通常 4–5 个工作日（待 DW 确认）';
const SEASONING_DAYS = 30; // ACH 入金观察期：默认 30 天，可由 DW 配置调整（待 DW 确认）；电汇入金不受此限制
const DEPOSIT_TYPE_NOTE = '入金类型（DW <code>type</code>）文档示例值：ACH、CASH_PROMOTION；完整枚举待 DW 确认';
const txMethod = (t) => t.method || (/^电汇/.test(t.desc || '') ? 'WIRE' : 'ACH');
/** 仍在 ACH 观察期内的已到账入金金额。实际可提现金额以 DW 返回的 cashAvailableForWithdrawal 为准（原型模拟） */
function achSeasoningHold(a = Acc.cur()) {
  const now = Date.now();
  return round2(sum((a.transactions || []).filter((t) => t.type === 'DEPOSIT' && txMethod(t) === 'ACH' && (t.dwStatus === 'SUCCESSFUL' || (!t.dwStatus && t.status === '已到账'))
    && (now - new Date(String(t.doneAt || t.date).replace(' ', 'T')).getTime()) / 86400000 < SEASONING_DAYS), (t) => t.amount));
}
function bankList(sel) {
  return Store.state.linkedBanks.map((b) => `<button class="opt ${sel === b.id ? 'on' : ''}" data-act="pickBank" data-id="${b.id}"><span class="radio"></span>${Icon('bank', 22)}<div class="grow"><div class="b">${esc(b.name)} ••${esc(b.mask)}</div><div class="xs muted">${b.type === 'SAVINGS' ? '储蓄' : '支票'}账户 · 户名 ${esc(b.owner)} · ${b.status === 'VERIFIED' ? '已验证' : '验证中'}</div></div></button>`).join('');
}
function holderName() { const d = Store.state.application.data; return `${d.firstName || ''} ${d.lastName || ''}`.trim(); }
const hasPendingTransfer = (a = Store.state.accounts.LIVE) => (a.transactions || []).some((t) => (t.type === 'DEPOSIT' || t.type === 'WITHDRAWAL') && t.dwStatus === 'PENDING');
function fundsBlocked(title) {
  const r = Acc.restriction();
  if (!r || !r.noFunds) return null;
  return { title, body: `${C.restrict()}<div class="state" style="min-height:auto"><div class="state-ic">${Icon('lock', 32)}</div><h2>暂不能${title}</h2><p>账户冻结期间不能进行资金划转。</p><button class="btn ghost mt16" data-act="cs">联系客服</button></div>` };
}
const bankActions = {
  pickBank(el, ctx) { ctx.bank = el.dataset.id; Router.refresh(); },
  addBank() { Router.hasHistory = true; Router.go(Fund.bindHref(Router.current.id)); },
  cs() { UI.toast('（原型）已转接客服'); },
};

/* ---------- P-13 入金（ACH / 电汇） ---------- */
Pages.p13 = {
  auth: true,
  render(p, ctx) {
    const a = Acc.cur();
    if (a.status !== 'ACTIVE') return notReady('入金');
    const paper = Store.state.mode === 'PAPER';
    const f = ctx.form || (ctx.form = { amount: '' });
    if (paper) {
      return { title: '入金', body: `${C.notice('info', '当前为模拟账户，入金为虚拟资金，不涉及真实资金划转。')}${C.field({ label: '虚拟入金金额 (USD)', bind: 'amount', value: f.amount, attrs: 'inputmode="decimal"' })}`, footer: '<button class="btn primary" data-act="paperDeposit">确认</button>' };
    }
    const blocked = fundsBlocked('入金'); if (blocked) return blocked;
    ctx.step = ctx.step || 'method';
    const banks = Store.state.linkedBanks;
    if (ctx.step === 'method') {
      const wire = Fund.preferWire();
      return {
        title: '入金',
        body: `${C.restrict()}<div class="sec-title">选择入金方式</div>
          <button class="opt ${!wire ? 'on' : ''}" data-act="pickAch"><span class="radio"></span>${Icon('bank', 22)}<div class="grow"><div class="b">银行转账（ACH）</div><div class="xs muted">${banks.length ? `已绑定 ${banks.length} 个本人美国银行账户 · 免手续费` : '需先绑定本人名下的美国银行账户'}</div></div>${Icon('right', 16, 'chev')}</button>
          <button class="opt ${wire ? 'on' : ''}" data-go="#/p33"><span class="radio"></span>${Icon('globe', 22)}<div class="grow"><div class="b">电汇${wire ? ' · 推荐' : ''}</div><div class="xs muted">从本人名下银行账户汇款，适用于境外银行或大额入金</div></div>${Icon('right', 16, 'chev')}</button>
          ${C.notice('info', `${ACH_BP_TEXT}。ACH 入金到账后默认有 ${SEASONING_DAYS} 天观察期，期间不可提现，可由 DW 配置调整（待 DW 确认）。电汇以银行实际到账时间为准，不受观察期限制。${C.tag('20')}`)}
          <div class="xs faint mb12">${DEPOSIT_TYPE_NOTE}</div>
          ${C.notice('info', `只接受来自<b>本人名下</b>账户的资金，第三方转账将被退回。${C.tag('PDF-3')}`)}`,
      };
    }
    if (ctx.step === 'form') {
      ctx.bank = ctx.bank || banks[0]?.id;
      const amt = parseFloat(f.amount) || 0;
      const todayTotal = sum(Store.state.deposits.filter((d) => d.date === today()), (d) => d.amount);
      let err = '';
      if (f.amount && amt < LIMITS.minDeposit) err = `单笔最低入金 ${fmt.usd(LIMITS.minDeposit)}`;
      else if (amt > LIMITS.maxDeposit) err = `单笔最高入金 ${fmt.usd(LIMITS.maxDeposit)}`;
      else if (amt + todayTotal > LIMITS.dailyDeposit) err = `超过每日入金上限 ${fmt.usd(LIMITS.dailyDeposit)}`;
      ctx.ok = amt > 0 && !err && ctx.bank;
      return {
        title: 'ACH 入金',
        body: `<div class="sec-title" style="font-size:15px">转出银行账户</div>
          ${bankList(ctx.bank)}
          <button class="link-btn xs mb16" data-go="#/p31">管理银行账户（${banks.length}/${LIMITS.maxBanks}）</button>
          ${C.field({ label: '入金金额 (USD)' + C.tag('PDF-3'), bind: 'amount', value: f.amount, attrs: 'inputmode="decimal"', placeholder: '0.00', error: err, hint: `单笔 ${fmt.usd(LIMITS.minDeposit)} – ${fmt.usd(LIMITS.maxDeposit)}，每日上限 ${fmt.usd(LIMITS.dailyDeposit)}` })}
          <div class="row mb16">${THRESHOLD_NOTE}</div>
          <div class="card">${C.kv('提交截止时间' + C.tag('20'), `工作日 ${LIMITS.cutoff}（示例，待 DW 确认）`)}${C.kv('购买力到账', '结算后授予购买力，通常 4–5 个工作日（待 DW 确认）')}${C.kv('可提现时间', `到账后 ${SEASONING_DAYS} 天观察期结束（默认，待 DW 确认）`)}${C.kv('入金类型', 'ACH')}${C.kv('手续费', '$0.00')}</div>
          <div class="xs faint mb12">${ACH_BP_TEXT}。</div>
          ${C.notice('warn', '<b>退回提示：</b>如银行退回此笔转账（如余额不足），使用该笔资金买入的证券可能被限制卖出或强制平仓，并可能产生退回费用；账户入金功能也可能被暂停。')}`,
        footer: `<button class="btn primary" data-act="toConfirm" ${ctx.ok ? '' : 'disabled'} id="nextBtn">下一步</button>`,
      };
    }
    if (ctx.step === 'confirm') {
      const b = banks.find((x) => x.id === ctx.bank);
      return {
        title: '确认入金',
        body: `<div class="card center"><div class="xs muted">入金金额</div><div class="b num" style="font-size:30px">${fmt.usd(parseFloat(f.amount))}</div></div>
          <div class="card">${C.kv('从', `${esc(b.name)} ••${esc(b.mask)}`)}${C.kv('到', `证券账户 ${esc(Acc.cur().accountNumber)}`)}${C.kv('方式', 'ACH')}${C.kv('手续费', '$0.00')}${C.kv('购买力到账', '结算后授予购买力，通常 4–5 个工作日（待 DW 确认）')}${C.kv('可提现时间', `到账后 ${SEASONING_DAYS} 天（默认，待 DW 确认）`)}</div>
          <div class="xs muted">确认即授权从上述银行账户扣款。资金由 DriveWealth 托管。</div>`,
        footer: '<button class="btn ghost" data-act="toForm">返回修改</button><button class="btn primary" data-act="doDeposit">确认入金</button>',
      };
    }
    const d = ctx.result;
    return {
      title: '入金已提交', noBack: true,
      body: `<div class="state" style="min-height:auto;padding-top:28px"><div class="state-ic">${Icon('check', 36)}</div><h2>入金申请已提交</h2><p>${ACH_BP_TEXT}。到账后我们会通知您。</p></div>
        <div class="card">${C.kv('流水号', d.id)}${C.kv('金额', fmt.usd(d.amount))}${C.kv('状态', C.badge('处理中', 'warn'))}</div>`,
      footer: `<button class="btn ghost" data-go="#/p18?id=${d.id}">查看进度</button><button class="btn primary" data-go="#/p07">完成</button>`,
    };
  },
  onInput(el, ctx) {
    if (ctx.step !== 'form') return;
    const amt = parseFloat(el.value) || 0;
    let err = '';
    if (el.value && amt < LIMITS.minDeposit) err = `单笔最低入金 ${fmt.usd(LIMITS.minDeposit)}`;
    else if (amt > LIMITS.maxDeposit) err = `单笔最高入金 ${fmt.usd(LIMITS.maxDeposit)}`;
    showFieldErr('amount', err);
    const btn = $('#nextBtn'); if (btn) btn.disabled = !(amt > 0 && !err && ctx.bank);
  },
  actions: {
    ...bankActions,
    pickAch(el, ctx) {
      if (!Store.state.linkedBanks.length) { Router.hasHistory = true; return Router.go(Fund.bindHref('p13')); }
      ctx.step = 'form'; Router.refresh();
    },
    toForm(el, ctx) { ctx.step = 'form'; Router.refresh(); },
    toConfirm(el, ctx) { Router.refresh(); if (ctx.ok) { ctx.step = 'confirm'; Router.refresh(); } },
    doDeposit(el, ctx) {
      const amount = round2(parseFloat(ctx.form.amount));
      const a = Acc.cur();
      const b = Store.state.linkedBanks.find((x) => x.id === ctx.bank);
      const id = 'DEP-' + Date.now().toString().slice(-8);
      Store.state.deposits.push({ id, amount, date: today() });
      a.transactions.unshift({ id, type: 'DEPOSIT', method: 'ACH', amount, date: today(), status: '处理中', dwStatus: 'PENDING', submittedAt: nowStr(), desc: `ACH 入金 · ${b.name} ••${b.mask}` });
      Store.save();
      ctx.result = { id, amount };
      ctx.step = 'done'; Router.refresh();
    },
    paperDeposit(el, ctx) {
      const amt = parseFloat(ctx.form.amount) || 0;
      if (amt <= 0) return UI.toast('请输入金额');
      const a = Acc.cur(); a.cash = round2(a.cash + amt); Store.save(); UI.toast('虚拟资金已到账'); Router.go('#/p07');
    },
  },
};

/* ---------- P-14 出金（ACH / 电汇） ---------- */
Pages.p14 = {
  auth: true,
  render(p, ctx) {
    const a = Acc.cur();
    if (a.status !== 'ACTIVE') return notReady('出金');
    if (Store.state.mode === 'PAPER') return { title: '出金', body: C.notice('info', '模拟账户不支持出金。') };
    const blocked = fundsBlocked('出金'); if (blocked) return blocked;
    const sm = Acc.summary(a);
    const hold = achSeasoningHold(a);
    const withdrawable = Math.max(0, round2(sm.withdrawable - hold));
    const banks = Store.state.linkedBanks;
    const f = ctx.form || (ctx.form = { amount: '', method: banks.length ? 'ACH' : 'WIRE' });
    ctx.bank = ctx.bank || banks[0]?.id;
    if (ctx.step === 'done') {
      return { title: '出金已提交', noBack: true, body: `<div class="state" style="min-height:auto;padding-top:28px"><div class="state-ic">${Icon('check', 36)}</div><h2>出金申请已提交</h2><p>${f.method === 'WIRE' ? '美东时间 17:00 前提交的电汇出金当日处理，到账以收款行为准（待 DW 确认）' : 'ACH 出金通常需要 4–5 个工作日（待 DW 确认）'}。</p></div><div class="card">${C.kv('流水号', ctx.result.id)}${C.kv('方式', f.method === 'WIRE' ? '电汇' : 'ACH')}${C.kv('金额', fmt.usd(ctx.result.amount))}${C.kv('状态', C.badge('处理中', 'warn'))}</div>`, footer: `<button class="btn ghost" data-go="#/p18?id=${ctx.result.id}">查看进度</button><button class="btn primary" data-go="#/p07">完成</button>` };
    }
    const wire = f.method === 'WIRE';
    const amt = parseFloat(f.amount) || 0;
    const min = wire ? LIMITS.minWire : LIMITS.minWithdrawal;
    let err = '';
    if (f.amount && amt < min) err = `单笔最低 ${fmt.usd(min)}`;
    else if (amt > withdrawable) err = '超过可提现金额';
    else if (amt > LIMITS.maxWithdrawal) err = `单笔最高 ${fmt.usd(LIMITS.maxWithdrawal)}`;
    const wireErr = ctx.wireErr || {};
    const wireOk = !wire || ['wBank', 'wAcct', 'wSwift', 'wCountry'].every((k) => (f[k] || '').trim());
    const recipient = wire ? `电汇 · ${esc(f.wBank || '')} ${f.wAcct ? '••' + esc(String(f.wAcct).slice(-4)) : ''}` : (() => { const b = banks.find((x) => x.id === ctx.bank); return b ? `${esc(b.name)} ••${esc(b.mask)}` : '—'; })();
    if (ctx.step === 'confirm') {
      return {
        title: '确认出金',
        body: `<div class="card center"><div class="xs muted">出金金额</div><div class="b num" style="font-size:30px">${fmt.usd(amt)}</div></div>
          <div class="card">${C.kv('从', `证券账户 ${esc(a.accountNumber)}`)}${C.kv('到', recipient)}${wire ? C.kv('收款人', esc(holderName())) : ''}${C.kv('方式', wire ? '电汇（WIRE）' : 'ACH')}${C.kv('手续费', wire ? '按 DW 电汇出金收费标准（待 DW 确认）' : '$0.25（DW 文档，待 DW 确认）')}${C.kv('预计到账', wire ? '美东 17:00 前提交当日处理（待 DW 确认）' : '通常 4–5 个工作日（待 DW 确认）')}</div>`,
        footer: '<button class="btn ghost" data-act="back2">返回修改</button><button class="btn primary" data-act="doWithdraw">确认出金</button>',
      };
    }
    return {
      title: '出金',
      body: `${C.restrict()}<div class="card">${C.kv('<b style="color:var(--text)">可提现金额</b>' + C.tag('PDF-3'), `<b class="num">${fmt.usd(withdrawable)}</b>`)}${C.kv('账户现金', fmt.usd(sm.cash))}${C.kv('未结算资金', fmt.usd(a.unsettled))}${C.kv('待成交买单占用', fmt.usd(Acc.reservedForBuys(a)))}${C.kv(`ACH 入金观察期内金额（${SEASONING_DAYS} 天）`, fmt.usd(hold))}
          <div class="xs faint mt8">卖出证券所得需结算后（通常 T+1）才可提现。ACH 入金到账后须满 ${SEASONING_DAYS} 天观察期才可提现：默认 ${SEASONING_DAYS} 天，可由 DW 配置调整（待 DW 确认）；电汇入金不受此限制。实际可提现金额以 DW 返回的 cashAvailableForWithdrawal 为准，此处扣减仅为原型模拟。</div></div>
        ${C.seg('method', [['ACH', '银行转账（ACH）'], ['WIRE', '电汇']], f.method, 'seg2')}
        ${wire ? `
          ${C.notice('info', '电汇只能汇入<b>本人名下</b>的银行账户，收款人固定为账户持有人。')}
          ${C.field({ label: '收款人', bind: '_ben', value: holderName(), attrs: 'disabled' })}
          ${C.field({ label: '收款银行名称', bind: 'wBank', value: f.wBank, error: wireErr.wBank })}
          ${C.field({ label: '收款账号 / IBAN', bind: 'wAcct', value: f.wAcct, error: wireErr.wAcct, attrs: 'autocomplete="off"' })}
          ${C.two({ label: 'SWIFT / ABA', bind: 'wSwift', value: f.wSwift, error: wireErr.wSwift, attrs: 'autocomplete="off"' }, { label: '银行所在国家/地区', bind: 'wCountry', value: f.wCountry, options: COUNTRIES, error: wireErr.wCountry })}
          ${C.field({ label: '中转行 SWIFT（选填）', bind: 'wInter', value: f.wInter })}`
        : `<div class="sec-title" style="font-size:15px">收款银行账户</div>
          ${banks.length ? bankList(ctx.bank) : C.notice('warn', '尚未绑定银行账户。')}
          <button class="btn ghost sm mb16" data-act="addBank">${Icon('plus', 16)} 绑定银行账户</button>`}
        ${C.field({ label: '出金金额 (USD)', bind: 'amount', value: f.amount, attrs: 'inputmode="decimal"', placeholder: '0.00', error: err, hint: `单笔 ${fmt.usd(min)} – ${fmt.usd(LIMITS.maxWithdrawal)}` })}
        <div class="row mb12">${THRESHOLD_NOTE}</div>
        ${C.kv('手续费', wire ? '按 DW 电汇出金收费标准（待 DW 确认）' : '$0.25（DW 文档，待 DW 确认）')}${C.kv('预计到账', wire ? '美东 17:00 前提交当日处理（待 DW 确认）' : '通常 4–5 个工作日（待 DW 确认）')}`,
      footer: `<button class="btn primary" data-act="toConfirm" ${amt > 0 && !err && (wire ? true : ctx.bank) ? '' : 'disabled'}>下一步</button>`,
    };
  },
  onInput(el, ctx) {
    if (el.dataset.bind !== 'amount' && el.tagName !== 'SELECT') return;
    Router.refresh(); setTimeout(() => { const i = $(`[data-bind="${el.dataset.bind}"]`); if (i && i.setSelectionRange) { i.focus(); i.setSelectionRange(i.value.length, i.value.length); } });
  },
  actions: {
    ...bankActions,
    method(el, ctx) { ctx.form.method = el.dataset.val; ctx.wireErr = {}; Router.refresh(); },
    toConfirm(el, ctx) {
      const f = ctx.form;
      if (f.method === 'WIRE') {
        const e = {};
        if (!(f.wBank || '').trim()) e.wBank = '请输入收款银行名称';
        if (!(f.wAcct || '').trim()) e.wAcct = '请输入收款账号';
        if (!(f.wSwift || '').trim()) e.wSwift = '请输入 SWIFT 或 ABA';
        if (!f.wCountry) e.wCountry = '请选择国家/地区';
        ctx.wireErr = e;
        if (Object.keys(e).length) return Router.refresh();
      }
      ctx.step = 'confirm'; Router.refresh();
    },
    back2(el, ctx) { ctx.step = null; Router.refresh(); },
    doWithdraw(el, ctx) {
      const f = ctx.form;
      const amount = round2(parseFloat(f.amount));
      const a = Acc.cur();
      const wire = f.method === 'WIRE';
      const b = Store.state.linkedBanks.find((x) => x.id === ctx.bank);
      a.cash = round2(a.cash - amount);
      const id = 'WDL-' + Date.now().toString().slice(-8);
      a.transactions.unshift({ id, type: 'WITHDRAWAL', method: wire ? 'WIRE' : 'ACH', amount: -amount, date: today(), status: '处理中', dwStatus: 'PENDING', submittedAt: nowStr(), desc: wire ? `电汇出金 · ${f.wBank} ••${String(f.wAcct).slice(-4)}` : `ACH 出金 · ${b.name} ••${b.mask}` });
      Store.save(); ctx.result = { id, amount }; ctx.step = 'done'; Router.refresh();
    },
  },
};

/* ---------- P-31 资金账户管理（ACH 银行账户） ---------- */
Pages.p31 = {
  auth: true,
  render() {
    const s = Store.state;
    if (s.accounts.LIVE.status !== 'ACTIVE') return notReady('银行账户');
    const banks = s.linkedBanks;
    const pending = hasPendingTransfer();
    return {
      title: '银行账户',
      body: `<div class="row between mb8"><span class="small muted">已绑定 ${banks.length} / ${LIMITS.maxBanks} 个${C.tag('PDF-3')}</span>${THRESHOLD_NOTE}</div>
        ${banks.length ? `<div class="list">${banks.map((b) => `<div class="li"><span class="li-ic">${Icon('bank', 18)}</span><span class="grow"><div class="li-title">${esc(b.name)} ••${esc(b.mask)}</div><div class="li-sub">${b.type === 'SAVINGS' ? '储蓄' : '支票'}账户 · 户名 ${esc(b.owner)} · ${b.status === 'VERIFIED' ? '已验证' : '验证中'}${b.createdAt ? ' · ' + b.createdAt : ''}</div></span><button class="btn ghost sm" data-act="unlink" data-id="${b.id}">解绑</button></div>`).join('')}</div>`
          : C.empty('bank', '还没有绑定银行账户')}
        <button class="btn primary mt12" data-act="addBank" ${banks.length >= LIMITS.maxBanks ? 'disabled' : ''}>${Icon('plus', 16)} 绑定新银行账户</button>
        ${banks.length >= LIMITS.maxBanks ? '<div class="xs muted center mt8">已达绑定上限，如需更换请先解绑。</div>' : ''}
        ${pending ? C.notice('info', '有处理中的入金或出金，完成前不能解绑银行账户。') : ''}
        ${C.notice('info', `只能绑定<b>本人名下</b>的美国银行账户，户名须与证券账户一致。没有美国银行账户？可以<button class="link-btn" data-go="#/p33">通过电汇入金</button>。`)}`,
    };
  },
  actions: {
    ...bankActions,
    unlink(el) {
      if (hasPendingTransfer()) return UI.alert('暂不能解绑', '有处理中的入金或出金，完成后才能解绑此银行账户。');
      const b = Store.state.linkedBanks.find((x) => x.id === el.dataset.id);
      UI.confirm({ title: '解绑银行账户？', body: `${esc(b.name)} ••${esc(b.mask)} 解绑后不能再用于入金和出金。`, ok: '解绑', danger: true, onOk: () => { Store.state.linkedBanks = Store.state.linkedBanks.filter((x) => x !== b); Store.save(); UI.toast('已解绑'); Router.refresh(); } });
    },
  },
};

/* ---------- P-32 绑定银行账户（Plaid） ---------- */
const PLAID_BANKS = ['示例银行 A', '示例银行 B', '示例信用社 C'];
Pages.p32 = {
  auth: true,
  backTo: '#/p31',
  render(p, ctx) {
    const s = Store.state;
    if (s.accounts.LIVE.status !== 'ACTIVE') return notReady('银行账户');
    ctx.step = ctx.step || 'intro';
    const from = p.from || 'p31';
    if (s.linkedBanks.length >= LIMITS.maxBanks && ctx.step !== 'done') {
      return { title: '绑定银行账户', body: `${C.notice('warn', `每个账户最多绑定 ${LIMITS.maxBanks} 个银行账户。如需更换，请先解绑。`)}<button class="btn ghost" data-go="#/p31">管理银行账户</button>` };
    }
    if (ctx.step === 'intro') {
      return {
        title: '绑定银行账户',
        body: `<div class="state" style="min-height:auto;padding:16px 0 4px"><div class="state-ic">${Icon('bank', 34)}</div><h2>通过 Plaid 安全绑定</h2><p>接下来将打开第三方服务 Plaid 的授权页面，登录您的网上银行并选择账户。</p></div>
          <div class="list">
            ${C.li({ icon: 'lock', title: '我们不会保存您的网银密码', sub: '登录在 Plaid 页面完成' })}
            ${C.li({ icon: 'user', title: '只能绑定本人名下的账户', sub: '银行返回的户名须与开户姓名一致' })}
            ${C.li({ icon: 'globe', title: '仅支持美国银行账户', sub: '没有美国银行账户？请改用电汇' })}
          </div>
          <div class="xs muted mt12">授权后，Plaid 会把账户户名、类型和尾号提供给我们，用于 ACH 入金和出金。${C.tag('PDF-3')}</div>
          ${C.notice('warn', '绑定方式待定（Q-DW-2）：DW 文档已核实的接口是直接录入银行账号与路由号（POST /back-office/bank-accounts）；Plaid 为可选集成，processor token 流程未在 DW 文档中核实。本原型暂按 Plaid 演示，接入前以 DW 回复为准。')}`,
        footer: '<button class="btn ghost" style="width:auto" data-go="#/p33">改用电汇</button><button class="btn primary" data-act="openPlaid">继续</button>',
      };
    }
    if (ctx.step === 'plaid') {
      return {
        title: 'Plaid（第三方页面占位）',
        body: `<div class="card" style="border:1.5px dashed var(--faint)"><div class="xs faint mb8">原型占位：实际为 Plaid Link 组件，本原型不采集任何银行凭据。</div>
            <div class="b mb8">选择您的银行</div>
            ${PLAID_BANKS.map((b) => `<button class="opt ${ctx.inst === b ? 'on' : ''}" data-act="pickInst" data-val="${b}"><span class="radio"></span>${Icon('bank', 20)}<div class="grow b">${b}</div></button>`).join('')}
            <label class="check mt12"><input type="checkbox" data-bind="mismatch" ${ctx.form?.mismatch ? 'checked' : ''}><span class="small">（原型）模拟银行返回的户名与开户姓名不一致</span></label></div>`,
        footer: `<button class="btn ghost" style="width:auto" data-act="cancelPlaid">取消</button><button class="btn primary" data-act="authPlaid" ${ctx.inst ? '' : 'disabled'}>（原型）模拟授权成功</button>`,
      };
    }
    if (ctx.step === 'pick') {
      const owner = ctx.form?.mismatch ? 'J Smith' : holderName();
      ctx.accts = ctx.accts || [{ type: 'CHECKING', mask: String(1000 + Math.floor(Math.random() * 9000)) }, { type: 'SAVINGS', mask: String(1000 + Math.floor(Math.random() * 9000)) }];
      ctx.pick = ctx.pick ?? 0;
      return {
        title: '选择账户',
        body: `<div class="small muted mb12">${esc(ctx.inst)} 返回了以下账户，请选择一个用于入金和出金。</div>
          ${ctx.accts.map((x, i) => `<button class="opt ${ctx.pick === i ? 'on' : ''}" data-act="pickAcct" data-val="${i}"><span class="radio"></span><div class="grow"><div class="b">${x.type === 'SAVINGS' ? '储蓄' : '支票'}账户 ••${x.mask}</div><div class="xs muted">户名 ${esc(owner)}</div></div></button>`).join('')}`,
        footer: '<button class="btn primary" data-act="linkAcct">绑定此账户</button>',
      };
    }
    const r = ctx.result;
    return {
      title: r.ok ? '绑定成功' : '无法绑定', noBack: true,
      body: r.ok
        ? `<div class="state" style="min-height:auto;padding-top:28px"><div class="state-ic">${Icon('check', 36)}</div><h2>银行账户已绑定</h2><p>${esc(r.bank.name)} ••${esc(r.bank.mask)} 现在可以用于 ACH 入金和出金。</p></div>`
        : `<div class="state" style="min-height:auto;padding-top:28px"><div class="state-ic" style="background:var(--danger-weak);color:var(--danger)">${Icon('x', 36)}</div><h2>户名不一致，无法绑定</h2><p>银行返回的户名（${esc(r.owner)}）与证券账户持有人（${esc(holderName())}）不一致。为防范第三方资金，只能绑定本人名下的账户。${C.tag('PDF-3')}</p></div>`,
      footer: r.ok
        ? `<button class="btn primary" data-go="${from === 'p13' ? '#/p13' : from === 'p06' ? '#/p13' : '#/' + from}">${from === 'p06' || from === 'p13' ? '去入金' : '完成'}</button>`
        : '<button class="btn ghost" data-go="#/p33">改用电汇</button><button class="btn primary" data-act="retry">重新选择</button>',
    };
  },
  actions: {
    openPlaid(el, ctx) { ctx.step = 'plaid'; Router.refresh(); },
    pickInst(el, ctx) { ctx.inst = el.dataset.val; Router.refresh(); },
    cancelPlaid(el, ctx) { ctx.step = 'intro'; Router.refresh(); },
    authPlaid(el, ctx) { ctx.step = 'pick'; ctx.accts = null; Router.refresh(); },
    pickAcct(el, ctx) { ctx.pick = Number(el.dataset.val); Router.refresh(); },
    retry(el, ctx) { ctx.step = 'plaid'; ctx.result = null; Router.refresh(); },
    linkAcct(el, ctx) {
      const s = Store.state;
      const x = ctx.accts[ctx.pick];
      const owner = ctx.form?.mismatch ? 'J Smith' : holderName();
      if (owner.toLowerCase() !== holderName().toLowerCase()) { ctx.result = { ok: false, owner }; ctx.step = 'done'; return Router.refresh(); }
      const bank = { id: 'b' + Date.now(), name: ctx.inst, type: x.type, mask: x.mask, status: 'VERIFIED', owner, createdAt: today() };
      s.linkedBanks.push(bank);
      notify('FUNDS', '银行账户已绑定', `${bank.name} ••${bank.mask} 已绑定，可用于入金和出金。`, '#/p31');
      Store.save(); ctx.result = { ok: true, bank }; ctx.step = 'done'; Router.refresh();
    },
  },
};

/* ---------- P-33 电汇入金指引（来自 DW deposit-instructions） ---------- */
Pages.p33 = {
  auth: true,
  backTo: '#/p13',
  render(p, ctx) {
    const s = Store.state;
    const a = s.accounts.LIVE;
    if (a.status !== 'ACTIVE') return notReady('电汇入金');
    const blocked = fundsBlocked('入金'); if (blocked) return blocked;
    const name = holderName();
    const ref = `${a.accountNumber} ${name}`;
    // 示例数据：实际值来自 GET /accounts/{id}/funding/deposit-instructions
    const rows = [
      ['收款人（Beneficiary）', 'DriveWealth, LLC（示例）'],
      ['收款银行', '示例托管银行 (Example Custody Bank)'],
      ['银行地址', '100 Example Plaza, New York, NY 10001'],
      ['收款账号', '000000000000（示例）'],
      ['ABA 路由号（美国境内）', '000000000（示例）'],
      ['SWIFT（境外汇款）', 'EXMPUS00（示例）'],
    ];
    const copyRow = ([k2, v], hl) => `<div class="row" style="padding:10px 0;border-top:1px solid var(--line)${hl ? ';background:var(--warn-weak);margin:0 -16px;padding:10px 16px' : ''}"><div class="grow"><div class="xs muted">${k2}</div><div class="small b num" style="word-break:break-all">${esc(v)}</div></div><button class="nav-btn" style="width:30px;height:30px" data-act="copy" data-val="${esc(v)}" aria-label="复制">${Icon('copy', 16)}</button></div>`;
    return {
      title: '电汇入金',
      body: `${C.notice('info', `请从<b>本人名下</b>的银行账户汇款到以下账户。收款信息由 DriveWealth 为您的账户生成。${C.tag('PDF-3')}`)}
        <div class="card">${rows.map((r) => copyRow(r)).join('')}${copyRow(['附言 / 备注（必填）', ref], true)}
          <div class="xs mt8" style="color:var(--warn)">附言必须填写您的账户号码和姓名，否则资金无法入账，可能被退回。</div></div>
        ${'' /* 时效出处（待 DW 确认）：https://developer.drivewealth.com/apis/docs/individual-funding ；观察期：depositing-1、info.drivewealth.com/funding-withdrawal-policies；截止时间 15:00 为示例值 */}
        <div class="card">${C.kv('最低汇款金额', fmt.usd(LIMITS.minWire) + ' ' + THRESHOLD_NOTE)}${C.kv('汇款截止时间' + C.tag('20'), `工作日 ${LIMITS.wireCutoff}（示例，待 DW 确认）`)}${C.kv('预计到账', '截止前汇出通常当日，否则次一工作日（待 DW 确认）')}${C.kv('观察期', '电汇入金无观察期（待 DW 确认）')}${C.kv('费用', '汇出行与中转行费用由汇款人承担')}</div>
        ${C.notice('warn', '第三方汇款（非本人账户）将被退回，退回产生的费用由汇款人承担。节假日顺延。')}
        <div class="xs faint">以上为示例收款信息，请勿据此汇款。</div>`,
      footer: '<button class="btn primary" data-act="sent">我已汇款</button>',
    };
  },
  actions: {
    sent(el, ctx) {
      UI.sheet('登记汇款（选填）', `<div class="small muted mb12">填写汇款金额，便于我们核对到账。资金以实际到账为准。</div>
        ${C.field({ label: '汇款金额 (USD)', bind: 'wireAmt', attrs: 'inputmode="decimal"', placeholder: '0.00' })}
        <button class="btn primary" data-act="logWire">提交</button>`);
    },
    logWire(el, ctx) {
      const amt = parseFloat((ctx.form || {}).wireAmt) || 0;
      if (amt < LIMITS.minWire) return UI.toast(`最低汇款金额 ${fmt.usd(LIMITS.minWire)}`);
      const a = Store.state.accounts.LIVE;
      const id = 'DEP-' + Date.now().toString().slice(-8);
      a.transactions.unshift({ id, type: 'DEPOSIT', method: 'WIRE', amount: round2(amt), date: today(), status: '等待到账', dwStatus: 'PENDING', submittedAt: nowStr(), desc: '电汇入金（用户登记）' });
      Store.save(); UI.close(); UI.toast('已登记，到账后通知您'); Router.go('#/p18?id=' + id);
    },
  },
};

/* ---------- P-15 文件 ---------- */
const DOC_TYPES = [['TRADE_CONFIRM', '交易确认书'], ['STATEMENT', '账户对账单'], ['TAX', '税务文件']];
Pages.p15 = {
  auth: true,
  render(p, ctx) {
    const a = Acc.cur();
    if (a.status !== 'ACTIVE') return notReady('文件');
    ctx.type = ctx.type || p.type || 'TRADE_CONFIRM';
    const docs = a.documents.filter((d) => d.type === ctx.type);
    return {
      title: '文件',
      body: `${C.seg('type', DOC_TYPES, ctx.type, 'seg2')}
        <div class="xs muted mb8">${C.tag('17')} 文件由 DriveWealth 生成，可在线查看和下载 PDF。</div>
        ${docs.length ? `<div class="list">${docs.map((d) => C.li({ icon: 'doc', title: esc(d.title), sub: `${d.date} · PDF`, act: 'open', data: `data-id="${d.id}"` })).join('')}</div>` : C.empty('doc', `暂无${DOC_TYPES.find((t) => t[0] === ctx.type)[1]}`)}
        ${ctx.type === 'TAX' ? C.notice('info', '年度税务文件（如 1099）通常于次年 2 月中旬提供。非美国税务居民将收到 1042-S。') : ''}`,
    };
  },
  actions: {
    type(el, ctx) { ctx.type = el.dataset.val; Router.refresh(); },
    open(el) {
      const a = Acc.cur(); const d = a.documents.find((x) => x.id === el.dataset.id);
      UI.sheet(esc(d.title), `<div class="doc-paper">DriveWealth, LLC
${d.type === 'TRADE_CONFIRM' ? 'TRADE CONFIRMATION' : d.type === 'STATEMENT' ? 'ACCOUNT STATEMENT' : 'TAX FORM'}

Account: ${a.accountNumber}
Period:  ${d.period}
Date:    ${d.date}

—— 原型占位内容 ——
实际产品中此处为券商生成的 PDF 文件。</div>
        <div class="row mt12"><button class="btn ghost" data-act="dl">分享</button><button class="btn primary" data-act="dl">下载 PDF</button></div>`);
    },
    dl() { UI.toast('（原型）已开始下载'); },
  },
};

/* ---------- P-16 设置与个人资料 ---------- */
Pages.p16 = {
  auth: true,
  render(p, ctx) {
    const sub = p.sub || '';
    if (sub === 'profile') return Pages.p16.profile(ctx);
    if (sub === 'close') return Pages.p16.close(ctx);
    if (sub === 'security') return { title: '安全', body: `<div class="list">${C.li({ icon: 'lock', title: '登录方式', sub: '邮箱验证码' })}${toggleRow('biometric', '面容 / 指纹解锁')}${C.li({ icon: 'id', title: '登录设备管理', sub: '当前设备 · iPhone' })}</div>` };
    const s = Store.state;
    const a = s.accounts.LIVE;
    return {
      title: '设置',
      body: `<div class="group-label">账户</div>
        <div class="list">
          ${C.li({ icon: 'user', title: '个人资料', sub: s.profileSync.status === 'PENDING' ? '正在同步至券商…' : '地址、邮箱、电话、就业信息', go: '#/p16?sub=profile' })}
          ${C.li({ icon: 'id', title: '账户号码' + C.tag('PDF-6'), right: `<span class="small num muted">${a.accountNumber ? esc(a.accountNumber) : '未开户'}</span>` })}
          ${C.li({ icon: 'shield', title: '账户类型', right: `<span class="small muted">${a.status === 'ACTIVE' ? '现金 · 自主' : '—'}</span>` })}
          ${C.li({ icon: 'bank', title: '银行账户', sub: '用于 ACH 入金和出金', go: '#/p31' })}
          ${C.li({ icon: 'lock', title: '安全', go: '#/p16?sub=security' })}
        </div>
        <div class="group-label">偏好</div>
        <div class="list">
          ${C.li({ icon: 'globe', title: '语言', right: '<span class="small muted">简体中文</span>' })}
          ${toggleRow('redUp', '红涨绿跌', '默认绿涨红跌（美股惯例）')}
          ${toggleRow('hideBalances', '默认隐藏金额')}
        </div>
        <div class="group-label">通知</div>
        <div class="list">${toggleRow('notifTrade', '交易与订单通知')}${toggleRow('notifFunds', '资金变动通知')}${toggleRow('notifMarketing', '活动与资讯')}</div>
        <div class="group-label">其他</div>
        <div class="list">${C.li({ icon: 'doc', title: 'DriveWealth 披露文件', act: 'dwLink' })}${C.li({ icon: 'help', title: '帮助中心', go: '#/p29' })}${C.li({ icon: 'trash', title: '关闭账户', go: '#/p16?sub=close', danger: true })}</div>
        <div class="xs faint center mt16">${APP_NAME} 原型 v0.1</div>`,
    };
  },
  profile(ctx) {
    const s = Store.state;
    const f = ctx.form || (ctx.form = { ...s.profile });
    const e = ctx.errors || {};
    const sync = s.profileSync;
    return {
      title: '个人资料',
      body: `${C.notice('warn', '保存后会把变更同步至券商，并<b>重新核验身份</b>，核验期间部分功能可能受限。')}${sync.status === 'PENDING' ? C.notice('info', '资料变更已提交，正在同步至券商（DriveWealth）并重新核验…') : sync.status === 'FAILED' ? C.notice('danger', '同步失败，请稍后重试或联系客服。') : C.notice('ok', `资料已与券商同步${sync.at ? ' · ' + sync.at : ''}${C.tag('24')}`)}
        ${C.field({ label: '法定姓名', bind: '_name', value: holderName() || '—', attrs: 'disabled', hint: '如需修改法定姓名，请联系客服并提供证明文件' })}
        ${C.field({ label: '邮箱', bind: 'email', value: f.email, type: 'email', error: e.email })}
        ${C.field({ label: '手机号', bind: 'phone', value: f.phone })}
        <div class="sec-title" style="font-size:15px">居住地址${C.tag('2')}</div>
        ${C.field({ label: '街道地址', bind: 'line1', value: f.line1, error: e.line1 })}
        ${C.field({ label: '公寓、楼层（选填）', bind: 'line2', value: f.line2 })}
        ${C.two({ label: '城市', bind: 'city', value: f.city }, { label: '州/省', bind: 'state', value: f.state })}
        ${C.field({ label: '邮编', bind: 'postalCode', value: f.postalCode })}
        <div class="sec-title" style="font-size:15px">就业信息</div>
        ${C.field({ label: '就业状态', bind: 'employmentStatus', value: f.employmentStatus, options: [['EMPLOYED', '受雇'], ['SELF_EMPLOYED', '自雇'], ['UNEMPLOYED', '无业'], ['RETIRED', '退休'], ['STUDENT', '学生']] })}
        ${C.field({ label: '雇主名称', bind: 'employerName', value: f.employerName, error: e.employerName })}`,
      footer: '<button class="btn primary" data-act="saveProfile">保存并同步</button>',
    };
  },
  close() {
    const a = Store.state.accounts.LIVE;
    if (a.status !== 'ACTIVE') return { title: '关闭账户', body: C.notice('info', '您尚未开通实盘账户。') };
    const sm = Acc.summary(a);
    const open = Acc.openOrders(a).length;
    const checks = [
      ['现金余额为 $0', a.cash <= 0, `当前 ${fmt.usd(a.cash)}`, '#/p14', '去出金'],
      ['无证券持仓', sm.ps.length === 0, `当前 ${sm.ps.length} 只`, '#/p12', '去卖出'],
      ['无待处理订单', open === 0, `当前 ${open} 笔`, '#/p11?status=OPEN', '去取消'],
    ];
    const ok = checks.every((c) => c[1]);
    return {
      title: '关闭账户',
      body: `${ok ? C.notice('ok', '账户已满足关闭条件。') : C.notice('danger', `账户仍有资产或未完成订单，<b>暂不能关闭</b>。请先处理以下事项，或将资产转出至其他券商。${C.tag('22')}`)}
        <div class="list">${checks.map(([t, pass, sub, go, cta]) => `<div class="li"><span class="li-ic" style="color:${pass ? 'var(--up)' : 'var(--danger)'}">${Icon(pass ? 'check' : 'x', 18)}</span><span class="grow"><div class="li-title">${t}</div><div class="li-sub">${sub}</div></span>${pass ? '' : `<button class="btn ghost sm" data-go="${go}">${cta}</button>`}</div>`).join('')}</div>
        <div class="xs muted">关闭后账户号码不可恢复，历史文件仍可按监管要求申请获取。</div>`,
      footer: `<button class="btn danger" data-act="closeAcct" ${ok ? '' : 'disabled'}>申请关闭账户</button>`,
    };
  },
  actions: {
    toggle(el) { const k = el.dataset.key; Store.state.prefs[k] = !Store.state.prefs[k]; Store.save(); applyPrefs(); Router.refresh(); },
    dwLink() { window.open(DW_DISCLOSURE_URL, '_blank', 'noopener'); },
    saveProfile(el, ctx) {
      const f = ctx.form; const e = {};
      if (!/^\S+@\S+\.\S+$/.test(f.email || '')) e.email = '请输入有效邮箱';
      if (f.line1 && PO_BOX_RE.test(`${f.line1} ${f.line2 || ''}`)) e.line1 = '居住地址不能是邮政信箱（P.O. Box）';
      if ((f.employmentStatus === 'EMPLOYED' || f.employmentStatus === 'SELF_EMPLOYED') && !f.employerName) e.employerName = '在职时须填写雇主名称';
      ctx.errors = e;
      if (Object.keys(e).length) return Router.refresh();
      const s = Store.state;
      const { _name, ...rest } = f;
      s.profile = rest; s.user.email = f.email;
      s.profileSync = { status: 'PENDING', at: null };
      if (s.dw.userID) s.dw.kyc = 'KYC_PROCESSING'; // PATCH /users 会触发 KYC 重跑
      Store.save(); Router.refresh();
      setTimeout(() => { s.profileSync = { status: 'SYNCED', at: nowStr() }; if (s.dw.userID && s.dw.kyc === 'KYC_PROCESSING') s.dw.kyc = 'KYC_APPROVED'; Store.save(); if (Router.current.id === 'p16') { UI.toast('已同步至券商'); Router.refresh(); } }, 1600);
    },
    closeAcct() { UI.confirm({ title: '确认关闭账户？', body: '提交后客服将在 1–2 个工作日内处理，关闭后无法恢复。', ok: '确认关闭', danger: true, onOk: () => UI.toast('（原型）关户申请已提交') }); },
  },
};
function toggleRow(key, title, sub) {
  const on = !!Store.state.prefs[key];
  return `<button class="li" data-act="toggle" data-key="${key}"><span class="grow"><div class="li-title">${title}</div>${sub ? `<div class="li-sub">${sub}</div>` : ''}</span>
    <span style="width:46px;height:28px;border-radius:14px;background:${on ? 'var(--primary)' : 'var(--line)'};position:relative;flex:none;transition:.2s"><i style="position:absolute;top:3px;left:${on ? 21 : 3}px;width:22px;height:22px;border-radius:50%;background:#fff;box-shadow:var(--shadow);transition:.2s"></i></span></button>`;
}

/* ---------- P-17 通知与提示 ---------- */
const NOTIF_CATS = [['ALL', '全部'], ['VIOLATION', '违规与限制'], ['TRADE', '交易'], ['FUNDS', '资金'], ['ACCOUNT', '账户'], ['SYSTEM', '系统']];
Pages.p17 = {
  auth: true,
  render(p, ctx) {
    const s = Store.state;
    ctx.tab = ctx.tab || p.tab || 'ALL';
    const list = s.notifications.filter((n) => ctx.tab === 'ALL' || n.category === ctx.tab);
    const a = s.accounts.LIVE;
    const vio = ctx.tab === 'VIOLATION' || ctx.tab === 'ALL' ? (a.violations || []) : [];
    return {
      title: '通知',
      right: `<button class="link-btn" style="padding:0 10px" data-act="readAll">全部已读</button>`,
      body: `${C.seg('tab', NOTIF_CATS, ctx.tab)}
        ${vio.length ? `<div class="card" style="border:1.5px solid var(--warn-weak)"><div class="row between"><div class="b">交易违规记录${C.tag('15')}</div>${C.badge('现金账户', 'warn')}</div>
          ${vio.map((v) => `<div class="hr"></div>${C.kv('类型', `<b>${esc(v.type)}</b>`)}${C.kv('发生日期', v.occurredAt)}${C.kv('近 12 个月累计', v.count + ' 次')}${C.kv('当前限制', esc(v.restriction))}`).join('')}
          <button class="link-btn xs mt8" data-go="#/p29">了解交易违规规则</button></div>` : ''}
        ${list.length ? `<div class="list">${list.map((n) => `<button class="li" data-act="openN" data-id="${n.id}" style="align-items:flex-start">
            <span class="li-ic" style="${n.category === 'VIOLATION' ? 'color:var(--warn)' : ''}">${Icon({ TRADE: 'market', FUNDS: 'bank', ACCOUNT: 'user', SYSTEM: 'info', VIOLATION: 'warn' }[n.category], 18)}</span>
            <span class="grow"><div class="row between"><span class="li-title ${n.read ? '' : 'b'}">${esc(n.title)}</span>${n.read ? '' : '<i style="width:8px;height:8px;border-radius:50%;background:var(--danger);flex:none"></i>'}</div><div class="li-sub">${esc(n.body)}</div><div class="xs faint mt8">${n.at}</div></span></button>`).join('')}</div>` : C.empty('bell', '暂无通知')}`,
    };
  },
  actions: {
    tab(el, ctx) { ctx.tab = el.dataset.val; Router.refresh(); },
    readAll() { Store.state.notifications.forEach((n) => { n.read = true; }); Store.save(); Router.refresh(); },
    openN(el) { const n = Store.state.notifications.find((x) => x.id === el.dataset.id); n.read = true; Store.save(); if (n.link) Router.go(n.link); else Router.refresh(); },
  },
};

/* ---------- P-18 历史记录 ---------- */
const TX_TYPES = [['ALL', '全部'], ['TRADE', '交易'], ['DEPOSIT', '入金'], ['WITHDRAWAL', '出金'], ['DIVIDEND', '分红'], ['FEE', '费用'], ['CORP_ACTION', '公司行动']];
Pages.p18 = {
  auth: true,
  render(p, ctx) {
    const a = Acc.cur();
    if (a.status !== 'ACTIVE') return notReady('历史记录');
    if (p.id) {
      const t = a.transactions.find((x) => x.id === p.id);
      if (!t) return { title: '记录详情', body: C.empty('clock', '记录不存在') };
      return {
        title: '记录详情',
        body: `<div class="card">${C.kv('类型', TX_TYPES.find((x) => x[0] === t.type)[1])}${t.symbol ? C.kv('证券', t.symbol) : ''}${t.qty ? C.kv('数量', fmt.qty(t.qty)) : ''}${t.price ? C.kv('价格', fmt.usd(t.price)) : ''}${C.kv('金额', fmt.usd(t.amount, { sign: true }))}${t.fee ? C.kv('费用', fmt.usd(t.fee)) : ''}${C.kv('日期', t.date)}${C.kv('状态', t.status)}${C.kv('流水号', t.id)}</div>
          ${t.ca ? C.notice('warn', `<b>公司行动说明${C.tag('18')}</b><br>${esc(t.desc)}${t.ca.type === 'SPLIT' ? `<br>拆股比例 ${t.ca.ratio}：${t.ca.before} 股 → ${t.ca.after} 股，总成本不变。` : ''}${t.ca.orderId ? `<br><button class="link-btn xs mt8" data-go="#/p11?id=${t.ca.orderId}">查看受影响的订单</button>` : ''}`) : `<div class="small muted">${esc(t.desc)}</div>`}
          ${fundTimeline(t)}`,
      };
    }
    ctx.type = ctx.type || 'ALL';
    const list = a.transactions.filter((t) => ctx.type === 'ALL' || t.type === ctx.type);
    return {
      title: '历史记录',
      body: `${C.seg('type', TX_TYPES, ctx.type)}
        <div class="xs muted mb8">${C.tag('16', '18')}</div>
        ${list.length ? `<div class="list">${list.map((t) => C.li({ icon: { TRADE: 'market', DEPOSIT: 'down', WITHDRAWAL: 'up', DIVIDEND: 'gift', FEE: 'doc', CORP_ACTION: 'warn' }[t.type], title: esc(t.desc), sub: `${t.date} · ${t.status}`, right: `<span class="num small ${t.amount > 0 ? 'up' : t.amount < 0 ? '' : 'muted'}">${t.amount ? fmt.usd(t.amount, { sign: true }) : '—'}</span>`, go: `#/p18?id=${t.id}` })).join('')}</div>` : C.empty('clock', '暂无记录')}`,
    };
  },
  actions: {
    type(el, ctx) { ctx.type = el.dataset.val; Router.refresh(); },
    simFund(el) {
      const s = Store.state;
      const a = Acc.cur();
      const t = a.transactions.find((x) => x.id === Router.current.params.id);
      const ok = el.dataset.val === 'ok';
      t.doneAt = nowStr();
      if (t.type === 'DEPOSIT') {
        if (ok) { t.dwStatus = 'SUCCESSFUL'; t.status = '已到账'; a.cash = round2(a.cash + t.amount); notify('FUNDS', '入金已到账', `${t.method === 'WIRE' ? '电汇' : 'ACH'}入金 ${fmt.usd(t.amount)} 已到账，可用于交易。`, '#/p18?id=' + t.id); }
        else { t.dwStatus = 'RETURNED'; t.status = '被退回'; t.failureReason = t.method === 'WIRE' ? '附言缺少账户号码，资金已退回汇款行' : 'R01 账户余额不足'; notify('FUNDS', '入金被退回', `${fmt.usd(t.amount)} 入金被退回：${t.failureReason}`, '#/p18?id=' + t.id); }
      } else if (ok) { t.dwStatus = 'SUCCESSFUL'; t.status = '已完成'; notify('FUNDS', '出金已完成', `${fmt.usd(-t.amount)} 已汇出。`, '#/p18?id=' + t.id); }
      else { t.dwStatus = 'FAILED'; t.status = '失败'; t.failureReason = '收款账户信息有误，被收款行退回'; a.cash = round2(a.cash - t.amount); notify('FUNDS', '出金失败', `${fmt.usd(-t.amount)} 出金失败，资金已退回证券账户。`, '#/p18?id=' + t.id); }
      Store.save(); UI.toast('（原型）已模拟 DW 资金事件'); Router.refresh();
    },
  },
};
/* 入金 / 出金状态时间线（按 DW deposits / redemptions 状态）
   时效出处（待 DW 确认）：入金 https://developer.drivewealth.com/apis/docs/depositing-1 ；出金 https://developer.drivewealth.com/apis/docs/individual-funding */
function fundTimeline(t) {
  if (!['DEPOSIT', 'WITHDRAWAL'].includes(t.type) || !t.dwStatus) return '';
  const st = t.dwStatus;
  const dep = t.type === 'DEPOSIT';
  const wire = t.method === 'WIRE';
  const pending = st === 'PENDING';
  const failed = st === 'RETURNED' || st === 'FAILED';
  const items = [
    [dep && wire ? '已登记汇款' : '已提交', t.submittedAt || t.date, 'done'],
    [dep ? (wire ? '等待银行到账' : '银行处理中') : 'DriveWealth 处理中', pending ? '处理中，请耐心等待' : '', pending ? 'active' : 'done'],
    failed ? [dep ? '被退回' : '失败，资金已退回证券账户', t.failureReason || '', 'fail']
      : [dep ? '已到账 · 购买力已授予' : '已汇出', st === 'SUCCESSFUL' ? (t.doneAt || t.date) + (dep && !wire ? ` · ${SEASONING_DAYS} 天观察期后可提现（默认，待 DW 确认）` : '') : (dep ? (wire ? '以银行实际到账为准' : '结算后授予购买力，通常 4–5 个工作日（待 DW 确认）') : (wire ? '美东 17:00 前提交当日处理（待 DW 确认）' : '通常 4–5 个工作日（待 DW 确认）')), st === 'SUCCESSFUL' ? 'done' : 'todo'],
  ];
  return `<div class="sec-title" style="font-size:15px">处理进度</div>${stepper(items)}
    ${failed && dep ? C.notice('warn', '入金被退回时，使用该笔资金买入的证券可能被限制卖出；如有疑问请联系客服。') : ''}
    ${pending ? `<div class="center xs faint">（原型）模拟 DW 事件：<button class="link-btn xs" data-act="simFund" data-val="ok">${dep ? '到账' : '成功'}</button> · <button class="link-btn xs" data-act="simFund" data-val="fail">${dep ? '退回' : '失败'}</button></div>` : ''}`;
}

/* ---------- P-28 从其他券商转入（ACATS） ---------- */
Pages.p28 = {
  auth: true,
  render(p, ctx) {
    const a = Acc.cur();
    if (a.status !== 'ACTIVE' || Store.state.mode === 'PAPER') return Store.state.mode === 'PAPER' ? { title: '转入持仓', body: C.notice('info', '模拟账户不支持转入。请切换到实盘账户。') } : notReady('转入');
    const f = ctx.form || (ctx.form = { type: 'FULL' });
    if (ctx.done) {
      return { title: '转入已提交', noBack: true, body: `<div class="state" style="min-height:auto;padding-top:28px"><div class="state-ic">${Icon('check', 36)}</div><h2>转入申请已提交</h2><p>ACATS 转入通常需要 5–7 个工作日，我们会通知您每一步进展。</p></div>
        <div class="card">${C.kv('转入单号', ctx.done)}${C.kv('转出券商', esc(f.broker))}${C.kv('类型', f.type === 'FULL' ? '全部转入' : '部分转入')}${C.kv('状态', C.badge('已提交', 'info'))}</div>`, footer: '<button class="btn primary" data-go="#/p07">完成</button>' };
    }
    return {
      title: '转入持仓',
      body: `<div class="card"><div class="b">通过 ACATS 转入</div><div class="small muted mt8">把其他美国券商账户中的股票、ETF 和现金直接转入，无需先卖出。</div>
          <div class="row mt12 xs muted" style="gap:6px">${['填写转出账户', '券商核对', '资产到账'].map((t, i) => `<span class="badge">${i + 1} · ${t}</span>`).join('')}</div></div>
        ${C.field({ label: '转出券商', bind: 'broker', value: f.broker, placeholder: '搜索券商名称' })}
        ${C.field({ label: '转出账户号码', bind: 'acct', value: f.acct, hint: '请与转出券商对账单上的账户号码一致' })}
        ${C.field({ label: '转出账户持有人', bind: 'owner', value: f.owner ?? holderName(), hint: '须与本账户持有人一致' })}
        <div class="small muted mb8">转入方式</div>
        <button class="opt ${f.type === 'FULL' ? 'on' : ''}" data-act="ttype" data-val="FULL"><span class="radio"></span><div class="grow"><div class="b">全部转入</div><div class="xs muted">转出账户将被对方券商关闭</div></div></button>
        <button class="opt ${f.type === 'PARTIAL' ? 'on' : ''}" data-act="ttype" data-val="PARTIAL"><span class="radio"></span><div class="grow"><div class="b">部分转入</div><div class="xs muted">选择要转入的证券和数量</div></div></button>
        ${f.type === 'PARTIAL' ? C.field({ label: '转入证券及数量', bind: 'assets', value: f.assets, type: 'textarea', placeholder: '如：AAPL 10\nSPY 5' }) : ''}
        ${C.notice('info', '转出券商可能收取转出费用。不在本平台证券主清单内的证券无法转入。')}`,
      footer: `<button class="btn primary" data-act="submitAcats">提交转入申请</button>`,
    };
  },
  actions: {
    ttype(el, ctx) { ctx.form.type = el.dataset.val; Router.refresh(); },
    submitAcats(el, ctx) {
      const f = ctx.form;
      if (!f.broker || !f.acct) return UI.toast('请填写转出券商和账户号码');
      const owner = (f.owner ?? holderName()).trim().toLowerCase();
      if (owner !== holderName().toLowerCase()) return UI.alert('无法提交', '转出账户持有人须与本账户持有人一致。');
      ctx.done = 'ACATS-' + Date.now().toString().slice(-8);
      Store.state.acats.push({ id: ctx.done, broker: f.broker, type: f.type, status: 'SUBMITTED' }); Store.save(); Router.refresh();
    },
  },
};

/* ---------- P-29 帮助中心 ---------- */
Pages.p29 = {
  render() {
    return {
      title: '帮助中心',
      body: `<input class="input mb16" placeholder="搜索问题" data-bind="hq">
        <div class="sec-title" style="font-size:15px">常见问题</div>
        ${DATA.faqs.map(([q, a]) => `<details class="faq"><summary>${esc(q)}${Icon('right', 16, 'chev')}</summary><p>${esc(a)}</p></details>`).join('')}
        <div class="sec-title" style="font-size:15px">联系我们</div>
        <div class="list">${C.li({ icon: 'help', title: '在线客服', sub: '工作日 9:00–18:00 (ET)', act: 'cs' })}${C.li({ icon: 'doc', title: '邮件支持', sub: 'support@example.com', act: 'cs' })}</div>
        <div class="sec-title" style="font-size:15px">法律文件</div>
        <div class="list">${C.li({ icon: 'doc', title: 'DriveWealth 披露文件' + C.tag('8'), act: 'dwLink' })}${C.li({ icon: 'doc', title: '平台用户服务协议', act: 'cs' })}${C.li({ icon: 'doc', title: '平台隐私政策', act: 'cs' })}</div>`,
    };
  },
  actions: { cs() { UI.toast('（原型）功能演示'); }, dwLink() { window.open(DW_DISCLOSURE_URL, '_blank', 'noopener'); } },
};
