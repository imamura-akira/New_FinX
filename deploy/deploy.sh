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

# 复用同一条 SSH 连接：服务器对短时间内的多个新连接会断开（sshd 限流）
CTL="/tmp/finx-deploy-%C"
SSH_OPTS=(-o ControlMaster=auto -o ControlPath="$CTL" -o ControlPersist=120 -o ServerAliveInterval=15)
ssh() { command ssh "${SSH_OPTS[@]}" "$@"; }
export RSYNC_RSH="ssh ${SSH_OPTS[*]}"

ssh "$HOST" "mkdir -p '$DIR/backend' '$DIR/deploy'"
RSYNC_EXCLUDES=(--include '.env.example' --exclude '.env' --exclude '.env.*' --exclude '*.local.json' --exclude 'RELEASES' --exclude '.DS_Store')
rsync -az --delete "${RSYNC_EXCLUDES[@]}" backend/ "$HOST:$DIR/backend/"
rsync -az --delete "${RSYNC_EXCLUDES[@]}" deploy/ "$HOST:$DIR/deploy/"

# 服务器端步骤脱离 SSH 会话在后台执行（会话断开也不会中断构建），本机轮询结果
ssh "$HOST" "cd '$DIR/deploy' && chmod +x remote-up.sh init-env.sh && setsid nohup ./remote-up.sh '$TAG' > last-deploy.log 2>&1 < /dev/null &"
echo "==> 服务器开始构建与启动（日志 $DIR/deploy/last-deploy.log）"
for _ in $(seq 1 120); do
	sleep 5
	last=$(ssh "$HOST" "tail -n 1 '$DIR/deploy/last-deploy.log'" 2>/dev/null || true)
	case "$last" in
	DEPLOY_OK*) echo "==> 部署成功：$TAG"; exit 0 ;;
	DEPLOY_FAIL*) echo "$last" >&2; ssh "$HOST" "tail -n 30 '$DIR/deploy/last-deploy.log'" >&2; exit 1 ;;
	esac
done
echo "10 分钟内未完成，查看：ssh $HOST tail -f $DIR/deploy/last-deploy.log" >&2
exit 1
