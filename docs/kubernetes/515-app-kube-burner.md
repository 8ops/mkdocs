# kube-burner

[Reference](https://github.com/kube-burner/kube-burner)

kube-burner 可以用于创建大量 namespace、deployments、daemonsets、jobs 等，评估 API Server、scheduler 等承载能力。



kubernetes 集群性能评测

**目标与衡量指标**

- 目标（示例）：在 X 节点集群上，验证可支持 N 个并发请求 / 秒，P95 响应时间 < 200 ms，CPU 使用率 < 70%，不发生 OOM 或容器重启。
- 关键指标（必收）：
  - 吞吐（requests/sec）
  - 响应时延分位数（P50/P90/P95/P99）
  - 错误率（5xx/4xx）
  - 节点与Pod资源：CPU、内存、磁盘 I/O、网络带宽
  - kube-apiserver 延迟与 QPS
  - kubelet / cAdvisor 指标（容器级）
  - 调度延迟、重启次数、OOM、eviction
  - 系统层：load average、interrupts、context switches
  - 网络丢包、连接数、socket time_wait 等

**推荐工具**（组合使用）

- 负载生成：k6（HTTP/gRPC/JS 脚本化）、wrk2、vegeta
- 集群级负载：kube-burner（模拟大量资源对象、job、ingress 等）、kubemark（controller/scale tests）
- 容器/节点压力：stress-ng、stress
- 网络压测：iperf3（节点间带宽）
- 监控/采集：Prometheus + Grafana + node-exporter + kube-state-metrics + cAdvisor + kubelet metrics-server
- 分布式追踪：Jaeger / Zipkin（排查延迟来源）
- 日志：ELK/EFK 或 Loki
- 可视化/分析：Grafana dashboard、benchmarks csv、k6 report HTML
- 负载测试报告：k6 cloud/local HTML / jq + csv

**压测环境准备**（必做）

1. **在非生产环境**搭建与线上尽量接近的集群（节点规格、网络、存储类型、CNI、服务网格是否开启都应一致）。
2. 部署完整监控栈（Prometheus + Grafana，node-exporter，kube-state-metrics）。保证抓取间隔（scrape_interval）为 10s 或更低（如 5s）以便捕获峰值。
3. 关闭自动伸缩（HPA/cluster-autoscaler）或根据测试需要明确开启/关闭（做伸缩测试时才开启）。
4. 确认调度策略、Pod QoS（requests/limits）、StorageClass 性能模式、CNI MTU、内核参数（net.ipv4.tcp_tw_recycle 已废弃，注意 tcp_tw_reuse 等）。
5. 准备一个“控制机”（可以是开发机或专用压测机）来运行 k6/wrk/kube-burner，尽量不要在集群节点上跑负载生成器以免污染监测数据。

**测试设计流程**（逐步）

1. **基线测试（低负载）**：小并发（例如 10-50 并发），观察系统稳定性/启动指标，确认监控正确。
2. **线性攀升（ramp-up）**：每 1~5 分钟提高 QPS，直至到达目标或出现异常（延迟突变、错误率上升）。记录临界点。
3. **稳态测试（sustain）**：在目标 QPS/并发下运行 10-30 分钟（或更长），观察资源与错误。收集 P95/P99。
4. **压力测试（stress）**：继续增加直到系统失效（用于找瓶颈）。
5. **恢复测试（soak）**：在中等到高负载下运行数小时或一天，观察内存泄露、连接泄漏、慢性错误。
6. **伸缩测试**：开启 HPA 或 cluster-autoscaler，观察伸缩触发时间与效果。
7. **网络与存储极限测试**：使用 iperf3 和 fio（对于 PV）进行 I/O/带宽测试。
8. **混合负载与故障注入**：用 chaos 工具（如 LitmusChaos）模拟节点故障、网络抖动、磁盘满等，观察可用性与恢复。



## 一、前置条件

### 1.1 prometheus

[Referernce](112-addons-prometheus.md)



### 1.2 elasticsearch

[Reference](113-addons-elastic.md)



### 1.3 binary

```bash
BINARY_VERSION=v1.17.7
wget https://github.com/kube-burner/kube-burner/releases/download/${BINARY_VERSION}/kube-burner-${BINARY_VERSION}-linux-x86_64.tar.gz
tar xzf kube-burner-${BINARY_VERSION}-linux-x86_64.tar.gz
mkdir -p ~/bin && mv kube-burner ~/bin/
kube-burner version
kube-burner help

Kube-burner 🔥

Tool aimed at stressing a kubernetes cluster by creating or deleting lots of objects.

Usage:
  kube-burner [command]

Available Commands:
  check-alerts Evaluate alerts for the given time range
  completion   Generates completion scripts for bash shell
  destroy      Destroy old namespaces labeled with the given UUID.
  health-check Check for Health Status of the cluster
  help         Help about any command
  import       Import metrics tarball
  index        Index kube-burner metrics
  init         Launch benchmark
  measure      Take measurements for a given set of resources without running workload
  version      Print the version number of kube-burner

Flags:
  -h, --help               help for kube-burner
      --log-level string   Allowed values: debug, info, warn, error, fatal (default "info")

Use "kube-burner [command] --help" for more information about a command.
```





## 二、workloads

```bash
git clone https://github.com/kube-burner/kube-burner.git
cd examples/workloads/

# 修改里面引用的镜像为私有
```



### 2.1 api-intensive

```bash

# hub.8ops.top/bitnami/nginx:1.23.4
# hub.8ops.top/google_containers/pause:3.10.1

# init
kube-burner init -c api-intensive.yml --uuid api-intensive

# destroy
kube-burner destroy --uuid api-intensive
```

