#!/usr/bin/env bash
# check_health.sh —— 一分钟体检：磁盘 / 内存 / 负载 / 端口 / 服务
# 用法：bash check_health.sh [端口1 端口2 ...]
# 退出码：0 全部正常，1 有告警（可直接接监控或定时任务）

set -uo pipefail

PORTS="${*:-22 80 3306 6379 8080}"
DISK_WARN=80
DISK_CRIT=90
MEM_WARN=85
LOAD_WARN=$(nproc)          # 经验值：load 超过核数就该关注

RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; NC=$'\033[0m'
warn=0

line() { printf '%s\n' "------------------------------------------------------------"; }

check_disk() {
  line; echo "[磁盘]"
  while read -r fs size used avail pct mnt; do
    if [ "$fs" = "Filesystem" ]; then
      printf '%-22s %6s %6s %6s %5s %s\n' "$fs" "$size" "$used" "$avail" "$pct" "$mnt"
      continue
    fi
    p=${pct%\%}
    case "$pct" in
      *%) ;;
      *) continue ;;      # 跳过没有使用率的行（如 tmpfs 特殊挂载）
    esac
    color=""
    if   [ "$p" -ge "$DISK_CRIT" ]; then color=$RED;   warn=1
    elif [ "$p" -ge "$DISK_WARN" ]; then color=$YEL;   warn=1
    else color=$GRN; fi
    printf '%s%-22s %6s %6s %6s %5s %s%s\n' "$color" "$fs" "$size" "$used" "$avail" "$pct" "$mnt" "$NC"
  done < <(df -hP)
}

check_mem() {
  line; echo "[内存]"
  free -m | awk 'NR==1{print;next}{printf "%-8s %8s %8s %8s\n",$1,$2,$3,$4}'
  used_pct=$(free | awk '/Mem:/{printf "%d", $3/$2*100}')
  echo "使用率：${used_pct}%"
  if [ "$used_pct" -ge "$MEM_WARN" ]; then echo "${YEL}内存使用率偏高，检查是否有进程泄漏${NC}"; warn=1; fi
  echo "Swap：$(free -m | awk '/Swap:/{print $3"MB / "$2"MB"}')"
}

check_load() {
  line; echo "[负载]  (CPU 核数: $(nproc))"
  read -r l1 l5 l15 _ < /proc/loadavg
  echo "1 分钟: $l1   5 分钟: $l5   15 分钟: $l15"
  if awk "BEGIN{exit !($l1 > $LOAD_WARN)}"; then
    echo "${YEL}load 超过核数，看是 CPU 还是 IO：top / vmstat 1${NC}"; warn=1
  fi
}

check_ports() {
  line; echo "[端口]"
  for p in $PORTS; do
    if ss -tln 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${p}$"; then
      printf '%s  %-6s 监听中%s  %s\n' "$GRN" "$p" "$NC" "$(ss -tlnp 2>/dev/null | grep -E "[:.]${p}\s" | head -1 | awk '{print $NF}')"
    else
      printf '%s  %-6s 未监听%s\n' "$RED" "$p" "$NC"; warn=1
    fi
  done
}

check_services() {
  line; echo "[关键服务]"
  for s in sshd crond firewalld docker nginx mysqld redis; do
    if systemctl list-unit-files 2>/dev/null | grep -q "^${s}\.service"; then
      st=$(systemctl is-active "$s" 2>/dev/null)
      [ "$st" = "active" ] && printf '%s  %-10s %s%s\n' "$GRN" "$s" "$st" "$NC" \
                           || { printf '%s  %-10s %s%s\n' "$RED" "$s" "$st" "$NC"; warn=1; }
    fi
  done
}

check_top() {
  line; echo "[CPU / 内存 Top5]"
  ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -6
  echo
  echo "系统启动时间：$(uptime -p 2>/dev/null || uptime)"
  echo "最近登录：$(last -n 3 2>/dev/null | head -3 | tr '\n' ' ')"
}

main() {
  echo "主机：$(hostname)   时间：$(date '+%F %T')   系统：$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release | awk -F= '/PRETTY_NAME/{print $2}')"
  check_disk; check_mem; check_load; check_ports; check_services; check_top
  line
  if [ "$warn" -eq 0 ]; then echo "${GRN}体检通过：没有发现异常${NC}"; exit 0
  else echo "${YEL}存在告警项，见上方标黄/标红内容${NC}"; exit 1; fi
}

main
