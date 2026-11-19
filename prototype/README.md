# 可点击原型

依据 `design/pages.md`（第 5 版 · 沙盒前定稿）制作的移动端可点击原型，覆盖 P-01 – P-36 与 S-01：DW 开户 KYC、补资料 / 补证件 / 未通过页面、ACH 与电汇资金流程。纯 HTML/CSS/JS，无需构建，也没有外部依赖。定稿状态与待 DW 确认事项（Q-DW-1 至 Q-DW-8）见 `design/pages.md` 第 5.1、6 节；其中 Q-DW-1（KYC 模式）与 Q-DW-2（绑卡方式）是沙盒接入的前置条件。

## 运行

任选一种：

- 在桌面 App 中用 `.claude/launch.json` 里的 `prototype` 配置启动预览。
- 或在本目录下启动任意静态服务器，例如在终端执行 `python3 -m http.server 8765`，然后打开 http://localhost:8765 。（桌面 App 的预览使用 8767 端口，两者可同时运行。）
- **避免看到旧页面**：`python3 -m http.server` 不发送禁止缓存的响应头，浏览器可能继续使用旧的 `index.html`。修改后请按 Cmd+Shift+R 强制刷新，或改用下面这条不缓存的启动命令（在 `prototype` 目录下执行）：
  `python3 -c "import http.server as h;C=type('C',(h.SimpleHTTPRequestHandler,),{'end_headers':lambda s:(s.send_header('Cache-Control','no-store'),h.SimpleHTTPRequestHandler.end_headers(s))});h.ThreadingHTTPServer(('',8765),C).serve_forever()"`

直接双击 `index.html`（file://）在部分浏览器中也能用，但推荐走本地服务器。

## 使用

- 右侧"原型控制"面板（窄屏时为右下角按钮）可以：
  - 切换场景：未登录 / 已登录未开户 / 开户审核中 / 已开户 · 美国未绑卡 / 已开户 · 非美国未入金 / 已开户 · ACH 观察期中（可提现 $0，演示 30 天观察期） / 已开户（有持仓）
  - 开户审核中：模拟 DW 返回的 KYC 结果（通过、需补资料 → P-34、需补证件 → P-35、人工复核、拒绝 → P-36）
  - 已开户：模拟 DW 账户状态（正常、仅可卖出、冻结）
  - 入金 / 出金记录详情（P-18）中可模拟到账、退回或失败
  - 显示或隐藏紫色的 `DW-x` 合规编号标注（对应 `design/compliance-map.md`）
  - 直接跳转到任一页面
- 登录演示验证码为 `123456`。
- P-02 可模拟 Google / Apple 登录；Apple 选"隐藏我的邮件地址"时会得到中转邮箱，P-03b 需另填联系邮箱。
- 第 4 版：账户类型固定为 LIVE / CASH / SELF（只读）；P-03e 新增资金来源；P-25、P-26 标注"首期不做，待合规评估"。
- 第 5 版：P-32 绑卡页标注"绑定方式待定（Q-DW-2）"；P-30 提交说明改为 POST 四类 + PATCH 补充（见 `js/core.js` DWSim.submitUser 注释）；KYC 模式按 Do KYC 假设（Q-DW-1）。
- 原型中的账户号码、用户 ID 等一律为占位示例，不包含任何真实凭据或账户编号。
- 资金时效（均待 DW 确认，出处见 `design/pages.md` 3.1.5）：ACH 购买力在结算后授予，通常 4–5 个工作日（待 DW 确认）；ACH 入金到账后 30 天观察期内不可提现，电汇不受限。可提现金额正式以 DW 返回的 `cashAvailableForWithdrawal` 为准，原型中的扣减只是模拟。
- 场景"已开户（有持仓）"：可提现金额为正数，其中一笔 5 天前到账的 ACH 入金 $300 仍在观察期内，会被扣除。
- 场景"已开户 · ACH 观察期中（可提现 $0）"：**用于演示 30 天观察期**。唯一一笔 ACH 入金 $1,500 在 3 天前到账，仍在观察期内，所以 P-14 出金页的可提现金额为 $0.00。
- 开户提交后约 3 秒自动返回 KYC 结果：美国纳税人 → 通过并开立账户；非美国纳税人 → 人工复核。
- 资金只走 DriveWealth 支持的 ACH（Plaid 绑定本人美国银行账户，原型中为占位，不采集任何凭据）与电汇。电汇收款信息均为示例值。
- 数据保存在浏览器 localStorage 中，切换场景即重置。

## 说明

- 所有行情、账户、机构名称均为虚构演示数据。
- 品牌名"示例券商"是占位，在 `js/core.js` 的 `APP_NAME` 中修改。
- 资金阈值、零碎持仓阈值（$1）、账户类型等是示例取值，对应 `pages.md` 第 5 节尚未确认的问题。

## 目录

```
index.html
css/app.css          设计变量与组件样式
js/data.js           演示数据与场景初始状态
js/core.js           路由、状态、账户计算、DW 开户模拟（DWSim）、组件、图表、账户抽屉(P-08)、原型控制台
js/pages/onboarding.js  P-01 – P-06、P-30、P-34 – P-36
js/pages/assets.js      P-07、P-08 路由、P-11、P-12
js/pages/market.js      P-09、P-10、P-19 – P-22
js/pages/funds.js       P-13 – P-18、P-28、P-29、P-31 – P-33
js/pages/discover.js    P-23 – P-27、S-01
```
