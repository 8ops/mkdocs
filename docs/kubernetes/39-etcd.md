# 实战 | ETCD





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

