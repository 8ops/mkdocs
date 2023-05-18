
# neo4j

## 一、常规操作

```CQL
# run: 
# mkdir -p /data1/lib/neo4j-5.7.0
# docker run -d --rm --name=neo4j -p 7474:7474 -p 7687:7687 -v /data1/lib/neo4j-5.7.0:/data neo4j:5.7.0
# mkdir -p /data1/lib/neo4j-4.4.20
# docker run -d --rm --name=neo4j -p 7474:7474 -p 7687:7687 -v /data1/lib/neo4j-4.4.20:/data neo4j:4.4.20

# browser: http://127.0.0.1:7474
# connect: neo4j://127.0.0.1:7687

# create
create (:Person {name:"A",age:10})
create (:Person {name:"B",age:15}),(:Person {name:"C",age:20})
create (p1:Person {name:"D",age:25})-[:follow{name:"follow start"}]->(p2:Person {name:"E",age:30}) 
create (p:Person:Author:Teacher {name:"F",age:40,book:"book name is F",class:"二年级"}) return p
create (:Author{name:"F",age:40})
merge (:Author{name:"F",age:40})

# match
match (p) return p limit 25
match (p {name:"A"}) return p
match (p {name:"A"}) return p.name,p.age
match (p:Person) return p
match (p:Person) where p.name = "B" return p
match (p:Person{name:"A"}) set p.addr="上海" return p
match (p:Person{name:"A"}) remove p.addr return p
match (p:Person) return p order by p.age
match (p) return p skip 2 limit 2
match (p:Person) where p.age is not null return p
match (p:Person) where p.age in [10,20,30] return p
match (p:Person) return count(*) # max(p.age) min(p.age) sun(p.age) avg(p.age)
match ()-[r:follow]->() return count(r)
match ()-[r:follow]->() return id(r),type(r)

# delete
match ()-[r]-() delete r
match (p:Person) delete p
# detach same as delete r+p
match (n) detach delete n 

# remove
remove p:Person
remove n.property

# relation followers/following
match (p:Person{name:"A"}) create (p)-[:follow{name:"follower 1st"}]->(:Person{name:"G"})
match (p1:Person{name:"A"}),(p2:Person{name:"B"}) create (p1)-[:follow{name:"follower 2nd"}]->(p2)
match (p1:Person{name:"B"}),(p2:Person{name:"C"}) create (p1)-[:follow{name:"follower 3rd"}]->(p2)

# constraint
create constraint on (p:Person) assert (p.name) is unique 
drop constraint on (p:Person) assert (p.name) is unique

# index
create index on :Person (name,age)
drop index on :Person (name,age)
```



## 二、一次笔记

```bash
# cypher-shell
cypher-shell -a 10.101.11.236 -u neo4j -p neo4j --encryption=false

neo4j-admin dump --database=graph.db --to=$(date +%s).db
neo4j-admin load --from=./1492683962.db --database=graph.db

# use
USING PERIODIC COMMIT 500
LOAD CSV FROM 'http://neo4j.test.youja.cn/relation/last_active_10000.csv' AS line
merge (m:u:Y {i:line[0],m:line[1]})
merge (n:u:Y {i:line[2],m:line[3]})
merge (m)-[:u]->(n)

watch -n 10 'cypher-shell -a 10.10.121.101 -u neo4j -p youja --encryption=false "match (n) return count(n) as COUNT"'

# batch-import: https://github.com/jexp/batch-import
# neo4j-import: https://neo4j.com/docs/operations-manual/current/tutorial/import-tool/

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

# ---

curl -s -o users.csv http://neo4j.8ops.top/relation/last_active_10000-users.csv
curl -s -o roles.csv http://neo4j.8ops.top/relation/last_active_10000-roles.csv

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









































