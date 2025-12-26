# Quick Start - Flannel

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
| work-node     | K-KUBE-LAB-08  | 10.101.11.196 |
| work-node     | K-KUBE-LAB-11  | 10.101.11.157 |
| work-node     | K-KUBE-LAB-012 | 10.101.11.250 |



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
CONTAINERD_VERSION=1.5.9-0ubuntu1~20.04.4
apt install -y containerd=${CONTAINERD_VERSION}

apt-mark hold containerd
apt-mark showhold
dpkg -l | grep containerd

# 替换 ctr 运行时
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml-default
cp /etc/containerd/config.toml-default /etc/containerd/config.toml

sed -i 's#sandbox_image.*$#sandbox_image = "hub.8ops.top/google_containers/pause:3.6"#' /etc/containerd/config.toml  
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
kubeadm config print init-defaults > kubeadm-init.yaml-default

kubeadm config images list
kubeadm config images list --config kubeadm-init.yaml
kubeadm config images pull --config kubeadm-init.yaml

kubeadm init --config kubeadm-init.yaml --upload-certs

mkdir -p ~/.kube && ln -s /etc/kubernetes/admin.conf ~/.kube/config 

# 添加节点 control-plane
kubeadm join 10.101.9.111:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:b214dc5d30387ad52c40bcd6ffa0e4bc29d15b488752af6a6ee66996914b8659 \
    --control-plane --certificate-key 629a5accb4cb5f839c004c07658d8fc275fb4145fc1fe44b2011249ac2fc4d83

# 添加节点 work-node
kubeadm join 10.101.9.111:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:b214dc5d30387ad52c40bcd6ffa0e4bc29d15b488752af6a6ee66996914b8659    
```

> 编辑 kubeadm-init.yaml

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
  advertiseAddress: 10.101.9.183
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  name: K-LAB-K8S-MASTER-01
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
controlPlaneEndpoint: 10.101.9.111:6443
networking:
  dnsDomain: cluster.local
  podSubnet: 172.20.0.0/16
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



## 三、应用 Flannel

```bash
#
# Example
#   https://books.8ops.top/attachment/kubernetes/kube-flannel.yaml-v0.19.1
#

kubectl apply -f kube-flannel.yaml
```

> 编辑配置

```bash
……
  net-conf.json: | # relative
    {
      "Network": "172.20.0.0/16",
      "Backend": {
        "Type": "host-gw"
      }
    }
……
    # 镜像替换为私有地址
      initContainers:
      - name: install-cni-plugin
        image: hub.8ops.top/google_containers/flannel-cni-plugin:v1.1.0
        ……
      - name: install-cni
        image: hub.8ops.top/google_containers/flannel:v0.19.1
        ……
      containers:
      - name: kube-flannel
        image: hub.8ops.top/google_containers/flannel:v0.19.1
```



## 四、Addon

### 4.1 Ingress-Nginx

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



### 4.2 Dashboard

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



