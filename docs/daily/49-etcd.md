# ETCD

Reference

> 相关问题

- [数据不一致](https://zhuanlan.zhihu.com/p/138424613)
- [performance](https://doczhcn.gitbook.io/etcd/index/index-1/performance)



## 查看

```bash
# The items in the lists are endpoint, ID, version, db size, is leader, is learner, raft term, raft index, raft applied index, errors.
etcdctl member list -w table \
  --endpoints=https://10.101.11.240:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

etcdctl endpoint status -w table \
  --cluster \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

etcdctl endpoint status -w table \
  --cluster \
  --endpoints=https://10.101.11.240:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

etcdctl endpoint health -w table \
  --cluster \
  --endpoints=https://10.101.11.240:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

## 操作

```bash
# 切换leader（--endpoints指向原leader）
etcdctl move-leader aa3d2ade73c186ec \
  --endpoints=https://10.101.11.240:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

etcdctl member remove 6fb6887435ae87d5 \
  --endpoints=https://10.101.11.240:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

etcdctl member add k-kube-lab-201 \
  --endpoints=https://10.101.11.240:2379 \
  --peer-urls=https://10.101.11.114:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 清除存储碎片
etcdctl defrag \
  --endpoints=https://10.101.11.240:2379,https://10.101.11.114:2379,https://10.101.11.154:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```



## 压测

> 写

```bash
# 假定 IP_1 是 leader, 写入请求发到 leader
# 1
benchmark \
  --endpoints=https://10.101.11.240:2379 \
  --conns=1 --clients=1 \
  put --key-size=8 --sequential-keys --total=10000 --val-size=256 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key 2>&1 1>/tmp/benchmark.out

# 2
benchmark \
  --endpoints=https://10.101.11.240:2379 \
  --conns=100 --clients=100 \
  put --key-size=8 --sequential-keys --total=10000 --val-size=256 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key 2>&1 1>/tmp/benchmark.out

# 写入发到所有成员
# 3
benchmark \
  --endpoints=https://10.101.11.240:2379,https://10.101.11.114:2379,https://10.101.11.154:2379 \
  --conns=100 --clients=100 \
  put --key-size=8 --sequential-keys --total=10000 --val-size=256 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key 2>&1 1>/tmp/benchmark.out

# 分析结果
awk '/Average|Requests\/sec/{if($1~/Average/){latency+=$2*1000}else if($1~/Requests\/sec/){qps+=$2}}END{printf("%.1f\t%d\n",latency,qps)}' /tmp/benchmark.out
```



> 读

```bash
# Linearizable 读取请求
# 1
benchmark \
  --endpoints=https://10.101.11.240:2379 \
  --conns=1 --clients=1 \
  range YOUR_KEY --consistency=l --total=10000 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key 2>&1 1>/tmp/benchmark.out
 
# 2
benchmark \
  --endpoints=https://10.101.11.240:2379 \
  --conns=100 --clients=100 \
  range YOUR_KEY --consistency=l --total=10000 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key 2>&1 1>/tmp/benchmark.out

# Serializable 读取请求，使用每个成员然后将数字加起来
# 3
for endpoint in \
  https://10.101.11.240:2379 \
  https://10.101.11.114:2379 \
  https://10.101.11.154:2379
do
benchmark \
  --endpoints=$endpoint \
  --conns=1 --clients=1 \
  range YOUR_KEY --consistency=s --total=1000 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
done 2>&1 1>/tmp/benchmark.out

# 4
for endpoint in \
  https://10.101.11.240:2379 \
  https://10.101.11.114:2379 \
  https://10.101.11.154:2379
do
benchmark \
  --endpoints=$endpoint \
  --conns=100 --clients=100 \
  range YOUR_KEY --consistency=s --total=1000 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
done 2>&1 1>/tmp/benchmark.out

# 分析结果
awk '/Average|Requests\/sec/{if($1~/Average/){latency+=$2*1000}else if($1~/Requests\/sec/){qps+=$2}}END{printf("%.1f\t%d\n",latency,qps)}' /tmp/benchmark.out
```



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
