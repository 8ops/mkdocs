# Upgrade - v1.24.0

[Reference](06-cluster-upgrade.md)



> 升级前后版本对比

| 软件名称   | 当前版本               | 升级版本               |
| ---------- | ---------------------- | ---------------------- |
| kubeadm    | 1.23.6-00              | 1.24.0-00              |
| kubelet    | 1.23.6-00              | 1.24.0-00              |
| kubernetes | 1.23.6-00              | 1.24.0-00              |
| etcd       | 3.5.1                  | 3.5.3-0                |
| flannel    | v0.15.1                | v0.17.0                |
| coredns    | v1.8.6                 | v1.8.6                 |
| containerd | 1.5.9-0ubuntu1~20.04.1 | 1.5.9-0ubuntu1~20.04.1 |



[优化访问镜像](10-access-image.md)



## 一、升级二进制

```bash
apt update
apt-mark showhold

# containerd
apt install -y --allow-change-held-packages containerd=1.5.9-0ubuntu1~20.04.1

# kubernetes
apt install -y --allow-change-held-packages kubeadm=1.24.0-00 kubectl=1.24.0-00 kubelet=1.24.0-00

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
kubeadm upgrade apply v1.24.0 -v 5

# 重启kubelet <配置未随kubernetes升级>
sed -i 's/pause:3.6/pause:3.7/' /var/lib/kubelet/kubeadm-flags.env
systemctl restart kubelet
systemctl status kubelet

# 依次升级剩下control-plane/node节点
kubeadm upgrade node -v 5

# 查看节点组件证书签名
kubeadm certs check-expiration

# 升级coredns <未随kubernetes升级>
kubectl -n kube-system edit deployment.apps/coredns
# hub.8ops.top/google_containers/coredns:1.8.4 --> v1.8.6

# 查看集群基础组件运行
kubectl -n kube-system get all
```



## 三、输出效果

### 3.1 升级二进制

> 升级二进制包

```bash
root@K-KUBE-LAB-01:~# apt install kubeadm=1.23.0-00 kubectl=1.23.0-00 kubelet=1.23.0-00
Reading package lists... Done
Building dependency tree
Reading state information... Done
The following packages will be upgraded:
  kubeadm kubectl kubelet
3 upgraded, 0 newly installed, 0 to remove and 88 not upgraded.
Need to get 37.0 MB of archives.
After this operation, 29.8 MB disk space will be freed.
Get:1 https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 kubelet amd64 1.23.0-00 [19.5 MB]
Get:2 https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 kubectl amd64 1.23.0-00 [8,932 kB]
Get:3 https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main amd64 kubeadm amd64 1.23.0-00 [8,588 kB]
Fetched 37.0 MB in 11s (3,437 kB/s)
(Reading database ... 64615 files and directories currently installed.)
Preparing to unpack .../kubelet_1.23.0-00_amd64.deb ...
Unpacking kubelet (1.23.0-00) over (1.22.2-00) ...
Preparing to unpack .../kubectl_1.23.0-00_amd64.deb ...
Unpacking kubectl (1.23.0-00) over (1.22.2-00) ...
Preparing to unpack .../kubeadm_1.23.0-00_amd64.deb ...
Unpacking kubeadm (1.23.0-00) over (1.22.2-00) ...
Setting up kubectl (1.23.0-00) ...
Setting up kubelet (1.23.0-00) ...
Setting up kubeadm (1.23.0-00) ...
```



> 查验二进制安装情况

```bash
root@K-KUBE-LAB-01:~# dpkg -l | grep kube && kubeadm version
ii  kubeadm                              1.23.0-00                         amd64        Kubernetes Cluster Bootstrapping Tool
ii  kubectl                              1.23.0-00                         amd64        Kubernetes Command Line Tool
ii  kubelet                              1.23.0-00                         amd64        Kubernetes Node Agent
ii  kubernetes-cni                       0.8.7-00                          amd64        Kubernetes CNI
kubeadm version: &version.Info{Major:"1", Minor:"23", GitVersion:"v1.23.0", GitCommit:"ab69524f795c42094a6630298ff53f3c3ebab7f4", GitTreeState:"clean", BuildDate:"2021-12-07T18:15:11Z", GoVersion:"go1.17.3", Compiler:"gc", Platform:"linux/amd64"}

root@K-KUBE-LAB-01:~# apt-mark hold kubeadm kubectl kubelet && apt-mark showhold
kubeadm set on hold.
kubectl set on hold.
kubelet set on hold.
containerd
kubeadm
kubectl
kubelet
```



### 3.2 升级集群

> 查看升级计划

```bash
root@K-KUBE-LAB-01:/opt# kubeadm upgrade plan
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: v1.22.0
[upgrade/versions] kubeadm version: v1.23.0
[upgrade/versions] Target version: v1.23.0
[upgrade/versions] Latest version in the v1.23 series: v1.23.0

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   CURRENT       TARGET
kubelet     5 x v1.23.0   v1.23.0

Upgrade to the latest version in the v1.23 series:

COMPONENT                 CURRENT   TARGET
kube-apiserver            v1.23.0   v1.23.0
kube-controller-manager   v1.23.0   v1.23.0
kube-scheduler            v1.23.0   v1.23.0
kube-proxy                v1.23.0   v1.23.0
CoreDNS                   1.8.4     v1.8.6
etcd                      3.5.1-0   3.5.1-0

You can now apply the upgrade by executing the following command:

	kubeadm upgrade apply v1.23.0

Note: Before you can perform this upgrade, you have to update kubeadm to v1.23.0.

_____________________________________________________________________


The table below shows the current state of component configs as understood by this version of kubeadm.
Configs that have a "yes" mark in the "MANUAL UPGRADE REQUIRED" column require manual config upgrade or
resetting to kubeadm defaults before a successful upgrade can be performed. The version to manually
upgrade to is denoted in the "PREFERRED VERSION" column.

API GROUP                 CURRENT VERSION   PREFERRED VERSION   MANUAL UPGRADE REQUIRED
kubeproxy.config.k8s.io   v1alpha1          v1alpha1            no
kubelet.config.k8s.io     v1beta1           v1beta1             no
_____________________________________________________________________
```



> 升级集群

```bash
root@K-KUBE-LAB-01:/opt# kubeadm upgrade apply v1.23.0
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.23.0"
[upgrade/versions] Cluster version: v1.23.0
[upgrade/versions] kubeadm version: v1.23.0
[upgrade/confirm] Are you sure you want to proceed with the upgrade? [y/N]: y
[upgrade/prepull] Pulling images required for setting up a Kubernetes cluster
[upgrade/prepull] This might take a minute or two, depending on the speed of your internet connection
[upgrade/prepull] You can also perform this action in beforehand using 'kubeadm config images pull'
[upgrade/apply] Upgrading your Static Pod-hosted control plane to version "v1.23.0"...
Static pod: kube-apiserver-k-kube-lab-01 hash: e300612cfc9bddbfe269ef9f69c6a68f
Static pod: kube-controller-manager-k-kube-lab-01 hash: 852bdcee5effb8966c5dfb63a6d52e1b
Static pod: kube-scheduler-k-kube-lab-01 hash: 0f85f2476aad9da7c200af3e1f1151b3
[upgrade/etcd] Upgrading to TLS for etcd
Static pod: etcd-k-kube-lab-01 hash: 22ac6fef1edf96d0d47ae64814294c48
[upgrade/staticpods] Preparing for "etcd" upgrade
[upgrade/staticpods] Current and new manifests of etcd are equal, skipping upgrade
[upgrade/etcd] Waiting for etcd to become available
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests2109837075"
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Current and new manifests of kube-apiserver are equal, skipping upgrade
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Current and new manifests of kube-controller-manager are equal, skipping upgrade
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Current and new manifests of kube-scheduler are equal, skipping upgrade
[upgrade/postupgrade] Applying label node-role.kubernetes.io/control-plane='' to Nodes with label node-role.kubernetes.io/master='' (deprecated)
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.23" in namespace kube-system with the configuration for the kubelets in the cluster
NOTE: The "kubelet-config-1.23" naming of the kubelet ConfigMap is deprecated. Once the UnversionedKubeletConfigMap feature gate graduates to Beta the default name will become just "kubelet-config". Kubeadm upgrade will handle this transition transparently.
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.23.0". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```



> 重启kubelet

```bash
root@K-KUBE-LAB-01:/opt# cat /var/lib/kubelet/kubeadm-flags.env
KUBELET_KUBEADM_ARGS="--container-runtime=remote --container-runtime-endpoint=/run/containerd/containerd.sock --pod-infra-container-image=hub.8ops.top/google_containers/pause:3.6"
```



> 升级control-plane节点

```bash
[upgrade] Reading configuration from the cluster...
[upgrade] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[upgrade] Upgrading your Static Pod-hosted control plane instance to version "v1.23.0"...
Static pod: kube-apiserver-k-kube-lab-02 hash: 72ef403458c0e6cc4a2a881a7a1e87a1
Static pod: kube-controller-manager-k-kube-lab-02 hash: 091e5187c5ddc3ba94ea9972160ab10f
Static pod: kube-scheduler-k-kube-lab-02 hash: bc1ed2e4c30353dc774c55cd248bfe8e
[upgrade/etcd] Upgrading to TLS for etcd
Static pod: etcd-k-kube-lab-02 hash: 64eadc3c867a01c762c2266ad4b7112a
[upgrade/staticpods] Preparing for "etcd" upgrade
[upgrade/staticpods] Current and new manifests of etcd are equal, skipping upgrade
[upgrade/etcd] Waiting for etcd to become available
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests1190914493"
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Current and new manifests of kube-apiserver are equal, skipping upgrade
[upgrade/staticpods] Preparing for "kube-controller-manager" upgrade
[upgrade/staticpods] Current and new manifests of kube-controller-manager are equal, skipping upgrade
[upgrade/staticpods] Preparing for "kube-scheduler" upgrade
[upgrade/staticpods] Current and new manifests of kube-scheduler are equal, skipping upgrade
[upgrade] The control plane instance for this node was successfully updated!
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[upgrade] The configuration for this node was successfully updated!
[upgrade] Now you should go ahead and upgrade the kubelet package using your package manager.
```



> 升级node节点

```bash
[upgrade] Reading configuration from the cluster...
[upgrade] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks
[preflight] Skipping prepull. Not a control plane node.
[upgrade] Skipping phase. Not a control plane node.
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[upgrade] The configuration for this node was successfully updated!
[upgrade] Now you should go ahead and upgrade the kubelet package using your package manager.
```



> 查看节点组件证书签名

```bash
root@K-KUBE-LAB-01:~# kubeadm certs check-expiration
[check-expiration] Reading configuration from the cluster...
[check-expiration] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'

CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Dec 23, 2022 02:44 UTC   364d                                    no
apiserver                  Dec 23, 2022 02:27 UTC   364d            ca                      no
apiserver-etcd-client      Dec 23, 2022 02:27 UTC   364d            etcd-ca                 no
apiserver-kubelet-client   Dec 23, 2022 02:27 UTC   364d            ca                      no
controller-manager.conf    Dec 23, 2022 02:28 UTC   364d                                    no
etcd-healthcheck-client    Dec 23, 2022 02:27 UTC   364d            etcd-ca                 no
etcd-peer                  Dec 23, 2022 02:27 UTC   364d            etcd-ca                 no
etcd-server                Dec 23, 2022 02:27 UTC   364d            etcd-ca                 no
front-proxy-client         Dec 23, 2022 02:27 UTC   364d            front-proxy-ca          no
scheduler.conf             Dec 23, 2022 02:28 UTC   364d                                    no

CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Dec 08, 2031 05:54 UTC   9y              no
etcd-ca                 Dec 08, 2031 05:54 UTC   9y              no
front-proxy-ca          Dec 08, 2031 05:54 UTC   9y              no
```



> 查看coredns运行

```bash
root@K-KUBE-LAB-02:~# kubectl -n kube-system get all -l k8s-app=kube-dns -o wide
NAME                           READY   STATUS    RESTARTS   AGE   IP            NODE            NOMINATED NODE   READINESS GATES
pod/coredns-7b8886d7cd-c27r6   1/1     Running   0          40s   172.20.4.14   k-kube-lab-05   <none>           <none>
pod/coredns-7b8886d7cd-k2jcf   1/1     Running   0          40s   172.20.2.3    k-kube-lab-03   <none>           <none>

NAME               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                  AGE   SELECTOR
service/kube-dns   ClusterIP   192.168.0.10   <none>        53/UDP,53/TCP,9153/TCP   12d   k8s-app=kube-dns

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                         SELECTOR
deployment.apps/coredns   2/2     2            2           12d   coredns      hub.8ops.top/google_containers/coredns:1.8.6   k8s-app=kube-dns

NAME                                 DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES                                         SELECTOR
replicaset.apps/coredns-56745ff78    0         0         0       12d   coredns      hub.8ops.top/google_containers/coredns:1.8.4   k8s-app=kube-dns,pod-template-hash=56745ff78
replicaset.apps/coredns-7b8886d7cd   2         2         2       35m   coredns      hub.8ops.top/google_containers/coredns:1.8.6   k8s-app=kube-dns,pod-template-hash=7b8886d7cd
```



> 查看集群基础组件运行

```bash
root@K-KUBE-LAB-01:/opt# kubectl -n kube-system get all
NAME                                        READY   STATUS    RESTARTS      AGE
pod/coredns-56745ff78-8lf2v                 1/1     Running   0             107s
pod/coredns-56745ff78-xvjr8                 1/1     Running   0             107s
pod/etcd-k-kube-lab-01                      1/1     Running   0             9d
pod/etcd-k-kube-lab-02                      1/1     Running   0             29m
pod/etcd-k-kube-lab-03                      1/1     Running   0             29m
pod/kube-apiserver-k-kube-lab-01            1/1     Running   0             9d
pod/kube-apiserver-k-kube-lab-02            1/1     Running   0             29m
pod/kube-apiserver-k-kube-lab-03            1/1     Running   0             29m
pod/kube-controller-manager-k-kube-lab-01   1/1     Running   1 (29m ago)   9d
pod/kube-controller-manager-k-kube-lab-02   1/1     Running   0             28m
pod/kube-controller-manager-k-kube-lab-03   1/1     Running   0             28m
pod/kube-flannel-ds-g572q                   1/1     Running   0             12d
pod/kube-flannel-ds-hwgv2                   1/1     Running   0             12d
pod/kube-flannel-ds-l8lww                   1/1     Running   0             12d
pod/kube-flannel-ds-tbs8l                   1/1     Running   0             12d
pod/kube-flannel-ds-z9sjj                   1/1     Running   0             12d
pod/kube-proxy-8wgfl                        1/1     Running   0             9d
pod/kube-proxy-cdzmz                        1/1     Running   0             9d
pod/kube-proxy-m22z7                        1/1     Running   0             9d
pod/kube-proxy-r6pxx                        1/1     Running   0             9d
pod/kube-proxy-wpp72                        1/1     Running   0             9d
pod/kube-scheduler-k-kube-lab-01            1/1     Running   1 (29m ago)   9d
pod/kube-scheduler-k-kube-lab-02            1/1     Running   0             28m
pod/kube-scheduler-k-kube-lab-03            1/1     Running   0             28m

NAME               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                  AGE
service/kube-dns   ClusterIP   192.168.0.10   <none>        53/UDP,53/TCP,9153/TCP   12d

NAME                             DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
daemonset.apps/kube-flannel-ds   5         5         5       5            5           <none>                   12d
daemonset.apps/kube-proxy        5         5         5       5            5           kubernetes.io/os=linux   12d

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coredns   2/2     2            2           12d

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/coredns-56745ff78    2         2         2       12d
replicaset.apps/coredns-7b8886d7cd   0         0         0       23m
```



