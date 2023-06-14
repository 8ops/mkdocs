# ArgoCD



## 一、安装

```bash
helm repo add argoproj https://argoproj.github.io/argo-helm
helm repo update argoproj
helm search repo argo-cd
helm show values argoproj/argo-cd --version 5.13.8 > argocd-configs.yaml-5.13.8-default

# Example
#   https://books.8ops.top/attachment/argoproj/helm/argocd-configs.yaml-5.13.8
#   https://books.8ops.top/attachment/argoproj/helm/argocd-configs.yaml-5.4.2
# 

helm upgrade --install argo-cd argoproj/argo-cd \
    -n kube-server \
    -f argocd-configs.yaml-5.13.8 \
    --version 5.13.8

helm -n kube-server uninstall argo-cd

kubectl -n kube-server get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -D; echo 

```



## 二、使用

可以通过 `UI` 界面向导操作，也可以通过 `argocd` 命令操作

```bash
curl -sSL -o ~/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v2.5.2/argocd-linux-amd64
chmod +x ~/bin/argocd
```



### 2.1 多集群

```bash
# 查看 kubeconfig
kubectl config get-contexts

# 登录 argo-cd
argocd login argo-cd.8ops.top --username=admin --password=xx --grpc-web
argocd context --grpc-web

# 添加 kubernetes cluster
argocd cluster add kubeconfig-guest-name \
    --kubeconfig ~/.kube/config \
    --name argocd-cluster-name --grpc-web
    
# 非安全模式 - token认证
argocd cluster add kube-context-name --name argocd-context-name --grpc-web
argocd cluster list --grpc-web
```



> argocd添加外部kubernetes cluster步骤

```bash
# 第一步，通过ingress-nginx暴露流量
kubectl apply -f kube-apiserver-ingress.yaml

# 第二步，在kubeconfig添加context

# 第三步，登录argocd
argocd login argocd.8ops.top

# 第四步，添加cluster
argocd cluster add kube-context-name --name argocd-context-name --grpc-web
# 添加完成后会在对应的 kubernetes cluster 创建 ServiceAccount/argocd-manager
# kubectl -n kube-system get ServiceAccount/argocd-manager ClusterRole/argocd-manager-role ClusterRoleBinding/argocd-manager-role-binding

# 第五步，查看cluster
argocd cluster list --grpc-web
```



> kube-apiserver-ingress.yaml

```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    service.alpha.kubernetes.io/app-protocols: '{"https":"HTTPS"}'
    nginx.ingress.kubernetes.io/whitelist-source-range: 10.1.1.0/28
  name: kube-apiserver
  namespace: default
spec:
  ingressClassName: external
  rules:
  - host: kube-apiserver.8ops.top
    http:
      paths:
      - backend:
          service:
            name: kubernetes
            port:
              number: 443
        path: /
        pathType: Prefix
  tls:
  - hosts:
    - kube-apiserver.8ops.top
    secretName: tls-8ops.top
```



> kubeconfig

```yaml
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://kube-apiserver.8ops.top
  name: kube-external-insecure
contexts:
- context:
    cluster: kube-external-insecure
    user: kube-external-user
  name: kube-external-insecure  
current-context: kube-external-insecure 
kind: Config
preferences:
  colors: true
users:
- name: kube-external-user
  user:
    token: <data>  
```

> view

```bash
SERVER                          NAME                   VERSION STATUS     MESSAGE PROJECT
https://kube-apiserver.8ops.top kube-external-insecure 1.23    Successful
https://kubernetes.default.svc  in-cluster             1.25    Successful
```



### 2.2 accounts

Reference

- [用户管理](https://argoproj.github.io/argo-cd/operator-manual/user-management/)

- [RBAC控制](https://argoproj.github.io/argo-cd/operator-manual/rbac/)

```bash
# get account admin's pass
~ $ kubectl -n kube-server get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode

# add account jesse
~ $ kubectl -n kube-server edit cm argocd-cm
data:
  ……
  accounts.jesse: login
  accounts.jesse.enabled: "true"

# setting account jesse's pass
# --current-password is admin's pass required
~ $ argocd account update-password  --account jesse --current-password xxxx --new-password xxxx --grpc-web

kubectl -n kube-server edit cm argocd-rbac-cm
# policy
# p, user, *, *, project/*, allow   ---- p=policy，用户名，资源，动作，项目，allow或deny
# policy.default: role:readonly     ---- 默认策略
#
  policy.csv: |
    p, jesse, applications, *, */*, allow
    p, jesse, clusters, *, *, allow
    p, jesse, certificates, get, *, allow
    p, jesse, repositories, get, *, allow
    p, jesse, projects, get, *, allow
    p, jesse, accounts, get, *, allow
    p, jesse, gpgkeys, get, *, allow
    p, jesse, logs, get, *, allow
    p, jesse, exec, create, */*, allow

argocd login argo-cd.8ops.top --grpc-web
argocd account list --grpc-web


# Can I sync any app?
argocd account can-i sync applications '*'

# Can I update a project?
argocd account can-i update projects 'default'

# Can I create a cluster?
argocd account can-i create clusters '*'

Actions: [get create update delete sync override]
Resources: [clusters projects applications applicationsets repositories certificates logs exec]
```



### 2.3 存储

相关元信息存储在 kubernetes cluster's etcd 中

```bash
# 1，获取资源类型
$ kubectl api-resources | grep argo
applications      app,apps         argoproj.io/v1alpha1  true  Application
applicationsets   appset,appsets   argoproj.io/v1alpha1  true  ApplicationSet
appprojects       appproj,appprojs argoproj.io/v1alpha1  true  AppProject
argocdextensions                   argoproj.io/v1alpha1  true  ArgoCDExtension

# 2，获取资源列表
$ kubectl -n kube-server get applications
NAME             SYNC STATUS   HEALTH STATUS
helm-guestbook   Synced        Healthy

# 3，展开详情
$ kubectl -n kube-server get applications helm-guestbook -o yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  creationTimestamp: "2022-10-11T05:37:49Z"
  generation: 19734
  name: helm-guestbook
  namespace: kube-server
  resourceVersion: "18247691"
  uid: c26e8225-c6cc-4338-a494-525f572cae4a
spec:
  destination:
    namespace: kube-app
    server: https://kubernetes.default.svc
  project: argo-example-apps
  source:
    helm:
      parameters:
      - name: replicaCount
        value: "2"
    path: helm-guestbook
    repoURL: https://git.8ops.top/gce/argocd-example-apps.git
    targetRevision: HEAD
……    
```



### 2.4 综合

```bash
argocd login argo-cd.8ops.top --username=admin --password=xx --grpc-web
argocd account update-password --account jesse --current-password xx --new-password xx --grpc-web

argocd ctx list

argocd cluster list
argocd proj    list
argocd repo    list
argocd app     list

# backup
argocd cluster list -o yaml > 01-argocd-cluster-list.yaml
argocd proj    list -o yaml > 02-argocd-proj-list.yaml
argocd repo    list -o yaml > 03-argocd-repo-list.yaml
argocd app     list -o yaml > 04-argocd-app-list.yaml

kubectl run redis-client --restart='Never' \
  --image hub.8ops.top/bitnami/redis:7.0.4 \
  --namespace kube-app \
  --command -- sleep infinity
```



### 2.5 cluster

```bash
argocd cluster list
argocd cluster rm 11-dev-ofc

# cluster add
argocd cluster add 11-dev-ofc-insecure  --name=11-dev-ofc  --grpc-web
argocd cluster add 12-test-ali-insecure --name=12-test-ali --grpc-web
argocd cluster add 13-stage-sh-insecure --name=13-stage-sh --grpc-web
argocd cluster add 14-prod-sh-insecure  --name=14-prod-sh  --grpc-web
```



### 2.6 proj

```bash
argocd proj list
argocd proj delete argo-example-proj
argocd proj create argo-example-proj --description "argo example proj" 

# argocd proj add-source
argocd proj remove-source argo-example-proj  \
    https://git.8ops.top/ops/argocd-example-apps.git
argocd proj add-source argo-example-proj \
    https://git.8ops.top/ops/argocd-example-apps.git

# argocd proj add-destination argo-example-proj in-cluster kube-app --name
argocd proj remove-destination argo-example-proj \
    https://kubernetes.default.svc kube-app
argocd proj add-destination argo-example-proj \
    https://kubernetes.default.svc kube-app 
argocd proj get argo-example-proj

# argocd proj allow-cluster-resource
argocd proj allow-cluster-resource argo-example-proj '*' '*' -l allow

# argocd proj allow-namespace-resource
argocd proj allow-namespace-resource argo-example-proj '*' '*' -l allow

# ---
argocd proj create control-plane-proj --description "control plane proj" 
argocd proj add-source control-plane-proj \
    https://git.8ops.top/ops/control-plane-ops.git
argocd proj add-destination control-plane-proj \
    https://kubernetes.default.svc default 
argocd proj add-destination control-plane-proj \
    https://kubernetes.default.svc kube-server 
argocd proj add-destination control-plane-proj \
    https://kubernetes.default.svc kube-system
argocd proj add-destination control-plane-proj \
    https://kubernetes.default.svc elastic-system
argocd proj add-destination control-plane-proj \
    https://kubernetes.default.svc cert-manager
argocd proj get control-plane-proj
```



### 2.7 repo

```bash
argocd repo list
argocd repo rm https://git.8ops.top/ops/argocd-example-apps.git
argocd repo add https://git.8ops.top/ops/argocd-example-apps.git \
    --name argo-example-repo \
    --project argo-example-proj \
    --username gitlab-read \
    --password xxxx \
    --insecure-skip-server-verification
argocd repo get https://git.8ops.top/ops/argocd-example-apps.git

# ---

argocd repo add https://git.8ops.top/ops/control-plane-ops.git \
    --name control-plane-repo \
    --project control-plane-proj \
    --username gitlab-read \
    --password jesse2022 \
    --insecure-skip-server-verification    
```



### 2.8 app

```bash
argocd app list
    
# Create a directory app
argocd app delete guestbook
argocd app create guestbook \
    --repo https://git.8ops.top/ops/argocd-example-apps.git \
    --path guestbook \
    --project argo-example-proj \
    --directory-recurse \
    --dest-namespace kube-app \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm 

# Create a Helm app
argocd app delete helm-guestbook
argocd app create helm-guestbook \
    --repo https://git.8ops.top/ops/argocd-example-apps.git \
    --path helm-guestbook \
    --dest-namespace kube-app \
    --project argo-example-proj \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm 

argocd app set helm-guestbook --values values-production.yaml

# Create a Helm app from a Helm repo
argocd app delete helm-repo-redis
argocd app create helm-repo-redis \
    --repo https://charts.bitnami.com/bitnami \
    --helm-chart redis \
    --revision 17.3.14 \
    --dest-namespace kube-app \
    --dest-server https://kubernetes.default.svc \
    --label author=jesse \
    --label tier=helm \
    --helm-set global.imageRegistry=hub.8ops.top \
    --helm-set image.tag=7.0.5 \
    --helm-set architecture=standalone \
    --helm-set auth.password=jesse \
    --helm-set master.persistence.enabled=false \
    --helm-set metrics.enabled=true \
    --helm-set metrics.image.tag=1.37.0 

argocd app set helm-repo-redis --helm-set master.count=1
argocd app set helm-repo-redis --helm-set replica.persistence.enabled=false

# # Create a Helm app from a Helm repo
# argocd app delete helm-repo-redis-cluster
# argocd app create helm-repo-redis-cluster \
#     --repo https://charts.bitnami.com/bitnami \
#     --helm-chart redis-cluster \
#     --revision 7.5.0 \
#     --dest-namespace kube-app \
#     --dest-server https://kubernetes.default.svc \
#     --label author=jesse \
#     --label tier=helm 
#     --values-literal-file cluster-values.yaml
# 
# # TODO persistence 未成功移除
# argocd app set helm-repo-redis-cluster --helm-set persistence.enabled=false 
# argocd app set helm-repo-redis-cluster --helm-set redis.useAOFPersistence=false 
```



### 2.9 app Helm Template

Create a Helm app from a Helm Templates

> sentinel

```bash
helm search repo redis

helm pull bitnami/redis --version 17.3.14 -d /tmp
tar xf /tmp/redis-17.3.14.tgz -C .
mv redis helm-repo-redis-sentinel-tpl

vim helm-repo-redis-sentinel-tpl/values.yaml

helm install --generate-name --dry-run --debug \
  helm-repo-redis-sentinel-tpl \
  -f helm-repo-redis-sentinel-tpl/values.yaml

helm -n kube-app uninstall helm-repo-redis-sentinel-tpl-standalone
helm -n kube-app upgrade --install helm-repo-redis-sentinel-tpl-standalone \
    helm-repo-redis-sentinel-tpl \
    -f helm-repo-redis-sentinel-tpl/sentinel-standalone-values.yaml

helm -n kube-app uninstall helm-repo-redis-sentinel-tpl-replication
helm -n kube-app upgrade --install helm-repo-redis-sentinel-tpl-replication \
    helm-repo-redis-sentinel-tpl \
    -f helm-repo-redis-sentinel-tpl/sentinel-replication-values.yaml

kubectl -n kube-app exec -it redis-client bash
redis-cli -h helm-repo-redis-sentinel-tpl-standalone-headless -a jesse
config get maxmemory

redis-cli -h helm-repo-redis-sentinel-tpl-replication-headless -a jesse info replication
redis-cli -h helm-repo-redis-sentinel-tpl-replication -a jesse info replication
redis-cli -h helm-repo-redis-sentinel-tpl-replication-node-0.helm-repo-redis-sentinel-tpl-replication-headless.kube-app.svc.cluster.local -a jesse info replication

argocd app delete helm-repo-redis-sentinel-tpl-standalone
argocd app create helm-repo-redis-sentinel-tpl-standalone \
    --repo https://git.8ops.top/ops/argocd-example-apps.git \
    --path helm-repo-redis-sentinel-tpl \
    --project argo-example-proj \
    --dest-namespace kube-app \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values standalone-values.yaml

argocd app delete helm-repo-redis-sentinel-tpl-replication
argocd app create helm-repo-redis-sentinel-tpl-replication \
    --repo https://git.8ops.top/ops/argocd-example-apps.git \
    --path helm-repo-redis-sentinel-tpl \
    --project argo-example-proj \
    --dest-namespace kube-app \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values replication-values.yaml
```

> cluster

```bash
helm pull bitnami/redis-cluster --version 8.3.1 -d /tmp
tar xf /tmp/redis-cluster-8.3.1.tgz -C .
mv redis-cluster helm-repo-redis-cluster-tpl

vim helm-repo-redis-cluster-tpl/values.yaml

helm install --generate-name --dry-run --debug \
  helm-repo-redis-cluster-tpl \
  -f helm-repo-redis-cluster-tpl/values.yaml
  
helm -n kube-app uninstall helm-repo-redis-cluster-tpl
helm -n kube-app upgrade --install helm-repo-redis-cluster-tpl \
    helm-repo-redis-cluster-tpl \
    -f helm-repo-redis-cluster-tpl/cluster-values.yaml

kubectl -n kube-app rollout restart sts helm-repo-redis-cluster-tpl
kubectl -n kube-app exec -it redis-client bash
redis-cli -h helm-repo-redis-cluster-tpl-headless -a jesse -c
config get maxmemory

argocd app delete helm-repo-redis-cluster-tpl
argocd app create helm-repo-redis-cluster-tpl \
    --repo https://git.8ops.top/ops/argocd-example-apps.git \
    --path helm-repo-redis-cluster-tpl \
    --project argo-example-proj \
    --dest-namespace kube-app \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values cluster-values.yaml
```



### 2.10 app Helm Dependency

Create a Helm app from a Helm Dependency

> sentinel

```bash
mkdir -p helm-repo-redis-sentinel-dep
cd helm-repo-redis-sentinel-dep

# - name: redis 必须是 bitnami 里面存在的 Charts
cat <<EOF | tee Chart.yaml
apiVersion: v2
name: bitnami-redis
version: "17.3.14"
dependencies:
- name: redis
  version: "17.3.14"
  repository: "https://charts.bitnami.com/bitnami"
EOF

vim sentinel-values.yaml

helm dep build --skip-refresh
helm dep list

helm install --generate-name --dry-run --debug \
  helm-repo-redis-sentinel-dep \
  -f helm-repo-redis-sentinel-dep/standalone-values.yaml
  
helm install --generate-name --dry-run --debug \
  helm-repo-redis-sentinel-dep \
  -f helm-repo-redis-sentinel-dep/replication-values.yaml

argocd app delete helm-repo-redis-sentinel-dep-standalone
argocd app create helm-repo-redis-sentinel-dep-standalone \
    --repo https://git.8ops.top/ops/argocd-example-apps.git \
    --path helm-repo-redis-sentinel-dep \
    --project argo-example-proj \
    --dest-namespace kube-app \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --release-name helm-repo-redis-sentinel-dep-standalone \
    --values standalone-values.yaml
    
argocd app delete helm-repo-redis-sentinel-dep-replication
argocd app create helm-repo-redis-sentinel-dep-replication \
    --repo https://git.8ops.top/ops/argocd-example-apps.git \
    --path helm-repo-redis-sentinel-dep \
    --project argo-example-proj \
    --dest-namespace kube-app \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --release-name helm-repo-redis-sentinel-dep-replication \
    --values replication-values.yaml
```

> cluster

```bash
mkdir -p helm-repo-redis-cluster-dep
cd helm-repo-redis-cluster-dep

# - name: redis-cluster 必须是 bitnami 里面存在的 Charts
cat <<EOF | tee Chart.yaml
apiVersion: v2
name: bitnami-redis
version: "8.3.1"
dependencies:
- name: redis-cluster
  version: "8.3.1"
  repository: "https://charts.bitnami.com/bitnami"
EOF

vim cluster-values.yaml

helm dep build --skip-refresh
helm dep list

helm install --generate-name --dry-run --debug \
  helm-repo-redis-cluster-dep \
  -f helm-repo-redis-cluster-dep/cluster-values.yaml

argocd app delete helm-repo-redis-cluster-dep
argocd app create helm-repo-redis-cluster-dep \
    --repo https://git.8ops.top/ops/argocd-example-apps.git \
    --path helm-repo-redis-cluster-dep \
    --project argo-example-proj \
    --dest-namespace kube-app \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values cluster-values.yaml

# #经验证是非必须的
#    --release-name helm-repo-redis-cluster-dep \ 
# argocd app delete argo-cd --cascade=false
```



## 三、ArgoCD 场景

尝试自举 argocd 

```bash
helm repo add argoproj https://argoproj.github.io/argo-helm
helm repo update argoproj
helm search repo argo-cd
helm pull argoproj/argo-cd --version 5.13.8 -d /tmp
tar xf /tmp/argo-cd-5.13.8.tgz -C .

cd argo-cd
vim values-ops.yaml

argocd app create argo-cd \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path devops/argo-cd \
    --project control-plane-proj \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml

# 貌似不允许这样
# argocd app delete argo-cd
```

### 3.1 calico

```bash
helm repo add projectcalico https://projectcalico.docs.tigera.io/charts
helm repo update
helm search repo tigera-operator
helm pull projectcalico/tigera-operator --version v3.24.1 -d /tmp
tar xf /tmp/tigera-operator-v3.24.1.tgz -C .

cd tigera-operator
vim values-ops.yaml

argocd proj allow-cluster-resource control-plane-proj * * 
argocd proj allow-namespace-resource control-plane-proj * * 
argocd proj add-destination control-plane-proj \
    https://kubernetes.default.svc kube-system
argocd proj add-destination control-plane-proj \
    https://kubernetes.default.svc kube-server
argocd proj add-destination control-plane-proj \
    https://kubernetes.default.svc default
argocd proj get control-plane-proj

argocd app create calico \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path tigera-operator \
    --project control-plane-proj \
    --dest-namespace kube-system \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml \
    --helm-skip-crds

# 由于此前使用Helm安装过calico
```



### 3.2 metallb

```bash
helm repo add metallb https://metallb.github.io/metallb
helm repo update metallb
helm search repo metallb
helm pull metallb/metallb --version 0.13.7 -d /tmp
tar xf /tmp/metallb-0.13.7.tgz -C .

cd metallb
vim values-ops.yaml

argocd app create metallb \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path metallb \
    --project control-plane-proj \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml \
    --helm-skip-crds

# 【不建议这样】
# argocd app delete metallb
# 其中资源 bgppeers.metallb.io + addresspools.metallb.io 会一直报 OutOfSync

argocd app create metallb-extention \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path metallb/extention \
    --project control-plane-proj \
    --directory-recurse \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --label author=jesse \
    --label tier=helm 
argocd app set metallb-extention --sync-policy automated
```



### 3.3 ingress-nginx

[Reference](05-helm.md#ingress-nginx)

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
helm search repo ingress-nginx
helm pull ingress-nginx/ingress-nginx --version 4.4.0 -d /tmp
tar xf /tmp/ingress-nginx-4.4.0.tgz -C .

cd ingress-nginx
vim values-ops.yaml

argocd app create ingress-nginx \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path ingress-nginx \
    --project control-plane-proj \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml
```



### 3.4 dashboard

[Reference](05-helm.md#dashboard)

```bash
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update kubernetes-dashboard
helm search repo kubernetes-dashboard
helm pull kubernetes-dashboard/kubernetes-dashboard --version 6.0.0 -d /tmp
tar xf /tmp/kubernetes-dashboard-6.0.0.tgz -C .

cd kubernetes-dashboard
vim values-ops.yaml

argocd app create kubernetes-dashboard \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path kubernetes-dashboard \
    --project control-plane-proj \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml
```



### 3.5 toolkit

```bash
# echoserver
argocd app create toolkit \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path toolkit \
    --project control-plane-proj \
    --directory-recurse \
    --dest-namespace default \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm 
```



### 3.6 mysql

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update bitnami
helm search repo mysql
helm pull bitnami/mysql --version 9.4.5 -d /tmp
tar xf /tmp/mysql-9.4.5.tgz -C .

cd mysql
vim values-standalone.yaml

argocd app create mysql-extention \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path mysql/extention \
    --project control-plane-proj \
    --directory-recurse \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm     
    
argocd app create mysql-standalone \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path mysql \
    --project control-plane-proj \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-standalone.yaml

```



### 3.7 minio

```bash
helm repo add minio https://charts.min.io/
helm repo update minio
helm search repo minio
helm pull minio/minio --version 5.0.4 -d /tmp
tar xf /tmp/minio-5.0.4.tgz -C .

cd minio
vim values-ops.yaml

argocd app create minio-extention \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path minio/extention \
    --project control-plane-proj \
    --directory-recurse \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm     
    
argocd app create minio \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path minio \
    --project control-plane-proj \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml

helm upgrade --install minio minio/minio \
    -f minio.yaml-5.0.4 \
    --namespace=kube-server \
    --create-namespace \
    --version 5.0.4   
```



### 3.8 nfs-provider

[Reference](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)

[sample](52-nfs-provider.md)

```bash
helm repo add nfs-provider https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
helm repo update nfs-provider
helm search repo nfs
helm pull nfs-provider/nfs-subdir-external-provisioner --version 4.0.17 -d /tmp
tar xf /tmp/nfs-subdir-external-provisioner-4.0.17.tgz -C .

cd nfs-subdir-external-provisioner
vim values-ops.yaml

# 需要在节点上支持 mount.nfs，否则 Pod 会报错误
# Warning  FailedMount  3m51s (x650 over 21h)  kubelet  MountVolume.SetUp failed for volume "nfs-subdir-external-provisioner-root" : mount failed: exit status 32
apt install nfs-common

argocd app create nfs-subdir-external-provisioner \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path nfs-subdir-external-provisioner \
    --project control-plane-proj \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml

# extention
argocd app create nfs-extention \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path nfs-subdir-external-provisioner/extention \
    --project control-plane-proj \
    --directory-recurse \
    --dest-namespace default \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm 
```



### 3.9 cert

[Reference](05-helm.md#cert-manager)

#### 3.9.1 cert-manager

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack
helm search repo cert-manager
helm pull jetstack/cert-manager --version v1.11.0 -d /tmp
tar xf /tmp/cert-manager-v1.11.0.tgz -C .

cd cert-manager
vim values-ops.yaml

argocd app create cert-manager \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path cert-manager \
    --project control-plane-proj \
    --dest-namespace cert-manager \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml

```

#### 3.9.2 imroc

webhook-dnspod

```bash
helm repo add imroc https://charts.imroc.cc
helm repo update imroc
helm search repo cert-manager-webhook-dnspod
helm pull imroc/cert-manager-webhook-dnspod --version 1.2.0 -d /tmp
tar xf /tmp/cert-manager-webhook-dnspod-1.2.0.tgz -C .

cd cert-manager-webhook-dnspod
vim values-ops.yaml

argocd app create cert-manager-webhook-dnspod \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path cert-manager-webhook-dnspod \
    --project control-plane-proj \
    --dest-namespace cert-manager \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml
```

#### 3.9.3 extension

cluster-issuer + certificate

```bash
argocd app create cert-manager-extention \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path cert-manager/extention \
    --project control-plane-proj \
    --directory-recurse \
    --dest-namespace cert-manager \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm 

```





### 3.10 prometheus

[Reference](20-prometheus.md#prometheus)

#### 3.10.1 prometheus

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
helm search repo prometheus
helm pull prometheus-community/prometheus --version 15.8.5 -d /tmp
tar xf /tmp/prometheus-15.8.5.tgz -C .

cd prometheus
vim values-server.yaml
vim values-alertmanager.yaml
vim values-extra.yaml

argocd app create prometheus \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path prometheus \
    --project control-plane-proj \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-server.yaml \
    --values values-alertmanager.yaml \
    --values values-extra.yaml

```

#### 3.10.2 extention

```bash
argocd app create prometheus-extention \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path prometheus/extention \
    --project control-plane-proj \
    --directory-recurse \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=directory 
```



#### 3.10.3 blackbox

```bash
helm search repo prometheus-blackbox-exporter
helm pull prometheus-community/prometheus-blackbox-exporter --version 7.0.0 -d /tmp
tar xf /tmp/prometheus-blackbox-exporter-7.0.0.tgz -C .

cd prometheus-blackbox-exporter
vim values-ops.yaml

argocd app create prometheus-blackbox-exporter \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path prometheus-blackbox-exporter \
    --project control-plane-proj \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml
```

#### 3.10.4 grafana

[mysql](#mysql)

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update grafana
helm search repo grafana
helm pull grafana/grafana --version 6.38.1 -d /tmp
tar xf /tmp/grafana-6.38.1.tgz -C .

cd grafana
vim values-ops.yaml

argocd app create grafana \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path grafana \
    --project control-plane-proj \
    --dest-namespace kube-server \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml
```



### 3.11 elastic

[Reference](05-helm.md#elastic)

#### 3.11.1 elastic

```bash
helm repo add elastic https://helm.elastic.co
helm repo update elastic
helm search repo elastic
helm pull elastic/elasticsearch --version 7.17.3 -d /tmp
tar xf /tmp/elasticsearch-7.17.3.tgz -C .

cd elasticsearch
vim values-master.yaml
vim values-data.yaml
vim values-client.yaml

argocd proj add-destination control-plane-proj \
    https://kubernetes.default.svc elastic-system

argocd app create elastic-extention \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path elasticsearch/extention \
    --project control-plane-proj \
    --directory-recurse \
    --dest-namespace elastic-system \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm        

argocd app create elastic-master \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path elasticsearch \
    --project control-plane-proj \
    --dest-namespace elastic-system \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-master.yaml
    
argocd app create elastic-data \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path elasticsearch \
    --project control-plane-proj \
    --dest-namespace elastic-system \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-data.yaml
    
argocd app create elastic-client \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path elasticsearch \
    --project control-plane-proj \
    --dest-namespace elastic-system \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-client.yaml
 
```

#### 3.11.2 kibana

```bash
helm search repo kibana
helm pull elastic/kibana --version 7.17.3 -d /tmp
tar xf /tmp/kibana-7.17.3.tgz -C .

cd kibana
vim values-ops.yaml

argocd app create kibana \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path kibana \
    --project control-plane-proj \
    --dest-namespace elastic-system \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml
```



#### 3.11.3 kafka

```bash
helm repo update bitnami
helm search repo kafka
helm pull bitnami/kafka --version 19.0.1 -d /tmp
tar xf /tmp/kafka-19.0.1.tgz -C .

cd kafka
vim values-ops.yaml

argocd app create kafka \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path kafka \
    --project control-plane-proj \
    --dest-namespace elastic-system \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml

# kafka-ui
argocd app create kafka-extention \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path kafka/extention \
    --project control-plane-proj \
    --directory-recurse \
    --dest-namespace elastic-system \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --auto-prune \
    --label author=jesse \
    --label tier=directory \
    --label owner=ops 
```

[Reference](https://books.8ops.top/attachment/kafka/95-kafka-ui.yaml)

#### 3.11.4 logstash

```bash
helm search repo logstash
helm pull elastic/logstash --version 7.17.3 -d /tmp
tar xf /tmp/logstash-7.17.3.tgz -C .

cd kibana
vim values-ops.yaml

argocd app create logstash \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path logstash \
    --project control-plane-proj \
    --dest-namespace elastic-system \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --values values-ops.yaml
 
```

#### 3.11.5 filebeat

```bash
# demo
argocd app create logstash-extention \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path logstash/extention \
    --project control-plane-proj \
    --directory-recurse \
    --dest-namespace elastic-system \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm     
    
# daemonset
helm search repo filebeat
helm pull elastic/filebeat --version 7.17.3 -d /tmp
tar xf /tmp/filebeat-7.17.3.tgz -C .

vim values-ops.yaml

argocd app create filebeat \
    --repo https://git.8ops.top/ops/control-plane-ops.git \
    --path filebeat \
    --project infrastructure \
    --dest-namespace elastic-system \
    --dest-server https://kubernetes.default.svc \
    --revision master \
    --sync-policy automated \
    --label author=jesse \
    --label tier=helm \
    --label owner=ops \
    --values values-ops.yaml
```





## 四、常见问题



### 3.1 加入集群认证问题

1. 白名单
2. 通过 token 走 insecure
3. 通过 kubeconfig 当引用外部 ca 文件时注意引入目录



### 3.2 kubernetes cluster 多套 argocd 

```bash
# helm values
crds:
  install: false
  keep: true
```

当同一命名空间多次部署时，不管是否是同一套 argocd 会自动加载之前的配置信息。



### 3.3 界面 PARAMETERS 无法识别出 values.yaml

```bash
argocd proj add-source argo-example-proj https://git.8ops.top/gce/argocd-example-apps.git
```

