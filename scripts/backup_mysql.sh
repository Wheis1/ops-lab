#!/usr/bin/env bash
# backup_mysql.sh —— MySQL 逻辑备份 + 自动清理旧备份
# 用法：
#   bash backup_mysql.sh                 # 用 ~/.my.cnf 里的账号
#   MYSQL_USER=backup MYSQL_PWD=xxx bash backup_mysql.sh
# 建议：放到 crontab 每天 3 点执行
#   0 3 * * * /opt/app/scripts/backup_mysql.sh >> /opt/app/logs/backup.log 2>&1

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/app/backup}"
KEEP_DAYS="${KEEP_DAYS:-7}"
MYSQL_USER="${MYSQL_USER:-backup}"
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"

TS=$(date +%F_%H%M)
FILE="${BACKUP_DIR}/all_${TS}.sql.gz"

log() { echo "[$(date '+%F %T')] $*"; }

mkdir -p "$BACKUP_DIR"

# 1. 前置检查：磁盘至少留 5G，否则不备份（避免把磁盘写满）
avail=$(df -Pk "$BACKUP_DIR" | awk 'NR==2{print int($4/1024/1024)}')
if [ "$avail" -lt 5 ]; then
  log "ERROR 可用空间不足 5G（当前 ${avail}G），跳过本次备份"
  exit 1
fi

# 2. 备份：--single-transaction 保证 InnoDB 一致性且不锁表
log "开始备份 -> ${FILE}"
if mysqldump \
      --defaults-extra-file=<(printf '[client]\nuser=%s\npassword=%s\nhost=%s\nport=%s\n' \
        "$MYSQL_USER" "${MYSQL_PWD:-}" "$MYSQL_HOST" "$MYSQL_PORT") \
      --single-transaction --quick --routines --triggers --events \
      --all-databases --set-gtid-purged=OFF 2>/dev/null | gzip -9 > "$FILE"; then
  log "备份完成，大小 $(du -h "$FILE" | cut -f1)"
else
  log "ERROR 备份失败，删除不完整文件"
  rm -f "$FILE"
  exit 1
fi

# 3. 校验：gzip -t 能过、文件头正常
if ! gzip -t "$FILE" 2>/dev/null; then
  log "ERROR 备份文件损坏"; rm -f "$FILE"; exit 1
fi
if ! gzip -dc "$FILE" | head -c 200 | grep -q "MySQL dump"; then
  log "ERROR 备份内容异常"; exit 1
fi

# 4. 清理 N 天前的备份
find "$BACKUP_DIR" -name 'all_*.sql.gz' -type f -mtime +"$KEEP_DAYS" -print -delete | while read -r f; do
  log "清理旧备份 $f"
done

log "本次备份结束，当前保留：$(ls -1 "$BACKUP_DIR"/all_*.sql.gz 2>/dev/null | wc -l) 份"
