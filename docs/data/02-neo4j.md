# Neo4J

## 导入导出

```bash
#导出
./neo4j-admin dump --database=graph.db --to=graph-20190222.db

#导入
./neo4j-admin load --from=graph-20190222.db --database=graph.db --force
```

