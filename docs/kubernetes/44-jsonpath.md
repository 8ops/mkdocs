# 实战 | JsonPath 使用

[Reference](https://kubernetes.io/docs/reference/kubectl/jsonpath/)



## 一、笔记

```bash
# 无换行打印
kubectl get po -A -o jsonpath='{.items[*].spec.containers[*].image}'

# go-template print
kubectl get po -A -o go-template --template='{{range .items}}{{printf "%s\n" .metadata.name}}{{end}}'

# go-template print
kubectl get po -A -o go-template --template='{{range .items}}{{printf "%s\n" .spec.containers[0].image}}{{end}}'

# jsonpath print
kubectl get po -A -o=jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'
```



## 二、常用技巧

| Function           | Description               | Example                                                      | Result                                            |
| ------------------ | ------------------------- | ------------------------------------------------------------ | ------------------------------------------------- |
| `text`             | the plain text            | `kind is {.kind}`                                            | `kind is List`                                    |
| `@`                | the current object        | `{@}`                                                        | the same as input                                 |
| `.` or `[]`        | child operator            | `{.kind}`, `{['kind']}` or `{['name\.type']}`                | `List`                                            |
| `..`               | recursive descent         | `{..name}`                                                   | `127.0.0.1 127.0.0.2 myself e2e`                  |
| `*`                | wildcard. Get all objects | `{.items[*].metadata.name}`                                  | `[127.0.0.1 127.0.0.2]`                           |
| `[start:end:step]` | subscript operator        | `{.users[0].name}`                                           | `myself`                                          |
| `[,]`              | union operator            | `{.items[*]['metadata.name', 'status.capacity']}`            | `127.0.0.1 127.0.0.2 map[cpu:4] map[cpu:8]`       |
| `?()`              | filter                    | `{.users[?(@.name=="e2e")].user.password}`                   | `secret`                                          |
| `range`, `end`     | iterate list              | `{range .items[*]}[{.metadata.name}, {.status.capacity}] {end}` | `[127.0.0.1, map[cpu:4]] [127.0.0.2, map[cpu:8]]` |
| `''`               | quote interpreted string  | `{range .items[*]}{.metadata.name}{'\t'}{end}`               | `127.0.0.1 127.0.0.2`                             |