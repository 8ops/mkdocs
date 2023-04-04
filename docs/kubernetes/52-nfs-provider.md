# 实战 | NFS Provider

## 一、安装

```bash
helm repo add nfs-provider https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
helm repo update nfs-provider
helm search repo nfs
helm show values nfs-provider/nfs-subdir-external-provisioner --version 4.0.17 > nfs-provider.yaml-4.0.17-default

# Example
#   https://books.8ops.top/attachment/nfs-provider/helm/nfs-provider.yaml-4.0.17
#   https://books.8ops.top/attachment/nfs-provider/helm/01-pod-busybox-nfs.yaml
# 

helm install nfs-provider nfs-provider/nfs-subdir-external-provisioner \
    --set nfs.server=10.101.11.236 \
    --set nfs.path=/data1/lib/nfs \
    -f nfs-provider.yaml-4.0.17 \
    --version 4.0.17

# demo
kubectl exec -it pod-busybox-nfs sh
mount | grep nfs
date > /data1/lib/nfs/from-busybox.txt
```



## 二、使用

```bash
# 以下实例的两个资源
# 
#   https://books.8ops.top/attachment/nfs-provider/10-sc-nfs-demo.yaml
#   https://books.8ops.top/attachment/nfs-provider/12-deploy-busybox-nfs.yaml
# 
```



### 2.1 StorageClass

```yaml
items:
- allowVolumeExpansion: true
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    labels:
      app: nfs-subdir-external-provisioner
      release: nfs-subdir-external-provisioner
    name: nfs-client
  parameters:
    archiveOnDelete: "true"
#    pathPattern: "${.PVC.namespace}/${.PVC.annotations.nfs.io/storage-path}" # default pvc-hashcode
  provisioner: cluster.local/nfs-subdir-external-provisioner # ref pod provider
  reclaimPolicy: Delete # Retain
  volumeBindingMode: Immediate
kind: List
```

### 2.2 PVC

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pvc-pod-nfs
  namespace: default
  annotations:
    nfs.io/storage-path: "pod-demo" # not required, depending on whether this annotation was shown in the storage class description Ref nfs path default/pod-demo
spec:
  storageClassName: "nfs-client"
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Mi
```

