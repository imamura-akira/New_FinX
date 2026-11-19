# 开发进度（progress.md）

> 最近更新：2026-11-19（Demo-1 #5 完成）

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
| 9–12 | 见下方"剩余任务（2026-11-19 修订）" | 未开始 | — |

### 剩余任务（2026-11-19 修订：纳入 F11 虚拟行情、F12 账户余额、FinX 主题、开户模块英文化）

| # | 任务 | 依赖 | 规模 |
|---|---|---|---|
| 8b ✅ | **Flutter 换 FinX 主题**（design/theme.md：紫罗兰色、渐变主按钮、圆角 18/全圆角按钮、紫味投影）+ 品牌素材（logo、Fifi）入 Flutter assets；P-01 换为 FinX 品牌版式 | #8 | S |
| 8c ✅ | **后端开户模块文案英文化**：提交校验（validate.go）与开户相关接口的报错改为原型英文文案（P-03–P-06、P-30、P-34–P-36）；其余模块保持中文 | #3 | S |
| F11a ✅ | **F11 后端虚拟行情** `internal/marketsim`：随机游走（2s tick，σ 0.0008，均值回归，bid/ask ±1–2bp）、约 30 只标的固定种子、当日分时/日 K；`GET /market/quotes`、`GET /market/instruments/{symbol}`（`simulated: true`）；`MARKET_DATA_MODE=SIM|REAL`；openapi 同步 api-spec 5.5 | #1 | M |
| 9 | Flutter 开户流（**英文**，新版式：分段进度条、STEP X OF N、税号遮罩 Show/Hide、Save & exit + Continue）：P-03a–g、P-04、P-05、P-30 | 8b、8c | L |
| 10 | Flutter KYC 与账户：P-06（轮询）、P-34/35/36（入口标"待沙盒验证"）、P-08 抽屉；**F12**：P-07 资产卡与 P-08 接 `/account/money`（余额/购买力/可提现取 DW 返回值，未开户显示开户引导） | #4、#9 | M+ |
| F11b | **F11 Flutter 行情**：P-07 自选、P-09 市场列表、P-10 个股（仅展示，无下单）；轮询 3–5 秒，价格变动时涨跌色刷新 | F11a、#10（共用 P-07） | M |
| 11 | Flutter 资金流：P-31/32 绑卡、P-13 入金、P-14 出金、P-18 资金记录 | #6、#10 | L |
| 12 | 演示辅助：`cmd/demoreset`（含 marketsim 重置）、`design/demo-script.md`、真机说明 | 全部 | S |

DoD 对应：第 9 条（首页真实余额、入金后可见变化）→ #10 + #11；第 10 条（行情可见变动）→ F11a + F11b。

**恢复步骤**：按上表从 #9 开始（8b、8c、F11a 已完成）。用户要求任务间不停顿连续执行（停止条件见记忆 continuous-execution）。2026-11-23 之后另行补测出金（sandbox-log.md "待补测"）。
App 运行方式见 `app/README.md`。注意：项目在 iCloud 同步的桌面目录，`app/build` 是指向 `~/Library/Caches/finx-app-build` 的符号链接（否则 codesign 因 iCloud 扩展属性失败）；若误删，重建：`cd app && ln -s ~/Library/Caches/finx-app-build build`。
本地运行（演示模式 + 沙盒分析日志）：

```bash
cd "/Users/ak/Desktop/Claude FinX New/backend" && (set -a; source ./.env; set +a; DATABASE_URL='postgres://postgres:dev@127.0.0.1:55432/finx?sslmode=disable' OTP_DEV_LOG=true KYC_POLL_INTERVAL=10s DW_LOG_BODIES=true go run ./cmd/server)
```

---

## 1. 当前位置

- **里程碑**：M0 已完成，并已推送。
- **当前**：M1（节点 1，F1–F4）进行中。后端完成 F1 与 dwmapper；F2–F4 业务接口与 Flutter 还没开始。

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

确认临时数据库还在。电脑重启或 Docker 退出后容器会消失，需要重新起一个并迁移：

```bash
docker ps --filter name=finx-pg --format '{{.Names}}' | grep -q finx-pg || docker run -d --name finx-pg --restart unless-stopped -v finx-pgdata:/var/lib/postgresql/data -e POSTGRES_PASSWORD=dev -e POSTGRES_DB=finx -p 127.0.0.1:55432:5432 postgres:16-alpine
```

```bash
cd "/Users/ak/Desktop/Claude FinX New/backend" && (set -a; source ./.env; set +a; DATABASE_URL='postgres://postgres:dev@127.0.0.1:55432/finx?sslmode=disable' go run ./cmd/server -migrate up)
```

然后对 Claude Code 说："继续节点 1：写迁移 000002，再实现 application 包的草稿接口（GET /application、PUT /application/draft）及其单测"。

本地运行服务器时（`DATABASE_URL` 与 `OTP_DEV_LOG` 不写进 .env，在命令行传入）：

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
