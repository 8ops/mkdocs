# Envoy

[Reference](https://gateway.envoyproxy.io/docs/tasks/quickstart/)



## 一、安装

### 1.1 Quick Install 

```bash
# 1) Install the Gateway API CRDs and Envoy Gateway:
GATEWAY_HELM_VERSION=1.6.0
helm show values oci://docker.io/envoyproxy/gateway-helm \
  --version ${GATEWAY_HELM_VERSION} > envoy-gateway.yaml-1.6.0-default

helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version ${GATEWAY_HELM_VERSION} \
  -f envoy-gateway.yaml-${GATEWAY_HELM_VERSION} \
  -n envoy-gateway-system \
  --create-namespace \
  --debug | tee debug.out

helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version ${GATEWAY_HELM_VERSION} \
  -f envoy-gateway.yaml-${GATEWAY_HELM_VERSION} \
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

vim 20-envoy-gateway-${ENVOY_GATEWAY_VERSION}.yaml
vim 20-envoy-quickstart.yaml

kubectl apply -f 20-envoy-gateway-${ENVOY_GATEWAY_VERSION}.yaml
kubectl apply -f 20-envoy-quickstart.yaml

```



### 1.2 YAML

#### 1.2.1 values.yaml

```yaml
# envoy-gateway.yaml-1.6.0
global:
  images:
    envoyGateway:
      image: hub.8ops.top/google_containers/envoyproxy-gateway:v1.6.0
      pullPolicy: IfNotPresent
    ratelimit:
      image: hub.8ops.top/google_containers/envoyproxy-ratelimit:99d85510
      pullPolicy: IfNotPresent

deployment:
  envoyGateway:
    resources:
      limits:
        cpu: 1
        memory: 1Gi
      requests:
        cpu: 50m
        memory: 64Mi

service:
  type: "ClusterIP"

config:
  envoyGateway:
    gateway:
      controllerName: gateway.envoyproxy.io/gatewayclass-controller
    provider:
      type: Kubernetes
    logging:
      level:
        default: info
    extensionApis:
      enableBackend: true
```



#### 1.2.2 quickstart.yaml

`20-envoy-gateway-quickstart-v1.6.0.yaml`

- EnvoyProxy
- GatewayClass
- Gateway

```yaml
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
  name: gc
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
  name: gw
  namespace: default
spec:
  gatewayClassName: gc
  listeners:
#     - name: http
#       protocol: HTTP
#       port: 80
    - name: https
      protocol: HTTPS
      allowedRoutes:
        namespaces:
          from: All
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
        - kind: Secret
          name: tls-8ops.top
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: ClientTrafficPolicy
metadata:
  name: global-client-traffic-policy
  namespace: envoy-gateway-system
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: gw
  headers:
    enableEnvoyHeaders: true
  http3: {}
  tcpKeepalive:
    idleTime: 20m
    interval: 60s
    probes: 3
  timeout:
    http:
      idleTimeout: 30s
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: global-security-policy
  namespace: envoy-gateway-system
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: gw
  authorization:
    defaultAction: Deny
    rules:
      - action: Allow
        principal:
          clientCIDRs:
            - 10.110.83.0/26
```



#### 1.2.3 basic.yaml

`3.0-backend-basic.yaml`

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend
  namespace: default
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: default
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
  namespace: default
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
  namespace: default
spec:
  parentRefs:
    - name: gw
  hostnames:
    - "echo.8ops.top"
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
    - backendRefs:
        - group: ""
          kind: Service
          name: echoserver
          port: 8080
          weight: 1
      matches:
        - path:
            type: PathPrefix
            value: /echoserver
```





## 二、使用

```bash
kubectl -n envoy-gateway-system get EnvoyProxy config
kubectl -n envoy-gateway-system logs -f envoy-default-eg-e41e7b31-798989bdc7-6hvsm -c envoy

kubectl get envoyproxy,gatewayclass,gateway,clienttrafficpolicy,securitypolicy -A

kubectl get httproute,svc

curl -i -H Host:echo.8ops.top http://10.101.11.213/
curl -i -k -H Host:echo.8ops.top https://10.101.11.213/
curl -i -k  -H Host:echo.8ops.top http://10.101.11.213/echoserver

kubectl -n envoy-gateway-system logs -f \
  envoy-default-gw-3d45476e-59c895d5d7-x4zhr \
  -c envoy --tail 1 | \
  jq ".start_time, .response_code, .\"x-envoy-origin-path\""
```





## 三、策略

[Gateway API Extensions](https://gateway.envoyproxy.io/v1.5/concepts/gateway_api_extensions/)

Currently supported extensions include [`Backend`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#backend), [`BackendTrafficPolicy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#backendtrafficpolicy), [`ClientTrafficPolicy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#clienttrafficpolicy), [`EnvoyExtensionPolicy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#envoyextensionpolicy), [`EnvoyGateway`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#envoygateway), [`EnvoyPatchPolicy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#envoypatchpolicy), [`EnvoyProxy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#envoyproxy), [`HTTPRouteFilter`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#httproutefilter), and [`SecurityPolicy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#securitypolicy).



[Traffic](https://gateway.envoyproxy.io/v1.5/tasks/traffic/)



### 3.1 Backend Routing

动态代理访问

```bash
# extensionApis enableBackend (values.yaml)
kubectl -n envoy-gateway-system edit cm envoy-gateway-config

    extensionApis:
      enableBackend: true


```



#### 3.1.1 Route to External Backend

```bash
kubectl apply -f 3.1.1-route-to-external-backend.yaml

kubectl get HTTPRoute,Backend

curl -H Host:proxy-demo.8ops.top http://10.101.11.213/
```



#### 3.1.2 Dynamic Forward Proxy

```bash
kubectl apply -f 3.1.2-dynamic-forward-proxy.yaml

kubectl get HTTPRoute,Backend

curl -H Host:books.8ops.top http://10.101.11.213/
```



### 3.2 Circuit Breakers

```bash
kubectl apply -f 3.2-circuit-breakers.yaml

kubectl get BackendTrafficPolicy

# web 压测工具
hey -c 2 -q 1 -z 10s https://echo.8ops.top/hello

Summary:
  Total:	10.0070 secs
  Slowest:	0.1193 secs
  Fastest:	0.0045 secs
  Average:	0.0177 secs
  Requests/sec:	1.9986

  Total data:	1620 bytes
  Size/request:	81 bytes

Response time histogram:
  0.004 [1]	|■■
  0.016 [17]	|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.027 [0]	|
  0.039 [0]	|
  0.050 [0]	|
  0.062 [0]	|
  0.073 [0]	|
  0.085 [0]	|
  0.096 [0]	|
  0.108 [0]	|
  0.119 [2]	|■■■■■


Latency distribution:
  10% in 0.0047 secs
  25% in 0.0051 secs
  50% in 0.0062 secs
  75% in 0.0086 secs
  90% in 0.1193 secs
  95% in 0.1193 secs
  0% in 0.0000 secs

Details (average, fastest, slowest):
  DNS+dialup:	0.0112 secs, 0.0045 secs, 0.1193 secs
  DNS-lookup:	0.0089 secs, 0.0000 secs, 0.0895 secs
  req write:	0.0001 secs, 0.0000 secs, 0.0002 secs
  resp wait:	0.0060 secs, 0.0043 secs, 0.0095 secs
  resp read:	0.0001 secs, 0.0000 secs, 0.0002 secs

Status code distribution:
  [503]	20 responses
```





### 3.1111 ClientTrafficPolicy

面向 *Client → Ingress* 方向的策略（限速、连接、TLS、HTTP options）

典型用途：

- 全局/分域限速
- 限制 client 最大连接数、超时时间
- 启用 HSTS、strip headers、清洗 headers
- 对入口流量进行 TLS 参数控制（版本、cipher suite）



```bash




```





### 3.2- BackendTrafficPolicy

面向 *Route → Backend* 方向（重试、超时、负载均衡、连接池）





### 3.3 -SecurityPolicy

横向的安全策略（JWT、mTLS、IP 限制、WAF）



```bash
# 验证白名单
curl -i -k -H Host:echo.8ops.top https://10.101.11.213/hello

kubectl -n envoy-gateway-system rollout restart deploy envoy-default-gw-3d45476e
kubectl -n envoy-gateway-system rollout restart deploy envoy-gateway


```





## 四、番外

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

### 4.2 kustomization

```bash
# 保留官方原始YAML文件，动态替换私有镜像
# 方便分开维护
mkdir -p custom_yaml && cd custom_yaml
wget https://github.com/envoyproxy/gateway/releases/download/v1.6.0/install.yaml
vim kustomization.yaml
kubectl apply -k .
```



```yaml
resources:
  - install.yaml

images:
  - name: docker.io/envoyproxy/envoy
    newName: hub.8ops.top/google_containers/envoyproxy-envoy
    newTag: distroless-v1.36.2
  - name: envoyproxy/envoy
    newName: hub.8ops.top/google_containers/envoyproxy-envoy
    newTag: distroless-v1.36.2
  - name: docker.io/envoyproxy/ratelimit
    newName: hub.8ops.top/google_containers/envoyproxy-ratelimit
    newTag: 99d85510
  - name: docker.io/envoyproxy/gateway
    newName: hub.8ops.top/google_containers/envoyproxy-gateway
    newTag: v1.6.0
  - name: envoyproxy/gateway
    newName: hub.8ops.top/google_containers/envoyproxy-gateway
    newTag: v1.6.0
```





