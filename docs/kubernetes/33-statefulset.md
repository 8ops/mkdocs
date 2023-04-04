# statefulset

pv是非必须

使用local volume方式

## 创建pv

> web-pv-pvc.yaml

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-volume-nginx-0
  labels:
    pvname: local-volume-nginx-0
spec:
  capacity:
    storage: 20Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-volume
  local:
    path: /data1/pv-nginx
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - 10.101.9.173
          - 10.101.9.174
          - 10.101.9.175
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-volume-nginx-1
  labels:
    pvname: local-volume-nginx-1
spec:
  capacity:
    storage: 20Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-volume
  local:
    path: /data1/pv-nginx
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - 10.101.9.173
          - 10.101.9.174
          - 10.101.9.175
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-volume-nginx-2
  labels:
    pvname: local-volume-nginx-2
spec:
  capacity:
    storage: 20Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-volume
  local:
    path: /data1/pv-nginx
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - 10.101.9.173
          - 10.101.9.174
          - 10.101.9.175
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: local-volume-nginx-web-0
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: local-volume
  selector:
    matchLabels:
      pvname: local-volume-nginx-0
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: local-volume-nginx-web-1
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: local-volume
  selector:
    matchLabels:
      pvname: local-volume-nginx-1
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: local-volume-nginx-web-2
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: local-volume
  selector:
    matchLabels:
      pvname: local-volume-nginx-2
```

## 创建sts

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    k8s-app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    k8s-app: nginx
---
apiVersion: apps/v1beta1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
  podManagementPolicy: "Parallel"
  replicas: 2
  template:
    metadata:
      labels:
        k8s-app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx-slim:0.8
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: local-volume-nginx
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: local-volume-nginx
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "local-volume"
      resources:
        requests:
          storage: 20Gi
```

## 管理

```bash

kubectl run -it --rm --image busybox:latest dns-test --restart=Never /bin/sh
ping -c 2 web-0.nginx.default.svc.cluster.local

kubectl scale sts/web --replicas=3
kubectl patch sts/web -p '{"spec":{"replicas":2}}'

kubectl get po -l k8s-app=nginx -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\t"}{.spec.nodeName}{"\n"}{end}'

kubectl patch sts/web --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"nginx-slim:0.7"}]'

kubectl patch sts/web -p '{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":1}}}}'

kubectl get po/web-2 --template '{{range $i, $c := .spec.containers}}{{$c.image}}{{end}}'

for i in 0 1 2; do kubectl exec web-$i -- sh -c 'echo $(hostname) > /usr/share/nginx/html/index.html'; done

for i in 0 1 2; do kubectl exec -it web-$i -- curl http://localhost/index.html; done
for i in 0 1 2; do kubectl exec -it web-$i -- curl http://localhost/ip.html; done

web-0 nginx-slim:0.7 10.101.9.175
web-1 nginx-slim:0.7 10.101.9.174
web-2 nginx-slim:0.7 10.101.9.173

kubectl delete sts/web --cascade=false

kubectl rollout restart sts/web
kubectl rollout status  sts/web

```



