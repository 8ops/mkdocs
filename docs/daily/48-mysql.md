# MySQL



## 一、高可用

### 1.1 github orchestrator



### 1.2 mycat2 

[Reference](http://www.mycat.org.cn/)



### 1.3 MMM

需要两个Master，同一时间只有一个Master对外提供服务，可以说是主备模式。

需要基础资源：

| 资源     | 数量  | 说明                                         |
| -------- | ----- | -------------------------------------------- |
| 主DB     | 2     | 用户主备模式的主主复制                       |
| 从DB     | 0~N台 | 可以根据需要配置N台从服务器                  |
| IP地址   | 2n+1  | N为MySQL服务器的数量                         |
| 监控用户 | 1     | 用户监控数据库状态的MySQL用户（replication） |
| 代理用户 | 1     | 用于MMM代理端改变read_only状态               |

故障转移步骤：

- Slave服务器上的操作
- 完成原主上已经复制的日志恢复
- 使用Change Master命令配置新主
- 主服务器上操作
- 设置read_only关闭
- 迁移VIP到新主服务器

优点：

- 提供了读写VIP的配置，试读写请求都可以达到高可用
- 工具包相对比较完善，不需要额外的开发脚本
- 完成故障转移之后可以对MySQL集群进行高可用监控

缺点：

- 故障简单粗暴，容易丢失事务，建议采用半同步复制方式，减少失败的概率
- 目前MMM社区已经缺少维护，不支持基于GTID的复制

适用场景：

- 读写都需要高可用的
- 基于日志点的复制方式

### 1.4 MHA

 

需要资源： 

| 资源     | 数量  | 说明                                         |
| -------- | ----- | -------------------------------------------- |
| 主DB     | 2     | 用于主备模式的主主复制                       |
| 从DB     | 2~N台 | 可以根据需要配置N台从服务器                  |
| IP地址   | n+2   | N为MySQL服务器的数量                         |
| 监控用户 | 1     | 用户监控数据库状态的MySQL用户（replication） |
| 复制用户 | 1     | 用于配置MySQL复制的用户                      |

MHA采用的是从slave中选出Master，故障转移：

- 从服务器：
- 选举具有最新更新的slave
- 尝试从宕机的master中保存二进制日志
- 应用差异的中继日志到其它的slave
- 应用从master保存的二进制日志
- 提升选举的slave为master
- 配置其它的slave向新的master同步

优点：

- MHA除了支持日志点的复制还支持GTID的方式
- 同MMM相比，MHA会尝试从旧的Master中恢复旧的二进制日志，只是未必每次都能成功。如果希望更少的数据丢失场景，建议使用MHA架构。

缺点：

MHA需要自行开发VIP转移脚本。

MHA只监控Master的状态，未监控Slave的状态

### 1.5 MGR

MGR是基于现有的MySQL架构实现的复制插件，可以实现多个主对数据进行修改，使用paxos协议复制，不同于异步复制的多Master复制集群。

支持多主模式，但官方推荐单主模式：

- 多主模式下，客户端可以随机向MySQL节点写入数据
- 单主模式下，MGR集群会选出primary节点负责写请求，primary节点与其它节点都可以进行读请求处理.

```sql
# 查看MGR的组员
select * from performance_schema.replication_group_members;

# 查看MGR的状态
select * from performance_schema.replication_group_member_stats;

# 查看MGR的一些变量
show variables like 'group%';

# 查看服务器是否只读
show variables like 'read_only%';
```

优点：

- 基本无延迟，延迟比异步的小很多
- 支持多写模式，但是目前还不是很成熟
- 数据的强一致性，可以保证数据事务不丢失

缺点:

- 仅支持innodb
- 只能用在GTID模式下，且日志格式为row格式

适用的业务场景：

- 对主从延迟比较敏感
- 希望对对写服务提供高可用，又不想安装第三方软件
- 数据强一致的场景

读写负载大问题

读负载大：

- 增加slave
- 加中间层(MyCat，ProxySQL，Maxscale)
- 读写分离

关于写负载大：

- 分库分表
- 增加中间层