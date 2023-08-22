# Helm + Prometheus

在《SRE: Google运维解密》一书中指出，监控系统需要能够有效的支持白盒监控和黑盒监控。通过白盒能够了解其内部的实际运行状态，通过对监控指标的观察能够预判可能出现的问题，从而对潜在的不确定因素进行优化。而黑盒监控，常见的如HTTP探针，TCP探针等，可以在系统或者服务在发生故障时能够快速通知相关的人员进行处理。通过建立完善的监控体系，从而达到以下目的：

- 长期趋势分析：通过对监控样本数据的持续收集和统计，对监控指标进行长期趋势分析。例如，通过对磁盘空间增长率的判断，我们可以提前预测在未来什么时间节点上需要对资源进行扩容。
- 对照分析：两个版本的系统运行资源使用情况的差异如何？在不同容量情况下系统的并发和负载变化如何？通过监控能够方便的对系统进行跟踪和比较。
- 告警：当系统出现或者即将出现故障时，监控系统需要迅速反应并通知管理员，从而能够对问题进行快速的处理或者提前预防问题的发生，避免出现对业务的影响。
- 故障分析与定位：当问题发生后，需要对问题进行调查和处理。通过对不同监控监控以及历史数据的分析，能够找到并解决根源问题。
- 数据可视化：通过可视化仪表盘能够直接获取系统的运行状态、资源使用情况、以及服务运行状态等直观的信息。



prometheus是目前人气较高的一款监控软件，活跃的社区吸引了无数的geeker。当然业内常用的监控系统还有nagios、zabbix。

大致原理是数据采集端（exporter）注册到prometheus后，由prometheus周期拉取暴露的metrics。

![architecture](../images/prometheus/architecture.jpg)



## 一、单一模式

基于kubernetes

![single](../images/prometheus/single.png)



### 1.1 prometheus

通过helm安装prometheus

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
helm search repo prometheus

# prometheus
helm show values prometheus-community/prometheus --version 15.8.5 > prometheus.yaml-15.8.5-default

# Example 
#   https://books.8ops.top/attachment/prometheus/helm/prometheus.yaml-15.8.5
#   https://books.8ops.top/attachment/prometheus/helm/prometheus-extra.yaml
#   https://books.8ops.top/attachment/prometheus/helm/prometheus-alertmanager.yaml
#

helm install prometheus prometheus-community/prometheus \
    -f prometheus.yaml-15.8.5 \
    -f prometheus-extra.yaml \
    -f prometheus-alertmanager.yaml \
    -n kube-server \
    --create-namespace \
    --version 15.8.5 --debug

kubectl -n kube-server scale --replicas=0 deploy prometheus-server
helm upgrade --install prometheus prometheus-community/prometheus \
    -f prometheus.yaml-15.8.5 \
    -f prometheus-extra.yaml \
    -f prometheus-alertmanager.yaml \
    -n kube-server \
    --create-namespace \
    --version 15.8.5 --debug

helm -n kube-server uninstall prometheus 

# reset
helm -n kube-server uninstall prometheus && \
    kubectl delete -f ../01-persistent-prometheus.yaml && \
    kubectl apply -f ../01-persistent-prometheus.yaml && \
    kubectl get pv,pvc -A
```



常用配置

- prometheus.yaml
  - alerting_rules.yml
  - recording_rules.yml
- alertmanager.yml



推荐配置指导

[awesone prometheus alerts](https://awesome-prometheus-alerts.grep.to/)



> 释放持久化卷

```bash
kubectl edit pv xxx
  finalizers:
  - kubernetes.io/pv-protection
  ...
  # upgraded
  finalizers: []
```



> 让master节点也部署node-exporter

```yaml
...
nodeExporter:
  ...
  tolerations:
    - key: "node-role.kubernetes.io/master"
      operator: "Exists"
```



> 采集外部exporter的metrics

```yaml
# 基于 helm 中 extraScrapeConfigs
extraScrapeConfigs: |
    - job_name: 'blackbox'
      metrics_path: /probe
      scheme: http
      params:
        module: [http_2xx]
      static_configs:
        - targets:
          - http://blackbox-exporter-prometheus-blackbox-exporter:9115
      relabel_configs:
        - source_labels: [__address__]
          target_label: __param_target
        - source_labels: [__param_target]
          target_label: instance
        - target_label: __address__
          replacement: blackbox-exporter-prometheus-blackbox-exporter:9115
    - job_name: 'node'
      honor_timestamps: true
      scrape_interval: 1m
      scrape_timeout: 10s
      metrics_path: /metrics
      scheme: http
      static_configs:
        - targets:
          - 10.101.11.168:19100
          - 10.101.11.188:19100
          - 10.101.11.197:19100
          - 10.101.11.209:19100
          - 10.101.11.236:19100
```



### 1.2 blackbox

blackbox-exporter 常用的一个黑盒

```bash

helm search repo prometheus-blackbox-exporter
helm show values prometheus-community/prometheus-blackbox-exporter --version 7.0.0 > blackbox-exporter.yaml-7.0.0-default

# Example 
#   https://books.8ops.top/attachment/prometheus/helm/blackbox-exporter.yaml

helm install blackbox-exporter prometheus-community/prometheus-blackbox-exporter \
    -f blackbox-exporter.yaml-7.0.0 \
    -n kube-server \
    --create-namespace \
    --version 7.0.0 --debug
    
helm upgrade --install blackbox-exporter prometheus-community/prometheus-blackbox-exporter \
    -f blackbox-exporter.yaml-7.0.0 \
    -n kube-server \
    --create-namespace \
    --version 7.0.0 --debug

helm -n kube-server uninstall blackbox-exporter 
```



### 1.3 grafana

[Reference](23-grafana.md)

```bash
# templ

## kubernetes
Kubernetes Cluster 

Kubernetes cluster monitoring

Kubernetes / Node Exporter Full

Kubernetes Nodes

kube-state-metrics

## middleware
NGINX Ingress controller

MySQL Overview

Redis Dashboard for Prometheus Redis Exporter
```



### 1.4 alertcenter

告警全家桶

推荐 [prometheus-alert-center](https://github.com/feiyu563/PrometheusAlert)

**第一步，准备**

> 企业微信机器人回调地址

```bash
https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxxx-xx-xx-xxxx
```



> 创建数据库

```bash
# MySQL 8

create database prometheus_alert;
create user 'prometheus_alert'@'%' identified by 'prometheus_alert';
grant all privileges on prometheus_alert.* to `prometheus_alert`@`%`;
flush privileges;
```



**第二步，启动**

[配置Yaml](https://m.8ops.top/attachment/prometheus/95-prometheus-alert-center.yaml)

```bash
kubectl apply -f 95-prometheus-alert-center.yaml
```



**第三步，初始数据**

```bash
mysql -uprometheus_alert -pprometheus_alert -Dprometheus_alert < prometheusalert.sql
```



**第四步，添加模板**

<u>企业微信</u>

```bash
# 模版名称：prometheus-wx-v2

# 模版内容
{{$var:=.commonLabels}}{{ range $k,$v:=.alerts }}{{if  eq $v.status "resolved"}}<font color="info">**【恢复】**</font>**{{$v.labels.alertname}}**
> <font color="info">级别：</font>{{$v.labels.severity}}
> <font color="info">环境：</font>{{GetString $v.labels.env}}
> <font color="info">持续：</font>{{GetTimeDuration $v.startsAt}}
> <font color="info">开始：</font>{{GetCSTtime $v.startsAt}}
> <font color="info">主机：</font>{{GetString $v.labels.ip}}
> {{$v.annotations.description}}{{else}}<font color="warning">**【告警】**</font>** {{$v.labels.alertname}} **
> <font color="warning">级别：</font>{{$v.labels.severity}}
> <font color="warning">环境：</font>{{GetString $v.labels.env}}
> <font color="warning">持续：</font>{{GetTimeDuration $v.startsAt}}
> <font color="warning">开始：</font>{{GetCSTtime $v.startsAt}}
> <font color="warning">主机：</font>{{GetString $v.labels.ip}}
> {{$v.annotations.description}}
> {{ $urimsg:=""}}{{ range $key,$value:=$var }}{{$urimsg =  print $urimsg $key "%3D%22" $value "%22%2C" }}{{end}}[☞点我屏蔽该告警☜](https://alertmanager-ops.8ops.top/#/silences/new?filter=%7B{{SplitString $urimsg 0 -3}}%7D){{end}}{{end}}
```

<u>阿里短信</u>

```bash
# 模版名称：prometheus-aly-dx

# 模版内容
{{ range $k,$v:=.alerts }}{{if eq $v.status "resolved"}}恢复/{{$v.labels.alertname}}
环境：{{GetString $v.labels.env}}
持续：{{GetTimeDuration $v.startsAt}}
主机：{{GetString $v.labels.ip}}
{{$v.annotations.summary}}{{else}}告警/{{$v.labels.alertname}}
环境：{{GetString $v.labels.env}}
持续：{{GetTimeDuration $v.startsAt}}
主机：{{GetString $v.labels.ip}}
{{$v.annotations.summary}}{{end}}{{end}}
```

- 阿里短信内容中不允许有特殊字符`【,】`



**第五步，联动AlertManager**

```bash
# kubectl -n kube-server edit cm prometheus-alertmanager

global:
  resolve_timeout: 5m
route:
  receiver: discard
  group_by:
  - alertname
  - severity
  continue: false
  routes:
  - receiver: prometheusalertcenter
    match_re:
      severity: critical
    continue: true
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
inhibit_rules:
- source_match:
    severity: critical
  target_match_re:
    severity: critical
  equal:
  - node
  - instance
  - alertname
- source_match:
    severity: critical
  target_match_re:
    severity: warning
  equal:
  - node
  - instance
  - alertname
receivers:
- name: discard
- name: prometheusalertcenter
  webhook_configs:
  - send_resolved: true
    http_config:
      follow_redirects: true
    url: http://prometheus-alert-center:8080/prometheusalert?type=wx&tpl=prometheus-wx-v2
    max_alerts: 0
templates:
- /opt/metadata/templates.d/*.tmpl
```



> 企业微信 Alert 效果


![alert](../images/prometheus/alert.png)



## 二、联邦模式

多业务集群下独立存在prometheus场景


![integrate](../images/prometheus/integrate.png)



> 意义 

- 集中查看数据
- 备份采集数据



```bash
# 下载最新二进制程序
PROMETHEUS_VERSION=2.46.0
wget -c -q https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz \
-O prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz -C .
mv prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz /usr/local/
ln -s /usr/local/prometheus-${PROMETHEUS_VERSION}.linux-amd64 /usr/local/prometheus

# add prometheus.yml
cat > /usr/local/prometheus/prometheus.yml <<EOF
scrape_configs:
- job_name: prometheus-instance
  honor_timestamps: true
  scrape_interval: 1m
  scrape_timeout: 1m
  metrics_path: /metrics
  scheme: https
  tls_config:
    insecure_skip_verify: true
  follow_redirects: true
  enable_http2: true
  static_configs:
  - targets:
    - prometheus-ops.8ops.top
- job_name: prometheus-federate
  honor_labels: true
  honor_timestamps: true
  params:
    match[]:
    - '{job=~".*"}'
  scrape_interval: 2m
  scrape_timeout: 2m
  metrics_path: /federate
  scheme: https
  tls_config:
    insecure_skip_verify: true
  follow_redirects: true
  enable_http2: true
  static_configs:
  - targets:
    - prometheus-ops.8ops.top
EOF

# add prometheus-federation.service
mkdir -p /data1/lib/prometheus
cat > /usr/lib/systemd/system/prometheus-federate.service <<EOF
[Unit]
Description=Prometheus main process.
After=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/prometheus
ExecStart=/usr/local/prometheus/prometheus \\
        --web.listen-address=0.0.0.0:9091 \\
        --web.page-title="Federation" \\
        --storage.tsdb.retention.time=365d \\
        --config.file=/usr/local/prometheus/prometheus.yml \\
        --storage.tsdb.path=/data1/lib/prometheus \\
        --web.console.libraries=/usr/local/prometheus/console_libraries \\
        --web.console.templates=/usr/local/prometheus/consoles \\
        --web.enable-lifecycle \\
        --web.enable-admin-api \\
        --web.enable-remote-write-receiver
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start prometheus-federate
systemctl enable prometheus-federate
systemctl is-enabled prometheus-federate
systemctl status prometheus-federate
```





## 三、使用向导



### 3.1 scrape

[configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)

[Sample](https://books.8ops.top/attachment/prometheus/85-prometheus-server.yaml)



### 3.2 rules

[configuration](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)

[Reference](https://github.com/samber/awesome-prometheus-alerts/tree/master/dist/rules)

[Sample](https://books.8ops.top/attachment/prometheus/90-prometheus-metadata-rules.yaml)



### 3.3 alertmanager

[configuration](https://prometheus.io/docs/alerting/latest/configuration/)


## 四、exporter

### 4.1 haproxy

```bash
EXPORTER_VERSION=0.15.0
curl -s -o /tmp/haproxy_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz \
https://github.com/prometheus/haproxy_exporter/releases/download/v${EXPORTER_VERSION}/haproxy_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz
tar xzf /tmp/haproxy_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz -C /tmp/
mv /tmp/haproxy_exporter-${EXPORTER_VERSION}.linux-amd64/haproxy_exporter /usr/local/sbin/

cat > /usr/lib/systemd/system/haproxy_exporter.service <<EOF
[Unit]
Description=HAProxy_exporter
After=syslog.target network.target

[Service]
ExecStart=/usr/local/sbin/haproxy_exporter --haproxy.scrape-uri=http://admin:xxxx@localhost:9200/stats;csv
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable haproxy_exporter
systemctl is-enabled haproxy_exporter
systemctl start  haproxy_exporter
systemctl status haproxy_exporter

curl http://127.0.0.1:9101/metrics
```





## 五、常见问题

### 5.1 TSDB被锁

常出现在升级prometheus，或重启prometheus

```bash
~$ kubectl -n kube-server get po
 
prometheus-server-8697db8cc8-4hdpc                                1/2     CrashLoopBackOff   282 (3m27s ago)   23h

~$ kubectl -n kube-server logs -f prometheus-server-8697db8cc8-4hdpc prometheus-server
……
ts=2022-05-13T23:29:02.926Z caller=main.go:1077 level=error err="opening storage failed: lock DB directory: resource temporarily unavailable"
```

进入 `/opt/data/prometheus/server`删除文件`lock`



### 5.2 获取指标

```bash
# apiserver
curl -s $APISERVER/metrics \
  --header "Authorization: Bearer $TOKEN" \
  --cacert /tmp/ca.crt \
  -o metrics.txt
  
# etcd
curl -s https://10.101.11.183:2379/metrics \
  --cert /etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key /etc/kubernetes/pki/etcd/healthcheck-client.key \
  --cacert /etc/kubernetes/pki/etcd/ca.crt
```



### 5.3 获取 etcd's metrices

```bash
# 1. 创建证书
kubectl create secret generic etcd-certs \
  --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  --from-file=/etc/kubernetes/pki/etcd/ca.crt \
  -n kube-server

# 2. helm config
  extraSecretMounts:
    - name: etcd-certs
      mountPath: /var/run/secrets/kubernetes.io/etcd
      secretName: etcd-certs
      readOnly: true

# 3. generic config
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

# 4. create service
# Example 
#   https://books.8ops.top/attachment/prometheus/70-generic-secret.sh
#   https://books.8ops.top/attachment/prometheus/71-prometheus-sd-etcd.yaml
#   kubectl apply -f 70-generic-secret.sh
#   kubectl apply -f 71-prometheus-sd-etcd.yaml
# 
#   kubectl -n kube-system create service clusterip kube-etcd --tcp=2379:2379
kubectl apply -f - << EOF
apiVersion: v1
items:
- apiVersion: v1
  kind: Service
  metadata:
    labels:
      app: kube-etcd
      app.kubernetes.io/name: etcd
    name: kube-etcd
    namespace: kube-system
  spec:
    ports:
    - name: etcd
      port: 2379
      protocol: TCP
      targetPort: 2379
    type: ClusterIP
- apiVersion: v1
  kind: Endpoints
  metadata:
    labels:
      app: kube-etcd
      k8s-app: etcd
    name: kube-etcd
    namespace: kube-system
  subsets:
  - addresses:
    - ip: 10.101.11.240
    - ip: 10.101.11.114
    - ip: 10.101.11.154
    ports:
    - port: 2379
      protocol: TCP
kind: List
EOF

kubectl -n kube-system label services/kube-etcd app.kubernetes.io/name=etcd
kubectl -n kube-system get services/kube-etcd endpoints/kube-etcd

```



### 5.4 删除数据

```bash
# 匹配标签删除数据
curl -X POST -g 'http://localhost:9090/api/v1/admin/tsdb/delete_series?match[]={instance=".*"}'

# 根据时间删除数据
curl -X POST -g 'http://localhost:9090/api/v1/admin/tsdb/delete_series?match[]={instance=".*"}&start<2023-07-01T00:00:00Z&end=2023-07-30T00:00:00Z'
```

