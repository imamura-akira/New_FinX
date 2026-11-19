#!/usr/bin/env bash
# 本机执行：同步代码到服务器并构建、启动（沙盒演示部署）。
#
#   deploy/deploy.sh                 # 部署当前提交
#   DEPLOY_HOST=root@1.2.3.4 deploy/deploy.sh
#
# 只同步 backend/ 与 deploy/；不同步、也不会覆盖或删除服务器上的 .env 与 *.local.json。
# 镜像以 git 短提交号打标签（有未提交改动时加 -dirty），旧镜像保留用于回滚（见 deploy.md）。
set -euo pipefail

HOST=${DEPLOY_HOST:-root@72.60.104.228}
DIR=${DEPLOY_DIR:-/opt/finx}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

TAG=$(git rev-parse --short HEAD)
git diff --quiet HEAD -- backend deploy || TAG="${TAG}-dirty"
echo "==> 部署 $TAG 到 $HOST:$DIR"

ssh "$HOST" "mkdir -p '$DIR/backend' '$DIR/deploy'"
RSYNC_EXCLUDES=(--include '.env.example' --exclude '.env' --exclude '.env.*' --exclude '*.local.json' --exclude 'RELEASES' --exclude '.DS_Store')
rsync -az --delete "${RSYNC_EXCLUDES[@]}" backend/ "$HOST:$DIR/backend/"
rsync -az --delete "${RSYNC_EXCLUDES[@]}" deploy/ "$HOST:$DIR/deploy/"

ssh "$HOST" bash -s -- "$DIR" "$TAG" <<'REMOTE'
set -euo pipefail
DIR=$1 TAG=$2
cd "$DIR/deploy"
[[ -f ../backend/.env && -f .env ]] || { echo "服务器缺少配置，先运行 init-env.sh（见 deploy.md）" >&2; exit 1; }
export IMAGE_TAG=$TAG
docker compose build migrate
docker compose up -d --remove-orphans postgres migrate backend
printf '%s %s\n' "$(date -u +%FT%TZ)" "$TAG" >> RELEASES
for i in $(seq 1 30); do
	if curl -fsS "http://${BACKEND_BIND:-172.16.0.1:18082}/healthz" >/dev/null 2>&1; then echo "==> backend 健康检查通过（$TAG）"; exit 0; fi
	sleep 2
done
echo "backend 60 秒内未就绪，查看：docker compose logs --tail 100 backend migrate" >&2
exit 1
REMOTE
