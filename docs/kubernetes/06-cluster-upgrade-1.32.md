# Upgrade - v1.32.0

[Reference](06-cluster-upgrade.md)

从v1.25.2之后kubernetes的二进制安装源发生了变化。

```bash
# 经测试支持以下版本
1.32.9-1.1
```



[参考阿里介绍](https://developer.aliyun.com/mirror/kubernetes)

```bash
# APT源预处理 <替换为v1.32>
apt update && apt install -y apt-transport-https

sed -i '/kubernetes/d' /etc/apt/sources.list

export KUBE_VERSION_FOR_APT=v1.32
mkdir -p /etc/apt/keyrings
curl -kfsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBE_VERSION_FOR_APT}/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBE_VERSION_FOR_APT}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt update && apt info kubeadm

```





> 升级前后版本对比

| 软件名称   | 当前版本               | 升级版本               |
| ---------- | ---------------------- | ---------------------- |
| kubeadm     | 1.31.1 | 1.32.9-1.1 |
| kubelet     | 1.31.1        | 1.32.9-1.1 |
| kubernetes  | 1.31.1        | 1.32.9-1.1 |
| etcd        | 3.5.15-0 | 3.5.16-0 （3.5.15-0） |
| flannel     | v0.19.1                | v0.27.3 |
| coredns     | v1.9.3                 | v1.11.3 |
| containerd  | 1.7.12-0ubuntu1~20.04.4 | 1.7.24-0ubuntu1~20.04.2 |



[优化访问镜像](10-access-image.md)



## 一、升级二进制

```bash
# view upgrade plan
kubeadm upgrade plan 

# cp -r /etc/kubernetes{,-$(date +%Y%m%d-01)}
cp -r /etc/kubernetes{,-v1.31}

apt update
apt-mark showhold

# containerd
export CONTAINERD_VERSION=1.7.12-0ubuntu2~20.04.1
apt install -y --allow-change-held-packages containerd=${CONTAINERD_VERSION}

# kubernetes
export KUBE_VERSION_FOR_BINARY=1.32.9-1.1
apt install -y --allow-change-held-packages kubeadm=${KUBE_VERSION_FOR_BINARY} kubectl=${KUBE_VERSION_FOR_BINARY} kubelet=${KUBE_VERSION_FOR_BINARY}

# detect
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
ETCDCTL_API=3 etcdctl member list -w table \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# save snap
ETCDCTL_API=3 etcdctl endpoint status -w table \
  --cluster \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key 

ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /opt/kubernetes/etcd-snap-$(date +%Y%m%d).db

etcdctl snapshot status /opt/kubernetes/etcd-snap-$(date +%Y%m%d).db -w table
# etcdctl snapshot restore /opt/kubernetes/etcd-snap-$(date +%Y%m%d).db ...

systemctl restart containerd

export KUBE_VERSION=v1.32.9
cd /opt/kubernetes

# 查看升级计划 <FW>|从1.32.9开始让使用UpgradeConfiguration进行升级配置

# print default 
kubeadm config print upgrade-defaults | tee kubeadm-upgrade.yaml-${KUBE_VERSION}-default

# vim kubeadm-upgrade.yaml/kubeadm-config.yaml
cp kubeadm-upgrade.yaml-${KUBE_VERSION}-default kubeadm-upgrade.yaml-${KUBE_VERSION}
vim kubeadm-upgrade.yaml-${KUBE_VERSION}
vim kubeadm-config.yaml-${KUBE_VERSION}

# kubeadm upgrade plan/apply
kubeadm config images list --config kubeadm-config.yaml-${KUBE_VERSION}
kubeadm config images pull --config kubeadm-config.yaml-${KUBE_VERSION}
kubeadm upgrade plan --config kubeadm-upgrade.yaml-${KUBE_VERSION}
kubeadm upgrade apply ${KUBE_VERSION} --config kubeadm-upgrade.yaml-${KUBE_VERSION}

# <以上操作仅需要在一台 control-plane 节点执行一次> #

# 重启 kubelet <当版本有变化配置未随 kubernetes 升级>
# 重启后可以通过 kubectl get no 查看节点版本发生了变化
sed -i 's/pause:3.10/pause:3.10/' /var/lib/kubelet/kubeadm-flags.env # v1.32
systemctl restart kubelet
systemctl status kubelet

# 重启containerd <当版本有变化>
sed -i 's/pause:3.10/pause:3.10/' /etc/containerd/config.toml # v1.32
systemctl restart containerd
systemctl status containerd

# 依次升级剩下control-plane/node节点
kubeadm upgrade node

systemctl restart kubelet
systemctl restart containerd

# 查看集群版本
kubectl version 

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

### 3.1 v1.32

kubeadm-config.yaml

```bash
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: "v1.32.9"
imageRepository: hub.8ops.top/google_containers
etcd:
  local:
    dataDir: /var/lib/etcd
    imageRepository: hub.8ops.top/google_containers
dns:
  imageRepository: hub.8ops.top/google_containers
  imageTag: v1.11.3
controlPlaneEndpoint: "10.101.11.110:6443"
networking:
  dnsDomain: cluster.local
  podSubnet: 172.19.0.0/16
  serviceSubnet: 192.168.0.0/16
certificatesDir: /etc/kubernetes/pki
```

kubeadm-upgrade.yaml

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: UpgradeConfiguration
plan:
  kubernetesVersion: "v1.32.9"
  allowRCUpgrades: false
apply:
  imagePullPolicy: IfNotPresent
  imagePullSerial: true
node:
  certificateRenewal: true
  etcdUpgrade: true
timeouts:
  controlPlaneComponentHealthCheck: 4m0s
  discovery: 5m0s
  etcdAPICall: 2m0s
  kubeletHealthCheck: 4m0s
  kubernetesAPICall: 1m0s
  tlsBootstrap: 5m0s
  upgradeManifests: 5m0s
```

Output

```bash
root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm config images list --config kubeadm-config.yaml-${KUBE_VERSION}
hub.8ops.top/google_containers/kube-apiserver:v1.32.9
hub.8ops.top/google_containers/kube-controller-manager:v1.32.9
hub.8ops.top/google_containers/kube-scheduler:v1.32.9
hub.8ops.top/google_containers/kube-proxy:v1.32.9
hub.8ops.top/google_containers/coredns:v1.11.3
hub.8ops.top/google_containers/pause:3.10
hub.8ops.top/google_containers/etcd:3.5.16-0
root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm config images pull --config kubeadm-config.yaml-${KUBE_VERSION}
[config/images] Pulled hub.8ops.top/google_containers/kube-apiserver:v1.32.9
[config/images] Pulled hub.8ops.top/google_containers/kube-controller-manager:v1.32.9
[config/images] Pulled hub.8ops.top/google_containers/kube-scheduler:v1.32.9
[config/images] Pulled hub.8ops.top/google_containers/kube-proxy:v1.32.9
[config/images] Pulled hub.8ops.top/google_containers/coredns:v1.11.3
[config/images] Pulled hub.8ops.top/google_containers/pause:3.10
[config/images] Pulled hub.8ops.top/google_containers/etcd:3.5.16-0
root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm upgrade plan --config kubeadm-upgrade.yaml-${KUBE_VERSION}
[preflight] Running pre-flight checks.
[upgrade/config] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[upgrade/config] Use 'kubeadm init phase upload-config --config your-config.yaml' to re-upload it.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: 1.31.1
[upgrade/versions] kubeadm version: v1.32.9
[upgrade/versions] Target version: v1.32.9
[upgrade/versions] Latest version in the v1.31 series: v1.32.9

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   NODE            CURRENT   TARGET
kubelet     k-kube-lab-01   v1.31.1   v1.32.9
kubelet     k-kube-lab-02   v1.31.1   v1.32.9
kubelet     k-kube-lab-03   v1.31.1   v1.32.9
kubelet     k-kube-lab-08   v1.31.1   v1.32.9
kubelet     k-kube-lab-11   v1.31.1   v1.32.9
kubelet     k-kube-lab-12   v1.31.1   v1.32.9

Upgrade to the latest version in the v1.31 series:

COMPONENT                 NODE            CURRENT    TARGET
kube-apiserver            k-kube-lab-01   v1.31.1    v1.32.9
kube-apiserver            k-kube-lab-02   v1.31.1    v1.32.9
kube-apiserver            k-kube-lab-03   v1.31.1    v1.32.9
kube-controller-manager   k-kube-lab-01   v1.31.1    v1.32.9
kube-controller-manager   k-kube-lab-02   v1.31.1    v1.32.9
kube-controller-manager   k-kube-lab-03   v1.31.1    v1.32.9
kube-scheduler            k-kube-lab-01   v1.31.1    v1.32.9
kube-scheduler            k-kube-lab-02   v1.31.1    v1.32.9
kube-scheduler            k-kube-lab-03   v1.31.1    v1.32.9
kube-proxy                                1.31.1     v1.32.9
CoreDNS                                   v1.11.3    v1.11.3
etcd                      k-kube-lab-01   3.5.15-0   3.5.16-0
etcd                      k-kube-lab-02   3.5.15-0   3.5.16-0
etcd                      k-kube-lab-03   3.5.15-0   3.5.16-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.32.9

_____________________________________________________________________


The table below shows the current state of component configs as understood by this version of kubeadm.
Configs that have a "yes" mark in the "MANUAL UPGRADE REQUIRED" column require manual config upgrade or
resetting to kubeadm defaults before a successful upgrade can be performed. The version to manually
upgrade to is denoted in the "PREFERRED VERSION" column.

API GROUP                 CURRENT VERSION   PREFERRED VERSION   MANUAL UPGRADE REQUIRED
kubeproxy.config.k8s.io   v1alpha1          v1alpha1            no
kubelet.config.k8s.io     v1beta1           v1beta1             no
_____________________________________________________________________
root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm upgrade apply ${KUBE_VERSION} --config kubeadm-upgrade.yaml-${KUBE_VERSION}
[upgrade] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[upgrade] Use 'kubeadm init phase upload-config --config your-config.yaml' to re-upload it.
[upgrade/preflight] Running preflight checks
[upgrade] Running cluster health checks
[upgrade/preflight] You have chosen to upgrade the cluster version to "v1.32.9"
[upgrade/versions] Cluster version: v1.31.1
[upgrade/versions] kubeadm version: v1.32.9
[upgrade] Are you sure you want to proceed? [y/N]: y
[upgrade/preflight] Pulling images required for setting up a Kubernetes cluster
[upgrade/preflight] This might take a minute or two, depending on the speed of your internet connection
[upgrade/preflight] You can also perform this action beforehand using 'kubeadm config images pull'
[upgrade/control-plane] Upgrading your static Pod-hosted control plane to version "v1.32.9" (timeout: 5m0s)...
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests2155881551"
[upgrade/staticpods] Preparing for "etcd" upgrade
[upgrade/staticpods] Renewing etcd-server certificate
[upgrade/staticpods] Renewing etcd-peer certificate
[upgrade/staticpods] Renewing etcd-healthcheck-client certificate
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/etcd.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-17-17-01-54/etcd.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This can take up to 5m0s
[apiclient] Found 3 Pods for label selector component=etcd
[upgrade/staticpods] Component "etcd" upgraded successfully!
[upgrade/etcd] Waiting for etcd to become available
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Renewing apiserver certificate
[upgrade/staticpods] Renewing apiserver-kubelet-client certificate
[upgrade/staticpods] Renewing front-proxy-client certificate
[upgrade/staticpods] Renewing apiserver-etcd-client certificate
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-17-17-01-54/kube-apiserver.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This can take up to 5m0s
[apiclient] Found 3 Pods for label selector component=kube-apiserver
[upgrade/staticpods] Component "kube-apiserver" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Renewing controller-manager.conf certificate
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/kube-controller-manager.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-17-17-01-54/kube-controller-manager.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This can take up to 5m0s
[apiclient] Found 3 Pods for label selector component=kube-controller-manager
[upgrade/staticpods] Component "kube-controller-manager" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Renewing scheduler.conf certificate
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/kube-scheduler.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-17-17-01-54/kube-scheduler.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This can take up to 5m0s
[apiclient] Found 3 Pods for label selector component=kube-scheduler
[upgrade/staticpods] Component "kube-scheduler" upgraded successfully!
[upgrade/control-plane] The control plane instance for this node was successfully upgraded!
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[upgrad/kubeconfig] The kubeconfig files for this node were successfully upgraded!
W1017 17:04:24.746297 2171335 postupgrade.go:117] Using temporary directory /etc/kubernetes/tmp/kubeadm-kubelet-config3372485492 for kubelet config. To override it set the environment variable KUBEADM_UPGRADE_DRYRUN_DIR
[upgrade] Backing up kubelet config file to /etc/kubernetes/tmp/kubeadm-kubelet-config3372485492/config.yaml
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[upgrade/kubelet-config] The kubelet configuration for this node was successfully upgraded!
[upgrade/bootstrap-token] Configuring bootstrap token and cluster-info RBAC rules
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[upgrade/addon] Skipping upgrade of addons because control plane instances [k-kube-lab-02 k-kube-lab-03] have not been upgraded
[upgrade/addon] Skipping upgrade of addons because control plane instances [k-kube-lab-02 k-kube-lab-03] have not been upgraded

[upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.32.9".

[upgrade] Now please proceed with upgrading the rest of the nodes by following the right order.
```



### 3.2 v1.33

kubeadm.yaml

```yaml

```

Output

```bash

```



### 3.3 v1.34

kubeadm.yaml

```yaml
```

Output

```bash
```



