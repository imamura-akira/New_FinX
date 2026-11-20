# DW 沙盒实测记录（sandbox-log.md）

> 记录沙盒实测结果与 DW 文档的差异。只记录结论与请求摘要；不记录凭据、token、DW 用户/账户 id、账户号码、WLP ID 或合作方标识。
> 测试数据全部为虚构（姓名 Demo Tester、example.com 邮箱、555 电话号码、随机生成且结构合法的 SSN）。
> 调用路径：curl → 我方后端 `/api/v1/*` → `internal/dwclient` → DW 沙盒（与 App 实际路径一致）。

## 2026-11-19 · Demo-1 #5 · 开户（A）与 KYC（B）

### 运行记录

| 轮次 | 我方请求 | DW 结果 | 结论 / 处理 |
|---|---|---|---|
| 0 | `POST /auth/tokens` | 200，有效期 3600 秒；响应带请求 id 头 | token 缓存、请求 id 解析均正常 |
| 1 | `POST /users`（四类核心资料，SSN 用常见示例号码 123-45-6789） | **400 E032** "Invalid SSN provided" | DW 校验 SSN 有效性。我方已加 SSN 结构校验（区号不为 000/666/9xx、组号不为 00、序号不为 0000，并排除常见示例号码），提交前先拦截。申请按设计标记为需人工处理（NEEDS_ATTENTION），不自动重试 |
| 2 | `POST /users`（SSN 换为结构合法的随机号码） | **200**，用户创建成功 | 四类核心资料与后端生成的 username/password 均被接受 |
| 2 | `PATCH /users/{id}`（其余五类） | **400 U025** "Unrecognized funding source - EMPLOYMENT" | `fundingSources` 取值不对。按 DW 参考页更正（见下文"字段取值"） |
| 3 | `POST /users` → `PATCH /users/{id}` | 均 **200** | 九类资料全部被接受（包括 `irsBackupWithholdings`、`language`、`position`） |
| 3 | `GET /users/{id}/kyc-status` | 200，`status.name = APPROVED` | 见下文"KYC 模式（Q-DW-1）" |
| 3 | `GET /users/{id}/accounts` → `POST /accounts`（LIVE / CASH / SELF） | **400 U040** "Missing/Incomplete documents: EMPLOYMENT_INFO - Missing fields: [type]" | **开户需要 `EMPLOYMENT_INFO.type`（所属行业）**，但现有页面没有采集这一项 → 规格缺口，待决定（见末尾"需要决定"第 1 条） |

### KYC 模式（Q-DW-1）

- **沙盒在 `POST /users` 成功的同一毫秒自动通过 KYC**：`kyc.accepted.acceptedBy = "SYSTEM PRINCIPAL APPROVER"`，`kyc.accepted` 与 `kyc.approved` 的时间戳相同，用户 `status.name = APPROVED`（"User approved."）。
- 自动通过**发生在 PATCH 之前**：此时只提交了四类核心资料，披露（DISCLOSURES）、就业、投资者画像等都还没提交。
- `GET /users/{id}/kyc-status` 的实际响应**没有 `kyc.status`**，`kyc` 对象里只有 `accepted` 和 `approved`；状态只在顶层 `status.name`（User 对象的粗粒度状态：PENDING / APPROVED）。这与文档"以 `kyc.status.name` 为准"的描述不一致；文档自己的示例响应也没有这个字段。
- **结论**：沙盒的表现符合文档所说 No KYC / Verify KYC 模式的"提交即通过、无中间状态"。8 个细分状态在沙盒中观察不到，**P-34 / P-35 / P-36 无法通过正常流程触发**（Q-DW-5 仍待 DW 答复）。生产环境是否为 Do KYC 模式，仍需 DW 书面确认（Q-DW-1）。

**已据此调整的实现：**
- KYC 解析：优先读 `kyc.status.name`；没有这个字段时，顶层 `status.name = APPROVED` 视为 `KYC_APPROVED`。顶层 PENDING **不映射**为任何细分状态，保持原状态并写日志，避免显示 DW 没有返回的状态。
- **开户门槛**：必须同时满足 KYC 已通过、我方编排已完成（DOCS_DONE，即披露等资料已全部提交）、没有转人工，才会调用 `POST /accounts`。原因：沙盒在披露提交前就已通过 KYC。

### 字段取值（据此修正 `backend/internal/dwmapper/enums.go`）

| 字段 | 实测 / 参考页 | 处理 |
|---|---|---|
| `IDENTIFICATION_INFO.value`（SSN） | 无效 SSN 返回 E032 | 我方先做结构校验 |
| `IDENTIFICATION_INFO.type` | 参考页 userTaxIDType：SSN、EIN、FTIN、PASSPORT、ALIEN_ID、OTHER | 外国税号 → FTIN；国民身份号码 → OTHER；ITIN 没有对应值，暂按 SSN 发送（**待 DW 确认**） |
| `COMPLIANCE_AML_INFO.fundingSources` | "EMPLOYMENT" 被拒；参考页取值：EMP、GIFT、TRUST、INVESTMENT、SAVINGS、RETIRE、GAMBLING、LEGAL、FAMILY、UNEMP、ROLLOVER、RENT、SALE、INSURANCE | 工资 → EMP、储蓄 → SAVINGS、投资收益 → INVESTMENT、继承/赠与 → GIFT；"经营收入"暂映射 EMP；**"其他"没有对应值**（提交时提示重新选择）→ 见"需要决定"第 2 条 |
| `INVESTOR_PROFILE_INFO.investmentObjectives` | 参考页：LONG_TERM 等前四个已废弃；可用值包括 GROWTH、INCOME、CAPITAL_PRESERVATION、SPECULATION | 一一对应，不再全部映射为 LONG_TERM |
| `INVESTOR_PROFILE_INFO.annualIncome / networthTotal / networthLiquid` | 发送数值后，DW 存为区间（如 "$100,000 - $199,999"） | 现有"区间代表值"方案可用 |
| `INVESTOR_PROFILE_INFO.investmentExperience`、`riskTolerance` | YRS_3_5、MODERATE 被接受 | 不变 |
| `EMPLOYMENT_INFO.position` | 发送 "Engineer"，DW 存为枚举 "ENGINEER"；参考页为约 90 个固定枚举值 | 页面上职位是自由文本，大多数输入不会落在枚举里 → 见"需要决定"第 1 条 |
| `EMPLOYMENT_INFO.type` | **开户必填**（U040） | 页面未采集 → 见"需要决定"第 1 条 |
| `PERSONAL_INFO.politicallyExposedNames`、`EMPLOYMENT_INFO.directorOf` | 按文档示例，非 PEP、非董事时发送字符串 "NULL"；**DW 用户对象随后显示 `politicallyExposed: true`、`director: true`** | **数据错误，必须修正**：测试用户既不是 PEP 也不是董事。下一轮将对比"省略字段 / 空字符串 / JSON null"三种写法，确认哪一种会得到 false → 见"需要决定"第 3 条 |
| `PERSONAL_INFO.irsBackupWithholdings` | 被接受，回显为 false | 文档页未列出，但沙盒支持 |
| `BASIC_INFO.language`、`phone`（+14155550142）、国家三位代码（USA） | 均被接受 | 不变 |
| `TAX_INFO` | `POST /users` 响应中 DW 根据国籍自动生成 `{usTaxpayer: true, taxTreatyWithUS: false}` | 我方随 PATCH 发送的 TAX_INFO 也被接受 |
| Q-DW-4（username/password 由后端生成） | 后端生成的用户名（fx + 16 位）和 24 位密码被接受 | 沙盒可行，仍待 DW 书面确认 |
| Q-DW-3（POST + PATCH 两步） | 两步方案可行 | 一次性提交（SINGLE_POST）未测试 |

### 响应结构（供代码与 api-spec 对照）

- `POST /users` 返回 `id`、`status{name, description}`、`userType{name}`、`documents[]`（每项含 type、description、data）、`createdWhen`、`referralCode`，并回显 WLP 与合作方标识（本文不记录）。
- `PATCH /users/{id}` 返回扁平化的用户对象：`ackCustomerAgreement`、`ackMarketData`、`ackDisclosureRule14b`、`ackSignedBy`、`ackSignedWhen` 等披露留痕字段，以及 `employmentStatus{name}`、`investmentExperience{name}`、`fundingSources[]`、`politicallyExposed`、`director` 等。
- `GET /users/{id}/kyc-status` 返回 `userID`、`status{name, description}`、`kyc{accepted{acceptedBy, timestamp}, approved{approvedBy, timestamp}}`、`identity{number（打码）, dob}`、`accounts[]`、`documents[]`。
- `POST /accounts` 的错误结构为 `{errorCode, message}`，message 中带缺失字段明细。成功响应尚未拿到。

### 日志与安全

- 在 `DW_LOG_BODIES=true`（仅沙盒，production 禁止开启）下核对成功响应时，发现 DW 用户对象中有 `addressLine1`、`displayName`、`avatarURL`、`idNo`、`ackSignedBy`、`employerCompany` 几个字段不在原脱敏清单中，已补入 `dwclient` 脱敏规则并加了单测。

### 第 4 轮（2026-11-19，用户批准增加行业与职位下拉之后）

| 步骤 | 结果 |
|---|---|
| 写法实验（`cmd/dwprobe`，对第 3 轮测试用户反复 PATCH） | 发送字符串 `"NULL"` → DW 回显 `politicallyExposed=true`、`director=true`；发送空字符串 `""` → 两者均为 false（且能把已有的 true 改回 false）；JSON null 和省略字段在已为 false 时仍为 false。**结论：非 PEP / 非董事时发送空字符串**，dwmapper 已改 |
| 新测试用户：`POST /users` → `PATCH`（含 `type=PROFESSIONAL`、`position=ENGINEER`、空字符串写法） | 均 200；DW 用户对象 `politicallyExposed=false`、`director=false`、`employmentPosition=ENGINEER` |
| KYC | `POST /users` 后约 2 秒内对账得到 APPROVED（与第 3 轮相同：自动通过） |
| `GET /users/{id}/accounts` → `POST /accounts`（LIVE / CASH / SELF，无 RIA 字段） | **200，账户直接 OPEN**（没有 PENDING 阶段）；从提交到账户 OPEN 约 9 秒 |
| 第 3 轮测试用户 | 实验工具补上 `type` 后，对账器在剩余重试次数内自动开户成功，同样直接 OPEN |

**`POST /accounts` 成功响应结构**：`id`、`accountNo`（10 位）、`status{name: OPEN, description: Open}`、`accountType{name: LIVE}`、`tradingType{name: CASH}`、`accountMgmtType{name: SELF}`（注意字段名是 `accountMgmtType`，与请求中的 `accountManagementType` 不同）、`openedWhen`、`bod{}`（盘前余额，开户时为空）。
**Q-DW-7**：SELF 账户不发送任何 RIA 字段即可开户，沙盒已验证。

**结论：主线 A（开户）与 B（KYC → 自动开户 → 显示账户号）在沙盒中已端到端跑通。** 沙盒中现有 2 个已开户的虚构测试用户，可用于 #7 出入金实测，以及演示的后备用户。

### 需要决定（暂停点，2026-11-19 更新）

- 第 1 条（行业 / 职位）：**已决定并实施**——P-03e 增加"所属行业"（必填）与"职位"（选填）下拉，见 pages.md 3.1.6、ui-signoff.md 第 3 节。
- 第 3 条（PEP / 董事写法）：**已在沙盒验证**——发送空字符串；仍建议请 DW 书面确认。
- 第 2、4 条：仍待决定（见下）。

### 需要决定（第一次暂停时的原文）

1. **`EMPLOYMENT_INFO.type`（行业）开户必填，`position` 为固定枚举**，但 P-03e 没有"行业"字段，"职位"是自由文本。属于页面规格缺口（UI 已定稿，按规则需要你决定）。建议：在职或自雇时，P-03e 增加"所属行业"下拉（DW 的 19 个行业），"职位"改为下拉（DW 枚举）；在 ui-signoff.md 第 3 节登记变更。另一种做法是后端填默认值，但那样提交给券商的 KYC 资料就不是用户本人的回答，不建议。
2. **资金来源选项与 DW 不一一对应**："其他"没有对应值，"经营收入"只能近似映射为 EMP。建议把 P-03e 的选项改成 DW 的取值（工资、储蓄、投资收益、赠与/继承、退休金、家庭资助、出售资产、租金等），删除"其他"。
3. **PEP / 董事为"否"时 DW 被记为"是"**。下一轮先在沙盒对比三种写法；同时建议列入 DW 问题清单（Q-DW 新增），请 DW 书面确认非 PEP 时的正确写法。
4. **P-06 的细分 KYC 状态在沙盒中观察不到**。演示时 P-06 会在提交后几秒内直接显示"核验通过"，演示脚本需按此准备口径；P-34/35/36 页面按既定方案保留，入口标"待沙盒验证"。

## 2026-11-19 · Demo-1 #7 · 出入金（C）

> 使用 #5 中已开户的 2 个虚构测试用户；银行账号为虚构号码，路由号使用结构合法的公开 ABA 号码。

### 运行记录

| 步骤 | 我方请求 → DW | DW 结果 | 结论 |
|---|---|---|---|
| 资金汇总（入金前） | `GET /accounts/{id}/summary/money` | 200，各项为 0 | 字段名与参考页一致：`cash.cashBalance / cashAvailableForTrade / cashAvailableForWithdrawal / cashPendingSettlement`、`payments.buyingPower.*`、`payments.redemptions.amountWithheldFromRedemptions` |
| 绑卡（DIRECT） | `POST /bank-accounts`（账号、路由号、CHECKING/SAVINGS、昵称、`beneficiaryDetails.accountHolderName` = 开户姓名） | **201**，`status: ACTIVE`，返回 `bank_` 前缀 id；**不返回银行名称** | 无需微存款验证，立即可用。因 DW 不返回银行名称，`BankAccount` 新增 `nickname` 供显示 |
| ACH 入金 $1,000 | `POST /funding/deposits`（带 Idempotency-Key） | 200，`status: {id: 17, message: "Processing"}` | **状态 17 PROCESSING 不在 DW 文档枚举中**，已加入契约 |
| 入金状态 | `GET /funding/deposits/{id}` | 约 2 秒内 `Successful`；`statusHistory`：Started → Pending（"Auto-move"）→ Processing → Approved（"Payment successfully submitted"）→ Successful（"MMW Open. Moving to Successful"） | **沙盒入金自动批准、自动到账**，无需人工操作 |
| 资金可用时间 | 同上 `seasoningDetails` | `depositBuyingPowerHoldExpires` 与 `seasoningPeriodExpires` 均为 **2026-11-23**（提交日 2026-11-19，约 2 个工作日）；`statusMessage: AWAITING_BUYING_POWER` | 见下文"结算与观察期" |
| 资金汇总（入金后） | 同上 | `cashBalance 1000`、`cashAvailableForTrade 0`、`cashAvailableForWithdrawal 0`、`pendingDepositsAmountNotAvailable 1000`、`amountWithheldFromRedemptions 1000` | 余额立即变动；购买力与可提现在可用日之前为 0。`/account/money` 新增的 `pendingDeposits`、`withheldForSeasoning` 正好对应 |
| 出金 $10（ACH） | 我方先查 DW 可提现金额 | 可提现 $0 → 我方返回 **42201 "超过可提现金额 $0.00"**，未调用 DW | 后端强制校验按设计生效 |
| 电汇入金指引 | `GET /accounts/{id}/funding/deposit-instructions` | 200，返回收款行名称/地址/SWIFT、账号、路由号；收款人为 DriveWealth | 已映射到 `/funding/deposit-instructions`；附言（reference）= 账户号 + 开户姓名 |
| 后备用户 | 绑卡（SAVINGS）+ ACH 入金 $5,000 | 同样约 2 秒 Successful，可用日 2026-11-23 | 后备出金演示用户 |

### 结算与观察期（回答"沙盒是否加速"）

- **入金本身是加速的**：提交后约 2 秒即为 Successful，余额立即增加。
- **购买力与可提现不是即时的**：DW 为每笔入金返回明确的可用日（本次为提交后约 2 个工作日，2026-11-23），在此之前购买力与可提现均为 0。可提现等待期远短于文档默认的 30 天，说明合作方配置已调整（文档称可定制）。生产环境的取值仍待 DW 书面确认（Q-DW-8e）。
- **结论**：演示出金**仍需要后备用户**。本日已为两个测试用户入金（$1,000、$5,000），**自 2026-11-23 起可用于出金演示**。演示前请先用 `GET /account/money` 确认 `cashAvailableForWithdrawal > 0`。
- 建议：P-13 / P-14 / P-18 直接显示 DW 返回的日期（`Transfer.buyingPowerAvailableAt`、`withdrawableAt`），比"通常 4–5 个工作日（待 DW 确认）"更准确。文案调整属于页面变更，待你确认后再改。

### 待补测（2026-11-23 之后）

- `POST /funding/redemptions` 的成功响应结构与出金状态推进（ACH 与 WIRE）。出金的参考页未能读取，目前按文档示例实现。
- 出金后资金汇总的变化。
- `GET /funding/redemptions/{id}` 路径（入金对应路径 `GET /funding/deposits/{id}` 已实测可用）。

### 本轮修正

- 入金状态新增 `PROCESSING`（编号 17）；出金 `On_Hold` 统一为 `ON_HOLD`。
- 对账时保存 DW 返回的购买力可用日与可提现日（迁移 000004）。
- 时间输出统一为 UTC（之前随本机时区输出 +08:00，不符合 api-spec "时间一律 ISO-8601 UTC"）。
- 日志脱敏补充 `username`（绑卡响应回显后端生成的 DW 用户名）与 `account_number`。
- 集成测试隔离：迁移回滚测试改为在临时数据库中进行，避免与其他包并行的集成测试互相干扰。

## 2026-11-19 · Demo-1 #10 · App 端开户进度联调

用模拟器上的虚构美国测试用户（P-03 全部填完，P-05 中 Rule 14b-1(c) 选"否"）提交，App 首页与 P-06 显示 DW 真实返回状态。

| 步骤 | 结果 |
|---|---|
| `POST /users` → `PATCH /users`（5 类资料，含 DISCLOSURES） | 200；KYC 立即 `KYC_APPROVED` |
| `POST /accounts`（LIVE / CASH / SELF） | **400 U040**：`DISCLOSURES - Missing fields: [ rule14b ]`。我方已发送 `"rule14b": false` |

- **发现**：沙盒把 `rule14b: false` 当作"缺字段"，导致选"否"的用户无法开户；此前各轮测试均选"是"，所以未暴露。与 pages.md 3.1.4"选'否'不影响开户"的设计不符。已登记 **Q-DW-11**。
- **影响**：选"否"的用户停在"交易账户开立中"（后端最多重试 5 次）。演示用户需在 P-05 选"是"。
- **用户决定（2026-11-19）**：保持现状，不强制选"是"；演示用户在 P-05 选"是"。DW 回复 Q-DW-11 后再定正式处理。
- **对照**：另一虚构测试用户在 P-05 选"是"，提交后约 4 秒 KYC 通过并开户（OPEN）。至此确认是 `rule14b` 取值导致失败。
- **App 端联调结果**：首页（开户中）显示"交易账户开立中"；开户后首页资产卡、"资金数据来自 DriveWealth · 更新于"、P-08 账户号码与 LIVE · CASH · SELF 均为 DW 真实返回，金额 $0.00。P-06 的轮询与各分支由 widget test 覆盖。

## 2026-11-20 · 真机 TestFlight 提交失败（Ref FX261119-WSFNYEBJ）

- 现象：App 显示"发送给券商时出错，无需重复提交"（编排转人工，`submit_blocked`）。
- 原因：`POST /users` 返回 **400 E032**，`errorDetails.field = ADDRESS_INFO.province`，`detail = "Invalid US state"`（DW requestId `request_f7b273ae-cefa-4826-89b4-d5f7d76e4225_pas`）。P-03d 州字段为自由输入，前后端只校验非空，非 USPS 代码的取值被放行。DW 用户未创建（失败发生在第一步）。
- 修正：美国地址的州规范为 USPS 两位代码（接受代码或全称，大小写不限）；无法识别时 P-03d 与提交校验均返回 42200（英文提示）。同时加固 SSN（123-45-6789、全同数字）与电话（NANP 区号 / 交换码不以 0、1 开头，全同数字）校验。
- 处理：该测试账号已按用户要求用 `demoreset reset` 清除，重新注册后可再次提交。


## 2026-11-20 · 真机入金后余额仍为 0（排查）

- 现象：真机用户（1@example.com，账户 FETU000001）入金后，资产页余额为 $0.00，下拉刷新无变化。
- 我方记录：该账户 3 笔 ACH 入金（$10,000 / $5,000 / $6,000，提交于 2026-11-19 22:53、23:35 与 11-20 02:21 UTC），均已提交 DW 成功（有 DW 编号），状态 **APPROVED**；对账任务每分钟查询一次，DW 均返回 200。另一真机用户 FEJQ000001 的 $10,000 入金同样停在 APPROVED。
- DW 侧（`demoreset verify`，04:23 UTC）：`summary/money` 中 cash 0、buyingPower 0、withdrawable 0。
- DW 入金状态历史：Started → Pending → Processing → Approved（"Payment successfully submitted"）→ Approved（**"Awaiting money movement window to open."**）。
- **结论：属于 c) DW 侧确实为 0，不是 App 或后端 bug。** 沙盒入金在"资金划转窗口"开放时才从 Approved 进到 Successful 并入账。11-19 白天（美东 11:24）提交的 funded1/2 入金约 2 秒即 Successful；本次 3 笔都在美东收盘后（17:53、18:35、21:21 ET）提交，需等下一个窗口（美东工作日白天，具体时刻待实测）。
- 窗口开放后余额会自动更新（后端对账每分钟一次，App 下拉刷新即可）。购买力与可提现仍按 DW 返回的可用日（约 2 个工作日后）。
- 演示提示：入金演示请在美东工作时间进行，否则结果页显示"已提交"，但余额要等到下一个窗口。窗口具体开放时间待 11-20 美东白天观察后回写。

## 2026-11-20 · 资金划转窗口实测（美东 09:31 复查）

- 11-20 美东 00:50 提交的 $10 ACH 入金（funded1，沙盒虚构用户）：**DW 在 2026-11-20 09:01:04 UTC（美东 04:01、北京 17:01）开放资金划转窗口**，状态 Approved → **Successful**（"MMW Open. Moving to Successful"），现金 $1,000 → $1,010。
- 同时 DW 写入"Buying power withheld until 2026-11-23. Withdrawal power withheld until 2026-11-23"；`seasoningDetails.status = 6 AWAITING_BUYING_POWER`，`depositBuyingPowerHoldExpires` 与 `seasoningPeriodExpires` 均为 2026-11-23。资金汇总：购买力 0、可提现 0、`pendingDepositsAmountNotAvailable` 与 `amountWithheldFromRedemptions` 均 1,010。funded2 同样为现金 $5,000、购买力 0（等 11-23）。
- **修正此前假设**：窗口并非"美东工作日白天"才开，本次在美东凌晨 04:01 开放；入账（Successful）与购买力 / 可提现生效是两回事——入账后仍按 DW 返回日期（本次 11-23，周一）才可交易与提现。App 现状（在途入金 / 观察期内金额、按 DW 日期显示）与此一致，无需改动。
- 原始报文：dw-raw-samples.md 第 4 节。下单实测（T-1–T-13）仍须等 11-23 购买力生效。

## 2026-11-20 · F14 交易模块：未实测项与假设（11-23 实测后回写）

> 依据 DW 参考文档（Create Order / Retrieve Order / Update Order / List Account Positions / Errors / Idempotent requests，2026-11-20 查阅）。已入金测试用户的购买力 2026-11-23 生效，真实下单实测排在当天；今天只用 fake DW 单测。

| # | 未实测项 | 当前假设 / 实现 | 11-23 要验证 |
|---|---|---|---|
| T-1 | 下单请求 | `POST /orders`：`accountNo`、`orderType: MARKET`、`symbol`、`side: BUY/SELL`，`amountCash`（按金额）或 `quantity`（按股数）二选一（文档错误码 O015），附 `Idempotency-Key`（文档："All POST requests accept Idempotency keys"，保存 4 天） | 字段是否被接受；响应是 `orderId` 还是 `id`（后端两者都读） |
| T-2 | 成交速度 | 下单后立即 `GET /orders/{id}` 取一次状态；之后由对账任务（与资金对账同频）和查询接口刷新 | 沙盒市价单是即时 FILLED 还是先 NEW |
| T-3 | 交易时段 | 不区分盘前盘后，随时可提交；不传 `preventQueuing`（默认 false，休市订单排队到开盘）。开关 `TRADE_PREVENT_QUEUING` 预留 | 沙盒休市时市价单是排队（NEW）、即时成交还是拒绝 |
| T-4 | 碎股规则 | 按金额允许碎股；按股数最多 6 位小数；最低金额 $1（示例值，`LIMIT_MIN_ORDER`） | DW 实际最小金额 / 最小股数步长（错误码 I013 INSTRUMENT_INVALID_ORDER_SIZE）；不支持碎股的证券 |
| T-5 | 购买力不足 | 后端先查 `summary/money` 的 `cashAvailableForTrade`，超出直接 42201，不调用 DW；若 DW 仍拒绝（创建时 4xx 或订单 REJECTED），App 显示"券商未受理 / 已拒绝" | DW 购买力不足时是创建失败（错误码？）还是订单 REJECTED（statusMessage？） |
| T-6 | 可卖数量 | 卖出以 `summary/positions` 的 `availableForTradingQty` 为上限；按金额卖出上限 = 可卖数量 × `mktPrice` | 当日买入（未结算）的股票是否计入可卖数量；CASH 账户卖出未结算股票的限制（Good Faith Violation） |
| T-7 | 撤单 | `PATCH /orders/{id}` `{"method":"CANCEL"}`；仅 NEW / PARTIAL_FILL 可撤；之后以 DW 返回状态为准 | 撤单后状态是直接 CANCELED 还是先 PENDING_CANCEL |
| T-8 | 拒单原因 | 订单 REJECTED 时显示通用中文原因；DW `statusMessage` 只写日志与数据库（不透出原文） | 常见拒单原因与对应中文文案 |
| T-9 | 预估价格 | 按股数买入时用虚拟行情（F11）卖一价估算金额，用于购买力与最低金额校验 | 与 DW 实际成交价的差异是否导致边界情况被 DW 拒绝 |
| T-10 | 限价单请求（窗口期实测） | `orderType: LIMIT`、`quantity`、`price`（限价）、`timeInForce: "DAY"`（文档枚举含 DAY；缺省也为当日有效）；不支持按金额（amountCash）下限价单 | DW 是否接受显式 `DAY`；碎股限价单是否允许；限价小数位规则（$1 以上两位、以下四位） |
| T-11 | 限价单挂单（窗口期实测） | 未到价时状态 NEW，App 显示"挂单中"；对账任务与查询刷新 | 挂单期间 DW 是否冻结购买力（`cashAvailableForTrade` 是否下降）；休市时提交的限价单是否排队 |
| T-12 | 限价单撤单（窗口期实测） | `PATCH /orders/{id}` `{"method":"CANCEL"}`，同市价单 | 撤单后是否直接 CANCELED、购买力是否立即释放 |
| T-13 | 限价单成交与过期（窗口期实测） | 价格到达后 FILLED（可能 PARTIAL_FILL）；当日未成交由 DW 收盘撤销（状态以 DW 返回为准） | 沙盒是否真实撮合限价（还是即时成交 / 永不成交）；收盘后过期订单的状态与 statusMessage |

