#!/usr/bin/env bash
# check_health.sh —— 一分钟体检：磁盘 / 内存 / 负载 / 端口 / 服务 / 进程
# 兼容 CentOS 7 与 Ubuntu 20.04+（服务名差异已做适配）
# 用法：bash check_health.sh [端口1 端口2 ...]
# 退出码：0 全部正常，1 有告警（可直接接监控或定时任务）

set -uo pipefail

PORTS="${*:-22 80 3306 6379 8080}"
DISK_WARN=80
DISK_CRIT=90
MEM_WARN=85
LOAD_WARN=$(nproc)          # 经验值：load 超过核数就该关注

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; GRY=$'\033[90m'; NC=$'\033[0m'
warn=0

line() { printf '%s\n' "------------------------------------------------------------"; }

os_name() {
  if [ -f /etc/redhat-release ]; then
    cat /etc/redhat-release
  else
    awk -F= '/^PRETTY_NAME=/{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null
  fi
}

check_disk() {
  line; echo "[磁盘]"
  printf '%-22s %6s %6s %6s %5s %s\n' "Filesystem" "Size" "Used" "Avail" "Use%" "Mounted"
  while read -r fs size used avail pct mnt; do
    [ "$fs" = "Filesystem" ] && continue
    case "$fs" in tmpfs|devtmpfs|udev|overlay) continue ;; esac
    case "$pct" in *%) ;; *) continue ;; esac
    p=${pct%\%}
    color=$GRN
    if [ "$p" -ge "$DISK_CRIT" ] 2>/dev/null; then
      color=$RED; warn=1
    elif [ "$p" -ge "$DISK_WARN" ] 2>/dev/null; then
      color=$YEL; warn=1
    fi
    printf '%s%-22s %6s %6s %6s %5s %s%s\n' "$color" "$fs" "$size" "$used" "$avail" "$pct" "$mnt" "$NC"
  done < <(df -hP)
}

check_mem() {
  line; echo "[内存]"
  free -m | awk 'NR<=3'          # 表头 + Mem + Swap，保留原始列
  used_pct=$(free | awk '/^Mem:/{printf "%d", $3/$2*100}')
  echo "内存使用率：${used_pct}%"
  if [ "$used_pct" -ge "$MEM_WARN" ]; then
    echo "${YEL}内存使用率偏高，检查是否有进程泄漏${NC}"; warn=1
  fi
  sw_total=$(free -m | awk '/^Swap:/{print $2}')
  if [ "${sw_total:-0}" -eq 0 ]; then
    echo "${YEL}未配置 swap，建议加 2G（见 README）${NC}"
  fi
}

check_load() {
  line; echo "[负载]  (CPU 核数: $(nproc))"
  read -r l1 l5 l15 _ < /proc/loadavg
  echo "1 分钟: $l1   5 分钟: $l5   15 分钟: $l15"
  if awk "BEGIN{exit !($l1 > $LOAD_WARN)}"; then
    echo "${YEL}load 超过核数，先分清是 CPU 还是 IO：top / vmstat 1${NC}"; warn=1
  fi
}

check_ports() {
  line; echo "[端口]"
  for p in $PORTS; do
    if ss -tln 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${p}$"; then
      printf '%s  %-6s 监听中%s  %s\n' "$GRN" "$p" "$NC" \
        "$(ss -tlnp 2>/dev/null | grep -E "[:.]${p} " | head -1 | sed 's/.*users:/users:/')"
    else
      printf '%s  %-6s 未监听（服务未安装或未启动）%s\n' "$GRY" "$p" "$NC"
    fi
  done
  echo "${GRY}说明：未监听端口不计入告警；服务装了没起来会由下面「关键服务」报出来${NC}"
}

# 服务名兼容：CentOS 用 sshd/crond/mysqld，Ubuntu 用 ssh/cron/mysql
check_services() {
  line; echo "[关键服务]"
  found=0
  for pair in ssh:sshd cron:crond docker:docker nginx:nginx mysql:mysqld redis:redis-server; do
    unit=""
    for u in "${pair%%:*}" "${pair##*:}"; do
      # 用 systemctl cat 判断单元是否存在，避免 list-unit-files | grep -q 的 SIGPIPE 问题
      if systemctl cat "${u}.service" >/dev/null 2>&1; then unit="$u"; break; fi
    done
    [ -z "$unit" ] && continue
    found=$((found + 1))
    st=$(systemctl is-active "$unit" 2>/dev/null || true)
    if [ "$st" = "active" ]; then
      printf '%s  %-12s %s%s\n' "$GRN" "$unit" "$st" "$NC"
    else
      printf '%s  %-12s %s%s\n' "$RED" "$unit" "$st" "$NC"; warn=1
    fi
  done
  if [ "$found" -eq 0 ]; then
    echo "${GRY}  未检测到常见服务（nginx/mysql/redis/docker 都还没装，属正常）${NC}"
  fi
}

check_top() {
  line; echo "[CPU / 内存 Top5]"
  ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -6
  echo
  echo "系统启动时间：$(uptime -p 2>/dev/null || uptime)"
  echo "最近登录：$(last -n 3 2>/dev/null | head -3 | tr '\n' ' ')"
}

main() {
  echo "主机：$(hostname)   时间：$(date '+%F %T')   系统：$(os_name)"
  check_disk; check_mem; check_load; check_ports; check_services; check_top
  line
  if [ "$warn" -eq 0 ]; then
    echo "${GRN}体检通过：没有发现异常${NC}"; exit 0
  else
    echo "${YEL}存在告警项，见上方标黄/标红内容${NC}"; exit 1
  fi
}

main
