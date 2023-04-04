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

```
```

## client-go

https://github.com/kubernetes/client-go

> 简单使用

```go
import (
    "k8s.io/client-go/tools/clientcmd"
    "k8s.io/client-go/kubernetes"
    appsv1beta1 "k8s.io/api/apps/v1beta1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    apiv1 "k8s.io/api/core/v1"
    "k8s.io/client-go/kubernetes/typed/apps/v1beta1"
    "flag"
    "fmt"
    "encoding/json"
)

func main() {
    //kubelet.kubeconfig  是文件对应地址
    kubeconfig := flag.String("kubeconfig", "kubelet.kubeconfig", "(optional) absolute path to the kubeconfig file")
    flag.Parse()

    // 解析到config
    config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
    if err != nil {
        panic(err.Error())
    }

    // 创建连接
    clientset, err := kubernetes.NewForConfig(config)
    if err != nil {
        panic(err.Error())
    }
    deploymentsClient := clientset.AppsV1beta1().Deployments(apiv1.NamespaceDefault)

    //创建deployment
    go createDeployment(deploymentsClient)

    //监听deployment
    startWatchDeployment(deploymentsClient)
}

//监听Deployment变化
func startWatchDeployment(deploymentsClient v1beta1.DeploymentInterface) {
    w, _ := deploymentsClient.Watch(metav1.ListOptions{})
    for {
        select {
        case e, _ := <-w.ResultChan():
            fmt.Println(e.Type, e.Object)
        }
    }
}

//创建deployemnt，需要谨慎按照部署的k8s版本来使用api接口
func createDeployment(deploymentsClient v1beta1.DeploymentInterface)  {
    var r apiv1.ResourceRequirements
    //资源分配会遇到无法设置值的问题，故采用json反解析
    j := `{"limits": {"cpu":"2000m", "memory": "1Gi"}, "requests": {"cpu":"2000m", "memory": "1Gi"}}`
    json.Unmarshal([]byte(j), &r)
    deployment := &appsv1beta1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name: "engine",
            Labels: map[string]string{
                "app": "engine",
            },
        },
        Spec: appsv1beta1.DeploymentSpec{
            Replicas: int32Ptr2(1),
            Template: apiv1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{
                    Labels: map[string]string{
                        "app": "engine",
                    },
                },
                Spec: apiv1.PodSpec{
                    Containers: []apiv1.Container{
                        {   Name:               "engine",
                            Image:           "my.com/engine:v2",
                            Resources: r,
                        },
                    },
                },
            },
        },
    }

    fmt.Println("Creating deployment...")
    result, err := deploymentsClient.Create(deployment)
    if err != nil {
        panic(err)
    }
    fmt.Printf("Created deployment %q.\n", result.GetObjectMeta().GetName())
}

func int32Ptr2(i int32) *int32 { return &i }
```

> deployment

```go
//声明deployment对象
var deployment *v1beta1.Deployment
//构造deployment对象
//创建deployment
deployment, err := clientset.AppsV1beta1().Deployments(<namespace>).Create(<deployment>)
//更新deployment
deployment, err := clientset.AppsV1beta1().Deployments(<namespace>).Update(<deployment>)
//删除deployment
err := clientset.AppsV1beta1().Deployments(<namespace>).Delete(<deployment.Name>, &meta_v1.DeleteOptions{})
//查询deployment
deployment, err := clientset.AppsV1beta1().Deployments(<namespace>).Get(<deployment.Name>, meta_v1.GetOptions{})
//列出deployment
deploymentList, err := clientset.AppsV1beta1().Deployments(<namespace>).List(&meta_v1.ListOptions{})
//watch deployment
watchInterface, err := clientset.AppsV1beta1().Deployments(<namespace>).Watch(&meta_v1.ListOptions{})
```

> service

```go
//声明service对象
var service *v1.Service
//构造service对象
//创建service
service, err := clientset.CoreV1().Services(<namespace>).Create(<service>)
//更新service
service, err := clientset.CoreV1().Services(<namespace>).Update(<service>)
//删除service
err := clientset.CoreV1().Services(<namespace>).Delete(<service.Name>, &meta_v1.DeleteOptions{})
//查询service
service, err := clientset.CoreV1().Services(<namespace>).Get(<service.Name>, meta_v1.GetOptions{})
//列出service
serviceList, err := clientset.CoreV1().Services(<namespace>).List(&meta_v1.ListOptions{})
//watch service
watchInterface, err := clientset.CoreV1().Services(<namespace>).Watch(&meta_v1.ListOptions{})
```

> pod

```go
//声明pod对象
var pod *v1.Pod
//创建pod
pod, err := clientset.CoreV1().Pods(<namespace>).Create(<pod>)
//更新pod
pod, err := clientset.CoreV1().Pods(<namespace>).Update(<pod>)
//删除pod
err := clientset.CoreV1().Pods(<namespace>).Delete(<pod.Name>, &meta_v1.DeleteOptions{})
//查询pod
pod, err := clientset.CoreV1().Pods(<namespace>).Get(<pod.Name>, meta_v1.GetOptions{})
//列出pod
podList, err := clientset.CoreV1().Pods(<namespace>).List(&meta_v1.ListOptions{})
//watch pod
watchInterface, err := clientset.CoreV1().Pods(<namespace>).Watch(&meta_v1.ListOptions{})
```

