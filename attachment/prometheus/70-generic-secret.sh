
kubectl create secret generic etcd-certs \
  --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  --from-file=/etc/kubernetes/pki/etcd/ca.crt \
  -n kube-server


