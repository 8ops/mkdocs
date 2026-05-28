# Airflow



释放

```bash
# 下载至本地资源包
helm install airflow ./airflow-1.18.0.tgz --namespace airflow -f values.yaml

# uninstall
helm list -n airflow
helm -n airflow uninstall airflow

# 清除环境
kubectl -n airflow get all,pvc,pv,job,rs,secret,sc

kubectl -n airflow delete --force pod/airflow-redis-0 pod/airflow-run-airflow-migrations-7xh65
kubectl -n airflow delete job.batch/airflow-run-airflow-migrations 
kubectl -n airflow delete persistentvolumeclaim/data-airflow-postgresql-0
kubectl -n airflow delete secret/airflow-broker-url secret/airflow-fernet-key secret/airflow-redis-password
kubectl -n airflow delete persistentvolumeclaim/data-airflow-postgresql-0 persistentvolume/airflow-postgresql-pv

```



## 一、install

```bash
helm repo add apache-airflow https://airflow.apache.org/
helm repo update apache-airflow
helm search repo airflow 

helm show values apache-airflow/airflow \
    --version 1.18.0 > airflow.yaml-1.18.0-default

helm upgrade --install airflow apache-airflow/airflow \
    -f airflow.yaml-1.18.0 \
    -n airflow \
    --version 1.18.0 --debug

kubectl -n airflow port-forward svc/airflow-api-server 8080:8080

helm show values apache-airflow/airflow \
    --version 1.21.0 > airflow.yaml-1.21.0-default

```



### 1.1 StorageClass

```bash
# 查看是否有默认 sc，并设置默认 sc
kubectl get sc
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 查看是否有默认 sc，并取消默认 sc
kubectl get sc -o yaml | grep is-default-class
kubectl patch storageclass old-sc-name \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```



```bash
kubectl delete -f ../01-persistent-airflow.yaml

kubectl apply  -f ../01-persistent-airflow.yaml

```



完整 StorageClass 和 PersistentVolume

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: airflow-postgres-sc
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: airflow-postgresql-pv
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: airflow-postgres-sc
  local:
    path: /data1/lib/airflow/postgres
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - cn-shanghai.10.160.11.184
```



