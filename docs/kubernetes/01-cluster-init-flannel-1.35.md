# Quick Start - Flannel - 1.35

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

#### 2.3.1 apt

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
# 35   address = ':10244' # 暴露 Prometheus 指标 10254会与ingress-nginx's metrics冲突
# 36   grpc_histogram = false
```



#### 2.3.2 binary

```bash
# containerd
CONTAINERD_VERSION=2.2.1
wget https://github.com/containerd/containerd/releases/download/v{CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
tar -xzf containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz -C /usr/local/

cat > /etc/systemd/system/containerd.service <<EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd
Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

# config.toml
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true #此行为添加

# runc
RUNC_VERSION=1.4.0
wget -O /usr/bin/runc https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64
chmod +x /usr/bin/runc

cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
```



#### 2.3.3 受信私有CA

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
kubectl apply -f kube-flannel.yaml-v0.27.4
```

> 编辑配置

```bash
--
  net-conf.json: |
    {
      "Network": "172.20.0.0/16",
      "EnableNFTables": true,
      "Backend": {
        "Type": "vxlan",
        "VNI": 4096,
        "Port": 4789,
        "DirectRouting": true
      },
      "MTU": 1450,
      "IPTables": false
    }
--
      - name: install-cni-plugin
        image: hub.8ops.top/google_containers/flannel-cni-plugin:v1.8.0-flannel1
--
      - name: install-cni
        image: hub.8ops.top/google_containers/flannel:v0.27.4
--
      - name: kube-flannel
        image: hub.8ops.top/google_containers/flannel:v0.27.4
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq=false
        - --kube-subnet-mgr=true

```



## 四、Addon



### 4.1 Ingress-Nginx

```bash
INGRESS_NGINX=4.14.1
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm search repo ingress-nginx
helm show values ingress-nginx/ingress-nginx \
  --version ${INGRESS_NGINX} > ingress-nginx.yaml-${INGRESS_NGINX}-default

helm install ingress-nginx-external-controller ingress-nginx/ingress-nginx \
  -f ingress-nginx.yaml-${INGRESS_NGINX} \
  -n kube-server \
  --create-namespace \
  --version ${INGRESS_NGINX}

kubectl -n kube-server create secret tls tls-8ops.top \
  --cert=8ops.top.crt \
   --key=8ops.top.key \
  --dry-run=client -o yaml > tls-8ops.top.yaml

kubectl -n kube-server exec -it ingress-nginx-external-controller-external-77947d57f4-4mspp -c controller -- bash
id
```

> 切割日志

```bash
# ubuntu 24.04 uid=101 is messagebus
# /etc/logrotate.d/nginx
/var/log/nginx/access.log
/data1/log/nginx/*/access.log
 {
    su messagebus nginx-ingress
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
/data1/log/nginx/*/error.log
 {
    su messagebus nginx-ingress
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
mkdir -p /data1/log/nginx && cd /data1/log/nginx
chown 101:82 * && ls -l 

systemctl start logrotate && ls -l && sleep 5 && systemctl status logrotate

# 调整定时器为小时
command -v logrotate || apt install -y -q logrotate
sed -i 's/OnCalendar=daily/OnCalendar=hourly/' /lib/systemd/system/logrotate.timer
systemctl daemon-reload && sleep 5 && systemctl status logrotate.timer

ls -lt /data1/log/nginx/* && tree /data1/log/nginx
```



### 4.2 Dashboard

```bash
KUBERNETES_DASHBOARD_VERSION=7.14.0
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update kubernetes-dashboard
helm search repo kubernetes-dashboard
helm show values kubernetes-dashboard/kubernetes-dashboard \
  --version ${KUBERNETES_DASHBOARD_VERSION}> kubernetes-dashboard.yaml-${KUBERNETES_DASHBOARD_VERSION}-default

helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
    -f kubernetes-dashboard.yaml-${KUBERNETES_DASHBOARD_VERSION} \
    -n kube-server \
    --create-namespace \
    --version ${KUBERNETES_DASHBOARD_VERSION}

#----
# create sa for guest
kubectl create serviceaccount dashboard-guest -n kube-server

# binding clusterrole
kubectl create clusterrolebinding dashboard-guest \
  --clusterrole=view \
  --serviceaccount=kube-server:dashboard-guest

# create token
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
kubectl -n kube-server get secrets dashboard-guest-secret -o=jsonpath={.data.token} | base64 -d && echo

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
kubectl -n kube-server get secrets dashboard-ops-secret -o=jsonpath={.data.token} | base64 -d && echo
```



### 4.3 ArgoCD

```bash
ARGOCD_VERSION=9.2.4
helm repo add argoproj https://argoproj.github.io/argo-helm
helm repo update argoproj
helm search repo argo-cd
helm show values argoproj/argo-cd \
  --version ${ARGOCD_VERSION} > argocd.yaml-${ARGOCD_VERSION}-default

helm upgrade --install argo-cd argoproj/argo-cd \
  -n kube-server \
  -f argocd.yaml-${ARGOCD_VERSION} \
  --version ${ARGOCD_VERSION}
```

