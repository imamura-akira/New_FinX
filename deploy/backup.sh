#!/usr/bin/env bash
# 每日定时备份（审计 OPS-P1-1）：由 /etc/cron.d/finx-backup 每天调用一次。
#   - pg_dump 压缩到 /opt/finx/backups/daily/finx-YYYYmmdd.sql.gz（目录 700、文件 600）
#   - 校验 gzip 完整且非空；失败写日志并以非零退出（cron 记录在 /var/log/finx-backup.log）
#   - 本机只保留最近 7 天的每日备份（部署前备份 pre-*.sql.gz 不在此清理范围）
#   - 异地副本：方案待用户选定（见 design/audit-20261121.md OPS-P1-1）
set -uo pipefail
cd "$(dirname "$0")"
DIR=/opt/finx/backups/daily
KEEP_DAYS=7
mkdir -p "$DIR" && chmod 700 "$DIR"
f="$DIR/finx-$(date -u +%Y%m%d).sql.gz"
ts() { date -u +%FT%TZ; }
if ! (umask 077 && docker compose exec -T postgres pg_dump -U finx -d finx | gzip >"$f.tmp"); then
	rm -f "$f.tmp"; echo "$(ts) BACKUP_FAIL pg_dump"; exit 1
fi
if ! gzip -t "$f.tmp" || [[ $(gzip -dc "$f.tmp" | head -c 4096 | wc -c) -eq 0 ]]; then
	rm -f "$f.tmp"; echo "$(ts) BACKUP_FAIL verify"; exit 1
fi
mv -f "$f.tmp" "$f" && chmod 600 "$f"
find "$DIR" -maxdepth 1 -name 'finx-*.sql.gz' -mtime +$((KEEP_DAYS - 1)) -print -delete | sed "s/^/$(ts) pruned /"
echo "$(ts) BACKUP_OK $(basename "$f") $(stat -c %s "$f") bytes; kept $(ls "$DIR"/finx-*.sql.gz | wc -l) daily"
