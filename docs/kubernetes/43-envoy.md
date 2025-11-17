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
    - name: http
      protocol: HTTP
      port: 80
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

export GATEWAY_HOST=10.101.11.213

# global
kubectl get envoyproxy,gatewayclass -A

# gateway's policy
kubectl get gateway,backend,BackendTrafficPolicy,clienttrafficpolicy,securitypolicy,HTTPRouteFilter, -A

kubectl get httproute,svc

curl -i -H Host:echo.8ops.top http://${GATEWAY_HOST}/
curl -i -k -H Host:echo.8ops.top https://${GATEWAY_HOST}/
curl -i -k  -H Host:echo.8ops.top http://${GATEWAY_HOST}/echoserver

kubectl -n envoy-gateway-system logs -f \
  envoy-default-gw-3d45476e-59c895d5d7-x4zhr \
  -c envoy --tail 1 | \
  jq ".start_time, .response_code, .\"x-envoy-origin-path\""
```





## 三、策略

[Gateway API Extensions](https://gateway.envoyproxy.io/v1.5/concepts/gateway_api_extensions/)

Currently supported extensions include [`Backend`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#backend), [`BackendTrafficPolicy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#backendtrafficpolicy), [`ClientTrafficPolicy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#clienttrafficpolicy), [`EnvoyExtensionPolicy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#envoyextensionpolicy), [`EnvoyGateway`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#envoygateway), [`EnvoyPatchPolicy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#envoypatchpolicy), [`EnvoyProxy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#envoyproxy), [`HTTPRouteFilter`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#httproutefilter), and [`SecurityPolicy`](https://gateway.envoyproxy.io/v1.5/api/extension_types/#securitypolicy).



Tasks

- [Traffic](https://gateway.envoyproxy.io/v1.5/tasks/traffic/)

- [Security](https://gateway.envoyproxy.io/v1.5/tasks/security/)
- [Extensibility](https://gateway.envoyproxy.io/v1.5/tasks/extensibility/)
- [Observability](https://gateway.envoyproxy.io/v1.5/tasks/observability/)
- [Operations](https://gateway.envoyproxy.io/v1.5/tasks/operations/)

API References 

[Gateway API Extensions](https://gateway.envoyproxy.io/v1.5/api/extension_types/)



### 3.1 Backend Routing

动态代理访问

```bash
# support: extensionApis enableBackend (values.yaml)
kubectl -n envoy-gateway-system edit cm envoy-gateway-config

    extensionApis:
      enableBackend: true

kubectl -n envoy-gateway-system get cm envoy-gateway-config -o yaml
```



#### 3.1.1 Route to External Backend

```bash
# namespace: default
kubectl apply -f 3.1.1-route-to-external-backend.yaml
kubectl get HTTPRoute,Backend

curl -H Host:proxy.8ops.top http://${GATEWAY_HOST}/
```



#### 3.1.2 Dynamic Forward Proxy

```bash
# namespace: default
kubectl apply -f 3.1.2-dynamic-forward-proxy.yaml
kubectl get HTTPRoute,Backend

curl -H Host:books.8ops.top http://${GATEWAY_HOST}/
```



### 3.2 Circuit Breakers (BackendTrafficPolicy)

[Reference](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/upstream/circuit_breaking)

```bash
# namespace: default
kubectl apply -f 3.2-circuit-breakers.yaml
kubectl get BackendTrafficPolicy

# web 压测工具
hey -n 200 -c 200 -q 1000 -z 10s -host "echo.8ops.top" https://${GATEWAY_HOST}/hello
Summary:
  Total:	11.6784 secs
  Slowest:	3.4666 secs
  Fastest:	0.2025 secs
  Average:	0.9338 secs
  Requests/sec:	190.6937

  Total data:	250506 bytes
  Size/request:	112 bytes

Response time histogram:
  0.203 [1]	|
  0.529 [379]	|■■■■■■■■■■■■■■■■
  0.855 [963]	|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  1.182 [438]	|■■■■■■■■■■■■■■■■■■
  1.508 [197]	|■■■■■■■■
  1.835 [79]	|■■■
  2.161 [56]	|■■
  2.487 [56]	|■■
  2.814 [32]	|■
  3.140 [16]	|■
  3.467 [10]	|


Latency distribution:
  10% in 0.4961 secs
  25% in 0.6008 secs
  50% in 0.7965 secs
  75% in 1.0232 secs
  90% in 1.6177 secs
  95% in 2.1907 secs
  99% in 2.8577 secs

Details (average, fastest, slowest):
  DNS+dialup:	0.0282 secs, 0.2025 secs, 3.4666 secs
  DNS-lookup:	0.0024 secs, 0.0000 secs, 0.0264 secs
  req write:	0.0000 secs, 0.0000 secs, 0.0001 secs
  resp wait:	0.7080 secs, 0.2025 secs, 2.1924 secs
  resp read:	0.0000 secs, 0.0000 secs, 0.0003 secs

Status code distribution:
  [200]	159 responses
  [503]	2068 responses
```





### 3.3 Client Traffic Policy

[Reference](https://gateway.envoyproxy.io/v1.5/api/extension_types/#clienttrafficpolicy)

面向 *Client → Ingress* 方向的策略（限速、连接、TLS、HTTP options）

典型用途：

- 全局/分域限速
- 限制 client 最大连接数、超时时间
- 启用 HSTS、strip headers、清洗 headers
- 对入口流量进行 TLS 参数控制（版本、cipher suite）



```bash
# namespace: default
kubectl apply -f 3.3-client-traffic-policy.yaml
kubectl get ClientTrafficPolicy

# spec.tcpKeepalive.idleTime: 20m
# spec.tcpKeepalive.interval: 60s
curl -v -H "Host: echo.8ops.top" http://${GATEWAY_HOST}/get --next -H "Host: echo.8ops.top" http://${GATEWAY_HOST}/get

# Output
* Re-using existing connection with host echo.8ops.top
* Connection #0 to host echo.8ops.top left intact

# spec.clientIPDetection.xForwardedFor.numTrustedHops: 2
curl -v https://${GATEWAY_HOST}/get \
  -H "Host: echo.8ops.top" \
  -H "X-Forwarded-Proto: https" \
  -H "X-Forwarded-For: 1.1.1.1,2.2.2.2,3.3.3.3,4.4.4.4"

# spec.timeout.http.idleTimeout: 5s
# spec.timeout.http.requestReceivedTimeout: 2s
openssl s_client -crlf -servername "echo.8ops.top" -connect ${GATEWAY_HOST}:443

# spec.connection.connectionLimit.value: 5
hey -n 200 -c 10 -q 1 -z 10s -host "echo.8ops.top" https://${GATEWAY_HOST}/hello

```



### 3.4 Direct Response (HTTPRouteFilter)

```bash
# naemspace: default
kubectl apply -f 3.4-http-route-filter.yaml
kubectl get HTTPRouteFilter

curl --verbose --header "Host: direct-response.8ops.top" http://${GATEWAY_HOST}/inline
# 503
# Oops! Your request is not found.

curl --verbose --header "Host: direct-response.8ops.top" http://${GATEWAY_HOST}/value-ref
# 500
# {"error": "Internal Server Error"}
```



### 3.5 Failover (BackendTrafficPolicy)

```bash
# namespace: default
kubectl apply -f 3.5-failover.yaml
kubectl get BackendTrafficPolicy

for i in {1..10}; do curl --verbose --header "Host: failover.8ops.top" http://${GATEWAY_HOST}/test 2>/dev/null | jq .pod; done

```



### 3.6 Fault Injection (BackendTrafficPolicy)

```bash
# namespace: default
kubectl apply -f 3.6-fault-injection.yaml
kubectl get BackendTrafficPolicy

hey -n 1000 -c 100 -host "foo.8ops.top"  http://${GATEWAY_HOST}/foo
hey -n 10 -c 5 -z 5s -host "foo.8ops.top"  http://${GATEWAY_HOST}/foo
hey -n 5 -c 1 -q 1 -z 5s -host "foo.8ops.top"  http://${GATEWAY_HOST}/foo
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





