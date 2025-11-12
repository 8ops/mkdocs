# Envoy

[Reference](https://www.envoyproxy.io/docs)

## 一、helm 

```bash
# # 未通过，requires helm>3.8，oci，镜像未完全替换
# helm install eg oci://docker.io/envoyproxy/gateway-helm \
#   --version 1.5.4 \
#   -f gateway-helm.yaml-1.5.4 \
#   -n envoy-gateway-system \
#   --create-namespace \
#   --dry-run --debug 
# 
# # Containers Images
# docker.io/envoyproxy/gateway:v1.5.4
# docker.io/envoyproxy/ratelimit:e74a664a
# docker.io/envoyproxy/envoy:distroless-v1.35.6

```



## 二、install

```bash
# 1) 准备：创建命名空间
kubectl create namespace envoy-gateway-system

# 2) 安装 Gateway API CRDs (仅需要安装一次)
ENVOY_GATEWAY_API_VERSION=v1.4.0
curl -sL -k -o 20-gateway-api-crds-${ENVOY_GATEWAY_API_VERSION}.yaml \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/${ENVOY_GATEWAY_API_VERSION}/standard-install.yaml

kubectl apply -f 20-gateway-api-crds-${ENVOY_GATEWAY_API_VERSION}.yaml
kubectl get crd gatewayclasses.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io gateways.gateway.networking.k8s.io

# 3) 安装 Envoy Gateway 控制器（YAML）
ENVOY_GATEWY_VERSION=v1.5.4
curl -sL -k -o 20-gateway-install-${ENVOY_GATEWY_VERSION}.yaml-default \
  https://github.com/envoyproxy/gateway/releases/download/${ENVOY_GATEWY_VERSION}/install.yaml

vim 20-gateway-install-${ENVOY_GATEWY_VERSION}.yaml

kubectl apply -f 20-gateway-install-${ENVOY_GATEWY_VERSION}.yaml

# kubectl -n envoy-gateway-system set image deployment/envoy-default-eg-e41e7b31 \
#   envoy=hub.8ops.top/google_containers/envoyproxy-envoy:distroless-v1.35.6

kubectl -n envoy-gateway-system patch deployment envoy-default-eg-e41e7b31 \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/image","value":"hub.8ops.top/google_containers/envoyproxy-envoy:distroless-v1.35.6"}]'


# 4) 部署示例后端 + GatewayClass/Gateway/HTTPRoute
ENVOY_GATEWAY_VERSION=v1.5.4
curl -sL -o 20-envoy-gateway-demo-${ENVOY_GATEWAY_VERSION}.yaml-default \
  https://github.com/envoyproxy/gateway/releases/download/${ENVOY_GATEWAY_VERSION}/quickstart.yaml

vim 20-envoy-gateway-demo-${ENVOY_GATEWAY_VERSION}.yaml

kubectl apply -f 20-envoy-gateway-${ENVOY_GATEWAY_VERSION}.yaml

# 临时测试
kubectl -n default port-forward --address 0.0.0.0 service/backend 3000:3000 &


# 5) 验证（等待资源准备）
kubectl -n envoy-gateway-system get pods
kubectl get gateway,httproute -A
kubectl -n envoy-gateway-system logs deploy/envoy-gateway -f

```





