# 日常应用



强制删除命令空间

```bash
# 1
kubectl delete ns <> --force=true --grace-period=0

# 2
kubectl get ns kube-server -o json > kube-server.json

## edit kube-server.json
# spec.finalize=[]

kubectl proxy 

curl -i -k -H "Content-Type: application/json" \
  -X PUT \
  --data-binary @kube-server.json \
  http://127.0.0.1:8001/api/v1/namespaces/kube-server/finalize

# 3
kubectl get ns kube-server -o json > kube-server.json

## edit kube-server.json
# spec.finalize=[]
kubectl replace --raw "/api/v1/namespaces/kube-server/finalize" -f kube-server.json

# 3
kubectl proxy

python3 force-remove.py kube-server

#!/usr/bin/env python3
import atexit
import json
import requests
import subprocess
import sys

namespace = sys.argv[1]
proxy_process = subprocess.Popen(['kubectl', 'proxy'])
atexit.register(proxy_process.kill)
p = subprocess.Popen(['kubectl', 'get', 'namespace', namespace, '-o', 'json'], stdout=subprocess.PIPE)
p.wait()
data = json.load(p.stdout)
data['spec']['finalizers'] = []
requests.put('http://127.0.0.1:8001/api/v1/namespaces/{}/finalize'.format(namespace), json=data).raise_for_status()

# 4
kubectl edit ns kube-server
## remove config
#  finalizers:
#  - controller.cattle.io/namespace-auth
```

