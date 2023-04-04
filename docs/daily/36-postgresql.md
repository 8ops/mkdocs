# postgresql 

```bash


yum install -y -q postgresql-server.x86_64
service postgresql initdb
/etc/init.d/postgresql start
chkconfig postgresql on



https://www.postgresql.org/

wget https://ftp.postgresql.org/pub/source/v9.3.13/postgresql-9.3.13.tar.gz

编译安装
cat /etc/profile.d/postgresql-env.sh
export POSTGRESQL_HOME=/usr/local/postgresql
export PATH={POSTGRESQL_HOME}/bin:PATH
export LD_LIBRARY_PATH={POSTGRESQL_HOME}/lib:{LD_LIBRARY_PATH}

. /etc/profile

cat /etc/ld.so.conf.d/postgresql-x86_64.conf
/usr/local/postgresql/lib

ldconfig

groupadd --gid=26
useradd --uid=26 --gid=26 postgres -M

mkdir /data/postgresql
chown postgres.postgres /data/postgresql

su postgres -c "/usr/local/postgresql/bin/initdb -D /data/postgresql"

    /usr/local/postgresql/bin/postgres -D /data/postgresql

or
    /usr/local/postgresql/bin/pg_ctl -D /data/postgresql -l logfile start

su postgres -c "/usr/local/postgresql/bin/pg_ctl -D /data/postgresql -l /tmp/postgresql.out start"
su postgres -c '/usr/local/postgresql/bin/pg_ctl -D /data/postgresql -l /tmp/postgresql.out -o "-h 0.0.0.0" start'

su postgres -c "/usr/local/postgresql/bin/pg_ctl -D /data/postgresql -l /tmp/postgresql.log -o '--config-file=/usr/local/postgresql/config/postgresql.conf' start"

]# netstat -nutlp | grep postgres
tcp        0      0 127.0.0.1:5432              0.0.0.0:*                   LISTEN      24140/postgres
tcp        0      0 ::1:5432                    :::*                        LISTEN      24140/postgres

su postgres -c "/usr/local/postgresql/bin/psql"
\password

postgres=# create user jesse with password 'jesse';
CREATE ROLE
postgres=# create database test owner jesse;
CREATE DATABASE
postgres=# grant all privileges on database test to jesse;
GRANT
postgres=#

\q

====> 
sudo -u postgres createuser --superuser dbuser
sudo -u postgres createdb -O dbuser exampledb
psql -U dbuser -d exampledb -h 127.0.0.1 -p 5432

\h：查看SQL命令的解释，比如\h select。
\?：查看psql命令列表。
\l：列出所有数据库。
\c [database_name]：连接其他数据库。
\d：列出当前数据库的所有表格。
\d [table_name]：列出某一张表格的结构。
\du：列出所有用户。
\e：打开文本编辑器。
\conninfo：列出当前数据库和连接的信息。

create table db_user(username varchar(20),age int,signup date);
insert into db_user (username,age,signup) values ('jesse',18,'2016-09-28'),('david',30,'2016-09-30');
alter table db_user add email varchar(40);
alter table db_user column



```

