# 05 · Docker Compose 编排

> 状态：🚧 待补 · 建议完成时间：本周内

## 目标

用一份 compose 文件把 Nginx + MySQL + Redis + 应用拉起来，并做到「一条命令重建环境」。

## 步骤

```bash
cp .env.example .env && vi .env
mkdir -p data/mysql data/redis logs/nginx src
cp /path/to/app.jar src/app.jar
docker compose up -d
docker compose ps
docker compose logs -f app
```

## 要能回答

- 镜像和容器的区别？分层存储、写时复制是什么？
- `depends_on` 能保证依赖服务「就绪」吗？（不能，要配 healthcheck）
- 容器日志把磁盘写满怎么防？（`logging.options.max-size`）
- 数据怎么持久化？（volume / bind mount，容器删了数据还在吗）

## 验证

```bash
# 待补：用一条命令证明这一步成功了，并贴出输出
```

## 截图

![待补](screenshots/TODO.png)

## 复盘

- 这一课最容易错的地方：
- 下次怎么更快：
