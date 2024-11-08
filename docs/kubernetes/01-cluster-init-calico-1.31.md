# Quick Start - Calico - v1.31.1

[Init](01-cluster-init-calico.md)

[Upgrade](06-cluster-upgrade-1.26.md)



## 一、操作集锦

### 1.1 cluster

```bash
# init
curl -s https://books.8ops.top/attachment/kubernetes/bin/01-init-v1.28.sh | bash

# containerd
sed -i 's#sandbox_image.*$#sandbox_image = "hub.8ops.top/google_containers/pause:3.10"#' /etc/containerd/config.toml  
sed -i 's#SystemdCgroup = false#SystemdCgroup = true#' /etc/containerd/config.toml 
grep -P 'sandbox_image|SystemdCgroup' /etc/containerd/config.toml  
systemctl restart containerd
systemctl status containerd

sed -i '/.registry.mirrors/a \        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."hub.8ops.top"]\n          endpoint = ["https://hub.8ops.top"]' /etc/containerd/config.toml
sed -i '/.registry.configs/a \         [plugins."io.containerd.grpc.v1.cri".registry.configs."hub.8ops.top".tls]\n          insecure_skip_verify = true ' /etc/containerd/config.toml
systemctl restart containerd
crictl pull hub.8ops.top/google_containers/pause:3.10

# kubeadm
kubeadm config images list 
kubeadm config images list --config kubeadm-init.yaml-v1.31.1
kubeadm config images pull --config kubeadm-init.yaml-v1.31.1

registry.k8s.io/kube-apiserver:v1.31.1
registry.k8s.io/kube-controller-manager:v1.31.1
registry.k8s.io/kube-scheduler:v1.31.1
registry.k8s.io/kube-proxy:v1.31.1
registry.k8s.io/coredns/coredns:v1.11.3
registry.k8s.io/pause:3.10
registry.k8s.io/etcd:3.5.15-0

hub.8ops.top/google_containers/kube-apiserver:v1.31.1
hub.8ops.top/google_containers/kube-controller-manager:v1.31.1
hub.8ops.top/google_containers/kube-scheduler:v1.31.1
hub.8ops.top/google_containers/kube-proxy:v1.31.1
hub.8ops.top/google_containers/coredns:v1.11.3
hub.8ops.top/google_containers/pause:3.10
hub.8ops.top/google_containers/etcd:3.5.15-0

kubeadm init --config kubeadm-init.yaml-v1.31.1 --upload-certs

kubeadm join 10.101.11.110:6443 --token abcdef.0123456789abcdef \
	--discovery-token-ca-cert-hash sha256:076a3d987ee738f335cc987732e9306b87e044b3cce8138705ceeccb698acce7 \
	--control-plane --certificate-key 735385a90b3b827dcaba8e5e623eb0937abc53e8c71a806470110aeddf86407d

kubeadm join 10.101.11.110:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:076a3d987ee738f335cc987732e9306b87e044b3cce8138705ceeccb698acce7

# cni's calico
# The following namespaces cannot be used: [calico-system calico-apiserver tigera-system tigera-elasticsearch tigera-compliance tigera-intrusion-detection tigera-dpi tigera-eck-operator tigera-fluentd calico-system tigera-manager]
# helm 安装未解决镜像私有化
helm repo add projectcalico https://projectcalico.docs.tigera.io/charts
helm repo update projectcalico
helm search repo tigera-operator
helm show values projectcalico/tigera-operator --version 3.28.2 > calico.yaml-3.28.2-default

helm upgrade --install calico projectcalico/tigera-operator \
    -f calico.yaml-3.28.2 \
    -n kube-system \
    --create-namespace \
    --version v3.28.2 \
    --debug 2>&1 | tee calico.yaml-3.28.2.out
    
helm -n kube-system uninstall calico

docker.io/calico/cni:v3.28.2
docker.io/calico/csi:v3.28.2
docker.io/calico/kube-controllers:v3.28.2
docker.io/calico/node-driver-registrar:v3.28.2
docker.io/calico/node:v3.28.2
docker.io/calico/pod2daemon-flexvol:v3.28.2
docker.io/calico/typha:v3.28.2

hub.8ops.top/google_containers/calico-typha:v3.28.2
hub.8ops.top/google_containers/calico-node:v3.28.2
hub.8ops.top/google_containers/calico-cni:v3.28.2
hub.8ops.top/google_containers/calico-pod2daemon-flexvol:v3.28.2
hub.8ops.top/google_containers/calico-csi:v3.28.2
hub.8ops.top/google_containers/calico-node-driver-registrar:v3.28.2
hub.8ops.top/google_containers/calico-kube-controllers:v3.28.2

# raw OK
wget https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
```



### 1.2 metallb

```bash
# metallb
helm repo add metallb https://metallb.github.io/metallb
helm repo update metallb
helm search repo metallb
helm show values metallb/metallb --version 0.14.8 > metallb.yaml-0.14.8-default

helm upgrade --install metallb metallb/metallb \
    -f metallb.yaml-0.14.8 \
    --namespace=kube-server \
    --create-namespace \
    --version 0.14.8 \
    --debug 2>&1 | tee metallb.yaml-0.14.8.out

helm -n kube-server uninstall metallb
```



### 1.3 ingress-nginx

```bash
# ingress-nginx
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm search repo ingress-nginx
helm show values ingress-nginx/ingress-nginx --version 4.11.3 > ingress-nginx.yaml-4.11.3-default

helm upgrade --install ingress-nginx-external-controller ingress-nginx/ingress-nginx \
    -f ingress-nginx.yaml-4.11.3 \
    -n kube-server \
    --version 4.11.3 \
    --debug 2>&1 | tee ingress-nginx.yaml-4.11.3.out

helm -n kube-server uninstall ingress-nginx-external-controller

kubectl -n default create secret tls tls-8ops.top \
  --cert=8ops.top.crt \
   --key=8ops.top.key

curl -k -vv --tlsv1.1 --tls-max 1.2  https://echoserver.8ops.top
```



### 1.4 dashboard

```bash
# dashboard
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update kubernetes-dashboard
helm search repo kubernetes-dashboard
helm show values kubernetes-dashboard/kubernetes-dashboard --version 7.8.0 > kubernetes-dashboard.yaml-7.8.0-default

helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
    -f kubernetes-dashboard.yaml-7.8.0 \
    -n kube-server \
    --create-namespace \
    --version 7.8.0 \
    --debug 2>&1 | tee kubernetes-dashboard.yaml-7.8.0.out

kubectl -n kube-server create secret tls tls-8ops.top \
  --cert=8ops.top.crt \
   --key=8ops.top.key
   
kubectl create serviceaccount dashboard-ops -n kube-server

kubectl create clusterrolebinding dashboard-ops \
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

kubectl describe secrets \
  -n kube-server $(kubectl -n kube-server get secret | awk '/dashboard-ops/{print $1}')

```



### 1.5 argo

```bash
helm repo add argoproj https://argoproj.github.io/argo-helm
helm repo update argoproj
helm search repo argo-cd
helm show values argoproj/argo-cd --version 7.6.8 > argo-cd.yaml-7.6.8-default

helm upgrade --install argo-cd argoproj/argo-cd \
    -n kube-server \
    -f argo-cd.yaml-7.6.8 \
    --version 7.6.8 \
    --debug 2>&1 | tee argo-cd.yaml-7.6.8.out

helm -n kube-server uninstall argo-cd

kubectl -n kube-server get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -D; echo 
    
```







## 二、常见问题

```bash
# 1, kube-proxy 报错 failed complete: unrecognized feature gate: SupportIPVSProxyMode

kubectl -n kube-system edit cm kube-proxy
# 移除配置 
featureGates:
  SupportIPVSProxyMode: true

# 2, 更多使用 
# https://docs.projectcalico.org/manifests/calico.yaml
# 网络策略
# 固定 IP
# IP 池

  
```



### 2.1  flannel switch calico

```bash
# 1、查看已安装flannel信息
cat /etc/cni/net.d/10-flannel.conflist

# 2、删除flannel布署资源
kubectl delete -f kube-flannel.yml

# 3、清除flannel遗留信息，在集群各节点清理flannel网络的残留文件
ifconfig cni0 down
ip link delete cni0
ifconfig flannel.1 down
ip link delete flannel.1
rm -rf /var/lib/cni
rm -rf /etc/cni/net.d

# 4、安装 calico

```



