# 04 · Redis 部署与故障处理

> 状态：🚧 待补 · 建议完成时间：本周内

## 目标

部署 Redis，配置密码与内存上限，复现「连接被拒」并定位修复。

## 步骤

```bash
docker compose up -d redis
docker compose exec redis redis-cli -a "$REDIS_PASSWORD" ping     # PONG

# 常见故障复现：把 bind 改成 127.0.0.1 后从另一台机器连
nc -zv 10.0.0.12 6379          # Connection refused / timeout
docker compose logs redis --tail 50
```

## 要能回答

- RDB 与 AOF 的区别，生产怎么选？
- 缓存穿透 / 击穿 / 雪崩分别是什么，怎么防？
- `KEYS *` 为什么禁止在生产用？（单线程阻塞，用 `SCAN`）
- 内存满了会怎样？（`maxmemory-policy` 决定淘汰还是报错）

## 验证

```bash
# 待补：用一条命令证明这一步成功了，并贴出输出
```

## 截图

![待补](screenshots/TODO.png)

## 复盘

- 这一课最容易错的地方：
- 下次怎么更快：
