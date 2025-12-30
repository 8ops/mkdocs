# Quick Start - Cilium - 1.35

[Reference](01-cluster-init.md)



> 当前各软件版本

| 名称       | 版本   |
| ---------- | ------ |
| ubuntu     | 24.04  |
| kubernetes | 1.35.0 |
| flannel    | 0.27.3 |



## 一、准备资源

### 1.1 VIP

通过 `haproxy` 代理 `apiserver` 多节点

**10.101.11.110**



### 1.2 服务器

| role          | hostname       | ip            |
| ------------- | -------------- | ------------- |
| control-plane | K-KUBE-LAB-01  | 10.101.11.240 |
| control-plane | K-KUBE-LAB-02  | 10.101.11.114 |
| control-plane | K-KUBE-LAB-03  | 10.101.11.154 |
| worker-node   | K-KUBE-LAB-08  | 10.101.11.196 |
| worker-node   | K-KUBE-LAB-11  | 10.101.11.157 |
| worker-node   | K-KUBE-LAB-012 | 10.101.11.250 |



## 二、搭建集群



### 2.1 初始化环境

```bash
 curl -s https://books.8ops.top/attachment/kubernetes/bin/01-init-ubuntu24.04-v1.35.sh | bash
```

### 

```bash
 # 查看系统随开机启动服务
 systemctl list-unit-files --state=enabled
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
CONTAINERD_VERSION=2.2.1-1~ubuntu.24.04~noble
apt install -y containerd.io=${CONTAINERD_VERSION}

apt-mark hold containerd.io
apt-mark showhold
dpkg -l | grep containerd.io

# 使用 crictl 替换 ctr 运行时
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml-default
cp /etc/containerd/config.toml-default /etc/containerd/config.toml

sed -i 's#registry.k8s.io/pause:3.10.1#hub.8ops.top/google_containers/pause:3.10.1#' /etc/containerd/config.toml
sed -i 's#SystemdCgroup = false#SystemdCgroup = true#' /etc/containerd/config.toml
sed -i 's#/etc/containerd/certs.d:/etc/docker/certs.d#/etc/containerd/certs.d#' /etc/containerd/config.toml
grep -P 'pause:|SystemdCgroup' /etc/containerd/config.toml

systemctl restart containerd && systemctl status containerd

# 调整日志级别（debug、info、warn、error、fatal、panic）和 prometheus 监控指标
# 27 [debug]
# 28   address = ''
# 29   uid = 0
# 30   gid = 0
# 31   level = 'warn' # 减少日志噪声
# 32   format = ''
# 33
# 34 [metrics]
# 35   address = ':10254' # 暴露 Prometheus 指标
# 36   grpc_histogram = false
```



> 受信私有CA

```bash
# 1
mkdir -p /etc/containerd/certs.d/hub.8ops.top
cp ca.crt /etc/containerd/certs.d/hub.8ops.top/ca.crt 

systemctl restart containerd && systemctl status containerd

crictl pull hub.8ops.top/google_containers/pause:3.10.1

# 2
mkdir -p /etc/containerd/certs.d/hub.8ops.top
cat > /etc/containerd/certs.d/hub.8ops.top/hosts.toml <<EOF
server = "https://hub.8ops.top"

[host."https://hub.8ops.top"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
EOF

# 临时验证
ctr -n k8s.io images pull \
  hub.8ops.top/google_containers/pause:3.10.1
ctr -n k8s.io images pull \
  --hosts-dir /etc/containerd/certs.d \
  hub.8ops.top/google_containers/pause:3.10.1
ctr -n k8s.io images rm hub.8ops.top/google_containers/pause:3.10.1
ctr -n k8s.io images ls

systemctl restart containerd && systemctl status containerd

crictl pull hub.8ops.top/google_containers/pause:3.10.1
crictl img
crictl rmi hub.8ops.top/google_containers/pause:3.10.1

# systemd-resolved 会干扰解析
systemctl stop systemd-resolved && systemctl disable systemd-resolved
sed -i -e '/^nameserver /i\nameserver 10.101.9.252' -e '/^nameserver 127.0.0.53/d' /etc/resolv.conf
cat /etc/resolv.conf && ping -c 2 hub.8ops.top
```



### 2.4 安装 kube 环境

```bash
# kubeadm
KUBERNETES_VERSION=1.35.0-1.1
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
export KUBE_VERSION=v1.35.0
mkdir -p /opt/kubernetes && cd /opt/kubernetes

kubeadm config print init-defaults > kubeadm-init.yaml-${KUBE_VERSION}-default
cp kubeadm-init.yaml-${KUBE_VERSION}-default kubeadm-init.yaml-${KUBE_VERSION}

kubeadm config images list
kubeadm config images list --config kubeadm-init.yaml-${KUBE_VERSION}
kubeadm config images pull --config kubeadm-init.yaml-${KUBE_VERSION}

# # origin
# registry.k8s.io/kube-apiserver:v1.35.0
# registry.k8s.io/kube-controller-manager:v1.35.0
# registry.k8s.io/kube-scheduler:v1.35.0
# registry.k8s.io/kube-proxy:v1.35.0
# registry.k8s.io/coredns/coredns:v1.13.1
# registry.k8s.io/pause:3.10.1
# registry.k8s.io/etcd:3.6.6-0
#
# # revision
# hub.8ops.top/google_containers/kube-apiserver:v1.35.0
# hub.8ops.top/google_containers/kube-controller-manager:v1.35.0
# hub.8ops.top/google_containers/kube-scheduler:v1.35.0
# hub.8ops.top/google_containers/kube-proxy:v1.35.0
# hub.8ops.top/google_containers/coredns:v1.13.1
# hub.8ops.top/google_containers/pause:3.10.1
# hub.8ops.top/google_containers/etcd:3.6.6-0

kubeadm init --config kubeadm-init.yaml-${KUBE_VERSION} --upload-certs

mkdir -p ~/.kube && ln -s /etc/kubernetes/admin.conf ~/.kube/config 

# 添加节点 control-plane
kubeadm join 10.101.11.110:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:3acfc0056f88d86565bcf482358e62b7729b59192d2faf51f6f553731beb674b \
	--control-plane --certificate-key 7d7617c7635f4e2e32e16c6616bbe21007a6bafd131f7a2417f89be78a915174

# 添加节点 work-node
kubeadm join 10.101.11.110:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:3acfc0056f88d86565bcf482358e62b7729b59192d2faf51f6f553731beb674b  
```

> 编辑 kubeadm-init.yaml-v1.35.0

```bash
apiVersion: kubeadm.k8s.io/v1beta4
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
  imagePullSerial: true
  name: K-KUBE-LAB-01
  taints: null
timeouts:
  controlPlaneComponentHealthCheck: 4m0s
  discovery: 5m0s
  etcdAPICall: 2m0s
  kubeletHealthCheck: 4m0s
  kubernetesAPICall: 1m0s
  tlsBootstrap: 5m0s
  upgradeManifests: 5m0s
---
apiServer: {}
apiVersion: kubeadm.k8s.io/v1beta4
caCertificateValidityPeriod: 87600h0m0s
certificateValidityPeriod: 8760h0m0s
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns:
  imageRepository: hub.8ops.top/google_containers
  imageTag: v1.13.1
encryptionAlgorithm: RSA-2048
etcd:
  local:
    dataDir: /var/lib/etcd
    imageRepository: hub.8ops.top/google_containers
    imageTag: 3.6.6-0
imageRepository: hub.8ops.top/google_containers
kind: ClusterConfiguration
kubernetesVersion: 1.35.0
controlPlaneEndpoint: 10.101.11.110:6443
networking:
  dnsDomain: cluster.local
  podSubnet: 172.19.0.0/16
  serviceSubnet: 192.168.0.0/16
proxy: {}
scheduler: {}
```

### 2.5 优化配置

*required*

#### 2.5.1 cgroup2

为什么必须升级到 cgroup v2

- v1.25+ **官方默认推荐 cgroup v2**

- systemd 已统一使用 v2

- CPU / Memory / IO 调度更精准

- eBPF、Cilium、Sidecar 性能显著提升

```bash
# 1，检测是否支持cgroup2（cgroupfs → v1、cgroup2fs → v2）
stat -fc %T /sys/fs/cgroup

# 2，OS 启用 cgroup v2
sed -i 's#GRUB_CMDLINE_LINUX=""#GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1 cgroup_no_v1=all"#' /etc/default/grub
grep GRUB_CMDLINE_LINUX= /etc/default/grub
update-grub
reboot

# 3，containerd 配置
# /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
systemctl restart containerd

# 4，kubelet 启用 systemd cgroup driver
# /var/lib/kubelet/config.yaml
cgroupDriver: systemd

# 5，验证
kubectl describe node | grep -i Cgroup
ls /sys/fs/cgroup/kubepods.slice/
```



#### 2.5.2 nftables

iptables → nftables 背景

- Ubuntu 22.04 默认 **iptables-nft**
- kube-proxy 支持 nftables backend
- iptables-legacy 与 nft 混用 = **灾难**

```bash
# 1，统一系统防火墙后端
update-alternatives --set iptables /usr/sbin/iptables-nft
update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
update-alternatives --set arptables /usr/sbin/arptables-nft
update-alternatives --set ebtables /usr/sbin/ebtables-nft

update-alternatives --list iptables

update-alternatives --display iptables

iptables -V
iptables v1.8.10 (nf_tables) # v1.8.0+ 自动识别 nf_tables

# 2，kube-proxy nftables 模式
kubectl -n kube-system edit configmap kube-proxy
---
kubeletConfiguration:
  cgroupDriver: systemd
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "iptables"
iptables:
  backend: "nft"

# 3，nftables 基础放行规则（示例）
table inet filter {
  chain input {
    type filter hook input priority 0;
    policy drop;

    iif lo accept
    ct state established,related accept

    tcp dport {22, 6443, 10250, 10257, 10259} accept
    udp dport {4789} accept   # CNI VXLAN（如 Flannel）
  }
}

# v1.35 使用 Cilium（eBPF 模式）
# → 几乎不依赖 iptables/nftables，性能和稳定性最好。

kubectl apply -f kube-proxy.yaml
kubectl -n kube-system rollout restart ds kube-proxy

# 4，应用后验证
# 4.1 
kubectl -n kube-system logs ds/kube-proxy | grep nft
# Using iptables-nft backend

# 4.2 nftables 规则是否存在（确认在使用nftables的判断依据）
nft list ruleset | grep KUBE-SERVICES

# 4.3 确认未混用 legacy
iptables-legacy -L

```

与 CNI 的关系（重点）

| CNI        | nftables 要求               |
| ---------- | --------------------------- |
| Flannel    | VXLAN UDP 4789              |
| Calico     | BGP TCP 179                 |
| Cilium     | **无需 kube-proxy（eBPF）** |
| MetalLB L2 | ARP / NDP 放行              |



kube-proxy ConfigMap 关键配置

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-proxy
  namespace: kube-system
  labels:
    app: kube-proxy
data:
  config.conf: |-
    apiVersion: kubeproxy.config.k8s.io/v1alpha1
    kind: KubeProxyConfiguration

    mode: iptables

    bindAddress: 0.0.0.0
    bindAddressHardFail: false

    clusterCIDR: 172.19.0.0/16

    iptables:
      masqueradeAll: false
      masqueradeBit: 14
      minSyncPeriod: 1s
      syncPeriod: 30s              # ✅ 降低 nft churn

    conntrack:
      maxPerCore: 32768            # ✅ 适合 6 节点
      min: 131072
      tcpEstablishedTimeout: 24h
      tcpCloseWaitTimeout: 1h

    configSyncPeriod: 30s          # ✅ 从 5s → 30s

    clientConnection:
      kubeconfig: /var/lib/kube-proxy/kubeconfig.conf
      qps: 0
      burst: 0

    metricsBindAddress: 127.0.0.1:10249
    healthzBindAddress: 0.0.0.0:10256

```



*optional*

```bash
# kubelet
kubectl -n kube-system get  configmap kubelet-config -o yaml > configmap-kubelet-config.yaml
kubectl -n kube-system edit configmap kubelet-config
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

# kube-proxy 升级为 iptables -> nftables
kubectl -n kube-system get  configmap kube-proxy -o yaml > configmap-kube-proxy.yaml
kubectl -n kube-system edit configmap kube-proxy

```



## 三、应用 Cilium

```bash
CILIUM_VERSION=1.18.5
helm repo add cilium https://helm.cilium.io/
helm repo update cilium
helm search repo cilium
helm show values cilium/cilium \
  --version ${CILIUM_VERSION} > cilium.yaml-${CILIUM_VERSION}-default

cp cilium.yaml-${CILIUM_VERSION}-default cilium.yaml-${CILIUM_VERSION}
vim cilium.yaml-${CILIUM_VERSION}

helm install cilium cilium/cilium \
  -f cilium.yaml-${CILIUM_VERSION} \
  --namespace=kube-system \
  --version ${CILIUM_VERSION} \
  --debug

```



## 四、Addon

### 4.1 MetalLB

```bash
METALLB_VERSION=0.15.3

helm repo add metallb https://metallb.github.io/metallb
helm repo update metallb
helm search repo metallb
helm show values metallb/metallb \
  --version ${METALLB_VERSION} > metallb.yaml-${METALLB_VERSION}-default

helm install metallb metallb/metallb \
  -f metallb.yaml-${METALLB_VERSION} \
  --namespace=kube-server \
  --create-namespace \
  --version ${METALLB_VERSION}

```



### 4.2 Ingress-Nginx

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm search repo ingress-nginx
helm show values ingress-nginx/ingress-nginx > ingress-nginx.yaml-v4.2.3-default

# external
# vim ingress-nginx-external.yaml-v4.2.3
# e.g. https://books.8ops.top/attachment/kubernetes/helm/ingress-nginx-external.yaml-v4.2.3
#
kubectl label node gat-gslab-k8s-node-01 edge=external
helm install ingress-nginx-external-controller ingress-nginx/ingress-nginx \
    -f ingress-nginx-external.yaml-v4.2.3 \
    -n kube-server \
    --create-namespace \
    --version 4.2.3
    
helm upgrade --install ingress-nginx-external-controller ingress-nginx/ingress-nginx \
    -f ingress-nginx-external.yaml-v4.2.3 \
    -n kube-server \
    --create-namespace \
    --version 4.2.3
    
# intrnal
# vim ingress-nginx-internal.yaml-v4.2.3
# e.g. https://books.8ops.top/attachment/kubernetes/helm/ingress-nginx-internal.yaml-v4.2.3
#
kubectl label node gat-gslab-k8s-node-02 edge=internal
helm install ingress-nginx-internal-controller ingress-nginx/ingress-nginx \
    -f ingress-nginx-internal.yaml-v4.2.3 \
    -n kube-server \
    --version 4.2.3

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
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
helm search repo kubernetes-dashboard
helm show values kubernetes-dashboard/kubernetes-dashboard > kubernetes-dashboard.yaml-v5.10.0-default

# vim kubernetes-dashboard.yaml-v5.10.0
# e.g. https://books.8ops.top/attachment/kubernetes/helm/kubernetes-dashboard.yaml-v5.10.0
# 

helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
    -f kubernetes-dashboard.yaml-v5.10.0 \
    -n kube-server \
    --create-namespace \
    --version 5.10.0

helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
    -f kubernetes-dashboard.yaml-v5.10.0 \
    -n kube-server \
    --create-namespace \
    --version 5.10.0
    
# create sa for guest
kubectl create serviceaccount dashboard-guest -n kube-server

# binding clusterrole
kubectl create clusterrolebinding dashboard-guest \
  --clusterrole=view \
  --serviceaccount=kube-server:dashboard-guest

# create token
# kubernetes v1.24.0+ newst 需要主动创建 secret
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: dashboard-guest-secret
  namespace: kube-server
  annotations:
    kubernetes.io/service-account.name: dashboard-guest
type: kubernetes.io/service-account-token
EOF

# output token
kubectl -n kube-server describe secrets dashboard-guest-secret
# 
# kubectl -n kube-server get secrets dashboard-guest-secret -o=jsonpath={.data.token} | \
#   base64 -d
#
# kubectl describe secrets \
#   -n kube-server $(kubectl -n kube-server get secret | awk '/dashboard-guest/{print $1}')

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



