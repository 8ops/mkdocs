# Redis

## 一、主从模式



## 二、哨兵模式



## 三、集群模式

[Reference](http://www.redis.cn/topics/cluster-tutorial.html)

<u>Demo笔记</u>

```bash

rm -rf /usr/local/redis/conf /opt/lib/redis
mkdir -p /usr/local/redis/conf /opt/lib/redis
cd /usr/local/redis/conf

# ---
for i in 700{0..8}
do
mkdir -p /opt/lib/redis/$i

cat > $i.conf << EOF
port $i
daemonize yes
dir /opt/lib/redis/$i

cluster-enabled yes
cluster-config-file nodes.conf
cluster-node-timeout 5000
appendonly no
EOF

redis-server $i.conf
done
# ---

redis-cli --cluster create 127.0.0.1:7000 127.0.0.1:7001 \
   127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 \
   127.0.0.1:7006 127.0.0.1:7007 127.0.0.1:7008 \
    --cluster-replicas 1

redis-cli -h 127.0.0.1 -p 7000 -c 

redis-benchmark -h 127.0.0.1 -p 7000 -n 100 -c 20
redis-benchmark -h 127.0.0.1 -p 7000 -c -t ping,set,get -n 100000

redis-cli --cluster reshard 127.0.0.1:7000

redis-cli -p 7000 cluster nodes

redis-cli --cluster check 127.0.0.1:7000

redis-cli --cluster add-node 127.0.0.1:7006 127.0.0.1:7000

redis-cli --cluster add-node 127.0.0.1:7007 127.0.0.1:7000

redis-cli --cluster add-node 127.0.0.1:7008 127.0.0.1:7000

redis-cli --cluster del-node 127.0.0.1:7000 48bab8e3c60f93608cd36cbdc2a6118e39b43737
redis-cli --cluster add-node 127.0.0.1:7007 127.0.0.1:7000 --cluster-slave
redis-cli --cluster add-node 127.0.0.1:7007 127.0.0.1:7000 --cluster-slave --cluster-master-id 99f581af1368ea58b41bf9d87447edd6794afd78


for i in {7000..7008}
do
redis-cli -p $i shutdown
done

for i in {a..z}
do
redis-cli -p 7000 -c set $i $i
done

for i in {a..z}
do
redis-cli -p 7000 -c get $i
done
```

