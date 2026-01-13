# Envoy

[Reference](https://gateway.envoyproxy.io/docs/tasks/quickstart/)



## 一、安装

### 1.1 Quick Install 

```bash
# 1) Install the Gateway API CRDs and Envoy Gateway:
GATEWAY_HELM_VERSION=1.6.0
helm show values oci://docker.io/envoyproxy/gateway-helm \
  --version ${GATEWAY_HELM_VERSION} > envoy-gateway.yaml-1.6.0-default

# Install
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version ${GATEWAY_HELM_VERSION} \
  -f envoy-gateway.yaml-${GATEWAY_HELM_VERSION} \
  -n envoy-gateway-system \
  --create-namespace \
  --debug | tee debug.out

# # Containers Images
# docker.io/envoyproxy/gateway:v1.6.0
# docker.io/envoyproxy/ratelimit:99d85510
# docker.io/envoyproxy/envoy:distroless-v1.36.2

# Upgrade
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version ${GATEWAY_HELM_VERSION} \
  -f envoy-gateway.yaml-${GATEWAY_HELM_VERSION} \
  -n envoy-gateway-system 

# Upgrade: Support Redis
kubectl apply -f 20-envoy-redis.yaml
kubectl -n envoy-gateway-system get deploy envoy-redis

helm upgrade eg oci://docker.io/envoyproxy/gateway-helm \
  --set config.envoyGateway.rateLimit.backend.type=Redis \
  --set config.envoyGateway.rateLimit.backend.redis.url="envoy-redis.envoy-gateway-system.svc.cluster.local:6379" \
  --reuse-values \
  -n envoy-gateway-system

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

export GATEWAY_HOST=$(kubectl get gateway gw -o jsonpath='{.status.addresses[0].value}')

# global
kubectl get envoyproxy,gatewayclass -A

# gateway's policy
kubectl get gateway,backend,BackendTrafficPolicy,clienttrafficpolicy,securitypolicy,HTTPRouteFilter -A

kubectl get httproute,svc

curl -i -H Host:echo.8ops.top http://${GATEWAY_HOST}/
curl -i -k -H Host:echo.8ops.top https://${GATEWAY_HOST}/
curl -i -k  -H Host:echo.8ops.top http://${GATEWAY_HOST}/echoserver

kubectl -n envoy-gateway-system logs -f \
  pod/envoy-default-gw-3d45476e-779fb9dc9d-kbf4g \
  -c envoy --tail 5 | \
  jq '.start_time, .response_code, ."x-envoy-origin-path"'

kubectl -n envoy-gateway-system logs -f \
  pod/envoy-default-gw-3d45476e-779fb9dc9d-x6zhr \
  -c envoy --tail 5 | \
  jq '.start_time, .response_code, ."x-envoy-origin-path", ."route_name"'
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



### 3.1 Backend

动态代理访问

```bash
# support: extensionApis enableBackend (values.yaml)
kubectl -n envoy-gateway-system edit cm envoy-gateway-config

    extensionApis:
      enableBackend: true

kubectl -n envoy-gateway-system get cm envoy-gateway-config -o yaml
```



#### 3.1.1 Route to External

```bash
kubectl apply -f 3.1.1-specific-proxy.yaml
kubectl get HTTPRoute,Backend

curl -I -H Host:proxy.8ops.top http://${GATEWAY_HOST}/
```



#### 3.1.2 Dynamic Forward Proxy

```bash
kubectl apply -f 3.1.2-dynamic-proxy.yaml
kubectl get HTTPRoute,Backend

curl -I -H Host:books.8ops.top http://${GATEWAY_HOST}/
```



### 3.2 BackendTrafficPolicy

#### 3.2.1 Circuit Breakers

```bash
# 慎用，会影响ratelimit
kubectl apply -f 3.2.1-circuit-breakers.yaml
kubectl get BackendTrafficPolicy

# web 压测工具
hey -n 200 -c 200 -q 200 -z 5s -host "echo.8ops.top" http://${GATEWAY_HOST}/hello
hey -n 2 -c 5 -q 250 -z 5s     -host "echo.8ops.top" http://${GATEWAY_HOST}/hello
# Output
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



#### 3.2.2 Failover

```bash
kubectl apply -f 3.2.2-failover.yaml
kubectl get BackendTrafficPolicy

for i in {1..10}
do 
  curl -v -H "Host: failover.8ops.top" \
  http://${GATEWAY_HOST}/test 2>/dev/null | jq .pod
done

```



#### 3.2.3 Fault Injection

```bash
# 未验证效果
kubectl apply -f 3.2.3-fault-injection.yaml
kubectl get BackendTrafficPolicy

curl -i -H "Host: fault-abort.8ops.top"  http://${GATEWAY_HOST}/abort
hey -n 5 -c 2 -q 1 -z 5s -host "fault-abort.8ops.top"  http://${GATEWAY_HOST}/abort

curl -i -H "Host: fault-delay.8ops.top"  http://${GATEWAY_HOST}/delay
hey -n 5 -c 2 -q 1 -z 5s -host "fault-delay.8ops.top"  http://${GATEWAY_HOST}/delay
```



#### 3.2.4 Rate Limit (Local)

```bash
kubectl apply -f 3.2.4-ratelimit-local.yaml
kubectl get HTTPRoute,BackendTrafficPolicy

curl -i -H "Host: ratelimit-local.8ops.top"  http://${GATEWAY_HOST}/ratelimit
hey -n 5 -c 2 -q 10 -z 5s -host "limit.8ops.top"  http://${GATEWAY_HOST}/ratelimit
# Output
Status code distribution:
  [200]	5 responses
  [429]	95 responses

# 【测试效果】
# 当externalTrafficPolicy设置成Local时流量在控制平面始终流向其中一个Pod
# 经测试与 circuitBreaker 同时应用时会不生效
# 当 clientSelectors 存在多个条件时，是与&的关系

for i in {0..9}
do
curl -I -H "Host: ratelimit-local.8ops.top" -H "x-user-id:one"  http://${GATEWAY_HOST}/ratelimit/${i}
done
# Output
x-ratelimit-limit: 10
x-ratelimit-remaining: 9
x-ratelimit-reset: 0

hey -n 5 -c 2 -q 10 -z 5s -host "ratelimit-local.8ops.top" -H "x-user-id:one"  http://${GATEWAY_HOST}/ratelimit
# Output
Status code distribution:
  [200]	100 responses

hey -n 5 -c 4 -q 10 -z 5s -host "ratelimit-local.8ops.top" -H "x-user-id:one"  http://${GATEWAY_HOST}/ratelimit
# Output
Status code distribution:
  [200]	116 responses
  [429]	81 responses

```



> ratelimit.yaml

```yaml
  rateLimit:
    type: Global
    global:
      rules:
      - clientSelectors:
        - sourceCIDR:
            value: 0.0.0.0/0
          headers:
          - name: x-user-id
            value: one
        limit:
          requests: 10
          unit: Second
```



>   修正 envoy-gateway 流量去单一Pod

```bash
# 【临时生效】
# envoy-gateway 设置为多副本时，当externalTrafficPolicy设置成Local时流量在控制平面始终流向其中一个Pod
kubectl -n envoy-gateway-system get service/envoy-default-gw-3d45476e -o jsonpath='{.spec.externalTrafficPolicy}'
kubectl -n envoy-gateway-system patch service envoy-default-gw-3d45476e -p '{"spec":{"externalTrafficPolicy":"Cluster"}}'

# 【持久生效】（两种patch方式）
kubectl -n envoy-gateway-system get EnvoyProxy config -o jsonpath='{.spec.provider.kubernetes.envoyService.externalTrafficPolicy}' 
kubectl -n envoy-gateway-system patch EnvoyProxy config --type='json' \
-p='[{"op":"replace","path":"/spec/provider/kubernetes/envoyService/externalTrafficPolicy","value":"Cluster"}]'
kubectl -n envoy-gateway-system patch EnvoyProxy config --type='merge' \
  -p='{"spec":{"provider":{"kubernetes":{"envoyService":{"externalTrafficPolicy":"Cluster"}}}}}'

```



#### 3.2.5 Rate Limit (Global)

```bash
kubectl apply -f 3.2.5-ratelimit-global.yaml
kubectl get HTTPRoute,BackendTrafficPolicy

for i in {0..9}
do
curl -I -H "Host: ratelimit-global.8ops.top" -H "x-user-id:one"  http://${GATEWAY_HOST}/ratelimit/${i}
done
# Output
x-ratelimit-limit: 10, 10;w=1
x-ratelimit-remaining: 9
x-ratelimit-reset: 1

hey -n 5 -c 2 -q 10 -z 5s -host "ratelimit-global.8ops.top" -H "x-user-id:one"  http://${GATEWAY_HOST}/ratelimit
# Output
Status code distribution:
  [200]	56 responses
  [429]	41 responses

hey -n 5 -c 1 -q 10 -z 5s -host "ratelimit-global.8ops.top" -H "x-user-id:one"  http://${GATEWAY_HOST}/ratelimit
# Output
Status code distribution:
  [200]	50 responses

```



#### 3.2.5 Rate Limit (Policy)

```bash
kubectl apply -f 3.2.6-policy-httproute.yaml
kubectl get HTTPRoute,BackendTrafficPolicy

for i in {1..4} 
do
curl -I -H "Host: ratelimit-http.8ops.top" -H "x-user-id: one" http://${GATEWAY_HOST}/get/${i}
done

for i in {1..4} 
do
curl -I -H "Host: ratelimit-http.8ops.top" -H "x-user-id: admin" http://${GATEWAY_HOST}/get/${i}
done

for j in {a..d}
do
for i in {1..4} 
do
curl -I -H "Host: ratelimit-http.8ops.top" -H "x-user-id: one-${i}" http://${GATEWAY_HOST}/get/${j}/${i}
done
done
```



#### 3.2.6 Rate Limit (merging)

```bash
kubectl apply -f 3.2.7-policy-merging.yaml
kubectl get HTTPRoute,BackendTrafficPolicy

# 【测试效果】
# 经测试与 circuitBreaker 同时应用时会不生效
# 当 global & local 策略生效时，优先级 httproute > gateway

curl -I -H "Host: echo.8ops.top" http://${GATEWAY_HOST}/get/${i}
curl -I -H "Host: ratelimit-local.8ops.top" -H "x-user-id:one"  http://${GATEWAY_HOST}/ratelimit/${i}
curl -I -H "Host: ratelimit-global.8ops.top" -H "x-user-id:one"  http://${GATEWAY_HOST}/ratelimit/${i}
curl -I -H "Host: ratelimit-http.8ops.top" -H "x-user-id: one" http://${GATEWAY_HOST}/get/${i}
# Output (global)
x-ratelimit-limit: 200, 200;w=1
x-ratelimit-remaining: 199
x-ratelimit-reset: 1

curl -I -H "Host: merging-http.8ops.top" http://${GATEWAY_HOST}/get
# Output (global & local)
x-ratelimit-limit: 200, 200;w=1
x-ratelimit-remaining: 199
x-ratelimit-reset: 1
x-ratelimit-limit: 2, 2;w=1
x-ratelimit-remaining: 1
x-ratelimit-reset: 1

for i in {1..5}
do
curl -I -H "Host: merging-http.8ops.top" http://${GATEWAY_HOST}/get/${i}
done

```





### 3.3 ClientTrafficPolicy

Client Traffic Policy

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

# spec.tcpKeepalive.idleTime: 60s
# spec.tcpKeepalive.interval: 60s
curl -v -H "Host: echo.8ops.top" http://${GATEWAY_HOST}/get \
  --next -H "Host: echo.8ops.top" http://${GATEWAY_HOST}/get
# Output
* Re-using existing connection with host echo.8ops.top
* Connection #0 to host echo.8ops.top left intact

# spec.clientIPDetection.xForwardedFor.numTrustedHops: 2
curl -v http://${GATEWAY_HOST}/get \
  -H "Host: echo.8ops.top" \
  -H "X-Forwarded-Proto: http" \
  -H "X-Forwarded-For: 1.1.1.1,2.2.2.2,3.3.3.3,4.4.4.4"

# spec.headers.disableRateLimitHeaders: false
curl -I -H "Host: limit.8ops.top" http://${GATEWAY_HOST}/get
# Output
HTTP/1.1 200 OK
content-type: application/json
x-content-type-options: nosniff
date: Tue, 18 Nov 2025 06:17:34 GMT
content-length: 417
x-ratelimit-limit: 4294967295
x-ratelimit-remaining: 4294967295
x-ratelimit-reset: 0

# spec.headers.requestID: Generate
curl -s -H "Host: echo.8ops.top" http://${GATEWAY_HOST}/get | \
  jq '.headers."X-Request-Id"'
curl -s -H "Host: echo.8ops.top" -H "X-Request-Id: abc" http://${GATEWAY_HOST}/get \
  | jq '.headers."X-Request-Id"'

# spec.tls.minVersion: "1.2"
curl -v -k -H "Host: echo.8ops.top" http://${GATEWAY_HOST}/get \
  --tls-max 1.1 --tlsv1.1
curl -v -k -H "Host: echo.8ops.top" http://${GATEWAY_HOST}/get \
  --tls-max 1.2 --tlsv1.2

# spec.timeout.http.idleTimeout: 10s
time openssl s_client -crlf -servername "echo.8ops.top" -connect ${GATEWAY_HOST}:443
# Output
real	0m10.042s
user	0m0.021s
sys	0m0.009s

# spec.connection.connectionLimit.value: 1
# spec.connection.connectionLimit.closeDelay: 1s
time hey -n 5 -c 5 -q 5 -z 5s -host "echo.8ops.top" https://${GATEWAY_HOST}/connectionlimit
# Output unlimited 
Status code distribution:
  [200]	125 responses
# Output limited
Status code distribution:
  [200]	35 responses

Error distribution:
  [4]	Get "https://10.101.11.213/connectionlimit": EOF
```



### 3.4 HTTPRoute



#### 3.4.1 HTTP Redirect

```bash
kubectl apply -f 3.4.1-http-redirect.yaml
kubectl get HTTPRoute

curl -v -H "Host: http-redirect.8ops.top" http://${GATEWAY_HOST}

```

#### 3.4.2 HTTP TLS Redirect

```bash
kubectl apply -f 3.4.2-http-tls.yaml
kubectl get HTTPRoute

curl -v -H "Host: http-tls.8ops.top" http://${GATEWAY_HOST}
curl -v -k -H "Host: http-tls.8ops.top" https://${GATEWAY_HOST}

# multi domain+tls
curl -v -H "Host: http-tls.u3c.ai" http://${GATEWAY_HOST}
curl -v -k -H "Host: http-tls.u3c.ai" https://${GATEWAY_HOST}

curl -v -H "Host: echo.u3c.ai" http://${GATEWAY_HOST}

# 测试效果
# 1，当监听证书匹配不上，会默认使用第一个证书。建议多gateway-listeners
# 2，同一个listeners里面不能同时监听同一端口，或者port+name+Protocol
# 3，httproter中当不指定sectionName时会默认监听所有预定义端口

```



`gateway-gw.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gw
spec:
  gatewayClassName: gc
  listeners:
  - name: http
    protocol: HTTP
    port: 80
  - name: http-8080
    protocol: HTTP
    port: 8080
  - name: https
    protocol: HTTPS
    allowedRoutes:
      namespaces:
        from: All
    port: 443
    tls:
      mode: Terminate
      certificateRefs:
      - group: ""
        kind: Secret
        name: tls-8ops.top
      - group: ""
        kind: Secret
        name: tls-u3c.ai
```



`httproute-tls.yaml`

```yaml
kind: HTTPRoute
metadata:
  name: http-tls-v2
spec:
  parentRefs:
    - name: gw
      sectionName: http-8080
```







### 3.5 HTTPRouteFilter

#### 3.5.1 Direct Response

```bash
kubectl apply -f 3.5.1-direct-response.yaml
kubectl get HTTPRouteFilter

curl -v -H "Host: direct-response.8ops.top" http://${GATEWAY_HOST}/inline
# Output: 503
# Oops! Your request is not found.

curl -v -H "Host: direct-response.8ops.top" http://${GATEWAY_HOST}/value-ref
# Output: 500
# {"error": "Internal Server Error"}
```



#### 3.5.2 URLRewrite

- ReplacePrefixMatch
- ReplaceFullPath
- URLRewrite

```bash
kubectl apply -f 3.5.2-url-rewirte.yaml

# spec.rules[filters[]]
curl -v -H "Host: path-rewrite.8ops.top" http://${GATEWAY_HOST}/api/v1/xx
# Output
	request_uri=http://path-rewrite.8ops.top:8080/path/xx
	
# url（debug）
# curl -I -H "Host: url-rewrite.8ops.top" http://${GATEWAY_HOST}/old
```



### 3.6 External IPS

```bash
kubectl patch gateway gw --type=json --patch '
- op: add
  path: /spec/addresses
  value:
   - type: IPAddress
     value: 1.2.3.4
'

kubectl patch gateway gw --type=json --patch '
- op: remove
  path: /spec/addresses
  value:
   - type: IPAddress
     value: 1.2.3.4
'

kubectl get service -n envoy-gateway-system
```



### 3.7 HTTP CONNECT Tunnels

```bash
kubectl apply -f 3.7-http-connect-tunnels.yaml
kubectl get httproute,httproute,backendtrafficpolicy

export PROXY_GATEWAY_HOST=$(kubectl get gateway/connect-proxy -o jsonpath='{.status.addresses[0].value}')

curl -ik -v -x ${PROXY_GATEWAY_HOST}:80 https://httpbin.org | grep -o "<title>.*</title>"

kubectl logs -f -n envoy-gateway-system pod/envoy-default-connect-proxy-f7d7286e-5764598547-6vzlb --tail 10
kubectl logs -n envoy-gateway-system deployments/envoy-default-connect-proxy-f7d7286e | tail -n 1 | jq | grep method
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





