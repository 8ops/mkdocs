# python

## 一、编译笔记

### 1.1 编译过程

```bash
# 注意顺序这个先装，否则后面安装解压时python出错
yum install zlib zlib-devel
wget --no-check-certificate https://www.python.org/ftp/python/2.7.12/Python-2.7.12.tgz
tar xvzf Python-2.7.12.tgz 
cd Python-2.7.12
./configure --prefix=/usr/local/python
make && make install

# 需要注意yum; which yum
cat > /etc/profile.d/sqlite3-env.sh << EOF
export SQLITE3_HOME=/usr/local/sqlite3
export PATH=${SQLITE3_HOME}/bin:$PATH
EOF
source /etc/profile
echo $PATH
which python

wget https://bootstrap.pypa.io/ez_setup.py -O - | python
easy_install pip
easy_install pymongo
easy_install redis
easy_install simplejson

# CentOS7.0 or Ubuntu 需要注意特殊情况
yum install -y mysql-devel.x86_64
easy_install MySQL-python

# 配置国内的源
mkdir -p ~/.pip
cat > ~/.pip/pip.conf <<EOF
[global]  
index-url=http://mirrors.aliyun.com/pypi/simple
EOF

# 遇到“ImportError: No module named _sqlite3”问题。
# 解决办法：需先编译sqlite3.
wget http://www.sqlite.org/sqlite-amalgamation-3.6.20.tar.gz
tar zxvf  sqlite-amalgamation-3.6.20.tar.gz
cd  sqlite-3.5.6
./configure –prefix=/usr/local/sqlite3
make && make install  #(这样，sqlite3编译完成）

# 再来编译python2.7.12:
wget http://python.org/ftp/python/2.7.12/Python-2.7.12.tar.xz
xz -d Python-2.7.12.tar.xz
tar xf  Python-2.7.12.tar

# 先修改Python-2.7.12目录里的setup.py 文件：
cd  Python-2.7.12
sqlite_inc_paths = [ ‘/usr/include’,
     ‘/usr/include/sqlite’,
     ‘/usr/include/sqlite3’,
     ‘/usr/local/include’,
     ‘/usr/local/include/sqlite’,
     ‘/usr/local/include/sqlite3’,
     ‘/usr/local/lib/sqlite3/include’,
     ‘/usr/local/sqlite3/include’, # 添加此行

./configure --prefix=/usr/local/python
make && make install  #（这样，python2.7.12编译完成，解决sqlite3导入出错的问题）

yum install -y -q libxslt-devel
pip install lxml

yum install -y zlib zlib-dev openssl-devel sqlite-devel bzip2-devel libffi libffi-devel gcc gcc-c++

yum install xz-devel mesa-libGL python-backports-lzma
```

`2.x.x`注定被时代淘汰，`3.x.x`大势所趋

常用安装方式

- 编译安装
- virtual
- [pyenv](https://github.com/pyenv/pyenv)

### 1.2 安装 openssl

可选 install 1.1.1o

另参考 [3.2.0](../daily/37-rabbitmq.md/?h=rabb#112-openssl)

```bash
# openssl 版本过低
# Installing Python-3.10.2...
# ERROR: The Python ssl extension was not compiled. Missing the OpenSSL lib?

# 1.下贼openssl
OPENSSL_VERSION=1.1.1o
wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
tar -zxvf openssl-${OPENSSL_VERSION}.tar.gz
cd openssl-${OPENSSL_VERSION}

# 2.编译安装
./config --prefix=/usr/local/openssl no-zlib #不需要zlib
make && make install

# 3.备份原配置
mv /usr/bin/openssl /usr/bin/openssl.bak
mv /usr/include/openssl/ /usr/include/openssl.bak

# 4.新版配置
ln -s /usr/local/openssl/include/openssl /usr/include/openssl
ln -s /usr/local/openssl/lib/libssl.so.1.1 /usr/local/lib64/libssl.so
ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl

# 5.修改系统配置
## 写入openssl库文件的搜索路径
echo "/usr/local/openssl/lib" >> /etc/ld.so.conf.d/openssl-x86_64.conf
## 使修改后的/etc/ld.so.conf生效 
ldconfig -v

# 6.查看openssl版本
openssl version

# 7.环境加载lib
LD_RUN_PATH="/usr/local/openssl/lib" \
LDFLAGS="-L/usr/local/openssl/lib" \
CPPFLAGS="-I/usr/local/openssl/include" \
CFLAGS="-I/usr/local/openssl/include" \
CONFIGURE_OPTS="--with-openssl=/usr/local/openssl" 
```



补充

```bash
# 执行以下命令可以解决上面的错误：
# CentOS
sudo ln -s /usr/local/lib64/libssl.so.1.1 /usr/lib64/
sudo ln -s /usr/local/lib64/libcrypto.so.1.1 /usr/lib64/
# 在 Ubuntu 上也更新了 OpenSSL，这里的命令有些不一样：

sudo ln -s /usr/local/lib/libcrypto.so.1.1 /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1
sudo ln -s /usr/local/lib/libssl.so.1.1 /usr/lib/x86_64-linux-gnu/libssl.so.1.1
```





## 二、编译安装

```bash
./configure --prefix=/usr/local/python-3.8.4 --enable-optimizations --with-openssl=/usr/local/openssl
make && make install
```



## 三、虚拟环境

`cache `提前下载`Python-xx.tar.xz`至`~/.pyenv/cache/`

可选

### 3.1 pyenv

[Reference](https://github.com/pyenv/pyenv)

```bash
# 1.下载pyenv
rm -rf ~/.pyenv
PYENV_VERSION=v2.3.22
curl -s -o /tmp/pyenv-${PYENV_VERSION}.tar.gz https://github.com/pyenv/pyenv/archive/refs/tags/${PYENV_VERSION}.tar.gz
tar xzf /tmp/pyenv-${PYENV_VERSION}.tar.gz
mv pyenv-${PYENV_VERSION} ~/.pyenv

# 2.初始pyenv环境
grep -q PYENV_ROOT ~/.profile | cat >> ~/.profile <<EOF
export PYENV_ROOT="~/.pyenv"
export PATH="\${PYENV_ROOT}/bin:\$PATH"
eval "\$(pyenv init --path)"
EOF

grep -q PYENV_ROOT ~/.bashrc | cat >> ~/.bashrc <<EOF
export PYENV_ROOT="~/.pyenv"
export PATH="\${PYENV_ROOT}/bin:\$PATH"
eval "\$(pyenv init --path)"
EOF

. ~/.bashrc

# view pyenv version
pyenv --version

# view install python versions
pyenv versions

# view support python versions
pyenv install --list

PYTHON_VERSION=3.12.4
# 若遇到 ModuleNotFoundError: No module named '_ssl'问题
LD_RUN_PATH="/usr/local/openssl/lib64" \
LDFLAGS="-L/usr/local/openssl/lib64" \
CPPFLAGS="-I/usr/local/openssl/include" \
CFLAGS="-I/usr/local/openssl/include" \
CONFIGURE_OPTS="--with-openssl=/usr/local/openssl " pyenv install ${PYTHON_VERSION}

```



### 3.2 python

[Reference](https://www.python.org/downloads/source/)

```bash

PYTHON_VERSION=3.12.4
mkdir -p ~/.pyenv/cache
curl -s -o ~/.pyenv/cache/Python-${PYTHON_VERSION}.tar.xz https://m.8ops.top/python/Python-${PYTHON_VERSION}.tar.xz

# ubuntu's install require package
apt install -y gcc make binutils build-essential zlib1g-dev \
    libffi-dev libbz2-dev  libsqlite3-dev \
    libreadline-dev lib64readline-dev libncurses5-dev libncursesw5-dev libssl-dev 

## centos's install require package
yum install gcc gcc-c++ autoconf automake binutils \
    make cmake wget openssl-devel libsqlite3x libffi-devel \
    httpd-devel libsqlite3x-devel ncurses-devel \
    bzip2-devel bzip2-libs bzip2 readline-devel readline mod-wsgi xz xz-devel

pyenv install 3.10.2

# 提示建议优化，重新安装即可
MAKE_OPTS="-j8" \
CONFIGURE_OPTS="--enable-shared --enable-optimizations --with-computed-gotos" \
CFLAGS="-march=native -O2 -pipe" \
pyenv install -v ${PYTHON_VERSION}
  
# 可以安装多个版本在一个系统中，选择指定版本为使用状态
pyenv global ${PYTHON_VERSION}

mkdir -p ~/.pip
cat > ~/.pip/pip.conf <<EOF
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/

[install]
trusted-host=mirrors.aliyun.com
EOF

pip install --upgrade pip
```



### 3.3 MacBook

```bash
mkdir -p ~/.pyenv/cache

wget https://www.python.org/ftp/python/3.11.2/Python-3.11.2.tar.xz \
    -O ~/.pyenv/cache/Python-3.11.2.tar.xz 

env \
  PATH="$(brew --prefix tcl-tk)/bin:$PATH" \
  LDFLAGS="-L$(brew --prefix tcl-tk)/lib -L$(brew --prefix zlib)/lib -L$(brew --prefix bzip2)/lib" \
  CPPFLAGS="-I$(brew --prefix tcl-tk)/include -L$(brew --prefix zlib)/include -L$(brew --prefix bzip2)/include" \
  PKG_CONFIG_PATH="$(brew --prefix tcl-tk)/lib/pkgconfig" \
  CFLAGS="-I$(brew --prefix tcl-tk)/include -I$(brew --prefix openssl)/include -I$(brew --prefix bzip2)/include -I$(brew --prefix zlib)/include -I$(brew --prefix readline)/include -I$(xcrun --show-sdk-path)/usr/include" \
  LDFLAGS="-I$(brew --prefix tcl-tk)/lib -L$(brew --prefix openssl)/lib -L$(brew --prefix readline)/lib -L$(brew --prefix zlib)/lib -L$(brew --prefix bzip2)/lib" \
  MAKE_OPTS="-j8" \
  CC=gcc pyenv install -v 3.11.2

```

## 四、常用模块

[Reference](https://docs.python.org/3/py-modindex.html)

```bash
python -m http.server 8000
```



## 五、常见问题

### 5.1 configure: error

```bash
# # mac apple slice
# checking for --with-universal-archs... no
# checking MACHDEP... "darwin"
# checking for xcrun... yes
# checking macOS SDKROOT... /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
# checking for gcc... clang
# checking whether the C compiler works... no
# configure: error: in `/var/folders/0s/qm_x16j50gvdlbkdf6lkm_g80000gn/T/python-build.20231211141839.54923/Python-3.12.1':
# configure: error: C compiler cannot create executables
# See `config.log' for more details
# make: *** No targets specified and no makefile found.  Stop.

# method 1
softwareupdate --all --install --force

# method 2
sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --install

brew reinstall zlib bzip2

# e.g.
# CFLAGS="-I$(brew --prefix openssl)/include -I$(brew --prefix bzip2)/include -I$(brew --prefix readline)/include -I$(xcrun --show-sdk-path)/usr/include" LDFLAGS="-L$(brew --prefix openssl)/lib -L$(brew --prefix readline)/lib -L$(brew --prefix zlib)/lib -L$(brew --prefix bzip2)/lib" pyenv install --patch 3.8.0 < <(curl -sSL https://github.com/python/cpython/commit/8ea6353.patch\?full_index\=1)


```

