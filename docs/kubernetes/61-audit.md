# Kubernetes Audit

## 一、apiserver开启audit.log

使用 `kubeadm` 启用 Kubernetes 的审计日志功能可以通过以下步骤实现。具体操作包括修改 API Server 的启动参数来开启审计日志记录并配置审计策略。

### 步骤 1：准备审计策略文件

首先，创建一个审计策略文件，这个文件定义了 Kubernetes 应记录哪些类型的操作。示例策略文件如下：

```yaml
# audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata  # 记录元数据信息，例如用户、资源类型等
    verbs: ["create", "update", "delete"]  # 记录创建、更新、删除操作
    resources:
      - group: ""  # 指定 Core API 资源
        resources: ["pods", "services", "deployments"]  # 要审计的资源
  - level: None  # 忽略不感兴趣的其他请求
```



```bash
cat > /etc/kubernetes/audit-policy.yaml << EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: Metadata
    verbs: ["create", "update", "delete"]
    resources:
      - group: ""
        resources: ["pods", "services", "deployments", "configmaps", "secrets", "serviceaccounts"]
  - level: None
EOF
```





将此文件保存为 `audit-policy.yaml`，并将其存放在主节点上一个合适的目录中（例如 `/etc/kubernetes/audit-policy.yaml`）。

### 步骤 2：修改 API Server 的启动参数

编辑 API Server 的配置文件来启用审计日志功能。在使用 `kubeadm` 部署的集群中，API Server 的配置位于 `/etc/kubernetes/manifests/kube-apiserver.yaml`。

在此文件中添加以下参数来启用审计日志：

```yaml
# /etc/kubernetes/manifests/kube-apiserver.yaml
spec:
  containers:
  - name: kube-apiserver
    image: k8s.gcr.io/kube-apiserver:v1.xx.x  # 确保这里的版本与您的 Kubernetes 版本匹配
    command:
      - kube-apiserver
      - --audit-policy-file=/etc/kubernetes/audit-policy.yaml  # 审计策略文件路径
      - --audit-log-path=/var/log/kubernetes/audit.log         # 审计日志文件路径
      - --audit-log-maxage=30                                  # 审计日志保留天数
      - --audit-log-maxbackup=10                               # 审计日志备份文件数
      - --audit-log-maxsize=100                                # 审计日志文件大小限制（单位 MB）
```

```bash
# kube-apiserver启动命令
    - --audit-policy-file=/etc/kubernetes/audit-policy.yaml
    - --audit-log-path=/var/log/kubernetes/audit.log
    - --audit-log-maxage=7
    - --audit-log-maxbackup=5
    - --audit-log-maxsize=10

# 挂载进容器
    - mountPath: /etc/kubernetes/audit-policy.yaml
      name: audit-policy
      readOnly: true
    - mountPath: /var/log/kubernetes
      name: audit-log

# 挂载宿主机配置
  - hostPath:
      path: /etc/kubernetes/audit-policy.yaml
      type: File
    name: audit-policy
  - hostPath:
      path: /var/log/kubernetes
      type: DirectoryOrCreate
    name: audit-log
```



将 `audit-policy-file` 指向刚才创建的策略文件路径，并指定 `audit-log-path` 为保存审计日志的文件路径。

### 步骤 3：重启 API Server

编辑并保存 `/etc/kubernetes/manifests/kube-apiserver.yaml` 文件后，`kubelet` 会检测到文件的更改并自动重启 `kube-apiserver` 容器，使新的审计日志设置生效。

### 步骤 4：检查审计日志

配置完成后，API Server 会在指定的日志文件（如 `/var/log/kubernetes/audit.log`）中生成审计记录。可以通过以下命令查看日志：

```bash
cat /var/log/kubernetes/audit.log
```

### 可选：将审计日志发送到外部日志管理系统

为实现更全面的日志分析，可以使用 Fluentd、Filebeat 等工具将日志导出至 ELK、Splunk 等日志管理平台。

这就完成了通过 `kubeadm` 启用 Kubernetes 审计日志的流程。



## 二、Falco

[Reference](https://falco.org/docs/getting-started/falco-kubernetes-quickstart/)





## 三、Kubewatch

[Reference](https://github.com/robusta-dev/kubewatch)

[chat](https://github.com/sunny0826/kubewatch-chat)



