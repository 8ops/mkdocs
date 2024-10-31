# Ansible

## 一、install

```bash
pip install ansible

# env
ANSIBLE_INVENTORY=/opt/ansible/config/hosts
ANSIBLE_TRANSFORM_INVALID_GROUP_CHARS=silently
ANSIBLE_CONFIG=/opt/ansible/config/ansible.cfg
```



## 二、配置

```bash
# ansible.cfg
[defaults]
ANSIBLE_DEPRECATION_WARNINGS=False
ANSIBLE_COMMAND_WARNINGS=False
inventory      = ./hosts
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/cache/facts
timeout = 60
[privilege_escalation]
[paramiko_connection]
[ssh_connection]
ssh_args = -C -o ControlMaster=auto -o ControlPersist=60s -o ServerAliveInterval=30 -o ServerAliveCountMax=10
[accelerate]
[selinux]
[colors]
[diff]
```





## 三、常见问题

### 3.1 connection

```bash
# 1，超时 /etc/ssh/sshd_config
ClientAliveInterval 60
ClientAliveCountMax 3

# 2，host key

# 3，目标机器python版本
# python3.6 有明显错误
ln -sf /usr/local/python3.9/bin/python3.9 /usr/bin/python3

ls -lt /usr/bin/pyt*
/usr/bin/python3 -> /usr/local/python3.9/bin/python3.9

# 4，ansible 版本
pip install --upgrade ansible


```



