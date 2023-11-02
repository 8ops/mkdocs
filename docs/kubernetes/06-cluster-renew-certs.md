# Renew certs

## 一、续签过程

[Reference](https://kubernetes.io/zh-cn/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)

### 1.1 查看证书过期时间

```bash
kubeadm certs check-expiration
```



### 1.2 备份证书

```bash
ls /etc
ls /etc/kubernetes

cp -r /etc/kubernetes /etc/kubernetes-$(date +%Y%m%d)
```



### 1.3 更新证书

```bash
# 每个control-plane节点
kubeadm certs renew all
```



### 1.4 重启组件

```bash
# You must restart the kube-apiserver, kube-controller-manager, kube-scheduler and etcd

# 静态容器 
#   ls /etc/kubernetes/manifests/
#   etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml

# 查看状态
kubectl -n kube-system get po -w

mv /etc/kubernetes/manifests /etc/kubernetes/manifests-$(date +%Y%m%d)
# sleep 60s
mv /etc/kubernetes/manifests-$(date +%Y%m%d) /etc/kubernetes/manifests
# Depercated
# kubectl -n kube-system get po -o name | \
#   awk '/kube-apiserver|kube-controller|kube-scheduler|etcd/{printf("kubectl -n kube-system delete %s\n",$1)}' | sh

# 看容器创建时间
watch 'crictl ps -a | awk "/kube-apiserver|kube-controller|kube-scheduler|etcd/"'

# 重启kube-proxy
kubectl -n kube-system rollout restart ds kube-proxy
kubectl -n kube-system rollout status  ds kube-proxy

# 重启kubelet
# systemctl status kubelet
# kubelet 证书默认自动签发了 /var/lib/kubelet/pki/kubelet-client-current.pem
openssl x509 -noout -dates -in /var/lib/kubelet/pki/kubelet-client-current.pem
systemctl restart kubelet

# 通过 prometheus 获取 ETCD 数据
# kubectl -n kube-server rollout restart deployment.apps/prometheus-server
kubectl -n kube-server delete secret generic etcd-certs
kubectl create secret generic etcd-certs \
  --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  --from-file=/etc/kubernetes/pki/etcd/ca.crt \
  -n kube-server
kubectl -n kube-server get secret etcd-certs \
    -o jsonpath='{.data.healthcheck-client\.crt}'| \
    base64 --decode | \
    openssl x509 -noout -dates  
kubectl -n kube-server scale --replicas=0 deployment.apps/prometheus-server
kubectl -n kube-server scale --replicas=1 deployment.apps/prometheus-server
```



### 1.5 验收效果

```bash
# 获取节点
kubectl get no 

# 核验组件证书续签结果
kubeadm certs check-expiration

# 查看所有本地文件证书
find /etc/kubernetes/pki -name '*.crt' | while read cert
do
printf "\nchecking [%-50s] [%s] " ${cert} "`openssl x509 -noout -enddate -in ${cert}`"
done;echo

# 核实新签发证书后进行的重启Pod
apt install jq -y -q
stat /etc/kubernetes/pki/apiserver-kubelet-client.crt | grep Modify
crictl inspect `crictl ps --name kube-scheduler -q` | jq .status.createdAt

# 查看kubelet最后加载时间
systemctl status kubelet

# review etcd
mkdir -p ~/bin
wget --quiet --no-check-certificate https://m.8ops.top/linux/etcdctl-3.4.24 -O ~/bin/etcdctl
chmod +x ~/bin/etcdctl
export PATH=~/bin:$PATH
etcdctl endpoint status -w table \
  --cluster \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```



## 二、变更时长

[Reference](https://github.com/kubernetes/kubernetes.git)



### 2.1 获取源码-分支

```bash
cd /opt
KUBE_VERSION=1.25.0
KUBE_VERSION=1.23.0

# install git
apt update
apt install git -y

# git clone
git clone https://github.com/kubernetes/kubernetes.git

# 切换版本
cd kubernetes
git checkout v${KUBE_VERSION}
# or git checkout remotes/origin/release-1.23
```



### 2.1 获取源码-下载

```bash
cd /opt
KUBE_VERSION=1.25.0
KUBE_VERSION=1.23.0

wget https://github.com/kubernetes/kubernetes/archive/refs/tags/v${KUBE_VERSION}.tar.gz
tar xzf v${KUBE_VERSION}.tar.gz -C .

cd kubernetes-${KUBE_VERSION}
```





### 2.2 修改源码 

```bash
# v1.23.0

# 100y
sed -i '68 s/duration365d\ \*\ 10/duration365d * 100/' staging/src/k8s.io/client-go/util/cert/cert.go
grep duration365d staging/src/k8s.io/client-go/util/cert/cert.go

sed -i '50 s/time.Hour\ \*\ 24\ \*\ 365/time.Hour * 24 * 365 * 100/' cmd/kubeadm/app/constants/constants.go
grep CertificateValidity cmd/kubeadm/app/constants/constants.go

git diff .

# 10y
sed -i '50 s/time.Hour\ \*\ 24\ \*\ 365/time.Hour * 24 * 365 * 10/' cmd/kubeadm/app/constants/constants.go
grep CertificateValidity cmd/kubeadm/app/constants/constants.go

git diff .

```



```bash
# v1.25.0

# 100y
sed -i '80 s/duration365d\ \*\ 10/duration365d * 100/' staging/src/k8s.io/client-go/util/cert/cert.go
grep duration365d staging/src/k8s.io/client-go/util/cert/cert.go

sed -i '51 s/time.Hour\ \*\ 24\ \*\ 365/time.Hour * 24 * 365 * 100/' cmd/kubeadm/app/constants/constants.go
grep CertificateValidity cmd/kubeadm/app/constants/constants.go

git diff .

# 10y
sed -i '51 s/time.Hour\ \*\ 24\ \*\ 365/time.Hour * 24 * 365 * 10/' cmd/kubeadm/app/constants/constants.go
grep CertificateValidity cmd/kubeadm/app/constants/constants.go

git diff .

```



#### 2.2.1 源码上下文

`vim ./staging/src/k8s.io/client-go/util/cert/cert.go`

```go
// 这个方法里面 NotAfter:              now.Add(duration365d * 10).UTC()
// 默认有效期就是 10 年，改成 100 年 (sysin)
// 输入 /NotAfter 查找，回车定位
func NewSelfSignedCACert(cfg Config, key crypto.Signer) (*x509.Certificate, error) {
        now := time.Now()
        tmpl := x509.Certificate{
                SerialNumber: new(big.Int).SetInt64(0),
                Subject: pkix.Name{
                        CommonName:   cfg.CommonName,
                        Organization: cfg.Organization,
                },
                NotBefore:             now.UTC(),
                // NotAfter:              now.Add(duration365d * 10).UTC(),
                NotAfter:              now.Add(duration365d * 100).UTC(),
                KeyUsage:              x509.KeyUsageKeyEncipherment | x509.KeyUsageDigitalSignature | x509.KeyUsageCertSign,
                BasicConstraintsValid: true,
                IsCA:                  true,
        }

        certDERBytes, err := x509.CreateCertificate(cryptorand.Reader, &tmpl, &tmpl, key.Public(), key)
        if err != nil {
                return nil, err
        }
        return x509.ParseCertificate(certDERBytes)
}
```

`vim ./cmd/kubeadm/app/constants/constants.go`

```go
// 就是这个常量定义 CertificateValidity，改成 * 100 年 (sysin)
// 输入 /CertificateValidity 查找，回车定位
const (
        // KubernetesDir is the directory Kubernetes owns for storing various configuration files
        KubernetesDir = "/etc/kubernetes"
        // ManifestsSubDirName defines directory name to store manifests
        ManifestsSubDirName = "manifests"
        // TempDirForKubeadm defines temporary directory for kubeadm
        // should be joined with KubernetesDir.
        TempDirForKubeadm = "tmp"

        // CertificateValidity defines the validity for all the signed certificates generated by kubeadm
        // CertificateValidity = time.Hour * 24 * 365
        CertificateValidity = time.Hour * 24 * 365 * 100

        // CACertAndKeyBaseName defines certificate authority base name
        CACertAndKeyBaseName = "ca"
        // CACertName defines certificate name
        CACertName = "ca.crt"
        // CAKeyName defines certificate name
        CAKeyName = "ca.key"
```





### 2.3 编译源码-手动

#### 2.3.1 配置环境

```bash
# 查看编译依赖 Golang 版本
cat build/build-image/cross/VERSION

cd /opt
GO_VERSION=1.19   # v1.25
GO_VERSION=1.17.3 # v1.23
wget https://golang.google.cn/dl/go${GO_VERSION}.linux-amd64.tar.gz
tar zxf go${GO_VERSION}.linux-amd64.tar.gz -C /usr/local

cat <<EOF > /etc/profile.d/go-env.sh
export GOROOT=/usr/local/go
export GOPATH=/usr/local/gopath
export PATH=\$PATH:\$GOROOT/bin
EOF
source /etc/profile.d/go-env.sh

# 这里一次性编译，直接执行如下命令即可
export PATH=$PATH:/usr/local/go/bin

# 编译 kubeadm, 这里主要编译 kubeadm 即可
make all WHAT=cmd/kubeadm GOFLAGS=-v
```



### 2.3 编译源码-容器

#### 2.3.1 配置环境

[编译要求](https://github.com/kubernetes/kubernetes/blob/v1.23.0/build/README.md)

```bash
# 查看 kube-cross 的 TAG 版本
cat build/build-image/cross/VERSION
# v1.23.0-go1.19.6-bullseye.0

yum install -y -q rsync docker-ce

# 配置docker代理下载源registry.k8s.io镜像
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:8080/"
Environment="HTTPS_PROXY=http://proxy.example.com:8080/"
Environment="NO_PROXY=localhost,127.0.0.1,.8ops.top,*.8ops.top"
systemctl daemon-reload
systemctl restart docker

TAG_NAME=v1.23.0-go1.19.6-bullseye.0 
docker pull hub.8ops.top/google_containers/kube-cross:${TAG_NAME}
docker tag  hub.8ops.top/google_containers/kube-cross:${TAG_NAME} registry.k8s.io/build-image/kube-cross:${TAG_NAME}

docker version # 19.03+
docker buildx version

build/run.sh make kubeadm KUBE_BUILD_PLATFORMS=linux/amd64

```



### 2.4 续签过程

```bash
mv /usr/bin/kubeadm{,-$(kubeadm version -o short)}

curl -k -s -o /usr/bin/kubeadm https://filestorage.8ops.top/ops/kubeadm/kubeadm-v1.25.0.amd64-10y
chmod +x /usr/bin/kubeadm

```



## 三、番外篇

### 3.1 组件证书已经过期

万一不巧证书真的过期了，在网上看有神操作解救。

现象

```bash
# 连接 Api-server 失败，报证书已过期不可用。
$ kubectl get node,pod
Unable to connect to the server: x509: certificate has expired or is not yet valid: current time 2023-01-31T16:55:27+08:00 is after 2023-01-16T04:47:34Z
```

急救包

```bash
# 大致思路：
# 备份集群配置 (当证书到期时是无法执行的此步骤可跳过)
# 但可以利用date命令将系统时间设置到过期前。

# 1，备份配置
cp -r /etc/kubernetes /etc/kubernetes-$(date +%Y%m%d)

# 2，变更系统时间至过期前
data -s "2023-01-01" || timedatectl set-time "2023-01-01"

# 3，导出原始配置文件（后续会用到）
kubectl -n kube-system get cm kubeadm-config -o yaml > kubeadm-init-config.yaml

# 4，查看证书相关信息（此时应该都invalid状态）
kubeadm certs check-expiration

# 5，续签组件证书
kubeadm certs renew all --config=kubeadm-init-config.yaml

# 6，重启组件（含kube-apiserver, kube-controller-manager, kube-scheduler and etcd）
mv /etc/kubernetes/manifests /etc/kubernetes/manifests-$(date +%Y%m%d)
sleep 60s
mv /etc/kubernetes/manifests-$(date +%Y%m%d) /etc/kubernetes/manifests

# 7，查看证书相关信息（此时恢复可用）
kubeadm certs check-expiration

# 8，重新生成配置文件
rm -rf /etc/kubernetes/*.conf
kubeadm init phase kubeconfig all --config=kubeadm-init-config.yaml

# 9，恢复时间
ntpdate -s ntp.aliyun.org
```



### 3.2 Kubelet 客户端证书轮换失败

[Reference](https://kubernetes.io/zh-cn/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/#kubelet-client-cert)

默认情况下，kubeadm 使用 `/etc/kubernetes/kubelet.conf` 中指定的 `/var/lib/kubelet/pki/kubelet-client-current.pem` 符号链接来配置 kubelet 自动轮换客户端证书。如果此轮换过程失败，你可能会在 kube-apiserver 日志中看到诸如 `x509: certificate has expired or is not yet valid` 之类的错误。要解决此问题，你必须执行以下步骤：

1. 从故障节点备份和删除 `/etc/kubernetes/kubelet.conf` 和 `/var/lib/kubelet/pki/kubelet-client*`。
2. 在集群中具有 `/etc/kubernetes/pki/ca.key` 的、正常工作的控制平面节点上 执行 `kubeadm kubeconfig user --org system:nodes --client-name system:node:$NODE > kubelet.conf`。 `$NODE` 必须设置为集群中现有故障节点的名称。 手动修改生成的 `kubelet.conf` 以调整集群名称和服务器端点， 或传递 `kubeconfig user --config`（此命令接受 `InitConfiguration`）。 如果你的集群没有 `ca.key`，你必须在外部对 `kubelet.conf` 中的嵌入式证书进行签名。

1. 将得到的 `kubelet.conf` 文件复制到故障节点上，作为 `/etc/kubernetes/kubelet.conf`。
2. 在故障节点上重启 kubelet（`systemctl restart kubelet`），等待 `/var/lib/kubelet/pki/kubelet-client-current.pem` 重新创建。

1. 手动编辑 `kubelet.conf` 指向轮换的 kubelet 客户端证书，方法是将 `client-certificate-data` 和 `client-key-data` 替换为：

   ```yaml
   client-certificate: /var/lib/kubelet/pki/kubelet-client-current.pem
   client-key: /var/lib/kubelet/pki/kubelet-client-current.pem
   ```

1. 重新启动 kubelet。
2. 确保节点状况变为 `Ready`。



### 3.3 执行kubectl命令报Refused

现象

```bash
$ kubectl get cs
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

解决

```bash
# 原因：当前用户下没有~/.kube/config或者不存在环境变量

# 方式1.复制 /etc/kubernetes 目录下 admin.conf 文件到 当前用户家目录下 /.kube/config
mkdir -p $HOME/.kube
echo 'yes' |  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 方式2.使用 KUBECONFIG 环境变量包含一个 kubeconfig 文件列表。
export  KUBECONFIG=/etc/kubernetes/admin.conf:~/.kube/devops.kubeconfig

# 方式3.在命令执行时使用--kubeconfig参数指定配置文件
kubectl config --kubeconfig=/etc/kubernetes/admin.conf
```



### 3.4 master节点上calico-node准备状态

现象

```bash
$ kubectl get pod -n kube-system calico-node-v52sv
  # NAME                READY   STATUS    RESTARTS   AGE
  # calico-node-v52sv   0/1     Running   0          31m

$ kubectl describe pod -n kube-system calico-node-v52sv | grep "not ready"
  # Warning  Unhealthy    33m (x2 over 33m)  kubelet  Readiness probe failed: calico/node is not ready: BIRD is not ready: Error querying BIRD: unable to connect to BIRDv4 socket: dial unix /var/run/calico/bird.ctl: connect: connection refused
  # calico/node is not ready: BIRD is not ready: BGP not established with 192.168.12.107,192.168.12.109,192.168.12.223,192.168.12.224,192.168.12.225,192.168.12.226

$ kubectl logs -f --tail 50  -n kube-system calico-node-v52sv | grep "interface"
  # 2023-02-01 08:40:57.583 [INFO][69] monitor-addresses/startup.go 714: Using autodetected IPv4 address on interface br-b92e9270f33c: 172.22.0.1/16
  # calico 对应的 Pod 启动失败，报错：
  # Number of node(s) with BGP peering established = 0
```

解决

```bash
# 原因：由于该节点上安装了docker并创建了容器，Calico 选择了有问题的br网卡，导致 calico-node 的 Pod 不能启动

# Calico 提供了 IP 自动检测的方法，默认是使用第一个有效网卡上的第一个有效的 IP 地址：
IP_AUTODETECTION_METHOD=first-found

# 节点上应该是出现了有问题的网卡，可以使用以下命令查看：
ip link | grep br

# ---
# 知识扩展: calico-node daemonset 默认的策略是获取第一个取到的网卡的 ip 作为 calico node 的ip, 由于集群中网卡名称不统一所以可能导致calico获取的网卡IP不对, 所以出现此种情况下就只能 IP_AUTODETECTION_METHOD 字段指定通配符网卡名称或者IP地址。

# 方法1.修改 yaml 配置清单中 IP 自动检测方法，在 spec.containers.env 下添加以下两行。（推荐）
  - name: IP_AUTODETECTION_METHOD
    value: "interface=ens.*"  # ens 根据实际网卡开头配置

# 方法2.删除有问题的网卡（推荐），即指定网卡名称（br 开头的问题网卡）删除。
ifconfig br-b92e9270f33c down

# 方法3.假如环境不依赖docker情况下，可以卸载docker, 然后重启系统即可。
sudo apt-get autoremove docker docker-ce docker-engine docker.io

kubectl delete pod -n kube-system calico-node-v52sv
```

### 3.5 加入集群时报bridge 错误

现象

```bash
[preflight] Some fatal errors occurred:
  [ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]: /proc/sys/net/bridge/bridge-nf-call-iptables does not exist
[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
error execution phase preflight
```

解决

```bash
# 配置
$ cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
$ cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
$ modprobe br_netfilter && sudo sysctl --system
```

### 3.6 kubenet报`path does not exist`

现象

```bash
Jan 16 14:27:25 weiyigeek-226 kubelet[882231]: E0116 14:27:25.496423  882231 kubelet.go:2347] "Container runtime network not ready" networkReady="NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns e>
Jan 16 14:27:26 weiyigeek-226 kubelet[882231]: E0116 14:27:26.482369  882231 file_linux.go:61] "Unable to read config path" err="path does not exist, ignoring" path="/etc/kubernetes/manifests"

```

解决

```bash
# 解决办法: 检查 /etc/kubernetes/manifests 目录是否存储及其权限
mkdir -vp /etc/kubernetes/manifests
```

### 3.7 节点加入到集群中时报secret错误

现象

```bash
I0116 04:39:41.428788  184219 checks.go:246] validating the existence and emptiness of directory /var/lib/etcd
[preflight] Would pull the required images (like 'kubeadm config images pull')
[download-certs] Downloading the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
secrets "kubeadm-certs" is forbidden: User "system:bootstrap:20w21w" cannot get resource "secrets" in API group "" in the namespace "kube-system"
error downloading the secret
```

解决

```bash
kubeadm init phase upload-certs --upload-certs
  # [upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
  # [upload-certs] Using certificate key:
  # 3a3d7610038c9d14edf377d92b9c6b44e049566ddd25b0e69bf571af58227ae7
```



