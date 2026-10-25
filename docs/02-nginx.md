# 02 · Nginx 部署与反向代理

> 状态：🚧 待补 · 建议完成时间：本周内

## 目标

一台机器跑两个项目：`/lost/` → 8082，`/catering/` → 8080；改配置不中断连接。

## 步骤

```bash
yum install -y nginx
nginx -v
cp conf/nginx/app.conf /etc/nginx/conf.d/app.conf
nginx -t                    # 语法校验，必须通过
systemctl enable --now nginx
nginx -s reload             # 平滑重载，不断连接
```

核心配置见 [`conf/nginx/app.conf`](../conf/nginx/app.conf)。

## 关键原理（面试会问）

- `proxy_pass http://upstream/` 末尾带 `/`：会去掉 location 匹配到的前缀
- `nginx -s reload`：master 收到信号后启动新 worker、旧 worker 处理完存量连接再退出，所以不中断
- 502 是后端不可用/端口错，504 是后端超时

## 验证

```bash
# 待补：用一条命令证明这一步成功了，并贴出输出
```

## 截图

![待补](screenshots/TODO.png)

## 复盘

- 这一课最容易错的地方：
- 下次怎么更快：
