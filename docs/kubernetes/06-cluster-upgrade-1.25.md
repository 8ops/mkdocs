# Upgrade - 1.25

[Reference](06-cluster-upgrade.md)



> 升级前后版本对比

| 软件名称   | 当前版本               | 升级版本               |
| ---------- | ---------------------- | ---------------------- |
| kubeadm    | 1.24.0-00              | 1.25.0-00              |
| kubelet    | 1.24.0-00              | 1.25.0-00              |
| kubernetes | 1.24.0-00              | 1.25.0-00              |
| etcd       | 3.5.3-0                | 3.5.4-0                |
| flannel    | v0.17.0                | v0.19.1                |
| coredns    | v1.8.6                 | v1.9.3                 |
| containerd | 1.5.9-0ubuntu1~20.04.1 | 1.5.9-0ubuntu1~20.04.4 |



[优化访问镜像](10-access-image.md)



## 一、升级二进制

```bash
apt update
apt-mark showhold

# containerd
CONTAINERD_VERSION=1.5.9-0ubuntu1~20.04.4
apt install -y --allow-change-held-packages containerd=${CONTAINERD_VERSION}

# kubernetes
KUBERNETES_VERSION=1.25.0-00
apt install -y --allow-change-held-packages kubeadm=${KUBERNETES_VERSION} kubectl=${KUBERNETES_VERSION} kubelet=${KUBERNETES_VERSION}

# validate
dpkg -l | grep -E "kube|containerd"
containerd --version
kubeadm version

# hold
apt-mark hold containerd kubeadm kubectl kubelet && apt-mark showhold

# lib
ls -l /var/lib/{containerd,etcd,kubelet}
```



## 二、升级集群

```yaml
systemctl restart containerd

# 查看升级计划
kubeadm upgrade plan 

# 升级集群 <仅需要在一台master节点执行一次>
kubeadm upgrade apply v1.25.0

# 重启kubelet <配置未随kubernetes升级>
sed -i 's/pause:3.7/pause:3.8/' /var/lib/kubelet/kubeadm-flags.env
systemctl restart kubelet
systemctl status kubelet

# 依次升级剩下control-plane/node节点
kubeadm upgrade node

# 查看节点组件证书签名
kubeadm certs check-expiration

# 升级coredns <未随kubernetes升级>
kubectl -n kube-system edit deployment.apps/coredns
# hub.8ops.top/google_containers/coredns:v1.8.6 --> v1.9.3

# 查看集群基础组件运行
kubectl -n kube-system get all
```



