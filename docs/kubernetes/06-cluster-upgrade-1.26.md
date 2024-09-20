# Upgrade - v1.26.0

[Reference](06-cluster-upgrade.md)



从v1.25.2之后kubernetes的二进制安装源发生了变化。

```bash
# 经测试支持以下版本
1.26.15-1.1
1.27.16-1.1
1.28.14-2.1
1.29.9-1.1
1.30.5-1.1
1.31.1-1.1
```



[参考阿里介绍](https://developer.aliyun.com/mirror/kubernetes)

```bash
# APT源预处理 <替换v1.26>

apt update && apt install -y apt-transport-https

sed -i '/kubernetes/d' /etc/apt/sources.list

export KUBE_VERSION_FOR_APT=v1.26
export KUBE_VERSION_FOR_APT=v1.27
export KUBE_VERSION_FOR_APT=v1.28
export KUBE_VERSION_FOR_APT=v1.29
export KUBE_VERSION_FOR_APT=v1.30
export KUBE_VERSION_FOR_APT=v1.31
mkdir -p /etc/apt/keyrings
curl -kfsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBE_VERSION_FOR_APT}/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBE_VERSION_FOR_APT}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt update && apt info kubeadm

```





> 升级前后版本对比

| 软件名称   | 当前版本               | 升级版本               |
| ---------- | ---------------------- | ---------------------- |
| kubeadm     | 1.25.0-00              | 1.26.15-1.1 |
| kubelet     | 1.25.0-00              | 1.26.15-1.1 |
| kubernetes  | 1.25.0-00              | 1.26.15-1.1 |
| etcd        | 3.5.4-0                | 3.5.10 |
| flannel     | v0.19.1                | - |
| coredns     | v1.9.3                 | v1.9.3 |
| containerd  | 1.5.9-0ubuntu1~20.04.4 | 1.7.12-0ubuntu2~20.04.1 |



[优化访问镜像](10-access-image.md)



## 一、升级二进制

```bash
cp -r /etc/kubernetes{,-$(date +%Y%m%d-01)}

apt update
apt-mark showhold

# containerd
export CONTAINERD_VERSION=1.7.12-0ubuntu2~20.04.1
apt install -y --allow-change-held-packages containerd=${CONTAINERD_VERSION}

# kubernetes
export KUBERNETES_VERSION=1.26.15-1.1
export KUBERNETES_VERSION=1.27.16-1.1
export KUBERNETES_VERSION=1.28.14-2.1
export KUBERNETES_VERSION=1.29.9-1.1
export KUBERNETES_VERSION=1.30.5-1.1
export KUBERNETES_VERSION=1.31.1-1.1
apt install -y --allow-change-held-packages kubeadm=${KUBERNETES_VERSION} kubectl=${KUBERNETES_VERSION} kubelet=${KUBERNETES_VERSION}

# validate
dpkg -l | grep -E "kube|containerd"
containerd --version
kubeadm version -o short

# hold
apt-mark hold containerd kubeadm kubectl kubelet && apt-mark showhold

# lib
df -lh / /data1
ls -l /var/lib/{containerd,etcd,kubelet}


```



## 二、升级集群

```bash
systemctl restart containerd

export KUBE_VERSION=v1.26.15
export KUBE_VERSION=v1.27.16
export KUBE_VERSION=v1.28.14
export KUBE_VERSION=v1.29.9
export KUBE_VERSION=v1.30.5
export KUBE_VERSION=v1.31.1
cd /opt/kubernetes

# 查看升级计划 <FW>
kubeadm config print init-defaults | tee kubeadm-init.yaml-${KUBE_VERSION}-defaulta
kubeadm upgrade plan 

cp kubeadm-init.yaml-${KUBE_VERSION}-default kubeadm-init.yaml-${KUBE_VERSION}
vim kubeadm-init.yaml-${KUBE_VERSION}

# 打印原始image
kubeadm config images list

# 打印更新配置文件后的image
kubeadm config images list --config kubeadm-init.yaml-${KUBE_VERSION} -v 5

# 预拉取镜像资源
kubeadm config images pull --config kubeadm-init.yaml-${KUBE_VERSION} -v 5

# 升级集群 
kubeadm upgrade apply ${KUBE_VERSION} --config kubeadm-init.yaml-${KUBE_VERSION} -v 5

# <以上操作仅需要在一台master节点执行一次> #

# 重启kubelet <当版本有变化配置未随kubernetes升级>
sed -i 's/pause:3.8/pause:3.9/' /var/lib/kubelet/kubeadm-flags.env
systemctl restart kubelet
systemctl status kubelet

# 重启containerd <当版本有变化>
sed -i 's/pause:3.8/pause:3.9/' /etc/containerd/config.toml
systemctl restart containerd
systemctl status containerd

# 依次升级剩下control-plane/node节点
kubeadm upgrade node

# 查看集群版本
kubectl version --short

# 查看节点组件证书签名
kubeadm certs check-expiration

# 升级coredns <v1.26后会随kubernetes同步升级>
# 此前版本需要手动编辑：hub.8ops.top/google_containers/coredns:v1.8.6 --> v1.9.3
kubectl -n kube-system edit deployment.apps/coredns

# 查看集群基础组件运行
kubectl -n kube-system get all

# detect etcd
etcdctl endpoint status -w table \
  --cluster \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```



## 三、输出过程

### 3.1 v1.26

```bash
root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm upgrade plan
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: v1.25.0
[upgrade/versions] kubeadm version: v1.26.15
W0920 13:51:19.925772 1997562 version.go:104] could not fetch a Kubernetes version from the internet: unable to get URL "https://dl.k8s.io/release/stable.txt": Get "https://cdn.dl.k8s.io/release/stable.txt": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
W0920 13:51:19.926784 1997562 version.go:105] falling back to the local client version: v1.26.15
[upgrade/versions] Target version: v1.26.15
[upgrade/versions] Latest version in the v1.25 series: v1.25.16

W0920 13:51:22.614798 1997562 configset.go:177] error unmarshaling configuration schema.GroupVersionKind{Group:"kubeproxy.config.k8s.io", Version:"v1alpha1", Kind:"KubeProxyConfiguration"}: strict decoding error: unknown field "udpIdleTimeout"
Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT        TARGET
kubelet     5 x v1.26.15   v1.25.16

Upgrade to the latest version in the v1.25 series:

COMPONENT                 CURRENT   TARGET
kube-apiserver            v1.25.0   v1.25.16
kube-controller-manager   v1.25.0   v1.25.16
kube-scheduler            v1.25.0   v1.25.16
kube-proxy                v1.25.0   v1.25.16
CoreDNS                   v1.9.3    v1.9.3
etcd                      3.5.4-0   3.5.10-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.25.16

_____________________________________________________________________

Upgrade to the latest stable version:

COMPONENT                 CURRENT   TARGET
kube-apiserver            v1.25.0   v1.26.15
kube-controller-manager   v1.25.0   v1.26.15
kube-scheduler            v1.25.0   v1.26.15
kube-proxy                v1.25.0   v1.26.15
CoreDNS                   v1.9.3    v1.9.3
etcd                      3.5.4-0   3.5.10-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.26.15

_____________________________________________________________________


The table below shows the current state of component configs as understood by this version of kubeadm.
Configs that have a "yes" mark in the "MANUAL UPGRADE REQUIRED" column require manual config upgrade or
resetting to kubeadm defaults before a successful upgrade can be performed. The version to manually
upgrade to is denoted in the "PREFERRED VERSION" column.

API GROUP                 CURRENT VERSION   PREFERRED VERSION   MANUAL UPGRADE REQUIRED
kubeproxy.config.k8s.io   v1alpha1          v1alpha1            no
kubelet.config.k8s.io     v1beta1           v1beta1             no
_____________________________________________________________________

root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm config images list
I0920 13:52:48.875674 1998736 version.go:256] remote version is much newer: v1.31.0; falling back to: stable-1.26
W0920 13:52:52.636679 1998736 version.go:104] could not fetch a Kubernetes version from the internet: unable to get URL "https://dl.k8s.io/release/stable-1.26.txt": Get "https://cdn.dl.k8s.io/release/stable-1.26.txt": dial tcp 151.101.109.55:443: connect: connection timed out
W0920 13:52:52.636743 1998736 version.go:105] falling back to the local client version: v1.26.15
registry.k8s.io/kube-apiserver:v1.26.15
registry.k8s.io/kube-controller-manager:v1.26.15
registry.k8s.io/kube-scheduler:v1.26.15
registry.k8s.io/kube-proxy:v1.26.15
registry.k8s.io/pause:3.9
registry.k8s.io/etcd:3.5.10-0
registry.k8s.io/coredns/coredns:v1.9.3

root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm config images list --config kubeadm-init.yaml-${KUBE_VERSION}
hub.8ops.top/google_containers/kube-apiserver:v1.26.0
hub.8ops.top/google_containers/kube-controller-manager:v1.26.0
hub.8ops.top/google_containers/kube-scheduler:v1.26.0
hub.8ops.top/google_containers/kube-proxy:v1.26.0
hub.8ops.top/google_containers/pause:3.9
hub.8ops.top/google_containers/etcd:3.5.10-0
hub.8ops.top/google_containers/coredns:v1.9.3

root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm upgrade apply ${KUBE_VERSION} --config kubeadm-init.yaml-${KUBE_VERSION}
[upgrade/config] Making sure the configuration is correct:
W0920 14:02:59.601766 2006340 common.go:93] WARNING: Usage of the --config flag with kubeadm config types for reconfiguring the cluster during upgrade is not recommended!
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.26.15"
[upgrade/versions] Cluster version: v1.25.0
[upgrade/versions] kubeadm version: v1.26.15
[upgrade] Are you sure you want to proceed? [y/N]: y
[upgrade/prepull] Pulling images required for setting up a Kubernetes cluster
[upgrade/prepull] This might take a minute or two, depending on the speed of your internet connection
[upgrade/prepull] You can also perform this action in beforehand using 'kubeadm config images pull'
[upgrade/apply] Upgrading your Static Pod-hosted control plane to version "v1.26.15" (timeout: 5m0s)...
[upgrade/etcd] Upgrading to TLS for etcd
[upgrade/staticpods] Preparing for "etcd" upgrade
[upgrade/staticpods] Renewing etcd-server certificate
[upgrade/staticpods] Renewing etcd-peer certificate
[upgrade/staticpods] Renewing etcd-healthcheck-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/etcd.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2024-09-20-14-03-32/etcd.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 3 Pods for label selector component=etcd
[upgrade/staticpods] Component "etcd" upgraded successfully!
[upgrade/etcd] Waiting for etcd to become available
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests43573343"
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Renewing apiserver certificate
[upgrade/staticpods] Renewing apiserver-kubelet-client certificate
[upgrade/staticpods] Renewing front-proxy-client certificate
[upgrade/staticpods] Renewing apiserver-etcd-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2024-09-20-14-03-32/kube-apiserver.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 3 Pods for label selector component=kube-apiserver
[upgrade/staticpods] Component "kube-apiserver" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Renewing controller-manager.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-controller-manager.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2024-09-20-14-03-32/kube-controller-manager.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 3 Pods for label selector component=kube-controller-manager
[upgrade/staticpods] Component "kube-controller-manager" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Renewing scheduler.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-scheduler.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2024-09-20-14-03-32/kube-scheduler.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 3 Pods for label selector component=kube-scheduler
[upgrade/staticpods] Component "kube-scheduler" upgraded successfully!
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.26.15". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```



### 3.2 v1.27

```bash
root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm upgrade plan | tee kubeadm-init.yaml-${KUBE_VERSION}-default
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: v1.26.15
[upgrade/versions] kubeadm version: v1.27.16
W0920 14:35:58.460906 2035688 version.go:104] could not fetch a Kubernetes version from the internet: unable to get URL "https://dl.k8s.io/release/stable.txt": Get "https://cdn.dl.k8s.io/release/stable.txt": dial tcp 151.101.77.55:443: connect: connection timed out
W0920 14:35:58.461096 2035688 version.go:105] falling back to the local client version: v1.27.16
[upgrade/versions] Target version: v1.27.16
W0920 14:36:03.708888 2035688 version.go:104] could not fetch a Kubernetes version from the internet: unable to get URL "https://dl.k8s.io/release/stable-1.26.txt": Get "https://cdn.dl.k8s.io/release/stable-1.26.txt": dial tcp 151.101.77.55:443: connect: connection timed out
W0920 14:36:03.708978 2035688 version.go:105] falling back to the local client version: v1.27.16
[upgrade/versions] Latest version in the v1.26 series: v1.27.16

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT        TARGET
kubelet     5 x v1.26.15   v1.27.16

Upgrade to the latest version in the v1.26 series:

COMPONENT                 CURRENT    TARGET
kube-apiserver            v1.26.15   v1.27.16
kube-controller-manager   v1.26.15   v1.27.16
kube-scheduler            v1.26.15   v1.27.16
kube-proxy                v1.26.15   v1.27.16
CoreDNS                   v1.9.3     v1.10.1
etcd                      3.5.10-0   3.5.12-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.27.16

_____________________________________________________________________


The table below shows the current state of component configs as understood by this version of kubeadm.
Configs that have a "yes" mark in the "MANUAL UPGRADE REQUIRED" column require manual config upgrade or
resetting to kubeadm defaults before a successful upgrade can be performed. The version to manually
upgrade to is denoted in the "PREFERRED VERSION" column.

API GROUP                 CURRENT VERSION   PREFERRED VERSION   MANUAL UPGRADE REQUIRED
kubeproxy.config.k8s.io   v1alpha1          v1alpha1            no
kubelet.config.k8s.io     v1beta1           v1beta1             no
_____________________________________________________________________

root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm config images list
W0920 14:41:28.924764 2039862 version.go:104] could not fetch a Kubernetes version from the internet: unable to get URL "https://dl.k8s.io/release/stable-1.txt": Get "https://cdn.dl.k8s.io/release/stable-1.txt": dial tcp 151.101.77.55:443: connect: connection timed out
W0920 14:41:28.924930 2039862 version.go:105] falling back to the local client version: v1.27.16
registry.k8s.io/kube-apiserver:v1.27.16
registry.k8s.io/kube-controller-manager:v1.27.16
registry.k8s.io/kube-scheduler:v1.27.16
registry.k8s.io/kube-proxy:v1.27.16
registry.k8s.io/pause:3.9
registry.k8s.io/etcd:3.5.12-0
registry.k8s.io/coredns/coredns:v1.10.1

root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm config images list --config kubeadm-init.yaml-${KUBE_VERSION}
hub.8ops.top/google_containers/kube-apiserver:v1.27.16
hub.8ops.top/google_containers/kube-controller-manager:v1.27.16
hub.8ops.top/google_containers/kube-scheduler:v1.27.16
hub.8ops.top/google_containers/kube-proxy:v1.27.16
hub.8ops.top/google_containers/pause:3.9
hub.8ops.top/google_containers/etcd:3.5.12-0
hub.8ops.top/google_containers/coredns:v1.10.1

root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm upgrade apply ${KUBE_VERSION} --config kubeadm-init.yaml-${KUBE_VERSION}
[upgrade/config] Making sure the configuration is correct:
W0920 14:47:47.420789 2044537 common.go:93] WARNING: Usage of the --config flag with kubeadm config types for reconfiguring the cluster during upgrade is not recommended!
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.27.16"
[upgrade/versions] Cluster version: v1.26.15
[upgrade/versions] kubeadm version: v1.27.16
[upgrade] Are you sure you want to proceed? [y/N]: y
[upgrade/prepull] Pulling images required for setting up a Kubernetes cluster
[upgrade/prepull] This might take a minute or two, depending on the speed of your internet connection
[upgrade/prepull] You can also perform this action in beforehand using 'kubeadm config images pull'
[upgrade/apply] Upgrading your Static Pod-hosted control plane to version "v1.27.16" (timeout: 5m0s)...
[upgrade/etcd] Upgrading to TLS for etcd
[upgrade/staticpods] Preparing for "etcd" upgrade
[upgrade/staticpods] Renewing etcd-server certificate
[upgrade/staticpods] Renewing etcd-peer certificate
[upgrade/staticpods] Renewing etcd-healthcheck-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/etcd.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2024-09-20-14-48-11/etcd.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 3 Pods for label selector component=etcd
[upgrade/staticpods] Component "etcd" upgraded successfully!
[upgrade/etcd] Waiting for etcd to become available
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests186193418"
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Renewing apiserver certificate
[upgrade/staticpods] Renewing apiserver-kubelet-client certificate
[upgrade/staticpods] Renewing front-proxy-client certificate
[upgrade/staticpods] Renewing apiserver-etcd-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2024-09-20-14-48-11/kube-apiserver.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 3 Pods for label selector component=kube-apiserver
[upgrade/staticpods] Component "kube-apiserver" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Renewing controller-manager.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-controller-manager.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2024-09-20-14-48-11/kube-controller-manager.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 3 Pods for label selector component=kube-controller-manager
[upgrade/staticpods] Component "kube-controller-manager" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Renewing scheduler.conf certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-scheduler.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2024-09-20-14-48-11/kube-scheduler.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[apiclient] Found 3 Pods for label selector component=kube-scheduler
[upgrade/staticpods] Component "kube-scheduler" upgraded successfully!
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[upgrade] Backing up kubelet config file to /etc/kubernetes/tmp/kubeadm-kubelet-config555192007/config.yaml
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.27.16". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.

```



### 3.3 v1.28

```bash

```



### 3.4 v1.29

```bash

```



### 3.5 v1.30

```bash

```



### 3.6 v1.31

```bash

```



