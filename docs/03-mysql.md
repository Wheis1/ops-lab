# 03 · MySQL 安装与备份恢复

> 状态：🚧 待补 · 建议完成时间：本周内

## 目标

装 MySQL 8.0，建业务库与最小权限账号，跑通「备份 → 删库 → 恢复」闭环。

## 步骤

```bash
# 1. 安装（容器方式最省事，见 docker-compose.yml）
docker compose up -d mysql
docker compose exec mysql mysql -uroot -p

# 2. 建库建号，只给必要权限
CREATE DATABASE app_db DEFAULT CHARSET utf8mb4;
CREATE USER 'app'@'%' IDENTIFIED BY '***';
GRANT SELECT,INSERT,UPDATE,DELETE ON app_db.* TO 'app'@'%';

# 3. 备份（一致性备份，不锁表）
mysqldump -uroot -p --single-transaction --routines --triggers app_db > app_db.sql

# 4. 恢复演练（真正做过才算会）
mysql -uroot -p -e "DROP DATABASE app_db; CREATE DATABASE app_db;"
mysql -uroot -p app_db < app_db.sql
```

## 要能回答

- `--single-transaction` 为什么能保证一致性？（InnoDB 快照读，不锁表）
- 误删数据怎么救？（binlog 按时间点恢复：`mysqlbinlog --start-datetime`）
- 备份完怎么验证？（恢复到测试库 + `CHECKSUM TABLE` 对比）

## 验证

```bash
# 待补：用一条命令证明这一步成功了，并贴出输出
```

## 截图

![待补](screenshots/TODO.png)

## 复盘

- 这一课最容易错的地方：
- 下次怎么更快：
