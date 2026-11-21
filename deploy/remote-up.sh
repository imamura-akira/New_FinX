#!/usr/bin/env bash
# 服务器端执行（由 deploy.sh 以 setsid/nohup 后台启动，不依赖 SSH 会话）：构建 → 迁移 → 启动 → 健康检查。
# 日志：/opt/finx/deploy/last-deploy.log；结束时最后一行为 DEPLOY_OK <tag> 或 DEPLOY_FAIL <tag>。
#
#   ./remote-up.sh <IMAGE_TAG>
set -uo pipefail
cd "$(dirname "$0")"
TAG=${1:?usage: remote-up.sh <IMAGE_TAG>}
export IMAGE_TAG=$TAG

fail() { echo "DEPLOY_FAIL $TAG: $*"; exit 1; }

[[ -f ../backend/.env && -f .env ]] || fail "缺少配置，先运行 init-env.sh（见 deploy.md）"
BIND=$(grep -E '^BACKEND_BIND=' .env | cut -d= -f2-)
BIND=${BIND:-172.16.0.1:18082}

echo "==> build $TAG"
docker compose build migrate || fail "构建失败"

# 迁移前自动备份数据库（审计 OPS-P1-2）：数据库在运行时必须备份成功，否则中止部署；首次部署（数据库未运行）跳过
if [[ -n "$(docker compose ps -q postgres 2>/dev/null)" ]]; then
	BK_DIR=/opt/finx/backups
	mkdir -p "$BK_DIR" && chmod 700 "$BK_DIR"
	BK="$BK_DIR/finx-$(date -u +%Y%m%dT%H%M%SZ)-pre-deploy-$TAG.sql.gz"
	echo "==> backup $(basename "$BK")"
	(umask 077 && docker compose exec -T postgres pg_dump -U finx -d finx | gzip >"$BK") || { rm -f "$BK"; fail "部署前备份失败，已中止（未执行迁移）"; }
	gzip -t "$BK" && [[ $(gzip -dc "$BK" | head -c 4096 | wc -c) -gt 0 ]] || { rm -f "$BK"; fail "部署前备份文件校验失败，已中止（未执行迁移）"; }
else
	echo "==> backup skipped（postgres 未运行，视为首次部署）"
fi

echo "==> up"
docker compose up -d --remove-orphans postgres migrate backend || fail "启动失败（docker compose logs --tail 100 migrate backend）"
printf '%s %s\n' "$(date -u +%FT%TZ)" "$TAG" >>RELEASES
# 记录当前版本：之后在服务器上执行的 compose 命令（run / restart）默认使用该镜像；回滚时改这一行
sed -i '/^IMAGE_TAG=/d' .env && printf 'IMAGE_TAG=%s\n' "$TAG" >>.env

for _ in $(seq 1 30); do
	if curl -fsS "http://$BIND/healthz" >/dev/null 2>&1; then
		echo "DEPLOY_OK $TAG"
		exit 0
	fi
	sleep 2
done
fail "backend 60 秒内未就绪（docker compose logs --tail 100 backend migrate）"
