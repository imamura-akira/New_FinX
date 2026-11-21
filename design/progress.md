# 开发进度（progress.md）

> 最近更新：2026-11-20（后端已部署到 VPS，见第 0.2 节；Demo-1 全部任务与 F13 完成；决定 D-1–D-8 已确认，D-9、D-10 待确认，见第 0 节）

## 0. 当前里程碑：Demo-1（客户演示）

目标：真实 Flutter App（iOS 模拟器优先）连接本机 Go 后端与 DW 沙盒，演示三条主线：A 开户、B KYC、C 出入金。M1 的剩余工作并入 Demo-1。

| # | 任务 | 状态 | 提交 |
|---|---|---|---|
| 1 | 迁移 000002、演示验证码 000000、路由挂载、本机访问 | 完成 | 6638838 |
| 2 | 开户草稿与证件暂存接口 | 完成 | 6ade440 |
| 3 | 开户提交编排 | 完成 | 2057c62 |
| 4 | KYC 状态、对账轮询、自动开户 | 完成 | dd89405 |
| 5 | 沙盒实测 A/B | 完成：沙盒中 提交 → KYC 通过 → 账户 OPEN 端到端跑通；P-03e 增加行业/职位下拉（已登记）；PEP/董事写法改为空字符串 | 见 `design/sandbox-log.md` |
| 6 | 资金接口（绑卡 DIRECT、ACH 入金、ACH/WIRE 出金、资金记录、资金汇总、电汇指引、在途对账） | 完成（fake DW + Postgres 测试；沙盒实测在 #7） | 见 git log |
| 7 | 沙盒实测 C | 完成：绑卡、ACH 入金（约 2 秒到账，可用日 DW 返回）、出金拦截、电汇指引均实测；**出金成功路径待 2026-11-23 资金可用后补测** | 见 sandbox-log.md |
| 8 | Flutter 工程骨架 + P-01 / P-02 | 完成：按 feature 分层；ApiClient（信封、错误码、401xx → S-01）；token 存 Keychain；原型设计令牌主题；P-01 欢迎、P-02 邮箱验证码登录、P-07 最小外壳、S-01 会话过期；16 个测试；iPhone 17 模拟器连本机后端实测登录与会话恢复 | 见 git log |
| 8b / 8c / F11a | FinX 主题、后端开户提示英文化、后端虚拟行情 | 完成 | 9e880fe / 80a6122 / a1de760 |
| 9 | Flutter 开户流程（英文、新版式） | 完成 | 3bffaf3 |
| 10 | Flutter P-06 开户进度、P-34/35/36、P-07 资产卡、P-08 抽屉（F12） | 完成 | 8beb241 |
| F11b | Flutter 行情：P-07 自选、P-09、P-10、底部 Tab | 完成 | 5c8f2d0 |
| 11 | Flutter 资金：P-31/32、P-13、P-14、P-18、P-33 | 完成 | e998b7d |
| — | App 图标与显示名称 FinX Stocks（theme.md v1.2） | 完成 | b3c2052 |
| 12 | cmd/demoreset、demo-script.md、真机说明 | 完成 | 9998e82 |
| F13 | 股票大师 / Fifi / 奖励 Tab 模拟数据展示（P-23/24、P-26、P-27），纯客户端 | 完成 | 2e63194 |

### 剩余任务（2026-11-19 修订：纳入 F11 虚拟行情、F12 账户余额、FinX 主题、开户模块英文化）

| # | 任务 | 依赖 | 规模 |
|---|---|---|---|
| 8b ✅ | **Flutter 换 FinX 主题**（design/theme.md：紫罗兰色、渐变主按钮、圆角 18/全圆角按钮、紫味投影）+ 品牌素材（logo、Fifi）入 Flutter assets；P-01 换为 FinX 品牌版式 | #8 | S |
| 8c ✅ | **后端开户模块文案英文化**：提交校验（validate.go）与开户相关接口的报错改为原型英文文案（P-03–P-06、P-30、P-34–P-36）；其余模块保持中文 | #3 | S |
| F11a ✅ | **F11 后端虚拟行情** `internal/marketsim`：随机游走（2s tick，σ 0.0008，均值回归，bid/ask ±1–2bp）、约 30 只标的固定种子、当日分时/日 K；`GET /market/quotes`、`GET /market/instruments/{symbol}`（`simulated: true`）；`MARKET_DATA_MODE=SIM|REAL`；openapi 同步 api-spec 5.5 | #1 | M |
| 9 ✅ | Flutter 开户流（**英文**，新版式：分段进度条、STEP X OF N、税号遮罩 Show/Hide、Save & exit + Continue）：P-03a–g、P-04、P-05、P-30 | 8b、8c | L |
| 10 ✅ | Flutter KYC 与账户：P-06（轮询）、P-34/35/36（入口标"待沙盒验证"）、P-08 抽屉；**F12**：P-07 资产卡与 P-08 接 `/account/money`（余额/购买力/可提现取 DW 返回值，未开户显示开户引导） | #4、#9 | M+ |
| F11b ✅ | **F11 Flutter 行情**：P-07 自选、P-09 市场列表、P-10 个股（仅展示，无下单）；轮询 3–5 秒，价格变动时涨跌色刷新 | F11a、#10（共用 P-07） | M |
| 11 ✅ | Flutter 资金流：P-31/32 绑卡、P-13 入金、P-14 出金、P-18 资金记录 | #6、#10 | L |
| 12 ✅ | 演示辅助：`cmd/demoreset`（含 marketsim 重置）、`design/demo-script.md`、真机说明 | 全部 | S |

**已决定（2026-11-19）**：Rule 14b-1(c) 选"否"时沙盒拒绝开户（Q-DW-11）。用户决定：App 保持现状（不强制选"是"），演示用户在 P-05 选"是"；等 DW 回复后再定正式处理。

**已确认决定（无人值守期间按"不改变合规语义、可逆、影响面最小"自行选择；2026-11-19 用户确认 D-1–D-8 全部按当前选择执行；2026-11-21 用户确认 D-31–D-33（F21 深色配套色值、外观项文案、全局令牌实现方式）按当前实现执行）**

| 编号 | 事项 | 当前选择 | 备选 / 影响 |
|---|---|---|---|
| D-1 | P-09 / P-10 中没有数据源的区块（涨跌分布、内部人增减持、今日热点、成交额、多周期 K 线、NBBO 数量与交易所、成交量） | 不显示，不造假数据；ui-signoff 第 3 节已登记 | 若演示需要完整版式，可用原型的示例数据补齐（会显示非行情接口来源的数字） |
| D-2 | 自选股没有后端接口 | 存在 App 内存中，默认 AAPL / NVDA / TSLA / SPY / QQQ，重启 App 恢复默认 | 第二阶段加 `/watchlist` 接口 |
| D-3 | 个股接口（`/market/instruments/{symbol}`）不含买一 / 卖一价 | P-10 另调 `/market/quotes?symbols=X` 取 bid/ask，不改接口契约 | 也可在个股接口增加 bid/ask（向后兼容的新增字段） |
| D-4 | P-14 电汇出金（WIRE）未经沙盒实测（可提现为 0，需等 2026-11-23） | App 暂不开放电汇出金表单，只做 ACH 出金；后端已支持 | 11-23 补测出金时一并实测后开放 |
| D-5 | P-18 历史记录 | 只显示资金进出，最近 50 条（后端分页游标在响应头，暂未接） | 后续加分页与交易流水 |
| D-6 | `cmd/demoreset` 的"行情重置" | 不新增 HTTP 管理接口；虚拟行情用固定种子初始化，重启后端即重置（demo-script 已写明） | 若需不重启重置，可加仅 sandbox、仅本机可用的管理接口 |
| D-7 | 已入金测试用户的 DW 用户 id、银行 id | 存在 `backend/demo-users.local.json`（`*.local.json` 已 gitignore，不提交），`demoreset import -local` 使用；两用户已于 2026-11-19 恢复本地关联（funded1 / funded2@example.com） | 也可每次手动传 `-dw-user` 等参数 |
| D-8 | CLAUDE.md 规则 7"用户可见文字用简体中文"与开户 / KYC 模块英文化（ui-signoff 已登记）字面冲突 | 用户确认后已在 CLAUDE.md 规则 7 补充开户与 KYC 模块英文的例外说明 | 建议在规则 7 后补一句"开户与 KYC 模块（P-03–P-06、P-30、P-34–P-36）为英文，见 ui-signoff 第 3 节" |
| D-9 | P-24 机构详情：原型中的"详情页结构待补充设计"内部提示 | App 不显示该内部提示，改为底部"演示数据"标注；前五大持仓保留"（示例）"字样 | 若需与原型完全一致，可恢复该提示 |
| D-10 | 股票大师 / Fifi / 奖励页右上角头像（原型进入 P-08 抽屉） | 未加头像入口，抽屉只在资产页（P-07）打开 | 如需每个 Tab 都能打开抽屉，可把抽屉上移到底部 Tab 外壳 |
| D-11 | design/prd.md 工作区曾被 v1.0 旧副本覆盖（缺 F13，且删掉了 F11、F12、DoD 第 9–10 条与开户英文说明） | **用户决定（2026-11-19）**：恢复已提交版本，并补登 F13，升为 v1.1（旧副本备份在本机 scratchpad，未提交） | 已处理 |
| D-12 | 排查"真机入金后余额为 0"：任务中邮箱为占位符 `<邮箱>` | 按最近一个真机用户 1@example.com 排查（另一真机用户 jacksmeagol@example.com 情况相同）；结论为 DW 资金划转窗口未开放（sandbox-log 2026-11-20），未改代码 | 若指的是其他用户，告知邮箱后重查 |
| D-13 | F14 页面入口：需求只列了 P-10 买入 / 卖出入口，P-11 / P-12 没有指定入口 | 按 pages.md P-07 规格（"待处理订单 → P-11、持仓 → P-12"），在资产页已开户时加一个"交易"分组（持仓、订单两行），P-12 右上角可进订单；P-19 结果页"查看订单" | 若需与原型版式一致（订单摘要卡、持仓环形图），二期按原型补 |
| D-14 | P-08 抽屉"市值"原为写死的 $0.00（Demo-1 无交易） | 改为 DW `summary/positions` 的 equityValue（取不到显示"—"，不影响资金展示） | — |
| D-15 | 按股数买入的购买力校验需要价格，DW 下单前无法给出成交价 | 前后端都用虚拟行情卖一价估算金额做前置校验；无报价时只能按金额买入。卖出参考价用买一价 | 接入真实行情后改用 NBBO |
| D-16 | P-19 规格中的预估佣金 / 费用、极小剩余持仓提示、违规风险预警（合规 10、15） | 本期未做（需求未要求，且 DW 佣金表与 GFV 规则未实测）；已登记 ui-signoff 与 prd 风险项 | 生产前必须补齐 |
| D-17 | 订单不存在 / 不属于当前用户的错误码 | 沿用资金模块做法返回 40901"订单不存在"（契约没有 404 业务码） | 若要区分，可在 api-spec 新增 40401（向后兼容） |
| D-18 | 首页"总资产"是否计入持仓市值 | **已定案（用户 2026-11-21）**：总资产 = 现金 + 持仓市值，取自 `GET /account/allocation`（均为 DW 返回值，后端相加），与资产分布卡共用同一份数据，两处数字完全一致（环心不再取整）；取不到时显示"—"，不以现金冒充总资产。审计 FUND-P0-3 | — |
| D-19 | P-27 原合规提示条（"若积分获取与入金或交易行为挂钩，需确认相关激励合规要求"）在 F16 定稿图中没有 | 按定稿移出页面，改登记为 prd 第 7 节 F16 风险项；页面底部保留"奖励内容为演示示例……以上线公告为准" | 若要求页面上继续显示，可在底部小字上方恢复提示条（不改其他结构） |
| D-20 | F18 报错文案策略（中文模式） | 已知后端提示精确映射双语；其余按错误码。中文模式下若后端返回了具体中文提示（如"超过可提现金额 $x"），仍显示后端原文，比错误码通用文案更具体；英文模式下后端中文原文一律改用错误码对应的英文通用文案 | 若要求严格"只按错误码"，把 localizeError 的中文分支改为通用文案即可 |
| D-21 | 后端自由文本（订单拒绝原因、出入金失败原因）英文模式显示 | 后端为中文且不改接口，英文模式下显示通用英文说明（"The broker rejected this order…"），中文模式原样显示 | 需要精确英文原因时，后端可增加 reasonCode 或英文原文（向后兼容） |
| D-22 | 英文术语与措辞（保守选择） | 挂单中 = Working；当日有效 = Day；可提现 = Available to Withdraw；观察期 = holding period；演示数据中的虚构机构名在英文下用英文名并标 (Sample)；"待 DW 确认" = to be confirmed by DW。所有英文为团队自译 | 上线前请母语审校与合规复核，尤其风险提示、费用与时效说明 |
| D-23 | 语言选择的存储 | 存在 Keychain（与会话 token 同一 flutter_secure_storage，非敏感值），未新增依赖 | 如需跨设备同步，需后端用户偏好接口 |
| D-24 | 为容纳英文的版式微调 | P-26 功能卡宽高比 1.45 → 1.25（英文两行副标题不溢出）；资产趋势空态文字居中；其余版式不变 | 如需保持原比例，可改为英文副标题单行省略 |
| D-25 | 总资产卡"今日变动"的口径 | 今日变动 = DW 各持仓 unrealizedDayPL 之和（只含持仓涨跌，不含当日出入金）；百分比基数 = 现金 + 持仓市值 − 今日变动（即昨日资产）。总资产金额本身仍按 D-18 显示 DW 现金，未改；模拟盘卡沿用"模拟盈亏"，未加今日变动 | 若 D-18 改为"现金 + 持仓市值"，今日变动口径不变；若要计入出入金，需后端提供日初资产或按每日快照计算 |
| D-26 | F19 多空比例是否模拟"他人下注" | 不模拟：比例只随真实下注变化，初始比例来自种子流动性（事件市场按示例概率，15 分钟市场 50% / 50%）。演示时若无人下注，比例保持不变（下注后即时变化并有滚动动画） | 如需演示时比例更"活"，可加带标注的做市机器人（需明确标为模拟，不能称为"用户观点"） |
| D-27 | 15 分钟市场的目标价与结算价 | 目标价 = 该窗口创建时的虚拟行情价（后台每 5 秒检查，通常在窗口开始后几秒内创建）；结算价 = 到期后首次检查时的虚拟行情价（通常 ≤ 5 秒）；到期超过 2 分钟才结算（如服务停机）则整窗作废退回本金；收盘价等于目标价作废 | 如需精确到秒，可在 marketsim 记录窗口边界价格 |
| D-28 | F19 下注限额与积分 | 单笔 10–5,000 分，初始 10,000 分，无补充积分机制（演示期间可用 demoreset 重置）；赔率上限 50 倍（概率夹在 2%–98%） | 可加"每日签到补分"等，需另行设计 |
| D-29 | 事件市场示例题目 | 内置 7 个：效果图中 3 个（美联储降息、NVDA 站上 $150、BTC 年底新高）+ CPI、S&P 500 年末周、超级碗、AI 新模型；题目为演示示例，截止后需用 cmd/predictctl 人工结算 | 正式上线前替换为经合规审核的题目 |
| D-30 | F20 欢迎页的"高点"与光点呼吸 | 高点取 5 个：3 个局部高点 + 上升由陡转缓的拐点 (284,30) + 终点（严格局部高点只有 3 个 + 终点，需求为 4–5 个，取 5 个与 5 声对应）；终点光点呼吸 3 次后常亮（无限呼吸会持续耗电，也会让页面一直处于动画状态） | 若要一直呼吸，把 _breathe 的 count 去掉即可 |
| D-31 | F21 深色配套色值 | 需求只给了背景 / 卡片 / 分隔线 / 主次文字 / 品牌紫 / 涨跌；其余（弱文字、选中底、提示条、模拟盘琥珀、情绪档位、奖励页英雄区、彩带等）按同一色相在深底上推导，见 theme.md 第 10 节 | 若需设计师统一校色，只改 theme.dart 令牌即可，页面无需改动 |
| D-32 | F21 外观项的文案 | 抽屉项中文"外观"、英文"Appearance"（随语言显示一种；语言项保留双语是为了改错语言后仍能找回，外观项无此需要） | 若要与语言项一样双语显示，改两份 ARB 的 appearanceTitle 即可（l10n 测试需同步放行） |
| D-33 | F21 实现方式 | 色板为全局令牌（getter），外观变化时整树重建 + 重绘；未逐页改为 Theme.of(context) 取色，避免改动 300+ 处调用与 CustomPainter 签名 | 与 F18 语言切换同一机制，已有测试覆盖 |

**"1 天到账"验证（2026-11-21）**：按用户授权对 funded1 发起第二笔 $10 ACH（DW `FEYQ000001-1795221580864-DPJID`）。DW 已受理（Approved），但资金划转窗口未开放，**尚未返回购买力 / 可提现生效日**，配置是否属实暂无法判定；11-23 的交易实测（T-1–T-13）与出金补测计划**暂不调整**，窗口开放后复查再定（若生效日为到账次日，则按用户指示提前并标注 Q-DW-8e；若仍为多天，则在 dw-questions.md 新增问题）。本次提交暴露对账重放与 IK075 处理缺陷，已修复并部署（5dfbbee，入金与下单同改；本机库已补录该笔入金），见 sandbox-log 2026-11-21。

**环境清理（2026-11-21）**：停掉 2026-11-19 23:00 为导出 DW 原始报文临时启动的本地后端（scratchpad 下的 finx-server，进程 75070，监听 8080），确认进程已退出、8080 端口已释放。该进程遗留期间曾导致一次问题：未带 `API_BASE_URL` 的模拟器调试包默认连到 127.0.0.1:8080，被这个本地后端返回 401，iPhone 17 模拟器上的登录状态因此被清除（需重新登录）。以后临时服务用完即停。

**待办（日期相关）**：**2026-11-23 之后**补测出金——用 #7 中已入金的两个虚构测试用户（$1,000、$5,000；本地数据库曾重建，本地关联已于 2026-11-19 用 `demoreset import` 恢复，登录 funded1 / funded2@example.com 即可），验证 `POST /funding/redemptions` 成功响应结构与状态推进（ACH，必要时 WIRE）、出金后资金汇总变化，并走通演示出金路径；结果回写 sandbox-log.md 与 api-spec.md。

DoD 对应：第 9 条（首页真实余额、入金后可见变化）→ #10 + #11；第 10 条（行情可见变动）→ F11a + F11b。

**恢复步骤**：Demo-1 清单已全部完成。下一步：① 用户确认待确认决定 D-1–D-8；② 2026-11-23 之后补测出金（上方待办）；③ 按 design/demo-script.md 彩排一次。
App 运行方式见 `app/README.md`。注意：项目在 iCloud 同步的桌面目录，`app/build` 是指向 `~/Library/Caches/finx-app-build` 的符号链接（否则 codesign 因 iCloud 扩展属性失败）；若误删，重建：`cd app && ln -s ~/Library/Caches/finx-app-build build`。
本地运行（演示模式 + 沙盒分析日志）：

```bash
cd "/Users/ak/Desktop/Claude FinX New/backend" && (set -a; source ./.env; set +a; DATABASE_URL='postgres://postgres:dev@127.0.0.1:55432/finx?sslmode=disable' OTP_DEV_LOG=true KYC_POLL_INTERVAL=10s DW_LOG_BODIES=true go run ./cmd/server)
```

---

## 0.1 Demo-1 完成汇报（2026-11-19 夜，无人值守执行）

**结论**：Demo-1 清单（8b–12、F11、F12）全部完成，每项单独提交（未推送）。三条主线均可在 iOS 模拟器上连接本机后端与 DW 沙盒演示：
- **A 登录与行情**：邮箱验证码登录；P-09 / P-10 / P-07 自选的虚拟行情每 3 秒刷新、涨跌闪色；未登录可浏览行情。
- **B 开户**：英文开户流程 → 提交后数秒 KYC 通过、自动开户 → P-06 显示账户号码；P-07 资产卡与 P-08 抽屉显示 DW 实时资金。
- **C 资金**：绑卡（DIRECT）、ACH 入金、出金（DW 可提现校验）、资金记录（显示 DW 返回的可用日）、电汇入金指引。

**验证**：
- 后端 `go vet` / `go test ./...` 全部通过。
- Flutter `flutter analyze` 无问题，`flutter test` 68 项通过（开户表单、出入金金额校验均有 widget / 单元测试）。
- 模拟器联调覆盖：开户中与已开户两种状态、行情三个页面、P-13 / P-33 / P-14（DW 真实数据），以及主屏图标与名称。
- 未在模拟器上亲手输入银行账号绑卡（只用测试与 #7 的接口级沙盒实测覆盖）。

**夜间新发现**：
- **沙盒：Rule 14b-1(c) 选 No 时 DW 拒绝开户**（U040，Q-DW-11）。已按用户决定保持现状，演示时选 Yes。
- **后端二进制过旧**：运行中的服务早于"资金来源"修正，导致草稿被拒；已重新编译并重启。`backend/.env` 的 `DATABASE_URL` 原为空值，已按用户指示补上。

**决定**：D-1–D-8（第 0 节表格）已由用户确认，按当前选择执行；F13 新增 D-9、D-10 待确认；D-11（prd.md 版本异常）已按用户决定处理。

**需要用户处理**：
- 推送本地提交：5c8f2d0（F11b）→ 本次汇报提交，共 5 个（3bffaf3、8beb241、60d4ba2 已推送）。
- 未跟踪的 `design/brand/`、`design/screens/`、`design/theme.md`、`prototype/assets/`，以及已修改的 `design/prd.md`、`design/backend-design.md`、`prototype/` 改动，均为用户自己的文件，未纳入提交，请自行决定是否提交。

## 0.2 沙盒演示部署（2026-11-20）

| 项 | 内容 |
|---|---|
| 地址 | `https://finxnew.akira.diy`（`/healthz`、`/api/v1/*`）；App：`--dart-define=API_BASE_URL=https://finxnew.akira.diy/api/v1` |
| 状态 | 已部署版本 `d0bf6de`（含演示验真）；healthz `db: ok`、`dw: configured`；证书有效（Let's Encrypt，TLS-ALPN） |
| 服务器 | Hostinger VPS（Ubuntu 24.04）root@72.60.104.228；与其他项目共用，80/443 由其他项目占用 |
| 路径 | `/opt/finx/backend`（代码 + `.env` + `demo-users.local.json`，均 600）、`/opt/finx/deploy`（compose、脚本、`.env` 含 POSTGRES_PASSWORD 与 IMAGE_TAG、`RELEASES`、`last-deploy.log`） |
| 组成 | compose 项目 `finxnew`：postgres（内部网络、无端口映射、卷 `finxnew-pgdata`）、migrate（一次性）、backend（仅绑 `172.16.0.1:18082`） |
| HTTPS | 共用 Caddy `/opt/elefenjoy-hostinger-demo/Caddyfile.https` 末尾追加了 finxnew 站点块（备份：`Caddyfile.https.bak-20261119-162744-finxnew`）；该 Caddy 为 admin off，改动需重启 `web` 容器（同机站点中断数秒） |
| 安全 | 登录白名单 `ALLOWED_EMAILS`（@example.com + 指定个人邮箱，名单外返回通用 42200）；演示验证码 000000；ufw 未启用（用户决定：其他服务依赖 8443/8795/Tailscale，本项目未新增公网端口） |
| 演示数据 | 服务器上已导入 funded1 / funded2@example.com（DW 实时资金正常） |
| 部署 | 本机 `deploy/deploy.sh`（同步 backend/、deploy/ → 服务器后台构建、迁移、启动、健康检查） |
| 回滚 | 改 `/opt/finx/deploy/.env` 的 `IMAGE_TAG` 为 `RELEASES` 中的旧标签 → `docker compose up -d --no-build backend`；撤销 HTTPS 接入：用上述备份覆盖 Caddyfile.https 后重启 `web`。详见 `deploy/deploy.md` |
| 共用 Caddy 重启 | 2026-11-19 16:27:45 UTC 重启一次（已备份 + 已校验 + 失败自动回滚），容器停止到启动约 0.26 秒；重启后 liveright.cloud 200、staging.finx 401（原有 Basic Auth），均正常 |
| 演示验真 | App（DEMO_MODE）P-08 抽屉底部"DW 沙盒凭证"；服务器上 `demoreset verify -email X` 直接读 DW 原样打印编号与状态，用于当场对照（deploy.md 第 5 节、demo-script B12） |
| 注意 | 服务器对短时间内的多个新 SSH 连接会断开，deploy.sh 已用连接复用；本机代理（fake-IP）下 dig 结果不准，以公共 DNS 为准 |

## 1. 当前位置

- **里程碑**：M0 已完成；M1 剩余工作并入 Demo-1，Demo-1 已全部完成（见第 0、0.1 节）。下文第 2–4 节为早期记录，保留备查。

## 2. 已完成

| 编号 | 内容 | 位置 | 状态 |
|---|---|---|---|
| M0 | 后端骨架、config、store（11 张表）、crypto、dwclient、openapi.yaml | `backend/` | 已推送 |
| 沙盒 | DW token 真实调用返回 200（有效期 3600 秒），凭据正确 | `backend/cmd/dwcheck` | 已验证 |
| — | 统一响应、错误码、请求解析 | `backend/internal/httpx` | 已完成 |
| F1 | 邮箱 OTP、会话 JWT（24 小时，无刷新接口）、`/auth/otp/request`、`/auth/otp/verify`、`/auth/logout`、`/me`；`/auth/oauth` 返回 50003 | `backend/internal/auth` | 有表驱动单测；**已挂载到 `/api/v1`**；已在真实 Postgres 上完成端到端冒烟测试（发码 → 限频 → 错码 → 登录 → /me → 注销 → 40102；日志里没有未打码的邮箱或 token） |
| F2/F3 | dwmapper：App 字段 → 9 类 DW documents，拆为 POST 四类核心 + PATCH 五类；POST/PATCH 请求体；取值无法映射时返回只含字段名的错误 | `backend/internal/dwmapper`（`data.go`、`enums.go`、`mapper.go`） | 9 个测试，覆盖美国/非美国纳税人、PEP/控制人、披露、映射错误不泄露取值、对照表完整性；并有一项契约测试：`Data` 字段与 openapi `ApplicationData` 完全一致 |
| 契约 | 6 个错误码（40101、40102、42200、42901、50000、50003）写入 api-spec.md 第 8 节与 openapi.yaml；api-spec.md 新增第 10 节变更记录（错误码、字段名以 openapi 为准）；openapi `ApplicationData` 补上 `tinConfirm`、`affiliatedAck`、`pepCountry`、`pepRoles`、`controlCompanySymbol`；oauth 增加 501 响应 | `design/api-spec.md`、`backend/api/openapi.yaml` | 契约测试已覆盖错误码枚举 |
| 环境 | `backend/.env` 已追加 `PII_ENCRYPTION_KEY`、`JWT_SECRET`；Flutter 3.50.0（`~/development/flutter`）；临时 Postgres 容器 `finx-pg`（已迁移到版本 1） | — | — |

## 3. 未开始 / 待办

| 事项 | 位置 | 说明 |
|---|---|---|
| 迁移 000002 | `backend/internal/store/migrations/` | `dw_users.dw_user_id` 改为可空（先存后端生成的 username/password，再调 POST /users，防止重复创建）；`applications` 加 `submit_attempts`、`submit_error`、`submit_blocked`、`last_attempt_at`；新增 `application_documents`（提交前暂存加密证件，提交时转 DW `POST /documents`） |
| F2 草稿接口 | `backend/internal/application/` | `GET /application`、`PUT /application/draft`：顶层字段浅合并、data_enc 加密（AAD 绑定行）、读取时税号打码；客户端回传打码值视为未修改；不在 `ApplicationData` 中的字段丢弃 |
| F2 证件上传 | 同上 | `POST /application/documents`：加密暂存，提交时上传 |
| F3 提交与编排 | 同上 | 完整校验（文案与原型 P-03 一致，可选值用 `dwmapper.Allowed`）、披露全部确认、签名等于法定姓名、非美国纳税人必须有证件；编排 CREATED→PATCHED→DOCS_DONE，`USER_SUBMIT_MODE=SINGLE_POST` 时合并为一次提交；后台每分钟重试，4xx 错误转人工处理 |
| F4 状态 | `backend/internal/application/`、`internal/events/` | `GET /application/status`；非终态 KYC 每分钟调 `GET /users/{id}/kyc-status` 对账 |
| Flutter `app/` | — | P-01、P-02、P-03a–g、P-04、P-05、P-30、P-06；字段名直接用接口字段名 |
| 沙盒创建测试 User | `design/sandbox-log.md`（新建） | 按报错修正 `dwmapper/enums.go`，并回写 pages.md 3.1.2；记录首次 POST /users 是否直接返回 APPROVED（Q-DW-1） |
| 邮件服务选型（SES 等） | — | 第一阶段不接入，验证码通过 `OTP_DEV_LOG=true` 打印到日志；生产前必须完成 |
| 会话刷新 | — | 第一阶段维持 24 小时后重新登录；生产前再评估 |

## 4. 下次恢复的第一步

```bash
cd "/Users/ak/Desktop/Claude FinX New/backend" && go build ./... && go test ./...
```

确认数据库容器在运行（现为 `--restart unless-stopped` + 数据卷 `finx-pgdata`，Docker 重启后数据保留）。容器不存在时重新创建并迁移：

```bash
docker ps --filter name=finx-pg --format '{{.Names}}' | grep -q finx-pg || docker run -d --name finx-pg --restart unless-stopped -v finx-pgdata:/var/lib/postgresql/data -e POSTGRES_PASSWORD=dev -e POSTGRES_DB=finx -p 127.0.0.1:55432:5432 postgres:16-alpine
```

```bash
cd "/Users/ak/Desktop/Claude FinX New/backend" && (set -a; source ./.env; set +a; DATABASE_URL='postgres://postgres:dev@127.0.0.1:55432/finx?sslmode=disable' go run ./cmd/server -migrate up)
```

（早期记录，已完成）当时的下一步："继续节点 1：写迁移 000002，再实现 application 包的草稿接口（GET /application、PUT /application/draft）及其单测"。

本地运行服务器时（`DATABASE_URL` 已写入 .env；`OTP_DEV_LOG` 仍在命令行传入）。演示用启动方式见 design/demo-script.md 第 1 节：

```bash
cd "/Users/ak/Desktop/Claude FinX New/backend" && (set -a; source ./.env; set +a; DATABASE_URL='postgres://postgres:dev@127.0.0.1:55432/finx?sslmode=disable' OTP_DEV_LOG=true go run ./cmd/server)
```

## 5. 已决定事项（2026-11-19）

1. 六个错误码批准，已写入契约。
2. 字段名以 openapi.yaml `ApplicationData` 为准；Flutter 不做旧名转换；已在 api-spec.md 第 10 节登记。
3. 会话维持 24 小时后重新登录，不加刷新接口，生产前再评估。
4. 第一阶段不接邮件服务商，验证码走开发态日志；SES 选型列入待办。
5. DW 枚举先用最可能的取值（`dwmapper/enums.go`），沙盒报错时修正并回写 pages.md 3.1.2。
6. token 额度无需处理。

## 6. 需要你决定的事项

暂无。
