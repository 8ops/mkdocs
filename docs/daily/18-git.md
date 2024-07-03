# git

## 一、常用操作

> 贡献代码

```bash
git remote -v
git remote add upstream https:/xxx #添加源关联到本地
git fetch upstream #更新源至本地 
git merge upstream/master #合并源代码
git push origin master #更新到fork源
```

> 废弃分支

```bash
git remote prune origin
```

### 1.1 case by case

在mac、linux及windows切换编程时，出现

```bash
$ git diff xx.go
warning: LF will be replaced by CRLF in approval/types.go.
The file will have its original line endings in your working directory.
```

解决

```bash
$ git config --global core.autocrlf input
```

当私有证书验证失败

```bash
$ git config --global sslVerify false
```

### 1.2 简易使用

```
删除远程分支
git push origin --delete serverfix
git push origin :serverfix
```

Create a new repository on the command line 

```
touch README.md
git init
git add README.md
git commit -m "first commit"
git remote add origin git@github.com:xtso520ok/hadoop-use.git
git push -u origin master
```

Push an existing repository from the command line 

```
git remote add origin git@github.com:xtso520ok/hadoop-use.git
git push -u origin master
```

by ssh-keygen

```bash
Global setup:
Set up git
git config --global user.name "user_name"
git config --global user.email ×××@×××.com
Add your public key

Next steps:
mkdir project_name
cd project_name
git init
touch README
git add README
git commit -m 'first commit'
git remote add origin git@github.com:user_name/project_name.git
git push -u origin master

Existing Git Repo?
cd existing_git_repo
git remote add origin git@github.com:user_name/project_name.git
git push -u origin master

Importing a Subversion Repo?
Click here
When you're done:
Continue 
[ADD/MODIFY/DELETE] by https
git status -s
git commit -m "Add README document"
git config --global user.name "xtso520ok" 
git config --global user.email xtso520ok@gmail.com 
git status -s 
git push origin master 
```

set pull rebase

```bash
git config --global pull.rebase true
git config --glbal http.sslverify false
```



### 1.3 常用操作

```bash
github的提交方式
     （1）git add .--------------------存储到本地
         git commit -m 'message'-------存储时的标记（修改了哪些地方，方便下次查询）
         git pull------------------------下载服务器代码
         git push------------------------上传代码至服务器
  svn服务器的提交方式
   （1）git add .  ------------------存储到本地
        git commit -m 'message'--------存储时的标记（修改了哪些地方，方便下次查询）
        git svn rebase------------------下载服务器代码
        git svn dcommit-----------------上传代码至服务器
   其他相关的git命令
（1）git branch-------------------查看当前属于哪个分支
    1、只有冲突存在时才会修改分支——改为冲突再git add .
    2、git rebase –-continue-------------------自动合并
    3、git checkout –b svn 新建分支名----------新建分支存储现有文件
    4、git branch-------------------------------查看在哪个分支下
    5、git checkout master----------------------将其放到master分支下
    6、git merge-------------------------------整合分支 

    7、git branch -d 分支名----------------------删除分支
（2）git checkout + 上传的commit编号-----------将本地代码恢复到此状态
（3）git log------------------------------------查看本地git上传日志
（4）git log -p app/controllers/grids_controller.rb----查看某个文件的修改历史
（5）git checkout d0eb6ef3afe8a377943d3cf6f1e9c320c18f6f32
     app/controllers/charts_controller.rb-----------返回到这个版本的文件（重现错误） 

（6）git diff ＋ commit编号--------------------------查询不同代码 

```



### 1.4 git 升级

```bash
GIT_VERSION=2.45.2
cd /opt
wget https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.gz
tar xzf git-${GIT_VERSION}.tar.gz
cd git-${GIT_VERSION}

yum install -y libcurl-devel
make prefix=/usr/local/ all
make prefix=/usr/local install

git config --global user.name "your_name"
git config --global user.email "email@address.com"
git config --list

```





## 二、安装gitlab

[Reference](https://gitlab.cn/install/)



### 2.1 docker engine

| 本地位置              | 容器位置          | 使用                          |
| :-------------------- | :---------------- | :---------------------------- |
| `$GITLAB_HOME/data`   | `/var/opt/gitlab` | 用于存储应用程序数据。        |
| `$GITLAB_HOME/logs`   | `/var/log/gitlab` | 用于存储日志。                |
| `$GITLAB_HOME/config` | `/etc/gitlab`     | 用于存储极狐GitLab 配置文件。 |

```bash
export GITLAB_HOME=/data1/gitlab
mkdir -p $GITLAB_HOME
docker run --detach \
  --hostname git.8ops.top \
  --publish 50443:443 --publish 50080:80 --publish 50022:22 \
  --name gitlab \
  --restart always \
  --volume $GITLAB_HOME/config:/etc/gitlab \
  --volume $GITLAB_HOME/logs:/var/log/gitlab \
  --volume $GITLAB_HOME/data:/var/opt/gitlab \
  --shm-size 256m \
  registry.gitlab.cn/omnibus/gitlab-jh:latest

docker logs -f gitlab
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```



### 2.2 docker-compose

```bash
export GITLAB_HOME=/data1/gitlab
mkdir -p $GITLAB_HOME
cat > docker-compose.yml <<EOF
version: '3.6'
services:
  web:
    image: 'registry.gitlab.cn/omnibus/gitlab-jh:latest'
    restart: always
    hostname: 'git.8ops.top'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'https://git.8ops.top'
    ports:
      - '443:443'
      - '80:80'
      - '22:22'
      - '9090:9090' # optional
      - '9093:9093' # optional
      - '9168:9168' # optional
      - '3000:3000' # optional
    volumes:
      - '\$GITLAB_HOME/config:/etc/gitlab'
      - '\$GITLAB_HOME/logs:/var/log/gitlab'
      - '\$GITLAB_HOME/data:/var/opt/gitlab'
    shm_size: '256m'
EOF

docker-compose up -d
docker-compose down

docker exec -it gitlab-web-1 grep 'Password:' /etc/gitlab/initial_root_password

docker exec -t gitlab-web-1 gitlab-backup create
docker exec -t gitlab-web-1 gitlab-backup create \
    SKIP=artifacts,repositories,registry,uploads,builds,pages,lfs,packages,terraform_state

```



### 2.3 publish port

```bash
vim /etc/gitlab/gitlab.rb


prometheus['listen_address'] = '0.0.0.0:9090'

alertmanager['listen_address'] = '0.0.0.0:9093'

gitlab_exporter['listen_address'] = '0.0.0.0'
gitlab_exporter['listen_port'] = '9168'

grafana['enable'] = true
grafana['http_addr'] = '0.0.0.0'
grafana['http_port'] = 3000

```





## 三、安装gitlab-runner

[Reference](https://docs.gitlab.com/runner/install/docker.html)

### 3.1 docker engine

```bash
mkdir -p /ops/lib/gitlab-runner/config

docker run -d --name gitlab-runner-01 --restart always \
  -v /ops/lib/gitlab-runner/config:/etc/gitlab-runner \
  -v /usr/bin/docker:/usr/bin/docker \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /ops/lib/gitlab-runner/cache:/cache \
  -v /ops/lib/gitlab-runner/npm:/root/.npm \
  hub.8ops.top/gitlab/gitlab-runner:ubuntu-v15.11.0

docker exec -it gitlab-runner-01 bash

root@2d1ad818473b:/# gitlab-runner register
Runtime platform                                    arch=amd64 os=linux pid=43 revision=436955cb version=15.11.0
Running in system-mode.

Enter the GitLab instance URL (for example, https://gitlab.com/):
https://git.8ops.top/
Enter the registration token:
1-EfKb5frVSZJyQivzHZ
Enter a description for the runner:
[2d1ad818473b]: 10.101.9.137
Enter tags for the runner (comma-separated):
normal
Enter optional maintenance note for the runner:
Jesse
WARNING: Support for registration tokens and runner parameters in the 'register' command has been deprecated in GitLab Runner 15.6 and will be replaced with support for authentication tokens. For more information, see https://gitlab.com/gitlab-org/gitlab/-/issues/380872
Registering runner... succeeded                     runner=1-EfKb5f
Enter an executor: docker, docker-windows, parallels, ssh, virtualbox, docker-ssh+machine, instance, custom, docker-ssh, shell, docker-autoscaler, docker+machine, kubernetes:
docker
Enter the default Docker image (for example, ruby:2.7):
alpine:latest
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!

Configuration (with the authentication token) was saved in "/etc/gitlab-runner/config.toml"
root@2d1ad818473b:/# cat /etc/gitlab-runner/config.toml
concurrent = 1
check_interval = 0
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "10.101.9.137"
  url = "https://git.8ops.top/"
  id = 10
  token = "CybARF7TCRmjmwCg59xz"
  token_obtained_at = 2023-06-02T03:48:38Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  [runners.cache]
    MaxUploadedArchiveSize = 0
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
```



### 3.2 docker-compose

```bash
mkdir -p /opt/lib/gitlab-runner/{config,cache,npm}

cd /opt/lib/gitlab-runner
cat > docker-compose.yaml <<EOF
version: '3.2'

services:
  gitlab:
    image: hub.8ops.top/gitlab/gitlab-runner:ubuntu-v15.11.0
    container_name: "gitlab-runner-01"
    restart: always
    volumes:
      - "/opt/lib/gitlab-runner/config:/etc/gitlab-runner"
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "/opt/lib/gitlab-runner/cache:/cache"
      - "/opt/lib/gitlab-runner/npm:/root/.npm"
EOF  

cat > config/config.toml <<EOF
concurrent = 10
check_interval = 0
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "docker-runner"
  url = "https://git.8ops.top/"
  id = 2
  token = "WtJP7sS8m8DuphDkrYxJ"
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    MaxUploadedArchiveSize = 0
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    tls_verify = false
    image = "alpine:latest"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/var/run/docker.sock:/var/run/docker.sock", "/opt/lib/gitlab-runner/cache:/cache" ,"/opt/lib/gitlab-runner/npm:/root/.npm"]
    shm_size = 0
EOF
```

## 四、github PR

PR步骤，在github中经常看到很多好的开源项目，有些功能没有覆盖到，或暴露出些bug可以通过PR帮其完善

```bash
# 第一步，fork repo 到自己帐号下

# 第二步，克隆到本地
git clone git@xxx

# 第三步，与原 repo 建立链接
git remote add upstream https://github.com/xx/yy.git
git remote -v

# 第四步，建立分支
git checkout -b feature-xx

# 第五步，coding，commit
git commit -m "add feature xx" .

# 第六步，push
git push --set-upstream origin feature-xx

# 第七步，自己帐号下创建 PR 到原 repo，描述相关内容
```



## 五、变更远程分支

```bash
# 重命名远程分支对应的本地分支
git branch -m oldName newName

# 删除远程分支
git push --delete origin oldName

# 上传新命名的本地分支
git push origin newName

# 关联远程分支
git branch --set-upstream-to origin/newName
```



