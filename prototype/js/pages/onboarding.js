'use strict';
/* P-01 – P-06、P-30、P-34 – P-36：启动、登录、开户与 KYC 补齐 */

/* ---------- P-01 欢迎页 ---------- */
Pages.p01 = {
  render() {
    if (Store.state.loggedIn) setTimeout(() => Router.go('#/p07'));
    return {
      headerless: true, cls: 'white',
      body: `<div class="state">
        <img class="brand-logo" src="assets/logo.png" alt="FinX">
        <p class="mt8">美股与 ETF 投资，开户、入金、交易一站完成。</p>
        <img class="mascot pill mt16" src="assets/fifi_pill.png" alt="Fifi">
        <div style="width:100%;margin-top:48px" class="col gap8">
          <button class="btn primary" data-go="#/p02?mode=register">注册</button>
          <button class="btn ghost" data-go="#/p02?mode=login">登录</button>
          <button class="link-btn mt12" data-act="browse">先逛逛行情</button>
        </div>
        <p class="xs faint mt24">证券服务由合作券商提供。投资有风险。</p>
      </div>`,
    };
  },
  actions: { browse() { Router.go('#/p09'); } },
};

/* ---------- P-02 登录 / 注册 ---------- */
Pages.p02 = {
  backTo: '#/p01',
  render(p, ctx) {
    const mode = ctx.mode || p.mode || 'login';
    ctx.mode = mode;
    const f = ctx.form || (ctx.form = { email: '' });
    const e = ctx.errors || {};
    return {
      title: mode === 'login' ? '登录' : '注册',
      body: `
        ${C.seg('setMode2', [['login', '登录'], ['register', '注册']], mode, 'seg2')}
        ${C.field({ label: '邮箱', bind: 'email', value: f.email, type: 'email', placeholder: 'name@example.com', error: e.email })}
        <div class="field ${e.code ? 'err' : ''}"><label>验证码</label>
          <div class="row"><input class="input grow" data-bind="code" value="${esc(f.code || '')}" inputmode="numeric" maxlength="6" placeholder="6 位验证码"><button class="btn ghost sm" data-act="sendCode" ${ctx.sent ? 'disabled' : ''}>${ctx.sent ? '已发送' : '获取验证码'}</button></div>
          ${e.code ? `<div class="err-msg">${e.code}</div>` : ctx.sent ? '<div class="hint">演示环境验证码：123456</div>' : ''}</div>
        <div class="row mt16 mb12" style="gap:10px"><span class="hr grow" style="margin:0"></span><span class="xs muted">或</span><span class="hr grow" style="margin:0"></span></div>
        <div class="col gap8 mb12">
          <button class="btn ghost" data-act="social" data-val="GOOGLE">使用 Google 登录</button>
          <button class="btn ghost" data-act="social" data-val="APPLE">通过 Apple 登录</button>
          <div class="xs faint center">原型占位：正式产品使用两家官方按钮样式。提供 Google 登录时同时提供 Apple 登录。</div>
        </div>
        ${mode === 'register' ? `<label class="check"><input type="checkbox" data-bind="terms" ${f.terms ? 'checked' : ''}><span>我已阅读并同意平台《用户服务协议》与《隐私政策》${C.tag('PDF-4')}<div class="xs faint">此为平台自有条款，券商（DriveWealth）披露将在开户时单独展示。</div></span></label>${e.terms ? `<div class="err-msg">${e.terms}</div>` : ''}` : ''}`,
      footer: `<button class="btn primary" data-act="submit">${mode === 'login' ? '登录' : '注册并登录'}</button>`,
    };
  },
  actions: {
    setMode2(el, ctx) { ctx.mode = el.dataset.val; ctx.errors = {}; Router.refresh(); },
    sendCode(el, ctx) {
      if (!/^\S+@\S+\.\S+$/.test(ctx.form.email || '')) { ctx.errors = { email: '请输入有效的邮箱地址' }; return Router.refresh(); }
      ctx.sent = true; ctx.errors = {}; UI.toast('验证码已发送'); Router.refresh();
    },
    social(el, ctx) {
      if (ctx.mode === 'register' && !(ctx.form || {}).terms) { ctx.errors = { terms: '请先同意平台条款' }; return Router.refresh(); }
      const prov = el.dataset.val;
      if (prov === 'GOOGLE') return loginAs({ provider: 'GOOGLE', email: 'demo.user@example.com', relay: false });
      UI.sheet('通过 Apple 登录（原型模拟）', `<div class="small muted mb12">Apple 会询问是否与本 App 共享邮箱。选择"隐藏"时，App 只会收到一个中转邮箱。</div>
        <div class="col gap8"><button class="btn ghost" data-act="appleShare" data-val="share">共享我的邮箱</button><button class="btn primary" data-act="appleShare" data-val="hide">隐藏我的邮件地址</button></div>`);
    },
    appleShare(el) {
      UI.close();
      const hide = el.dataset.val === 'hide';
      loginAs({ provider: 'APPLE', email: hide ? 'x7k2q9m4' + RELAY_DOMAIN : 'demo.user@example.com', relay: hide });
    },
    submit(el, ctx) {
      const f = ctx.form; const e = {};
      if (!/^\S+@\S+\.\S+$/.test(f.email || '')) e.email = '请输入有效的邮箱地址';
      if ((f.code || '') !== '123456') e.code = '验证码不正确（演示环境为 123456）';
      if (ctx.mode === 'register' && !f.terms) e.terms = '请先同意平台条款';
      ctx.errors = e;
      if (Object.keys(e).length) return Router.refresh();
      const s = Store.state;
      loginAs({ provider: 'EMAIL', email: f.email, relay: false });
    },
  },
};
// 原型：Apple"隐藏邮件地址"返回的中转邮箱域名（占位示例）
const RELAY_DOMAIN = '@privaterelay.example';
function loginAs({ provider, email, relay }) {
  const s = Store.state;
  s.loggedIn = true;
  s.user = { email, loginProvider: provider, providerUserId: provider === 'EMAIL' ? null : provider.toLowerCase() + '_demo_' + Math.random().toString(36).slice(2, 8), emailIsRelay: relay };
  s.profile.email = relay ? s.profile.email : email;
  if (s.scenario === 'fresh') s.scenario = 'loggedIn';
  Store.save();
  UI.toast(provider === 'EMAIL' ? '登录成功' : `已通过 ${provider === 'GOOGLE' ? 'Google' : 'Apple'} 登录${relay ? '（中转邮箱）' : ''}`);
  Router.go('#/p07');
}

/* ---------- P-03 开户信息填写 ---------- */
// 步骤：美国纳税人由 DW 用税号自动核验，不需要 P-04 证件上传
function obSteps() {
  const st = [['a', 'Prepare'], ['b', 'Identity'], ['c', 'Tax'], ['d', 'Address'], ['e', 'Finances'], ['f', 'Compliance'], ['g', 'Account type']];
  if (!DWSim.isUS()) st.push(['p04', 'ID upload']);
  st.push(['p05', 'Disclosures'], ['p30', 'Review']);
  return st;
}
const OB_HEADS = {
  b: ['Your identity', 'Enter it exactly as it appears on your government ID.'],
  c: ['Your tax information', 'Required by the USA PATRIOT Act to verify your identity.'],
  d: ['Your home address', 'Enter where you actually live. P.O. Boxes are not accepted.'],
  e: ['Employment & finances', 'Used for suitability assessment and regulatory reporting.'],
  f: ['A few compliance questions', 'Required by regulators. Please answer truthfully.'],
  g: ['Your account type', 'Cash account, self-directed. Nothing to choose at launch.'],
  p04: ['Upload your ID', 'International applicants upload a government-issued photo ID.'],
  p05: ['Disclosures & signature', 'Review and agree below. Signed electronically (E-Sign).'],
  p30: ['Review & submit', 'Check everything. FinX sends your details to DriveWealth for verification.'],
};
function obProgress(key) {
  const st = obSteps();
  const i = Math.max(0, st.findIndex((s) => s[0] === key));
  const head = OB_HEADS[key] || [st[i][1], ''];
  return `<div class="steps">${st.map((_, k) => `<i class="${k <= i ? 'done' : ''}"></i>`).join('')}</div>
    <div class="step-tag">STEP ${i + 1} OF ${st.length}</div>
    <div class="q-title">${head[0]}</div>${head[1] ? `<div class="q-sub">${head[1]}</div>` : ''}`;
}
const PO_BOX_RE = /\b(p\.?\s*o\.?\s*box|p\.?\s*o\.?\s*b\.?\s*\d|post\s+office\s+box|pmb\s*\d|po\s*box)\b|邮政信箱/i;
const ASCII_NAME_RE = /^[A-Za-z]+(?:[ '\-][A-Za-z]+)*$/;
const PHONE_RE = /^\+?[\d\s\-()]{7,20}$/;
function ageOf(dob) {
  const d = new Date(dob); if (isNaN(d)) return null;
  const now = new Date(); let a = now.getFullYear() - d.getFullYear();
  if (now.getMonth() < d.getMonth() || (now.getMonth() === d.getMonth() && now.getDate() < d.getDate())) a--;
  return a;
}
const COUNTRIES = [['US', 'United States'], ['CN', 'China'], ['HK', 'Hong Kong'], ['TW', 'Taiwan'], ['SG', 'Singapore'], ['GB', 'United Kingdom'], ['CA', 'Canada'], ['AU', 'Australia'], ['JP', 'Japan']];
const LANGS = [['zh_CN', '简体中文'], ['zh_TW', '繁體中文'], ['en_US', 'English']];
const INCOME = [['<25k', 'Under $25,000'], ['25k-50k', '$25,000 – $50,000'], ['50k-100k', '$50,000 – $100,000'], ['100k-200k', '$100,000 – $200,000'], ['>200k', 'Over $200,000']];
const NETWORTH = [['<50k', 'Under $50,000'], ['50k-200k', '$50,000 – $200,000'], ['200k-500k', '$200,000 – $500,000'], ['500k-1m', '$500,000 – $1,000,000'], ['>1m', 'Over $1,000,000']];
const EMPLOY = [['EMPLOYED', 'Employed'], ['SELF_EMPLOYED', 'Self-employed'], ['UNEMPLOYED', 'Unemployed'], ['RETIRED', 'Retired'], ['STUDENT', 'Student']];
const EXPERIENCE = [['NONE', 'None'], ['1-2', '1–2 years'], ['3-5', '3–5 years'], ['5+', '5+ years']];
const OBJECTIVE = [['GROWTH', 'Growth'], ['INCOME', 'Income'], ['PRESERVE', 'Capital preservation'], ['SPEC', 'Speculation']];
const RISK = [['LOW', 'Low'], ['MED', 'Medium'], ['HIGH', 'High']];
const ID_TYPES = [['PASSPORT', 'Passport'], ['NATIONAL_ID_CARD', 'National ID card'], ['DRIVER_LICENSE', "Driver's license"], ['RESIDENCE_PERMIT', 'Residence permit']];
// 资金来源（DW COMPLIANCE_AML_INFO.fundingSources）：代码为占位，枚举值待 DW 确认
const FUND_SOURCES = [['EMPLOYMENT', 'Employment income'], ['SAVINGS', 'Savings'], ['INVESTMENTS', 'Investment returns'], ['BUSINESS', 'Business income'], ['INHERITANCE', 'Inheritance / gift'], ['OTHER', 'Other']];
function defaultContactEmail() { const u = Store.state.user; return u.emailIsRelay ? '' : u.email; }
const lab = (list, v) => (list.find((x) => x[0] === v) || [, v || '—'])[1];
const ynLab = (v) => (v === 'YES' ? 'Yes' : v === 'NO' ? 'No' : '—');
const maskTin = (t) => (t ? String(t).replace(/[A-Za-z0-9](?=[A-Za-z0-9-]{4})/g, '•') : '—');
function tinOptions(d) {
  return d.usTaxPayer === 'YES' ? [['SSN', 'Social Security Number (SSN)'], ['ITIN', 'Individual Taxpayer ID (ITIN)']] : [['FOREIGN_TIN', 'National tax ID (TIN)'], ['NIN', 'National ID number (NIN)']];
}

const OB_VALIDATE = {
  b(d) {
    const e = {};
    if (!ASCII_NAME_RE.test(d.firstName || '')) e.firstName = 'Use standard ASCII letters only (no é, и, Chinese, etc.)';
    if (!ASCII_NAME_RE.test(d.lastName || '')) e.lastName = 'Use standard ASCII letters only (no é, и, Chinese, etc.)';
    const age = ageOf(d.dateOfBirth);
    if (age == null) e.dateOfBirth = 'Select your date of birth';
    else if (age < 18) e.dateOfBirth = 'You must be 18 or older to open an account';
    else if (age > 120) e.dateOfBirth = 'Check your date of birth';
    if (!d.citizenship) e.citizenship = 'Select your citizenship';
    if (!d.taxResidency) e.taxResidency = 'Select your country of tax residence';
    if (!PHONE_RE.test((d.phone || '').trim())) e.phone = 'Enter a valid phone number with country code';
    if (!d.language) e.language = 'Select a language';
    const ce = (d.contactEmail ?? defaultContactEmail()).trim();
    if (!/^\S+@\S+\.\S+$/.test(ce)) e.contactEmail = 'Enter a valid contact email';
    else if (ce.endsWith(RELAY_DOMAIN)) e.contactEmail = 'Enter a real email we can reach you at (relay email support TBC by DW)';
    return e;
  },
  c(d) {
    const e = {};
    if (!d.usTaxPayer) e.usTaxPayer = 'Please answer this question';
    const t = (d.tin || '').trim();
    if (d.tinType === 'SSN' && !/^\d{3}-?\d{2}-?\d{4}$/.test(t)) e.tin = 'SSN format: 123-45-6789';
    else if (d.tinType === 'ITIN' && !/^9\d{2}-?\d{2}-?\d{4}$/.test(t)) e.tin = 'ITIN starts with 9: 9XX-XX-XXXX';
    else if (!t || t.length < 5) e.tin = 'Enter your full tax ID';
    if (d.usTaxPayer === 'NO' && !d.taxTreaty) e.taxTreaty = 'Please answer this question';
    if (!d.tinConfirm) e.tinConfirm = 'Confirm this is the number you use to file taxes';
    return e;
  },
  d(d) {
    const e = {};
    if (!d.line1) e.line1 = 'Enter your street address';
    else if (PO_BOX_RE.test(`${d.line1} ${d.line2 || ''}`)) e.line1 = 'Home address cannot be a P.O. Box — enter where you actually live';
    if (!d.city) e.city = 'Enter your city';
    if (!d.postalCode) e.postalCode = 'Enter your ZIP / postal code';
    if (d.country === 'US' && !d.state) e.state = 'Enter your state';
    if (d.hasMailing && !d.mailLine1) e.mailLine1 = 'Enter your mailing address';
    return e;
  },
  e(d) {
    const e = {};
    if (!d.employmentStatus) e.employmentStatus = 'Select your employment status';
    if ((d.employmentStatus === 'EMPLOYED' || d.employmentStatus === 'SELF_EMPLOYED') && !d.employerName) e.employerName = 'Employer name is required when employed';
    if (!d.annualIncome) e.annualIncome = 'Select your annual income';
    if (!d.netWorth) e.netWorth = 'Select your net worth';
    if (!d.netWorthLiquid) e.netWorthLiquid = 'Select your liquid net worth';
    if (!d.experience) e.experience = 'Select your investment experience';
    if (!d.objective) e.objective = 'Select your investment objective';
    if (!d.risk) e.risk = 'Select your risk tolerance';
    if (!(d.fundingSources || []).length) e.fundingSources = 'Select at least one source of funds';
    return e;
  },
  f(d) {
    const e = {};
    if (!d.isAffiliated) e.isAffiliated = 'Please answer this question';
    if (d.isAffiliated === 'YES') { if (!d.affiliatedFirm) e.affiliatedFirm = 'Enter the firm name'; if (!d.affiliatedAck) e.affiliatedAck = 'Confirm you understand the notification requirements'; }
    if (!d.isPEP) e.isPEP = 'Please answer this question';
    if (d.isPEP === 'YES' && !d.pepName) e.pepName = 'Enter the name of the PEP';
    if (!d.isControl) e.isControl = 'Please answer this question';
    if (d.isControl === 'YES' && !d.controlCompany) e.controlCompany = 'Enter the company name or ticker';
    return e;
  },
};
function obSubmittedGuard(title) {
  const s = Store.state;
  if (s.accountStatus !== 'SUBMITTED' && s.accountStatus !== 'APPROVED') return null;
  return { title, body: `<div class="state">${C.notice('info', 'Your application has been submitted — no need to fill it in again.')}<button class="btn primary" data-go="${Onb.status()?.go || '#/p06'}">View application status</button></div>` };
}
function obNextAfter(step) { // 返回确认页（P-30）或进入下一步
  const a = Store.state.application;
  if (a.returnTo === 'p30') { a.step = 'p30'; Store.save(); return Router.go('#/p30'); }
  const order = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
  const n = order[order.indexOf(step) + 1];
  if (n) { a.step = n; Store.save(); return Router.go('#/p03?step=' + n); }
  a.step = DWSim.isUS() ? 'p05' : 'p04'; Store.save(); Router.go('#/' + a.step);
}

Pages.p03 = {
  auth: true,
  backTo: '#/p07',
  render(p, ctx) {
    const g = obSubmittedGuard('Account opening'); if (g) return g;
    const app = Store.state.application;
    const step = p.step || (app.step && app.step.length === 1 ? app.step : 'a');
    ctx.form = app.data;
    const d = app.data;
    const e = ctx.errors || {};
    const yesno = (bind, q, extra = '') => `<div class="card"><div class="b small">${q}</div>${C.yn(bind, d[bind])}${e[bind] ? `<div class="err-msg">${e[bind]}</div>` : ''}${d[bind] === 'YES' && extra ? `<div class="mt12">${extra}</div>` : ''}</div>`;
    let body = '';
    let next = 'Continue';
    switch (step) {
      case 'a':
        next = app.step && app.step !== 'a' ? 'Resume application' : 'Start application';
        body = `
          <div class="hero"><div class="small muted">INDIVIDUAL BROKERAGE ACCOUNT</div><div style="font-size:22px;font-weight:700;margin-top:4px">Let's open your account</div><div class="small muted mt8">Opened and held by our partner broker DriveWealth. Most U.S. taxpayers verify with a tax ID, no ID photos needed; international applicants upload one. Verification time TBC by DW.</div></div>
          <div class="sec-title">What you'll need</div>
          <div class="list">
            ${C.li({ icon: 'shield', title: 'Your SSN / ITIN / national tax ID', sub: 'Used to verify your identity and for tax reporting' })}
            ${C.li({ icon: 'id', title: 'A government-issued photo ID', sub: 'International applicants upload a passport or ID card' })}
            ${C.li({ icon: 'clock', title: 'About 5 minutes', sub: 'You can pause and come back anytime' })}
          </div>
          ${C.notice('info', `Your information is encrypted, sent to ${APP_NAME}, then submitted to DriveWealth for identity verification. ${C.tag('7')}`)}`;
        break;
      case 'b':
        body = `${obProgress('b')}
          ${C.two({ label: 'First name' + C.tag('1'), bind: 'firstName', value: d.firstName, placeholder: 'Jane', error: e.firstName, attrs: 'autocapitalize="words"' }, { label: 'Last name', bind: 'lastName', value: d.lastName, placeholder: 'Doe', error: e.lastName })}
          <div class="hint" style="margin:-8px 0 12px">Use standard ASCII characters only, exactly as on your government ID.</div>
          ${C.field({ label: 'Date of birth' + C.tag('4'), bind: 'dateOfBirth', value: d.dateOfBirth, type: 'date', error: e.dateOfBirth, hint: 'You must be 18 or older to open an account.' })}
          ${C.field({ label: 'Citizenship', bind: 'citizenship', value: d.citizenship, options: COUNTRIES, error: e.citizenship })}
          ${C.field({ label: 'Country of tax residence', bind: 'taxResidency', value: d.taxResidency, options: COUNTRIES, error: e.taxResidency })}
          ${C.field({ label: 'Phone number (with country code)', bind: 'phone', value: d.phone, type: 'tel', placeholder: '+1 415 555 0142', error: e.phone })}
          ${C.field({ label: 'Contact email', bind: 'contactEmail', value: d.contactEmail ?? defaultContactEmail(), type: 'email', error: e.contactEmail, hint: Store.state.user.emailIsRelay ? 'You signed in with Apple Hide My Email. Enter an email we can reach you at; used for broker notices and documents (relay email support TBC by DW).' : 'Defaults to your sign-in email. Used for broker notices and documents.' })}
          ${C.field({ label: 'Language for documents & notices', bind: 'language', value: d.language, options: LANGS, error: e.language })}`;
        break;
      case 'c': {
        const opts = tinOptions(d);
        if (!opts.some((o) => o[0] === d.tinType)) d.tinType = opts[0][0];
        const us = d.usTaxPayer === 'YES';
        body = `${obProgress('c')}
          ${yesno('usTaxPayer', 'Are you a U.S. taxpayer?<div class="xs muted mt8" style="font-weight:400">U.S. citizens, green-card holders and other U.S. tax residents.</div>')}
          ${d.usTaxPayer ? `
          ${C.field({ label: 'Tax ID type' + C.tag('3', 'PDF-1'), bind: 'tinType', value: d.tinType, options: opts })}
          <div class="field ${e.tin ? 'err' : ''}"><label>Tax ID</label>
            <div class="row"><input class="input grow" type="${ctx.showTin ? 'text' : 'password'}" data-bind="tin" value="${esc(d.tin || '')}" placeholder="${d.tinType === 'SSN' ? '123-45-6789' : ''}" autocomplete="off"><button class="btn ghost sm" data-act="toggleTin" type="button">${ctx.showTin ? 'Hide' : 'Show'}</button></div>
            ${e.tin ? `<div class="err-msg">${e.tin}</div>` : '<div class="hint">We encrypt it and never display it in full again.</div>'}</div>
          ${us ? yesno('irsBackup', 'Has the IRS notified you that your account is subject to backup withholding?')
            : yesno('taxTreaty', 'Does your country of tax residence have a tax treaty with the U.S., and do you want to claim treaty rates?<div class="xs muted mt8" style="font-weight:400">Used to prepare your W-8BEN. Final form per DriveWealth requirements.</div>')}
          <label class="check"><input type="checkbox" data-bind="tinConfirm" ${d.tinConfirm ? 'checked' : ''}><span>I confirm this is my own government-issued number, used to file taxes.</span></label>
          ${e.tinConfirm ? `<div class="err-msg">${e.tinConfirm}</div>` : ''}` : ''}`;
        break;
      }
      case 'd':
        body = `${obProgress('d')}
          ${C.notice('warn', 'Enter the address where you <b>actually live</b>. P.O. Boxes are not accepted. ' + C.tag('2'))}
          ${C.field({ label: 'Country/region', bind: 'country', value: d.country, options: COUNTRIES })}
          ${C.field({ label: 'Street address', bind: 'line1', value: d.line1, placeholder: '200 Market Street', error: e.line1 })}
          ${C.field({ label: 'Apt, suite, floor (optional)', bind: 'line2', value: d.line2, placeholder: 'Apt 5B' })}
          ${C.two({ label: 'City', bind: 'city', value: d.city, error: e.city }, { label: 'State/Province', bind: 'state', value: d.state, error: e.state })}
          ${C.field({ label: 'ZIP / Postal code', bind: 'postalCode', value: d.postalCode, error: e.postalCode })}
          <label class="check"><input type="checkbox" data-bind="hasMailing" ${d.hasMailing ? 'checked' : ''}><span>My mailing address is different</span></label>
          ${d.hasMailing ? C.field({ label: 'Mailing address (P.O. Box allowed)', bind: 'mailLine1', value: d.mailLine1, error: e.mailLine1 }) : ''}`;
        break;
      case 'e': {
        const employed = d.employmentStatus === 'EMPLOYED' || d.employmentStatus === 'SELF_EMPLOYED';
        body = `${obProgress('e')}
          ${C.field({ label: 'Employment status' + C.tag('PDF-1'), bind: 'employmentStatus', value: d.employmentStatus, options: EMPLOY, error: e.employmentStatus })}
          ${employed ? C.field({ label: d.employmentStatus === 'SELF_EMPLOYED' ? 'Business name' : 'Employer name', bind: 'employerName', value: d.employerName, error: e.employerName }) + C.field({ label: 'Occupation (optional)', bind: 'occupation', value: d.occupation }) : ''}
          ${C.field({ label: 'Annual income', bind: 'annualIncome', value: d.annualIncome, options: INCOME, error: e.annualIncome })}
          ${C.field({ label: 'Net worth', bind: 'netWorth', value: d.netWorth, options: NETWORTH, error: e.netWorth })}
          ${C.field({ label: 'Liquid net worth', bind: 'netWorthLiquid', value: d.netWorthLiquid, options: NETWORTH, error: e.netWorthLiquid, hint: 'Assets you can quickly convert to cash: deposits, stocks, etc.' })}
          <div class="field ${e.fundingSources ? 'err' : ''}" data-field="fundingSources"><label>Sources of funds (select all that apply) ${C.tag('PDF-1')}</label>
            <div class="row" style="flex-wrap:wrap;gap:8px">${FUND_SOURCES.map(([v, l]) => `<button class="chip ${(d.fundingSources || []).includes(v) ? 'on' : ''}" data-act="toggleFund" data-val="${v}">${l}</button>`).join('')}</div>
            ${e.fundingSources ? `<div class="err-msg">${e.fundingSources}</div>` : '<div class="hint">For AML checks. Final options TBC by DW.</div>'}</div>
          <div class="sec-title" style="font-size:15px">Investor profile</div>
          ${C.field({ label: 'Investment experience', bind: 'experience', value: d.experience, options: EXPERIENCE, error: e.experience })}
          ${C.field({ label: 'Investment objective', bind: 'objective', value: d.objective, options: OBJECTIVE, error: e.objective })}
          ${C.field({ label: 'Risk tolerance', bind: 'risk', value: d.risk, options: RISK, error: e.risk })}
          <div class="xs faint">All fields above are required by DriveWealth to open your account.</div>`;
        break;
      }
      case 'f':
        body = `${obProgress('f')}
          <div class="small muted mb12" style="margin-top:-8px">${C.tag('5', 'PDF-2')}</div>
          ${yesno('isAffiliated', '1. Are you, or anyone with a beneficial interest in this account, employed by a registered broker-dealer, FINRA or a securities exchange?',
            C.field({ label: 'Firm name', bind: 'affiliatedFirm', value: d.affiliatedFirm, error: e.affiliatedFirm }) +
            `<div class="notice info">Under FINRA rules you may need to notify your employer in writing, and your employer may request duplicate account statements.</div>
             <label class="check"><input type="checkbox" data-bind="affiliatedAck" ${d.affiliatedAck ? 'checked' : ''}><span>I understand the notification requirements above</span></label>${e.affiliatedAck ? `<div class="err-msg">${e.affiliatedAck}</div>` : ''}`)}
          ${yesno('isPEP', '2. Are you a politically exposed person (PEP)?<div class="xs muted mt8" style="font-weight:400">Someone who holds or has held a prominent public position: heads of state, senior government, judicial or military officials, senior executives of state-owned enterprises, important party officials, plus their immediate family and close associates.</div>',
            C.field({ label: 'Name of the PEP', bind: 'pepName', value: d.pepName, error: e.pepName }) +
            C.field({ label: 'Country/region', bind: 'pepCountry', value: d.pepCountry, options: COUNTRIES }) +
            C.field({ label: 'Role and years held', bind: 'pepRole', value: d.pepRole, placeholder: 'e.g. City council member, 2015–2020' }))}
          ${yesno('isControl', '3. Are you a director, 10% shareholder or policy-making officer of a publicly traded company?',
            C.field({ label: 'Company name or ticker', bind: 'controlCompany', value: d.controlCompany, error: e.controlCompany }))}`;
        break;
      case 'g':
        next = DWSim.isUS() ? 'Continue: Disclosures' : 'Continue: Upload ID';
        body = `${obProgress('g')}
          <div class="small muted mb12">The account you'll open ${C.tag('6')}</div>
          <div class="card" style="border:1.5px solid var(--primary-weak)">
            <div class="row between"><span class="b">Cash account · Self-directed</span>${C.badge('Only type at launch', 'ok')}</div>
            <div class="xs muted mt8">Trade with settled funds only, no margin. You make all investment decisions.</div>
            <div class="hr"></div>
            ${C.kv('accountType', '<span class="num">LIVE</span>')}${C.kv('tradingType', '<span class="num">CASH</span>')}${C.kv('accountManagementType', '<span class="num">SELF</span>')}
          </div>
          <div class="small muted mb8 mt16">Not yet available</div>
          <div class="opt" style="opacity:.5;pointer-events:none"><span class="radio"></span><div class="grow"><div class="b">Margin account (MARGIN)</div><div class="xs muted">Not yet available · TBC by DW</div></div></div>
          <div class="opt" style="opacity:.5;pointer-events:none"><span class="radio"></span><div class="grow"><div class="b">Advisor-managed (RIA_MANAGED)</div><div class="xs muted">Not yet available · TBC by DW</div></div></div>
          ${C.notice('info', 'Account type is fixed. Whether riaID / riaProductID must be omitted for SELF accounts is TBC with DW; final combinations subject to DW sandbox testing.')}`;
        break;
      default:
        return Pages.s01.render({ type: 'notfound' });
    }
    if (app.returnTo === 'p30' && step !== 'a') next = 'Save & back to review';
    return {
      title: 'Account opening',
      body,
      footer: `${step !== 'a' && app.returnTo !== 'p30' ? '<button class="btn ghost" style="width:auto;white-space:nowrap;flex:none" data-act="saveExit">Save & exit</button>' : ''}<button class="btn primary" data-act="next" data-step="${step}">${next}</button>${step === 'c' ? `<div class="trust-note">${Icon('lock', 12)} Encrypted in transit and at rest</div>` : ''}`,
    };
  },
  onInput(el, ctx) {
    const s = Store.state;
    const a = s.application;
    if (s.accountStatus === 'NONE') s.accountStatus = 'DRAFT';
    a.data = ctx.form;
    const b = el.dataset.bind;
    const d = a.data;
    // 国籍 / 税务居民变化时，预填"是否美国纳税人"（用户仍可修改）
    if (b === 'citizenship' || b === 'taxResidency') d.usTaxPayer = d.citizenship === 'US' || d.taxResidency === 'US' ? 'YES' : 'NO';
    if (b === 'usTaxPayer') { d.tinType = tinOptions(d)[0][0]; d.tin = ''; }
    Store.save();
    if ((b === 'firstName' || b === 'lastName') && el.value && !ASCII_NAME_RE.test(el.value)) showFieldErr(b, 'Standard ASCII letters only (no é, и, Chinese, etc.)');
    else if (b === 'line1' && PO_BOX_RE.test(el.value)) showFieldErr(b, 'Home address cannot be a P.O. Box');
    else if (['firstName', 'lastName', 'line1'].includes(b)) showFieldErr(b, '');
    if (el.tagName === 'SELECT' || el.type === 'checkbox') Router.refresh();
  },
  actions: {
    toggleTin() { const ctx = Router.current.ctx; ctx.showTin = !ctx.showTin; Router.refresh(); },
    next(el, ctx) {
      const step = el.dataset.step;
      const a = Store.state.application;
      const v = OB_VALIDATE[step];
      const e = v ? v(a.data) : {};
      ctx.errors = e;
      if (Object.keys(e).length) { Router.refresh(); UI.toast('Please fix the highlighted fields'); return; }
      if (Store.state.accountStatus === 'NONE') Store.state.accountStatus = 'DRAFT';
      ctx.errors = {};
      obNextAfter(step);
    },
    saveExit() { Store.save(); UI.toast('Progress saved. Come back anytime'); Router.go('#/p07'); },
    toggleFund(el) {
      const s = Store.state; const d = s.application.data;
      const set = new Set(d.fundingSources || []);
      set.has(el.dataset.val) ? set.delete(el.dataset.val) : set.add(el.dataset.val);
      d.fundingSources = [...set];
      if (s.accountStatus === 'NONE') s.accountStatus = 'DRAFT';
      Store.save(); Router.refresh();
    },
  },
};
function showFieldErr(bind, msg) {
  const f = document.querySelector(`[data-field="${bind}"]`);
  if (!f) return;
  f.classList.toggle('err', !!msg);
  let m = f.querySelector('.err-msg');
  const ph = f.querySelector('.hint-empty');
  if (msg) {
    if (!m) { m = document.createElement('div'); m.className = 'err-msg'; f.appendChild(m); }
    m.textContent = msg; if (ph) ph.remove();
  } else if (m) {
    m.remove();
    if (f.parentElement && f.parentElement.classList.contains('two') && !f.querySelector('.hint')) { const d = document.createElement('div'); d.className = 'hint hint-empty'; d.setAttribute('aria-hidden', 'true'); f.appendChild(d); }
  }
}

/* ---------- 证件上传组件（P-04、P-35 共用） ---------- */
function uploadBox(bind, label, value) {
  return `<label class="upload ${value ? 'done' : ''}"><input type="file" accept="image/*,application/pdf" capture="environment" data-bind="${bind}">${Icon(value ? 'check' : 'camera', 24, '')}<div class="small mt8">${value ? `Uploaded: ${esc(value)} · Tap to retake` : `Take a photo or upload · ${label}`}</div></label>`;
}
const needsBack = (t) => t && t !== 'PASSPORT';
function docUploader(k) {
  const t = k.docType || 'PASSPORT';
  return `${C.field({ label: 'Document type', bind: 'docType', value: t, options: ID_TYPES })}
    ${uploadBox('front', t === 'PASSPORT' ? 'Passport photo page (FRONT)' : 'Front of ID (FRONT)', k.front)}
    ${needsBack(t) ? uploadBox('back', 'Back of ID (BACK)', k.back) : ''}
    <div class="center"><button class="link-btn xs" data-act="sampleDoc" style="color:var(--faint)">(Prototype) Use sample images</button></div>`;
}
function docReady(k) { return !!k.front && (!needsBack(k.docType || 'PASSPORT') || !!k.back); }
function docOnInput(k, el) {
  if (el.type === 'file') { const f = el.files && el.files[0]; if (f) k[el.dataset.bind] = f.name; Store.save(); Router.refresh(); return; }
  k[el.dataset.bind] = el.value;
  if (el.dataset.bind === 'docType') { k.front = ''; k.back = ''; }
  Store.save();
  if (el.tagName === 'SELECT') Router.refresh();
}
function docSample(k) { k.front = 'sample_front.jpg'; if (needsBack(k.docType || 'PASSPORT')) k.back = 'sample_back.jpg'; Store.save(); Router.refresh(); }
const DOC_TIPS = `<div class="card"><div class="b small mb8">Photo requirements</div>
  <div class="tips">${['All four corners visible, nothing covered or cropped', 'Even lighting, no glare or shadows', 'Document is not expired', 'Name matches your application'].map((t) => `<div class="row small" style="gap:8px;padding:4px 0">${Icon('check', 16, 'up')}<span>${t}</span></div>`).join('')}</div>
  <svg viewBox="0 0 200 92" width="100%" height="92" style="margin-top:8px"><rect x="40" y="6" width="120" height="80" rx="8" fill="none" stroke="var(--line)" stroke-width="2"/><rect x="52" y="20" width="32" height="40" rx="4" fill="none" stroke="var(--faint)" stroke-width="1.5"/><path d="M96 26h50M96 38h40M96 50h46M52 72h94" stroke="var(--faint)" stroke-width="1.5"/><path d="M34 16V0h16M166 0h16v16M182 76v16h-16M50 92H34V76" fill="none" stroke="var(--primary)" stroke-width="2.5"/></svg></div>`;

/* ---------- P-04 证件上传（开户流程中，仅非美国纳税人） ---------- */
Pages.p04 = {
  auth: true,
  backTo: '#/p03?step=g',
  render(p, ctx) {
    const g = obSubmittedGuard('Identity document'); if (g) return g;
    const app = Store.state.application;
    if (DWSim.isUS()) {
      return { title: 'Identity verification', body: `${C.notice('ok', 'U.S. taxpayers are verified by DriveWealth with their tax ID after submission, so <b>no ID upload is needed</b>. We will notify you if a document is required. ' + C.tag('3'))}`, footer: '<button class="btn primary" data-go="#/p05">Continue: Disclosures</button>' };
    }
    const k = app.kyc;
    ctx.form = k;
    return {
      title: 'Identity document',
      body: `${obProgress('p04')}
        ${C.notice('info', 'Upload a valid government-issued photo ID. It is encrypted and submitted to DriveWealth with your application for identity verification. ' + C.tag('3', 'PDF-1'))}
        ${docUploader(k)}${DOC_TIPS}
        <div class="xs faint">Whether a selfie / liveness check is required is TBC by DriveWealth.</div>`,
      footer: `<button class="btn primary" data-act="next" ${docReady(k) ? '' : 'disabled'}>${app.returnTo === 'p30' ? 'Save & back to review' : 'Continue: Disclosures'}</button>`,
    };
  },
  onInput(el) { docOnInput(Store.state.application.kyc, el); },
  actions: {
    sampleDoc() { docSample(Store.state.application.kyc); },
    next() {
      const a = Store.state.application;
      if (!docReady(a.kyc)) return UI.toast('Please upload your ID photos first');
      a.kyc.uploadedAt = nowStr();
      a.step = a.returnTo === 'p30' ? 'p30' : 'p05'; Store.save(); Router.go('#/' + a.step);
    },
  },
};

/* ---------- P-05 披露确认（按 DW DISCLOSURES 字段） ---------- */
const DW_DOCS = [
  ['termsOfUse', 'Terms of Use'],
  ['customerAgreement', 'Customer Account Agreement'],
  ['marketDataAgreement', 'Market Data Agreement'],
  ['privacyPolicy', 'Privacy Policy'],
  ['dataSharing', 'Data Sharing Consent'],
];
const PARTNER_DOCS = [
  ['p_terms', 'FinX Terms of Service'],
  ['p_privacy', 'FinX Privacy Policy'],
  ['p_risk', 'FinX Investment Risk Disclosure'],
];
function discReady(ds) {
  const d = Store.state.application.data;
  const fullName = `${d.firstName || ''} ${d.lastName || ''}`.trim();
  const sigOk = !!fullName && (ds.signature || '').trim().toLowerCase() === fullName.toLowerCase();
  return [...DW_DOCS, ...PARTNER_DOCS].every(([id]) => ds[id]) && !!ds.rule14b && !!ds.esign && sigOk;
}
Pages.p05 = {
  auth: true,
  backTo: '#/p03?step=g',
  render(p, ctx) {
    const g = obSubmittedGuard('Disclosures'); if (g) return g;
    const app = Store.state.application;
    const ds = app.disclosures;
    ctx.form = ds;
    const d = app.data;
    const fullName = `${d.firstName || ''} ${d.lastName || ''}`.trim();
    const sigBad = ds.signature && ds.signature.trim().toLowerCase() !== fullName.toLowerCase();
    const docRow = ([id, title]) => `<div class="row" style="padding:10px 0;border-top:1px solid var(--line)">
        <label class="check grow" style="padding:0"><input type="checkbox" data-bind="${id}" ${ds[id] ? 'checked' : ''}><span>I have read and agree to the <b>${title}</b></span></label>
        <button class="link-btn xs" data-act="openDoc" data-id="${id}" data-title="${esc(title)}">View</button></div>`;
    return {
      title: 'Disclosures',
      body: `${obProgress('p05')}
        <div class="card" style="border:1.5px solid var(--accent)">
          <div class="row between"><div class="b">DriveWealth disclosures ${C.tag('8', 'PDF-4')}</div>${C.badge('Broker', 'info')}</div>
          <div class="xs muted mt8">Your brokerage account is opened and held by DriveWealth, LLC. Please read these documents before opening. Full documents: <a href="${DW_DISCLOSURE_URL}" target="_blank" rel="noopener">${DW_DISCLOSURE_URL}</a></div>
          <div class="mt8">${DW_DOCS.map(docRow).join('')}</div>
          <div style="padding:10px 0;border-top:1px solid var(--line)">
            <div class="small"><b>Rule 14b-1(c) shareholder disclosure</b>: When an issuer requests it, do you consent to the broker sharing your name, address and positions for shareholder communications?</div>
            ${C.yn('rule14b', ds.rule14b)}<div class="xs faint">Choosing No does not affect your application.</div>
          </div>
          <label class="check" style="border-top:1px solid var(--line);padding-top:10px"><input type="checkbox" data-bind="extendedHoursAgreement" ${ds.extendedHoursAgreement ? 'checked' : ''}><span>(Optional) I agree to the <b>Extended Hours Trading Agreement</b></span></label>
          <div class="xs faint">Document names and fields per official DriveWealth materials.</div>
        </div>
        <div class="card">
          <div class="row between"><div class="b">${APP_NAME} platform terms</div>${C.badge('Platform')}</div>
          <div class="mt8">${PARTNER_DOCS.map(docRow).join('')}</div>
        </div>
        <div class="card">
          <div class="b mb8">Electronic signature consent</div>
          <label class="check"><input type="checkbox" data-bind="esign" ${ds.esign ? 'checked' : ''}><span class="small">I agree to receive documents and sign agreements electronically under the E-Sign Act of 2000, and confirm my electronic signature has the same legal effect as a handwritten one. I may withdraw this consent or request paper copies at any time.</span></label>
          ${C.field({ label: `Type your legal name to sign (${esc(fullName || '—')})`, bind: 'signature', value: ds.signature, placeholder: fullName, error: sigBad ? 'Signature must match your legal name' : '' })}
        </div>`,
      footer: `<button class="btn primary" data-act="next" ${discReady(ds) ? '' : 'disabled'}>${app.returnTo === 'p30' ? 'Save & back to review' : 'Continue: Review'}</button>`,
    };
  },
  onInput(el) {
    const ds = Store.state.application.disclosures;
    if (el.tagName === 'BUTTON') { ds.rule14bAt = new Date().toISOString(); Store.save(); return; } // 是/否 按钮由 setYN 写入
    ds[el.dataset.bind] = el.type === 'checkbox' ? el.checked : el.value;
    if (el.type === 'checkbox') ds[el.dataset.bind + 'At'] = new Date().toISOString();
    Store.save();
    if (el.type === 'checkbox') Router.refresh();
    else { const btn = document.querySelector('[data-act="next"]'); if (btn) btn.disabled = !discReady(ds); }
  },
  actions: {
    openDoc(el) {
      const isDW = !el.dataset.id.startsWith('p_');
      UI.sheet(esc(el.dataset.title), `<div class="doc-paper">${isDW ? `[DriveWealth disclosure document]\n\nThe full official document appears here.\nPlaceholder text in this prototype.\n\nOfficial address:\n${DW_DISCLOSURE_URL}` : `[${APP_NAME} platform document]\n\nThe full platform terms appear here.\nPlaceholder text in this prototype.`}</div>
        ${isDW ? `<a class="btn ghost mt12" href="${DW_DISCLOSURE_URL}" target="_blank" rel="noopener">Open the official page in your browser</a>` : ''}`);
    },
    next() {
      const a = Store.state.application;
      if (!discReady(a.disclosures)) return;
      a.step = 'p30'; Store.save(); Router.go('#/p30');
    },
  },
};

/* ---------- P-30 开户资料确认（提交即由我方后端创建 DW User） ---------- */
Pages.p30 = {
  auth: true,
  backTo: '#/p05',
  render(p, ctx) {
    const g = obSubmittedGuard('Review & submit'); if (g) return g;
    const s = Store.state;
    const app = s.application;
    const d = app.data, ds = app.disclosures, k = app.kyc;
    if (ctx.submitting) {
      return { title: 'Review & submit', noBack: true, body: `<div class="state"><div class="spinner"></div><h2 class="mt16">Submitting</h2><p>Securely sending your application to our partner broker. Please keep this page open.</p></div>` };
    }
    const bad = {};
    ['b', 'c', 'd', 'e', 'f'].forEach((st) => { if (Object.keys(OB_VALIDATE[st](d)).length) bad[st] = true; });
    if (!DWSim.isUS() && !docReady(k)) bad.p04 = true;
    if (!discReady(ds)) bad.p05 = true;
    const group = (title, step, rows, tags = '') => `<div class="card" ${bad[step] ? 'style="border:1.5px solid var(--danger)"' : ''}>
      <div class="row between"><span class="b">${title}${tags}</span><span class="row" style="gap:6px">${bad[step] ? C.badge('Incomplete', 'danger') : ''}<button class="link-btn xs" data-act="edit" data-step="${step}">Edit</button></span></div>
      <div class="mt8">${rows.map(([k2, v]) => C.kv(k2, esc(v ?? '—'))).join('')}</div></div>`;
    const us = d.usTaxPayer === 'YES';
    const employed = d.employmentStatus === 'EMPLOYED' || d.employmentStatus === 'SELF_EMPLOYED';
    const signed = [...DW_DOCS, ...PARTNER_DOCS].filter(([id]) => ds[id]).length;
    const body = `${obProgress('p30')}
      
      ${group('Identity', 'b', [['Name', `${d.firstName || ''} ${d.lastName || ''}`], ['Date of birth', d.dateOfBirth], ['Citizenship', lab(COUNTRIES, d.citizenship)], ['Tax residence', lab(COUNTRIES, d.taxResidency)], ['Phone', d.phone], ['Contact email', d.contactEmail ?? defaultContactEmail()], ['Sign-in method', { EMAIL: 'Email code', GOOGLE: 'Google', APPLE: 'Apple' }[s.user.loginProvider] || '—'], ['Language', lab(LANGS, d.language)]], C.tag('1', '4'))}
      ${group('Tax', 'c', [['U.S. taxpayer', ynLab(d.usTaxPayer)], ['Tax ID type', lab(tinOptions(d), d.tinType)], ['Tax ID', maskTin(d.tin)], us ? ['IRS backup withholding', ynLab(d.irsBackup)] : ['Tax treaty claimed', ynLab(d.taxTreaty)]], C.tag('3'))}
      ${group('Home address', 'd', [['Address', [d.line1, d.line2].filter(Boolean).join(', ')], ['City / State', [d.city, d.state].filter(Boolean).join(', ')], ['ZIP', d.postalCode], ['Country', lab(COUNTRIES, d.country)]], C.tag('2'))}
      ${group('Employment & finances', 'e', [['Employment status', lab(EMPLOY, d.employmentStatus)], ...(employed ? [['Employer', d.employerName]] : []), ['Annual income', lab(INCOME, d.annualIncome)], ['Net worth', lab(NETWORTH, d.netWorth)], ['Liquid net worth', lab(NETWORTH, d.netWorthLiquid)], ['Experience', lab(EXPERIENCE, d.experience)], ['Objective', lab(OBJECTIVE, d.objective)], ['Risk tolerance', lab(RISK, d.risk)], ['Sources of funds', (d.fundingSources || []).map((v) => lab(FUND_SOURCES, v)).join(', ') || '—']], C.tag('PDF-1'))}
      ${group('Compliance', 'f', [['Broker-dealer / FINRA / exchange', ynLab(d.isAffiliated)], ['Politically exposed person', ynLab(d.isPEP)], ['Public company control person', ynLab(d.isControl)]], C.tag('5', 'PDF-2'))}
      ${group('Account type', 'g', [['Type', 'Cash account · Self-directed'], ['accountType', 'LIVE'], ['tradingType', 'CASH'], ['accountManagementType', 'SELF'], ['riaID / riaProductID', 'Omission TBC with DW']], C.tag('6'))}
      ${DWSim.isUS() ? '' : group('Identity document', 'p04', [['Document type', lab(ID_TYPES, k.docType || 'PASSPORT')], ['Front', k.front], ...(needsBack(k.docType || 'PASSPORT') ? [['Back', k.back]] : [])])}
      ${group('Signed disclosures', 'p05', [['Documents agreed', `${signed} / ${DW_DOCS.length + PARTNER_DOCS.length}`], ['Rule 14b-1(c)', ds.rule14b === 'YES' ? 'Consent' : ds.rule14b === 'NO' ? 'No consent' : '—'], ['Extended hours agreement', ds.extendedHoursAgreement ? 'Agreed' : 'Not selected'], ['E-signature', ds.signature]], C.tag('8'))}
      ${Object.keys(bad).length ? C.notice('danger', 'Sections marked in red are incomplete. Please fix them before submitting.') : ''}`;
    return {
      title: 'Review & submit',
      body,
      footer: `<button class="btn primary" data-act="submit" ${Object.keys(bad).length ? 'disabled' : ''}>Submit application</button>`,
    };
  },
  actions: {
    edit(el) {
      const st = el.dataset.step;
      Store.state.application.returnTo = 'p30'; Store.save();
      Router.go(st.length === 1 ? '#/p03?step=' + st : '#/' + st);
    },
    submit(el, ctx) {
      ctx.submitting = true; Router.refresh();
      setTimeout(() => { ctx.submitting = false; DWSim.submitUser(); Router.go('#/p06'); }, 900);
    },
  },
};

/* ---------- P-06 开户进度 ---------- */
function stepper(items) {
  return `<div class="card">${items.map(([title, sub, st], i) => {
    const color = { done: 'var(--up)', active: 'var(--primary)', action: 'var(--warn)', fail: 'var(--faint)', todo: 'var(--line)' }[st];
    const ic = st === 'done' ? Icon('check', 14) : st === 'action' ? '!' : st === 'fail' ? Icon('x', 14) : String(i + 1);
    return `<div class="row" style="align-items:flex-start;gap:12px;padding:6px 0">
      <div style="flex:none;width:24px;height:24px;border-radius:50%;display:grid;place-items:center;font-size:12px;font-weight:700;${st === 'todo' ? `border:2px solid ${color};color:var(--faint)` : `background:${color};color:#fff`}">${ic}</div>
      <div class="grow"><div class="${st === 'todo' ? 'muted' : 'b'} small">${title}</div>${sub ? `<div class="xs muted">${sub}</div>` : ''}</div></div>`;
  }).join('')}</div>`;
}
const KYC_EN = { KYC_NOT_READY: 'Information incomplete', KYC_READY: 'Queued for verification', KYC_PROCESSING: 'Verifying your identity', KYC_INFO_REQUIRED: 'Information needs review', KYC_DOC_REQUIRED: 'Document required', KYC_MANUAL_REVIEW: 'Manual review', KYC_APPROVED: 'Verified', KYC_DENIED: 'Could not open account' };
const ACCT_EN = { PENDING: 'Opening', OPEN: 'Open', OPEN_NO_NEW_TRADES: 'Sell only', FROZEN: 'Frozen', CLOSED: 'Closed' };
Pages.p06 = {
  auth: true,
  backTo: '#/p07',
  render() {
    const s = Store.state;
    const app = s.application;
    if (s.accountStatus === 'NONE' || s.accountStatus === 'DRAFT') {
      return { title: 'Application status', body: `<div class="state"><div class="state-ic">${Icon('doc', 36)}</div><h2>No application yet</h2><p>Finish the application form to submit.</p><button class="btn primary mt24" data-go="${Onb.resumeHref()}">Continue application</button></div>` };
    }
    const k = s.dw.kyc;
    const acct = s.dw.account;
    const live = s.accounts.LIVE;
    const opened = s.accountStatus === 'APPROVED';
    const funded = Fund.linked().length > 0 || live.cash > 0 || (live.transactions || []).some((t) => t.type === 'DEPOSIT');
    const kycSt = k === 'KYC_APPROVED' ? 'done' : k === 'KYC_DENIED' ? 'fail' : ['KYC_INFO_REQUIRED', 'KYC_DOC_REQUIRED'].includes(k) ? 'action' : 'active';
    const steps = [
      ['Application submitted', `Ref ${app.ref || '—'} · ${fmt.dt(app.submittedAt)}`, 'done'],
      ['Identity verification (by DriveWealth)', `${KYC_EN[k]}${s.dw.kycUpdatedAt ? ' · ' + s.dw.kycUpdatedAt : ''}`, kycSt],
      ['Account opening', acct ? ACCT_EN[acct] : 'Opens automatically after verification', opened ? 'done' : acct === 'PENDING' ? 'active' : 'todo'],
      ['Fund your account', funded ? 'Bank linked or funded' : opened ? 'Link a bank or wire funds' : 'Available once your account is open', funded ? 'done' : opened ? 'active' : 'todo'],
    ];
    const ob = Onb.status();
    let card = '';
    let footer = '<button class="btn primary" data-go="#/p07">Back to home</button>';
    const simLinks = `<div class="center mt8 xs faint">(Prototype) Simulate DW result: ${[['KYC_APPROVED', 'Approve'], ['KYC_INFO_REQUIRED', 'Info required'], ['KYC_DOC_REQUIRED', 'Doc required'], ['KYC_MANUAL_REVIEW', 'Manual review'], ['KYC_DENIED', 'Deny']].map(([v, l]) => `<button class="link-btn xs" data-act="kyc" data-val="${v}">${l}</button>`).join(' · ')}</div>`;
    if (opened) {
      const r = Acc.restriction() || (live.dwStatus !== 'OPEN' ? { title: ACCT_EN[live.dwStatus], body: '' } : null);
      card = `<div class="card">
          <div class="row between"><span class="b">Your live account is open</span>${C.badge(ACCT_EN[live.dwStatus || 'OPEN'], ACCT_LABEL[live.dwStatus || 'OPEN'][1])}</div>
          <div class="row mt8 small"><span class="muted">Account number ${C.tag('PDF-6')}</span><span class="grow b num right">${esc(live.accountNumber)}</span><button class="nav-btn" style="width:28px;height:28px" data-act="copy" data-val="${esc(live.accountNumber)}">${Icon('copy', 16)}</button></div>
          ${C.kv('Account type' + C.tag('6'), 'Cash account · Self-directed')}
          <div class="xs faint">Created as LIVE · CASH · SELF; riaID / riaProductID omission TBC with DW</div>
        </div>${r ? C.restrict() : ''}`;
      if (!funded) {
        card += `<div class="sec-title" style="font-size:15px">Funding options</div>
          <button class="opt ${Fund.preferWire() ? '' : 'on'}" data-go="${Fund.bindHref('p06')}"><span class="radio"></span>${Icon('bank', 22)}<div class="grow"><div class="b">Link a bank account (ACH)</div><div class="xs muted">U.S. bank account in your own name. No fee.</div></div>${Icon('right', 16, 'chev')}</button>
          <button class="opt ${Fund.preferWire() ? 'on' : ''}" data-go="#/p33"><span class="radio"></span>${Icon('globe', 22)}<div class="grow"><div class="b">Wire transfer</div><div class="xs muted">${Fund.preferWire() ? 'Recommended if you have no U.S. bank account' : 'For large amounts or international banks'}</div></div>${Icon('right', 16, 'chev')}</button>`;
        footer = '<button class="btn ghost" data-go="#/p07">Later</button>';
      } else footer = '<button class="btn ghost" data-go="#/p07">Back to home</button><button class="btn primary" data-go="#/p13">Deposit</button>';
    } else if (k === 'KYC_APPROVED') {
      card = `<div class="card center"><div class="spinner"></div><div class="b mt12">Identity verified. Opening your account</div><div class="xs muted">Timing TBC by DW</div></div>`;
    } else if (k === 'KYC_INFO_REQUIRED' || k === 'KYC_DOC_REQUIRED') {
      card = `<button class="card row" style="width:100%;text-align:left;border:1.5px solid var(--warn)" data-go="${ob.go}"><span class="li-ic" style="color:var(--warn)">${Icon(ob.icon, 18)}</span><span class="grow"><div class="b">${ob.title}</div><div class="xs muted">${ob.sub}</div></span>${Icon('right', 16, 'chev')}</button>`;
      footer = `<button class="btn primary" data-go="${ob.go}">${ob.cta}</button>`;
    } else if (k === 'KYC_DENIED') {
      card = `<button class="card row" style="width:100%;text-align:left" data-go="#/p36"><span class="li-ic">${Icon('info', 18)}</span><span class="grow"><div class="b">Application unsuccessful</div><div class="xs muted">See the result and your options</div></span>${Icon('right', 16, 'chev')}</button>`;
      footer = '<button class="btn primary" data-go="#/p36">View result</button>';
    } else if (k === 'KYC_MANUAL_REVIEW') {
      card = `${C.notice('info', '<b>Manual review</b><br>Our partner broker is reviewing your application (timing TBC by DW). We will notify you. No need to resubmit.')}<button class="btn ghost" data-act="cs">Contact support</button>${simLinks}`;
    } else {
      card = `<div class="card center"><div class="spinner"></div><div class="b mt12">Verifying your identity</div><div class="xs muted">Timing TBC by DW. This page updates automatically.</div></div>${simLinks}<div class="xs faint center">(Prototype) In sandbox the first submission may be approved instantly, depending on the KYC model (TBC with DW).</div>`;
    }
    return {
      title: 'Application status', noBack: true,
      body: `${stepper(steps)}${card}
        <div class="xs faint mt12">Identity verification is performed by our partner broker DriveWealth. ${C.tag('7')}</div>`,
      footer,
    };
  },
  actions: { cs() { UI.toast(`(Prototype) Connected to support · Ref ${Store.state.application.ref}`); } },
};

/* ---------- P-34 补充开户资料（KYC_INFO_REQUIRED） ---------- */
const FIELD_LABEL = { firstName: 'First name', lastName: 'Last name', dateOfBirth: 'Date of birth', line1: 'Street address', line2: 'Apt, suite', city: 'City', state: 'State', postalCode: 'ZIP code', tin: 'Tax ID' };
const ISSUE_FIELDS = { line1: ['line1', 'line2', 'city', 'state', 'postalCode'], dateOfBirth: ['dateOfBirth'], firstName: ['firstName', 'lastName'], lastName: ['firstName', 'lastName'], tin: ['tin'] };
const MAX_ATTEMPTS = 3; // 示例：最多修改次数待确认（pages.md 问题 13）
function kycStateGuard(kyc, title) {
  if (Store.state.dw.kyc === kyc) return null;
  return { title, body: `<div class="state"><div class="state-ic">${Icon('check', 34)}</div><h2>Nothing to do right now</h2><p>Your application has nothing that needs attention.</p><button class="btn primary mt24" data-go="#/p06">View application status</button></div>` };
}
function showVal(f, v) { return f === 'tin' ? maskTin(v) : v || '—'; }
Pages.p34 = {
  auth: true,
  backTo: '#/p06',
  render(p, ctx) {
    const g = kycStateGuard('KYC_INFO_REQUIRED', 'Update your information'); if (g) return g;
    const s = Store.state;
    const d = s.application.data;
    const issues = s.dw.issues;
    if (!ctx.form) { ctx.form = {}; issues.forEach((i) => ISSUE_FIELDS[i.field].forEach((f) => { ctx.form[f] = d[f] || ''; })); }
    const f = ctx.form;
    const e = ctx.errors || {};
    const attempt = (s.dw.attempt || 0) + 1;
    const flagged = new Set(issues.flatMap((i) => ISSUE_FIELDS[i.field]));
    const others = [['Name', `${d.firstName} ${d.lastName}`, 'firstName'], ['Date of birth', d.dateOfBirth, 'dateOfBirth'], ['Tax ID', maskTin(d.tin), 'tin'], ['Address', [d.line1, d.line2, d.city, d.state, d.postalCode].filter(Boolean).join(', '), 'line1'], ['Phone', d.phone], ['Employment status', lab(EMPLOY, d.employmentStatus)], ['Annual income', lab(INCOME, d.annualIncome)]].filter((r) => !flagged.has(r[2]));
    const editor = (fld, pair = false) => C.field({ label: FIELD_LABEL[fld] + (fld === 'line2' ? ' (optional)' : ''), bind: fld, value: f[fld], type: fld === 'dateOfBirth' ? 'date' : 'text', error: e[fld], pair });
    return {
      title: 'Update your information',
      body: `<div class="state" style="min-height:auto;padding:12px 0 4px"><div class="state-ic" style="background:var(--warn-weak);color:var(--warn)">${Icon('edit', 32)}</div>
          <h2>Almost there. Please review the items below</h2><p>Our partner broker could not verify some of your details. Update the highlighted items and resubmit for verification.</p></div>
        ${issues.map((i, n) => `<div class="card" style="border:1.5px solid var(--warn-weak)">
          <div class="row between"><span class="b">${n + 1}. ${FIELD_LABEL[i.field]}</span>${C.badge('Review', 'warn')}</div>
          <div class="xs muted mt8">Currently: ${esc(ISSUE_FIELDS[i.field].map((x) => showVal(x, d[x])).filter((x) => x !== '—').join(', '))}</div>
          <div class="notice warn mt8" style="margin-bottom:12px">${Icon('info', 16)}<div class="small">${esc(i.reason)}</div></div>
          ${i.field === 'line1' ? `${editor('line1')}${editor('line2')}<div class="two">${editor('city', true)}${editor('state', true)}</div>${editor('postalCode')}` : ISSUE_FIELDS[i.field].map(editor).join(i.field === 'firstName' ? '' : '')}
          <label class="check"><input type="checkbox" data-bind="keep_${i.field}" ${f['keep_' + i.field] ? 'checked' : ''}><span class="small">I checked. This is correct, keep as is</span></label>
        </div>`).join('')}
        <details class="faq"><summary>View everything else (no changes needed)${Icon('right', 16, 'chev')}</summary><div style="padding:0 0 8px">${others.map(([k2, v]) => C.kv(k2, esc(v || '—'))).join('')}</div></details>
        <div class="xs muted mt12">Attempt ${attempt} of ${MAX_ATTEMPTS} (sample limit, TBC)${C.tag('1', '2', '3', '4', '24')}</div>`,
      footer: `<button class="btn ghost" style="width:auto" data-act="cs">Contact support</button><button class="btn primary" data-act="submit">Resubmit for verification</button>`,
    };
  },
  onInput(el) {
    const b = el.dataset.bind;
    if ((b === 'firstName' || b === 'lastName') && el.value && !ASCII_NAME_RE.test(el.value)) showFieldErr(b, 'Standard ASCII letters only');
    else if (b === 'line1' && PO_BOX_RE.test(el.value)) showFieldErr(b, 'Home address cannot be a P.O. Box');
    else if (['firstName', 'lastName', 'line1'].includes(b)) showFieldErr(b, '');
    if (el.type === 'checkbox') Router.refresh();
  },
  actions: {
    cs() { UI.toast(`(Prototype) Connected to support · Ref ${Store.state.application.ref}`); },
    submit(el, ctx) {
      const s = Store.state;
      const d = s.application.data;
      const f = ctx.form;
      const merged = { ...d, ...Object.fromEntries(Object.entries(f).filter(([k2]) => !k2.startsWith('keep_'))) };
      const e = {};
      const changes = [];
      s.dw.issues.forEach((i) => {
        const fields = ISSUE_FIELDS[i.field];
        const all = { ...OB_VALIDATE[i.step](merged) };
        fields.forEach((x) => { if (all[x]) e[x] = all[x]; });
        const changed = fields.filter((x) => (merged[x] || '') !== (d[x] || ''));
        if (!changed.length && !f['keep_' + i.field]) e[fields[0]] = e[fields[0]] || 'Update this item, or confirm it is correct';
        changed.forEach((x) => changes.push([FIELD_LABEL[x], showVal(x, d[x]), showVal(x, merged[x])]));
      });
      ctx.errors = e;
      if (Object.keys(e).length) { Router.refresh(); return UI.toast('Please review the highlighted items'); }
      const rows = changes.length ? changes.map(([k2, a, b]) => `<div class="kv"><span>${esc(k2)}</span><span><s class="faint">${esc(a)}</s> → <b>${esc(b)}</b></span></div>`).join('') : '<div>Nothing changed. Your original details will be resubmitted for verification.</div>';
      UI.confirm({
        title: 'Resubmit your application?', body: `${rows}<div class="mt8">Your identity will be verified again after you submit.</div>`, ok: 'Resubmit',
        onOk: () => {
          changes.length && Object.assign(d, Object.fromEntries(Object.entries(f).filter(([k2]) => !k2.startsWith('keep_'))));
          s.dw.attempt = (s.dw.attempt || 0) + 1;
          DWSim.resubmit(); Router.go('#/p06');
        },
      });
    },
  },
};

/* ---------- P-35 补充身份证件（KYC_DOC_REQUIRED） ---------- */
Pages.p35 = {
  auth: true,
  backTo: '#/p06',
  render(p, ctx) {
    const g = kycStateGuard('KYC_DOC_REQUIRED', 'Upload your ID'); if (g) return g;
    const s = Store.state;
    const k = s.dw.docUpload || (s.dw.docUpload = { docType: 'PASSPORT' });
    ctx.form = k;
    return {
      title: 'Upload your ID',
      body: `<div class="state" style="min-height:auto;padding:12px 0 4px"><div class="state-ic" style="background:var(--warn-weak);color:var(--warn)">${Icon('id', 32)}</div>
          <h2>Upload an ID to finish verification</h2><p>${esc(s.dw.docReason || KYC_DOC_REASON)}</p></div>
        <div class="card"><div class="b small mb8">Accepted documents (any one) ${C.tag('3')}</div>
          <div class="row" style="gap:6px;flex-wrap:wrap">${ID_TYPES.map(([, l]) => C.badge(l)).join('')}</div>
          <div class="xs muted mt8">Must be government-issued, photo-bearing and unexpired. Whether proof of address is needed is per broker requirements.</div></div>
        ${docUploader(k)}${DOC_TIPS}
        ${C.notice('info', `Your document is encrypted, sent to ${APP_NAME} and submitted to DriveWealth solely for identity verification.`, 'lock')}`,
      footer: `<button class="btn ghost" style="width:auto" data-act="cs">Contact support</button><button class="btn primary" data-act="submit" ${docReady(k) ? '' : 'disabled'}>Submit document</button>`,
    };
  },
  onInput(el) { docOnInput(Store.state.dw.docUpload, el); },
  actions: {
    sampleDoc() { docSample(Store.state.dw.docUpload); },
    cs() { UI.toast(`(Prototype) Connected to support · Ref ${Store.state.application.ref}`); },
    submit() {
      const s = Store.state;
      if (!docReady(s.dw.docUpload)) return UI.toast('Please upload your ID photos first');
      s.dw.docUpload.uploadedAt = nowStr();
      DWSim.resubmit(); UI.toast('Document submitted. Verifying again'); Router.go('#/p06');
    },
  },
};

/* ---------- P-36 开户未通过（KYC_DENIED） ---------- */
Pages.p36 = {
  auth: true,
  backTo: '#/p07',
  render() {
    const g = kycStateGuard('KYC_DENIED', 'Application result'); if (g) return g;
    const s = Store.state;
    const app = s.application;
    return {
      title: 'Application result',
      body: `<div class="state" style="min-height:auto;padding:20px 0 8px"><div class="state-ic" style="background:var(--surface-2);color:var(--muted)">${Icon('info', 34)}</div>
          <h2>We can't open your account right now</h2><p>This decision was made by our partner broker DriveWealth based on identity verification and compliance requirements. For compliance reasons we cannot share specifics. ${C.tag('7')}</p></div>
        <div class="card">
          <div class="row between"><span class="b">Application reference</span><button class="link-btn xs" data-act="copy" data-val="${esc(app.ref)}">Copy</button></div>
          <div class="num mt8" style="font-size:17px;letter-spacing:.5px">${esc(app.ref)}</div>
          <div class="hr"></div>${C.kv('Decided at', s.dw.kycUpdatedAt || '—')}
        </div>
        <div class="sec-title" style="font-size:15px">What you can do</div>
        <div class="list">
          ${C.li({ icon: 'help', title: 'Contact support', sub: 'Your reference number is attached automatically', act: 'cs' })}
          ${C.li({ icon: 'market', title: 'Keep browsing markets', sub: 'Quotes and watchlists remain available', go: '#/p09' })}
          ${C.li({ icon: 'bars', title: 'Use the paper account', sub: 'Practice with virtual funds', act: 'paper' })}
          ${C.li({ icon: 'trash', title: 'Request deletion of your data', sub: 'Process TBC with legal', act: 'del' })}
        </div>
        <div class="xs faint mt12">(Prototype) Whether and when you can reapply is TBC (pages.md Q12).</div>`,
      footer: '<button class="btn primary" data-go="#/p07">Back to home</button>',
    };
  },
  actions: {
    cs() { UI.toast(`(Prototype) Connected to support · Ref ${Store.state.application.ref}`); },
    paper() { Store.state.mode = 'PAPER'; Store.save(); UI.toast('Switched to the paper account'); Router.go('#/p07'); },
    del() { UI.confirm({ title: 'Request deletion of your submitted data?', body: 'Support will contact you to confirm. Records we must keep for regulators are deleted when the retention period ends. (Process TBC with legal)', ok: 'Submit request', onOk: () => UI.toast('(Prototype) Deletion request submitted') }); },
  },
};
