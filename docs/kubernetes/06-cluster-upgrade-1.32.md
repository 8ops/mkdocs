# Upgrade - v1.32.0

[Reference](06-cluster-upgrade.md)

从v1.25.2之后kubernetes的二进制安装源发生了变化。

```bash
# 经测试支持以下版本
1.32.9-1.1
1.33.5-1.1
1.34.1-1.1
```



[参考阿里介绍](https://developer.aliyun.com/mirror/kubernetes)

```bash
# APT源预处理 <替换为v1.32>
apt update && apt install -y apt-transport-https

sed -i '/kubernetes/d' /etc/apt/sources.list

export KUBE_VERSION_FOR_APT=v1.34
mkdir -p /etc/apt/keyrings
curl -kfsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBE_VERSION_FOR_APT}/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBE_VERSION_FOR_APT}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt update && apt info kubeadm

```





> 升级前后版本对比

| 软件名称   | 当前版本               | 升级v1.32          | 升级v1.33 | 升级v1.34 |
| ---------- | ---------------------- | ---------------------- | ---------------------- | ---------------------- |
| kubeadm     | 1.31.1 | 1.32.9-1.1 | 1.33.5-1.1 | 1.34.1-1.1 |
| kubelet     | 1.31.1        | 1.32.9-1.1 | 1.33.5-1.1 | 1.34.1-1.1 |
| kubernetes  | 1.31.1        | 1.32.9-1.1 | 1.33.5-1.1 | 1.34.1-1.1 |
| etcd        | 3.5.15-0 | 3.5.16-0 | 3.5.21-0 | 3.6.4-0 |
| flannel     | v0.19.1                | v0.27.3 |  |  |
| coredns     | v1.9.3                 | v1.11.3 | v1.12.0 | v1.12.1 |
| containerd  | 1.7.12-0ubuntu1~20.04.4 | 1.7.24-0ubuntu1~20.04.2 | 1.7.24-0ubuntu1~20.04.2 | 1.7.24-0ubuntu1~20.04.2 |



[优化访问镜像](10-access-image.md)



## 一、升级二进制

```bash
# view upgrade plan
kubeadm upgrade plan 

# cp -r /etc/kubernetes{,-$(date +%Y%m%d-01)}
export KUBE_VERSION_OLD=v1.33
cp -r /etc/kubernetes{,-${KUBE_VERSION_OLD}}

apt update
apt-mark showhold

# containerd
export CONTAINERD_VERSION=1.7.24-0ubuntu1~20.04.2
apt install -y --allow-change-held-packages containerd=${CONTAINERD_VERSION}

# kubernetes
export KUBE_VERSION_FOR_BINARY=1.34.1-1.1
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
etcdctl member list -w table \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# save snap
etcdctl endpoint status -w table \
  --cluster \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key 

export KUBE_VERSION_OLD=v1.33
etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /opt/kubernetes/etcd-snap-${KUBE_VERSION_OLD}-$(date +%Y%m%d).db

# v1.34 后不支持查看status
# etcdctl snapshot status /opt/kubernetes/etcd-snap-${KUBE_VERSION_OLD}-$(date +%Y%m%d).db -w table
# etcdctl snapshot restore /opt/kubernetes/etcd-snap-${KUBE_VERSION_OLD}-$(date +%Y%m%d).db ...

systemctl restart containerd

export KUBE_VERSION=v1.34.1
cd /opt/kubernetes

# 查看升级计划 <FW>|从1.32.9开始让使用UpgradeConfiguration进行升级配置

# print default 
kubeadm config print upgrade-defaults | tee kubeadm-upgrade.yaml-${KUBE_VERSION}-default

# vim kubeadm-upgrade.yaml/kubeadm-config.yaml
cp kubeadm-upgrade.yaml-${KUBE_VERSION}-default kubeadm-upgrade.yaml-${KUBE_VERSION}
vim kubeadm-upgrade.yaml-${KUBE_VERSION}

# kubeadm upgrade plan/apply
kubeadm upgrade plan
vim kubeadm-config.yaml-${KUBE_VERSION}
kubeadm config images list --config kubeadm-config.yaml-${KUBE_VERSION}
kubeadm config images pull --config kubeadm-config.yaml-${KUBE_VERSION}

kubeadm upgrade plan --config kubeadm-upgrade.yaml-${KUBE_VERSION}
kubeadm upgrade apply ${KUBE_VERSION} --config kubeadm-upgrade.yaml-${KUBE_VERSION}

# <以上操作仅需要在一台 control-plane 节点执行一次> #

# 重启 kubelet <当版本有变化配置未随 kubernetes 升级>
# 重启后可以通过 kubectl get no 查看节点版本发生了变化
sed -i 's/pause:3.10/pause:3.10/' /var/lib/kubelet/kubeadm-flags.env # v1.32
sed -i 's/pause:3.10/pause:3.10.1/' /var/lib/kubelet/kubeadm-flags.env # v1.34
systemctl restart kubelet
systemctl status kubelet

# 重启containerd <当版本有变化>
sed -i 's/pause:3.10/pause:3.10/' /etc/containerd/config.toml # v1.32
sed -i 's/pause:3.10/pause:3.10.1/' /etc/containerd/config.toml # v1.34
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

kubeadm-config.yaml

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: "v1.33.5"
imageRepository: hub.8ops.top/google_containers
etcd:
  local:
    dataDir: /var/lib/etcd
    imageRepository: hub.8ops.top/google_containers
dns:
  imageRepository: hub.8ops.top/google_containers
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
  kubernetesVersion: "v1.33.5"
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
hub.8ops.top/google_containers/kube-apiserver:v1.33.5
hub.8ops.top/google_containers/kube-controller-manager:v1.33.5
hub.8ops.top/google_containers/kube-scheduler:v1.33.5
hub.8ops.top/google_containers/kube-proxy:v1.33.5
hub.8ops.top/google_containers/coredns:v1.12.0
hub.8ops.top/google_containers/pause:3.10
hub.8ops.top/google_containers/etcd:3.5.21-0

root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm config images pull --config kubeadm-config.yaml-${KUBE_VERSION}
[config/images] Pulled hub.8ops.top/google_containers/kube-apiserver:v1.33.5
[config/images] Pulled hub.8ops.top/google_containers/kube-controller-manager:v1.33.5
[config/images] Pulled hub.8ops.top/google_containers/kube-scheduler:v1.33.5
[config/images] Pulled hub.8ops.top/google_containers/kube-proxy:v1.33.5
[config/images] Pulled hub.8ops.top/google_containers/coredns:v1.12.0
[config/images] Pulled hub.8ops.top/google_containers/pause:3.10
[config/images] Pulled hub.8ops.top/google_containers/etcd:3.5.21-0

root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm upgrade plan --config kubeadm-upgrade.yaml-${KUBE_VERSION}
[preflight] Running pre-flight checks.
[upgrade/config] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[upgrade/config] Use 'kubeadm init phase upload-config --config your-config-file' to re-upload it.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: 1.32.9
[upgrade/versions] kubeadm version: v1.33.5
[upgrade/versions] Target version: v1.33.5
[upgrade/versions] Latest version in the v1.32 series: v1.33.5

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   NODE            CURRENT   TARGET
kubelet     k-kube-lab-01   v1.32.9   v1.33.5
kubelet     k-kube-lab-02   v1.32.9   v1.33.5
kubelet     k-kube-lab-03   v1.32.9   v1.33.5
kubelet     k-kube-lab-08   v1.32.9   v1.33.5
kubelet     k-kube-lab-11   v1.32.9   v1.33.5
kubelet     k-kube-lab-12   v1.32.9   v1.33.5

Upgrade to the latest version in the v1.32 series:

COMPONENT                 NODE            CURRENT    TARGET
kube-apiserver            k-kube-lab-01   v1.32.9    v1.33.5
kube-apiserver            k-kube-lab-02   v1.32.9    v1.33.5
kube-apiserver            k-kube-lab-03   v1.32.9    v1.33.5
kube-controller-manager   k-kube-lab-01   v1.32.9    v1.33.5
kube-controller-manager   k-kube-lab-02   v1.32.9    v1.33.5
kube-controller-manager   k-kube-lab-03   v1.32.9    v1.33.5
kube-scheduler            k-kube-lab-01   v1.32.9    v1.33.5
kube-scheduler            k-kube-lab-02   v1.32.9    v1.33.5
kube-scheduler            k-kube-lab-03   v1.32.9    v1.33.5
kube-proxy                                1.32.9     v1.33.5
CoreDNS                                   v1.11.3    v1.12.0
etcd                      k-kube-lab-01   3.5.16-0   3.5.21-0
etcd                      k-kube-lab-02   3.5.16-0   3.5.21-0
etcd                      k-kube-lab-03   3.5.16-0   3.5.21-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.33.5

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
[upgrade] Use 'kubeadm init phase upload-config --config your-config-file' to re-upload it.
[upgrade/preflight] Running preflight checks
	[WARNING SystemVerification]: cgroups v1 support is in maintenance mode, please migrate to cgroups v2
[upgrade] Running cluster health checks
[upgrade/preflight] You have chosen to upgrade the cluster version to "v1.33.5"
[upgrade/versions] Cluster version: v1.32.9
[upgrade/versions] kubeadm version: v1.33.5
[upgrade] Are you sure you want to proceed? [y/N]: y
[upgrade/preflight] Pulling images required for setting up a Kubernetes cluster
[upgrade/preflight] This might take a minute or two, depending on the speed of your internet connection
[upgrade/preflight] You can also perform this action beforehand using 'kubeadm config images pull'
[upgrade/control-plane] Upgrading your static Pod-hosted control plane to version "v1.33.5" (timeout: 5m0s)...
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests2651918843"
[upgrade/staticpods] Preparing for "etcd" upgrade
[upgrade/staticpods] Renewing etcd-server certificate
[upgrade/staticpods] Renewing etcd-peer certificate
[upgrade/staticpods] Renewing etcd-healthcheck-client certificate
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/etcd.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-21-11-44-08/etcd.yaml"
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
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-21-11-44-08/kube-apiserver.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This can take up to 5m0s
[apiclient] Found 3 Pods for label selector component=kube-apiserver
[upgrade/staticpods] Component "kube-apiserver" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Renewing controller-manager.conf certificate
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/kube-controller-manager.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-21-11-44-08/kube-controller-manager.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This can take up to 5m0s
[apiclient] Found 3 Pods for label selector component=kube-controller-manager
[upgrade/staticpods] Component "kube-controller-manager" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Renewing scheduler.conf certificate
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/kube-scheduler.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-21-11-44-08/kube-scheduler.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This can take up to 5m0s
[apiclient] Found 3 Pods for label selector component=kube-scheduler
[upgrade/staticpods] Component "kube-scheduler" upgraded successfully!
[upgrade/control-plane] The control plane instance for this node was successfully upgraded!
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[upgrade/kubeconfig] The kubeconfig files for this node were successfully upgraded!
W1021 11:46:43.156714  385011 postupgrade.go:117] Using temporary directory /etc/kubernetes/tmp/kubeadm-kubelet-config2133805764 for kubelet config. To override it set the environment variable KUBEADM_UPGRADE_DRYRUN_DIR
[upgrade] Backing up kubelet config file to /etc/kubernetes/tmp/kubeadm-kubelet-config2133805764/config.yaml
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[upgrade/kubelet-config] The kubelet configuration for this node was successfully upgraded!
[upgrade/bootstrap-token] Configuring bootstrap token and cluster-info RBAC rules
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[upgrade/addon] Skipping upgrade of addons because control plane instances [k-kube-lab-02 k-kube-lab-03] have not been upgraded
[upgrade/addon] Skipping upgrade of addons because control plane instances [k-kube-lab-02 k-kube-lab-03] have not been upgraded

[upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.33.5".

[upgrade] Now please proceed with upgrading the rest of the nodes by following the right order.
```



### 3.3 v1.34

kubeadm-config.yaml

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: "v1.34.1"
imageRepository: hub.8ops.top/google_containers
etcd:
  local:
    dataDir: /var/lib/etcd
    imageRepository: hub.8ops.top/google_containers
dns:
  imageRepository: hub.8ops.top/google_containers
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
  kubernetesVersion: "v1.34.1"
  allowRCUpgrades: false
  etcdUpgrade: true
apply:
  imagePullPolicy: IfNotPresent
  imagePullSerial: true
  etcdUpgrade: true
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
hub.8ops.top/google_containers/kube-apiserver:v1.34.1
hub.8ops.top/google_containers/kube-controller-manager:v1.34.1
hub.8ops.top/google_containers/kube-scheduler:v1.34.1
hub.8ops.top/google_containers/kube-proxy:v1.34.1
hub.8ops.top/google_containers/coredns:v1.12.1
hub.8ops.top/google_containers/pause:3.10.1
hub.8ops.top/google_containers/etcd:3.6.4-0
root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm config images pull --config kubeadm-config.yaml-${KUBE_VERSION}
[config/images] Pulled hub.8ops.top/google_containers/kube-apiserver:v1.34.1
[config/images] Pulled hub.8ops.top/google_containers/kube-controller-manager:v1.34.1
[config/images] Pulled hub.8ops.top/google_containers/kube-scheduler:v1.34.1
[config/images] Pulled hub.8ops.top/google_containers/kube-proxy:v1.34.1
[config/images] Pulled hub.8ops.top/google_containers/coredns:v1.12.1
[config/images] Pulled hub.8ops.top/google_containers/pause:3.10.1
[config/images] Pulled hub.8ops.top/google_containers/etcd:3.6.4-0
root@K-KUBE-LAB-01:/opt/kubernetes# kubeadm upgrade plan --config kubeadm-upgrade.yaml-${KUBE_VERSION}
[preflight] Running pre-flight checks.
[upgrade/config] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[upgrade/config] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: 1.33.5
[upgrade/versions] kubeadm version: v1.34.1
[upgrade/versions] Target version: v1.34.1
[upgrade/versions] Latest version in the v1.33 series: v1.34.1

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   NODE            CURRENT   TARGET
kubelet     k-kube-lab-01   v1.33.5   v1.34.1
kubelet     k-kube-lab-02   v1.33.5   v1.34.1
kubelet     k-kube-lab-03   v1.33.5   v1.34.1
kubelet     k-kube-lab-08   v1.33.5   v1.34.1
kubelet     k-kube-lab-11   v1.33.5   v1.34.1
kubelet     k-kube-lab-12   v1.33.5   v1.34.1

Upgrade to the latest version in the v1.33 series:

COMPONENT                 NODE            CURRENT    TARGET
kube-apiserver            k-kube-lab-01   v1.33.5    v1.34.1
kube-apiserver            k-kube-lab-02   v1.33.5    v1.34.1
kube-apiserver            k-kube-lab-03   v1.33.5    v1.34.1
kube-controller-manager   k-kube-lab-01   v1.33.5    v1.34.1
kube-controller-manager   k-kube-lab-02   v1.33.5    v1.34.1
kube-controller-manager   k-kube-lab-03   v1.33.5    v1.34.1
kube-scheduler            k-kube-lab-01   v1.33.5    v1.34.1
kube-scheduler            k-kube-lab-02   v1.33.5    v1.34.1
kube-scheduler            k-kube-lab-03   v1.33.5    v1.34.1
kube-proxy                                1.33.5     v1.34.1
CoreDNS                                   v1.11.3    v1.12.1
etcd                      k-kube-lab-01   3.5.21-0   3.6.4-0
etcd                      k-kube-lab-02   3.5.21-0   3.6.4-0
etcd                      k-kube-lab-03   3.5.21-0   3.6.4-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.34.1

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
[upgrade] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.
[upgrade/preflight] Running preflight checks
	[WARNING SystemVerification]: cgroups v1 support is in maintenance mode, please migrate to cgroups v2
[upgrade] Running cluster health checks
[upgrade/preflight] You have chosen to upgrade the cluster version to "v1.34.1"
[upgrade/versions] Cluster version: v1.33.5
[upgrade/versions] kubeadm version: v1.34.1
[upgrade] Are you sure you want to proceed? [y/N]: y
[upgrade/preflight] Pulling images required for setting up a Kubernetes cluster
[upgrade/preflight] This might take a minute or two, depending on the speed of your internet connection
[upgrade/preflight] You can also perform this action beforehand using 'kubeadm config images pull'
W1021 17:09:44.553900 1036588 checks.go:830] detected that the sandbox image "hub.8ops.top/google_containers/pause:3.10" of the container runtime is inconsistent with that used by kubeadm. It is recommended to use "hub.8ops.top/google_containers/pause:3.10.1" as the CRI sandbox image.
[upgrade/control-plane] Upgrading your static Pod-hosted control plane to version "v1.34.1" (timeout: 5m0s)...
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests1247406299"
[upgrade/staticpods] Preparing for "etcd" upgrade
[upgrade/staticpods] Renewing etcd-server certificate
[upgrade/staticpods] Renewing etcd-peer certificate
[upgrade/staticpods] Renewing etcd-healthcheck-client certificate
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/etcd.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-21-17-09-44/etcd.yaml"
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
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-21-17-09-44/kube-apiserver.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This can take up to 5m0s
[apiclient] Found 3 Pods for label selector component=kube-apiserver
[upgrade/staticpods] Component "kube-apiserver" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Renewing controller-manager.conf certificate
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/kube-controller-manager.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-21-17-09-44/kube-controller-manager.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This can take up to 5m0s
[apiclient] Found 3 Pods for label selector component=kube-controller-manager
[upgrade/staticpods] Component "kube-controller-manager" upgraded successfully!
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Renewing scheduler.conf certificate
[upgrade/staticpods] Moving new manifest to "/etc/kubernetes/manifests/kube-scheduler.yaml" and backing up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-10-21-17-09-44/kube-scheduler.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This can take up to 5m0s
[apiclient] Found 3 Pods for label selector component=kube-scheduler
[upgrade/staticpods] Component "kube-scheduler" upgraded successfully!
[upgrade/control-plane] The control plane instance for this node was successfully upgraded!
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[upgrade/kubeconfig] The kubeconfig files for this node were successfully upgraded!
W1021 17:12:34.221411 1036588 postupgrade.go:116] Using temporary directory /etc/kubernetes/tmp/kubeadm-kubelet-config305043063 for kubelet config. To override it set the environment variable KUBEADM_UPGRADE_DRYRUN_DIR
[upgrade] Backing up kubelet config file to /etc/kubernetes/tmp/kubeadm-kubelet-config305043063/config.yaml
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/instance-config.yaml"
[patches] Applied patch of type "application/strategic-merge-patch+json" to target "kubeletconfiguration"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[upgrade/kubelet-config] The kubelet configuration for this node was successfully upgraded!
[upgrade/bootstrap-token] Configuring bootstrap token and cluster-info RBAC rules
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[upgrade/addon] Skipping upgrade of addons because control plane instances [k-kube-lab-02 k-kube-lab-03] have not been upgraded
[upgrade/addon] Skipping upgrade of addons because control plane instances [k-kube-lab-02 k-kube-lab-03] have not been upgraded

[upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.34.1".

[upgrade] Now please proceed with upgrading the rest of the nodes by following the right order.

```





## 四、常见问题

### 4.1 cgroup版本迭代

现象

- ubuntu 20.04
- containerd 1.7.24

报错

```bash
# kubeadm upgrade apply
	[WARNING SystemVerification]: cgroups v1 support is in maintenance mode, please migrate to cgroups v2
```

建议通过升级操作（实际升级kernel>5.10.0）ubuntu 24.04还解决此问题。以下方法可能存在兼容性不足。

修复（一键脚本）

```bash
#!/usr/bin/env bash
# migrate-cgroupv2-ubuntu20.04.sh
# 一键迁移 Ubuntu20.04 + containerd 1.7.x 到 cgroup v2 (systemd unified cgroup)
# 设计目标：安全、可回滚、交互式（可 --dry-run）
set -euo pipefail
PROG="$(basename "$0")"
TS="$(date +%F-%H%M%S)"
DRY_RUN=false

usage() {
  cat <<EOF
$PROG  - Migrate node to cgroup v2 (Ubuntu 20.04 + containerd 1.7.x)
Usage:
  sudo $PROG [--dry-run] [-y]
Options:
  --dry-run   : Do checks and show planned changes, do NOT modify files.
  -y          : Non-interactive, auto-approve reboot when required.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -y) AUTO_YES=true ;;
    -h|--help) usage; exit 0 ;;
    *) ;;
  esac
done

AUTO_YES=${AUTO_YES:-false}

if [ "$DRY_RUN" = true ]; then
  echo "=== DRY RUN mode: no files will be modified ==="
fi

# Ensure root
if [ "$(id -u)" -ne 0 ] && [ "$DRY_RUN" = false ]; then
  echo "ERROR: must run as root (or with sudo)"
  exit 2
fi

echo "=== Check environment ==="

KERNEL="$(uname -r)"
echo "Kernel: $KERNEL"

# recommend kernel >= 5.10 but not strictly required
# try to parse major.minor
kernel_major=$(echo "$KERNEL" | awk -F. '{print $1}')
kernel_minor=$(echo "$KERNEL" | awk -F. '{print $2}')
if [ "$kernel_major" -lt 5 ] || { [ "$kernel_major" -eq 5 ] && [ "$kernel_minor" -lt 10 ]; }; then
  echo "WARNING: kernel earlier than 5.10 detected. cgroup v2 support may be limited. Recommended: upgrade kernel to >=5.10 (Ubuntu HWE) before migrating."
fi

# containerd version check
containerd_bin="$(command -v containerd || true)"
containerdctl_bin="$(command -v crictl || true)"
ctr_bin="$(command -v ctr || true)"

if command -v containerd >/dev/null 2>&1; then
  # prefer containerd --version if available; some installations have containerd as socket only
  if containerd --version >/dev/null 2>&1; then
    CV=$(containerd --version | head -n1)
  else
    # fallback to ctr
    if [ -n "$ctr_bin" ]; then
      CV=$(ctr version | head -n1)
    else
      CV="unknown"
    fi
  fi
else
  CV="not-found"
fi
echo "Detected containerd: $CV"

if echo "$CV" | grep -qE '1\.7\.'; then
  echo "containerd 1.7.x detected (good)."
else
  echo "WARNING: containerd version is not clearly 1.7.x. Detected: $CV. Please confirm containerd >= 1.6 recommended for cgroup v2 support."
fi

echo
echo "=== Planned changes (preview) ==="
echo "1) Backup /etc/default/grub -> /etc/default/grub.bak.$TS"
echo "2) Add kernel param: systemd.unified_cgroup_hierarchy=1 to GRUB_CMDLINE_LINUX_DEFAULT if not present"
echo "3) run update-grub"
echo "4) Backup /etc/containerd/config.toml -> /etc/containerd/config.toml.bak.$TS (if exists)"
echo "5) Ensure containerd config has SystemdCgroup = true under plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options"
echo "6) Backup /var/lib/kubelet/config.yaml -> /var/lib/kubelet/config.yaml.bak.$TS (if exists) and set cgroupDriver: systemd"
echo "7) Restart containerd and kubelet after modification (if not DRY_RUN)"
echo "8) Prompt for reboot (required to enable kernel param)."

if [ "$DRY_RUN" = true ]; then
  echo "DRY RUN: Exiting after preview."
  exit 0
fi

read -p "Proceed with migration on this node? (yes/[no]) " ans
if [ "$ans" != "yes" ]; then
  echo "Aborted by user."
  exit 0
fi

echo "=== Backing up files ==="
backup_file() {
  local src="$1"; local dst
  if [ -f "$src" ]; then
    dst="${src}.bak.${TS}"
    echo "Backing up $src -> $dst"
    cp -a "$src" "$dst"
  else
    echo "No $src to backup."
  fi
}

backup_file /etc/default/grub
backup_file /etc/containerd/config.toml
backup_file /var/lib/kubelet/config.yaml

echo
echo "=== Ensure GRUB kernel param: systemd.unified_cgroup_hierarchy=1 ==="
GRUB_FILE="/etc/default/grub"
GRUB_VAR="GRUB_CMDLINE_LINUX_DEFAULT"

current_val=$(awk -F= -v var="$GRUB_VAR" '$1==var {print substr($0, index($0,$2))}' "$GRUB_FILE" 2>/dev/null || true)
# Normalize: remove leading/trailing quotes
current_val=$(echo "$current_val" | sed -E 's/^"//; s/"$//')
if echo "$current_val" | grep -q "systemd.unified_cgroup_hierarchy=1"; then
  echo "GRUB already contains systemd.unified_cgroup_hierarchy=1"
else
  echo "Adding systemd.unified_cgroup_hierarchy=1 to $GRUB_FILE"
  # escape slashes for sed
  esc=$(echo "$current_val" | sed -e 's/[\/&]/\\&/g')
  if grep -q "^${GRUB_VAR}=" "$GRUB_FILE"; then
    # append param inside quotes
    sed -i.bak."${TS}" -E "s|^(${GRUB_VAR}=)(.*)|\1\"\2 systemd.unified_cgroup_hierarchy=1\"|" "$GRUB_FILE"
  else
    # add line
    echo "${GRUB_VAR}=\"${current_val} systemd.unified_cgroup_hierarchy=1\"" >> "$GRUB_FILE"
  fi
  echo "Updated $GRUB_FILE (backup saved as ${GRUB_FILE}.bak.${TS})."
fi

echo
echo "=== containerd config: ensure SystemdCgroup = true ==="
CONFD="/etc/containerd/config.toml"
if [ ! -f "$CONFD" ]; then
  echo "$CONFD does not exist. Generating default config via: containerd config default"
  containerd config default > "$CONFD"
  echo "Default config written to $CONFD"
fi

# Check if SystemdCgroup exists
if grep -q "SystemdCgroup" "$CONFD"; then
  echo "Found existing SystemdCgroup entry. Setting to true."
  sed -i "s/^\s*SystemdCgroup\s*=.*/\t\tSystemdCgroup = true/" "$CONFD" || true
else
  echo "Inserting SystemdCgroup = true under the runc options section."
  # Try to insert after the [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options] line
  awk '
  BEGIN{inserted=0}
  {
    print $0
    if (!inserted && $0 ~ /^\[plugins\."io.containerd.grpc.v1.cri"\.containerd\.runtimes\.runc\.options\]/) {
      # next non-empty line we put the setting if not present
      getline; print $0
      print "\t\tSystemdCgroup = true"
      inserted=1
    }
  }
  END{
    if (!inserted) {
      # fallback: append the section and setting
      print ""
      print "[plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.runc.options]"
      print "\t\tSystemdCgroup = true"
    }
  }' "$CONFD" > "${CONFD}.tmp" && mv "${CONFD}.tmp" "$CONFD"
fi

# show a snippet
echo "---- /etc/containerd/config.toml excerpt (search lines around runc.options) ----"
grep -n -n -E "runtimes.runc.options|SystemdCgroup" -n "$CONFD" || true
echo "------------------------------------------------------------------"

echo
echo "=== kubelet config: ensure cgroupDriver: systemd ==="
KUBELET_CONF="/var/lib/kubelet/config.yaml"
if [ -f "$KUBELET_CONF" ]; then
  if grep -q "cgroupDriver" "$KUBELET_CONF"; then
    sed -i.bak."${TS}" -E "s/^(cgroupDriver:).*/\1 systemd/" "$KUBELET_CONF"
    echo "Replaced existing cgroupDriver in $KUBELET_CONF (backup -> ${KUBELET_CONF}.bak.${TS})"
  else
    # add cgroupDriver at top
    tmpfile="${KUBELET_CONF}.tmp.${TS}"
    echo "cgroupDriver: systemd" > "$tmpfile"
    cat "$KUBELET_CONF" >> "$tmpfile"
    mv "$tmpfile" "$KUBELET_CONF"
    echo "Inserted cgroupDriver: systemd at top of $KUBELET_CONF"
  fi
else
  echo "Note: $KUBELET_CONF not found. If kubelet is configured elsewhere, please ensure kubelet uses cgroupDriver=systemd (e.g. kubeadm kubelet config)."
fi

echo
echo "=== Restarting containerd and kubelet to apply config changes ==="
if systemctl is-active --quiet containerd; then
  systemctl restart containerd
  echo "containerd restarted."
else
  echo "containerd service not active; skipping restart."
fi

if systemctl list-units --type=service | grep -q kubelet; then
  systemctl daemon-reload || true
  systemctl restart kubelet || true
  echo "kubelet restarted (if present)."
else
  echo "kubelet service not found; skipping restart."
fi

echo
echo "=== update-grub to apply kernel command line changes ==="
update-grub

echo
echo "=== Migration steps complete on this node ==="
echo "A reboot is required to enable unified cgroup hierarchy kernel parameter."
if [ "$AUTO_YES" = "true" ]; then
  echo "AUTO_YES set: rebooting now..."
  reboot
else
  read -p "Reboot now? (yes/[no]) " r
  if [ "$r" = "yes" ]; then
    echo "Rebooting..."
    reboot
  else
    echo "Please remember to reboot this node later to enable cgroup v2."
    echo "After reboot, run the verification steps listed below."
  fi
fi

# End of script

```

执行

```bash
chmod +x migrate-cgroupv2-ubuntu20.04.sh
# 查看将要执行的操作（只做检查）
./migrate-cgroupv2-ubuntu20.04.sh --dry-run

# 真正执行并交互式选择是否重启
./migrate-cgroupv2-ubuntu20.04.sh

```

核验

```bash
# 是否启用了 cgroup v2
[ -f /sys/fs/cgroup/cgroup.controllers ] && echo "cgroup v2 enabled" || echo "cgroup v2 NOT enabled"

# containerd 配置是否生效（查看当前运行时信息）
ctr version || true
containerd --version || true

# 查看 containerd runtime info (需要 crictl installed)
crictl info | grep -i cgroup || true

# kubelet 是否运行正常
journalctl -u kubelet -n 200 --no-pager

# 节点状态
kubectl get nodes

# 若出现异常，查看 containerd & kubelet 日志
journalctl -u containerd -n 200 --no-pager
journalctl -u kubelet -n 200 --no-pager

```

### 4.2 coredns 未自动升级

```bash
root@K-KUBE-LAB-01:/opt/kubernetes# kubectl -n kube-system get cm kubeadm-config -o yaml
apiVersion: v1
data:
  ClusterConfiguration: |
    apiServer: {}
    apiVersion: kubeadm.k8s.io/v1beta4
    caCertificateValidityPeriod: 87600h0m0s
    certificateValidityPeriod: 8760h0m0s
    certificatesDir: /etc/kubernetes/pki
    clusterName: kubernetes
    controlPlaneEndpoint: 10.101.11.110:6443
    controllerManager: {}
    dns:
      imageRepository: hub.8ops.top/google_containers
      imageTag: v1.11.3 # 之前某一版本时在kubeadm-config.yaml中固定过
    encryptionAlgorithm: RSA-2048
    etcd:
      local:
        dataDir: /var/lib/etcd
    imageRepository: hub.8ops.top/google_containers
    kind: ClusterConfiguration
    kubernetesVersion: v1.34.1
    networking:
      dnsDomain: cluster.local
      podSubnet: 172.19.0.0/16
      serviceSubnet: 192.168.0.0/16
    proxy: {}
    scheduler: {}
kind: ConfigMap
metadata:
  creationTimestamp: "2024-10-16T07:32:06Z"
  name: kubeadm-config
  namespace: kube-system
  resourceVersion: "74880322"
  uid: d479c592-d763-404e-9e46-283df09bfd22
```

依次尝试

```bash
# 1 apply
kubeadm upgrade apply

# 2 upgrade
kubeadm upgrade node phase addon coredns --kubeconfig /etc/kubernetes/admin.conf --dry-run
kubeadm upgrade node phase addon coredns --kubeconfig /etc/kubernetes/admin.conf

# 3 patch
kubectl -n kube-system patch deployment coredns --type='json' -p="[{'op':'replace','path':'/spec/template/spec/containers/0/image','value':'hub.8ops.top/google_containers/coredns:v1.12.1'}]"


```





