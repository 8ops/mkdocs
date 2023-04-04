# DataOps

`Observability`

## 一、搭建 Opentelemetry



```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm search repo opentelemetry

helm show values open-telemetry/opentelemetry-collector > opentelemetry-collector.yaml-0.31.3-default
helm show values open-telemetry/opentelemetry-operator > opentelemetry-operator.yaml-0.12.2-default
helm show values open-telemetry/opentelemetry-demo > opentelemetry-demo.yaml-0.3.0-default

helm install my-otel-demo open-telemetry/opentelemetry-demo


# Example
#   https://books.8ops.top/attachment/opentelemetry/helm/opentelemetry-collector.yaml-0.31.3

helm install opentelemetry-collector open-telemetry/opentelemetry-collector \
    -f opentelemetry-collector.yaml-0.31.3 \
    -n kube-server \
    --version 0.31.3 --debug
    
    
    
```

















