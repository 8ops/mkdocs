# Quick Start - Kylin

[Reference](01-cluster-init.md)



> 当前各软件版本

| 名称       | 版本    |
| ---------- | ------- |
| ubuntu     | v22.04  |
| kubernetes | v1.34.1 |
| flannel    | v0.27.3 |
| calico     |         |



硬件是H3C的信创裸机，对比在不同操作系统：ubuntu vs kylin。





## 一、准备资源

### 1.1 VIP

通过 `haproxy` 代理 `apiserver` 多节点

**10.101.11.20**



### 1.2 服务器

| 角色          | 服务器地址    |
| ------------- | ------------- |
| control-plane | 10.101.11.164 |
| control-plane | 10.101.11.164 |
| control-plane | 10.101.11.166 |



## 二、Ubuntu

[Reference](01-cluster-init.md)



### 2.1 初始化环境

```bash
curl -s https://books.8ops.top/attachment/kubernetes/bin/01-init-v1.34.sh | bash
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
CONTAINERD_VERSION=1.7.28-0ubuntu1~24.04.1
apt install -y containerd=${CONTAINERD_VERSION}

apt-mark hold containerd
apt-mark showhold
dpkg -l | grep containerd

# 替换 ctr 运行时
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml-default
cp /etc/containerd/config.toml-default /etc/containerd/config.toml

sed -i 's#sandbox_image.*$#sandbox_image = "hub.8ops.top/google_containers/pause:3.10.1"#' /etc/containerd/config.toml  
sed -i 's#SystemdCgroup = false#SystemdCgroup = true#' /etc/containerd/config.toml 
grep -P 'sandbox_image|SystemdCgroup' /etc/containerd/config.toml  
sed -i '/.registry.mirrors/a \        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."hub.8ops.top"]\n          endpoint = ["https://hub.8ops.top"]' /etc/containerd/config.toml
sed -i '/.registry.configs/a \         [plugins."io.containerd.grpc.v1.cri".registry.configs."hub.8ops.top".tls]\n          insecure_skip_verify = true ' /etc/containerd/config.toml
systemctl restart containerd
systemctl status containerd
```



### 2.4 安装 kube 环境

```bash
# kubeadm
KUBERNETES_VERSION=1.34.2-1.1
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
export KUBE_VERSION=v1.34.1
mkdir -p /opt/kubernetes && cd /opt/kubernetes

# # Support Upgrade
# kubeadm config print upgrade-defaults | tee kubeadm-upgrade.yaml-${KUBE_VERSION}-default
# # https://books.8ops.top/attachment/kubernetes/kubeadm-upgrade.yaml-v1.34.1
# 
# vim kubeadm-config.yaml-${KUBE_VERSION}
# # https://books.8ops.top/attachment/kubernetes/kubeadm-config.yaml-v1.34.1
# kubeadm config images list --config kubeadm-config.yaml-${KUBE_VERSION}
# kubeadm config images pull --config kubeadm-config.yaml-${KUBE_VERSION}
# 
# kubeadm upgrade plan --config kubeadm-upgrade.yaml-${KUBE_VERSION}
# kubeadm upgrade apply ${KUBE_VERSION} --config kubeadm-upgrade.yaml-${KUBE_VERSION}

kubeadm config print init-defaults > kubeadm-init.yaml-${KUBE_VERSION}-default
cp kubeadm-init.yaml-${KUBE_VERSION}-default kubeadm-init.yaml-${KUBE_VERSION}
kubeadm init --config kubeadm-init.yaml-${KUBE_VERSION} --upload-certs -v 5
# https://books.8ops.top/attachment/kubernetes/kubeadm-init.yaml-v1.34.1

kubeadm config images list
kubeadm config images list --config kubeadm-init.yaml
kubeadm config images pull --config kubeadm-init.yaml

kubeadm init --config kubeadm-init.yaml --upload-certs

mkdir -p ~/.kube && ln -s /etc/kubernetes/admin.conf ~/.kube/config 

# join control-plane
kubeadm join 10.101.11.20:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:3120bda6edfea64948e5fc27e52dce5d4045b09bd0aa16f0e5cb48a55dc171b5 \
	--control-plane --certificate-key 5453c6031ff44884c8dae2a22a02cb877255646eabbcc79365d26dd2d451944f

# join work-node
kubeadm join 10.101.11.20:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:3120bda6edfea64948e5fc27e52dce5d4045b09bd0aa16f0e5cb48a55dc171b5
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



## 三、Kylin



## 四、addons



```bash
systemctl restart kubelet && sleep 5 && systemctl restart containerd

# 去除 control-plane 污点
kubectl taint nodes gat-devofc-xc-k8s-01 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes gat-devofc-xc-k8s-02 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes gat-devofc-xc-k8s-03 node-role.kubernetes.io/control-plane:NoSchedule-
```



### 4.1 cni

#### 4.1.1 flannel

```bash
# https://books.8ops.top/attachment/kubernetes/kube-flannel.yaml-v0.27.4

kubectl apply -f kube-flannel.yaml-v0.27.4

```

> 关键配置

```bash
……
  net-conf.json: | # relative
    {
      "Network": "172.18.0.0/16",
      "Backend": {
        "Type": "host-gw"
      }
    }
……
    # 镜像替换为私有地址
      initContainers:
      - name: install-cni-plugin
        image: hub.8ops.top/google_containers/flannel-cni-plugin:v1.8.0-flannel1
        ……
      - name: install-cni
        image: hub.8ops.top/google_containers/flannel:v0.27.4
        ……
      containers:
      - name: kube-flannel
        image: hub.8ops.top/google_containers/flannel:v0.27.4
```

> 卸载

```bash
kubectl delete -f kube-flannel.yml-v0.27.4

# remove link
ip link delete cni0
# ip link delete flannel.1
# ip link delete flannel.*

# remove dictory
# rm -f /etc/cni/net.d/10-flannel.conflist /etc/cni/net.d/10-flannel.conf
rm -rf /var/lib/cni/ /run/flannel/ /etc/cni/net.d 

# remove route
# ip route delete 172.18.0.0/16

systemctl restart kubelet && sleep 5 && systemctl restart containerd

```



#### 4.1.2 calico

```bash
# [未成功]
# https://books.8ops.top/attachment/kubernetes/calico.yaml-v3.30.4

kubectl apply -f calico.yaml-v3.30.4
```

> 卸载

```bash
kubectl delete -f calico.yaml-v3.30.4

kubectl delete crd bgppeers.crd.projectcalico.org bgpconfigurations.crd.projectcalico.org \
ippools.crd.projectcalico.org felixconfigurations.crd.projectcalico.org \
clusterinformations.crd.projectcalico.org blockaffinities.crd.projectcalico.org \
hostendpoints.crd.projectcalico.org ipamblocks.crd.projectcalico.org ipamhandles.crd.projectcalico.org \
networkpolicies.crd.projectcalico.org globalnetworkpolicies.crd.projectcalico.org

ip link delete cni0
rm -rf /var/lib/cni/ /run/flannel/ /etc/cni/net.d 
systemctl restart kubelet && sleep 5 && systemctl restart containerd
```



#### 4.1.3 cilium

```bash
CILIUM_VERSION=1.17.9

helm repo add cilium https://helm.cilium.io/
helm repo update cilium
helm search repo cilium
helm show values cilium/cilium \
  --version ${CILIUM_VERSION} > cilium.yaml-${CILIUM_VERSION}-default

helm install cilium cilium/cilium \
  -f cilium.yaml-${CILIUM_VERSION} \
  --namespace=kube-system \
  --version ${CILIUM_VERSION}
```



### 4.2 metallb

```bash
METALLB_VERSION=0.15.2

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

helm -n kube-server uninstall metallb
```



### 4.3 ingress-nginx

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



### 4.4 dashboard

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



