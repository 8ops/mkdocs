
kubectl get ns kube-app || kubectl create ns kube-app
kubectl get ns kube-server || kubectl create ns kube-server
kubectl get ns elastic-system || kubectl create ns elastic-system

kubectl get secret tls-8ops.top || \
    kubectl create secret tls tls-8ops.top --cert=app/lib/8ops.top.crt --key=app/lib/8ops.top.key
kubectl -n kube-app get secret tls-8ops.top || \
    kubectl -n kube-app create secret tls tls-8ops.top --cert=app/lib/8ops.top.crt --key=app/lib/8ops.top.key
kubectl -n kube-server get secret tls-8ops.top || \
    kubectl -n kube-server create secret tls tls-8ops.top --cert=app/lib/8ops.top.crt --key=app/lib/8ops.top.key
kubectl -n elastic-system get secret tls-8ops.top || \
    kubectl -n elastic-system create secret tls tls-8ops.top --cert=app/lib/8ops.top.crt --key=app/lib/8ops.top.key

printf "May be\n" 
printf "  kubectl delete secret tls-8ops.top \n" 
printf "  kubectl -n kube-app delete secret tls-8ops.top \n" 
printf "  kubectl -n kube-server delete secret tls-8ops.top \n" 
printf "  kubectl -n elastic-system delete secret tls-8ops.top \n" 
