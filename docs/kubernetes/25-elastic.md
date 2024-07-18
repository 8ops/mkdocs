# Helm + Elastic



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



### 5.2 docker部署问题

```bash
1，挂载数据的时候出现访问受限以至于无法启动时，可将挂载数据的目录所有者和用户组改为 elastic 前提条件得先创建用户和用户组,省事一点就直接 chown -R 1000:1000 /home/elasticsearch/data
2，在运行elasticsearch时出现 max virtual memory areas vm.max_map_count [65530], 请在宿主机中执行: sudo sysctl -w vm.max_map_count=262144 或者运行sudo vi /etc/sysctl.conf在文件中追加vm.max_map_count=262144 保存后执行sudo sysctl -p
3，cluster.initial_master_nodes 为集群创建初期具有master选举权的节点。
4，discovery.seed_hosts 发送信息给具有master选举权的节点，如果当前节点具有master节点的选举权，则需要向其他同样具有master节点选举权的发送消息。如果无master 节点选举权，则须把所有具有master选举权的节点host 加入。
5，集群master节点须大于等于3个，因为如果当前主节点挂了之后es须从具有master 选举权的节点中重新选举出新的主节点，如果具有master 选举权的节点存活少于一半时，节点是无法完成选举的，所以必须有大于一半以上且具有master选举权的节点存在时es才能重新选举出新的主节点。不然节点无法工作。
6，elasticsearch.yml里的配置都可在docker-compose.yml中environment里覆盖。
```





## 六、Docker实践

### 6.1 ChatGPT

在三台 Docker 机器上搭建一个 Kafka 集群需要配置 ZooKeeper 集群和 Kafka 集群。ZooKeeper 用于管理 Kafka 集群的元数据。以下是详细步骤。

#### 6.1.1 环境准备

假设你有三台 Docker 机器，分别是 `machine1`、`machine2` 和 `machine3`，并且你已经安装了 Docker 和 Docker Compose。

1. ZooKeeper 集群配置

首先，为每台机器创建 ZooKeeper 的 Docker Compose 文件 `docker-compose-zookeeper.yml`。

machine1 (ZooKeeper1)

```yaml
version: '3'
services:
  zookeeper:
    image: zookeeper:3.7.1
    container_name: zookeeper1
    ports:
      - "2181:2181"
    environment:
      ZOO_MY_ID: 1
      ZOO_SERVERS: server.1=machine1:2888:3888;2181 server.2=machine2:2888:3888;2181 server.3=machine3:2888:3888;2181
```

machine2 (ZooKeeper2)

```yaml
version: '3'
services:
  zookeeper:
    image: zookeeper:3.7.1
    container_name: zookeeper2
    ports:
      - "2181:2181"
    environment:
      ZOO_MY_ID: 2
      ZOO_SERVERS: server.1=machine1:2888:3888;2181 server.2=machine2:2888:3888;2181 server.3=machine3:2888:3888;2181
```

machine3 (ZooKeeper3)

```yaml
version: '3'
services:
  zookeeper:
    image: zookeeper:3.7.1
    container_name: zookeeper3
    ports:
      - "2181:2181"
    environment:
      ZOO_MY_ID: 3
      ZOO_SERVERS: server.1=machine1:2888:3888;2181 server.2=machine2:2888:3888;2181 server.3=machine3:2888:3888;2181
```

启动每台机器上的 ZooKeeper 容器：

```yaml
docker-compose -f docker-compose-zookeeper.yml up -d
```

2. Kafka 集群配置

为每台机器创建 Kafka 的 Docker Compose 文件 `docker-compose-kafka.yml`。

machine1 (Kafka1)

```yaml
version: '3'
services:
  kafka:
    image: wurstmeister/kafka:latest
    container_name: kafka1
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: machine1:2181,machine2:2181,machine3:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://machine1:9092
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092
      KAFKA_LOG_DIRS: /kafka/kafka-logs
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

machine2 (Kafka2)

```yaml
version: '3'
services:
  kafka:
    image: wurstmeister/kafka:latest
    container_name: kafka2
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 2
      KAFKA_ZOOKEEPER_CONNECT: machine1:2181,machine2:2181,machine3:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://machine2:9092
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092
      KAFKA_LOG_DIRS: /kafka/kafka-logs
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

machine3 (Kafka3)

```yaml
version: '3'
services:
  kafka:
    image: wurstmeister/kafka:latest
    container_name: kafka3
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 3
      KAFKA_ZOOKEEPER_CONNECT: machine1:2181,machine2:2181,machine3:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://machine3:9092
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092
      KAFKA_LOG_DIRS: /kafka/kafka-logs
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

启动每台机器上的 Kafka 容器：

```sh
docker-compose -f docker-compose-kafka.yml up -d
```

3. 验证集群

使用 `kafka-topics.sh` 工具验证 Kafka 集群是否正常工作。

创建测试主题

在任意一台机器上运行：

```sh
docker exec -it kafka1 kafka-topics.sh --create --topic test-topic --bootstrap-server machine1:9092,machine2:9092,machine3:9092 --replication-factor 3 --partitions 1
```

查看主题列表

在任意一台机器上运行：

```sh
docker exec -it kafka1 kafka-topics.sh --list --bootstrap-server machine1:9092,machine2:9092,machine3:9092
```

总结

通过以上步骤，你已经成功在三台 Docker 机器上搭建了一个 Kafka 集群。此集群包含三台 ZooKeeper 服务器和三台 Kafka 代理，能够提供高可用性和扩展性。根据需要，你可以进一步调整和优化配置，以满足具体的生产需求。



#### 6.1.2 查看 topic & cosumer

要查看 Kafka topic 的详细信息，可以使用 Kafka 提供的命令行工具 `kafka-topics.sh` 和 `kafka-consumer-groups.sh`。这些工具可以显示 topic 的配置、分区信息、副本状态等详细信息。以下是具体的命令和步骤：

使用 `kafka-topics.sh` 查看 topic 详情

首先，确保你已经连接到 Kafka 集群，并且 Kafka bin 目录在你的环境变量中。如果没有，可以使用绝对路径访问 `kafka-topics.sh`。

查看 topic 列表

查看集群中所有的 topic：

```sh
kafka-topics.sh --list --bootstrap-server <broker_address>
```

例如：

```
sh
复制代码
kafka-topics.sh --list --bootstrap-server localhost:9092
```

查看单个 topic 的详细信息

查看某个特定 topic 的详细信息：

```sh
kafka-topics.sh --describe --topic <topic_name> --bootstrap-server <broker_address>
```

例如，查看 `test-topic` 的详细信息：

```sh
kafka-topics.sh --describe --topic test-topic --bootstrap-server localhost:9092
```

输出示例：

```plaintext
Topic: test-topic  PartitionCount: 1  ReplicationFactor: 3  Configs: segment.bytes=1073741824
  Topic: test-topic  Partition: 0  Leader: 1  Replicas: 1,2,3  Isr: 1,2,3
```

解释输出信息

- **Topic**: topic 的名称。
- **PartitionCount**: topic 的分区数。
- **ReplicationFactor**: topic 的副本因子。
- **Configs**: topic 的配置。
- **Partition**: 分区编号。
- **Leader**: 该分区的 Leader broker ID。
- **Replicas**: 该分区的副本 broker ID 列表。
- **Isr**: 同步副本（in-sync replicas）的 broker ID 列表。

使用 `kafka-consumer-groups.sh` 查看消费者组信息

除了查看 topic 的信息，你还可以查看消费者组的详细信息。

列出消费者组

列出所有消费者组：

```sh
kafka-consumer-groups.sh --list --bootstrap-server <broker_address>
```

例如：

```sh
kafka-consumer-groups.sh --list --bootstrap-server localhost:9092
```

查看消费者组详细信息

查看某个消费者组的详细信息，包括每个分区的偏移量等：

```sh
kafka-consumer-groups.sh --describe --group <group_name> --bootstrap-server <broker_address>
```

例如，查看 `test-group` 的详细信息：

```sh
kafka-consumer-groups.sh --describe --group test-group --bootstrap-server localhost:9092
```

输出示例：

```plaintext
GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG             CONSUMER-ID        HOST            CLIENT-ID
test-group      test-topic      0          5               10              5               consumer-1         /127.0.0.1      consumer-1
```

解释输出信息

- **GROUP**: 消费者组名称。
- **TOPIC**: 消费的 topic 名称。
- **PARTITION**: topic 的分区编号。
- **CURRENT-OFFSET**: 当前消费者消费到的偏移量。
- **LOG-END-OFFSET**: 分区的最新偏移量。
- **LAG**: 当前消费者的滞后量（未消费的消息数量）。
- **CONSUMER-ID**: 消费者 ID。
- **HOST**: 消费者所在的主机。
- **CLIENT-ID**: 消费者的客户端 ID。

示例

假设你的 Kafka broker 在 `localhost:9092`，并且你想查看 `my-topic` 的详细信息：

```sh
kafka-topics.sh --describe --topic my-topic --bootstrap-server localhost:9092
```

如果你有一个消费者组 `my-group`，想查看其详细信息：

```sh
kafka-consumer-groups.sh --describe --group my-group --bootstrap-server localhost:9092
```

通过这些命令，你可以全面了解 Kafka topic 和消费者组的详细信息，以便更好地管理和调试 Kafka 集群。





#### 6.1.3 变更topic partition replication



在 Kafka 中，调整 topic 的分区数和副本因子可以帮助你根据需要进行扩展和提高数据的容错性。以下是详细的步骤和命令，用于变更 Kafka topic 的分区数和副本因子。

增加分区数

注意：你只能增加分区数，不能减少。增加分区数会改变消息的分布，可能会影响消息的顺序。

使用 `kafka-topics.sh` 增加分区数

假设你要将 `my-topic` 的分区数增加到 5：

```sh
kafka-topics.sh --alter --topic my-topic --partitions 5 --bootstrap-server localhost:9092
```

调整副本因子

调整副本因子稍微复杂一些，因为你需要手动指定分区的副本分布。你可以使用 `kafka-reassign-partitions.sh` 工具来完成此任务。

1. 生成分区重新分配计划

创建一个文件 `increase-replication-factor.json`，其中包含新的分区分配计划。假设你有一个 3 节点的 Kafka 集群（broker1、broker2、broker3），并且你想将 `my-topic` 的副本因子从 1 增加到 3。

首先，生成当前分区分配计划：

```sh
kafka-reassign-partitions.sh --zookeeper localhost:2181 --topics-to-move-json-file topics-to-move.json --broker-list "1,2,3" --generate
```

`topics-to-move.json` 内容示例：

```json
{
  "version":1,
  "topics":[
    {
      "topic":"my-topic"
    }
  ]
}
```

这将生成一个 JSON 输出文件，包含当前和建议的分区分配计划。

2. 修改分区重新分配计划

根据生成的建议，编辑 `increase-replication-factor.json` 文件，使其符合你的需求。假设生成的文件如下所示：

```json
{
  "version": 1,
  "partitions": [
    {
      "topic": "my-topic",
      "partition": 0,
      "replicas": [1, 2, 3]
    },
    {
      "topic": "my-topic",
      "partition": 1,
      "replicas": [2, 3, 1]
    },
    {
      "topic": "my-topic",
      "partition": 2,
      "replicas": [3, 1, 2]
    }
  ]
}
```

确保每个分区的 `replicas` 列表中包含新的副本分布。

3. 执行分区重新分配计划

使用 `kafka-reassign-partitions.sh` 工具执行新的分区分配计划：

```sh
kafka-reassign-partitions.sh --zookeeper localhost:2181 --reassignment-json-file increase-replication-factor.json --execute
```

4. 验证分区重新分配状态

你可以验证重新分配过程是否完成：

```sh
kafka-reassign-partitions.sh --zookeeper localhost:2181 --reassignment-json-file increase-replication-factor.json --verify
```

示例完整流程

1. **生成分区重新分配计划**

   生成 `topics-to-move.json`：

   ```json
   {
     "version":1,
     "topics":[
       {
         "topic":"my-topic"
       }
     ]
   }
   ```

   生成当前分区分配计划：

   ```sh
   kafka-reassign-partitions.sh --zookeeper localhost:2181 --topics-to-move-json-file topics-to-move.json --broker-list "1,2,3" --generate
   ```

   这将输出建议的分配计划。将其复制到 `increase-replication-factor.json`。

2. **修改分区重新分配计划**

   编辑 `increase-replication-factor.json` 使其符合你的需求：

   ```json
   {
     "version": 1,
     "partitions": [
       {
         "topic": "my-topic",
         "partition": 0,
         "replicas": [1, 2, 3]
       },
       {
         "topic": "my-topic",
         "partition": 1,
         "replicas": [2, 3, 1]
       },
       {
         "topic": "my-topic",
         "partition": 2,
         "replicas": [3, 1, 2]
       }
     ]
   }
   ```

3. **执行分区重新分配计划**

   ```sh
   kafka-reassign-partitions.sh --zookeeper localhost:2181 --reassignment-json-file increase-replication-factor.json --execute
   ```

4. **验证分区重新分配状态**

   ```sh
   kafka-reassign-partitions.sh --zookeeper localhost:2181 --reassignment-json-file increase-replication-factor.json --verify
   ```

通过这些步骤，你可以成功调整 Kafka topic 的分区数和副本因子。注意，在生产环境中进行这些操作前，务必做好备份和测试。

#### 6.1.4 删除topic

```sh
kafka-topics.sh --delete --topic <topic_name> --bootstrap-server <broker_address>
```



### 6.2 实践



#### 6.2.1 环境准备

```bash
# ELK-DOCKER-01    10.131.1.237
# ELK-DOCKER-02    10.131.1.224
# ELK-DOCKER-03    10.131.1.209
# 
# ELK-DOCKER-04    10.131.1.227

mkdir -p /data1/lib/docker
ln -s /data1/lib/docker /var/lib/docker

systemctl enable docker
systemctl is-enabled docker
systemctl start docker
systemctl status docker

cat > /etc/docker/daemon.json <<EOF
{
  "insecure-registries": [
    "hub.8ops.top"
  ]
}
EOF

docker pull hub.8ops.top/middleware/zookeeper:3.9.2
docker pull hub.8ops.top/bitnami/kafka:3.6.2
```



#### 6.2.2 安装kafka

[Reference](https://hub.docker.com/r/bitnami/kafka)

```bash
cat > docker-compose.yaml <<EOF
services:
  zookeeper:
    image: 'hub.8ops.top/middleware/zookeeper:3.9.2'
    restart: always
    container_name: zookeeper
    network_mode: host
    ports:
      - 2181:2181
      - 2888:2888
      - 3888:3888
    environment:
      ZOO_MY_ID: 1
      ZOO_SERVERS: server.1=10.131.1.237:2888:3888;2181 server.2=10.131.1.224:2888:3888;2181 server.3=10.131.1.209:2888:3888;2181

  kafka:
    image: 'hub.8ops.top/bitnami/kafka:3.6.2'
    restart: always
    container_name: kafka
    network_mode: host
    ports:
      - 9092:9092
    environment:
      - KAFKA_CFG_ZOOKEEPER_CONNECT=10.131.1.237:2181,10.131.1.224:2181,10.131.1.209:2181
      - ALLOW_PLAINTEXT_LISTENER=yes
      - KAFKA_BROKER_ID=1
      - KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://10.131.1.237:9092
      - KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092
      - KAFKA_CFG_NUM_PARTITIONS=3
      - KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR=2
      - KAFKA_LOG_DIRS=/kafka/kafka-logs
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    depends_on:
      - zookeeper

EOF

docker compose down

docker compose up -d

```



#### 6.2.3 测试kafka

> 功能测试

```bash
# detect zookeeper
docker logs zookeeper
docker exec -it zookeeper bin/zkServer.sh status

# detect kafka topic
docker logs kafka

# producter & consumer
# /opt/bitnami/kafka/bin/kafka-topics.sh
export BOOTSTRAP_SERVER=10.131.1.237:9092,10.131.1.224:9092,10.131.1.209:9092 

docker exec -it kafka-client kafka-topics.sh --list --bootstrap-server ${BOOTSTRAP_SERVER}

docker exec -it kafka-client kafka-topics.sh --create --topic test-topic --bootstrap-server ${BOOTSTRAP_SERVER} --replication-factor 2 --partitions 2

docker exec -it kafka-client kafka-topics.sh --describe --topic test-topic --bootstrap-server ${BOOTSTRAP_SERVER}

docker exec -it kafka-client kafka-topics.sh --alter --topic test-topic --partitions 3 --bootstrap-server ${BOOTSTRAP_SERVER}

docker exec -it kafka-client kafka-topics.sh --create --topic test-topic-02 --bootstrap-server ${BOOTSTRAP_SERVER} --replication-factor 1 --partitions 1

docker exec -it kafka-client kafka-topics.sh --delete --topic test-topic-02 --bootstrap-server ${BOOTSTRAP_SERVER}

# detect kafka consumer
docker exec -it kafka-client kafka-consumer-groups.sh --list --bootstrap-server ${BOOTSTRAP_SERVER}

docker exec -it kafka-client kafka-consumer-groups.sh --describe --all-groups --bootstrap-server ${BOOTSTRAP_SERVER}
```

> 性能测试

```bash
# producer
docker exec -it kafka-client kafka-producer-perf-test.sh \
    --topic test-topic \
    --num-records 10000000 \
    --record-size 100 \
    --throughput 1000000 \
    --producer-props \
    acks=1 \
    bootstrap.servers=${BOOTSTRAP_SERVER}

10000000 records sent, 269578.110257 records/sec (25.71 MB/sec), 2.11 ms avg latency, 378.00 ms max latency, 1 ms 50th, 2 ms 95th, 30 ms 99th, 116 ms 99.9th.

# consumer
docker exec -it kafka-client kafka-consumer-perf-test.sh \
    --bootstrap-server ${BOOTSTRAP_SERVER}  \
    --topic test-topic \
    --fetch-size 1048576 \
    --messages 10000000 \
    --consumer.config /opt/bitnami/kafka/config/consumer.properties

start.time, end.time, data.consumed.in.MB, MB.sec, data.consumed.in.nMsg, nMsg.sec, rebalance.time.ms, fetch.time.ms, fetch.MB.sec, fetch.nMsg.sec
2024-06-27 09:44:58:834, 2024-06-27 09:45:07:905, 953.6911, 105.1363, 10000176, 1102433.6898, 3411, 5660, 168.4967, 1766815.5477
```



#### 6.2.4 安装elastic

[Reference](https://hub.docker.com/_/elasticsearch)

```bash
# sysctl
cat >> /etc/sysctl.d/99-sysctl.conf <<EOF
vm.max_map_count = 262144
fs.file-max = 655360
EOF

sysctl -p
sysctl vm.max_map_count fs.file-max

mkdir -p /data1/lib/elastic
chown 1000 /data1/lib/elastic

export SEED_HOSTS=10.131.1.237:9300,10.131.1.224:9300,10.131.1.209:9300
export MASTER_NODES=10.131.1.237,10.131.1.224,10.131.1.209

# master/client - 机器复用
cat >> docker-compose.yaml <<EOF

  elasticsearch:
    image: hub.8ops.top/elastic/elasticsearch:7.17.22
    restart: always
    container_name: es-master
    network_mode: host
    environment:
      - node.name=es-master-01
      - node.roles=master,ingest
      - cluster.name=es-docker-cluster
      - discovery.seed_hosts=${SEED_HOSTS}
      - cluster.initial_master_nodes=${MASTER_NODES}
      - bootstrap.memory_lock=true
      - xpack.security.enabled=false
      - xpack.security.http.ssl.enabled=false
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
      - network.host=0.0.0.0
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 655360
        hard: 655360
    volumes:
      - /data1/lib/elastic:/usr/share/elasticsearch/data
    ports:
      - 9200:9200
      - 9300:9300

EOF

docker compose up -d

# data
cat > docker-compose.yaml <<EOF
services:
  elasticsearch:
    image: hub.8ops.top/elastic/elasticsearch:7.17.22
    restart: always
    container_name: es-data
    network_mode: host
    environment:
      - node.name=es-data-01
      - node.roles=data
      - cluster.name=es-docker-cluster
      - discovery.seed_hosts=${SEED_HOSTS}
      - cluster.initial_master_nodes=${MASTER_NODES}
      - bootstrap.memory_lock=true
      - xpack.security.enabled=false
      - xpack.security.http.ssl.enabled=false
      - "ES_JAVA_OPTS=-Xms32g -Xmx32g"
      - network.host=0.0.0.0
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 655360
        hard: 655360
    volumes:
      - /data1/lib/elastic:/usr/share/elasticsearch/data
    ports:
      - 9200:9200
      - 9300:9300

EOF

docker compose up -d

#      # 两种角色方式都可以
#      - node.roles=master,ingest,data,ml
#      
#      OR
#
#      - node.master=false
#      - node.data=true
#      - node.ingest=false
#      - node.ml=false
```





#### 6.2.5 测试elastic

```bash
docker logs -f es-docker-cluster-data

pip install esrally

export ELASTIC_SERVER=10.131.1.237:9200,10.131.1.224:9200,10.131.1.209:9200

# list tracks
esrally list tracks

esrally race --track=geonames --target-hosts=${ELASTIC_SERVER} --pipeline=benchmark-only --client-options="use_ssl:false" --on-error=abort --test-mode

esrally race --track=geonames --target-hosts=${ELASTIC_SERVER} --pipeline=benchmark-only --client-options="timeout:60"

esrally race --track=geonames --target-hosts=${ELASTIC_SERVER} --pipeline=benchmark-only --report-file=report.md --report-format=markdown --quiet

# challenge
esrally race --distribution-version=7.17.22 --track=geonames --target-hosts=${ELASTIC_SERVER} --challenge=append-no-conflicts

esrally race --track=geonames --target-hosts=${BOOTSTRAP_SERVER} --pipeline=benchmark-only

esrally race --track=geonames --kill-running-processes

# Deprecated
docker run --name esrally --rm -it -e ENDPOINT="${ELASTIC_SERVER}" hub.8ops.top/elastic/esrally:053

```





#### 6.2.6 辅助工具

```bash
# kafka_manager、kibana、elastic ui
cat > docker-compose.yaml <<EOF
services:
  kafka-client:
    image: 'hub.8ops.top/bitnami/kafka:3.6.2'
    container_name: kafka-client
    network_mode: host
    command: ["sleep","infinity"]
    
  kafka-manager:
    image: hub.8ops.top/middleware/kafka-manager:3.0.0.5
    container_name: kafka-manager
    network_mode: host
    ports:
      - "9000:9000"
    environment:
      ZK_HOSTS: "10.131.1.237:2181,10.131.1.224:2181,10.131.1.209:2181"
      KAFKA_BROKERS: "10.131.1.237:9092,10.131.1.224:9092,10.131.1.209:9092"
      APPLICATION_SECRET: "random-secret"
      KAFKA_MANAGER_AUTH_ENABLED: "true"
      KAFKA_MANAGER_USERNAME: jesse
      KAFKA_MANAGER_PASSWORD: xqp4AtsTEBjj4rKJvhyY5XBN340

  kibana:
    image: hub.8ops.top/elastic/kibana:7.17.22
    container_name: kibana
    network_mode: host
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=["http://10.131.1.237:9200","http://10.131.1.224:9200","http://10.131.1.209:9200"]

EOF

docker compose up -d

```



#### 6.2.7 优化配置

```bash
# kafka

# vector

# elasticsearch
# 1，索引自动分片
# 2，ILM


```



