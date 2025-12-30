# Quick Start - Kylin - 1.34

[Reference](01-cluster-init.md)



> 当前各软件版本

| 名称          | 版本    |
| ------------- | ------- |
| ubuntu        | v22.04  |
| kubernetes    | v1.34.1 |
| flannel       | v0.27.3 |
| calico        | v3.30.4 |
| cilium        | 1.17.9  |
| metallb       | 0.15.2  |
| ingress-nginx | 4.13.3  |
| envoy-gateway | 1.6.0   |
| dashboard     | 4.13.3  |



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
curl -s https://books.8ops.top/attachment/kubernetes/bin/01-init-ubuntu20.04-v1.34.sh | bash
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

kubeadm config images list
kubeadm config images list --config kubeadm-init.yaml-${KUBE_VERSION}
kubeadm config images pull --config kubeadm-init.yaml-${KUBE_VERSION}

# kubeadm init --config kubeadm-init.yaml-${KUBE_VERSION} --upload-certs -v 5
# https://books.8ops.top/attachment/kubernetes/kubeadm-init.yaml-v1.34.1
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

| Kylin | 发布时间 | kernel short version | kernel version                  |
| ----- | -------- | -------------------- | ------------------------------- |
| V10   | 2024     | 4.19.90              | 4.19.90-89.17.v2401.ky10.x86_64 |
| V11   | 2025     | 6.6.0                | 6.6.0-32.7.v2505.ky11.x86_64    |



### 3.1 初始化环境

```bash
curl -s https://books.8ops.top/attachment/kubernetes/bin/01-init-kylin11-v1.34.sh | bash
```



### 3.2 调整lib目录

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



### 3.3 安装容器运行时

```bash
# 类CentOS系统
CONTAINERD_VERSION=2.2.0
yum info containerd.io-${CONTAINERD_VERSION}
yum install -y containerd.io-${CONTAINERD_VERSION}

containerd --version

# 替换 ctr 运行时
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml-default
cp /etc/containerd/config.toml-default /etc/containerd/config.toml

sed -i 's#registry.k8s.io/pause:#hub.8ops.top/google_containers/pause:#' /etc/containerd/config.toml
sed -i 's#SystemdCgroup = false#SystemdCgroup = true#' /etc/containerd/config.toml 
grep -P 'sandbox |SystemdCgroup' /etc/containerd/config.toml  	

yum install -y ca-certificates
curl -s -o /etc/pki/ca-trust/source/anchors/xx.crt http://m.8ops.top/cert/xx.crt
md5sum /etc/pki/ca-trust/source/anchors/xx.crt
update-ca-trust extract

systemctl restart containerd
systemctl status containerd
```



> 番外

```bash
yum repolist all
yum --enablerepo=docker-ce-stable info containerd.io
yum --showduplicates list containerd.io --all

CONTAINERD_VERSION=2.2.0-2.el10
yum info containerd.io-${CONTAINERD_VERSION} --enablerepo=docker-ce-stable
yum install -y containerd.io-${CONTAINERD_VERSION} --enablerepo=docker-ce-stable # --allowerasing

containerd version # v10 会报下面的错误
containerd: /usr/lib64/libc.so.6: version `GLIBC_2.32' not found (required by containerd)
containerd: /usr/lib64/libc.so.6: version `GLIBC_2.34' not found (required by containerd)
yum erase containerd -y

# 查看当前 glibc 版本
rpm -q glibc
# 或
ldd --version

# 检查 containerd 二进制需要哪些 GLIBC 符号（如果你已下载容器运行时二进制）
readelf -V /usr/local/bin/containerd 2>/dev/null || readelf -V $(which containerd) 2>/dev/null

# 或用 strings（更直观地查找符号）
strings $(which containerd) | grep GLIBC || true

yum info kubectl --disableexcludes=kubernetes
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

systemctl restart containerd && systemctl restart kubelet
```





### 3.4 安装 kube 环境

```bash
# kubeadm
yum --showduplicates list kubeadm --all --disableexcludes=kubernetes
KUBERNETES_VERSION=1.34.2
yum install -y kubeadm-${KUBERNETES_VERSION} kubectl-${KUBERNETES_VERSION} kubelet-${KUBERNETES_VERSION} \
  --disableexcludes=kubernetes

rpm -qa | grep kube

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
export KUBE_VERSION=v1.34.2
mkdir -p /opt/kubernetes && cd /opt/kubernetes

kubeadm config print init-defaults > kubeadm-init.yaml-${KUBE_VERSION}-default
cp kubeadm-init.yaml-${KUBE_VERSION}-default kubeadm-init.yaml-${KUBE_VERSION}

kubeadm config images list
kubeadm config images list --config kubeadm-init.yaml-${KUBE_VERSION}
kubeadm config images pull --config kubeadm-init.yaml-${KUBE_VERSION}
# registry.k8s.io/kube-apiserver:v1.34.3
# registry.k8s.io/kube-controller-manager:v1.34.3
# registry.k8s.io/kube-scheduler:v1.34.3
# registry.k8s.io/kube-proxy:v1.34.3
# registry.k8s.io/coredns/coredns:v1.12.1
# registry.k8s.io/pause:3.10.1
# registry.k8s.io/etcd:3.6.5-0

# kubeadm init --config kubeadm-init.yaml-${KUBE_VERSION} --upload-certs -v 5
kubeadm init --config kubeadm-init.yaml-${KUBE_VERSION} --upload-certs

mkdir -p ~/.kube && ln -s /etc/kubernetes/admin.conf ~/.kube/config 

# join control-plane
kubeadm join 10.127.4.2:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:65a25ce5f03aad42b7469b80d18c0dbdb09e2076fd64615190814583158fdbee \
    --control-plane --certificate-key 154603190150de8244640c4f4cf53ce43ced2aceb43bd51baae139e0c4eb48e3

# join work-node
kubeadm join 10.127.4.2:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:65a25ce5f03aad42b7469b80d18c0dbdb09e2076fd64615190814583158fdbee	
```



### 3.5 优化配置

```bash
# kylin 系统和软件源的特殊性
systemctl enable containerd kubelet
systemctl start containerd kubelet
systemctl is-enabled containerd kubelet

systemctl status containerd kubelet

ls /usr/libexec/cni /opt/cni/bin/ # 若目录没有刚拷贝
cp -a /usr/libexec/cni/* /opt/cni/bin/
```



## 四、addons

```bash
systemctl restart kubelet && sleep 5 && systemctl restart containerd

# 去除 control-plane 污点
kubectl taint nodes gat-devofc-xc-k8s-01 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes gat-devofc-xc-k8s-02 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes gat-devofc-xc-k8s-03 node-role.kubernetes.io/control-plane:NoSchedule-

# 去除 control-plane 污点
kubectl taint nodes gat-sangfor-xc-k8s-01 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes gat-sangfor-xc-k8s-02 node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes gat-sangfor-xc-k8s-03 node-role.kubernetes.io/control-plane:NoSchedule-
```



> 评测结论

| 操作系统      | ubuntu | kylin | 备注                       |
| ------------- | ------ | ----- | -------------------------- |
| kubernetes    | √      |       |                            |
| cni / flannel | √      |       |                            |
| cni / calico  | x      |       |                            |
| cni / cilium  | √      |       |                            |
| metallb       | mostly |       | frr未就位，service访问不通 |
| ingress-nginx | √      |       |                            |
| envoy-gateway | √      |       |                            |
| dashboard     | √      |       |                            |
| reboot 测试   |        |       |                            |



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
# https://books.8ops.top/attachment/kubernetes/helm/cilium.yaml-1.17.9
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

> 卸载

```bash
ip link delete cni0
rm -rf /var/lib/cni/ /run/flannel/ /etc/cni/net.d 

ip link | awk '/cilium/{print $2}' | sed 's/://' | xargs -I{} sudo ip link delete {}
iptables-save | grep -i cilium
iptables -F && iptables -t nat -F
iptables -X && iptables -t nat -X
iptables-save

ip route show | awk '/cilium/{printf("ip route del %s\n", $1)}' | sh
ip route show | grep cilium

ip link | awk '/cilium/{printf("ip link delete %s \n", $2)}' | sed 's/@.*$//' | sh
ip link | grep cilium

systemctl restart kubelet && sleep 5 && systemctl restart containerd
```



### 4.2 metallb

```bash
# https://books.8ops.top/attachment/kubernetes/helm/metallb.yaml-0.15.2
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

helm upgrade --install metallb metallb/metallb \
  -f metallb.yaml-${METALLB_VERSION} \
  --namespace=kube-server \
  --create-namespace \
  --version ${METALLB_VERSION}

helm -n kube-server uninstall metallb
```



### 4.3 ingress-nginx

```bash
# https://books.8ops.top/attachment/kubernetes/helm/ingress-nginx.yaml-4.13.3
INGRESS_NGINX_VERSION=4.13.3
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm search repo ingress-nginx

helm install ingress-nginx-external-controller \
  ingress-nginx/ingress-nginx \
  -f ingress-nginx.yaml-${INGRESS_NGINX_VERSION} \
  -n kube-server \
  --version ${INGRESS_NGINX_VERSION}
```



### 4.4 envoy-gateway

```bash
# https://books.8ops.top/attachment/kubernetes/helm/envoy-gateway.yaml-1.6.0
GATEWAY_HELM_VERSION=1.6.0
helm show values oci://docker.io/envoyproxy/gateway-helm \
  --version ${GATEWAY_HELM_VERSION} > envoy-gateway.yaml-1.6.0-default

# Install
kubectl apply -f 20-envoy-redis.yaml

helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version ${GATEWAY_HELM_VERSION} \
  -f envoy-gateway.yaml-${GATEWAY_HELM_VERSION} \
  -n envoy-gateway-system \
  --create-namespace 

kubectl apply -f 20-envoy-gateway-quickstart-v1.6.0.yaml
kubectl apply -f 20-3.0-backend-basic.yaml

curl -k -v -H "Host: echo.8ops.top" https://10.101.11.244/echo
curl -k -v -H "Host: echo.8ops.top" https://10.101.11.244/echoserver

curl -k -v -H "Host: echo.u3c.ai" https://10.101.11.244/echo
curl -k -v -H "Host: echo.u3c.ai" https://10.101.11.244/echoserver

```



### 4.5 dashboard

```bash
# https://books.8ops.top/attachment/kubernetes/helm/kubernetes-dashboard.yaml-7.13.0
KUBERNETES_DASHBOARD_VERSION=7.13.0
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update
helm search repo kubernetes-dashboard
helm show values kubernetes-dashboard/kubernetes-dashboard > kubernetes-dashboard.yaml-v5.10.0-default

helm install kubernetes-dashboard \
  kubernetes-dashboard/kubernetes-dashboard \
  -f kubernetes-dashboard.yaml-${KUBERNETES_DASHBOARD_VERSION} \
  -n kube-server \
  --create-namespace \
  --version ${KUBERNETES_DASHBOARD_VERSION}

kubectl create serviceaccount dashboard-ops -n kube-server

kubectl create clusterrolebinding dashboard-ops-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-server:dashboard-ops
  
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

kubectl -n kube-server get secrets dashboard-ops-secret -o=jsonpath={.data.token} | base64 -d; echo
```



### 4.6 prometheus

```bash
PROMETHEUS_VERSION=27.47.0
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
helm search repo prometheus
helm show values prometheus-community/prometheus \
  --version ${PROMETHEUS_VERSION} > prometheus.yaml-${PROMETHEUS_VERSION}-default

helm install prometheus prometheus-community/prometheus \
  -f prometheus.yaml-${PROMETHEUS_VERSION} \
  -f prometheus-extra.yaml \
  -f prometheus-alertmanager.yaml \
  -n kube-server \
  --create-namespace \
  --version ${PROMETHEUS_VERSION} \
  --debug | tee /tmp/debug.out
    
helm upgrade --install prometheus prometheus-community/prometheus \
  -f prometheus.yaml-${PROMETHEUS_VERSION} \
  -f prometheus-extra.yaml \
  -f prometheus-alertmanager.yaml \
  -n kube-server \
  --create-namespace \
  --version ${PROMETHEUS_VERSION} \
  --debug | tee /tmp/debug.out

kubectl apply -f 90-prometheus-metadata-rules.yaml
kubectl apply -f 91-prometheus-metadata-hosts.yaml
```



### 4.7 elasticsearch

```bash
ELASTICSEARCH_VERSION=7.17.3
helm repo add elastic https://helm.elastic.co
helm repo update elastic
helm search repo elastic
helm search repo elastic/elasticsearch --versions # 查看支持的所有版本

helm install elastic-single elastic/elasticsearch \
  -f elastic-single.yaml-${ELASTICSEARCH_VERSION} \
  -n elastic-system\
  --create-namespace \
  --version ${ELASTICSEARCH_VERSION} \
  --debug | tee /tmp/debug.out

helm upgrade --install elastic-single elastic/elasticsearch \
  -f elastic-single.yaml-${ELASTICSEARCH_VERSION} \
  -n elastic-system\
  --create-namespace \
  --version ${ELASTICSEARCH_VERSION} \
  --debug | tee /tmp/debug.out

```



## 五、番外

### 5.1 Endpoints升级

`< 1.33 使用 Endpoints`

```yaml
# Endpoints
- apiVersion: v1
  kind: Endpoints
  metadata:
    name: haproxy
    namespace: kube-server
  subsets:
  - addresses:
    - ip: 10.127.4.2
    ports:
    - name: tcp
      port: 9200
      protocol: TCP
```

`> 1.33 使用 EndpointSlice`

```yaml
# EndpointSlice
- apiVersion: discovery.k8s.io/v1
  kind: EndpointSlice
  addressType: IPv4
  metadata:
    name: haproxy
    namespace: kube-server
    labels:
      kubernetes.io/service-name: haproxy
  ports:
  - name: tcp
    port: 9200
    protocol: TCP
  endpoints:
  - addresses:
    - 10.127.4.2
    conditions:
      ready: true
```



