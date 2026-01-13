# Quick Start - Calico

[Reference](01-cluster-init.md)



> 当前各软件版本

| 名称       | 版本    |
| ---------- | ------- |
| ubuntu     | v22.04  |
| kubernetes | v1.25.0 |
| calico     | v3.24.1 |

- 这里操作系统选择 `20.04`



## 一、准备资源

### 1.1 VIP

通过 `haproxy` 代理 `apiserver` 多节点

**10.101.11.110**



### 1.2 服务器

| 角色          | 服务器地址    |
| ------------- | ------------- |
| control-plane | 10.101.11.240 |
| control-plane | 10.101.11.114 |
| control-plane | 10.101.11.154 |
| work-node     | 10.101.11.196 |
| work-node     | 10.101.11.157 |
| work-node     | 10.101.11.250 |



## 二、搭建集群

[Reference](01-cluster-init.md)

> pull repo 

```bash
{
  "registry.cn-hangzhou.aliyuncs.com/google_containers/kube-apiserver:v1.25.0":"hub.8ops.top/google_containers/kube-apiserver",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/kube-controller-manager:v1.25.0":"hub.8ops.top/google_containers/kube-controller-manager",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/kube-scheduler:v1.25.0":"hub.8ops.top/google_containers/kube-scheduler",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/kube-proxy:v1.25.0":"hub.8ops.top/google_containers/kube-proxy",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.8":"hub.8ops.top/google_containers/pause",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/etcd:3.5.4-0":"hub.8ops.top/google_containers/etcd",
  "registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:v1.9.3":"hub.8ops.top/google_containers/coredns"
}
```



### 2.1 初始化环境

```bash
curl -s https://books.8ops.top/attachment/kubernetes/bin/01-init.sh | bash
```



### 2.2 调整lib目录

```bash
# containerd
mkdir -p /data1/lib/containerd && \
    ([ -e /var/lib/containerd ] && mv /var/lib/containerd{,-$(date +%Y%m%d)} || /bin/true) && \
    ln -s /data1/lib/containerd /var/lib/containerd
ls -l /var/lib/containerd

# kubelet
mkdir -p /data1/lib/kubelet && \
    ([ -e /var/lib/kubelet ] && mv /var/lib/kubelet{,-$(date +%Y%m%d)} || /bin/true) && \
    ln -s /data1/lib/kubelet /var/lib/kubelet
ls -l /var/lib/kubelet   

# etcd（仅需要在 control-plane）
mkdir -p /data1/lib/etcd && \
    ([ -e /var/lib/etcd ] && mv /var/lib/etcd{,-$(date +%Y%m%d)} || /bin/true) && \
    ln -s /data1/lib/etcd /var/lib/etcd
ls -l /var/lib/etcd
```



### 2.3 安装容器运行时

```bash
CONTAINERD_VERSION=1.5.9-0ubuntu1~20.04.4
apt install -y containerd=${CONTAINERD_VERSION}

apt-mark hold containerd
apt-mark showhold
dpkg -l | grep containerd

# 替换 ctr 运行时
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml-default
cp /etc/containerd/config.toml-default /etc/containerd/config.toml

sed -i 's#sandbox_image.*$#sandbox_image = "hub.8ops.top/google_containers/pause:3.8"#' /etc/containerd/config.toml  
sed -i 's#SystemdCgroup = false#SystemdCgroup = true#' /etc/containerd/config.toml 
grep -P 'sandbox_image|SystemdCgroup' /etc/containerd/config.toml  
systemctl restart containerd
systemctl status containerd
```



### 2.4 安装 kube 环境

```bash
# kubeadm
KUBERNETES_VERSION=1.25.0-00
apt install -y -q kubeadm=${KUBERNETES_VERSION} kubectl=${KUBERNETES_VERSION} kubelet=${KUBERNETES_VERSION}

apt-mark hold kubeadm kubectl kubelet
apt-mark showhold
dpkg -l | grep kube

# 用于运行 crictl
cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

systemctl restart containerd
crictl images
crictl ps -a

# 初始集群（仅需要在其中一台 control-plane 节点操作）
# config
kubeadm config print init-defaults > kubeadm-init.yaml-v1.25.0-default

kubeadm config images list
kubeadm config images list --config kubeadm-init.yaml-v1.25.0
kubeadm config images pull --config kubeadm-init.yaml-v1.25.0

kubeadm init --config kubeadm-init.yaml-v1.25.0 --upload-certs

mkdir -p ~/.kube && ln -s /etc/kubernetes/admin.conf ~/.kube/config 

# 添加节点 control-plane
kubeadm join 10.101.9.111:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:b214dc5d30387ad52c40bcd6ffa0e4bc29d15b488752af6a6ee66996914b8659 \
    --control-plane --certificate-key 629a5accb4cb5f839c004c07658d8fc275fb4145fc1fe44b2011249ac2fc4d83

# 添加节点 work-node
kubeadm join 10.101.9.111:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:b214dc5d30387ad52c40bcd6ffa0e4bc29d15b488752af6a6ee66996914b8659    
```

> 编辑 kubeadm-init.yaml-v1.25.0

```bash
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 10.101.11.240
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  name: K-KUBE-LAB-01
  taints: null
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns:
  imageRepository: hub.8ops.top/google_containers
  imageTag: v1.9.3
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: hub.8ops.top/google_containers
kind: ClusterConfiguration
kubernetesVersion: 1.25.0
controlPlaneEndpoint: 10.101.11.110:6443
networking:
  dnsDomain: cluster.local
  podSubnet: 172.19.0.0/16
  serviceSubnet: 192.168.0.0/16
scheduler: {}
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
```

### 2.5 优化配置

*optional*

```bash
# kubelet
kubectl -n kube-system edit cm kubelet-config
……
    # GC
    imageGCLowThresholdPercent: 40
    imageGCHighThresholdPercent: 50
    # Resource
    systemReserved:
      cpu: 500m
      memory: 500m
    kubeReserved:
      cpu: 500m
      memory: 500m
    evictionPressureTransitionPeriod: 300s # upgrade
    nodeStatusReportFrequency: 10s         # upgrade
    nodeStatusUpdateFrequency: 10s         # upgrade
    cgroupDriver: systemd
    maxPods: 200
    resolvConf: /etc/resolv.conf
kind: ConfigMap                            # relative
……

# kube-proxy 
# 当flannel采用host-gw时，需要开启ipvs
kubectl -n kube-system edit cm kube-proxy

……
    configSyncPeriod: 5s # upgrade
    mode: "ipvs"         # upgrade
    ipvs:                # relative
      tcpTimeout: 900s   # upgrade
      syncPeriod: 5s     # upgrade
      minSyncPeriod: 5s  # upgrade
……
```



## 三、Install Calico

### 3.1 Helm

[Reference](https://projectcalico.docs.tigera.io/getting-started/kubernetes/helm)

```bash
helm repo add projectcalico https://projectcalico.docs.tigera.io/charts
helm repo update projectcalico
helm search repo tigera-operator
helm show values projectcalico/tigera-operator > calico-tigera-operator.yaml-v3.24.1-default

helm install calico projectcalico/tigera-operator \
  -f calico-tigera-operator.yaml-v3.24.1 \
  -n kube-system \
  --create-namespace \
  --version v3.24.1

helm upgrade --install calico projectcalico/tigera-operator \
  -f calico-tigera-operator.yaml-v3.24.1 \
  -n kube-system \
  --create-namespace \
  --version v3.24.1
```

> 编辑配置

```bash
# vim calico-tigera-operator.yaml-v3.24.1

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 50m
    memory: 64Mi

tigeraOperator:
  image: google_containers/calico-tigera-operator
  version: v1.28.1
  registry: hub.8ops.top
calicoctl:
  image: hub.8ops.top/google_containers/calico-ctl
  tag: v3.24.1
```

<u>遗留问题</u>

1. calico 命名空间 `calico-apiserver` & `calico-system` 不能替换
2. calico 依赖镜像 `calico/cni/controllers` 等5个无法替换成内部地址



### 3.2 原生

`建议`

[Reference](https://projectcalico.docs.tigera.io/getting-started/kubernetes/quickstart)

```bash
# Example
#   https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/calico.yaml
#   https://docs.projectcalico.org/manifests/calico.yaml # 未成功
#   EDIT AFTER
#   https://books.8ops.top/attachment/kubernetes/calico.yaml-v3.24.1
# 
kubectl apply -f calico.yaml-v3.24.1
```

> 编辑配置

```bash
……
            - name: CALICO_IPV4POOL_CIDR
              value: "172.19.0.0/16"
……

# 镜像替换
          image: hub.8ops.top/quay/calico-cni:v3.24.1
          image: hub.8ops.top/quay/calico-cni:v3.24.1
          image: hub.8ops.top/quay/calico-node:v3.24.1
          image: hub.8ops.top/quay/calico-node:v3.24.1
          image: hub.8ops.top/quay/calico-kube-controllers:v3.24.1
```



## 四、Addon

### 4.1 MetalLB

[Reference](103-addons-metallb.md)



### 4.2 Ingress-Nginx

采用 <u>Deployment</u> 资源类型部署，结合 <u>LoadBalancer</u> 方式暴露流量

```bash
INGRESS_NGINX_VERSION=4.2.5
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm search repo ingress-nginx
helm show values ingress-nginx/ingress-nginx > ingress-nginx.yaml-${INGRESS_NGINX_VERSION}-default

# external
# vim ingress-nginx-external.yaml-4.2.5
# e.g. https://books.8ops.top/attachment/kubernetes/helm/ingress-nginx-external.yaml-4.2.5
#

helm install ingress-nginx-external-controller ingress-nginx/ingress-nginx \
    -f ingress-nginx-external.yaml-${INGRESS_NGINX_VERSION} \
    -n kube-server \
    --create-namespace \
    --version ${INGRESS_NGINX_VERSION}
    
helm upgrade --install ingress-nginx-external-controller ingress-nginx/ingress-nginx \
    -f ingress-nginx-external.yaml-${INGRESS_NGINX_VERSION} \
    -n kube-server \
    --create-namespace \
    --version ${INGRESS_NGINX_VERSION}

```

> 切割日志

```bash
# /etc/logrotate.d/nginx
/var/log/nginx/access.log
 {
    su systemd-resolve nginx-ingress
    hourly
    rotate 180
    dateext
    missingok
    notifempty
    compress
    delaycompress
    nomail
    sharedscripts
    postrotate
        for pid in `/bin/pidof nginx `;do
            kill -USR1 ${pid}
        done
    endscript
}
/var/log/nginx/error.log
 {
    su systemd-resolve nginx-ingress
    daily
    rotate 7
    dateext
    missingok
    notifempty
    compress
    delaycompress
    nomail
    sharedscripts
    postrotate
        for pid in `/bin/pidof nginx `;do
            kill -USR1 ${pid}
        done
    endscript
}

# 确保uid=101,gid=82的用户和组存在
groupadd -g 82 nginx-ingress
cd /data1/log/nginx

chown 101.82 * && ls -l 

systemctl start logrotate && ls -l && sleep 5 && systemctl status logrotate

# 调整定时器为小时
sed -i 's/OnCalendar=daily/OnCalendar=hourly/' /lib/systemd/system/logrotate.timer
systemctl daemon-reload && sleep 5 && systemctl status logrotate.timer
```



### 4.3 Dashboard

```bash
KUBERNETES_DASHBOARD_VERSION=5.10.0
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update kubernetes-dashboard
helm search repo kubernetes-dashboard
helm show values kubernetes-dashboard/kubernetes-dashboard > kubernetes-dashboard.yaml-${KUBERNETES_DASHBOARD_VERSION}-default

# vim kubernetes-dashboard.yaml-5.10.0
# e.g. https://books.8ops.top/attachment/kubernetes/helm/kubernetes-dashboard.yaml-5.10.0
# 

helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
    -f kubernetes-dashboard.yaml-${KUBERNETES_DASHBOARD_VERSION} \
    -n kube-server \
    --create-namespace \
    --version ${KUBERNETES_DASHBOARD_VERSION}

helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
    -f kubernetes-dashboard.yaml-${KUBERNETES_DASHBOARD_VERSION} \
    -n kube-server \
    --create-namespace \
    --version ${KUBERNETES_DASHBOARD_VERSION}
    
#----
# create sa for ops
kubectl create serviceaccount dashboard-ops -n kube-server

# binding clusterrole
kubectl create clusterrolebinding dashboard-ops \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-server:dashboard-ops

# create token
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: dashboard-ops-secret
  namespace: kube-server
  annotations:
    kubernetes.io/service-account.name: dashboard-ops
type: kubernetes.io/service-account-token
EOF

# output token
kubectl -n kube-server describe secrets dashboard-ops-secret

```



## 五、常见问题

```bash
# 1, calico-node pod not ready
# 需要开启 firewall port

# 2, first-found 会找主机的第一块网卡，但预设是找"eth*"，所以vm的网卡为ens*会失败，需要如下操作
>> search
- name: IP
  value: "autodetect"
>> add
- name: IP_AUTODETECTION_METHOD
  value: "interface=ens192"  (多网卡用","分隔)

# 3, wget https://github.com/projectcalico/calico/releases/download/v3.28.2/calicoctl-linux-amd64 -o calicoctl
calicoctl -h
calicoctl version
calicoctl node status
```

### 5.1 Calico vs Flannel

| 对比项     | Calico                   | Flannel     |
| ---------- | ------------------------ | ----------- |
| Underlay   | BGP                      | X           |
| Overlay    | vxlan / ipip             | vxlan       |
| Qos        | X                        | X           |
| 效能耗损   | Overlay 20%, Underlay 3% | Overlay 20% |
| 安全策略   | NetworkPolicy            | X           |
| 固定IP/Mac | 支持固定IP               | X           |

