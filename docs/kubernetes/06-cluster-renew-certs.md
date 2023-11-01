# Renew certs

## 一、续签过程

[Reference](https://kubernetes.io/zh-cn/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)

### 1.1 查看证书过期时间

```bash
kubeadm certs check-expiration
```



### 1.2 备份证书

```bash
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



