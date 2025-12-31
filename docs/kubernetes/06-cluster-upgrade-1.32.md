# Upgrade - 1.32

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

| 软件名称   | 当前版本               | 升级v1.32          | 升级v1.33 | 升级v1.34 | 升级v1.35 |
| ---------- | ---------------------- | ---------------------- | ---------------------- | ---------------------- | ---------------------- |
| kubeadm     | 1.31.1 | 1.32.9-1.1 | 1.33.5-1.1 | 1.34.1-1.1 |  |
| kubelet     | 1.31.1        | 1.32.9-1.1 | 1.33.5-1.1 | 1.34.1-1.1 |  |
| kubernetes  | 1.31.1        | 1.32.9-1.1 | 1.33.5-1.1 | 1.34.1-1.1 |  |
| etcd        | 3.5.15-0 | 3.5.16-0 | 3.5.21-0 | 3.6.4-0 |  |
| flannel     | v0.19.1                | v0.27.3 |  |  |  |
| coredns     | v1.9.3                 | v1.11.3 | v1.12.0 | v1.12.1 |  |
| containerd  | 1.7.12-0ubuntu1~20.04.4 | 1.7.24-0ubuntu1~20.04.2 | 1.7.24-0ubuntu1~20.04.2 | 1.7.24-0ubuntu1~20.04.2 |  |



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

### 2.1 cluster

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
# https://books.8ops.top/attachment/kubernetes/kubeadm-upgrade.yaml-v1.34.1

# kubeadm upgrade plan/apply
kubeadm upgrade plan
vim kubeadm-config.yaml-${KUBE_VERSION}
# https://books.8ops.top/attachment/kubernetes/kubeadm-config.yaml-v1.34.1
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



### 2.2 calico

```bash
CALICO_VERSION=v3.30.4
# CALICO_VERSION=v3.31.0 # 未在 Kubernetes v1.34.1 上面应用成功，发布特性发生重大变化 https://github.com/projectcalico/calico/blob/release-v3.31/release-notes/v3.31.0-release-notes.md
curl -s -k -o 01-calico.yaml-${CALICO_VERSION}.yaml-default \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml

# edit image and namespace
vim 01-calico.yaml-${CALICO_VERSION}.yaml

# # Containers Images
# image: quay.io/calico/cni:v3.30.4
# image: quay.io/calico/cni:v3.30.4
# image: quay.io/calico/node:v3.30.4
# image: quay.io/calico/node:v3.30.4
# image: quay.io/calico/kube-controllers:v3.30.4

kubectl apply -f 01-calico.yaml-${CALICO_VERSION}.yaml

```



#### 2.2.1 calicoctl

```bash
# download calicoctl
CALICO_VERSION=v3.30.4
curl -sL -o ~/bin/calicoctl \
  https://github.com/projectcalico/calico/releases/download/${CALICO_VERSION}/calicoctl-linux-amd64

root@K-KUBE-LAB-01:~# calicoctl node status
Calico process is running.

IPv4 BGP status
+---------------+-------------------+-------+------------+-------------+
| PEER ADDRESS  |     PEER TYPE     | STATE |   SINCE    |    INFO     |
+---------------+-------------------+-------+------------+-------------+
| 10.101.11.114 | node-to-node mesh | up    | 2025-10-30 | Established |
| 10.101.11.154 | node-to-node mesh | up    | 2025-10-30 | Established |
| 10.101.11.196 | node-to-node mesh | up    | 2025-10-30 | Established |
| 10.101.11.157 | node-to-node mesh | up    | 2025-10-30 | Established |
| 10.101.11.250 | node-to-node mesh | up    | 2025-10-30 | Established |
+---------------+-------------------+-------+------------+-------------+

IPv6 BGP status
No IPv6 peers found.

root@K-KUBE-LAB-01:~# calicoctl node checksystem
Checking kernel version...
		5.4.0-80-generic    					OK
Checking kernel modules...
		xt_rpfilter         					OK
		xt_bpf              					OK
		nf_conntrack_netlink					OK
		xt_conntrack        					OK
		xt_icmp             					OK
		xt_multiport        					OK
		ip6_tables          					OK
		ipt_ipvs            					OK
		ipt_rpfilter        					OK
		xt_set              					OK
		ip_set              					OK
		ipt_REJECT          					OK
		ipt_set             					OK
		xt_addrtype         					OK
		xt_icmp6            					OK
		xt_mark             					OK
		xt_u32              					OK
		ip_tables           					OK
		vfio-pci            					OK
System meets minimum system requirements to run Calico!

root@K-KUBE-LAB-01:~# calicoctl ipam check
Checking IPAM for inconsistencies...

Loading all IPAM blocks...
Found 6 IPAM blocks.
 IPAM block 172.19.156.192/26 affinity=host:k-kube-lab-03:
 IPAM block 172.19.179.128/26 affinity=host:k-kube-lab-02:
 IPAM block 172.19.196.192/26 affinity=host:k-kube-lab-08:
 IPAM block 172.19.218.64/26 affinity=host:k-kube-lab-11:
 IPAM block 172.19.26.0/26 affinity=host:k-kube-lab-12:
 IPAM block 172.19.36.64/26 affinity=host:k-kube-lab-01:
IPAM blocks record 29 allocations.

Loading all IPAM pools...
  172.19.0.0/16
Found 1 active IP pools.

Loading all nodes.
Found 6 node tunnel IPs.

Loading all service load balancer IPs.
No configuration for LoadBalancer kubecontroller found, skipping service check

Loading all workload endpoints.
Found 23 workload IPs.
Workloads and nodes are using 29 IPs.

Loading all handles
Looking for top (up to 20) nodes by allocations...
  k-kube-lab-11 has 16 allocations
  k-kube-lab-08 has 5 allocations
  k-kube-lab-12 has 5 allocations
  k-kube-lab-03 has 1 allocations
  k-kube-lab-02 has 1 allocations
  k-kube-lab-01 has 1 allocations
Node with most allocations has 16; median is 1

Scanning for IPs that are allocated but not actually in use...
Found 0 IPs that are allocated in IPAM but not actually in use.
Scanning for IPs that are in use by a workload or node but not allocated in IPAM...
Found 0 in-use IPs that are not in active IP pools.
Found 0 in-use IPs that are in active IP pools but have no corresponding IPAM allocation.

Scanning for IPAM handles with no matching IPs...
Found 0 handles with no matching IPs (and 29 handles with matches).
Scanning for IPs with missing handle...
Found 0 handles mentioned in blocks with no matching handle resource.
Check complete; found 0 problems.
root@K-KUBE-LAB-01:~# calicoctl ipam show
+----------+---------------+-----------+------------+--------------+
| GROUPING |     CIDR      | IPS TOTAL | IPS IN USE |   IPS FREE   |
+----------+---------------+-----------+------------+--------------+
| IP Pool  | 172.19.0.0/16 |     65536 | 29 (0%)    | 65507 (100%) |
+----------+---------------+-----------+------------+--------------+

```



#### 2.2.2 calico-cloud

<u>未成功</u>

```bash
# free: https://www.calicocloud.io/start-free

# 1 
# 安装 Calico Cloud 连接组件（示例 Helm 安装）
helm repo add tigera https://docs.tigera.io/charts
helm repo update
helm install calico-cloud tigera/tigera-secure-ee \
  --namespace kube-system --create-namespace \
  --set installation.variant=CalicoCloud \
  --set calicoCloud.organizationToken="<YOUR_TOKEN>" \
  --set calicoCloud.clusterName="<YOUR_CLUSTER_NAME>" \
  --set calicoCloud.global.imageRepository="hub.8ops.top/google_containers" \
  --set flowLogs.enabled=true \
  --set observability.enabled=true

# 4. 验证 Calico Cloud 连接
kubectl -n kube-system get pods
kubectl -n kube-system logs deployment/calico-cloud-operator

# 2
# https://docs.tigera.io/calico-cloud/free/quickstart
kubectl apply -f 01-tigera-operator-v3.30.4.yaml
kubectl apply -f 01-custom-resources-v3.30.4.yaml

$ kubectl get tigerastatus
NAME                            AVAILABLE   PROGRESSING   DEGRADED   SINCE
apiserver                       True        False         False      67s
calico                                                    True
goldmane                        False       True          False      117s
ippools                                                   True
management-cluster-connection   True        False         False      72s
whisker                         False       True          False      117s
```



### 2.3 cilium

#### 2.3.1 释放calico

```bash
# 删除calico资源
kubectl delete -f 01-calico.yaml-${CALICO_VERSION}.yaml

kubectl delete crd bgppeers.crd.projectcalico.org bgpconfigurations.crd.projectcalico.org \
ippools.crd.projectcalico.org felixconfigurations.crd.projectcalico.org \
clusterinformations.crd.projectcalico.org blockaffinities.crd.projectcalico.org \
hostendpoints.crd.projectcalico.org ipamblocks.crd.projectcalico.org ipamhandles.crd.projectcalico.org \
networkpolicies.crd.projectcalico.org globalnetworkpolicies.crd.projectcalico.org

# --------
# 每个节点上
# tree /etc/cni/net.d*
mv /etc/cni/net.d{,-$(date +%Y%m%d)}

# 删除iptables链表
ip link | awk '/cali/{print $2}' | sed 's/://' | xargs -I{} sudo ip link delete {}
iptables-save | grep -i cali
iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -X
iptables-save

# 删除路由
ip route show | awk '/cali/{printf("ip route del %s\n", $1)}' | sh
ip route show | grep cali

# 删除虚拟网卡
ip link | awk '/cali/{printf("ip link delete %s \n", $2)}' | sed 's/@.*$//' | sh
ip link | grep cali

# reset cni
systemctl restart kubelet && sleep 5 && systemctl restart containerd

# install cni
```



#### 2.3.2 安装cilium

##### 2.3.2.1 helm

```bash
# # cilium (required kernel>4.18 support ebpf)
# 内核版本
uname -r
# 查看 /boot/config-$(uname -r) 中 BPF 相关
grep -E 'CONFIG_BPF|CONFIG_BPF_SYSCALL|CONFIG_CGROUP_BPF' /boot/config-$(uname -r) || true
# 或查看是否包含 helper 名称（次优方案）
grep bpf_get_current_cgroup_id /proc/kallsyms || true

CILIUM_VERSION=1.12.19
CILIUM_VERSION=1.17.9
# CILIUM_VERSION=1.18.3 # 报ebpf支持受限内核>4.18，实际kernel=5.4

helm repo add cilium https://helm.cilium.io/
helm repo update cilium
helm search repo cilium
helm show values cilium/cilium \
  --version ${CILIUM_VERSION} > cilium.yaml-${CILIUM_VERSION}-default
  
# # Containers Images: 1.18.3
# quay.io/cilium/cilium:v1.18.3
# quay.io/cilium/certgen:v0.2.4
# quay.io/cilium/hubble-relay:v1.18.3
# quay.io/cilium/hubble-ui-backend:v0.13.3
# quay.io/cilium/hubble-ui:v0.13.3
# quay.io/cilium/cilium-envoy:v1.34.10-1761014632-c360e8557eb41011dfb5210f8fb53fed6c0b3222
# quay.io/cilium/operator:v1.18.3
# 
# # no use
# quay.io/cilium/startup-script:1755531540-60ee83e
# quay.io/cilium/clustermesh-apiserver:v1.18.3
# ghcr.io/spiffe/spire-agent:1.12.4
# ghcr.io/spiffe/spire-server:1.12.4

helm install cilium cilium/cilium \
  -f cilium.yaml-${CILIUM_VERSION} \
  --namespace=kube-system \
  --version ${CILIUM_VERSION} --debug

helm upgrade --install cilium cilium/cilium \
  -f cilium.yaml-${CILIUM_VERSION} \
  --namespace=kube-system \
  --version ${CILIUM_VERSION}
  
helm -n kube-system uninstall cilium

```



> cilium.yaml-1.17.9

```yaml
image:
  repository: "hub.8ops.top/quay/cilium"
  tag: "v1.17.9"
  useDigest: false

resources:
  limits:
    cpu: 2
    memory: 2Gi
  requests:
    cpu: 50m
    memory: 64Mi

certgen:
  image:
    repository: "hub.8ops.top/quay/cilium-certgen"
    tag: "v0.2.1"
    useDigest: false

hubble:
  enabled: true
  relay:
    enabled: true
    image:
      repository: "hub.8ops.top/quay/hubble-relay"
      tag: "v1.17.9"
      useDigest: false

    resources:
      limits:
        cpu: 1
        memory: 1Gi
      requests:
        cpu: 50m
        memory: 64Mi

    prometheus:
      enabled: true
      port: 9966

  ui:
    enabled: true
    standalone:
      enabled: true

    backend:
      image:
        repository: "hub.8ops.top/quay/hubble-ui-backend"
        tag: "v0.13.3"
        useDigest: false

      resources:
        limits:
          cpu: 1
          memory: 1Gi
        requests:
          cpu: 50m
          memory: 64Mi

    frontend:
      image:
        repository: "hub.8ops.top/quay/hubble-ui"
        tag: "v0.13.3"
        useDigest: false

      resources:
        limits:
          cpu: 1
          memory: 1Gi
        requests:
          cpu: 50m
          memory: 64Mi

    ingress:
      enabled: true
      className: "external"
      hosts:
        - hubble.8ops.top
      tls:
        - secretName: tls-8ops.top
          hosts:
            - hubble.8ops.top

ipam:
  mode: "cluster-pool"
  operator:
    clusterPoolIPv4PodCIDRList: "172.19.0.0/16"
    clusterPoolIPv4MaskSize: 24

prometheus:
  enabled: true
  port: 9962

operator:
  enabled: true
  image:
    repository: "hub.8ops.top/quay/cilium-operator"
    tag: "v1.17.9"
    useDigest: false

  resources:
    limits:
      cpu: 1
      memory: 1Gi
    requests:
      cpu: 50m
      memory: 64Mi

  prometheus:
    enabled: true
    port: 9963

ingressController:
  enabled: true

envoy:
  enabled: false
```



##### 2.3.2.2 utils

```bash
# CILIUM CLI
CILIUM_CLI_VERSION=v0.18.8
curl -sL --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
tar xzvfC cilium-linux-amd64.tar.gz ~/bin

# HUBBLE
HUBBLE_VERSION=v1.18.3
curl -sL --remote-name-all https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-amd64.tar.gz.sha256sum

# reset cni
systemctl restart kubelet && sleep 5 && systemctl restart containerd
```





#### 2.3.3 释放cilium

```bash
helm -n kube-system uninstall cilium

# 删除crds
kubectl get crds | awk '/cilium/{printf("kubectl delete crds %s\n", $1)}' | sh

# 删除命名空间（不一定再次遇到）
kubectl patch namespace cilium-secrets -p '{"metadata":{"finalizers":[]}}' --type=merge
kubectl delete --force --grace-period=0 ns cilium-secrets
kubectl get namespace cilium-secrets -o json \
  | jq 'del(.spec.finalizers)' \
  | kubectl replace --raw "/api/v1/namespaces/cilium-secrets/finalize" -f -

# 每个节点上
mv /etc/cni/net.d{,-$(date +%Y%m%d)-2}
# rm -rf /etc/cni/net.d

# 删除iptables链表
ip link | awk '/cilium/{print $2}' | sed 's/://' | xargs -I{} sudo ip link delete {}
iptables-save | grep -i cilium
iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -X
iptables-save

# 删除路由
ip route show | awk '/cilium/{printf("ip route del %s\n", $1)}' | sh
ip route show | grep cilium

# 删除虚拟网卡
ip link | awk '/cilium/{printf("ip link delete %s \n", $2)}' | sed 's/@.*$//' | sh
ip link | grep cilium

# reset cni
systemctl restart kubelet && sleep 5 && systemctl restart containerd

# install cni
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





## 四、addons

参考[Helm](05-helm.md)



### 4.1 metallb

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

helm upgrade --install metallb metallb/metallb \
  -f metallb.yaml-${METALLB_VERSION} \
  --namespace=kube-server \
  --create-namespace \
  --version ${METALLB_VERSION}

```



### 4.2 Ingress-nginx

```bash
INGRESS_NGINX_VERSION=4.13.3
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm search repo ingress-nginx

helm show values ingress-nginx/ingress-nginx \
  --version 4.13.3 > ingress-nginx.yaml-4.13.3-default

# # Containers Images
# registry.k8s.io/ingress-nginx/controller:v1.13.3
# registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.6.3

# # 不经过Haproxy protocol，走metalLB时禁用
# #   use-proxy-protocol: "true"

# # 支持XFF传递
#     use-forwarded-headers: "true"
#     compute-full-forwarded-for: "true"
#     forwarded-for-header: "X-Forwarded-For"
#     real-ip-header: "X-Forwarded-For"
#     set-real-ip-from: "0.0.0.0/0"
  
helm upgrade --install ingress-nginx-external-controller \
  ingress-nginx/ingress-nginx \
  -f ingress-nginx.yaml-${INGRESS_NGINX_VERSION} \
  -n kube-server \
  --version ${INGRESS_NGINX_VERSION} --debug

curl -k -H "Host: echoserver.8ops.top" https://10.101.11.242/echoserver
```



### 4.3 kubernetes-dashboard

```bash
KUBERNETES_DASHBOARD_VERSION=7.13.0
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update kubernetes-dashboard
helm search repo kubernetes-dashboard

helm show values kubernetes-dashboard/kubernetes-dashboard \
  --version ${KUBERNETES_DASHBOARD_VERSION}  > kubernetes-dashboard.yaml-${KUBERNETES_DASHBOARD_VERSION}-default

# # Containers Images
# docker.io/kubernetesui/dashboard-auth:1.3.0
# docker.io/kubernetesui/dashboard-api:1.13.0
# docker.io/kubernetesui/dashboard-web:1.7.0
# docker.io/kubernetesui/dashboard-metrics-scraper:1.2.2
# registry.k8s.io/metrics-server/metrics-server:v0.7.2
# kong:3.8

helm upgrade --install kubernetes-dashboard \
  kubernetes-dashboard/kubernetes-dashboard \
  -f kubernetes-dashboard.yaml-${KUBERNETES_DASHBOARD_VERSION} \
  -n kube-server \
  --create-namespace \
  --version ${KUBERNETES_DASHBOARD_VERSION} --debug

```



### 4.4 argo-cd

```bash
ARGOCD_VERSION=9.0.5
helm repo add argoproj https://argoproj.github.io/argo-helm
helm repo update argoproj
helm search repo argo-cd

helm show values argoproj/argo-cd \
  --version ${ARGOCD_VERSION} > argo-cd.yaml-${ARGOCD_VERSION}-default

# # Containers Images
# quay.io/argoproj/argocd:v3.1.9
# ghcr.io/dexidp/dex:v2.44.0

helm upgrade --install argo-cd argoproj/argo-cd \
  -n kube-server \
  -f argo-cd.yaml-${ARGOCD_VERSION} \
  --version ${ARGOCD_VERSION} --debug

```





## 五、常见问题

### 5.1 cgroup版本迭代

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

### 5.2 coredns 未自动升级

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



### 5.3  metrics 

```bash
# error 
error: Metrics API not available

# # solution
# 检查 APIService 是否可用（全局配置，会引用到 kubernetes-dashboard-metrics-server）
kubectl get apiservices v1beta1.metrics.k8s.io -o wide
kubectl describe apiservice v1beta1.metrics.k8s.io

# 检查 metrics-server 资源状态：具体取决于metrics-server

# 认证受权过期

# 检查网络联通性：更换CNI期间会受影响
```



