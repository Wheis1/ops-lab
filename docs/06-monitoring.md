# 06 · Prometheus + Grafana 监控告警

> 状态：🚧 待补 · 建议完成时间：本周内

## 目标

采集主机与业务指标，配 3 条告警规则，钉钉能收到通知。

## 步骤

```bash
# 1. 起 node_exporter
docker run -d --name node-exporter --net host \
  -v /:/host:ro,rslave prom/node-exporter --path.rootfs=/host

# 2. Prometheus 配置见 conf/prometheus/prometheus.yml
promtool check config /etc/prometheus/prometheus.yml

# 3. 验证采集
curl -s http://127.0.0.1:9090/api/v1/targets | head
curl -s http://127.0.0.1:9100/metrics | grep node_load1

# 4. 触发一次告警（把磁盘写满或用 stress 压 CPU），确认钉钉收到
```

## 三条必配告警

| 告警 | 表达式 | 阈值 |
| --- | --- | --- |
| 磁盘使用率 | `100 - node_filesystem_avail_bytes{fstype!~"tmpfs"} / node_filesystem_size_bytes * 100` | > 85% 持续 5m |
| 内存使用率 | `100 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100` | > 90% 持续 5m |
| 服务探活 | `probe_success == 0` | 持续 1m |

## 要能回答

- Prometheus 为什么用 pull 而不是 push？（目标可控、易发现异常）
- exporter 是什么？和 agent 有什么区别？
- 告警太多怎么办？（分级、抑制、聚合，避免告警风暴）

## 验证

```bash
# 待补：用一条命令证明这一步成功了，并贴出输出
```

## 截图

![待补](screenshots/TODO.png)

## 复盘

- 这一课最容易错的地方：
- 下次怎么更快：
