#!/usr/bin/env bash
# deploy.sh —— 一键部署模板：停旧进程 → 备份 → 启动 → 端口检测 → HTTP 校验 → 失败回滚
# ⚠️ 这是模板，必须按你的项目改「配置区」再跑；第一次建议在测试机执行
# 用法：bash deploy.sh [--skip-backup]

set -euo pipefail

# ============ 配置区（按项目改） ============
APP_NAME="lost-found"
APP_HOME="/opt/app"
APP_JAR="${APP_HOME}/src/${APP_NAME}.jar"
APP_PORT=8082
HEALTH_URL="http://127.0.0.1:${APP_PORT}/actuator/health"
BACKUP_DIR="${APP_HOME}/backup"
LOG_DIR="${APP_HOME}/logs"
KEEP_RELEASES=5
# ===========================================

TS=$(date +%F_%H%M%S)
RELEASE_DIR="${APP_HOME}/releases/${TS}"
CURRENT_LINK="${APP_HOME}/current"
SKIP_BACKUP=0
[ "${1:-}" = "--skip-backup" ] && SKIP_BACKUP=1

log()  { echo "[$(date '+%T')] $*"; }
fail() { echo "[$(date '+%T')] ❌ $*" >&2; }

# 1. 前置检查
precheck() {
  log "① 前置检查"
  local avail
  avail=$(df -Pk "$APP_HOME" | awk 'NR==2{print int($4/1024/1024)}')
  [ "$avail" -ge 2 ] || { fail "磁盘可用不足 2G（${avail}G）"; exit 1; }
  if ss -tln | awk '{print $4}' | grep -qE "[:.]${APP_PORT}$"; then
    fail "端口 ${APP_PORT} 已被占用：$(ss -tlnp | grep ":${APP_PORT} " || true)"
    fail "先确认是旧实例还是其他服务（ps -fp <pid>），不要盲目 kill"
    exit 1
  fi
  [ -f "$APP_JAR" ] || { fail "找不到包：$APP_JAR"; exit 1; }
  log "   磁盘 ${avail}G 可用，端口空闲，包存在"
}

# 2. 备份：包 + 数据库
backup() {
  [ "$SKIP_BACKUP" -eq 1 ] && { log "② 跳过备份（--skip-backup）"; return; }
  log "② 备份"
  mkdir -p "$BACKUP_DIR"
  if [ -L "$CURRENT_LINK" ]; then
    cp -a "$(readlink -f "$CURRENT_LINK")" "$BACKUP_DIR/app_${TS}" && log "   旧版本已备份"
  fi
  if command -v mysqldump >/dev/null 2>&1; then
    bash "$(dirname "$0")/backup_mysql.sh" || { fail "数据库备份失败，中止部署"; exit 1; }
  fi
}

# 3. 启动：软链切换 + 后台拉起
start() {
  log "③ 启动新版本"
  mkdir -p "$RELEASE_DIR" "$LOG_DIR"
  cp -a "$APP_JAR" "$RELEASE_DIR/"
  ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"
  nohup java -jar "$CURRENT_LINK/${APP_NAME}.jar" \
        --server.port="${APP_PORT}" \
        >> "${LOG_DIR}/${APP_NAME}.out" 2>&1 &
  log "   PID=$! 已拉起"
}

# 4. 健康检查：端口 + HTTP，重试 20 次（约 40 秒）
health() {
  log "④ 健康检查"
  for i in $(seq 1 20); do
    if ss -tln | awk '{print $4}' | grep -qE "[:.]${APP_PORT}$"; then
      code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$HEALTH_URL" || true)
      if [ "$code" = "200" ]; then
        log "   ✅ 服务健康（HTTP 200，第 ${i} 次探测）"
        return 0
      fi
    fi
    sleep 2
  done
  fail "健康检查失败：端口=${APP_PORT} 未就绪或 HTTP 非 200"
  return 1
}

# 5. 回滚：切回上一个 release
rollback() {
  log "⑤ 回滚"
  local prev
  prev=$(ls -1d "${APP_HOME}"/releases/*/ 2>/dev/null | grep -v "${TS}" | tail -1 || true)
  if [ -z "$prev" ]; then fail "没有可回滚的历史版本"; return 1; fi
  pkill -f "${APP_NAME}.jar" 2>/dev/null || true
  sleep 2
  ln -sfn "${prev%/}" "$CURRENT_LINK"
  nohup java -jar "${prev%/}/${APP_NAME}.jar" --server.port="${APP_PORT}" \
        >> "${LOG_DIR}/${APP_NAME}.out" 2>&1 &
  log "   已回滚到 ${prev}"
  health || { fail "回滚后仍不健康，请人工介入"; return 1; }
}

# 5'. 清理历史版本
cleanup() {
  local n
  n=$(ls -1d "${APP_HOME}"/releases/*/ 2>/dev/null | wc -l)
  if [ "$n" -gt "$KEEP_RELEASES" ]; then
    ls -1dt "${APP_HOME}"/releases/*/ | tail -n +$((KEEP_RELEASES + 1)) | xargs -r rm -rf
    log "   已清理历史版本，保留最近 ${KEEP_RELEASES} 个"
  fi
}

main() {
  log "==== 部署开始：${APP_NAME} @ $(hostname) ===="
  precheck
  backup
  if start && health; then
    cleanup
    log "==== ✅ 部署成功 ===="
  else
    fail "启动或健康检查失败，自动回滚"
    rollback || true
    log "==== ❌ 部署失败（已尝试回滚）===="
    exit 1
  fi
}

main
