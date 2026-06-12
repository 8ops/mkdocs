# Quick Start - Ack

aliyun 容器服务多种模式使用下来还是 ack 托管集群性价比高。

ack serverless 就是一个坑货。对最小资源规格有限制，按 eni 容量计费显贵。



## 一、Quick

ack 托管集群使用常用技巧



### 1.1 动态扩缩



### 1.2 ingress-nginx服务暴露

```bash
# helm 配置文件中指定

controller:

  config:
    ...
    allow-snippet-annotations: "true"
    annotations-risk-level: "Critical" # 4.14.1 往后默认降级为 Warn 对注解中的 snippet 大部分不支持
    forwarded-for-header: "X-Forwarded-For" # 获取来访 IP
    real-ip-header: "X-Forwarded-For"
    set-real-ip-from: "0.0.0.0/0"
    
  kind: Deployment # 不用像此前 DaemonSet 模式固定节点
  replicaCount: 2

  service: # 会自动在 clb 创建负载均衡
  # https://help.aliyun.com/zh/ack/ack-managed-and-ack-dedicated/user-guide/add-annotations-to-the-yaml-file-of-a-service-to-configure-clb-instances
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/alibaba-cloud-loadbalancer-address-type: internet # intranet-对内，internet-对外
      
      service.beta.kubernetes.io/alibaba-cloud-loadbalancer-delete-protection: "on" # default

# 用于限制其他命名空间恶意创建 clb 资源
# ack 实例控制面板 --> 安全管理 --> 策略管理
# ACKBlockLoadBalancer √
# ACKBlockInternetLoadBalancer

```





### 1.3 使用私有内网 dns

```bash
# 1. 移除内置 CoreDNS（组件管理 -- 搜索 CoreDNS -- 卸载）

# 2. 安装普通 CoreDNS（组件管理 -- 搜索 CoreDNS -- 安装）

# 3. 编辑配置 configmap/coredns
# worker 节点不允许变更 /etc/resolv.conf，其实变更也无法 dns 拦截

kubectl -n kube-system edit cm coredns
        ...
        forward . 10.0.0.2 { # 替换配置为私有dns
          prefer_udp
        }
```



### 1.4 ECS 配置网卡

Alibaba Cloud Linux 3/4 LTS

其中

Alibaba Cloud Linux 3 Pro & Alibaba Cloud Linux 4 Pro 是符合信创要求的操作系统，操作系统需要付费购买。

```bash
########
# 需要追加一个私有网卡
########

# 查看网络连接名称
nmcli con show

# 查看网卡配置
ip a show eth0

# 追加辅助私网 IP 地址
nmcli con modify "cloud-init eth0" +ipv4.addresses 192.168.1.202/24
nmcli con modify "cloud-init eth0" ipv4.addresses 10.170.0.11/24,10.170.0.1/24

# 重启网络设备
nmcli con reload

# 激活修改后的网络连接
nmcli con up "cloud-init eth0"
```







## 二、资源隔离

在 Kubernetes 中，**按 Namespace 限制资源使用**，通常有 3 种方式，分别解决不同问题：

1. **限制单个 Pod/Container 最大最小资源** → `LimitRange`
2. **限制整个 Namespace 总资源配额** → `ResourceQuota`
3. **限制对象数量（Pod、PVC、Service 数量等）** → `ResourceQuota`

一般生产环境会 **`LimitRange + ResourceQuota` 配合使用**。

------

### 1. 使用 ResourceQuota 限制 Namespace 总资源

例如限制 `dev` namespace：

- CPU 总量最多：8 核
- 内存总量最多：16Gi
- Pod 数量最多：50
- PVC 总量：20

YAML 示例

```
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-resource-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi

    limits.cpu: "8"
    limits.memory: 16Gi

    pods: "50"
    persistentvolumeclaims: "20"
```

创建：

```
kubectl apply -f quota.yaml
```

查看：

```
kubectl describe resourcequota -n dev
```

示例输出：

```
Name:            dev-resource-quota
Namespace:       dev
Resource         Used    Hard
--------         ----    ----
limits.cpu       2       8
limits.memory    4Gi     16Gi
pods             12      50
```

资源说明

| 配额项                 | 说明                                |
| ---------------------- | ----------------------------------- |
| requests.cpu           | namespace 所有 Pod request CPU 总和 |
| requests.memory        | request memory 总和                 |
| limits.cpu             | limit CPU 总和                      |
| limits.memory          | limit memory 总和                   |
| pods                   | pod 数量                            |
| services               | Service 数量                        |
| persistentvolumeclaims | PVC 数量                            |
| requests.storage       | 存储申请总量                        |

------

### 2. 使用 LimitRange 限制 Pod 默认资源与上下限

仅靠 `ResourceQuota` 有个问题：

> 用户不写 `resources`，Pod 可能无法创建或无限制。

所以建议同时加 `LimitRange`。

例如：

- 默认 CPU request：100m
- 默认 memory request：128Mi
- 单容器最大 CPU：2核
- 单容器最大内存：4Gi

YAML 示例

```
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limit-range
  namespace: dev
spec:
  limits:
  - type: Container

    defaultRequest:
      cpu: 100m
      memory: 128Mi

    default:
      cpu: "500m"
      memory: 512Mi

    min:
      cpu: 50m
      memory: 64Mi

    max:
      cpu: "2"
      memory: 4Gi
```

应用：

```
kubectl apply -f limitrange.yaml
```

查看：

```
kubectl describe limitrange -n dev
```

效果：

如果用户 Deployment 不写资源：

```
resources: {}
```

K8s 自动补充：

```
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

如果超限：

例如申请：

```
resources:
  limits:
    cpu: 4
```

会被拒绝：

```
maximum cpu usage per Container is 2, but limit is 4
```

------

### 3. 限制 GPU / StorageClass 等资源

例如 GPU：

```
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-quota
  namespace: ai
spec:
  hard:
    requests.nvidia.com/gpu: "2"
```

限制某类存储：

```
spec:
  hard:
    gold.storageclass.storage.k8s.io/requests.storage: 100Gi
```

------

### 4. 企业常用最佳实践

建议按环境设置：

**dev namespace（开发）**

限制宽松：

```
requests.cpu: 4
limits.cpu: 8
requests.memory: 8Gi
limits.memory: 16Gi
pods: 100
```

**test namespace（测试）**

中等：

```
requests.cpu: 8
limits.cpu: 16
memory: 32Gi
```

**prod namespace（生产）**

严格：

- 强制 request/limit
- 禁止 BestEffort Pod
- 配合 HPA/VPA
- 限制对象数量

比如：

```
pods: 200
services: 20
configmaps: 100
secrets: 100
persistentvolumeclaims: 50
```

------

### 5. 一键模板（推荐）

给 namespace 同时加：

```
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limit-range
  namespace: dev
spec:
  limits:
  - type: Container
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    default:
      cpu: 500m
      memory: 512Mi
    max:
      cpu: "2"
      memory: 4Gi

---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: default-resource-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "50"
    persistentvolumeclaims: "20"
```

直接：

```
kubectl apply -f namespace-limit.yaml
```

这样就实现：

- **单 Pod 不可无限吃资源**
- **namespace 总资源有上限**
- **默认资源自动注入**
- **避免资源抢占（Noisy Neighbor）**

如果你是多租户（比如 ArgoCD 多项目、多个业务 namespace），建议再配合：

- `NetworkPolicy`（网络隔离）
- `RBAC`（权限隔离）
- `PriorityClass`（资源抢占优先级）
- `LimitRange + ResourceQuota`（资源隔离）

