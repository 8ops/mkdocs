# admin



## 一、依赖准备



|       | Addr          | Port  | User          | Pass          | db            |
| ----- | ------------- | ----- | ------------- | ------------- | ------------- |
| Redis | 10.101.11.250 | 30389 |               |               |               |
| MySQL | 10.101.11.250 | 30380 | gin_vue_admin | gin_vue_admin | gin_vue_admin |
| MySQL | 10.101.11.250 | 30380 | go_admin      | go_admin      | go_admin      |

```bash
create database gin_vue_admin;
create user 'gin_vue_admin'@'%' identified by 'gin_vue_admin';
grant all privileges on gin_vue_admin.* to `gin_vue_admin`@`%`;
flush privileges;

create database go_admin;
create user 'go_admin'@'%' identified by 'go_admin';
grant all privileges on go_admin.* to `go_admin`@`%`;
flush privileges;
```



## 二、脚手架

享受社区力量



### 2.1 gin-vue-admin

[Reference](https://github.com/flipped-aurora/gin-vue-admin)



#### 2.1.1 lanuch

```bash
git clone https://github.com/flipped-aurora/gin-vue-admin.git

cd gin-vue-admin/server
go build -o server main.go
./server

cd gin-vue-admin/web
npm i
npm run serve

# vscode 打开 gin-vue-admin.code-workspace
```



#### 2.1.2 自定义vue

```bash
cat > view/demo/index.vue <<EOF
<template>
  <div>
  This is demo menu
  </div>
</template>
EOF
```



#### 2.1.3 代码自动生成

```bash
# 创建表
create table tb_demo(
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  c_name varchar(20),
  c_age int,
  PRIMARY KEY (`id`)
);

show create table tb_demo\G;
Create Table: CREATE TABLE `tb_demo` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `c_name` varchar(20) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `c_age` int DEFAULT NULL,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_tb_demo_deleted_at` (`deleted_at`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci

# 会自动migrate
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `created_at` datetime(3) DEFAULT NULL,
  `updated_at` datetime(3) DEFAULT NULL,
  `deleted_at` datetime(3) DEFAULT NULL,
  
  
```

[Reference](https://www.gin-vue-admin.com/guide/generator/server.html#%E5%AD%97%E6%AE%B5%E7%95%8C%E9%9D%A2%E8%AF%B4%E6%98%8E)



#### 2.1.4 自定义接口

```bash
show create table casbin_rule\G;
INSERT INTO casbin_rule (ptype, v0, v1, v2, v3, v4, v5, v6, v7) VALUES ('p', '999', '/tbDemo/getABC', 'GET', '', '', '', '', '');
select * from casbin_rule;

```





### 2.2 gin-admin

[Reference](https://github.com/go-admin-team/go-admin)



```bash
# 会自动migrate
  `xx_id` bigint NOT NULL AUTO_INCREMENT,
  `xx_name` varchar(255) DEFAULT NULL,
  
  `created_at` datetime(3) DEFAULT NULL COMMENT '创建时间',
  `updated_at` datetime(3) DEFAULT NULL COMMENT '最后更新时间',
  `deleted_at` datetime(3) DEFAULT NULL COMMENT '删除时间',
  `create_by` bigint DEFAULT NULL COMMENT '创建者',
  `update_by` bigint DEFAULT NULL COMMENT '更新者',  
```





