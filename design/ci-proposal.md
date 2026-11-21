# CI 方案（审计 TEST-P1-3，待用户批准后启用）

> 现状：仓库没有 CI。11 个 PG 集成测试在本机没设 `TEST_DATABASE_URL` 时会静默跳过，实际上从未自动运行。
> 本方案**尚未启用**：批准后，把下方 YAML 原样保存为 `.github/workflows/ci.yml` 并提交即可生效。

## 1. 做什么

| Job | 运行内容 | 触发 |
|---|---|---|
| backend | `gofmt` 检查 → `go vet` → `go test -race ./...`（带 Postgres 16 服务容器，设置 `TEST_DATABASE_URL`，PG 集成测试必跑）→ `govulncheck ./...` | push 到 main、所有 PR |
| app | `flutter analyze` → `flutter test` | 同上 |

- **PG 测试不再静默跳过**：设置 `CI=true` 时，如果缺少 `TEST_DATABASE_URL`，PG 测试应改为失败。需要在 `store.TestDB` 一类的公共入口加一行判断，启用 CI 时一并修改。
- **不涉及任何凭据**：CI 不连接 DW，也不读取 .env；Postgres 使用服务容器的临时口令。
- **不做部署**：部署仍然手动执行 `deploy/deploy.sh`。

## 2. 成本与前提

- 仓库为私有：GitHub Free 每月有 2,000 分钟 Actions 额度。预计每次运行约 6–8 分钟（Flutter 安装与依赖缓存后约 4 分钟），按每天 5 次推送估算，每月约 1,000 分钟，在额度内。
- 版本固定：Go 1.27.4（与 go.mod 一致），Flutter 3.50.0 stable（与本机一致）。
- **启用前需要你确认**：
  1. 是否启用；
  2. 是否把 govulncheck 设为阻断（建议：阻断）；
  3. 是否给 main 加"CI 必须通过才能合并"的分支保护（目前直接推 main，建议先不加）。

## 3. 工作流（批准后保存为 `.github/workflows/ci.yml`）

```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  backend:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test
        ports: ["5432:5432"]
        options: >-
          --health-cmd "pg_isready -U test" --health-interval 2s --health-timeout 5s --health-retries 20
    env:
      CI: "true"
      TEST_DATABASE_URL: postgres://test:test@localhost:5432/test?sslmode=disable
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: "1.27.4"
          cache-dependency-path: backend/go.sum
      - name: gofmt
        run: test -z "$(gofmt -l .)" || (gofmt -l . && exit 1)
      - run: go vet ./...
      - run: go test -race -count=1 ./...
      - name: govulncheck
        run: go run golang.org/x/vuln/cmd/govulncheck@v1.10.0 ./...

  app:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: "3.50.0"
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

## 4. 启用后的收尾

- **PG 测试改为必跑**：`CI=true` 且缺少 `TEST_DATABASE_URL` 时 `t.Fatal`，不再跳过。
- **README 加 CI 徽章**（可选）。
- **审计文档登记**：TEST-P1-3 改为"已启用"。
