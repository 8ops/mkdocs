# elastic

[API](https://www.elastic.co/guide/en/elasticsearch/reference/current/rest-apis.html)

## 一、基本操作



```bash
/_cat/allocation
/_cat/shards
/_cat/shards/{index}
/_cat/master
/_cat/nodes
/_cat/tasks
/_cat/indices
/_cat/indices/{index}
/_cat/segments
/_cat/segments/{index}
/_cat/count
/_cat/count/{index}
/_cat/recovery
/_cat/recovery/{index}
/_cat/health
/_cat/pending_tasks
/_cat/aliases
/_cat/aliases/{alias}
/_cat/thread_pool
/_cat/thread_pool/{thread_pools}
/_cat/plugins
/_cat/fielddata
/_cat/fielddata/{fields}
/_cat/nodeattrs
/_cat/repositories
/_cat/snapshots/{repository}
/_cat/templates
```



## 二、常用优化



### 2.1 操作系统

> /etc/security/limits.d/elastic.conf

```bash
elastic soft memlock unlimited
elastic hard memlock unlimited
elastic soft nofile 655350
elastic hard nofile 655350
elastic soft nproc  655350
elastic hard nproc  655350
```

> /etc/sysctl.d/elastic.conf

```bash
vm.max_map_count = 262144

# sysctl -p
```



### 2.2 集群配置

**通过 kibana's Dev Tools** 

#### 2.2.1 ILM

[Reference](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/index-lifecycle-management.html)

[一次使用](../kubernetes/25-elastic.md#42-ilm)



#### 2.2.2  rebalance

> 禁用调度

用于添加节点后不让主动调度 rebalance。

默认情况下当 elastic cluster 有新节点加入的时候，节点上的 shards 会自动均衡存储在所有可用的节点，故新节点加入时会产生大量的 replica 动作，节点负载变高，IO 消耗变高。

可选配置值：none | true

```bash
GET /_cluster/settings

PUT /_cluster/settings
{
  "transient" : {
    "cluster" : {
      "routing" : {
        "rebalance" : {
          "enable" : "none"
        }
      }
    }
  }
}
```



> 主动调度

```bash
POST /_cluster/reroute
{
  "commands": [
    {
      "move": {
        "index": "demo-json-2023.02.10",
        "shard": 1,
        "from_node": "elastic-cluster-data-2",
        "to_node": "elastic-cluster-data-1"
      }
    }
  ]
}
```



#### 2.2.3 mapping 

[Reference](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/dynamic-templates.html)



### 2.3 beats配置



#### 2.3.1 filebeat

[Reference](https://www.elastic.co/guide/en/beats/filebeat/7.17/filebeat-input-journald.html)

```bash
filebeat.inputs:
- type: log # 仅可输入提前内置的log/stdin/docker/container/journald... 
```



#### 2.3.2 processor

[Reference](https://www.elastic.co/guide/en/beats/filebeat/7.17/filtering-and-enhancing-data.html)

```bash
# 有效配置
      processors:
      - drop_fields:
          fields: ["agent.ephemeral_id", "agent.id", "agent.name", "agent.type", "agent.version", "ecs", "host"]
drop 
# 无效配置
#          fields: ["agent.ephemeral_id", "agent.id", "agent.name", "agent.type", "agent.version", "ecs", "host", "fields.topic", "input.type", "log"]
# 怀疑 "host", "fields.topic", "input.type", "log" 字段不允许
```

