# MetalLB

[对各CNI插件支持情况](https://metallb.universe.tf/installation/network-addons/)



## 一、支持 ARP

> 更新 kube-proxy 配置

```bash
kubectl edit configmap -n kube-system kube-proxy

apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true # relative
  
# restart  
kubectl -n kube-system rollout restart ds kube-proxy
```



## 二、metallb

### 2.1 install

```bash
# https://artifacthub.io/packages/helm/metallb/metallb

helm repo add metallb https://metallb.github.io/metallb
helm repo update metallb
helm search repo metallb
helm show values metallb/metallb --version 0.13.5 > metallb.yaml-0.13.5-default

# Example
#   https://books.8ops.top/attachment/kubernetes/helm/metallb.yaml-0.13.5
#   https://books.8ops.top/attachment/kubernetes/10-metallb-ipaddresspool.yaml
#   https://books.8ops.top/attachment/kubernetes/10-metallb-l2advertisement.yaml
#

helm install metallb metallb/metallb \
    -f metallb.yaml-0.13.5 \
    --namespace=kube-server \
    --create-namespace \
    --version 0.13.5

helm upgrade --install metallb metallb/metallb \
    -f metallb.yaml-0.13.5 \
    --namespace=kube-server \
    --create-namespace \
    --version 0.13.5

helm -n kube-server uninstall metallb

# l2
kubectl apply -f 10-metallb-ipaddresspool.yaml
kubectl apply -f 10-metallb-l2advertisement.yaml

ping -c 5 10.101.11.216

# bgp

```



> vim metallb.yaml-0.13.5

```yaml
prometheus:
  scrapeAnnotations: true

controller:
  enabled: true
  logLevel: info
  image:
    repository: hub.8ops.top/google_containers/metallb-controller
    tag: v0.13.5

speaker:
  enabled: true
  logLevel: info
  image:
    repository: hub.8ops.top/google_containers/metallb-speaker
    tag: v0.13.5
```



### 2.2 ipaddresspool

> vim 10-metallb-ipaddresspool.yaml

```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: kube-server
spec:
  addresses:
  - 10.101.11.212-10.101.11.216
```



### 2.3 l2

需要 `IPAddressPool`、`L2Advertisement`

> vim 10-metallb-l2advertisement.yaml

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2
  namespace: kube-server
spec:
  ipAddressPools:
  - first-pool
```



### 2.4 bgp

因未找到两个peer两个点无法进行测试

需要 `IPAddressPool`、`BGPPeer`、`BGPAdvertisement`

> vim 10-bpg.yaml

```yaml
# BGPPeer to ToR-1
apiVersion: metallb.io/v1beta1
kind: BGPPeer
metadata:
  name: bgp-peer-tor1
  namespace: metallb-system
spec:
  peerAddress: <TOR1_IP>           # e.g. 10.101.11.1  <-- REPLACE
  peerASN: <TOR1_ASN>              # e.g. 65010         <-- REPLACE
  myASN: <MY_ASN>                  # e.g. 65000         <-- REPLACE
  # optional: source address the speaker should use for this peer (must be reachable)
  # sourceAddress: 10.101.11.5

---
# BGPPeer to ToR-2 (optional Redundancy)
apiVersion: metallb.io/v1beta1
kind: BGPPeer
metadata:
  name: bgp-peer-tor2
  namespace: metallb-system
spec:
  peerAddress: <TOR2_IP>           # e.g. 10.101.11.2  <-- REPLACE if you have second peer
  peerASN: <TOR2_ASN>              # e.g. 65010
  myASN: <MY_ASN>                  # same as above

---
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: advertise-lb-pool
  namespace: metallb-system
spec:
  ipAddressPools:
    - lb-pool-10-101-11
  aggregationLength: 32
  # localPref: 100         # optional
  # communities: ["no-export"]  # optional, if your network supports communities

---
apiVersion: metallb.io/v1beta1
kind: BFDProfile
metadata:
  name: bfd-fast
  namespace: metallb-system
spec:
  desiredMinTxInterval: 300
  requiredMinRxInterval: 300
  detectMultiplier: 3

---
apiVersion: metallb.io/v1beta1
kind: BGPPeer
metadata:
  name: bgp-peer-tor1-with-bfd
  namespace: metallb-system
spec:
  peerAddress: <TOR1_IP>
  peerASN: <TOR1_ASN>
  myASN: <MY_ASN>
  bfdProfile: bfd-fast

```





## 三、使用反馈

### 3.1 ingress-nginx暴露流量

当使用 `ingress-nginx` 暴露流量时，需要获取 <u>XFF</u> 信息，需要 变更 `externalTrafficPolicy` 策略

```bash
kubectl patch \
    svc ingress-nginx-external-controller-external \
    -n kube-server \
    -p '{"spec":{"externalTrafficPolicy":"Local"}}'
# OR Edit
# kubectl edit svc ingress-nginx-external-controller-external -n kube-server
#  externalTrafficPolicy: Local
```





> Reference

- https://metallb.universe.tf/faq/



### 3.2 arping

ping不通

如何确认由哪个节点响应

```bash
ip a show enp0s3

arping -i enp0s3 10.101.11.242
# 可以看出由节点轮询响应
42 bytes from 52:54:0a:65:0b:a6 (10.101.11.242): index=42 time=298.749 usec
42 bytes from 52:54:0a:65:0b:a5 (10.101.11.242): index=43 time=419.429 usec
42 bytes from 52:54:0a:65:0b:a6 (10.101.11.242): index=44 time=334.331 usec
42 bytes from 52:54:0a:65:0b:a5 (10.101.11.242): index=45 time=411.971 usec
```







