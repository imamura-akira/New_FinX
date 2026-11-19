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
