# 实战 | MetalLB 使用

[对各CNI插件支持情况](https://metallb.universe.tf/installation/network-addons/)



## 一、支持ARP

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



## 二、安装 metallb

```bash
helm repo add metallb https://metallb.github.io/metallb
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

kubectl apply -f 10-metallb-ipaddresspool.yaml
kubectl apply -f 10-metallb-l2advertisement.yaml

ping -c 5 10.101.11.216
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



## 三、使用反馈

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









