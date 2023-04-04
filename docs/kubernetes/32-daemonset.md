# daemon set

[update-daemon-set](<https://v1-12.docs.kubernetes.io/zh/docs/tasks/manage-daemon/update-daemon-set/>)

## create

```bash

---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: node-job
  namespace: kube-system
  labels:
    k8s-app: node-job
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 10
  template:
    metadata:
      labels:
        k8s-app: node-job
    spec:
      terminationGracePeriodSeconds: 30
      containers:
      - name: node-job
        image: node-job:v20190909130012
        env:
        - name: WORK_IDC
          value: ofc
        - name: WORK_ENV
          value: dev
        securityContext:
          runAsUser: 0
        resources:
          limits:
            memory: 200Mi
            cpu: 200m
          requests:
            cpu: 100m
            memory: 100Mi
        volumeMounts:
        - name: data1
          mountPath: /data1
      volumes:
      - name: data1
        hostPath:
          path: /data1
---
```

## rollout

```bash
# 获取是否支持滚动更新
kubectl -n kube-system get ds/node-job -o go-template='{{.spec.updateStrategy.rollingUpdate.maxUnavailable}}{{"\n"}}'

## return RollingUpdate
kubectl -n kube-system get ds/node-job -o go-template='{{.spec.updateStrategy.type}}{{"\n"}}' 

## return RollingUpdate
kubectl -n kube-system create -f node-job-daemonset.yaml --dry-run -o go-template='{{.spec.updateStrategy.type}}{{"\n"}}'

# 命令设置支持滚动更新
kubectl -n kube-system patch ds/node-job -p '{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":5}}}}'

# 镜像升级滚动更新
kubectl -n kube-system set image ds/node-job node-job=node-job:v20190909130012

# json输出
kubectl -n kube-system get ds/node-job -o json

# 根据label过滤po
kubectl -n kube-system get po -l k8s-app=node-job -o wide

# watch rollout status
kubectl -n kube-system rollout status ds/node-job

# restart 
kubectl -n kube-system rollout restart ds/node-job
```

