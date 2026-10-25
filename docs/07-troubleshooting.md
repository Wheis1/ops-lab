# 07 · Linux 故障排查手册

> 用法：每次遇到问题，先按这个模板记录，再回来补全。
> 面试时被问「你处理过什么故障」，你打开这一页就够了。
> 写满 20 个场景，比简历上写十句「熟悉」有用。

## 模板（复制这一段）

```markdown
### 场景 N：一句话描述现象

- **环境**：CentOS 7.9 / 2C2G / Nginx 1.20 + MySQL 8.0
- **现象**：用户看到什么、日志报什么、什么时候开始
- **定位过程**：
  ```bash
  # 1. 先看整体
  # 2. 再缩小范围
  # 3. 确认根因
  ```
  （每步写命令 + 关键输出，不要只写命令）
- **根因**：一句话说清，不要写「配置错误」这种废话
- **修复**：改了什么、改了哪一行
- **验证**：用什么命令证明已经好了
- **复盘**：怎么避免再次发生（监控项 / 规范 / 脚本）
```

---

## 场景 1：根分区磁盘写满，应用日志报 No space left on device

- **环境**：CentOS 7.9，40G 系统盘，Nginx + 应用日志未切割
- **现象**：应用报 `No space left on device`，`df` 显示 `/` 使用率 100%
- **定位过程**：

```bash
# 1. 确认哪个分区满
df -h
# /dev/vda1  40G  40G  0  100%  /

# 2. 找出该分区下最大的目录（不跨文件系统，排除 /proc 干扰）
du -sh /* 2>/dev/null | sort -h | tail -n 10

# 3. 找出大文件（-xdev 不跨挂载点）
find / -xdev -type f -size +500M -exec ls -lh {} \; 2>/dev/null

# 4. 有没有「已删除但被进程占用」的文件（du 看不到、df 却算）
lsof +L1 | head
```

- **根因**：应用日志按天写但没做切割，`app.log` 涨到 20G；另外有一个被 delete 但被 java 进程持有的日志文件仍占 5G
- **修复**：

```bash
# 清理旧日志（先确认再删）
find /var/log/app -name "*.log.*" -mtime +7 -print
find /var/log/app -name "*.log.*" -mtime +7 -delete

# 正在写的日志不要 rm，用 truncate，避免句柄不释放
truncate -s 0 /var/log/app/app.log

# 配置 logrotate，按天切、留 7 份、压缩
cat >/etc/logrotate.d/app <<'EOF'
/var/log/app/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    copytruncate
}
EOF
```

- **验证**：`df -h /` 使用率降到 40% 以下；`logrotate -d /etc/logrotate.d/app` 无报错；应用恢复写入
- **复盘**：加磁盘监控告警（80% 预警、90% 告警）；所有服务上线必须配 logrotate

---

## 场景 2：启动服务提示 8080 端口已被占用

- **环境**：CentOS 7.9
- **现象**：`java -jar app.jar` 启动失败，日志 `Address already in use: bind`
- **定位过程**：

```bash
# 1. 看谁在监听 8080
ss -tlnp | grep ':8080'
# LISTEN 0 128 *:8080 *:* users:(("java",pid=2317,fd=98))

# 2. 确认这个进程是什么
ps -fp 2317
ls -l /proc/2317/cwd     # 看工作目录，判断是哪个应用

# 3. 如果是自己上一次没退干净的进程，杀掉；如果是别的业务，改端口
kill -15 2317
sleep 2 && ss -tlnp | grep ':8080'
```

- **根因**：旧的 jar 进程没有正常退出（kill -9 之后父进程重新拉起），新实例抢不到端口
- **修复**：`systemctl stop app` 停干净 → 确认端口释放 → 再启动；部署脚本里加「启动前检测端口」逻辑（见 `scripts/deploy.sh`）
- **验证**：`ss -tlnp | grep 8080` 只有一个 PID，且是新启动的；`curl -I http://127.0.0.1:8080` 返回 200
- **复盘**：部署脚本必须做端口占用检查，不能盲目启动

---

## 场景 3：Nginx 启动失败（Job for nginx.service failed）

- **环境**：CentOS 7.9，Nginx 1.20
- **现象**：`systemctl start nginx` 失败，`systemctl status nginx` 显示 `failed`
- **定位过程**：

```bash
systemctl status nginx -l --no-pager
journalctl -u nginx -n 50 --no-pager

# 配置语法校验（最常查的一步）
nginx -t
# nginx: [emerg] unknown directive "proxy_passs" in /etc/nginx/conf.d/app.conf:12

# 端口是否被别的服务占用
ss -tlnp | grep ':80\|:443'

# SELinux 是否拦截
getenforce
ausearch -m avc -ts recent 2>/dev/null | tail
```

- **根因**：conf 里 `proxy_pass` 拼成了 `proxy_passs`，语法错误导致启动失败（另一种常见原因是 80 端口被 httpd 占用）
- **修复**：修正拼写 → `nginx -t` 通过 → `systemctl restart nginx`
- **验证**：`systemctl is-active nginx` 返回 active；`curl -I http://127.0.0.1` 返回 200
- **复盘**：改配置必须 `nginx -t` 再 reload；把 `nginx -t` 写进部署脚本

---

## 场景 4：MySQL 登录报 ERROR 1045 (Access denied)

- **环境**：MySQL 8.0
- **现象**：`mysql -uroot -p` 报 `ERROR 1045 (28000): Access denied for user 'root'@'localhost'`
- **定位过程**：

```bash
# 1. 先确认不是密码输错 / 不是连错实例
mysql --version
ss -tlnp | grep 3306
tail -n 50 /var/log/mysqld.log

# 2. 用 skip-grant-tables 临时进（仅排障，生产慎用）
systemctl stop mysqld
mysqld_safe --skip-grant-tables --skip-networking &
mysql -uroot

# 3. 看用户和授权主机
SELECT user, host, plugin FROM mysql.user;
SHOW GRANTS FOR 'root'@'localhost';
```

- **根因**：应用连接用的是 `root'@'%`，但授权表里只有 `root'@'localhost'`；或密码含特殊字符未加引号
- **修复**：

```sql
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '新密码';
CREATE USER 'app'@'10.0.0.%' IDENTIFIED BY '应用密码';
GRANT SELECT,INSERT,UPDATE,DELETE ON app_db.* TO 'app'@'10.0.0.%';
```

改完注释掉 `skip-grant-tables` 重启，**不要长期开着**（等于无密码）
- **验证**：`mysql -uapp -p -h 10.0.0.12 -e "select 1"` 成功
- **复盘**：应用不用 root；密码用环境变量注入，不写死在配置里

---

## 场景 5：Redis 报 Connection refused

- **环境**：Redis 6.x
- **现象**：应用报 `RedisConnectionFailureException: Connection refused`
- **定位过程**：

```bash
ss -tlnp | grep 6379          # 没有任何输出 = 服务没起
systemctl status redis -l --no-pager
tail -n 50 /var/log/redis/redis.log

# 端口通不通（从应用机器上测）
nc -zv 10.0.0.12 6379

# 若本机能连、远端不能连：看 bind 与保护模式
grep -E '^(bind|protected-mode|requirepass)' /etc/redis.conf

# 再看防火墙
firewall-cmd --list-ports
```

- **根因**：redis.conf 里 `bind 127.0.0.1` + `protected-mode yes`，只允许本机访问；应用在另一台机器上，所以被拒
- **修复**：`bind 0.0.0.0`（或内网 IP）+ 设置 `requirepass` + 防火墙只放行应用机器 IP，然后 `systemctl restart redis`
- **验证**：`redis-cli -h 10.0.0.12 -a '密码' ping` 返回 PONG；`nc -zv` 通
- **复盘**：Redis 绝不能裸奔在公网；改配置后必须两端都验证（本机 + 应用机）

---

## 场景 6：CPU 使用率 100%，但看不出是哪个业务

- **环境**：CentOS 7.9，Java 应用
- **现象**：监控告警 CPU 95%+，接口变慢
- **定位过程**：

```bash
top -o %CPU                       # 找到吃 CPU 的 PID
top -Hp 2317                      # 看该进程内哪个线程高
printf '%x\n' 2331                # 线程号转 16 进制，如 0x91b
jstack 2317 | grep -A 30 'nid=0x91b'   # 定位到具体代码行
pidstat -p 2317 1 5               # 观察持续占用
```

- **根因**：某接口死循环重试（连接池耗尽后不断重连），线程一直占 CPU
- **修复**：先限流/降级止血 → 修代码 → 灰度发布
- **验证**：CPU 回落到 20% 以下；`jstack` 不再有该热点线程
- **复盘**：加重试上限与熔断；CPU 告警阈值分级

---

## 待补场景（本周每天补 2 个）

- [ ] 7. 内存不足触发 OOM Killer（`dmesg | grep -i 'killed process'`）
- [ ] 8. load average 很高但 CPU 不高（IO 等待，`vmstat 1` 看 wa）
- [ ] 9. SSH 连不上（防火墙 / sshd 状态 / 安全组 / 磁盘满导致无法登录）
- [ ] 10. 忘记 root 密码（GRUB 单用户模式重置）
- [ ] 11. inode 用尽（`df -i`，大量小文件）
- [ ] 12. crontab 定时任务不执行（路径 / 权限 / 环境变量 / crond 状态）
- [ ] 13. Nginx 502 与 504 的区别与定位
- [ ] 14. MySQL 连接数打满（`show processlist`、`max_connections`）
- [ ] 15. MySQL 主从延迟（`Seconds_Behind_Master`、大事务、从库压力）
- [ ] 16. 容器启动即退出（`docker logs`、退出码、启动命令）
- [ ] 17. Docker 磁盘占用过大（`docker system df`、overlay2、日志）
- [ ] 18. K8s Pod Pending / CrashLoopBackOff（`describe`、`logs`、探针）
- [ ] 19. 时间不同步导致证书校验/主从异常（`chronyc sources`、`timedatectl`）
- [ ] 20. SELinux 拦截服务（`getenforce`、`ausearch -m avc`、`setsebool`）
