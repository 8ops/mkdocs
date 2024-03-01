# vmware fusion

应用于 Apple M2 Pro 

该平台是arm架构，在安装软件和后续的iso均选择对应的arm架构。

## 一、安装vmware

[Reference](https://www.vmware.com/products/fusion/fusion-evaluation.html)

注册个人账号获取licence安装时输入。



## 二、安装vm

### 2.1 安装windows

获取arm的iso

[Reference](https://next.itellyou.cn/Original/)

在选择网络nat模式时，安装过程中无法联网且无法绕开。

```bash
# 解决
1，按住 `Shift + F10` 输入 `oobe\bypassnro`重启后继续安装会出现跳过网络按钮
2，`Win + R` 输入 `PowerShell` 执行 `Set-ExecutionPolicy RemoteSigned`以管理员权限运行
3，在vmware菜单：虚拟机-安装vmware tools，在DVD挂载镜像后点击setup.exe安装
4，若运行过`bcdedit /debug on`，需要再运行一次`bcdedit /debug off`
```



### 2.2 安装kali

获取arm的iso

[Reference](https://www.kali.org/get-kali/#kali-installer-images)

网络安全自带工具集合