# admin



## 一、依赖准备



|       | Addr          | Port  | User          | Pass          | db            |
| ----- | ------------- | ----- | ------------- | ------------- | ------------- |
| Redis | 10.101.11.250 | 30389 |               |               |               |
| MySQL | 10.101.11.250 | 30380 | gin_vue_admin | gin_vue_admin | gin_vue_admin |
| MySQL | 10.101.11.250 | 30380 | gin_admin     | gin_admin     | gin_admin     |

```bash
create database gin_vue_admin;
create user 'gin_vue_admin'@'%' identified by 'gin_vue_admin';
grant all privileges on gin_vue_admin.* to `gin_vue_admin`@`%`;
flush privileges;

create database gin_admin;
create user 'gin_admin'@'%' identified by 'gin_admin';
grant all privileges on gin_admin.* to `gin_admin`@`%`;
flush privileges;

create table tb_demo(
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  c_name varchar(20),
  c_age int,
  PRIMARY KEY (`id`)
);

show create table tb_demo\G;
```



## 二、脚手架

享受社区力量



### 2.1 gin-vue-admin

[Reference](https://github.com/flipped-aurora/gin-vue-admin)



```bash
cat > view/demo/index.vue <<EOF
<template>
  <div>
  This is demo menu
  </div>
</template>
EOF
```





### 2.2 gin-admin

[Reference](https://github.com/go-admin-team/go-admin)





