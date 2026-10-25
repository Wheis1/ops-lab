#!/usr/bin/env bash
# clean_logs.sh —— 日志清理：默认只预览，确认后加 --force 才真正删除
# 用法：
#   bash clean_logs.sh                      # 预览：列出 7 天前的日志
#   bash clean_logs.sh --force              # 真删
#   bash clean_logs.sh --days 30 --force    # 清理 30 天前的
#   bash clean_logs.sh --truncate /var/log/app/app.log   # 清空正在写的日志（不删文件）

set -euo pipefail

LOG_DIRS="${LOG_DIRS:-/var/log/app /opt/app/logs}"
DAYS=7
FORCE=0
TRUNCATE_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --force)    FORCE=1 ;;
    --days)     DAYS="$2"; shift ;;
    --truncate) TRUNCATE_FILE="$2"; shift ;;
    -h|--help)  sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "未知参数：$1"; exit 2 ;;
  esac
  shift
done

# 清空单个正在写的文件（比 rm 安全：文件句柄还在，进程不会报错）
if [ -n "$TRUNCATE_FILE" ]; then
  if [ -f "$TRUNCATE_FILE" ]; then
    before=$(du -h "$TRUNCATE_FILE" | cut -f1)
    : > "$TRUNCATE_FILE"
    echo "已清空 $TRUNCATE_FILE（原大小 $before）"
  else
    echo "文件不存在：$TRUNCATE_FILE"; exit 1
  fi
  exit 0
fi

total=0
for d in $LOG_DIRS; do
  [ -d "$d" ] || continue
  echo "扫描目录：$d"
  while IFS= read -r f; do
    size=$(du -h "$f" | cut -f1)
    echo "  $f  ($size)"
    total=$((total + 1))
    if [ "$FORCE" -eq 1 ]; then
      rm -f "$f"
    fi
  done < <(find "$d" -type f \( -name '*.log' -o -name '*.log.[0-9]*' -o -name '*.gz' \) -mtime +"$DAYS" 2>/dev/null)
done

echo "------------------------------------------------------------"
if [ "$FORCE" -eq 1 ]; then
  echo "已删除 $total 个 ${DAYS} 天前的日志文件"
else
  echo "预览模式：共 $total 个文件，未删除。确认无误后加 --force 执行"
fi
echo "提示：删之前先看 logrotate 是否已配置：ls /etc/logrotate.d/"
