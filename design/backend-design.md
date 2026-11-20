# 后端方案（backend-design.md）— Go 后端 v1

> 对应 PRD v1.0 与 api-spec.md v1。目标：第一阶段以最小架构打通 DW 沙盒全流程，同时把"待 DW 确认"项全部隔离在配置与适配层，答复后不动业务代码。

## 1. 总体架构

```
Flutter App ──HTTPS──▶ Go 后端（单体，模块化） ──HTTPS──▶ DW Back Office API（沙盒）
                         │  ▲
                         │  └── SQS 消费（kyc/deposits/bankAccounts 事件）
                         ▼
                      PostgreSQL（+ 对象存储：证件影像，加密）
```

- **第一阶段单体**（monolith, 模块化包结构），不拆微服务；DW 请求全部经 `dwclient` 包。
- App 不持有 DW 凭据、不直连 DW（pages.md 3.3.2）。

## 2. 目录结构（backend/）

```
cmd/server/            入口
api/openapi.yaml       契约（由 api-spec.md 生成，先行冻结）
internal/
  auth/                OTP、OAuth、会话（JWT，短时效 + 刷新）
  application/         开户草稿、提交编排、补救流程
  account/             账户与资金汇总
  funding/             银行账户、入金、出金
  notification/        站内通知
  dwclient/            DW HTTP 客户端（见第 3 节）
  dwmapper/            App 字段 ⇄ DW documents 映射（pages.md 3.1.2 为唯一依据）
  events/              SQS 消费者 + 对账轮询
  marketsim/           虚拟行情引擎（F11，阶段性）
  store/               Postgres 仓储；migrations/
  crypto/              PII 字段级加密（AES-256-GCM，密钥走 KMS/env）
  config/              全部开关与阈值
```

## 3. DW 客户端（dwclient）

- **鉴权**：`POST /back-office/auth/tokens`，请求头带 `dw-client-app-key`；token 进程内缓存并在到期前刷新；全局限流器约束 token 请求（预算约 5–10 次/小时）。凭据只从环境变量读取：`DW_APP_KEY / DW_CLIENT_ID / DW_CLIENT_SECRET / DW_BASE_URL`（沙盒 `https://bo-api.drivewealth.io/back-office`）。
- **可靠性**：超时 10s；幂等 GET 重试 3 次退避；写操作不自动重试（防重复入金），失败入待办队列人工/定时补偿。
- **审计**：每次调用记录 method、path、dw requestId、HTTP 码、耗时；请求体脱敏（SSN、账号打码）后留存。
- **接口清单（第一阶段）**：
  | 用途 | DW 接口 | 状态 |
  |---|---|---|
  | 创建用户 | `POST /users`（4 核心 documents） | 已核实 |
  | 补充/修改资料 | `PATCH /users/{userID}` | 已核实 |
  | 证件上传 | `POST /documents` | 待沙盒验证 |
  | KYC 状态 | `GET /users/{userID}/kyc-status` | 已核实（对账用） |
  | 开户 | `POST /accounts`（LIVE/CASH/SELF，不带 RIA 字段） | 已核实 |
  | 绑卡 | `POST /back-office/bank-accounts` | 已核实（方案 A）【Q-DW-2】 |
  | ACH 入金 | `POST /back-office/funding/deposits`（type=ACH） | 已核实 |
  | 电汇指引 | `GET /accounts/{id}/funding/deposit-instructions` | 待沙盒验证 |
  | 出金 | `POST /funding/redemptions`（ACH/WIRE） | 字段待核【Q-DW-8d】 |
  | 资金汇总 | 账户 money summary（cashAvailableForWithdrawal） | 字段待核【Q-DW-8d】 |

## 4. 开户提交编排（application）

```
POST /application/submit
 └─ 事务内落库（application → SUBMITTED, 生成 username/password【Q-DW-4】）
 └─ Step1: POST /users（BASIC/IDENTIFICATION/PERSONAL/ADDRESS_INFO）→ 存 dw_user_id
 └─ Step2: PATCH /users/{id}（EMPLOYMENT/INVESTOR_PROFILE/DISCLOSURES/TAX/COMPLIANCE_AML）【Q-DW-3 可合并】
 └─ Step3: 非美国用户 POST /documents（证件）
 └─ 任一步失败：记录断点，后台重试续传（编排状态机：CREATED→PATCHED→DOCS_DONE）
KYC_APPROVED 事件 → 自动 POST /accounts → 存 account_no → 通知
```

- KYC 模式按 **Do KYC** 实现【Q-DW-1】；`config.kyc_mode` 预留 `DO_KYC / PARTNER_KYC`，后者将禁用 P-34/P-35 分支并要求接入 KYC_VERIFICATION_INFO（本阶段不实现，只留开关与报错）。

## 5. 事件与对账（events）

- SQS 消费：`kyc.created / kyc.updated / deposits.* / bankAccounts.created`（事件名以 DW 配置为准，待沙盒验证）；幂等以事件 id 去重；更新本地状态并生成站内通知。
- 对账轮询（兜底）：非终态的 KYC 每 1 分钟、在途 transfer 每 5 分钟拉取 DW 对账；差异以 DW 为准并告警。
- App 侧只轮询我方 `/application/status`、`/funding/transfers`。

## 6. 数据模型（Postgres，首版）

| 表 | 关键字段 | 说明 |
|---|---|---|
| users_app | id, email, login_provider, email_is_relay, created_at | App 登录账户 |
| sessions | token_hash, user_id, expires_at | |
| applications | id, user_id, status, step, data_enc(jsonb 加密), application_ref, submitted_at | 草稿与提交 |
| dw_users | application_id, dw_user_id, dw_username_enc, dw_password_enc, kyc_status, kyc_updated_at | DW User 影子 |
| kyc_issues | dw_user_id, code, field, raw, user_message | P-34 数据源 |
| accounts | dw_user_id, dw_account_id, account_no, status, opened_at | LIVE/CASH/SELF |
| bank_accounts | account_id, dw_bank_account_id, bank_name, mask, type, owner_name, status | 账号全文不落库（只存 DW id + 尾号） |
| transfers | id, account_id, type(DEPOSIT/WITHDRAWAL), method(ACH/WIRE), amount, status, failure_reason, dw_ref, submitted_at, done_at | |
| documents_meta | dw_user_id, doc_type, side, object_key_enc, uploaded_at | 影像存对象存储，加密 |
| dw_events | event_id(唯一), type, payload, processed_at | 幂等去重 |
| audit_log | actor, action, target, at, detail | 状态变更审计 |

**PII 规则**：SSN/税号、证件影像、地址、出生日期 → 字段级加密（crypto 包）；日志与错误信息一律脱敏；保存期限与删除流程待法务（PRD 问题 15），表结构预留 `deleted_at` 软删。

## 6.5 虚拟行情引擎（marketsim，F11）

- 内存随机游走：每只股票以 `prevClose` 为锚，按固定 tick（默认 2s）更新 `last = last × (1 + N(0, σ))`，σ 默认 0.0008，日内围绕锚点均值回归，涨跌幅 = 相对 prevClose；bid/ask 按 last ± 1–2 bp 生成。
- 标的池取自演示自选与 P-09 列表（约 30 只，含 QQQ/SPY/DIA），进程启动时用固定种子初始化，`cmd/demoreset` 可重置。
- K 线：按 tick 聚合生成模拟分时与日 K，仅内存保留当日。
- 所有响应带 `simulated: true`；`config.market_data_mode: SIM | REAL`，REAL 为二期接真实行情源的挂载点，契约不变。
- 边界：虚拟行情只用于展示，不参与任何资金计算；账户余额、购买力、可提现一律来自 DW（见第 3 节），两者在 UI 上不混用。
- 市场情绪（2026-11-20，`internal/marketsim/sentiment.go`，`GET /market/sentiment`）：恐慌贪婪指数 = 0.3×涨跌家数分（50 + 50×(涨−跌)/总数）+ 0.3×平均涨跌幅分（50 + 25×均值%）+ 0.2×动量分（50 + 100×近 10 根分时均涨幅%）+ 0.2×波动分（50 − 100×(近 10 根分时平均振幅% − 0.55) − 5×VXX 涨跌幅%），各分量夹在 0–100；每个 tick 以 α=0.08 指数平滑，使指数缓慢变化。平均涨跌幅与动量不含 VXX；涨跌家数统计全部标的，|涨跌幅| < 0.10% 计平盘。恐慌贪婪指数正式数据源待定（自行计算或采购，不得抓取第三方指数）。

## 6.6 资产分布与每日资产快照（portfolio，F17）

- 包 `internal/portfolio`：`DWSource` 读 DW summary/money（cash.cashBalance）与 summary/positions（marketValue），`PaperSource` 读模拟账户（`papertrade.Service.Holdings`）；按 `marketsim.InstrumentType` 的 STOCK / ETF 归类，列表外代码按股票计。占比千分位最大余数法，合计 100.0。
- 表 `asset_snapshots`（迁移 000008）：主键 (user_id, mode REAL|PAPER, day 美东日期) 去重；`source` = CLOSE（收盘任务，覆盖当日记录）或 FIRST_REQUEST（当日首次请求兜底，仅在当日无记录时写入）。
- 收盘任务：每 5 分钟检查，美东 16:10 之后当日未完成时，为全部已开户用户（accounts.dw_account_id 非空且未关闭）与全部模拟账户记录 CLOSE 快照；部分失败下一轮重试。每个实盘用户 2 次 DW 调用。
- 边界：快照只用于趋势展示，不参与任何资金计算；`cmd/demoreset` 重置用户时一并删除其快照。

## 7. 配置开关（config，对应 ui-signoff.md 第 2 节）

```yaml
market_data_mode: SIM       # SIM | REAL（F11，二期接真实行情）
kyc_mode: DO_KYC            # Q-DW-1
bank_link_method: DIRECT    # DIRECT | PLAID   Q-DW-2
user_submit_mode: POST_PATCH # POST_PATCH | SINGLE_POST  Q-DW-3
seasoning_days: 30          # Q-DW-8e（展示用；可提现以 DW 返回为准）
limits: { min_deposit: 10, max_deposit: 50000, daily_deposit: 50000,
          min_withdrawal: 1, max_withdrawal: 50000, min_wire: 100, max_banks: 2,
          min_order: 1 }  # 示例值；min_order 为 F14 单笔最低下单金额（LIMIT_MIN_ORDER，以券商为准）
paper_initial_cash: 100000   # F15 模拟盘初始虚拟资金（PAPER_INITIAL_CASH，演示与练习用途）
trade_prevent_queuing: false # F14：DW preventQueuing，休市时是否拒单而非排队（待沙盒实测，TRADE_PREVENT_QUEUING）
```

## 8. 安全清单

- DW 凭据：仅环境变量；不进仓库、不进日志、不进 App（3.3.2 已约定）。
- 传输：全链路 TLS；App↔后端启用证书校验。
- 会话:短时效 JWT + 刷新；OTP 限频与防爆破。
- 出金强控：WIRE 收款人后端强制 = 开户姓名；金额与限额后端二次校验（不信任客户端）。
- 沙盒与生产配置完全隔离（不同 env 文件 / secrets）。

## 9. 沙盒测试计划（对应 PRD 里程碑）

| 里程碑 | 测试项 | 验证的 Q-DW |
|---|---|---|
| M0 | token 获取与缓存、限流 | — |
| M1 | POST /users + PATCH 两步；一次性提交对比试验 | Q-DW-3、Q-DW-4 |
| M1 | KYC 状态推进方式（看首次返回是否直接 APPROVED） | Q-DW-1 |
| M2 | 触发 INFO_REQUIRED / DOC_REQUIRED / DENIED | Q-DW-5 |
| M2 | POST /accounts 不带 RIA 字段 | Q-DW-7 |
| M3 | 绑卡（按 Q-DW-2 答复的方案）、ACH 入金、deposit-instructions | Q-DW-2 |
| M3 | redemptions 字段与状态、money summary 字段 | Q-DW-8d |
| M4 | SQS 事件名与 payload、对账一致性 | 事件配置 |

沙盒实测与文档不一致时：以沙盒为准，回写 pages.md / api-spec.md 变更记录。
