# 开发进度（progress.md）

> 最近更新：2026-11-19（暂停点）

## 1. 当前位置

- **里程碑**：M0 已完成，并已推送（`5108696`、`769397c`）。
- **当前**：M1（节点 1，F1–F4）进行中，后端部分约完成三分之一。

## 2. 已完成

| 编号 | 内容 | 位置 | 状态 |
|---|---|---|---|
| M0 | 后端骨架、config、store（11 张表）、crypto、dwclient（token 缓存/限流/脱敏）、openapi.yaml | `backend/` | 已提交 |
| M0 | 迁移已在真实 Postgres 16（Docker 临时容器）上验证 up/down 与约束 | — | 已验证 |
| 沙盒 | DW token 接口真实调用返回 200，有效期 3600 秒；凭据正确 | `backend/cmd/dwcheck` | 已验证 |
| — | 配置：`DW_BASE_URL` 误填 `/auth/tokens` 时报错；新增 `JWT_SECRET`、`SESSION_TTL`、`OTP_DEV_LOG`（production 禁止开启） | `backend/internal/config` | 有单测 |
| — | 统一响应包装与错误码、请求解析、鉴权 context | `backend/internal/httpx` | 已完成 |
| F1 | 邮箱 OTP（6 位、5 分钟有效、60 秒重发、每邮箱每小时 5 次、每 IP 每小时 20 次、错 5 次作废、一次性）、HS256 会话 JWT（库中只存哈希，可注销）、`/auth/otp/request`、`/auth/otp/verify`、`/auth/logout`、`/me`；`/auth/oauth` 返回 50003"暂未开通" | `backend/internal/auth` | 有表驱动单测，**尚未挂到服务器路由** |
| 环境 | Flutter 3.50.0 已安装到 `~/development/flutter`（PATH 已写入 `~/.zshrc`）；Go 1.27.4；Docker Desktop | — | — |

## 3. 做到一半 / 未开始

| 事项 | 位置 | 状态 |
|---|---|---|
| F1 路由挂载 | `backend/cmd/server/main.go`（有 TODO 注释） | 未做：服务器启动后还不能调用 `/api/v1/*` |
| F2/F3 dwmapper（App 字段 → DW documents） | `backend/internal/dwmapper/`（目前只有 doc.go） | 未开始。设计已定：字段名用 openapi `ApplicationData`；DW 枚举集中在一个 enums.go，全部标"待沙盒验证" |
| F2 草稿保存/读取（data_enc 加密） | `backend/internal/application/` | 未开始 |
| F3 提交编排（CREATED→PATCHED→DOCS_DONE、断点续传、后台重试） | 同上 | 未开始。需要迁移 000002：`dw_users.dw_user_id` 改为可空（先存生成的 username/password 再调 POST /users，防止重复创建）、`applications` 加重试字段、新增 `application_documents` 表（提交前暂存证件） |
| F4 `/application/status` + KYC 状态对账轮询 | `backend/internal/application/`、`internal/events/` | 未开始 |
| Flutter 工程 `app/`（P-01–P-06、P-30） | — | 未开始 |
| 沙盒创建测试 User、`design/sandbox-log.md` | — | 未开始 |

## 4. 下次恢复的第一步

```bash
cd "/Users/ak/Desktop/Claude FinX New/backend" && go build ./... && go test ./...
```

通过后对 Claude Code 说："继续节点 1：先挂载 auth 路由（main.go 的 TODO），然后写 dwmapper 及其单测"。

本地联调还需在 `backend/.env` 里补两项，并临时起一个数据库：
- `PII_ENCRYPTION_KEY`：用 `openssl rand -base64 32` 生成
- `JWT_SECRET`：用 `openssl rand -base64 48` 生成
- 临时数据库：`docker run -d --rm --name finx-pg -e POSTGRES_PASSWORD=dev -e POSTGRES_DB=finx -p 127.0.0.1:55432:5432 postgres:16-alpine`，对应 `DATABASE_URL=postgres://postgres:dev@127.0.0.1:55432/finx?sslmode=disable`

## 5. 需要你决定的事项

1. **错误码补充**：api-spec.md 第 8 节只定义了范围。代码中暂用下列具体码，均属新增，不破坏现有契约。确认后我会同步写入 api-spec.md 和 openapi.yaml：
   - 40101：未登录 / token 无效
   - 40102：会话过期或已注销
   - 42200：字段校验失败
   - 42901：请求过于频繁（HTTP 429）
   - 50000：服务器内部错误
   - 50003：功能暂未开通（HTTP 501）
2. **开户字段名**：api-spec 要求与 pages.md P-03 一致，但原型（UI 定稿）用的是另一套名字，例如 `netWorth` / `pages.md: netWorthRange`、扁平地址 / `residentialAddress{}`。另外原型还有几个字段 pages.md 里没有：`phone`、`language`、`netWorthLiquid`、`usTaxPayer`、`irsBackup`、`taxTreaty`、`tinConfirm`、`affiliatedAck`。计划：接口一律用 openapi.yaml `ApplicationData` 里已写的名字（这些字段都已包含），Flutter 端负责转换；同时在 api-spec.md 变更记录里登记。
3. **会话有效期**：契约没有刷新接口，暂定 24 小时后需要重新用验证码登录。是否需要新增刷新接口（属于新增，不破坏现有契约）？
4. **邮件服务**：目前验证码只能在 `OTP_DEV_LOG=true` 时打印到日志。正式发送需要选定邮件服务商（如 SES），未接入前生产环境无法登录。
5. **DW 枚举取值**（投资经验、风险承受、投资目标、资金来源、税号类型等）：DW 文档没给全，dwmapper 会先用最可能的取值，沙盒创建 User 时按报错修正，然后回写 pages.md 3.1.2。
6. **token 额度**：本小时已用 3 次 token 请求，上限是 6 次（`DW_TOKEN_REQUESTS_PER_HOUR`）。日常运行时 token 会缓存 1 小时，不影响使用。
