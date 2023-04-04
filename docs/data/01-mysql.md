# MySQL

## 一、<u>忘记root密码</u>

### 1.1 首先确认服务器出于安全的状态

也就是没有人能够任意地连接MySQL数据库。 
因为在重新设置MySQL的root密码的期间，MySQL数据库完全出于没有密码保护的 
状态下，其他的用户也可以任意地登录和修改MySQL的信息。可以采用将MySQL对 
外的端口封闭，并且停止Apache以及所有的用户进程的方法实现服务器的准安全 
状态。最安全的状态是到服务器的Console上面操作，并且拔掉网线。 

### 1.2 修改MySQL的登录设置： 

> vi /etc/my.cnf 

在[mysqld]的段中加上一句：skip-grant-tables 
例如：

```bash
[mysqld] 
datadir=/var/lib/mysql 
socket=/var/lib/mysql/mysql.sock 
skip-grant-tables 
```

### 1.3 重新启动mysqld 

/etc/init.d/mysqld restart 

Stopping MySQL: [ OK ] 
Starting MySQL: [ OK ] 

### 1.4 登录并修改MySQL的root密码 

/usr/bin/mysql 

```bash
Welcome to the MySQL monitor. Commands end with ; or \g. 
Your MySQL connection id is 3 to server version: 3.23.56 
Type 'help;' or '\h' for help. Type '\c' to clear the buffer. 
mysql> USE mysql ; 
Reading table information for completion of table and column names 
You can turn off this feature to get a quicker startup with -A 
Database changed 
mysql> UPDATE user SET Password = password ( 'new-password' ) WHERE User = 'root' ; 
Query OK, 0 rows affected (0.00 sec) 
Rows matched: 2 Changed: 0 Warnings: 0 
mysql> flush privileges ; 
Query OK, 0 rows affected (0.01 sec) 
mysql> quit 
Bye 
```

### 1.5 将MySQL的登录设置修改回来 

vi /etc/my.cnf 

将刚才在[mysqld]的段中加上的skip-grant-tables删除 

### 1.6 重新启动mysqld 

/etc/init.d/mysqld restart 

Stopping MySQL: [ OK ] 
Starting MySQL: [ OK ]

```
echo "SET PASSWORD FOR root@localhost=PASSWORD('password');">/var/lib/mysql/rootpwd.sql
service mysql restart
rm -f /var/lib/mysql/rootpwd.sql
```

```
#/etc/my.conf
[mysqld]
skip-grant-tables

#修改
#ALTER USER 'root'@'localhost' IDENTIFIED BY 'Zb^R%94Cbtpr';
update mysql.user set authentication_string=password('Zb^R%94Cbtpr') where user='root' and Host = 'localhost';
```