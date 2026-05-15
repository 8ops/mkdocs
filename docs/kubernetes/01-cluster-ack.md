# ack

aliyun 容器服务多种模式使用下来还是 ack 托管集群性价比高。

ack serverless 就是一个坑货。对最小资源规格有限制，按 eni 容量计费显贵。



## 一、常用技巧

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
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/alibaba-cloud-loadbalancer-address-type: internet # intranet-对内，internet-对外
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



