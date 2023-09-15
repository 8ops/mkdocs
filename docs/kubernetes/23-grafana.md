# Helm + Grafana

先准备mysql存储grafana的metedata信息[实战 | 基于Kubernetes使用MySQL](21-mysql.md)

| name     | value   |
| -------- | ------- |
| database | grafana |
| username | grafana |
| password | grafana |



## 一、安装

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm search repo grafana
 
helm show values grafana/grafana --version 6.38.1 > grafana.yaml-6.38.1-default 

# Example 
#   https://books.8ops.top/attachment/grafana/helm/grafana.yaml-6.38.1
# 

helm install grafana grafana/grafana \
    -f grafana.yaml-6.38.1 \
    -n kube-server \
    --create-namespace \
    --version 6.38.1 --debug

helm upgrade --install grafana grafana/grafana \
    -f grafana.yaml-6.38.1 \
    -n kube-server \
    --create-namespace \
    --version 6.38.1 --debug
    
helm -n kube-server uninstall grafana    

CREATE DATABASE `grafana` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

# reset admin exec container
grafana-cli admin reset-admin-password "admin"
```



## 二、升级

```bash

helm show values grafana/grafana > grafana.yaml-6.38.1-default 

# Example 
#   https://books.8ops.top/attachment/grafana/helm/grafana.yaml-6.38.1
# 

helm install grafana grafana/grafana \
    -f grafana.yaml-6.38.1 \
    -n kube-server \
    --create-namespace \
    --version 6.38.1 --debug
```





## 三、模板

<u>Category</u>

- Application
- GenDash
- Kubernetes
- Middleware
- Network
- General

```bash
https://books.8ops.top/attachment/grafana/template/kube-state-metrics.json
https://books.8ops.top/attachment/grafana/template/kubernetes-cluster-monitoring.json
https://books.8ops.top/attachment/grafana/template/kubernetes-cluster-summary.json
https://books.8ops.top/attachment/grafana/template/kubernetes-node-exporter-full.json
https://books.8ops.top/attachment/grafana/template/middleware-mysql-overview.json
https://books.8ops.top/attachment/grafana/template/middleware-nginx-ingress-controller.json
https://books.8ops.top/attachment/grafana/template/middleware-redis-ha.json
```



## 四、效果

[官方模板](https://grafana.com/grafana/dashboards/)

![kube-state-metrics](../images/grafana/kube-state-metrics.png)

![Kubernetes cluster monitoring](../images/grafana/kubernetes-cluster-monitoring.png)

![Kubernetes / Node Exporter Full](../images/grafana/kubernetes-node-exporter-full.png)

![Kubernetes Nodes](../images/grafana/kubernetes-nodes.png)

![Kubernetes Cluster](../images/grafana/kuernetes-cluster.png)

![MySQL Overview](../images/grafana/middleware-mysql.png)

![NGINX Ingress controller](../images/grafana/middleware-nginx.png)

![Redis Dashboard for Prometheus Redis Exporter](../images/grafana/middleware-redis.png)

## 五、进阶

### 5.1 变量



### 5.2 插件

#### 5.2.1 node graph

[Reference](https://grafana.com/grafana/plugins/hamedkarbasi93-nodegraphapi-datasource/)

```bash
# 插件名称
hamedkarbasi93-nodegraphapi-datasource


```



#### 5.2.2 echarts

```bash
# 插件名称
volkovlabs-echarts-panel

```



#### 5.2.3 static database

```bash
# 插件名称
marcusolsson-static-datasource

```



#### 5.2.4 diagram panel

```bash
# 插件名称
jdbranham-diagram-panel

# Mermaid syntax
graph LR
A[alias A] 
B{alias B}
A --> B ----> D[rect]
B --> E[(database)]
A --> C{{polygon}} --> F
C --> G((circle))
G ---->|long line| I
G ----> J(round rect)
```

