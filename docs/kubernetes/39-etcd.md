# etcd

## 一、搭建集群

当 master 节点变化后需要核实信息

### 1.1 member

```bash
etcdctl member list \
    --endpoints=https://10.101.11.183:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key  

etcdctl member remove d928e5a97677118c \
    --endpoints=https://10.101.11.183:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key

ETCDCTL_API=3 etcdctl endpoint status --cluster -w table \
    --endpoints=https://10.101.11.183:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key   

ETCDCTL_API=3 etcdctl endpoint health --cluster -w table \
    --endpoints=https://10.101.11.183:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key  
```



### 1.2 endpoints

```bash
kubectl -n kube-system edit kube-etcd
```





## 二、搭建监控

### 2.1 基于prometheus监控etcd

```bash
# 1，创建客户端证书
kubectl create secret generic etcd-certs \
  --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  --from-file=/etc/kubernetes/pki/etcd/ca.crt \
  -n kube-server

# 2，添加 prometheus's rule 自发现节点
- job_name: kubernetes-etcd
  honor_timestamps: true
  scrape_interval: 1m
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: https
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/etcd/ca.crt
    cert_file: /var/run/secrets/kubernetes.io/etcd/healthcheck-client.crt
    key_file: /var/run/secrets/kubernetes.io/etcd/healthcheck-client.key
    insecure_skip_verify: false
  follow_redirects: true
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_label_app_kubernetes_io_name]
    separator: ;
    regex: etcd
    replacement: $1
    action: keep
  kubernetes_sd_configs:
  - role: endpoints
    kubeconfig_file: ""
    follow_redirects: true
    namespaces:
      own_namespace: false
      names:
      - kube-system
```



## 三、番外篇

### 3.1 压测

当扩容后ETCD节点在不同数量下工作性能对比

在实验环境做压测效果如下

> 7个节点

| 方式  | 策略         | 请求数 | key  | value | conns | clients | latency | qps   |
| ----- | ------------ | ------ | ---- | ----- | ----- | ------- | ------- | ----- |
| write | leader       | 10000  | 8    | 256   | 1     | 1       | 31.9    | 31    |
| write | leader       | 10000  | 8    | 256   | 100   | 100     | 188     | 529   |
| write | all member   | 10000  | 8    | 256   | 100   | 100     | 187     | 532   |
| read  | Linearizable | 10000  | 8    | 256   | 1     | 1       | 3.5     | 284   |
| read  | Linearizable | 10000  | 8    | 256   | 100   | 100     | 15.8    | 6184  |
| read  | Serializable | 10000  | 8    | 256   | 1     | 1       | 4.5     | 1443  |
| read  | Serializable | 10000  | 8    | 256   | 100   | 100     | 83      | 10608 |

> 3个节点

| 方式  | 策略         | 请求数 | key  | value | conns | clients | latency | qps  |
| ----- | ------------ | ------ | ---- | ----- | ----- | ------- | ------- | ---- |
| write | leader       | 10000  | 8    | 256   | 1     | 1       | 4       | 251  |
| write | leader       | 10000  | 8    | 256   | 100   | 100     | 46.9    | 2114 |
| write | all member   | 10000  | 8    | 256   | 100   | 100     | 27.2    | 3474 |
| read  | Linearizable | 10000  | 8    | 256   | 1     | 1       | 2.4     | 412  |
| read  | Linearizable | 10000  | 8    | 256   | 100   | 100     | 31.7    | 3134 |
| read  | Serializable | 10000  | 8    | 256   | 1     | 1       | 3.7     | 2450 |
| read  | Serializable | 10000  | 8    | 256   | 100   | 100     | 95.9    | 8412 |

- 结果显示当etcd cluster节点达7个时写延迟提升5-8倍QPS下降5-8倍
- 节点增加至7个集群自身消耗会比较严重



### 3.2 问题

#### 3.2.1 ETCD 数据不一致

```bash
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|         ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://10.101.11.240:2379 | 5fa87e503b09d83d |   3.5.1 |  112 MB |      true |      false |         3 |  311385411 |          311385411 |        |
| https://10.101.11.114:2379 | 797dc1cea3a53a6b |   3.5.1 |  119 MB |     false |      false |         3 |  311385411 |          311385411 |        |
| https://10.101.11.154:2379 | 8ac0782f040c745a |   3.5.1 |  123 MB |     false |      false |         3 |  311385411 |          311385411 |        |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

- 3个节点中DB SIZE不一致
- 通过判断 `RAFT INDEX | RAFT APPLIED INDEX` 断定数据已经完整同步
- 在实验环境模拟出此现象，经执行 `etcdctl defrag` 清理磁盘碎片使其统一

#### 3.2.2 ETCD日志报异常

```bash
{"level":"warn","ts":"2023-03-13T08:46:25.065Z","caller":"etcdserver/util.go:166","msg":"apply request took too long","took":"101.221909ms","expected-duration":"100ms","prefix":"read-only range ","request":"key:\"/registry/replicasets/kube-app/\" range_end:\"/registry/replicasets/kube-app0\" ","response":"range_response_count:2849 size:12995415"}
```

- [ListOption](https://my.oschina.net/u/4518070/blog/5547497) 不设置 `ResourceVersion=0` 会导致 apiserver 去 etcd 拿数据，应该尽量避免。

```bash
{"level":"warn","ts":"2023-03-14T01:41:03.397Z","caller":"v3rpc/interceptor.go:197","msg":"request stats","start time":"2023-03-14T01:41:03.090Z","time spent":"307.305871ms","remote":"127.0.0.1:28932","response type":"/etcdserverpb.KV/Range","request count":0,"request size":56,"response count":2028,"response size":1332819,"request content":"key:\"/registry/events/kube-app/\" range_end:\"/registry/events/kube-app0\" "}
```
