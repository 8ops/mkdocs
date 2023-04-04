# 实战 | 基于Helm使用Redis

提前持久化

## 一、Install

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update bitnami
helm search repo redis

# sentinel
helm show values bitnami/redis --version 16.8.7 > redis-sentinel.yaml-16.8.7-default

# Example
#   https://books.8ops.top/attachment/redis/helm/redis-sentinel.yaml-16.8.7
#

helm upgrade --install redis-sentinel bitnami/redis \
    -f redis-sentinel.yaml-16.8.7 \
    -n kube-server \
    --create-namespace \
    --version 16.8.7

helm -n kube-server uninstall redis-sentinel 

# cluster
helm show values bitnami/redis-cluster --version 7.5.0 > redis-cluster.yaml-7.5.0-default

# Example
#   https://books.8ops.top/attachment/redis/helm/redis-cluster.yaml-7.5.0
#

helm install redis-cluster bitnami/redis-cluster \
    -f redis-cluster.yaml-7.5.0 \
    -n kube-server \
    --create-namespace \
    --version 7.5.0 --debug
    
helm upgrade --install redis-cluster bitnami/redis-cluster \
    -f redis-cluster.yaml-7.5.0 \
    -n kube-server \
    --create-namespace \
    --version 7.5.0 --debug
    
helm -n kube-server uninstall redis-cluster 
```



## 二、Usage

```bash
# redis-ha
kubectl -n kube-server exec -it redis-ha-node-0 sh

PATH=/opt/bitnami/redis/bin:$PATH
redis-cli -h redis-sentinel
auth jesse

# redis-cluster
redis-cli -h redis-cluster -c
auth jesse

kubectl -n kube-server scale sts redis-cluster --replicas=0

## add nodes
redis-cli --cluster add-node 127.0.0.1:7000 172.31.6.35:7000
redis-cli --cluster reshard 127.0.0.1:7000
redis-cli --cluster add-node 127.0.0.1:7001 172.31.6.35:7000 --cluster-slave --cluster-master-id [MASTER_NODE_ID]
```



## 三、Single



```bash
```

