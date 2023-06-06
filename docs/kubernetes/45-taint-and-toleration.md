# Taints and Tolerations

[Reference](https://kubernetes.io/zh-cn/docs/concepts/scheduling-eviction/taint-and-toleration/)

```bash
# --- 
kubectl taint nodes k-node-03 node-role.kubernetes.io/prometheus:NoSchedule
kubectl taint nodes k-node-03 node-role.kubernetes.io/prometheus:NoSchedule-

kubectl taint nodes k-k8s-node-03 node-role.kubernetes.io/elastic:NoSchedule
kubectl taint nodes k-node-03 node-role.kubernetes.io/elastic:NoSchedule-

# --- 
NODE
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/control-plane
# Taints:             node-role.kubernetes.io/control-plane:NoSchedule
POD
  tolerations:
  - effect: NoExecute
    operator: Exists
POD
# daemonset.apps/kube-flannel-ds, daemonset.apps/kube-proxy
      tolerations:
      - operator: Exists

# --- 
NODE
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/prometheus
# Taints:             node-role.kubernetes.io/prometheus:NoSchedule
# deployment.apps/echoserver
      tolerations:
      - operator: Exists

# --- 
kubectl get no k-k8s-master-01 -o=jsonpath='{.spec.taints}';echo
kubectl get no k-k8s-node-01 -o=jsonpath='{.spec.taints}';echo
kubectl get no k-k8s-node-02 -o=jsonpath='{.spec.taints}';echo
kubectl get no k-k8s-node-03 -o=jsonpath='{.spec.taints}';echo

kubectl patch node k-k8s-node-03 -p '{"spec":{"taints":[]}}'

```

> 效果选择

| 效果               | 说明                                                         |
| :----------------- | :----------------------------------------------------------- |
| `NoSchedule`       | 不能容忍此污点的 Pod 不会被调度到节点上；现有 Pod 不会从节点中逐出。 |
| `PreferNoSchedule` | Kubernetes 会尽量避免将不能容忍此污点的 Pod 调度到节点上。   |
| `NoExecute`        | 如果 Pod 已在节点上运行，则该 Pod 会从节点中被逐出；如果尚未在节点上运行，则不会被调度到节点上。 |