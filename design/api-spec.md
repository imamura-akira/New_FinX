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
