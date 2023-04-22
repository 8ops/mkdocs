# vue

> 前提条件：已安装node可以正常使用npm命令，并全局安装vue-cli工具。 

```bash
npm install vue-cli -g
```

## 创建项目 

- 使用vue初始化基于webpack的新项目 

```
vue init webpack my-project
```

​      项目创建过程中会提示是否安装eslint，可以选择不安装，否则项目编译过程中出现各种代码格式的问题； 

- 项目创建完成后，安装基础模块 

```bash
cd myproject
npm install
```

​      模块安装时间有可能会很长，依赖与网速； 

- 安装完成之后可在开发模式下运行项目并预览项目效果 

```bash
npm run dev
```

- 如果项目可以正常启动，即可继续安装vue的辅助工具 

```bash
npm install vue-router --save （路由管理模块）
npm install vuex --save （状态管理模块）
npm install vue-resource --save （网路请求模块）
```