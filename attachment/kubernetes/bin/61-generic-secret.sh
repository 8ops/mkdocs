#!/bin/bash

scp 8ops.top:~/.acme.sh/8ops.top/fullchain.cer 8ops.top.crt
scp 8ops.top:~/.acme.sh/8ops.top/8ops.top.key  8ops.top.key

kubectl delete secret tls-8ops.top
kubectl create secret tls tls-8ops.top --cert=8ops.top.crt --key=8ops.top.key

kubectl -n kube-server delete secret tls-8ops.top
kubectl -n kube-server create secret tls tls-8ops.top --cert=8ops.top.crt --key=8ops.top.key

rm -f 8ops.top.crt 8ops.top.key


