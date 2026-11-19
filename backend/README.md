# 后端（Go）

结构与约定见 `design/backend-design.md`；接口契约见 `api/openapi.yaml`（与 `design/api-spec.md` v1 同步）。

## 运行

```bash
cp .env.example .env          # 填写变量值；.env 不得入库
set -a; source .env; set +a   # 程序只读环境变量，不读 .env 文件
go run ./cmd/server           # GET http://localhost:8080/healthz
go run ./cmd/server -migrate up   # 需要 DATABASE_URL（PostgreSQL 13+）
```

未配置 `DATABASE_URL` 或 DW 凭据时服务仍可启动，`/healthz` 会分别报告 `not_configured`。启动时不会向 DW 申请 token（节省每小时 token 预算）。

## 测试

```bash
go build ./... && go vet ./... && go test ./...
TEST_DATABASE_URL=postgres://... go test ./internal/store/   # 可选：在真实 Postgres 上跑迁移 up/down
```

`internal/dwclient` 的测试全部使用 httptest 模拟 DW，不访问真实沙盒。

## 已实现（M0）

| 包 | 内容 |
|---|---|
| `cmd/server` | 入口、`GET /healthz`、优雅退出、`-migrate up/down` |
| `internal/config` | 第 7 节全部开关（`KYC_MODE`、`BANK_LINK_METHOD`、`USER_SUBMIT_MODE`、`SEASONING_DAYS`、`SEASONING_START`、`LIMIT_*`）与 DW 客户端参数，带校验 |
| `internal/store` | Postgres 连接（pgx）、golang-migrate 内嵌迁移，首版 11 张表 |
| `internal/crypto` | AES-256-GCM 字段级加解密，支持 AAD 绑定行与列 |
| `internal/dwclient` | token 获取与进程内缓存、到期前刷新、每小时预算限流、401 自动重新鉴权、GET 退避重试、写操作不重试、审计日志与脱敏 |
| `api/openapi.yaml` | v1 契约全量（23 个接口） |

其余包（auth、application、account、funding、notification、dwmapper、events）目前只有占位，按里程碑 M1–M4 实现。

## 凭据自检

```bash
set -a; source .env; set +a; go run ./cmd/dwcheck   # 申请一次 token，只报告结果；消耗 1 次每小时 token 预算
```

## 沙盒已验证（2026-11-19）

- `POST /auth/tokens` 返回 200，现有 token 响应解析可用，有效期 3600 秒
- 响应带请求 id 头（已能被现有兼容逻辑读取）
- `DW_BASE_URL` 只填基础地址 `https://bo-api.drivewealth.io/back-office`；误填含 `/auth/tokens` 的完整路径会被 API 网关以 403 "Missing Authentication Token" 拒绝（配置校验已拦截）
