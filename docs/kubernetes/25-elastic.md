# 实战 | 快速搭建 ELK



## 一、ECK-Operater

Elastic Cloud on Kubernetes

基于kubernetes部署

[Reference](https://www.elastic.co/cn/downloads/elastic-cloud-kubernetes)

```bash
# https://download.elastic.co/downloads/eck/1.2.1/all-in-one.yaml
# https://download.elastic.co/downloads/eck/2.4.0/crds.yaml
# https://download.elastic.co/downloads/eck/2.4.0/operator.yaml
```

[参考](http://icyfenix.cn/appendix/operation-env-setup/elk-setup.html)



> 演示3节点的集群

```bash
# version: 7.17.3

# Example
#   https://books.8ops.top/attachment/elastic/01-persistent-elastic-eck-pv.yaml
#   https://books.8ops.top/attachment/elastic/01-persistent-elastic-eck-pvc.yaml
#   https://books.8ops.top/attachment/elastic/10-eck_crds.yaml-2.4.0
#   https://books.8ops.top/attachment/elastic/10-eck_operator.yaml-2.4.0
#   https://books.8ops.top/attachment/elastic/11-eck-elastic.yaml-7.17.3
#   https://books.8ops.top/attachment/elastic/12-eck-kibana.yaml-7.17.3
#

# 1，安装 ECK 对应的 Operator 资源对象
kubectl apply -f elastic_eck_crds.yaml-2.4.0
kubectl apply -f elastic_eck_operator.yaml-2.4.0

# 2，创建磁盘挂载
kubectl apply -f 01-persistent-elastic-pv.yaml
kubectl apply -f 01-persistent-elastic-pvc.yaml

# 3，创建 elastic 节点
kubectl apply -f 10-elastic.yaml-7.17.3

kubectl port-forward service/quickstart-es-http 5601

## 获取 ES 密码
kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}' | echo

# 4，创建kibana组件
kubectl apply -f 11-kibana.yaml-7.17.3

kubectl port-forward service/quickstart-kb-http 5601

## 获取 KB 密码
kubectl get secret quickstart-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode; echo

```





## 二、OneKey

基于单机部署

- version: 7.0.1

- method:  docker-compose

```
version: '2.2'
services:
  es-node-01:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.0.1
    container_name: es-node-01
    environment:
      - node.name=es-node-01
      - discovery.seed_hosts=es-node-02
      - cluster.initial_master_nodes=es-node-01,es-node-02
      - cluster.name=es-cluster
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms4g -Xmx4g"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    ports:
      - 19200:9200
    networks:
      - esnet
  es-node-02:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.0.1
    container_name: es-node-02
    environment:
      - node.name=es-node-02
      - discovery.seed_hosts=es-node-01
      - cluster.initial_master_nodes=es-node-01,es-node-02
      - cluster.name=es-cluster
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms4g -Xmx4g"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    ports:
      - 29200:9200
    networks:
      - esnet
  es-node-03:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.0.1
    container_name: es-node-03
    environment:
      - node.name=es-node-03
      - discovery.seed_hosts=es-node-01
      - cluster.initial_master_nodes=es-node-01,es-node-02
      - cluster.name=es-cluster
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms4g -Xmx4g"
    ulimits:
      memlock:
        soft: -1
        hard: -1
    networks:
      - esnet

  es-redis:
    image: redis:5.0.5
    container_name: es-redis
    ports:
      - 16379:6379
    networks:
      - esnet

  es-logstash-01:
    image: docker.elastic.co/logstash/logstash:7.0.1
    container_name: es-logstash-01
    links:
      - es-node-01
      - es-node-02
      - es-redis
    volumes:
      - /data/elk/logstash/pipeline:/usr/share/logstash/pipeline
    networks:
      - esnet

networks:
  esnet:
```



## 三、Helm

[Reference](https://developer.aliyun.com/article/861272)

### 3.1 安全准备

ElasticSearch 7.x 版本默认安装了 X-Pack 插件，并且部分功能免费，这里我们配置安全证书文件。

> 生成证书

```bash
# 运行容器生成证书
docker run --name elastic-charts-certs \
  -i -w /app hub.8ops.top/elastic/elasticsearch:7.17.3 \
  /bin/sh -c "elasticsearch-certutil ca --out /app/elastic-stack-ca.p12 --pass '' && elasticsearch-certutil cert --name security-master --dns security-master --ca /app/elastic-stack-ca.p12 --pass '' --ca-pass '' --out /app/elastic-certificates.p12"

# 从容器中将生成的证书拷贝出来
docker cp elastic-charts-certs:/app/elastic-certificates.p12 ./ 

# 删除容器
docker rm -f elastic-charts-certs

# 将 pcks12 中的信息分离出来，写入文件
openssl pkcs12 -nodes -passin pass:'' \
  -in elastic-certificates.p12 \
  -out elastic-certificate.pem
```

> 添加证书到集群

```bash
# 添加证书
kubectl -n elastic-system create secret generic elastic-certificates \
  --from-file=lib/elastic-certificates.p12
kubectl -n elastic-system create secret generic elastic-certificate-pem \
  --from-file=lib/elastic-certificate.pem

# 设置集群用户名密码，用户名不建议修改
kubectl -n elastic-system create secret generic elastic-credentials \
  --from-literal=username=elastic --from-literal=password=ops@2022
  
kubectl -n elastic-system create secret generic kibana \
  --from-literal=encryptionkey=zGFTX0cy3ubYVmzuunACDZuRj0PALqOM
```

尝试启动xpack资料

- https://github.com/elastic/helm-charts/tree/7.17/kibana/examples/security



### 3.2 安装

#### 3.2.1 elasticsearch

```bash
helm repo add elastic https://helm.elastic.co
helm repo update elastic

helm search repo elastic
helm show values elastic/elasticsearch --version 7.17.3 > elasticsearch.yaml-7.17.3

# Example
#   https://books.8ops.top/attachment/elastic/01-persistent-elastic-cluster.yaml
#   https://books.8ops.top/attachment/elastic/helm/elastic-cluster-master.yaml-7.17.3
#   https://books.8ops.top/attachment/elastic/helm/elastic-cluster-data.yaml-7.17.3
#   https://books.8ops.top/attachment/elastic/helm/elastic-cluster-client.yaml-7.17.3
#

# master 节点
helm upgrade --install elastic-cluster-master elastic/elasticsearch \
    -f elastic-cluster-master.yaml-7.17.3 \
    -n elastic-system\
    --version 7.17.3

# data 节点
helm upgrade --install elastic-cluster-data elastic/elasticsearch \
    -f elastic-cluster-data.yaml-7.17.3 \
    -n elastic-system\
    --version 7.17.3

# client 节点
helm upgrade --install elastic-cluster-client elastic/elasticsearch \
    -f elastic-cluster-client.yaml-7.17.3 \
    -n elastic-system\
    --version 7.17.3

#### 
# 尝试禁用 xpack.security.enabled 
# 
kubectl -n elastic-system delete pvc \
    elastic-cluster-data-elastic-cluster-data-0 \
    elastic-cluster-data-elastic-cluster-data-1 \
    elastic-cluster-data-elastic-cluster-data-2 \
    elastic-cluster-master-elastic-cluster-master-0 \
    elastic-cluster-master-elastic-cluster-master-1 \
    elastic-cluster-master-elastic-cluster-master-2

```

![elastic 首页](../images/elastic/elastic.png)

![elastic _cat](../images/elastic/elastic-1.png)

![elastic 索引](../images/elastic/elastic-2.png)

#### 3.2.2 kibana

```bash
helm search repo kibana
helm show values elastic/kibana --version 7.17.3 > kibana.yaml-7.17.3

# Example
#   https://books.8ops.top/attachment/elastic/helm/kibana.yaml-7.17.3
# 

helm upgrade --install kibana elastic/kibana \
    -f kibana.yaml-7.17.3 \
    -n elastic-system \
    --version 7.17.3
```

![kibana 首页](../images/elastic/kibana.png)

![kibana discover](../images/elastic/kibana-1.png)



#### 3.2.3 kafka

[Reference](https://kafka.apache.org/)

```bash
# Example
#   https://github.com/bitnami/containers/tree/main/bitnami/kafka
#   
#   https://books.8ops.top/attachment/elastic/helm/kafka.yaml-19.0.1
#   

helm repo update bitnami
helm search repo kafka
helm show values bitnami/kafka --version 19.0.1 > kafka.yaml-19.0.1.default

helm upgrade --install kafka bitnami/kafka \
    -f kafka.yaml-19.0.1 \
    -n elastic-system \
    --version 19.0.1

#
# 若重置需要删除原数据，或者不挂载磁盘
# 否则会因为cluster_id冲突
# --------------------------------------------- #
# usage
kubectl run kafka-client --restart='Never' \
  --image hub.8ops.top/bitnami/kafka:3.3.1-debian-11-r1 \
  --namespace elastic-system --command -- sleep infinity

kubectl exec --tty -i kafka-client --namespace elastic-system -- bash

# 新版本不需要连接 ZK
## PRODUCER:
kafka-console-producer.sh \
    --broker-list kafka-0.kafka-headless.elastic-system.svc.cluster.local:9092 \
    --topic test

## CONSUMER:
kafka-console-consumer.sh \
    --bootstrap-server kafka.elastic-system.svc.cluster.local:9092 \
    --topic www-online-ui \
    --from-beginning

# 查看消费情况
kafka-consumer-groups.sh \
    --bootstrap-server kafka-headless.elastic-system.svc.cluster.local:9092 \
    --describe 
    
# 查看topic
kafka-topics.sh \
    --bootstrap-server kafka-headless.elastic-system.svc.cluster.local:9092 \
    --list

# 查看同步单个topic
kafka-topics.sh \
    --bootstrap-server kafka-headless.elastic-system.svc.cluster.local:9092 \
    --topic test --describe

# 删除topic - TODO
kafka-run-class.sh kafka.admin.TopicCommand \
    --bootstrap-server kafka-headless.elastic-system.svc.cluster.local:9092 \
    --delete --topic test 

# 修改副本数/ 存储过期时间 - TODO
kafka-topics.sh \
    --bootstrap-server kafka-headless.elastic-system.svc.cluster.local:9092 \
    --topic demo-json --partitions 6
```



![kafka](../images/elastic/kafka.png)



#### 3.2.4 logstash

```bash
# Example
#   https://books.8ops.top/attachment/elastic/helm/logstash.yaml-7.17.3
#   

helm search repo logstash
helm show values elastic/logstash --version 7.17.3 > logstash.yaml-7.17.3-default

helm upgrade --install logstash elastic/logstash \
    -f logstash.yaml-7.17.3 \
    -n elastic-system \
    --version 7.17.3

```



#### 3.2.5 filebeat

[Reference](https://www.elastic.co/guide/en/beats/filebeat/current/configuring-howto-filebeat.html)

```bash
# Example: 
#   - demo.json/demo.out --> filebeat --> elasticsearch --> kibana
#   https://books.8ops.top/attachment/elastic/50-filebeat-demo.yaml
# 
#   - demo.json/demo.out --> filebeat --> kafka --> elasticsearch --> logstash --> kibana
#   https://books.8ops.top/attachment/elastic/50-filebeat-demo-kafka.yaml
# 

# ---
helm search repo filebeat
helm show values elastic/filebeat --version 7.17.3 > filebeat.yaml-7.17.3.default

```



## 四、常用实践

### 4.1 容器环境收集日志方案

| **方案**                                                     | **优点**                                                     | **缺点**                                                   |
| ------------------------------------------------------------ | ------------------------------------------------------------ | ---------------------------------------------------------- |
| 每个app的镜像中都集成日志收集组件<br />或由app镜像直接将信息推送到采集端 | 部署方便，kubernetes的yaml文件无须特别配置，可以为每个app自定义日志收集配置 | 强耦合，不方便应用和日志收集组件升级和维护且会导致镜像过大 |
| 单独创建一个日志收集组件跟app的容器一起运行在同一个pod中     | 低耦合，扩展性强，方便维护和升级                             | 需要对kubernetes的yaml文件进行单独配置，略显繁琐           |
| 将所有的Pod的日志都挂载到宿主机上，每台主机上单独起一个日志收集Pod | 完全解耦，性能最高，管理起来最方便                           | 需要统一日志收集规则，目录和输出方式                       |

![收集区别](../images/elastic/collect.png)



### 4.2 ILM

进入kibana管理界面，进入`Management --> Dev Tools`

```bash
# 第一步，创建生命周期管理策略
PUT /_ilm/policy/clean_index_7days
{
  "policy": {
    "phases": {
      "delete": {
        "min_age": "7d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}

GET /_ilm/policy/clean_index_7days

# 第二步，创建模板
PUT /_template/demo
{
  "index_patterns": ["demo-*"],
  "order": 1,
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 1,
    "index.lifecycle.name": "clean_index_7days"
  }
}

GET /_template/demo

# 第三步，绑定索引和策略（已经产生的索引不会自动绑定）
PUT /demo-json-2023.01.01/_settings
{
    "index" : {
        "lifecycle" : {
            "name" : "clean_index_7days"
        }
    }
}

GET /demo-json-2023.01.01/_ilm/explain

# 第四步，调整检测策略
PUT /_cluster/settings
{
  "transient": {
    "indices.lifecycle.poll_interval": "10s"
  }
}

GET /_cluster/settings

```

<u>区分 HOT / WARM /DELETE 存储</u>

```bash
PUT _ilm/policy/clean_index_7days
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {}
      },
      "warm": {
        "min_age": "2d",
        "actions": {
          "allocate": {
            "number_of_replicas": 0
          }
        }
      },
      "delete": {
        "min_age": "8d",
        "actions": {
          "delete": {
            "delete_searchable_snapshot": true
          }
        }
      }
    }
  }
}
```



## 五、常见问题

### 5.1 ILM出现错误

<u>现象</u>

```bash
illegal_argument_exception: index.lifecycle.rollover_alias [demo] does not point to index [demo-2023.01.05]

illegal_argument_exception: rollover target [logs] does not point to a write index

illegal_argument_exception: setting [index.lifecycle.rollover_alias] for index [demo-2023.01.05] is empty or not defined
```

<u>原因</u>

- 启用滚动更新需要为每个索引设置别名，按天分割的索引不适合动态设置别名。

<u>解决</u>

- 先移除旧策略，再绑定新策略（直接替换不生效）。
