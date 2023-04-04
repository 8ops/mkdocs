# 实战 | Kubernetes Cluster  续签组件证书



[Reference](https://kubernetes.io/zh-cn/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)

## 1，查看证书过期时间

```bash
kubeadm certs check-expiration
```



## 2，备份证书

```bash
cp -r /etc/kubernetes /etc/kubernetes-$(date +%Y%m%d)
```



## 3，更新证书

```bash
# 每个control-plane节点
kubeadm certs renew all

# 会有如下提示
# You must restart the kube-apiserver, kube-controller-manager, kube-scheduler and etcd
```



## 4，重启组件

```bash
# 静态容器 
#   ls /etc/kubernetes/manifests/
#   etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml

kubectl -n kube-system get po -o name | \
  awk '/kube-apiserver|kube-controller|kube-scheduler|etcd/{printf("kubectl -n kube-system delete %s\n",$1)}' | sh

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



## 5，验收效果

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
```

