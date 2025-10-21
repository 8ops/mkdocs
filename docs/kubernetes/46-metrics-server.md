# metrices-server

自定义metrices-server时，需要变更全局引用映射关系

```bash
 kubectl get apiservice v1beta1.metrics.k8s.io  -o yaml
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"apiregistration.k8s.io/v1","kind":"APIService","metadata":{"annotations":{},"labels":{"k8s-app":"metrics-server"},"name":"v1beta1.metrics.k8s.io"},"spec":{"group":"metrics.k8s.io","groupPriorityMinimum":100,"insecureSkipTLSVerify":true,"service":{"name":"metrics-server","namespace":"kube-system"},"version":"v1beta1","versionPriority":100}}
    meta.helm.sh/release-name: kubernetes-dashboard
    meta.helm.sh/release-namespace: kube-server
  creationTimestamp: "2022-05-06T14:42:57Z"
  labels:
    k8s-app: metrics-server
  name: v1beta1.metrics.k8s.io
  resourceVersion: "366184122"
  uid: dddbe175-6021-46d3-ab1d-35d301d32849
spec:
  group: metrics.k8s.io
  groupPriorityMinimum: 100
  insecureSkipTLSVerify: true
  service: # 变更这儿的映射关系
    name: kubernetes-dashboard-metrics-server
    namespace: kube-server
    port: 443
  version: v1beta1
  versionPriority: 100
```
