'use strict';
/* P-01 – P-06、P-30、P-34 – P-36：启动、登录、开户与 KYC 补齐 */

/* ---------- P-01 欢迎页 ---------- */
Pages.p01 = {
  render() {
    if (Store.state.loggedIn) setTimeout(() => Router.go('#/p07'));
    return {
      headerless: true,
      body: `<div class="state">
        <div class="mark">${Icon('market', 34)}</div>
        <h2 class="mt16" style="font-size:26px">${APP_NAME}</h2>
        <p>美股与 ETF 投资，开户、入金、交易一站完成。</p>
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
  const st = [['a', '准备'], ['b', '基本身份'], ['c', '税务'], ['d', '地址'], ['e', '就业与财务'], ['f', '监管问题'], ['g', '账户类型']];
  if (!DWSim.isUS()) st.push(['p04', '证件上传']);
  st.push(['p05', '披露确认'], ['p30', '确认提交']);
  return st;
}
function obProgress(key) {
  const st = obSteps();
  const i = Math.max(0, st.findIndex((s) => s[0] === key));
  return `<div class="progress"><i style="width:${((i + 1) / st.length) * 100}%"></i></div><div class="xs muted mb16">第 ${i + 1} / ${st.length} 步 · ${st[i][1]}</div>`;
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
const COUNTRIES = [['US', '美国'], ['CN', '中国'], ['HK', '中国香港'], ['TW', '中国台湾'], ['SG', '新加坡'], ['GB', '英国'], ['CA', '加拿大'], ['AU', '澳大利亚'], ['JP', '日本']];
const LANGS = [['zh_CN', '简体中文'], ['zh_TW', '繁體中文'], ['en_US', 'English']];
const INCOME = [['<25k', '低于 $25,000'], ['25k-50k', '$25,000 – $50,000'], ['50k-100k', '$50,000 – $100,000'], ['100k-200k', '$100,000 – $200,000'], ['>200k', '高于 $200,000']];
const NETWORTH = [['<50k', '低于 $50,000'], ['50k-200k', '$50,000 – $200,000'], ['200k-500k', '$200,000 – $500,000'], ['500k-1m', '$500,000 – $1,000,000'], ['>1m', '高于 $1,000,000']];
const EMPLOY = [['EMPLOYED', '受雇'], ['SELF_EMPLOYED', '自雇'], ['UNEMPLOYED', '无业'], ['RETIRED', '退休'], ['STUDENT', '学生']];
const EXPERIENCE = [['NONE', '无'], ['1-2', '1–2 年'], ['3-5', '3–5 年'], ['5+', '5 年以上']];
const OBJECTIVE = [['GROWTH', '资本增值'], ['INCOME', '稳定收益'], ['PRESERVE', '资本保值'], ['SPEC', '投机']];
const RISK = [['LOW', '低'], ['MED', '中'], ['HIGH', '高']];
const ID_TYPES = [['PASSPORT', '护照'], ['NATIONAL_ID_CARD', '身份证'], ['DRIVER_LICENSE', '驾照'], ['RESIDENCE_PERMIT', '居留许可']];
// 资金来源（DW COMPLIANCE_AML_INFO.fundingSources）：代码为占位，枚举值待 DW 确认
const FUND_SOURCES = [['EMPLOYMENT', '工资收入'], ['SAVINGS', '储蓄'], ['INVESTMENTS', '投资收益'], ['BUSINESS', '经营收入'], ['INHERITANCE', '继承 / 赠与'], ['OTHER', '其他']];
function defaultContactEmail() { const u = Store.state.user; return u.emailIsRelay ? '' : u.email; }
const lab = (list, v) => (list.find((x) => x[0] === v) || [, v || '—'])[1];
const ynLab = (v) => (v === 'YES' ? '是' : v === 'NO' ? '否' : '—');
const maskTin = (t) => (t ? String(t).replace(/[A-Za-z0-9](?=[A-Za-z0-9-]{4})/g, '•') : '—');
function tinOptions(d) {
  return d.usTaxPayer === 'YES' ? [['SSN', '社会安全号码 SSN'], ['ITIN', '个人纳税识别号 ITIN']] : [['FOREIGN_TIN', '所在国税号 TIN'], ['NIN', '国民身份号码 NIN']];
}

const OB_VALIDATE = {
  b(d) {
    const e = {};
    if (!ASCII_NAME_RE.test(d.firstName || '')) e.firstName = '请使用英文字母填写，不支持 é、и、中文等非标准字符';
    if (!ASCII_NAME_RE.test(d.lastName || '')) e.lastName = '请使用英文字母填写，不支持 é、и、中文等非标准字符';
    const age = ageOf(d.dateOfBirth);
    if (age == null) e.dateOfBirth = '请选择出生日期';
    else if (age < 18) e.dateOfBirth = '开户人须年满 18 周岁';
    else if (age > 120) e.dateOfBirth = '请检查出生日期';
    if (!d.citizenship) e.citizenship = '请选择国籍';
    if (!d.taxResidency) e.taxResidency = '请选择税务居民国家/地区';
    if (!PHONE_RE.test((d.phone || '').trim())) e.phone = '请输入有效的手机号（含国家区号）';
    if (!d.language) e.language = '请选择语言';
    const ce = (d.contactEmail ?? defaultContactEmail()).trim();
    if (!/^\S+@\S+\.\S+$/.test(ce)) e.contactEmail = '请输入有效的联系邮箱';
    else if (ce.endsWith(RELAY_DOMAIN)) e.contactEmail = '请填写可以联系到您的真实邮箱（能否使用中转邮箱待 DW 确认）';
    return e;
  },
  c(d) {
    const e = {};
    if (!d.usTaxPayer) e.usTaxPayer = '请回答此问题';
    const t = (d.tin || '').trim();
    if (d.tinType === 'SSN' && !/^\d{3}-?\d{2}-?\d{4}$/.test(t)) e.tin = 'SSN 格式应为 123-45-6789';
    else if (d.tinType === 'ITIN' && !/^9\d{2}-?\d{2}-?\d{4}$/.test(t)) e.tin = 'ITIN 以 9 开头，格式为 9XX-XX-XXXX';
    else if (!t || t.length < 5) e.tin = '请输入完整税号';
    if (d.usTaxPayer === 'NO' && !d.taxTreaty) e.taxTreaty = '请回答此问题';
    if (!d.tinConfirm) e.tinConfirm = '请确认这是您本人报税使用的号码';
    return e;
  },
  d(d) {
    const e = {};
    if (!d.line1) e.line1 = '请输入街道地址';
    else if (PO_BOX_RE.test(`${d.line1} ${d.line2 || ''}`)) e.line1 = '居住地址不能是邮政信箱（P.O. Box），请填写实际居住地址';
    if (!d.city) e.city = '请输入城市';
    if (!d.postalCode) e.postalCode = '请输入邮编';
    if (d.country === 'US' && !d.state) e.state = '请输入州';
    if (d.hasMailing && !d.mailLine1) e.mailLine1 = '请输入邮寄地址';
    return e;
  },
  e(d) {
    const e = {};
    if (!d.employmentStatus) e.employmentStatus = '请选择就业状态';
    if ((d.employmentStatus === 'EMPLOYED' || d.employmentStatus === 'SELF_EMPLOYED') && !d.employerName) e.employerName = '在职时须填写雇主名称';
    if (!d.annualIncome) e.annualIncome = '请选择年收入';
    if (!d.netWorth) e.netWorth = '请选择净资产';
    if (!d.netWorthLiquid) e.netWorthLiquid = '请选择可投资（流动）净资产';
    if (!d.experience) e.experience = '请选择投资经验';
    if (!d.objective) e.objective = '请选择投资目标';
    if (!d.risk) e.risk = '请选择风险承受能力';
    if (!(d.fundingSources || []).length) e.fundingSources = '请至少选择一项资金来源';
    return e;
  },
  f(d) {
    const e = {};
    if (!d.isAffiliated) e.isAffiliated = '请回答此问题';
    if (d.isAffiliated === 'YES') { if (!d.affiliatedFirm) e.affiliatedFirm = '请填写机构名称'; if (!d.affiliatedAck) e.affiliatedAck = '请确认已了解报备要求'; }
    if (!d.isPEP) e.isPEP = '请回答此问题';
    if (d.isPEP === 'YES' && !d.pepName) e.pepName = '请填写政治公众人物姓名';
    if (!d.isControl) e.isControl = '请回答此问题';
    if (d.isControl === 'YES' && !d.controlCompany) e.controlCompany = '请填写公司名称或股票代码';
    return e;
  },
};
function obSubmittedGuard(title) {
  const s = Store.state;
  if (s.accountStatus !== 'SUBMITTED' && s.accountStatus !== 'APPROVED') return null;
  return { title, body: `<div class="state">${C.notice('info', '您的开户申请已提交，无需重复填写。')}<button class="btn primary" data-go="${Onb.status()?.go || '#/p06'}">查看申请状态</button></div>` };
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
    const g = obSubmittedGuard('开立账户'); if (g) return g;
    const app = Store.state.application;
    const step = p.step || (app.step && app.step.length === 1 ? app.step : 'a');
    ctx.form = app.data;
    const d = app.data;
    const e = ctx.errors || {};
    const yesno = (bind, q, extra = '') => `<div class="card"><div class="b small">${q}</div>${C.yn(bind, d[bind])}${e[bind] ? `<div class="err-msg">${e[bind]}</div>` : ''}${d[bind] === 'YES' && extra ? `<div class="mt12">${extra}</div>` : ''}</div>`;
    let body = '';
    let next = '下一步';
    switch (step) {
      case 'a':
        next = app.step && app.step !== 'a' ? '继续申请' : '开始申请';
        body = `
          <div class="hero"><div class="small muted">个人券商账户</div><div style="font-size:22px;font-weight:700;margin-top:4px">开立证券账户</div><div class="small muted mt8">账户由合作券商 DriveWealth 开立和托管。美国纳税人通常无需上传证件，其他用户需上传；核验时长待 DW 确认。</div></div>
          <div class="sec-title">您需要准备</div>
          <div class="list">
            ${C.li({ icon: 'shield', title: '税号（SSN / ITIN / 所在国税号）', sub: '用于身份核验及税务申报' })}
            ${C.li({ icon: 'id', title: '政府签发的带照片证件', sub: '非美国纳税人需上传护照或身份证' })}
            ${C.li({ icon: 'clock', title: '约 5 分钟', sub: '可随时退出，进度会自动保存' })}
          </div>
          ${C.notice('info', `您的资料将加密传输到${APP_NAME}，再由我们提交给 DriveWealth 进行身份核验。${C.tag('7')}`)}`;
        break;
      case 'b':
        body = `${obProgress('b')}
          ${C.two({ label: '法定名（First name）' + C.tag('1'), bind: 'firstName', value: d.firstName, placeholder: 'Alex', error: e.firstName, attrs: 'autocapitalize="words"' }, { label: '法定姓（Last name）', bind: 'lastName', value: d.lastName, placeholder: 'Chen', error: e.lastName })}
          <div class="hint" style="margin:-8px 0 12px">请与证件上的英文/拼音姓名一致，仅支持标准英文字母。</div>
          ${C.field({ label: '出生日期' + C.tag('4'), bind: 'dateOfBirth', value: d.dateOfBirth, type: 'date', error: e.dateOfBirth, hint: '开户人须年满 18 周岁' })}
          ${C.field({ label: '国籍', bind: 'citizenship', value: d.citizenship, options: COUNTRIES, error: e.citizenship })}
          ${C.field({ label: '税务居民国家/地区', bind: 'taxResidency', value: d.taxResidency, options: COUNTRIES, error: e.taxResidency })}
          ${C.field({ label: '手机号（含国家区号）', bind: 'phone', value: d.phone, type: 'tel', placeholder: '+1 415 555 0142', error: e.phone })}
          ${C.field({ label: '联系邮箱', bind: 'contactEmail', value: d.contactEmail ?? defaultContactEmail(), type: 'email', error: e.contactEmail, hint: Store.state.user.emailIsRelay ? '您使用 Apple"隐藏邮件地址"登录，请填写可以联系到您的邮箱，用于券商通知与文件（能否使用中转邮箱待 DW 确认）' : '默认取登录邮箱，可修改；用于券商通知与文件' })}
          ${C.field({ label: '文件与通知语言', bind: 'language', value: d.language, options: LANGS, error: e.language })}`;
        break;
      case 'c': {
        const opts = tinOptions(d);
        if (!opts.some((o) => o[0] === d.tinType)) d.tinType = opts[0][0];
        const us = d.usTaxPayer === 'YES';
        body = `${obProgress('c')}
          ${yesno('usTaxPayer', '您是否为美国纳税人？<div class="xs muted mt8" style="font-weight:400">包括美国公民、绿卡持有人及其他美国税务居民。</div>')}
          ${d.usTaxPayer ? `
          ${C.field({ label: '税号类型' + C.tag('3', 'PDF-1'), bind: 'tinType', value: d.tinType, options: opts })}
          ${C.field({ label: '税号', bind: 'tin', value: d.tin, placeholder: d.tinType === 'SSN' ? '123-45-6789' : '', error: e.tin, attrs: 'autocomplete="off"' })}
          ${us ? yesno('irsBackup', '您是否收到美国国税局（IRS）通知，需要对您的账户执行备用预扣税（backup withholding）？')
            : yesno('taxTreaty', '您的税务居民国家/地区是否与美国签有税收协定，且您希望申请适用协定税率？<div class="xs muted mt8" style="font-weight:400">将据此生成 W-8BEN 信息，具体形式以 DriveWealth 要求为准。</div>')}
          <label class="check"><input type="checkbox" data-bind="tinConfirm" ${d.tinConfirm ? 'checked' : ''}><span>我确认这是由政府签发、本人报税时使用的号码。</span></label>
          ${e.tinConfirm ? `<div class="err-msg">${e.tinConfirm}</div>` : ''}` : ''}`;
        break;
      }
      case 'd':
        body = `${obProgress('d')}
          ${C.notice('warn', '请填写您<b>实际居住</b>的地址，不接受邮政信箱（P.O. Box）。' + C.tag('2'))}
          ${C.field({ label: '国家/地区', bind: 'country', value: d.country, options: COUNTRIES })}
          ${C.field({ label: '街道地址', bind: 'line1', value: d.line1, placeholder: '200 Market Street', error: e.line1 })}
          ${C.field({ label: '公寓、楼层（选填）', bind: 'line2', value: d.line2, placeholder: 'Apt 5B' })}
          ${C.two({ label: '城市', bind: 'city', value: d.city, error: e.city }, { label: '州/省', bind: 'state', value: d.state, error: e.state })}
          ${C.field({ label: '邮编', bind: 'postalCode', value: d.postalCode, error: e.postalCode })}
          <label class="check"><input type="checkbox" data-bind="hasMailing" ${d.hasMailing ? 'checked' : ''}><span>邮寄地址与居住地址不同</span></label>
          ${d.hasMailing ? C.field({ label: '邮寄地址（可为 P.O. Box）', bind: 'mailLine1', value: d.mailLine1, error: e.mailLine1 }) : ''}`;
        break;
      case 'e': {
        const employed = d.employmentStatus === 'EMPLOYED' || d.employmentStatus === 'SELF_EMPLOYED';
        body = `${obProgress('e')}
          ${C.field({ label: '就业状态' + C.tag('PDF-1'), bind: 'employmentStatus', value: d.employmentStatus, options: EMPLOY, error: e.employmentStatus })}
          ${employed ? C.field({ label: d.employmentStatus === 'SELF_EMPLOYED' ? '经营的企业名称' : '雇主名称', bind: 'employerName', value: d.employerName, error: e.employerName }) + C.field({ label: '职位（选填）', bind: 'occupation', value: d.occupation }) : ''}
          ${C.field({ label: '年收入', bind: 'annualIncome', value: d.annualIncome, options: INCOME, error: e.annualIncome })}
          ${C.field({ label: '净资产', bind: 'netWorth', value: d.netWorth, options: NETWORTH, error: e.netWorth })}
          ${C.field({ label: '可投资（流动）净资产', bind: 'netWorthLiquid', value: d.netWorthLiquid, options: NETWORTH, error: e.netWorthLiquid, hint: '可快速变现的资产，如现金、存款、股票' })}
          <div class="field ${e.fundingSources ? 'err' : ''}" data-field="fundingSources"><label>资金来源（可多选）${C.tag('PDF-1')}</label>
            <div class="row" style="flex-wrap:wrap;gap:8px">${FUND_SOURCES.map(([v, l]) => `<button class="chip ${(d.fundingSources || []).includes(v) ? 'on' : ''}" data-act="toggleFund" data-val="${v}">${l}</button>`).join('')}</div>
            ${e.fundingSources ? `<div class="err-msg">${e.fundingSources}</div>` : '<div class="hint">用于反洗钱核查，选项待 DW 确认</div>'}</div>
          <div class="sec-title" style="font-size:15px">投资者画像</div>
          ${C.field({ label: '投资经验', bind: 'experience', value: d.experience, options: EXPERIENCE, error: e.experience })}
          ${C.field({ label: '投资目标', bind: 'objective', value: d.objective, options: OBJECTIVE, error: e.objective })}
          ${C.field({ label: '风险承受能力', bind: 'risk', value: d.risk, options: RISK, error: e.risk })}
          <div class="xs faint">以上为券商（DriveWealth）开户要求的必填信息。</div>`;
        break;
      }
      case 'f':
        body = `${obProgress('f')}
          <div class="small muted mb12">以下三项为监管要求的问题，请如实回答。${C.tag('5', 'PDF-2')}</div>
          ${yesno('isAffiliated', '1. 您本人或在此账户中有受益权益的人，是否受雇于注册经纪自营商、FINRA 或证券交易所？',
            C.field({ label: '机构名称', bind: 'affiliatedFirm', value: d.affiliatedFirm, error: e.affiliatedFirm }) +
            `<div class="notice info">根据 FINRA 规则，您可能需要书面告知雇主您开立了此账户，雇主也可能要求获取账户对账单副本。</div>
             <label class="check"><input type="checkbox" data-bind="affiliatedAck" ${d.affiliatedAck ? 'checked' : ''}><span>我已了解上述报备要求</span></label>${e.affiliatedAck ? `<div class="err-msg">${e.affiliatedAck}</div>` : ''}`)}
          ${yesno('isPEP', '2. 您是否为政治公众人物（PEP）？<div class="xs muted mt8" style="font-weight:400">政治公众人物指现在或曾经担任重要公共职位或职能的个人，例如国家元首、高级政府官员、高级司法或军事官员、国有企业高管、重要政党官员，以及其直系亲属和密切关系人。</div>',
            C.field({ label: 'PEP 姓名（必填）', bind: 'pepName', value: d.pepName, error: e.pepName }) +
            C.field({ label: '相关国家/地区', bind: 'pepCountry', value: d.pepCountry, options: COUNTRIES }) +
            C.field({ label: '职务及任职年份', bind: 'pepRole', value: d.pepRole, placeholder: '如：市议员，2015–2020' }))}
          ${yesno('isControl', '3. 您是否为某上市公司的董事、持股 10% 以上的股东或政策制定高管？',
            C.field({ label: '公司名称或股票代码', bind: 'controlCompany', value: d.controlCompany, error: e.controlCompany }))}`;
        break;
      case 'g':
        next = DWSim.isUS() ? '下一步：披露确认' : '下一步：上传证件';
        body = `${obProgress('g')}
          <div class="small muted mb12">您将开立的账户${C.tag('6')}</div>
          <div class="card" style="border:1.5px solid var(--primary-weak)">
            <div class="row between"><span class="b">现金账户 · 自主交易</span>${C.badge('首期唯一类型', 'ok')}</div>
            <div class="xs muted mt8">使用账户内已有资金交易，不提供融资；由您本人做出全部投资决定。</div>
            <div class="hr"></div>
            ${C.kv('accountType', '<span class="num">LIVE</span>')}${C.kv('tradingType', '<span class="num">CASH</span>')}${C.kv('accountManagementType', '<span class="num">SELF</span>')}
          </div>
          <div class="small muted mb8 mt16">暂未开放</div>
          <div class="opt" style="opacity:.5;pointer-events:none"><span class="radio"></span><div class="grow"><div class="b">保证金账户（MARGIN）</div><div class="xs muted">暂未开放 · 待 DW 确认</div></div></div>
          <div class="opt" style="opacity:.5;pointer-events:none"><span class="radio"></span><div class="grow"><div class="b">顾问管理（RIA_MANAGED）</div><div class="xs muted">暂未开放 · 待 DW 确认</div></div></div>
          ${C.notice('info', '账户类型不可选择。创建 SELF 账户时是否需要省略 riaID / riaProductID，待 DW 确认；所有组合以 DW 沙盒测试结果为准。')}`;
        break;
      default:
        return Pages.s01.render({ type: 'notfound' });
    }
    if (app.returnTo === 'p30' && step !== 'a') next = '保存并返回确认页';
    return {
      title: '开立账户',
      body,
      footer: `${step !== 'a' && app.returnTo !== 'p30' ? '<button class="btn ghost" style="width:auto;white-space:nowrap;flex:none" data-act="saveExit">稍后继续</button>' : ''}<button class="btn primary" data-act="next" data-step="${step}">${next}</button>`,
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
    if ((b === 'firstName' || b === 'lastName') && el.value && !ASCII_NAME_RE.test(el.value)) showFieldErr(b, '仅支持标准英文字母，不支持 é、и、中文等字符');
    else if (b === 'line1' && PO_BOX_RE.test(el.value)) showFieldErr(b, '居住地址不能是邮政信箱（P.O. Box）');
    else if (['firstName', 'lastName', 'line1'].includes(b)) showFieldErr(b, '');
    if (el.tagName === 'SELECT' || el.type === 'checkbox') Router.refresh();
  },
  actions: {
    next(el, ctx) {
      const step = el.dataset.step;
      const a = Store.state.application;
      const v = OB_VALIDATE[step];
      const e = v ? v(a.data) : {};
      ctx.errors = e;
      if (Object.keys(e).length) { Router.refresh(); UI.toast('请检查标红的字段'); return; }
      if (Store.state.accountStatus === 'NONE') Store.state.accountStatus = 'DRAFT';
      ctx.errors = {};
      obNextAfter(step);
    },
    saveExit() { Store.save(); UI.toast('进度已保存，可随时回来继续'); Router.go('#/p07'); },
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
  return `<label class="upload ${value ? 'done' : ''}"><input type="file" accept="image/*,application/pdf" capture="environment" data-bind="${bind}">${Icon(value ? 'check' : 'camera', 24, '')}<div class="small mt8">${value ? `已上传：${esc(value)} · 点击重拍` : `拍照或上传 · ${label}`}</div></label>`;
}
const needsBack = (t) => t && t !== 'PASSPORT';
function docUploader(k) {
  const t = k.docType || 'PASSPORT';
  return `${C.field({ label: '证件类型', bind: 'docType', value: t, options: ID_TYPES })}
    ${uploadBox('front', t === 'PASSPORT' ? '护照资料页（FRONT）' : '证件正面（FRONT）', k.front)}
    ${needsBack(t) ? uploadBox('back', '证件背面（BACK）', k.back) : ''}
    <div class="center"><button class="link-btn xs" data-act="sampleDoc" style="color:var(--faint)">（原型）使用示例图片</button></div>`;
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
const DOC_TIPS = `<div class="card"><div class="b small mb8">拍摄要求</div>
  <div class="tips">${['证件四角完整，没有被遮挡或裁切', '光线均匀，没有反光或阴影', '证件在有效期内', '姓名与开户资料一致'].map((t) => `<div class="row small" style="gap:8px;padding:4px 0">${Icon('check', 16, 'up')}<span>${t}</span></div>`).join('')}</div>
  <svg viewBox="0 0 200 92" width="100%" height="92" style="margin-top:8px"><rect x="40" y="6" width="120" height="80" rx="8" fill="none" stroke="var(--line)" stroke-width="2"/><rect x="52" y="20" width="32" height="40" rx="4" fill="none" stroke="var(--faint)" stroke-width="1.5"/><path d="M96 26h50M96 38h40M96 50h46M52 72h94" stroke="var(--faint)" stroke-width="1.5"/><path d="M34 16V0h16M166 0h16v16M182 76v16h-16M50 92H34V76" fill="none" stroke="var(--primary)" stroke-width="2.5"/></svg></div>`;

/* ---------- P-04 证件上传（开户流程中，仅非美国纳税人） ---------- */
Pages.p04 = {
  auth: true,
  backTo: '#/p03?step=g',
  render(p, ctx) {
    const g = obSubmittedGuard('证件上传'); if (g) return g;
    const app = Store.state.application;
    if (DWSim.isUS()) {
      return { title: '身份验证', body: `${C.notice('ok', '美国纳税人提交后，由 DriveWealth 使用税号自动核验身份，<b>无需上传证件</b>。如核验需要补充证件，我们会通知您。' + C.tag('3'))}`, footer: '<button class="btn primary" data-go="#/p05">下一步：披露确认</button>' };
    }
    const k = app.kyc;
    ctx.form = k;
    return {
      title: '证件上传',
      body: `${obProgress('p04')}
        ${C.notice('info', '请上传一份政府签发、带照片的有效证件。证件将加密传输，随开户资料一并提交给 DriveWealth 用于身份核验。' + C.tag('3', 'PDF-1'))}
        ${docUploader(k)}${DOC_TIPS}
        <div class="xs faint">是否需要自拍或活体检测，待 DriveWealth 确认。</div>`,
      footer: `<button class="btn primary" data-act="next" ${docReady(k) ? '' : 'disabled'}>${app.returnTo === 'p30' ? '保存并返回确认页' : '下一步：披露确认'}</button>`,
    };
  },
  onInput(el) { docOnInput(Store.state.application.kyc, el); },
  actions: {
    sampleDoc() { docSample(Store.state.application.kyc); },
    next() {
      const a = Store.state.application;
      if (!docReady(a.kyc)) return UI.toast('请先上传证件照片');
      a.kyc.uploadedAt = nowStr();
      a.step = a.returnTo === 'p30' ? 'p30' : 'p05'; Store.save(); Router.go('#/' + a.step);
    },
  },
};

/* ---------- P-05 披露确认（按 DW DISCLOSURES 字段） ---------- */
const DW_DOCS = [
  ['termsOfUse', '服务条款（Terms of Use）'],
  ['customerAgreement', '客户账户协议（Customer Agreement）'],
  ['marketDataAgreement', '行情数据协议（Market Data Agreement）'],
  ['privacyPolicy', '隐私政策（Privacy Policy）'],
  ['dataSharing', '数据共享同意（Data Sharing）'],
];
const PARTNER_DOCS = [
  ['p_terms', '平台用户服务协议'],
  ['p_privacy', '平台隐私政策'],
  ['p_risk', '平台投资风险提示'],
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
    const g = obSubmittedGuard('披露确认'); if (g) return g;
    const app = Store.state.application;
    const ds = app.disclosures;
    ctx.form = ds;
    const d = app.data;
    const fullName = `${d.firstName || ''} ${d.lastName || ''}`.trim();
    const sigBad = ds.signature && ds.signature.trim().toLowerCase() !== fullName.toLowerCase();
    const docRow = ([id, title]) => `<div class="row" style="padding:10px 0;border-top:1px solid var(--line)">
        <label class="check grow" style="padding:0"><input type="checkbox" data-bind="${id}" ${ds[id] ? 'checked' : ''}><span>我已阅读并同意 <b>${title}</b></span></label>
        <button class="link-btn xs" data-act="openDoc" data-id="${id}" data-title="${esc(title)}">查看</button></div>`;
    return {
      title: '披露确认',
      body: `${obProgress('p05')}
        <div class="card" style="border:1.5px solid var(--accent)">
          <div class="row between"><div class="b">DriveWealth 披露${C.tag('8', 'PDF-4')}</div>${C.badge('券商披露', 'info')}</div>
          <div class="xs muted mt8">您的证券账户由 DriveWealth, LLC 开立和托管。以下为 DriveWealth 的披露文件，开户前请仔细阅读。完整文件：<a href="${DW_DISCLOSURE_URL}" target="_blank" rel="noopener">${DW_DISCLOSURE_URL}</a></div>
          <div class="mt8">${DW_DOCS.map(docRow).join('')}</div>
          <div style="padding:10px 0;border-top:1px solid var(--line)">
            <div class="small"><b>Rule 14b-1(c) 股东信息披露</b>：当证券发行人要求时，是否同意券商向其提供您的姓名、地址和持仓，用于股东通讯？</div>
            ${C.yn('rule14b', ds.rule14b)}<div class="xs faint">选择"否"不影响开户。</div>
          </div>
          <label class="check" style="border-top:1px solid var(--line);padding-top:10px"><input type="checkbox" data-bind="extendedHoursAgreement" ${ds.extendedHoursAgreement ? 'checked' : ''}><span>（选填）我同意 <b>盘前盘后交易协议（Extended Hours Agreement）</b></span></label>
          <div class="xs faint">文件名称与字段以 DriveWealth 官方提供为准。</div>
        </div>
        <div class="card">
          <div class="row between"><div class="b">${APP_NAME} 平台条款</div>${C.badge('平台披露')}</div>
          <div class="mt8">${PARTNER_DOCS.map(docRow).join('')}</div>
        </div>
        <div class="card">
          <div class="b mb8">电子签署同意</div>
          <label class="check"><input type="checkbox" data-bind="esign" ${ds.esign ? 'checked' : ''}><span class="small">我同意依据 2000 年《全球及全国商务电子签名法》（E-Sign Act）以电子方式接收文件、签署协议，并确认电子签名与手写签名具有同等效力。我可随时撤回此同意或申请纸质文件。</span></label>
          ${C.field({ label: `请输入您的法定姓名以签署（${esc(fullName || '—')}）`, bind: 'signature', value: ds.signature, placeholder: fullName, error: sigBad ? '签名须与法定姓名一致' : '' })}
        </div>`,
      footer: `<button class="btn primary" data-act="next" ${discReady(ds) ? '' : 'disabled'}>${app.returnTo === 'p30' ? '保存并返回确认页' : '下一步：确认资料'}</button>`,
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
      UI.sheet(esc(el.dataset.title), `<div class="doc-paper">${isDW ? `[DriveWealth 披露文件]\n\n此处展示 DriveWealth 官方文件全文。\n原型中以占位文字代替。\n\n官方地址：\n${DW_DISCLOSURE_URL}` : `[${APP_NAME} 平台文件]\n\n此处展示平台自有条款全文。\n原型中以占位文字代替。`}</div>
        ${isDW ? `<a class="btn ghost mt12" href="${DW_DISCLOSURE_URL}" target="_blank" rel="noopener">在浏览器中打开官方页面</a>` : ''}`);
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
    const g = obSubmittedGuard('确认开户资料'); if (g) return g;
    const s = Store.state;
    const app = s.application;
    const d = app.data, ds = app.disclosures, k = app.kyc;
    if (ctx.submitting) {
      return { title: '确认开户资料', noBack: true, body: `<div class="state"><div class="spinner"></div><h2 class="mt16">正在提交</h2><p>正在把您的资料安全提交给合作券商，请勿关闭页面。</p></div>` };
    }
    const bad = {};
    ['b', 'c', 'd', 'e', 'f'].forEach((st) => { if (Object.keys(OB_VALIDATE[st](d)).length) bad[st] = true; });
    if (!DWSim.isUS() && !docReady(k)) bad.p04 = true;
    if (!discReady(ds)) bad.p05 = true;
    const group = (title, step, rows, tags = '') => `<div class="card" ${bad[step] ? 'style="border:1.5px solid var(--danger)"' : ''}>
      <div class="row between"><span class="b">${title}${tags}</span><span class="row" style="gap:6px">${bad[step] ? C.badge('需补全', 'danger') : ''}<button class="link-btn xs" data-act="edit" data-step="${step}">修改</button></span></div>
      <div class="mt8">${rows.map(([k2, v]) => C.kv(k2, esc(v ?? '—'))).join('')}</div></div>`;
    const us = d.usTaxPayer === 'YES';
    const employed = d.employmentStatus === 'EMPLOYED' || d.employmentStatus === 'SELF_EMPLOYED';
    const signed = [...DW_DOCS, ...PARTNER_DOCS].filter(([id]) => ds[id]).length;
    const body = `${obProgress('p30')}
      <div class="small muted mb12">提交前请最后核对。提交后将由${APP_NAME}把资料提交给 DriveWealth 进行身份核验。</div>
      ${group('基本身份', 'b', [['姓名', `${d.firstName || ''} ${d.lastName || ''}`], ['出生日期', d.dateOfBirth], ['国籍', lab(COUNTRIES, d.citizenship)], ['税务居民', lab(COUNTRIES, d.taxResidency)], ['手机号', d.phone], ['联系邮箱', d.contactEmail ?? defaultContactEmail()], ['登录方式', { EMAIL: '邮箱验证码', GOOGLE: 'Google', APPLE: 'Apple' }[s.user.loginProvider] || '—'], ['语言', lab(LANGS, d.language)]], C.tag('1', '4'))}
      ${group('税务', 'c', [['美国纳税人', ynLab(d.usTaxPayer)], ['税号类型', lab(tinOptions(d), d.tinType)], ['税号', maskTin(d.tin)], us ? ['IRS 备用预扣', ynLab(d.irsBackup)] : ['适用税收协定', ynLab(d.taxTreaty)]], C.tag('3'))}
      ${group('居住地址', 'd', [['地址', [d.line1, d.line2].filter(Boolean).join(', ')], ['城市 / 州', [d.city, d.state].filter(Boolean).join(', ')], ['邮编', d.postalCode], ['国家/地区', lab(COUNTRIES, d.country)]], C.tag('2'))}
      ${group('就业与财务', 'e', [['就业状态', lab(EMPLOY, d.employmentStatus)], ...(employed ? [['雇主', d.employerName]] : []), ['年收入', lab(INCOME, d.annualIncome)], ['净资产', lab(NETWORTH, d.netWorth)], ['流动净资产', lab(NETWORTH, d.netWorthLiquid)], ['投资经验', lab(EXPERIENCE, d.experience)], ['投资目标', lab(OBJECTIVE, d.objective)], ['风险承受', lab(RISK, d.risk)], ['资金来源', (d.fundingSources || []).map((v) => lab(FUND_SOURCES, v)).join('、') || '—']], C.tag('PDF-1'))}
      ${group('监管问题', 'f', [['受雇于券商 / FINRA / 交易所', ynLab(d.isAffiliated)], ['政治公众人物', ynLab(d.isPEP)], ['上市公司控制人', ynLab(d.isControl)]], C.tag('5', 'PDF-2'))}
      ${group('账户类型', 'g', [['类型', '现金账户 · 自主交易'], ['accountType', 'LIVE'], ['tradingType', 'CASH'], ['accountManagementType', 'SELF'], ['riaID / riaProductID', '是否省略待 DW 确认']], C.tag('6'))}
      ${DWSim.isUS() ? '' : group('身份证件', 'p04', [['证件类型', lab(ID_TYPES, k.docType || 'PASSPORT')], ['正面', k.front], ...(needsBack(k.docType || 'PASSPORT') ? [['背面', k.back]] : [])])}
      ${group('已签署披露', 'p05', [['已同意文件', `${signed} / ${DW_DOCS.length + PARTNER_DOCS.length}`], ['Rule 14b-1(c)', ds.rule14b === 'YES' ? '同意提供' : ds.rule14b === 'NO' ? '不同意提供' : '—'], ['盘前盘后协议', ds.extendedHoursAgreement ? '已同意' : '未选择'], ['电子签名', ds.signature]], C.tag('8'))}
      ${Object.keys(bad).length ? C.notice('danger', '标红的分组信息不完整，请修改后再提交。') : ''}`;
    return {
      title: '确认开户资料',
      body,
      footer: `<button class="btn primary" data-act="submit" ${Object.keys(bad).length ? 'disabled' : ''}>提交开户申请</button>`,
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
Pages.p06 = {
  auth: true,
  backTo: '#/p07',
  render() {
    const s = Store.state;
    const app = s.application;
    if (s.accountStatus === 'NONE' || s.accountStatus === 'DRAFT') {
      return { title: '开户进度', body: `<div class="state"><div class="state-ic">${Icon('doc', 36)}</div><h2>尚未提交申请</h2><p>完成开户信息填写后即可提交。</p><button class="btn primary mt24" data-go="${Onb.resumeHref()}">继续开户</button></div>` };
    }
    const k = s.dw.kyc;
    const acct = s.dw.account;
    const live = s.accounts.LIVE;
    const opened = s.accountStatus === 'APPROVED';
    const funded = Fund.linked().length > 0 || live.cash > 0 || (live.transactions || []).some((t) => t.type === 'DEPOSIT');
    const kycSt = k === 'KYC_APPROVED' ? 'done' : k === 'KYC_DENIED' ? 'fail' : ['KYC_INFO_REQUIRED', 'KYC_DOC_REQUIRED'].includes(k) ? 'action' : 'active';
    const steps = [
      ['资料提交', `参考号 ${app.ref || '—'} · ${fmt.dt(app.submittedAt)}`, 'done'],
      ['身份核验（由 DriveWealth 执行）', `${KYC_LABEL[k][0]}${s.dw.kycUpdatedAt ? ' · ' + s.dw.kycUpdatedAt : ''}`, kycSt],
      ['开立交易账户', acct ? ACCT_LABEL[acct][0] : '核验通过后自动开立', opened ? 'done' : acct === 'PENDING' ? 'active' : 'todo'],
      ['入金', funded ? '已绑定银行账户或已入金' : opened ? '绑定银行账户或通过电汇入金' : '账户开通后即可入金', funded ? 'done' : opened ? 'active' : 'todo'],
    ];
    const ob = Onb.status();
    let card = '';
    let footer = '<button class="btn primary" data-go="#/p07">返回首页</button>';
    const simLinks = `<div class="center mt8 xs faint">（原型）模拟 DW 返回：${[['KYC_APPROVED', '通过'], ['KYC_INFO_REQUIRED', '需补资料'], ['KYC_DOC_REQUIRED', '需补证件'], ['KYC_MANUAL_REVIEW', '人工复核'], ['KYC_DENIED', '拒绝']].map(([v, l]) => `<button class="link-btn xs" data-act="kyc" data-val="${v}">${l}</button>`).join(' · ')}</div>`;
    if (opened) {
      const r = Acc.restriction() || (live.dwStatus !== 'OPEN' ? { title: ACCT_LABEL[live.dwStatus][0], body: '' } : null);
      card = `<div class="card">
          <div class="row between"><span class="b">实盘账户已开通</span>${C.badge(ACCT_LABEL[live.dwStatus || 'OPEN'][0], ACCT_LABEL[live.dwStatus || 'OPEN'][1])}</div>
          <div class="row mt8 small"><span class="muted">账户号码${C.tag('PDF-6')}</span><span class="grow b num right">${esc(live.accountNumber)}</span><button class="nav-btn" style="width:28px;height:28px" data-act="copy" data-val="${esc(live.accountNumber)}">${Icon('copy', 16)}</button></div>
          ${C.kv('账户类型' + C.tag('6'), '现金账户 · 自主交易')}
          <div class="xs faint">创建参数 LIVE · CASH · SELF；riaID / riaProductID 是否省略待 DW 确认</div>
        </div>${r ? C.restrict() : ''}`;
      if (!funded) {
        card += `<div class="sec-title" style="font-size:15px">入金方式</div>
          <button class="opt ${Fund.preferWire() ? '' : 'on'}" data-go="${Fund.bindHref('p06')}"><span class="radio"></span>${Icon('bank', 22)}<div class="grow"><div class="b">绑定银行账户（ACH）</div><div class="xs muted">需本人名下的美国银行账户，免手续费</div></div>${Icon('right', 16, 'chev')}</button>
          <button class="opt ${Fund.preferWire() ? 'on' : ''}" data-go="#/p33"><span class="radio"></span>${Icon('globe', 22)}<div class="grow"><div class="b">电汇入金</div><div class="xs muted">${Fund.preferWire() ? '推荐：适用于没有美国银行账户的用户' : '适用于大额或境外银行汇款'}</div></div>${Icon('right', 16, 'chev')}</button>`;
        footer = '<button class="btn ghost" data-go="#/p07">稍后再说</button>';
      } else footer = '<button class="btn ghost" data-go="#/p07">返回首页</button><button class="btn primary" data-go="#/p13">去入金</button>';
    } else if (k === 'KYC_APPROVED') {
      card = `<div class="card center"><div class="spinner"></div><div class="b mt12">身份核验已通过，正在开立交易账户</div><div class="xs muted">预计时长待 DW 确认</div></div>`;
    } else if (k === 'KYC_INFO_REQUIRED' || k === 'KYC_DOC_REQUIRED') {
      card = `<button class="card row" style="width:100%;text-align:left;border:1.5px solid var(--warn)" data-go="${ob.go}"><span class="li-ic" style="color:var(--warn)">${Icon(ob.icon, 18)}</span><span class="grow"><div class="b">${ob.title}</div><div class="xs muted">${ob.sub}</div></span>${Icon('right', 16, 'chev')}</button>`;
      footer = `<button class="btn primary" data-go="${ob.go}">${ob.cta}</button>`;
    } else if (k === 'KYC_DENIED') {
      card = `<button class="card row" style="width:100%;text-align:left" data-go="#/p36"><span class="li-ic">${Icon('info', 18)}</span><span class="grow"><div class="b">开户未通过</div><div class="xs muted">查看结果与后续可选操作</div></span>${Icon('right', 16, 'chev')}</button>`;
      footer = '<button class="btn primary" data-go="#/p36">查看结果</button>';
    } else if (k === 'KYC_MANUAL_REVIEW') {
      card = `${C.notice('info', '<b>人工复核中</b><br>合作券商正在人工审核您的资料（预计时长待 DW 确认）。结果出来后我们会通知您，无需重复提交。')}<button class="btn ghost" data-act="cs">联系客服</button>${simLinks}`;
    } else {
      card = `<div class="card center"><div class="spinner"></div><div class="b mt12">正在核验您的身份</div><div class="xs muted">预计时长待 DW 确认，本页会自动更新。</div></div>${simLinks}<div class="xs faint center">沙盒中首次提交可能直接返回通过，取决于 KYC 模式（待 DW 确认）。</div>`;
    }
    return {
      title: '开户进度', noBack: true,
      body: `${stepper(steps)}${card}
        <div class="xs faint mt12">身份核验由合作券商 DriveWealth 执行。${C.tag('7')}</div>`,
      footer,
    };
  },
  actions: { cs() { UI.toast(`（原型）已转接客服，参考号 ${Store.state.application.ref}`); } },
};

/* ---------- P-34 补充开户资料（KYC_INFO_REQUIRED） ---------- */
const FIELD_LABEL = { firstName: '法定名', lastName: '法定姓', dateOfBirth: '出生日期', line1: '街道地址', line2: '公寓、楼层', city: '城市', state: '州/省', postalCode: '邮编', tin: '税号' };
const ISSUE_FIELDS = { line1: ['line1', 'line2', 'city', 'state', 'postalCode'], dateOfBirth: ['dateOfBirth'], firstName: ['firstName', 'lastName'], lastName: ['firstName', 'lastName'], tin: ['tin'] };
const MAX_ATTEMPTS = 3; // 示例：最多修改次数待确认（pages.md 问题 13）
function kycStateGuard(kyc, title) {
  if (Store.state.dw.kyc === kyc) return null;
  return { title, body: `<div class="state"><div class="state-ic">${Icon('check', 34)}</div><h2>当前无需处理</h2><p>您的开户申请没有需要补充的内容。</p><button class="btn primary mt24" data-go="#/p06">查看开户进度</button></div>` };
}
function showVal(f, v) { return f === 'tin' ? maskTin(v) : v || '—'; }
Pages.p34 = {
  auth: true,
  backTo: '#/p06',
  render(p, ctx) {
    const g = kycStateGuard('KYC_INFO_REQUIRED', '补充开户资料'); if (g) return g;
    const s = Store.state;
    const d = s.application.data;
    const issues = s.dw.issues;
    if (!ctx.form) { ctx.form = {}; issues.forEach((i) => ISSUE_FIELDS[i.field].forEach((f) => { ctx.form[f] = d[f] || ''; })); }
    const f = ctx.form;
    const e = ctx.errors || {};
    const attempt = (s.dw.attempt || 0) + 1;
    const flagged = new Set(issues.flatMap((i) => ISSUE_FIELDS[i.field]));
    const others = [['姓名', `${d.firstName} ${d.lastName}`, 'firstName'], ['出生日期', d.dateOfBirth, 'dateOfBirth'], ['税号', maskTin(d.tin), 'tin'], ['地址', [d.line1, d.line2, d.city, d.state, d.postalCode].filter(Boolean).join(', '), 'line1'], ['手机号', d.phone], ['就业状态', lab(EMPLOY, d.employmentStatus)], ['年收入', lab(INCOME, d.annualIncome)]].filter((r) => !flagged.has(r[2]));
    const editor = (fld, pair = false) => C.field({ label: FIELD_LABEL[fld] + (fld === 'line2' ? '（选填）' : ''), bind: fld, value: f[fld], type: fld === 'dateOfBirth' ? 'date' : 'text', error: e[fld], pair });
    return {
      title: '补充开户资料',
      body: `<div class="state" style="min-height:auto;padding:12px 0 4px"><div class="state-ic" style="background:var(--warn-weak);color:var(--warn)">${Icon('edit', 32)}</div>
          <h2>还差一步：请核对以下资料</h2><p>合作券商未能核实您的部分信息。请修改标出的内容，提交后会重新核验。</p></div>
        ${issues.map((i, n) => `<div class="card" style="border:1.5px solid var(--warn-weak)">
          <div class="row between"><span class="b">${n + 1}. ${FIELD_LABEL[i.field]}</span>${C.badge('需核对', 'warn')}</div>
          <div class="xs muted mt8">当前填写：${esc(ISSUE_FIELDS[i.field].map((x) => showVal(x, d[x])).filter((x) => x !== '—').join(', '))}</div>
          <div class="notice warn mt8" style="margin-bottom:12px">${Icon('info', 16)}<div class="small">${esc(i.reason)}</div></div>
          ${i.field === 'line1' ? `${editor('line1')}${editor('line2')}<div class="two">${editor('city', true)}${editor('state', true)}</div>${editor('postalCode')}` : ISSUE_FIELDS[i.field].map(editor).join(i.field === 'firstName' ? '' : '')}
          <label class="check"><input type="checkbox" data-bind="keep_${i.field}" ${f['keep_' + i.field] ? 'checked' : ''}><span class="small">我已核对，信息无误，保持不变</span></label>
        </div>`).join('')}
        <details class="faq"><summary>查看其余资料（无需修改）${Icon('right', 16, 'chev')}</summary><div style="padding:0 0 8px">${others.map(([k2, v]) => C.kv(k2, esc(v || '—'))).join('')}</div></details>
        <div class="xs muted mt12">第 ${attempt} 次提交 · 最多 ${MAX_ATTEMPTS} 次（示例，待确认）${C.tag('1', '2', '3', '4', '24')}</div>`,
      footer: `<button class="btn ghost" style="width:auto" data-act="cs">联系客服</button><button class="btn primary" data-act="submit">重新提交核验</button>`,
    };
  },
  onInput(el) {
    const b = el.dataset.bind;
    if ((b === 'firstName' || b === 'lastName') && el.value && !ASCII_NAME_RE.test(el.value)) showFieldErr(b, '仅支持标准英文字母');
    else if (b === 'line1' && PO_BOX_RE.test(el.value)) showFieldErr(b, '居住地址不能是邮政信箱（P.O. Box）');
    else if (['firstName', 'lastName', 'line1'].includes(b)) showFieldErr(b, '');
    if (el.type === 'checkbox') Router.refresh();
  },
  actions: {
    cs() { UI.toast(`（原型）已转接客服，参考号 ${Store.state.application.ref}`); },
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
        if (!changed.length && !f['keep_' + i.field]) e[fields[0]] = e[fields[0]] || '请修改此项，或勾选"信息无误，保持不变"';
        changed.forEach((x) => changes.push([FIELD_LABEL[x], showVal(x, d[x]), showVal(x, merged[x])]));
      });
      ctx.errors = e;
      if (Object.keys(e).length) { Router.refresh(); return UI.toast('请检查标出的内容'); }
      const rows = changes.length ? changes.map(([k2, a, b]) => `<div class="kv"><span>${esc(k2)}</span><span><s class="faint">${esc(a)}</s> → <b>${esc(b)}</b></span></div>`).join('') : '<div>未修改任何内容，将按原资料重新提交核验。</div>';
      UI.confirm({
        title: '确认重新提交？', body: `${rows}<div class="mt8">提交后将重新核验身份。</div>`, ok: '确认提交',
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
    const g = kycStateGuard('KYC_DOC_REQUIRED', '补充身份证件'); if (g) return g;
    const s = Store.state;
    const k = s.dw.docUpload || (s.dw.docUpload = { docType: 'PASSPORT' });
    ctx.form = k;
    return {
      title: '补充身份证件',
      body: `<div class="state" style="min-height:auto;padding:12px 0 4px"><div class="state-ic" style="background:var(--warn-weak);color:var(--warn)">${Icon('id', 32)}</div>
          <h2>请上传身份证件完成核验</h2><p>${esc(s.dw.docReason || KYC_DOC_REASON)}</p></div>
        <div class="card"><div class="b small mb8">可接受的证件（任选一种）${C.tag('3')}</div>
          <div class="row" style="gap:6px;flex-wrap:wrap">${ID_TYPES.map(([, l]) => C.badge(l)).join('')}</div>
          <div class="xs muted mt8">须为政府签发、带照片、在有效期内的证件。是否需要地址证明以合作券商要求为准。</div></div>
        ${docUploader(k)}${DOC_TIPS}
        ${C.notice('info', `证件将加密传输到${APP_NAME}，再提交给 DriveWealth，仅用于身份核验。`, 'lock')}`,
      footer: `<button class="btn ghost" style="width:auto" data-act="cs">联系客服</button><button class="btn primary" data-act="submit" ${docReady(k) ? '' : 'disabled'}>提交证件</button>`,
    };
  },
  onInput(el) { docOnInput(Store.state.dw.docUpload, el); },
  actions: {
    sampleDoc() { docSample(Store.state.dw.docUpload); },
    cs() { UI.toast(`（原型）已转接客服，参考号 ${Store.state.application.ref}`); },
    submit() {
      const s = Store.state;
      if (!docReady(s.dw.docUpload)) return UI.toast('请先上传证件照片');
      s.dw.docUpload.uploadedAt = nowStr();
      DWSim.resubmit(); UI.toast('证件已提交，正在重新核验'); Router.go('#/p06');
    },
  },
};

/* ---------- P-36 开户未通过（KYC_DENIED） ---------- */
Pages.p36 = {
  auth: true,
  backTo: '#/p07',
  render() {
    const g = kycStateGuard('KYC_DENIED', '开户结果'); if (g) return g;
    const s = Store.state;
    const app = s.application;
    return {
      title: '开户结果',
      body: `<div class="state" style="min-height:auto;padding:20px 0 8px"><div class="state-ic" style="background:var(--surface-2);color:var(--muted)">${Icon('info', 34)}</div>
          <h2>暂时无法为您开立证券账户</h2><p>该结果由合作券商 DriveWealth 根据身份核验与合规要求作出。出于合规原因，我们无法提供具体原因。${C.tag('7')}</p></div>
        <div class="card">
          <div class="row between"><span class="b">申请参考号</span><button class="link-btn xs" data-act="copy" data-val="${esc(app.ref)}">复制</button></div>
          <div class="num mt8" style="font-size:17px;letter-spacing:.5px">${esc(app.ref)}</div>
          <div class="hr"></div>${C.kv('结果时间', s.dw.kycUpdatedAt || '—')}
        </div>
        <div class="sec-title" style="font-size:15px">您还可以</div>
        <div class="list">
          ${C.li({ icon: 'help', title: '联系客服', sub: '咨询时会自动附上申请参考号', act: 'cs' })}
          ${C.li({ icon: 'market', title: '继续查看行情', sub: '市场行情、自选股照常可用', go: '#/p09' })}
          ${C.li({ icon: 'bars', title: '使用模拟账户', sub: '用虚拟资金体验交易', act: 'paper' })}
          ${C.li({ icon: 'trash', title: '申请删除已提交的资料', sub: '删除流程待法务确认', act: 'del' })}
        </div>
        <div class="xs faint mt12">（原型）能否再次申请、需等待多久，待确认（pages.md 问题 12）。</div>`,
      footer: '<button class="btn primary" data-go="#/p07">返回首页</button>',
    };
  },
  actions: {
    cs() { UI.toast(`（原型）已转接客服，参考号 ${Store.state.application.ref}`); },
    paper() { Store.state.mode = 'PAPER'; Store.save(); UI.toast('已切换到模拟账户'); Router.go('#/p07'); },
    del() { UI.confirm({ title: '申请删除已提交的资料？', body: '提交后客服会联系您确认。按监管要求需要保留的记录，将在保存期满后删除。（流程待法务确认）', ok: '提交申请', onOk: () => UI.toast('（原型）删除申请已提交') }); },
  },
};
