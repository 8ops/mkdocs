# Helm + MongoDB

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



## 1.2 download

```bash
# https://www.mongodb.com/try/download/community
# server
https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel70-7.0.12.tgz
https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel70-5.0.27.tgz
https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel70-4.4.29.tgz

# client
https://fastdl.mongodb.org/linux/mongodb-shell-linux-x86_64-rhel70-7.0.12.tgz
https://fastdl.mongodb.org/linux/mongodb-shell-linux-x86_64-rhel70-5.0.27.tgz
https://fastdl.mongodb.org/linux/mongodb-shell-linux-x86_64-rhel70-4.4.29.tgz

# https://www.mongodb.com/try/download/shell
https://fastdl.mongodb.org/tools/db/mongodb-database-tools-rhel70-x86_64-100.9.5.tgz

```





## 二、Docker

[all-in-one.yaml](https://github.com/mongodb/mongodb-atlas-kubernetes/blob/main/deploy/all-in-one.yaml)



```bash
cat > docker-compose.yaml <<EOF
services:

  mongo:
    image: mongo:4.4.29
    restart: always
    container_name: mongo
    network_mode: host
    ports:
      - 27017:27017
#    environment:
#      MONGO_INITDB_ROOT_USERNAME: root
#      MONGO_INITDB_ROOT_PASSWORD: example
    volumes:
      - /opt/lib/mongo/data:/data/db

  mongo-express:
    image: mongo-express:1.0.2-18
    restart: always
    container_name: mongo-express
    network_mode: host
    ports:
      - 8081:8081
    environment:
#      ME_CONFIG_MONGODB_ADMINUSERNAME: root
#      ME_CONFIG_MONGODB_ADMINPASSWORD: example
#      ME_CONFIG_MONGODB_URL: mongodb://root:example@mongo:27017/
      ME_CONFIG_MONGODB_URL: mongodb://127.0.0.1:27017/
      ME_CONFIG_BASICAUTH: false

EOF

docker compose up -d


```







## 三、常见问题

### 3.1 对指令的特别要求

[Reference](https://www.jianshu.com/p/359803fef7c7)

mongodb 5 on x86 requires a cpu with avx, check your cpu flags of the kubernetes node with `lscpu | grep avx`

[官方解释](https://www.mongodb.com/docs/manual/administration/production-notes/)



