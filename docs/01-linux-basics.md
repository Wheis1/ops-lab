# 01 · 系统初始化与基础

> 状态：🚧 待补 · 建议完成时间：本周内

## 目标

装完系统后，10 分钟内把机器调整到「可交付」状态：用户、SSH、时区、防火墙、软件源。

## 步骤

| # | 做什么 | 关键命令 |
| --- | --- | --- |
| 1 | 建运维账号，禁用 root 远程登录 | `useradd ops` `usermod -aG wheel ops` `PermitRootLogin no` |
| 2 | 配置密钥登录 | `ssh-keygen` `ssh-copy-id ops@host` |
| 3 | 时区与时间同步 | `timedatectl set-timezone Asia/Shanghai` `chronyc sources` |
| 4 | 防火墙只开必要端口 | `firewall-cmd --add-service=http --permanent` `--reload` |
| 5 | 换软件源 / 装常用工具 | `yum install -y vim net-tools lsof tcpdump` |
| 6 | 内核参数（文件句柄、端口范围） | `ulimit -n` `sysctl -w net.ipv4.ip_local_port_range` |

```bash
# 权限自查：哪些账号能登录、哪些能 sudo
awk -F: '$3>=1000 && $3<65534 {print $1,$3,$7}' /etc/passwd
grep -E '^(wheel|sudo)' /etc/group
sshd -T | grep -E 'permitrootlogin|passwordauthentication'
```

## 验证

```bash
# 待补：用一条命令证明这一步成功了，并贴出输出
```

## 截图

![待补](screenshots/TODO.png)

## 复盘

- 这一课最容易错的地方：
- 下次怎么更快：
