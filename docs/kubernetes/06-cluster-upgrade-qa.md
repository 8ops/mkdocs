# 实战 | 维护集群关键问题

## 一、信息查看

> 节点信息

```bash
K-KUBE-LAB-01 10.101.11.240
K-KUBE-LAB-02 10.101.11.114
K-KUBE-LAB-03 10.101.11.154

K-KUBE-LAB-201 10.101.11.238
K-KUBE-LAB-202 10.101.11.93
K-KUBE-LAB-203 10.101.11.53

```



kubernetes 所有组件中只会有 ETCD 存在 leader 选举

```bash
cd /etc/kubernetes
rsync -av manifests/ manifests-20230310/
rsync -av manifests-20230310/ manifests/

# The items in the lists are endpoint, ID, version, db size, is leader, is learner, raft term, raft index, raft applied index, errors.
etcdctl member list -w table \
  --endpoints=https://10.101.11.114:2379 \
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
  --endpoints=https://10.101.11.114:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# 切换leader
etcdctl move-leader ed1afb9abd383490 \
  --endpoints=https://10.101.11.240:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

etcdctl member remove 99bb4ff3ed8558ca \
  --endpoints=https://10.101.11.114:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

etcdctl member add k-kube-lab-201 \
  --endpoints=https://10.101.11.114:2379 \
  --peer-urls=https://10.101.11.238:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

```



## 二、MOCK场景

kubernetes cluster 在运行过程中会有很多异常情况，此处用于模拟异常并尝试恢复。

当control-plane不可用时，集群中业务的pod不受影响，流量正常接入。



### 2.1 终止部分control-plane节点

**可行**

| control-plane节点数 | 允许异常节点 |
| ------------------- | ------------ |
| 3                   | 1            |
| 4                   | 1            |
| 5                   | 2            |
| 6                   | 2            |
| 7                   | 3            |
| 8                   | 3            |
| 9                   | 5            |



> 模拟故障

```bash
# 共3台control-plane

#1，停第1台静态容器
cd /etc/kubernetes
mv manifests manifests-20230310
# 现象：集群正常，etcd leader 飘移
# 原因：etcd leader 成功飘移（etcd leader 刚好在停掉的节点上）

#2，停第2台静态容器
cd /etc/kubernetes
mv manifests manifests-20230310
# 现象：集群崩溃，etcd leader 消失
# 原因：etcd learner/leader 角色未发生变化，etcd luster节点数量小于2 etcd 集群不存在leader无法正常工作
```

> 恢复故障

```bash
#1，恢复第2台静态容器
cd /etc/kubernetes
rsync -av manifests-20230310/ manifests/
# 现象：集群正常，etcd leader 出现
# 原因：etcd leader 未发生飘移 ，etcd luster节点数量为2

#2，恢复第1台静态容器
cd /etc/kubernetes
rsync -av manifests-20230310/ manifests/
# 现象：集群正常
```



### 2.2 终止全部 control-plane 节点

**不可行**

```bash
# 参考场景一，当恢复到第2台 control-plane 时集群恢复可用。
```



### 2.3 挪用其他节点证书恢复

**不可行**

> 模拟故障

```bash
# 在其中一个节点上操作

#1，停掉control-plane
cd /etc/kubernetes
mv manifests manifests-20230310
# 现象：集群正常，摘掉1个control-plane

#2，备份证书
mv pki pki-20230310
```



> 恢复故障

```bash
#1，从其他节点恢复证书
scp /etc/kubernetes/pki

#2，恢复control-plane
cd /etc/kubernetes
rsync -av manifests-20230310/ manifests/
# 现象：集群正常，摘掉control-plane未恢复
# 原因：拷贝过来的证书签名中 X509v3 Subject Alternative Name 未包含当前节点信息
```



### 2.4 当集群不可用时 join 新节点

**不可行**

> 恢复故障

```bash
kubeadm init phase upload-certs --upload-certs

# I0310 17:40:27.320512 1479993 version.go:256] remote version is much newer: v1.26.2; falling back to: stable-1.25
# [upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
# error execution phase upload-certs: error uploading certs: error creating token: timed out waiting for the condition
# To see the stack trace of this error execute with --v=5 or higher

# 现象：无法join
# 原因：无法往etcd插入节点数据
```



### 2.5 编辑etcd数据

**不可行**

> 恢复故障

```bash
etcdctl member remove b9512d2bb2a3c6f5 \
  --endpoints=https://10.101.11.154:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

etcdctl member add k-kube-lab-201 \
  --endpoints=https://10.101.11.154:2379 \
  --peer-urls=https://10.101.11.238:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

etcdctl endpoint status \
  --endpoints=https://10.101.11.154:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

etcdctl endpoint status -w table \
  --cluster \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key  
  
# 原因：当集群不可用时etcd数据只支持查看
```



### 2.6 删除 control-plane节点后再join

**可行**

> 恢复故障

```bash
# etcd member 节点信息还存在需要先手动移除
etcdctl member remove 1bd3101f2cbe0fab \
  --endpoints=https://10.101.11.154:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
# 原因：若不  
```



### 2.7 etcd数据不一致

[Reference](https://zhuanlan.zhihu.com/p/138424613)

```txt

+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|         ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://10.101.11.240:2379 | 5fa87e503b09d83d |   3.5.1 |  112 MB |      true |      false |         3 |  309461550 |          309461550 |        |
| https://10.101.11.114:2379 | 797dc1cea3a53a6b |   3.5.1 |  119 MB |     false |      false |         3 |  309461550 |          309461550 |        |
| https://10.101.11.154:2379 | 8ac0782f040c745a |   3.5.1 |  123 MB |     false |      false |         3 |  309461550 |          309461550 |        |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
```

[etcd performance](https://doczhcn.gitbook.io/etcd/index/index-1/performance)



## 三、番外

### 3.1 成员数量(cluser size)

这里主要涉及到两点。首先是一个etcd cluster的节点数量最好是奇数，两个原因：

1. 对应的偶数个节点(奇数+1)能容忍的失败节点数量还是一样的。例如3个节点时，能容忍一个节点down，4个节点时同样只能容忍一个节点down。但是节点增多，导致失败的概率会增大；
2. 在发生网络分区，将cluster隔离成两个小团体时，总有一个团体能满足quorum(法定票数)，从而能继续提供服务。但是对于偶数个节点，则有可能两个隔离的分区都无法提供服务。



另外一点就是关于cluster节点数量的上限问题。虽然上限没有限制，但是一个etcd cluster最好不要超过7个节点。一方面，节点数量增加的确可以增加容错率，例如7个节点可以容忍3个down，9个则可以容忍4个down。但是另一方面，节点数量增加，同样也会导致quorum增大，例如7个节点的quorum是4，9个节点的quorum则是5；因为etcd是强一致性K/V DB，每一个写请求必须至少quorum个节点都写成功才能返回成功，所以节点数量增加会降低写请求的性能。





### 3.2 替换节点的正确姿势

当cluster中某个节点down了，一般需要把这个节点从cluster中移除，并增加一个新的节点到cluster中去。



这里一定要注意，要先删除老节点，然后再增加新节点。先删除后增加，先删除后增加，重要的事情说三遍！这个顺序不能反了，如果先增加新节点，然后再删除老节点，有可能导致cluster无法工作，并且永远也无法自动恢复，就必须人工干预了。



这里举一个例子来说明。假设cluster有三个节点，其中一个节点突然发生故障。这时cluster中还有两个节点健康，依然满足quorum，所以cluster还可以正常提供服务。这时如果先增加一个新节点到cluster中，因为那个down的节点还没有从cluster中移除，所以cluster的节点数量就变成了4。如果一切顺利，新节点正常启动，倒也还好。但是如果发生了意外（比如配置错误），导致新增加的节点启动失败，这时cluster的quorum已经从2变成了3，可是cluster中依然只有两个节点能工作，不符合quorum要求，从而导致cluster无法对外提供服务，而且永远无法自动恢复。这个时候，当你再想从cluster中删除任何节点，都不会成功了，因为删除节点也需要向cluster中发送一个写请求，这时cluster已经因为quorum不达标而无法提供服务了，所以删除节点的操作不会成功。这就尴尬了！
