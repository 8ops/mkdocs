# Envoy

[Reference](https://www.envoyproxy.io/docs)

## 一、安装

### 1.1 quick install 

```bash
# 1) Install the Gateway API CRDs and Envoy Gateway:
helm show values oci://docker.io/envoyproxy/gateway-helm \
  --version 1.6.0 > envoy-gateway.yaml-1.6.0-default

helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version 1.6.0 \
  -f envoy-gateway.yaml-1.6.0 \
  -n envoy-gateway-system \
  --create-namespace \
  --debug | tee debug.out

helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version 1.6.0 \
  -f envoy-gateway-helm.yaml-1.6.0 \
  -n envoy-gateway-system 

# # Containers Images
# docker.io/envoyproxy/gateway:v1.6.0
# docker.io/envoyproxy/ratelimit:99d85510
# docker.io/envoyproxy/envoy:distroless-v1.36.2

kubectl get crds \
  backendtlspolicies.gateway.networking.k8s.io \
  gatewayclasses.gateway.networking.k8s.io \
  gateways.gateway.networking.k8s.io \
  grpcroutes.gateway.networking.k8s.io \
  httproutes.gateway.networking.k8s.io \
  referencegrants.gateway.networking.k8s.io

# 2) Install GatewayClass/Gateway/HTTPRoute
ENVOY_GATEWAY_VERSION=v1.6.0
curl -sL -o 20-envoy-gateway-quickstart-${ENVOY_GATEWAY_VERSION}.yaml-default \
  https://github.com/envoyproxy/gateway/releases/download/${ENVOY_GATEWAY_VERSION}/quickstart.yaml

vim 20-envoy-gateway-quickstart-${ENVOY_GATEWAY_VERSION}.yaml

kubectl apply -f 20-envoy-gateway-quickstart-${ENVOY_GATEWAY_VERSION}.yaml

```



### 1.2 YAML

#### 1.2.1 values.yaml

```yaml
# envoy-gateway.yaml-1.6.0
certgen:
  job:
    affinity: {}
    annotations: {}
    args: []
    nodeSelector: {}
    pod:
      annotations: {}
      labels: {}
    resources: {}
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      privileged: false
      readOnlyRootFilesystem: true
      runAsGroup: 65532
      runAsNonRoot: true
      runAsUser: 65532
      seccompProfile:
        type: RuntimeDefault
    tolerations: []
    ttlSecondsAfterFinished: 30
  rbac:
    annotations: {}
    labels: {}
config:
  envoyGateway:
    extensionApis: {}
    gateway:
      controllerName: gateway.envoyproxy.io/gatewayclass-controller
    logging:
      level:
        default: info
    provider:
      type: Kubernetes
createNamespace: false
deployment:
  annotations: {}
  envoyGateway:
    image:
      repository: ""
      tag: ""
    imagePullPolicy: ""
    imagePullSecrets: []
    resources:
      limits:
        cpu: 1
        memory: 1Gi
      requests:
        cpu: 100m
        memory: 256Mi
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop:
        - ALL
      privileged: false
      runAsGroup: 65532
      runAsNonRoot: true
      runAsUser: 65532
      seccompProfile:
        type: RuntimeDefault
  pod:
    affinity: {}
    annotations:
      prometheus.io/port: "19001"
      prometheus.io/scrape: "true"
    labels: {}
    nodeSelector: {}
    tolerations: []
    topologySpreadConstraints: []
  ports:
  - name: grpc
    port: 18000
    targetPort: 18000
  - name: ratelimit
    port: 18001
    targetPort: 18001
  - name: wasm
    port: 18002
    targetPort: 18002
  - name: metrics
    port: 19001
    targetPort: 19001
  priorityClassName: null
  replicas: 1
global:
  imagePullSecrets: []
  imageRegistry: ""
  images:
    envoyGateway:
      image: hub.8ops.top/google_containers/envoyproxy-gateway:v1.6.0
      pullPolicy: IfNotPresent
      pullSecrets: []
    ratelimit:
      image: hub.8ops.top/google_containers/envoyproxy-ratelimit:99d85510
      pullPolicy: IfNotPresent
      pullSecrets: []
    envoyProxy:
      image: hub.8ops.top/google_containers/envoyproxy-envoy:distroless-v1.36.2
      pullPolicy: IfNotPresent
      pullSecrets: []
hpa:
  behavior: {}
  enabled: false
  maxReplicas: 1
  metrics: []
  minReplicas: 1
kubernetesClusterDomain: cluster.local
podDisruptionBudget:
  minAvailable: 0
service:
  annotations: {}
  trafficDistribution: ""
topologyInjector:
  annotations: {}
  enabled: true
```



#### 1.2.2 quickstart.yaml

```yaml
# 20-envoy-gateway-quickstart-v1.6.0.yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: config
  namespace: envoy-gateway-system
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyDeployment:
        replicas: 1
        container:
          image: hub.8ops.top/google_containers/envoyproxy-envoy:distroless-v1.36.2
          resources:
            limits:
              cpu: 500m
              memory: 1Gi
            requests:
              cpu: 50m
              memory: 64Mi
      envoyService:
        type: LoadBalancer
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: config
    namespace: envoy-gateway-system
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eg
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  labels:
    app: backend
    service: backend
spec:
  ports:
    - name: http
      port: 3000
      targetPort: 3000
  selector:
    app: backend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      version: v1
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      serviceAccountName: backend
      containers:
        - image: hub.8ops.top/google_containers/envoy-echo-basic:v20231214-v1.0.0-140-gf544a46e
          imagePullPolicy: IfNotPresent
          name: backend
          ports:
            - containerPort: 3000
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backend
spec:
  parentRefs:
    - name: eg
  hostnames:
    - "www.example.com"
  rules:
    - backendRefs:
        - group: ""
          kind: Service
          name: backend
          port: 3000
          weight: 1
      matches:
        - path:
            type: PathPrefix
            value: /
```





## 二、使用



## 三、策略



## 四、其他

### 4.1 官方YAML安装

遇annotations过大，未通过。

```bash
# 1) 准备：创建命名空间
kubectl create namespace envoy-gateway-system

# 2) 安装 Gateway API CRDs (仅需要安装一次)
ENVOY_GATEWAY_API_VERSION=v1.4.0
curl -sL -k -o 20-gateway-api-crds-${ENVOY_GATEWAY_API_VERSION}.yaml \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/${ENVOY_GATEWAY_API_VERSION}/standard-install.yaml

kubectl apply -f 20-gateway-api-crds-${ENVOY_GATEWAY_API_VERSION}.yaml

# # 清除crds annotations过大报错问题
# yq eval-all 'del(.metadata.annotations)' -i install.yaml

# 3) 安装 Envoy Gateway 控制器（YAML）
ENVOY_GATEWAY_VERSION=v1.6.0
curl -sL -k -o 20-envoy-gateway-install-${ENVOY_GATEWAY_VERSION}.yaml-default \
  https://github.com/envoyproxy/gateway/releases/download/${ENVOY_GATEWAY_VERSION}/install.yaml

vim 20-gateway-install-${ENVOY_GATEWAY_VERSION}.yaml

kubectl apply -f 20-gateway-install-${ENVOY_GATEWAY_VERSION}.yaml

# # Containers Images
#             image: docker.io/envoyproxy/ratelimit:99d85510
#           image: envoyproxy/gateway:v1.6.0
#         image: envoyproxy/gateway:v1.6.0
# hub.8ops.top/google_containers/envoyproxy-gateway:v1.6.0

# # 变更镜像（尝试效果：会马上回退成原生）
# kubectl -n envoy-gateway-system set image deployment/envoy-default-eg-e41e7b31 \
#   envoy=hub.8ops.top/google_containers/envoyproxy-envoy:distroless-v1.36.2
# # OR
# kubectl -n envoy-gateway-system patch deployment envoy-default-eg-e41e7b31 \
#   --type='json' \
#   -p='[{"op":"replace","path":"/spec/template/spec/containers/0/image","value":"hub.8ops.top/google_containers/envoyproxy-envoy:distroless-v1.36.2"}]'

# 4) 部署示例后端 + GatewayClass/Gateway/HTTPRoute
curl -sL -o 20-envoy-gateway-quickstart-${ENVOY_GATEWAY_VERSION}.yaml-default \
  https://github.com/envoyproxy/gateway/releases/download/${ENVOY_GATEWAY_VERSION}/quickstart.yaml

vim 20-envoy-gateway-quickstart-${ENVOY_GATEWAY_VERSION}.yaml

kubectl apply -f 20-envoy-gateway-quickstart-${ENVOY_GATEWAY_VERSION}.yaml

# 临时测试
kubectl -n default port-forward --address 0.0.0.0 service/backend 3000:3000 &


# 5) 验证（等待资源准备）
kubectl -n envoy-gateway-system get pods
kubectl get gateway,httproute -A
kubectl -n envoy-gateway-system logs deploy/envoy-gateway -f

```





