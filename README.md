&#x20;HEAD

# ops-lab

# Linux 运维实验与排障记录：部署、脚本、故障排查手册

# ops-lab · Linux 运维实验与排障记录

> 2026 届计算机专业毕业生的运维动手记录：每做一次部署或排障，就留下命令、输出和结论。
> 目的不是收集教程，而是证明「我真的在服务器上跑过、错过、修好了」。

* 环境：CentOS 7.9（阿里云 ECS 2C2G）+ 本地 VMware
* 内容：LNMP 部署、Docker Compose 编排、MySQL 备份恢复、Prometheus 监控、故障场景定位与修复
* 结构：`docs/` 看过程，`scripts/` 直接跑，`conf/` 是配置模板，`screenshots/` 是截图证据

## 目录结构

|目录|放什么|说明|
|-|-|-|
|`docs/`|实验记录、部署手册、排障手册|面试官主要看这里|
|`scripts/`|Shell 运维脚本|能直接执行，带注释|
|`conf/`|Nginx / MySQL / Redis / Prometheus 配置|脱敏后的模板|
|`docker-compose.yml`|4 服务编排（Nginx + MySQL + Redis + 应用）|`docker compose up -d` 一键拉起|
|`src/`|你自己的应用包（jar），不提交|已在 `.gitignore` 中忽略|
|`screenshots/`|关键步骤截图|命名：`序号-场景-日期.png`|

## 实验进度

|#|实验|关键命令|记录|状态|
|-|-|-|-|-|
|1|系统初始化（用户、SSH、防火墙、时区）|`useradd` `sshd\_config` `firewall-cmd` `timedatectl`|[01-linux-basics](docs/01-linux-basics.md)|🚧 待补|
|2|Nginx 部署 + 反向代理 + 路径分流|`nginx -t` `nginx -s reload` `ss -tlnp`|[02-nginx](docs/02-nginx.md)|🚧 待补|
|3|MySQL 8.0 安装 + 备份恢复|`mysqldump` `mysql <`|[03-mysql](docs/03-mysql.md)|🚧 待补|
|4|Redis 部署 + 常见故障|`redis-cli ping` `ss` `tail -f`|[04-redis](docs/04-redis.md)|🚧 待补|
|5|Docker Compose 编排 4 个服务|`docker compose up -d` `docker logs`|[05-docker](docs/05-docker.md)|🚧 待补|
|6|Prometheus + Grafana 监控告警|`node\_exporter` `promtool check`|[06-monitoring](docs/06-monitoring.md)|🚧 待补|
|7|故障场景复现与定位（20 个）|见手册|[07-troubleshooting](docs/07-troubleshooting.md)|🚧 进行中|
|8|项目部署手册（可直接交付）|见手册|[08-deploy-manual](docs/08-deploy-manual.md)|🚧 待补|

> 状态标记：✅ 已完成并验证 / 🚧 进行中 / ⬜ 未开始。做完一个就把 🚧 改成 ✅，这是你每天的进度条。

## 快速开始

```bash
git clone https://github.com/<你的用户名>/ops-lab.git
cd ops-lab

# 看机器健康状况（磁盘/内存/负载/端口）
bash scripts/check\_health.sh

# MySQL 逻辑备份（先配置好 \~/.my.cnf）
bash scripts/backup\_mysql.sh

# 清理 7 天前的日志（默认只打印，不删除）
bash scripts/clean\_logs.sh --dry-run

# 一键部署（模板，需按实际项目改路径与端口）
bash scripts/deploy.sh
```

## 写文档的约定

1. 每个故障都按 **现象 → 定位命令（带输出） → 根因 → 修复 → 验证** 五段写，缺一段都算没做完。
2. 命令要能复制粘贴复现，涉及路径的写真实路径。
3. 截图命名 `序号-场景-日期.png`，例如 `03-disk-full-20261024.png`。
4. **不提交**密码、密钥、真实公网 IP、公司内部信息；IP 用 `192.0.2.10` 这类文档地址占位。

## 本周待办

* \[ ] 补齐 `docs/07-troubleshooting.md` 的场景 6-20
* \[ ] 每个已完成的场景补 1 张截图
* \[ ] `scripts/` 四个脚本在本机跑通一次
* \[ ] 录一段 2 分钟演示（部署 + 排障各 1 分钟）

&#x20;85bbdf1 (init: first commit)

