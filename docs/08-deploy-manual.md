# 08 · 部署实施手册（模板 + 示例）

> 这是交给「客户/下一任运维」看的东西，标准是：**别人照着做，不用问你也能部署成功**。
> 下面的示例是 LNMP + Docker Compose 场景，把路径、IP、账号换成你自己的即可。

---

## 1. 项目与环境

| 项目 | 内容 |
| --- | --- |
| 系统 | CentOS 7.9 x86_64 |
| 配置 | 2C4G / 40G 系统盘 |
| 依赖 | JDK 11、MySQL 8.0、Redis 6.2、Nginx 1.20、Docker 24 + Compose v2 |
| 网络 | 内网 10.0.0.0/24，对外仅开放 80/443，管理走跳板机 |
| 部署方式 | Docker Compose 一键编排（4 个容器） |

## 2. 前置检查（部署前 5 分钟）

```bash
# 系统版本与内核
cat /etc/redhat-release && uname -r

# 磁盘与内存（至少留 20% 空闲）
df -h && free -h

# 端口是否被占用（80/443/3306/6379/8082/8080）
ss -tlnp | grep -E ':(80|443|3306|6379|8082|8080)\b'

# 时间是否同步（不同步会导致证书/SQL 时间错乱）
timedatectl

# SELinux 与防火墙状态（决定后面要不要放行）
getenforce && systemctl is-active firewalld

# Docker 是否可用
docker version && docker compose version
```

## 3. 部署步骤

```bash
# 3.1 建目录与用户（不用 root 跑应用）
useradd -r -s /sbin/nologin appuser
mkdir -p /opt/app/{conf,logs,data,backup}

# 3.2 拉取代码
cd /opt/app
git clone <仓库地址> src && cd src

# 3.3 准备环境变量（密码不写进 compose 文件）
cp .env.example .env
vi .env      # 填 MYSQL_ROOT_PASSWORD / MYSQL_PASSWORD / REDIS_PASSWORD

# 3.4 导入数据库（首次部署）
docker compose up -d mysql
sleep 20
docker compose exec -T mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" < init.sql

# 3.5 拉起全部服务
docker compose up -d
docker compose ps          # 4 个容器都应为 running/healthy

# 3.6 配置 Nginx 路径分流（单机双项目）
nginx -t && nginx -s reload
```

## 4. 验证清单（缺一项都不算部署完成）

| # | 检查项 | 命令 | 期望结果 |
| --- | --- | --- | --- |
| 1 | 容器状态 | `docker compose ps` | 全部 Up / healthy |
| 2 | 应用端口 | `ss -tlnp \| grep 8082` | 有监听 |
| 3 | 首页 | `curl -I http://127.0.0.1:8082/lost/` | HTTP 200 |
| 4 | 反向代理 | `curl -I http://127.0.0.1/lost/` | HTTP 200，Header 有 upstream |
| 5 | 数据库连通 | `docker compose exec mysql mysqladmin ping` | `mysqld is alive` |
| 6 | 缓存连通 | `redis-cli -a "$REDIS_PASSWORD" ping` | `PONG` |
| 7 | 监控指标 | `curl -s http://127.0.0.1:9100/metrics \| head` | 有指标输出 |
| 8 | 日志无 ERROR | `docker compose logs --tail 100 app \| grep ERROR` | 无输出 |
| 9 | 重启自愈 | `docker compose restart app` 后再验证第 3 项 | 200 |

## 5. 回滚方案

```bash
# 5.1 部署前必须备份（脚本已包含）
bash scripts/backup_mysql.sh

# 5.2 回滚到上一个镜像 tag
docker compose down
docker tag app:previous app:latest
docker compose up -d

# 5.3 回滚数据库（谨慎：会覆盖当前数据）
gunzip < backup/app_db_20261024_0300.sql.gz | docker compose exec -T mysql mysql -uroot -p"$PWD" app_db
```

## 6. 常见问题

| 现象 | 可能原因 | 处理 |
| --- | --- | --- |
| 容器 Up 但访问 502 | 应用没起完 / 端口写错 | `docker logs` 看启动日志，确认 `server.port` |
| 启动报 `bind: address already in use` | 旧进程未退出 | `ss -tlnp` 找 PID，停掉再起 |
| 数据库连不上（1045） | 密码错 / 授权主机不匹配 | 核对 `.env` 与 `mysql.user` |
| 页面样式丢失 | Nginx 静态资源路径错 | 检查 `root` 与 `location /static` |
| 磁盘快速上涨 | 容器日志未限制 | compose 加 `logging: max-size: 100m` |

## 7. 附录

- 端口分配：8082（失物招领）、8080（智慧餐饮）、3306、6379、9100（node_exporter）
- 目录：代码 `/opt/app/src`、日志 `/opt/app/logs`、备份 `/opt/app/backup`
- 账号：应用账号 `app`，仅授权业务库，禁止 root 登录应用
- 变更记录：每次上线在此追加一行（日期 / 内容 / 操作人 / 是否回滚）

| 日期 | 变更内容 | 操作人 | 结果 |
| --- | --- | --- | --- |
| 2026-10-24 | 首次部署 v1.0 | 王森 | 成功 |
