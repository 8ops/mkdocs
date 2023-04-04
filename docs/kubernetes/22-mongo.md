# 实战 | 通过Helm搭建 MongoDB

## 一、Helm



## 1.1 Install

`fake`

```bash
helm search repo mongo
helm show values bitnami/mongodb --version 13.1.5 > mongo.yaml-13.1.5-default

# standalone
# Example
#   https://books.8ops.top/attachment/mongo/helm/mongo.yaml-13.1.5
#

helm install mongo-standalone bitnami/mongodb \
    -f mongo.yaml-13.1.5 \
    -n kube-server \
    --create-namespace \
    --version 13.1.5 --debug

helm show values bitnami/mongodb --version 11.2.0 > mongo.yaml-11.2.0-default

###
# reponse : Illegal instruction
###

# standalone
# Example
#   https://books.8ops.top/attachment/mongo/helm/mongo.yaml-11.2.0
#

helm install mongo-standalone bitnami/mongodb \
    -f mongo.yaml-11.2.0 \
    -n kube-server \
    --create-namespace \
    --version 11.2.0 --debug

```



## 二、原生

[all-in-one.yaml](https://github.com/mongodb/mongodb-atlas-kubernetes/blob/main/deploy/all-in-one.yaml)



```bash
```







## 三、常见问题

### 3.1 对指令的特别要求

[Reference](https://www.jianshu.com/p/359803fef7c7)

mongodb 5 on x86 requires a cpu with avx, check your cpu flags of the kubernetes node with `lscpu | grep avx`

[官方解释](https://www.mongodb.com/docs/manual/administration/production-notes/)
