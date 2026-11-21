#!/usr/bin/env bash
# 在服务器上运行：为部署补齐配置（只写入，不打印任何值）。可重复运行，已有的数据库密码不会变。
#
#   cd /opt/finx/deploy && ALLOWED_EMAILS='@example.com,...' ./init-env.sh
#
# - deploy/.env：生成 POSTGRES_PASSWORD（若不存在）。
# - ../backend/.env：写入 compose 内的 DATABASE_URL、OTP_DEV_LOG=true，以及 ALLOWED_EMAILS（若提供）。
#   同名键先删除再追加，保证只有一行。
set -euo pipefail
cd "$(dirname "$0")"
umask 077

APP_ENV_FILE=../backend/.env
[[ -f "$APP_ENV_FILE" ]] || { echo "缺少 $APP_ENV_FILE（先从本机 scp 过来）" >&2; exit 1; }

set_kv() { # set_kv FILE KEY VALUE
	local file=$1 key=$2 val=$3
	touch "$file"
	sed -i "/^${key}=/d" "$file"
	printf '%s=%s\n' "$key" "$val" >>"$file"
}

if [[ ! -f .env ]] || ! grep -q '^POSTGRES_PASSWORD=' .env; then
	set_kv .env POSTGRES_PASSWORD "$(openssl rand -hex 24)"
	echo "已生成数据库密码（deploy/.env）"
fi
pw=$(grep '^POSTGRES_PASSWORD=' .env | head -1 | cut -d= -f2-)

set_kv "$APP_ENV_FILE" DATABASE_URL "postgres://finx:${pw}@postgres:5432/finx?sslmode=disable"
set_kv "$APP_ENV_FILE" OTP_DEV_LOG true
# 固定验证码 000000：仅演示环境，生产禁止，接入邮件服务后移除（审计 SEC-P0-1，用户已知悉并接受）
set_kv "$APP_ENV_FILE" OTP_FIXED_CODE true
if [[ -n "${ALLOWED_EMAILS:-}" ]]; then
	set_kv "$APP_ENV_FILE" ALLOWED_EMAILS "$ALLOWED_EMAILS"
fi
chmod 600 .env "$APP_ENV_FILE"
echo "已写入 backend/.env：DATABASE_URL、OTP_DEV_LOG、OTP_FIXED_CODE$([[ -n "${ALLOWED_EMAILS:-}" ]] && echo '、ALLOWED_EMAILS')"
