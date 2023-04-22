# Golang

## 环境配置

```bash
export GO_HOME=/usr/local/go
export PATH=${GO_HOME}/bin:${PATH}
export GOROOT=${GO_HOME}
export GOPATH=/Users/jesse/workspace/go
export PATH=${GOPATH}/bin:${PATH}

export CGO_ENABLED=0

export GOPROXY=https://goproxy.io
# export GOPROXY=https://athens.azurefd.net
# export GOPROXY=https://goproxy.cn
# export GOPROXY=https://gocenter.io

export GOPRIVATE="*.8ops.top"
export GONOPROXY="*.8ops.top"
export GONOSUMDB="*.8ops.top"

export GOLANG_PROTOBUF_REGISTRATION_CONFLICT=warn
```



## Goland激活

更多操作见https://zhile.io/

> 2020.1.1前

```
使用方法:
 0. 先下载压缩包解压后得到jetbrains-agent.jar，把它放到你认为合适的文件夹内。
    下载页面：https://zhile.io/2018/08/17/jetbrains-license-server-crack.html
 1. 启动你的IDE，如果上来就需要注册，选择：试用（Evaluate for free）进入IDE
 2. 点击你要注册的IDE菜单："Configure" 或 "Help" -> "Edit Custom VM Options ..."
    如果提示是否要创建文件，请点"Yes"。
    参考文章：https://intellij-support.jetbrains.com/hc/en-us/articles/206544869
 3. 在打开的vmoptions编辑窗口末行添加：-javaagent:/absolute/path/to/jetbrains-agent.jar
    一定要自己确认好路径(不要使用中文路径)，填错会导致IDE打不开！！！最好使用绝对路径。
	一个vmoptions内只能有一个-javaagent参数。
    示例:
      mac:      -javaagent:/Users/neo/jetbrains-agent.jar
      linux:    -javaagent:/home/neo/jetbrains-agent.jar
      windows:  -javaagent:C:\Users\neo\jetbrains-agent.jar
    如果还是填错了，参考这篇文章编辑vmoptions补救：
    https://intellij-support.jetbrains.com/hc/en-us/articles/206544519
 4. 重启你的IDE。
 5. 点击IDE菜单 "Help" -> "Register..." 或 "Configure" -> "Manage License..."
    支持两种注册方式：License server 和 Activation code:
    1). 选择License server方式，地址填入：http://jetbrains-license-server （应该会自动填上）
        或者点击按钮："Discover Server"来自动填充地址。
    2). 选择Activation code方式离线激活，请使用：ACTIVATION_CODE.txt 内的注册码激活
        如果激活窗口一直弹出（error 1653219），请去hosts文件里移除jetbrains相关的项目
        如果你需要自定义License name，请访问：https://zhile.io/custom-license.html
```

> 2020.1.2后

果断使用 `VS Code`

