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
export GITLAB_HOME=/data1/lib/gitlab
mkdir -p $GITLAB_HOME
cat > docker-compose.yml <<EOF
services:
  gitlab:
    image: 'gitlab/gitlab-ce:17.4.0-ce.0'
    restart: always
    hostname: 'git.8ops.top'
    container_name: gitlab
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

docker compose up -d
docker compose down

docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password

docker exec -t gitlab gitlab-backup create
docker exec -t gitlab gitlab-backup create \
    SKIP=artifacts,repositories,registry,uploads,builds,pages,lfs,packages,terraform_state

TODAY=20240924
docker exec gitlab gitlab-rake gitlab:backup:create BACKUP=${TODAY} CRON=1
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



### 2.4 初始密码

```bash
# 初始安装
cat /etc/gitlab/initial_root_password

# 重置
gitlab-rails runner "user = User.find_by_username('root'); user.password = 'your_new_password'; user.password_confirmation = 'your_new_password'; user.save!"

# 界面重置

# 配置文件重置
gitlab_rails['initial_root_password'] = 'your_desired_password'

gitlab-ctl reconfigure

```



### 2.5 邮箱设置

```bash
# 1. 编辑 GitLab 配置文件
# 打开 /etc/gitlab/gitlab.rb 文件进行编辑：

vim /etc/gitlab/gitlab.rb

# 2. 配置邮件服务器
# 在 gitlab.rb 文件中找到 gitlab_rails['smtp_enable'] 部分，按以下模板进行设置。

# 示例：使用 Gmail 作为 SMTP 服务器
# 注意： 如果使用 Gmail，建议为你的账户启用应用专用密码，而不是直接使用你的登录密码。你可以在 Gmail 设置中创建专用密码。
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.gmail.com"
gitlab_rails['smtp_port'] = 587
gitlab_rails['smtp_user_name'] = "your-email@gmail.com"
gitlab_rails['smtp_password'] = "your-password"
gitlab_rails['smtp_domain'] = "smtp.gmail.com"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['smtp_tls'] = false
gitlab_rails['smtp_openssl_verify_mode'] = 'peer'


# 示例：使用其他 SMTP 服务器（如企业邮箱）
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.your-domain.com"
gitlab_rails['smtp_port'] = 465
gitlab_rails['smtp_user_name'] = "your-email@your-domain.com"
gitlab_rails['smtp_password'] = "your-password"
gitlab_rails['smtp_domain'] = "your-domain.com"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
gitlab_rails['smtp_tls'] = true
gitlab_rails['smtp_openssl_verify_mode'] = 'none'

# 3. 设置发件人地址
# 你还需要设置 GitLab 发送邮件时的发件人地址。可以在 gitlab.rb 中找到或添加以下配置：
gitlab_rails['gitlab_email_enabled'] = true
gitlab_rails['gitlab_email_from'] = 'your-email@your-domain.com'
gitlab_rails['gitlab_email_display_name'] = 'GitLab'
gitlab_rails['gitlab_email_reply_to'] = 'noreply@your-domain.com'

# 4. 重新配置 GitLab
# 在完成配置后，需要重新加载配置文件并应用更改：
gitlab-ctl reconfigure

# 5. 测试电子邮件配置
# 完成配置后，测试电子邮件功能是否正常工作。你可以使用 gitlab-rails 命令发送测试邮件：
gitlab-rails runner "Notify.test_email('your-email@domain.com', 'Test Email', 'This is a test email message').deliver_now"

# 
gitlab-ctl reconfigure
gitlab-rails runner "Notify.test_email('your-email@domain.com', 'Test Email', 'This is a test email message').deliver_now"


```





### 2.5 upgrade

**递进式升级**

[Reference](https://gitlab-com.gitlab.io/support/toolbox/upgrade-path)



跨版本升级记录

- 17.8.5
- 17.9.2



#### 步骤 1：备份现有数据

在执行任何升级操作之前，务必备份 GitLab 数据，包括数据库、Git 仓库、配置文件和其他相关数据。

备份命令：

1. 如果你使用了外部存储卷挂载，请手动备份这些卷：

   - Git 仓库数据 (`/var/opt/gitlab`)
   - GitLab 配置文件 (`/etc/gitlab`)
   - 日志文件 (`/var/log/gitlab`)

2. 使用 `gitlab-backup` 命令创建备份（运行在 GitLab 容器内）：

   ```bash
   docker exec -t <gitlab-container-name> gitlab-backup create
   ```
   
   这会创建一个备份文件，通常存储在 `/var/opt/gitlab/backups` 目录下。
   
3. 备份重要的配置文件：

   ```bash
   docker cp <gitlab-container-name>:/etc/gitlab /path/to/backup/etc-gitlab
   docker cp <gitlab-container-name>:/var/opt/gitlab /path/to/backup/var-opt-gitlab
   docker cp <gitlab-container-name>:/var/log/gitlab /path/to/backup/var-log-gitlab
   ```

#### 步骤 2：停止并移除现有 GitLab 容器

在升级之前，需要停止并移除旧的 GitLab 容器。停止 GitLab 容器不会删除数据，因为数据通常保存在 Docker 卷中。

```bash
docker stop <gitlab-container-name>
docker rm <gitlab-container-name>
```

#### 步骤 3：拉取新的 GitLab CE 镜像

从 Docker Hub 下载最新版本的 GitLab CE 镜像：

```bash
docker pull gitlab/gitlab-ce:latest
```

你也可以指定某个版本：

```bash
docker pull gitlab/gitlab-ce:<version>
```

#### 步骤 4：启动新版本的 GitLab 容器

使用与原来相同的配置重新启动容器。确保挂载相同的数据卷，以保证数据不会丢失。

```bash
docker run --detach \
  --hostname gitlab.example.com \
  --publish 443:443 --publish 80:80 --publish 22:22 \
  --name gitlab \
  --restart always \
  --volume /path/to/gitlab/config:/etc/gitlab \
  --volume /path/to/gitlab/logs:/var/log/gitlab \
  --volume /path/to/gitlab/data:/var/opt/gitlab \
  gitlab/gitlab-ce:latest
```

- 将 `/path/to/gitlab/config`、`/path/to/gitlab/logs`、`/path/to/gitlab/data` 替换为你实际的数据卷路径。
- 更新 `--hostname` 参数以匹配你的 GitLab 实例的域名。

#### 步骤 5：检查容器状态

升级完成后，检查容器是否正常运行，并通过日志查看是否有错误：

```bash
docker logs -f gitlab
```

确保服务启动成功，并且 GitLab 能够正常访问。

#### 步骤 6：验证升级

通过浏览器访问 GitLab 界面，确保一切工作正常。你可以在 GitLab 管理界面中查看当前的 GitLab 版本，确认升级是否成功。

```bash
http://<gitlab-hostname>
```

#### 步骤 7：清理旧镜像（可选）

确认升级成功后，你可以删除旧的 Docker 镜像以释放空间：

```bash
docker image prune
```



#### 补偿措施

```bash
# 查看启动服务
docker exec gitlab gitlab-ctl status

# 启动某服务/重启
docker exec gitlab gitlab-ctl start <app>
docker exec gitlab gitlab-ctl restart

# 查看日志
tail -f logs/

# 查看数据迁移
docker exec gitlab gitlab-rake db:migrate

# 重置权限
docker exec -it gitlab update-permissions

# 检查Redis状态
docker exec -it gitlab gitlab-ctl status redis

# 检查SideKiq状态
docker exec -it gitlab gitlab-ctl status sidekiq

# 清理缓存
docker exec -it gitlab gitlab-rake cache:clear
docker exec -it gitlab gitlab-ctl restart

# 修复文件权限
docker exec -it gitlab gitlab-ctl reconfigure

# 手动修复
chown -R git:git /var/opt/gitlab
chown -R gitlab-www:gitlab-www /var/log/gitlab

# 强制升级
gitlab-ctl upgrade

# 回滚
gitlab-ctl stop
gitlab-rake gitlab:backup:restore BACKUP=<备份文件名>
gitlab-ctl restart

```





## 三、安装gitlab-runner

[Reference](https://docs.gitlab.com/runner/install/docker.html)

### 3.1 docker engine

```bash
# 第一步，启动 gitlab-runner 实例
mkdir -p /ops/lib/gitlab-runner/config
docker run -d --name gitlab-runner-01 --restart always \
  -v /ops/lib/gitlab-runner/config:/etc/gitlab-runner \
  -v /usr/bin/docker:/usr/bin/docker \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /ops/lib/gitlab-runner/cache:/cache \
  -v /ops/lib/gitlab-runner/npm:/root/.npm \
  -e 'CA_CERTIFICATES_PATH="/etc/gitlab-runner/certs/ca.crt"' \ # 受信私有CA
  hub.8ops.top/build/gitlab-runner:ubuntu-v17.4.0

# 第二步，进入gitlab console 注册实例并获取注册命令 （Admin Area -> Runners）
gitlab-runner register  --url https://git.8ops.top  --token glrt-zvyQjQV7FDszMetH1Yxu

# 第三步，进入gitlab-runner实例进行注册
docker exec -it gitlab-runner bash

root@gitlab-runner:/# gitlab-runner register  --url https://git.8ops.top  --token glrt-Kdv9Ad4PHqJGyoyKQCp5
Runtime platform                                    arch=amd64 os=linux pid=1431 revision=b92ee590 version=17.4.0
Running in system-mode.

Enter the GitLab instance URL (for example, https://gitlab.com/):
[https://git.8ops.top]:
Verifying runner... is valid                        runner=Kdv9Ad4PH
Enter a name for the runner. This is stored only in the local config.toml file:
[gitlab-runner]:
Enter an executor: ssh, virtualbox, docker-windows, kubernetes, instance, custom, shell, parallels, docker, docker+machine, docker-autoscaler:
docker
Enter the default Docker image (for example, ruby:2.7):

Enter the default Docker image (for example, ruby:2.7):
hub.8ops.top/build/alpine:3
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!

Configuration (with the authentication token) was saved in "/etc/gitlab-runner/config.toml"

# 查看自动生成配置文件
root@gitlab-runner:/# cat /etc/gitlab-runner/config.toml
concurrent = 1
check_interval = 0
connection_max_age = "15m0s"
shutdown_timeout = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "gitlab-runner"
  url = "https://git.8ops.top"
  id = 18
  token = "glrt-Kdv9Ad4PHqJGyoyKQCp5"
  token_obtained_at = 2024-09-26T03:24:18Z
  token_expires_at = 0001-01-01T00:00:00Z
  executor = "docker"
  [runners.custom_build_dir]
  [runners.cache]
    MaxUploadedArchiveSize = 0
    [runners.cache.s3]
    [runners.cache.gcs]
    [runners.cache.azure]
  [runners.docker]
    helper_image = "hub.8ops.top/build/gitlab-runner-helper:x86_64-v17.4.0"
    tls_verify = false
    image = "hub.8ops.top/build/alpine:3"
    privileged = true
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
    network_mtu = 0
```



### 3.2 docker-compose

```bash
# 第一步，启动 gitlab-runner 实例
mkdir -p /opt/lib/gitlab-runner/{config,cache,npm}
cd /opt/lib/gitlab-runner
cat > docker-compose.yaml <<EOF
services:
  gitlab:
    image: hub.8ops.top/build/gitlab-runner:ubuntu-v17.4.0
    container_name: "gitlab-runner-01"
    restart: always
    environment:
      CA_CERTIFICATES_PATH: '/etc/gitlab-runner/certs/ca.crt' # 受信私有CA
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - "/opt/lib/gitlab-runner/config:/etc/gitlab-runner"
      - "/opt/lib/gitlab-runner/cache:/cache"
      - "/opt/lib/gitlab-runner/npm:/root/.npm"
EOF  

# 第二步，进入gitlab console 注册实例并获取注册命令 （Admin Area -> Runners）
gitlab-runner register  --url https://git.8ops.top  --token glrt-zvyQjQV7FDszMetH1Yxu

# 第三步，进入gitlab-runner实例进行注册
docker exec -it gitlab-runner bash

root@gitlab-runner:/# gitlab-runner register  --url https://git.8ops.top  --token glrt-Kdv9Ad4PHqJGyoyKQCp5
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



