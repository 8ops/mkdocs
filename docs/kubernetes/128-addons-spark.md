# Spark



## 一、install

```bash
# 未成功
REGISTRY_NAME=registry-1.docker.io
REPOSITORY_NAME=bitnamicharts

helm registry login ${REGISTRY_NAME} --username <username> --password <password>

helm install spark oci://${REGISTRY_NAME}/${REPOSITORY_NAME}/spark \
    -f spark.yaml-10.0.3 \
    -n kube-bigdata \
    --debug

```



```bash
# 未成功

# Add the Helm repo
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm repo update spark-operator
helm search repo spark-operator

helm show values spark-operator/spark-operator \
    --version 2.5.0 > spark-operator.yaml-2.5.0-default

# Install the chart
helm install spark-operator spark-operator/spark-operator \
  --namespace kube-bigdata \
  --create-namespace \

```



```bash
# kubectl apply -f spark-pi.yaml

apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: spark-pi
  namespace: default
spec:
  type: Scala
  mode: cluster
  image: "apache/spark:latest"
  imagePullPolicy: Always
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples_2.12-3.5.3.jar"
  sparkVersion: "3.5.3"
  restartPolicy:
    type: Never
  driver:
    cores: 1
    coreLimit: "1200m"
    memory: "512m"
    labels:
      version: 3.5.3
    serviceAccount: my-spark-operator-spark
  executor:
    cores: 1
    instances: 2
    memory: "512m"
    labels:
      version: 3.5.3

```

