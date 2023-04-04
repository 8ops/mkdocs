
# neo4j

## Tool

```txt

cypher-shell -a 192.168.1.220 -u neo4j -p youja --encryption=false
cypher-shell -a 10.10.121.101 -u neo4j -p youja --encryption=false
cypher-shell -a 10.10.121.102 -u neo4j -p youja --encryption=false

neo4j-admin dump --database=graph.db --to=$(date +%s).db
neo4j-admin load --from=./1492683962.db --database=graph.db

```

```txt
# use

USING PERIODIC COMMIT 500
LOAD CSV FROM 'http://neo4j.test.youja.cn/relation/last_active_10000.csv' AS line
merge (m:u:Y {i:line[0],m:line[1]})
merge (n:u:Y {i:line[2],m:line[3]})
merge (m)-[:u]->(n)


watch -n 10 'cypher-shell -a 10.10.121.101 -u neo4j -p youja --encryption=false "match (n) return count(n) as COUNT"'

```

> batch-import: https://github.com/jexp/batch-import

> neo4j-import: https://neo4j.com/docs/operations-manual/current/tutorial/import-tool/

```txt
# test

match(n) detach delete n
    
create constraint on (n:u)
assert n.i is unique

create constraint on (n:Y)
assert n.i is unique

create constraint on (n:A)
assert n.i is unique

USING PERIODIC COMMIT 100
LOAD CSV FROM 'http://neo4j.test.youja.cn/relation/last_active_00500.csv' AS line
merge (m:u:Y {i:line[0],m:line[1]})
merge (n:u:Y {i:line[2],m:line[3]})
merge (m)-[:u]->(n)


neo4j stop

awk -F',' '{printf("%s,%s,u\n%s,%s,u:Y\n",$1,$2,$3,$4)}' \
last_active_10000.csv-10 | sort -u > users.csv
sed -i '1 i\\i:ID,m,:LABEL' users.csv

awk -F',' '{printf("%s,%s,u\n",$1,$3)}' \
last_active_10000.csv-10 | sort -u > roles.csv
sed -i '1 i\\:START_ID,:END_ID,:TYPE' roles.csv

rm -rf /data/neo4j/data/databases/graph.db

neo4j-import --into /data/neo4j/data/databases/graph.db \
--nodes users.csv \
--relationships roles.csv \
--delimiter "," \
--array-delimiter ":" --quote "\""


neo4j start

```

```txt

curl -s -o users.csv http://neo4j.test.youja.cn/relation/last_active_10000-users.csv
curl -s -o roles.csv http://neo4j.test.youja.cn/relation/last_active_10000-roles.csv

neo4j stop

rm -rf /data/neo4j/data/databases/graph.db

neo4j-import --into /data/neo4j/data/databases/graph.db \
--nodes users.csv \
--relationships roles.csv \
--delimiter "," \
--array-delimiter ":" --quote "\"" \
--skip-duplicate-nodes

neo4j start

```








































