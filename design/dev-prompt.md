# 开发提示词（dev-prompt.md）— 逐节点复制给 Claude Code（Opus 4.5 / Opus 5.5）

> 用法：每个节点开始时，把对应一段完整复制给 Claude Code。规则已固化在根目录 `CLAUDE.md`，Claude Code 会自动读取，提示词里不再重复。
> 每段完成的标志：代码可运行、测试通过、已 push 到 GitHub。

---

## 节点 0：仓库初始化 + 后端骨架（M0）

```
请先读 CLAUDE.md 和 design/ 下的 prd.md、backend-design.md、api-spec.md，然后执行：

1. 初始化 git 仓库并推送基线：
   - git init，确认 .gitignore 生效（.env、design/reference/、.DS_Store 不入库）
   - 首次提交信息 "M0: 设计文档与原型基线"
   - git remote add origin https://github.com/imamura-akira/New_FinX.git
   - git push -u origin main（如远程已有 README 等文件，先 pull --rebase 合并）

2. 按 backend-design.md 第 2 节创建 backend/ 骨架：
   - Go module、目录结构、cmd/server 入口（health 接口可跑）
   - internal/config：第 7 节的全部配置开关 + .env.example（只放变量名）
   - internal/store：Postgres 连接 + 第 6 节 11 张表的首版 migration（用 golang-migrate）
   - internal/crypto：AES-256-GCM 字段级加解密（密钥来自环境变量）
   - internal/dwclient：token 获取与进程内缓存（POST /back-office/auth/tokens，
     请求头 dw-client-app-key；到期前刷新；全局限流约 5–10 次/小时）、
     统一的请求日志与脱敏；先配 httptest 单测，不打真实沙盒
   - api/openapi.yaml：按 design/api-spec.md 全量写出 v1 契约

3. 验收：go build ./... 与 go test ./... 通过；提交并 push，提交信息 "M0: 后端骨架 + DW token 客户端"。

注意：我稍后会提供 .env（DW 沙盒凭据），你不需要也不要向我索要凭据内容；
联调真实沙盒的步骤等我说开始再做。
```

---

## 节点 1：认证 + 开户提交 + KYC 状态（M1，F1–F4）

```
请读 design/api-spec.md 第 1、2 节和 design/pages.md 的 P-01–P-06、P-30、3.1 节，然后执行：

1. backend：实现 /auth/*（邮箱 OTP：开发态验证码打印到日志即可）、会话 JWT、/me。
2. backend：实现 /application 草稿保存与读取（data_enc 加密存储）、
   /application/submit 编排状态机（CREATED→PATCHED→DOCS_DONE，断点续传，
   见 backend-design.md 第 4 节）、/application/status。
   internal/dwmapper 按 pages.md 3.1.2 的表实现 App 字段 → DW documents 映射，并配单测。
3. app/：初始化 Flutter 工程（目录按 feature 分层），实现 P-01、P-02（邮箱 OTP）、
   P-03a–g、P-04、P-05、P-30、P-06，UI 以 prototype/ 对应页面为准；
   接口层按 openapi.yaml 生成或手写 client，后端未就绪的部分用本地 mock 切换。
4. 用 .env 中的沙盒凭据跑一次真实联调：创建一个测试 User（POST 四类 + PATCH 其余），
   把 kyc 状态返回记录到 design/sandbox-log.md（新建，记录日期、请求摘要、结论；不记凭据）。
   特别记录：首次 POST /users 是否直接返回 APPROVED（这回答 Q-DW-1 的 KYC 模式）。
5. 验收：PRD DoD 第 1–3 条中除 P-34/35/36 触发外全部可演示；
   测试通过后 push，提交信息 "M1: 认证 + 开户提交 + KYC 状态"。
```

---

## 节点 2：补救流程 + 开户（M2，F5–F6）

```
请读 design/pages.md 3.2 节（P-34–P-36）和 api-spec.md 第 2、3 节，然后执行：

1. backend：/application/remediate（PATCH /users 重跑 KYC）、/application/documents（证件上传转 POST /documents）、
   KYC_APPROVED 后自动 POST /accounts（LIVE/CASH/SELF，不带任何 RIA 字段）、/account 与 /account/money。
2. backend：events 包：SQS 消费（kyc 事件）+ 非终态轮询对账兜底（backend-design.md 第 5 节）。
   沙盒的事件配置如果还没有，先用轮询跑通，SQS 留接口。
3. app/：P-34、P-35、P-36、P-08 账户卡、S-01 受限状态。
4. 沙盒验证 P-34/35/36 的触发方式（dw-questions.md Q-DW-5；若无法触发，在 sandbox-log.md 记录并继续）。
5. 验收：KYC 通过后账户号码在 App 可见；push，提交信息 "M2: 补救流程 + 账户开立"。
```

---

## 节点 3：绑卡 + 出入金（M3，F7–F9）

```
请读 design/api-spec.md 第 4、5 节和 pages.md 3.1.5、P-13/P-14/P-31/P-32/P-33，然后执行：

1. backend：/funding/bank-accounts（按 config.bank_link_method，先实现 DIRECT 方案：
   POST /back-office/bank-accounts；PLAID 留接口返回"未开通"）、
   /funding/deposits（type=ACH）、/funding/deposit-instructions、
   /funding/withdrawals（redemptions；WIRE 收款人后端强制 = 开户姓名）、/funding/transfers。
   限额走 config.limits，可提现金额一律用 DW 返回值。
2. app/：P-31、P-32（按 DIRECT 方案的表单；Plaid 入口置灰）、P-13、P-33、P-14、P-18 资金时间线。
3. 沙盒跑通：绑卡 → ACH 入金到 SUCCESSFUL → 出金一笔；
   把 redemptions 实际字段、money summary 实际字段名回写 design/api-spec.md（登记变更）并记 sandbox-log.md。
4. 验收：PRD DoD 第 5–7 条可演示；push，提交信息 "M3: 绑卡与出入金"。
```

---

## 节点 4：通知 + 对账 + 全流程演练（M4，F10）

```
1. backend：/notifications、文件列表 /documents（沙盒有确认书/对账单就接，没有就返回空并记录）、
   audit_log 覆盖全部状态变更；补齐 dwclient 失败补偿队列。
2. app/：P-17 通知、P-15 文件。
3. 全流程演练 PRD 第 1 节 DoD 的 8 条，逐条在 design/sandbox-log.md 打钩，不通过的列原因。
4. push，提交信息 "M4: 通知与全流程演练"；然后给我一份差异清单：
   沙盒实测与 design/ 文档不一致的所有点，以及建议的文档修订。
```
