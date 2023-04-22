# client-go

[Reference](https://github.com/kubernetes/client-go)

## 一、简单使用

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

## 二、相关资源

### 2.1 deployment

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

### 2.2 service

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

### 2.3 pod

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

