# 接口方案（api-spec.md）— App ↔ 我方后端 v1

> 原则：**App 只调用我方后端，绝不直接调用 DW**；后端是 DW 的唯一出口（见 backend-design.md）。
> 契约先行：本文件冻结后生成 OpenAPI（`backend/api/openapi.yaml`），前后端各自生成代码。
> 所有响应为 `{"code":0,"message":"ok","data":{...}}` 包装；错误码见第 8 节。时间一律 ISO-8601 UTC。
> 标注【Q-DW-x】的字段/行为依赖 DW 答复，实现时走配置开关。

Base URL：`/api/v1`　认证：`Authorization: Bearer <sessionToken>`（除 /auth/* 外均必须）

## 1. 认证（F1，P-01/P-02）

| 方法 路径 | 请求 | 响应 data | 说明 |
|---|---|---|---|
| POST /auth/otp/request | `{email}` | `{ttl, resendAfter}` | 发验证码；限频 |
| POST /auth/otp/verify | `{email, code}` | `{sessionToken, isNewUser}` | 登录/注册合一 |
| POST /auth/oauth | `{provider: "GOOGLE"\|"APPLE", idToken}` | `{sessionToken, isNewUser, emailIsRelay}` | 阶段 1.5；Apple 中转邮箱置 emailIsRelay=true【Q-DW-6b】 |
| POST /auth/logout | — | — | 注销会话 |
| GET /me | — | `{email, loginProvider, applicationId, accountStatus}` | 启动时取全局状态 |

## 2. 开户申请（F2/F3，P-03–P-05、P-30）

| 方法 路径 | 请求 | 响应 data | 说明 |
|---|---|---|---|
| GET /application | — | `{applicationId, status, step, data, disclosures, kyc, documents[]}` | status: NONE/DRAFT/SUBMITTED/APPROVED/DENIED |
| PUT /application/draft | `{step, data{...}}` | `{savedAt}` | 自动保存；字段名与 pages.md P-03 数据字段一致 |
| POST /application/documents | `{docType, side: "FRONT"\|"BACK", image(base64)}` | `{documentId}` | P-04/P-35 证件；后端转 DW `POST /documents` |
| POST /application/submit | `{signatureName, disclosures[]}` | `{applicationRef, submittedAt}` | 后端：`POST /users`（BASIC/IDENTIFICATION/PERSONAL/ADDRESS_INFO）→ `PATCH /users/{userID}`（其余 documents）【Q-DW-3】→ 证件上传。username/password 后端生成【Q-DW-4】 |
| GET /application/status | — | `{kycStatus, kycUpdatedAt, issues[]{code,field,userMessage}, requiredDocs[], accountStatus, accountNo, applicationRef, submittedAt, submitState}` | P-06 轮询/推送合一接口；kycStatus 为 DW 8 状态 |
| PATCH /application/remediate | `{fields{...}}` | `{resubmittedAt}` | P-34；后端 `PATCH /users/{userID}`，DW 重跑 KYC |

**KYC 状态枚举**（与 DW 一致，已核实）：`KYC_NOT_READY / KYC_READY / KYC_PROCESSING / KYC_INFO_REQUIRED / KYC_DOC_REQUIRED / KYC_MANUAL_REVIEW / KYC_APPROVED / KYC_DENIED`

**App 数据 → DW document 映射**：见 pages.md 3.1.2 表（后端据此组装；App 不感知 DW 字段名）。

## 3. 账户（F6，P-06/P-08/S-01）

| 方法 路径 | 响应 data | 说明 |
|---|---|---|
| GET /account | `{accountId, accountNo, status, accountType:"LIVE", tradingType:"CASH", managementType:"SELF", openedAt}` | status: PENDING/OPEN/OPEN_NO_NEW_TRADES/FROZEN/CLOSED |
| GET /account/money | `{cash, settledCash, buyingPower, cashAvailableForWithdrawal, unsettled, pendingDeposits, withheldForSeasoning, updatedAt}` | 来自 DW 账户资金汇总【Q-DW-8d 复核字段名】；**可提现一律用 DW 返回值** |
| GET /account/allocation | `{simulated, total, items:[{type: "STOCK"\|"ETF"\|"CASH", amount, pct}], updatedAt}` | P-07 资产分布（F17，2026-11-20 新增）。现金取 DW summary/money 的 cash.cashBalance（与 /account/money 的 cash 同源），持仓市值取 DW summary/positions 的 marketValue，按我方标的列表 STOCK / ETF 归堆（列表外代码按股票计）；total = 现金 + 股票 + ETF；pct 由后端计算（一位小数，最大余数法合计 100.0，总额为 0 时全为 0）；items 固定 3 条、顺序 STOCK→ETF→CASH，0 金额照常返回。未开户 40901，DW 失败 50001 |
| GET /account/history | `?range=7D\|30D\|90D\|ALL`（缺省 7D）→ `{simulated, range, points:[{date, total, cash, stock, etf}]}` | P-07 资产趋势（F17）。每日资产快照：每个用户 × 账户类型 × 美东日期一条，按日期升序；7D/30D/90D 为含今日的最近 N 个美东自然日。收盘后（美东 16:10 起）记录 CLOSE 快照；当日首次请求分布 / 趋势时若尚无记录兜底写入一条（之后被收盘快照覆盖）。有几天返回几天，不补造历史；快照为内部记录，金额以 DW 返回为基础。range 非法 42200 |

## 4. 银行账户（F7，P-31/P-32）

| 方法 路径 | 请求 | 响应 data | 说明 |
|---|---|---|---|
| GET /funding/bank-accounts | — | `[{id, bankName, mask, type, ownerName, status, createdAt}]` | |
| POST /funding/bank-accounts | 方案 A：`{accountNumber, routingNumber, type, nickname}`；方案 B：`{plaidProcessorToken}` | `{id, status}` | 【Q-DW-2 二选一】后端转 DW `POST /back-office/bank-accounts`（方案 A 已核实）；户名一致性校验方式随 Q-DW-2 |
| DELETE /funding/bank-accounts/{id} | — | — | 有在途入/出金时返回 40901 |

## 5. 出入金（F8/F9，P-13/P-14/P-33/P-18）

| 方法 路径 | 请求 | 响应 data | 说明 |
|---|---|---|---|
| GET /funding/deposit-instructions | — | `{beneficiaryName, bankName, bankAddress, accountNumber, routingNumber, swift, reference}` | 电汇指引；后端转 DW `GET /accounts/{id}/funding/deposit-instructions`；reference 必含账户号+姓名 |
| POST /funding/deposits | `{bankAccountId, amount}` | `{transferId, status}` | ACH；后端转 DW `POST /back-office/funding/deposits`（type=ACH，已核实） |
| POST /funding/withdrawals | `{method:"ACH"\|"WIRE", amount, bankAccountId?, wire?{bankName, accountNumber, swiftOrAba, country, intermediarySwift?}}` | `{transferId, status}` | 后端转 DW `POST /funding/redemptions`【Q-DW-8d 字段待核】；WIRE 收款人固定为本人，后端强制 |
| GET /funding/transfers | `?type=&cursor=` | `[{transferId, type, method, amount, status, failureReason, submittedAt, doneAt}]` | P-18 时间线 |

**入金状态枚举**（DW Deposit Status）：`STARTED / PENDING / SUCCESSFUL / FAILED / RETURNED / APPROVED / REJECTED / ON_HOLD / PROCESSING`（PROCESSING 为沙盒实测新增，见第 10 节）；出金状态枚举待 Q-DW-8d。
**金额校验**：限额走后端配置 `limits.*`（当前示例值）；超限返回 42201 并带限额。

## 5.5 市场数据（F11，阶段性虚拟行情）

> 第一阶段由后端**虚拟行情服务**提供（随机游走模拟，非真实数据），响应统一带 `simulated: true`；
> 接口形状按真实行情设计，接入真实数据源时只换实现、不改契约。App 轮询间隔 3–5 秒。

| 方法 路径 | 请求 | 响应 data | 说明 |
|---|---|---|---|
| GET /market/quotes | `?symbols=AAPL,SPY` | `{simulated, ts, quotes:[{symbol, last, chg, chgPct, bid, ask}]}` | 批量报价；P-07 自选、P-09 列表用 |
| GET /market/instruments/{symbol} | — | `{simulated, symbol, name, last, chg, chgPct, dayHigh, dayLow, prevClose, candles:[{t,o,h,l,c}]}` | P-10 个股页；candles 为模拟分时/日 K |
| GET /market/sentiment | — | `{simulated: true, ts, fearGreed:{value, label, components:{breadth, change, momentum, volatility}}, breadth:{up, down, flat, total, flatThresholdPct}}` | P-09 市场情绪卡（2026-11-20 F11 扩展，无需登录，App 每 3 秒轮询）。`value` 0–100 整数；`label` 档位：0–24 `EXTREME_FEAR` 极度恐慌、25–44 `FEAR` 恐慌、45–55 `NEUTRAL` 中性、56–75 `GREED` 贪婪、76–100 `EXTREME_GREED` 极度贪婪。由虚拟行情合成：涨跌家数 30% + 平均涨跌幅 30% + 动量 20% + 波动 20%，指数平滑缓慢变化。`breadth` 统计全部虚拟标的，\|涨跌幅\| < `flatThresholdPct`（0.10%）计为平盘。**恐慌贪婪指数正式数据源待定（自行计算或采购，不得抓取第三方指数）** |

## 5.6 交易（F14，P-19 / P-11 / P-12）

> 后端转 DW `POST /orders`、`GET /orders/{orderID}`、`PATCH /orders/{orderID}`（`method: CANCEL`）、`GET /accounts/{accountID}/summary/positions`（字段依据 DW 参考文档，2026-11-20 查阅；沙盒实测排在 2026-11-23）。
> 支持**市价单**与**限价单**（2026-11-20 扩展，限价单只做当日有效 DAY）；订单在我方落库（含 Idempotency-Key），状态以 DW 返回为准（对账任务与查询时刷新）。

| 方法 路径 | 请求 | 响应 data | 说明 |
|---|---|---|---|
| POST /orders | `{symbol, side: "BUY"\|"SELL", orderType: "MARKET"\|"LIMIT", amount?, quantity?, limitPrice?, timeInForce?: "DAY"}` | `{orderId, status}` | 市价单：`amount`（美元，两位小数，允许碎股）与 `quantity`（股数，最多 6 位小数）二选一。限价单：必须按 `quantity`，`limitPrice` > 0（$1 以上最多两位小数，$1 以下最多四位），有效期只支持 `DAY`（缺省即 DAY）；买入冻结金额 = quantity × limitPrice，须 ≥ 单笔最低且 ≤ DW 购买力；后端转 DW 字段 `orderType: "LIMIT"`、`price`、`timeInForce: "DAY"`。后端强制：买入预估金额 ≤ DW 购买力（`cashAvailableForTrade`），且 ≥ 单笔最低 $1（示例值，配置 `LIMIT_MIN_ORDER`）；卖出股数 ≤ DW 可卖数量（`availableForTradingQty`）；按金额卖出 ≤ 可卖数量 × DW 市价。超限 42201（附 `limits`）；账户 OPEN_NO_NEW_TRADES 时买入返回 40301；同一订单 10 秒内重复提交 40901；结果不明 50001 附 `orderId` |
| GET /orders | `?status=OPEN\|CLOSED&cursor=` | `[Order]` | 每页 50 条，下一页游标在响应头 `X-Next-Cursor`（同 /funding/transfers）；未开户返回空数组 |
| GET /orders/{id} | — | `Order` | 未完结订单查询时向 DW 刷新一次 |
| POST /orders/{id}/cancel | — | `{orderId, status}` | 仅 NEW / PARTIAL_FILL 可撤；其他状态 40901。后端转 DW `PATCH /orders/{orderID}`，撤单结果以 DW 返回状态为准（可能先为 PENDING_CANCEL） |
| GET /positions | — | `{updatedAt, equityValue, positions:[{symbol, quantity, sellableQty, avgPrice, costBasis, marketPrice, marketValue, unrealizedPL, unrealizedDayPL}]}` | 全部为 DW `summary/positions` 返回值（App 只计算盈亏百分比）；未开户返回 40901 |

**Order**：`{orderId, orderNo, symbol, side, orderType, quantity, amount, limitPrice, timeInForce, status, filledQty, avgPrice, totalAmount, fees, rejectReason, submittedAt, updatedAt, doneAt}`（`limitPrice` / `timeInForce` 仅限价单有值）；`quantity` / `amount` 为委托值（二者其一为 null），`filledQty`、`avgPrice`、`totalAmount`、`fees` 为 DW 返回（未成交为 null），`rejectReason` 为可展示的中文原因（不透出 DW 原文）。
**订单状态枚举**（DW Order Status）：`NEW / PARTIAL_FILL / FILLED / REJECTED / CANCELED / PENDING_CANCEL`；我方新增 `SUBMITTING`（已记录、提交结果待确认）。App 文案：NEW = 排队中 / 已报，PARTIAL_FILL = 部分成交，FILLED = 已成交，REJECTED = 已拒绝，CANCELED = 已撤单，PENDING_CANCEL = 撤单中，SUBMITTING = 提交中。

## 5.7 模拟交易 / 模拟盘（F15，演示与练习用途）

> 全部在我方后端实现，**不调用 DW**；数据存独立表（paper_*），与真实账户、DW 资金数字完全分开。需要登录，不要求已开立 DW 账户。
> 撮合依据虚拟行情（F11）：市价买入按卖一价、卖出按买一价即时成交；限价单价格到达才成交（买：卖一价 ≤ 限价；卖：买一价 ≥ 限价，均按当时报价成交），挂单期间冻结资金 / 股数，当日有效（美东日切后自动撤销）。所有响应带 `simulated: true`。

| 方法 路径 | 请求 | 响应 data | 说明 |
|---|---|---|---|
| GET /paper/account | — | `{simulated, initialCash, cash, reservedCash, buyingPower, positionsValue, totalValue, totalPL, totalPLPct, resetAt, updatedAt}` | 首次访问自动创建（初始资金 `PAPER_INITIAL_CASH`，默认 100000）。buyingPower = cash − reservedCash（限价买单冻结）；totalPL = totalValue − initialCash |
| POST /paper/account/reset | — | 同上 | 一键重置：恢复初始资金，清空模拟持仓与订单 |
| GET /paper/account/allocation | 同 /account/allocation（`simulated: true`） | 模拟账户资产分布（F17）：现金含限价买单冻结部分，持仓按虚拟行情估值，不调用 DW |
| GET /paper/account/history | 同 /account/history（`simulated: true`） | 模拟账户每日快照（独立存储，mode=PAPER）；一键重置不删除历史快照 |
| POST /paper/orders | `{symbol, side, orderType: "MARKET"\|"LIMIT", amount?, quantity?, limitPrice?, timeInForce?: "DAY"}` | `{orderId, status}` | 市价单：amount 与 quantity 二选一；限价单：必须按 quantity，`limitPrice` > 0（$1 以上最多两位小数，$1 以下最多四位），有效期只支持 DAY。超出可用资金 / 可卖数量 / 单笔最低 → 42201（附 limits）；无演示行情的代码 → 42200 |
| GET /paper/orders | `?status=OPEN\|CLOSED&cursor=` | `[PaperOrder]` | 同 /orders 分页规则；查询前先撮合 |
| GET /paper/orders/{id} | — | `PaperOrder` | 不存在或非本人 40901 |
| POST /paper/orders/{id}/cancel | — | `{orderId, status: "CANCELED"}` | 仅未成交（NEW）可撤，撤单后释放冻结 |
| GET /paper/positions | — | `{simulated, updatedAt, equityValue, positions:[Position]}` | 结构同 GET /positions；市价、市值、盈亏按虚拟行情计算（模拟值） |

**PaperOrder**：Order 的全部字段 + `limitPrice`、`timeInForce`、`simulated: true`；状态取值 `NEW / FILLED / CANCELED / REJECTED`，`fees` 恒为 0。

## 5.9 预测板块（F19，积分演示版）

> 全程使用**预测积分**（每用户初始 10,000 分），不涉及真实资金、券商账户与模拟盘账户，数据独立存储（predict_* 表，迁移 000009）；响应带 `simulated: true`。真金 / 去中心化版本为独立研究项，需独立合规评估。

| 方法 路径 | 请求 | 响应 data | 说明 |
|---|---|---|---|
| GET /predict/account | — | `{simulated, points, initialPoints, stats}` | 首次访问自动创建积分账户；stats 见下 |
| GET /predict/markets | `?category=ALL\|CRYPTO\|STOCKS\|MACRO\|SPORTS\|TRENDING` | `{simulated, serverTime, updown:[PredictMarket], events:[PredictMarket]}` | updown：BTC / SOL 当前 15 分钟窗口（UTC 15 分钟对齐，目标价 = 窗口创建时的虚拟行情价）；events：未截止事件市场（后端种子数据 7 个） |
| GET /predict/markets/{id} | — | `PredictMarket` | 不存在 40901 |
| POST /predict/bets | `{marketId, outcome: "YES"\|"NO", stake}` | `{simulated, bet, points, market}` | stake 为整数 10–5,000 且 ≤ 积分余额（不足 42201）；市场截止后 40901；涨跌市场 YES = 上涨、NO = 下跌。**赔付简化模型**：按下注时所选方向的概率 p（该方向池 ÷ 两边池，含种子流动性，夹在 2%–98%）定赔率，若正确可得 floor(stake ÷ p) 分（含本金）；下注后池子增加，比例随双边下注量实时变化。**AMM / 订单簿定价留二期** |
| GET /predict/bets | — | `{simulated, bets:[PredictBet], stats}` | 最近 200 笔，含市场摘要 |
| POST /predict/claim | — | `{simulated, claimed, points}` | 领取全部已结算派彩（命中派彩、作废退回本金） |

- **PredictMarket**：`{id, kind: UPDOWN|EVENT, category, symbol, title:{zh,en}, subtitle:{zh,en}, outcomes:[{key, label:{zh,en}, percent, pool}], opensAt, closesAt, targetPrice, settlePrice, status: OPEN|CLOSED|SETTLED, result: YES|NO|VOID|null}`；**PredictBet**：`{id, marketId, outcome, stake, probability, potentialPayout, status: OPEN|WON|LOST|VOID, payout, claimed, createdAt, settledAt, market}`；**stats**：`{settled, wins, hitRate, netPoints, claimable, openBets, openStake}`（命中率不含作废；累计盈亏 = 已结算派彩 − 本金）。
- **结算**：涨跌市场到期由后端按虚拟行情自动结算（收盘价 > 目标价为上涨，< 为下跌，相等作废）；到期超过 2 分钟才结算（如服务停机）则作废退回本金，避免用事后价格结算。事件市场由管理命令 `cmd/predictctl settle <id> YES|NO|VOID` 结算。
- BTC / SOL 为虚拟行情新增的模拟加密标的（`GET /market/quotes` 可查），只用于积分预测，实盘与模拟盘下单均不报价。

## 6. 文件与通知（F10，P-15/P-17）

| 方法 路径 | 响应 data | 说明 |
|---|---|---|
| GET /documents?type= | `[{docId, type, title, period, date, url}]` | 交易确认书/对账单/税务；url 为短时效签名链接 |
| GET /notifications?cursor= | `[{id, category, title, body, createdAt, read, deepLink}]` | |
| POST /notifications/read | `{ids[]}` | — | |

## 7. 状态推送

第一阶段 App 用**轮询**（P-06 在 KYC 非终态时 5–10s 轮询 /application/status；资金详情页同理）。后端内部由 SQS 事件驱动更新（kyc.created/updated、deposits.*、bankAccounts.created【事件名待 DW 确认】），轮询 DW 仅用于对账。阶段 1.5 评估 WebSocket/推送。

## 8. 错误码

| code | 含义 |
|---|---|
| 0 | 成功 |
| 401xx | 未登录 / 会话过期（App → S-01 会话过期页），具体码如下 |
| 40101 | 未登录 / token 无效（HTTP 401） |
| 40102 | 会话过期或已注销（HTTP 401；会话有效期 24 小时，无刷新接口，需重新验证码登录） |
| 40301 | 账户受限（附 restriction: FROZEN / OPEN_NO_NEW_TRADES） |
| 40901 | 状态冲突（在途资金禁止解绑、重复提交等） |
| 422xx | 字段校验失败类，具体码如下 |
| 42200 | 字段校验失败（HTTP 422；附 fields[]{field, reason}，文案与 P-03 校验一致） |
| 42201 | 金额超限（HTTP 422；附限额） |
| 42901 | 请求过于频繁（HTTP 429；如验证码限频；附 retryAfter 秒数） |
| 50000 | 服务器内部错误（HTTP 500；对用户显示"稍后重试"） |
| 50001 | DW 调用失败（对用户显示"稍后重试"，不透出 DW 原始错误） |
| 50002 | DW 返回数据异常（已记录，人工介入） |
| 50003 | 功能暂未开通（HTTP 501；如阶段 1.5 的 Google / Apple 登录） |

## 9. 版本与冻结

- 变更 2026-11-19：新增 5.5 市场数据（虚拟行情，F11）；/account/money 的展示要求见 PRD F12。

- 本契约 v1 随 UI 定稿冻结路径与字段名；新增字段向后兼容，破坏性变更升 /api/v2。
- 【Q-DW-x】标注处的请求体结构已为两种方案预留，答复后删除未选方案并更新 OpenAPI。

## 10. 变更记录

| 日期 | 变更 | 性质 |
|---|---|---|
| 2026-11-19 | 第 8 节补充具体错误码 40101、40102、42200、42901、50000、50003（原仅定义 401xx / 422xx 范围；42901、50000、50003 为新增） | 新增，向后兼容 |
| 2026-11-19 | 开户资料字段名以 `backend/api/openapi.yaml` 的 `ApplicationData` 为准（含 `residentialAddress{}`、`annualIncomeRange`、`netWorthRange`、`netWorthLiquidRange`、`investmentExperience`、`investmentObjective`、`riskTolerance`、`isAffiliatedBD` 等布尔字段，以及 `phone`、`language`、`usTaxPayer`、`irsBackup`、`taxTreaty`、`tinConfirm`、`affiliatedAck`、`pepCountry`、`pepRoles[]`、`controlCompanySymbol`）。原型 `prototype/` 中的字段名只属于已冻结的原型，Flutter 直接使用接口字段名，不做旧名转换 | 澄清，不改路径 |
| 2026-11-19 | `GET /application` 响应新增 `documents[]{documentId, docType, side, uploadedAt}`（已暂存证件，不含影像）；`data.tin` 读取时只返回后 4 位，客户端回传打码值视为未修改；`accountType/tradingType/accountManagementType` 由后端固定为 LIVE/CASH/SELF | 新增，向后兼容 |
| 2026-11-19 | `GET /application/status` 新增 `applicationRef`、`submittedAt`、`submitState`（NOT_SUBMITTED / SUBMITTING / SUBMITTED / NEEDS_ATTENTION）。kycStatus 只反映 DW 真实返回，DW User 创建前为 KYC_NOT_READY；`GET /account` 在账户未开立时返回 40901 | 新增，向后兼容 |
| 2026-11-19 | `ApplicationData` 新增 `industry`（DW EMPLOYMENT_INFO.type 枚举，受雇/自雇时必填）与 `position`（DW position 枚举，选填）；`occupation` 保留但不再发送给 DW（停用，后续版本删除需升版本）。选项见 pages.md 3.1.6 | 新增，向后兼容 |
| 2026-11-19 | 资金（Demo-1 #6）：`GET /account/money` 新增 `pendingDeposits`、`withheldForSeasoning`；`Transfer` 新增 `bankAccountId`，status 新增我方取值 `SUBMITTING`（已记录、提交结果待确认）；`GET /funding/transfers` 每页 50 条，下一页游标放在响应头 `X-Next-Cursor`；资金接口在账户冻结/关闭时返回 40301（附 restriction），账户未开立返回 40901；入金提交结果不明时返回 50001 并附 `transferId`；出金超过 DW 可提现金额返回 42201（附 limits.available）；`POST /funding/bank-accounts` 不接受客户端户名（后端写入开户姓名） | 新增，向后兼容 |
| 2026-11-19 | 沙盒实测（sandbox-log.md #7）：入金状态枚举新增 `PROCESSING`（DW 编号 17，文档未列出）；`Transfer` 新增 `buyingPowerAvailableAt`、`withdrawableAt`（来自 DW seasoningDetails）；`BankAccount` 新增 `nickname`（DW 绑卡响应不含银行名称） | 新增，向后兼容 |
| 2026-11-19 | 开户与 KYC 模块（`/application/*`，对应 P-03–P-06、P-30、P-34–P-36）的 `message` 与 `fields[].reason`、KYC 问题项 `userMessage` 改为英文（文案取自原型；行业/职位两条为新增），其余模块仍为中文（pages.md 定稿说明、ui-signoff 第 3 节） | 文案变更，字段与结构不变 |
| 2026-11-19 | 5.5 市场数据（F11）落地：`/market/quotes`、`/market/instruments/{symbol}` 写入 openapi.yaml；两接口**无需登录**（虚拟行情、不含用户信息，P-01"先逛逛行情"需未登录可看）；`/market/instruments` 响应新增 `exchange`、`type`；`chgPct` 为百分数；`symbols` 单次最多 50 个、未知代码忽略、为空返回全部；未知个股返回 42200 | 新增，向后兼容 |
| 2026-11-19 | 沙盒实测：`rule14b` 为 false（P-05 选"否"）时 DW 拒绝开户（U040），`GET /application/status` 将停在 KYC_APPROVED、accountStatus 为空。接口不变；处理方式待 Q-DW-11 与用户决定 | 记录，无接口变更 |
| 2026-11-20 | `GET /account` 新增可选字段 `dw{userId, accountId, accountNo, kycStatus, syncedAt}`：**仅演示环境**（`OTP_DEV_LOG=true`，config 禁止 production 开启）返回，供 App P-08"DW 沙盒凭证"区与 DW 当场对照；生产不返回 | 新增，向后兼容 |
| 2026-11-20 | 开户校验加固（`PUT /application/draft` 分步校验与 `POST /application/submit`）：美国地址 `residentialAddress.state` 须为 USPS 州代码或全称（沙盒 E032）；SSN 拦截 123-45-6789 与全同数字；美国 / NANP 电话区号与交换码不以 0、1 开头、全同数字拦截。均返回 42200 字段错误（英文文案），接口形状不变 | 校验收紧，向后兼容 |
| 2026-11-20 | 新增 5.6 交易（F14）：`POST /orders`、`GET /orders`、`GET /orders/{id}`、`POST /orders/{id}/cancel`、`GET /positions`，以及 `Order`、`Position`、`OrderStatus` 结构；只支持市价单（按金额或按股数）。用户已同意按向后兼容新增处理，不升 v2 | 新增，向后兼容 |
| 2026-11-20 | 新增 5.7 模拟交易 / 模拟盘（F15）：`/paper/account`、`/paper/account/reset`、`/paper/orders`、`/paper/orders/{id}`、`/paper/orders/{id}/cancel`、`/paper/positions`；结构与实盘 Order / Position 对齐并带 `simulated: true`；不调用 DW | 新增，向后兼容 |
| 2026-11-20 | 5.6 交易扩展限价单：`POST /orders` 的 `orderType` 新增 `LIMIT`，新增请求字段 `limitPrice`、`timeInForce`（只支持 DAY）；`Order` 新增 `limitPrice`、`timeInForce`。市价单行为不变 | 新增，向后兼容 |
| 2026-11-20 | 5.5 市场数据扩展（F11）：新增 `GET /market/sentiment`（恐慌贪婪指数 + 涨跌家数，`simulated: true`，无需登录）；P-09 指数卡新增 IWM（罗素 2000，复用 `/market/quotes`，标的池已含）。恐慌贪婪指数正式数据源待定（自行计算或采购，不得抓取第三方指数） | 新增，向后兼容 |
| 2026-11-20 | F17 资产分布与资产趋势：新增 `GET /account/allocation`、`GET /account/history?range=`、`GET /paper/account/allocation`、`GET /paper/account/history`（每日资产快照，迁移 000008 asset_snapshots）；新增结构 `Allocation`、`AssetHistory` | 新增，向后兼容 |
| 2026-11-20 | 新增 5.9 预测板块（F19，积分演示版）：`/predict/account`、`/predict/markets`、`/predict/markets/{id}`、`/predict/bets`（POST / GET）、`/predict/claim`；新增结构 PredictMarket、PredictBet、PredictStats；虚拟行情新增模拟加密标的 BTC、SOL | 新增，向后兼容 |
