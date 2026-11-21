# 部署说明（deploy.md）— 后端沙盒演示部署

> 用途：把 Go 后端部署到 VPS，供 App 演示连接 DW **沙盒**。不是生产部署。
> 地址：`https://finxnew.akira.diy`（`/healthz`、`/api/v1/*`）。
> 本目录不含任何凭据；凭据只在服务器的 `/opt/finx/backend/.env`（权限 600，不进 git）。

## 1. 结构

| 组件 | 说明 |
|---|---|
| `postgres`（postgres:16-alpine） | 只接内部网络（`internal: true`），不映射任何端口；数据卷 `finxnew-pgdata` |
| `migrate` | 一次性服务：`server -migrate up`，成功后才启动 backend |
| `backend`（`finxnew-backend:<git sha>`） | distroless 静态镜像，非 root；只绑定 `172.16.0.1:18082`（docker0 网关，公网不可直接访问） |
| HTTPS | 当前 VPS 的 80/443 由其他项目占用。443 上的**共用 Caddy**（`/opt/elefenjoy-hostinger-demo`）按 `caddy-site.snippet` 反代到 `host.docker.internal:18082`，证书用 TLS-ALPN 自动签发 |
| `caddy`（profile `standalone`） | 仅在独立服务器上使用：`docker compose --profile standalone up -d`，配置见 `Caddyfile` |

服务器路径：

```text
/opt/finx/backend/            代码（rsync）+ .env（凭据，600）+ demo-users.local.json（600）
/opt/finx/deploy/             compose、脚本 + .env（POSTGRES_PASSWORD，600）+ RELEASES（部署记录）
```

防火墙：不启用 ufw（VPS 上的其他服务依赖 8443、8795、Tailscale；Docker 发布的端口本身也会绕过 ufw）。本项目不新增任何公网端口。

## 2. 首次部署

1. 同步代码：在仓库根目录运行 `deploy/deploy.sh`。首次运行时，服务器还没有配置，脚本会在同步代码后报"缺少配置"并退出，这是预期行为。
2. 上传凭据（只复制，不查看内容）：

```bash
scp backend/.env root@72.60.104.228:/opt/finx/backend/.env
```

```bash
scp backend/demo-users.local.json root@72.60.104.228:/opt/finx/backend/demo-users.local.json
```

3. 在服务器上补齐配置（生成数据库密码，写入 DATABASE_URL、OTP_DEV_LOG、登录白名单；不打印任何值）：

```bash
ssh root@72.60.104.228 "cd /opt/finx/deploy && ALLOWED_EMAILS='@example.com,...' ./init-env.sh"
```

4. 再运行一次 `deploy/deploy.sh`：构建镜像 → 迁移 → 启动 backend → 本机健康检查。
5. 接入共用 Caddy（一次性；会重启共用 Caddy，同机其他站点中断约数秒）：

```bash
ssh root@72.60.104.228 'cd /opt/elefenjoy-hostinger-demo && cp Caddyfile.https Caddyfile.https.bak-$(date +%Y%m%d-%H%M%S) && cat /opt/finx/deploy/caddy-site.snippet >> Caddyfile.https && docker run --rm -v "$PWD/Caddyfile.https:/etc/caddy/Caddyfile:ro" caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile && docker compose -f compose.https.yaml restart web'
```

   该 Caddy 的全局配置为 `admin off`，不能热重载，只能重启容器。校验失败时不会重启。

6. 验证：

```bash
curl -s https://finxnew.akira.diy/healthz
```

应看到 `"db":"ok"`、`"dw":"configured"`。本机若开着代理（fake-IP 模式），请让该域名直连。

## 3. 日常部署

```bash
deploy/deploy.sh
```

服务器端的构建与启动由 `remote-up.sh` 在后台执行（日志 `/opt/finx/deploy/last-deploy.log`，SSH 断开也不会中断），本机轮询直到成功或失败。脚本只同步 `backend/` 与 `deploy/`，不会覆盖或删除服务器上的 `.env`、`*.local.json`、`RELEASES`。镜像标签为 git 短提交号（有未提交改动时加 `-dirty`），每次部署追加一行到 `/opt/finx/deploy/RELEASES`。

## 3.1 数据库备份（审计 OPS-P1-1 / OPS-P1-2）

- **部署前自动备份**：`remote-up.sh` 在构建之后、迁移之前执行 `pg_dump`，生成 `/opt/finx/backups/finx-<UTC时间>-pre-deploy-<版本>.sql.gz`（目录 700、文件 600），并校验 gzip 完整且非空。**备份失败即中止部署（DEPLOY_FAIL），不执行迁移**。首次部署时数据库尚未运行，跳过备份。
- **每日备份**：`/etc/cron.d/finx-backup` 每天 03:17 UTC 运行 `deploy/backup.sh`，生成 `/opt/finx/backups/daily/finx-YYYYmmdd.sql.gz`，本机保留 7 天。日志写入 `/var/log/finx-backup.log`（logrotate 每周轮转，保留 8 份），成功行为 `BACKUP_OK`，失败行为 `BACKUP_FAIL`。
- **异地副本**：方案待定（见 design/audit-20261121.md 的 OPS-P1-1）。目前备份与数据库在同一台机器上。
- **恢复**：用同版本 postgres 镜像起一个临时容器，执行 `gunzip -c <备份> | psql -v ON_ERROR_STOP=1`，核对后再切换。2026-11-21 已演练一次，21 张表全部恢复。

## 4. 回滚

查看历史版本：

```bash
ssh root@72.60.104.228 'cat /opt/finx/deploy/RELEASES; docker image ls finxnew-backend'
```

当前版本记录在 `/opt/finx/deploy/.env` 的 `IMAGE_TAG`（每次部署成功后自动更新），服务器上的 compose 命令默认使用它。切回上一个镜像（不重新构建）：

```bash
ssh root@72.60.104.228 'cd /opt/finx/deploy && sed -i "/^IMAGE_TAG=/d" .env && echo IMAGE_TAG=<旧标签> >> .env && docker compose up -d --no-build backend'
```

- 数据库迁移只前进，回滚镜像不会回滚表结构；如新版本带了迁移且需要撤销，先评估后再用 `docker compose run --rm migrate -migrate down`（每次回退一步）。
- 撤销 Caddy 接入：用第 2 节第 5 步产生的 `Caddyfile.https.bak-*` 覆盖回去，再重启 `web`。
- 完全下线：`docker compose down`（保留数据卷）；连数据一起删除需加 `-v`（不可恢复）。

## 5. 演示数据

在服务器上恢复两个已入金测试用户的本地关联（只读 DW，写本地数据库）：

```bash
ssh root@72.60.104.228 'cd /opt/finx/deploy && for u in funded-1000 funded-5000; do docker compose run --rm --no-deps --user 0 -v /opt/finx/backend/demo-users.local.json:/app/demo-users.local.json:ro --entrypoint /app/demoreset backend import -local $u; done'
```

演示验真（直接读 DW 沙盒，原样打印编号与状态，与 App"DW 沙盒凭证"对照）：

```bash
ssh root@72.60.104.228 'cd /opt/finx/deploy && docker compose run --rm --no-deps --entrypoint /app/demoreset backend verify -email funded1@example.com'
```

其他命令（`list`、`reset -email X [-yes]`）同理，把参数换掉即可，用法见 `backend/cmd/demoreset/main.go`。每次 `import` / `verify` 会申请一次 DW token（每小时上限 6 次，与运行中的服务共用预算），不要连续频繁执行。

## 6. App 连接

```bash
flutter run --dart-define=API_BASE_URL=https://finxnew.akira.diy/api/v1 --dart-define=DEMO_MODE=true
```

登录邮箱须在服务器 `ALLOWED_EMAILS` 白名单内；演示验证码仍为 000000（`OTP_FIXED_CODE=true`；未设置时沿用 `OTP_DEV_LOG`）。**仅演示环境，生产禁止，接入邮件服务后移除**；同一邮箱 + IP 每小时最多请求 5 次验证码，超限拒绝并记日志。

## 7. 安全要点

- 仅沙盒：`APP_ENV` 必须为 sandbox（config 在 production 下禁止 `OTP_DEV_LOG` 与 `OTP_FIXED_CODE`）。
- 登录白名单（`ALLOWED_EMAILS`）防止公网任意邮箱用演示验证码登录；名单外邮箱返回与格式错误相同的提示。
- 日志：`docker compose logs` 不含 PII（dwclient 已脱敏）；不要开启 `DW_LOG_BODIES`。
- 数据库只在内部网络；backend 端口只在 docker0 网关上，外部只能经 HTTPS 访问。
