# Quick Start - Calico - v1.31.1

[Init](01-cluster-init-calico.md)

[Upgrade](06-cluster-upgrade-1.26.md)



## 一、操作集锦

```bash
# 初始优化
curl -s https://books.8ops.top/attachment/kubernetes/bin/01-init-v1.28.sh | bash

sed -i 's#sandbox_image.*$#sandbox_image = "hub.8ops.top/google_containers/pause:3.10"#' /etc/containerd/config.toml  
sed -i 's#SystemdCgroup = false#SystemdCgroup = true#' /etc/containerd/config.toml 
grep -P 'sandbox_image|SystemdCgroup' /etc/containerd/config.toml  
systemctl restart containerd
systemctl status containerd

sed -i '/.registry.mirrors/a \        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."hub.8ops.top"]\n          endpoint = ["https://hub.8ops.top"]' /etc/containerd/config.toml
sed -i '/.registry.configs/a \         [plugins."io.containerd.grpc.v1.cri".registry.configs."hub.8ops.top".tls]\n          insecure_skip_verify = true ' /etc/containerd/config.toml
systemctl restart containerd
crictl pull hub.8ops.top/google_containers/pause:3.10

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

# The following namespaces cannot be used: [calico-system calico-apiserver tigera-system tigera-elasticsearch tigera-compliance tigera-intrusion-detection tigera-dpi tigera-eck-operator tigera-fluentd calico-system tigera-manager]
helm upgrade --install tigera-operator projectcalico/tigera-operator \
    -f tigera-operator.yaml-3.28.2 \
    -n kube-system \
    --create-namespace \
    --version v3.28.2 \
    --debug 2>&1 | tee tigera-operator.yaml-3.28.2.out
    
helm -n kube-system uninstall tigera-operator

```



## 二、常见问题

```bash
# kube-proxy 报错 failed complete: unrecognized feature gate: SupportIPVSProxyMode

kubectl -n kube-system edit cm kube-proxy
# 移除配置 
featureGates:
  SupportIPVSProxyMode: true
  
  
  
```


