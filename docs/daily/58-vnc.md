# VNC

Ubuntu的VNC远程连接仅在本地登录桌面时可用，这通常与VNC服务的绑定机制和会话管理有关。以下是综合分析与解决方案：

------

### **问题根源**

1. **VNC服务绑定到用户会话** Ubuntu默认的VNC服务（如`gnome-vino`或`tigervnc`）需要依赖当前用户的图形会话存在。当用户本地注销后，VNC服务进程随之终止，导致远程无法连接。
2. **服务启动模式限制** 若VNC服务通过`systemd`配置为系统级服务，可能因权限或环境变量问题无法在无用户登录时启动。

------

### 一、VNCServer

#### 1. **配置VNC服务为独立进程（推荐）**

- **步骤1：创建专用用户（可选）** `sudo adduser vncuser`
- **步骤2：安装并配置TigerVNC** `sudo apt install tigervnc-standalone-server sudo -u vncuser vncpasswd  # 设置VNC密码`
- **步骤3：创建自定义systemd服务** `sudo nano /etc/systemd/system/vncserver@:1.service`内容如下（替换`vncuser`和显示号）： `[Unit] Description=Start VNC server at startup After=syslog.target network.target [Service] Type=forking User=vncuser Group=vncuser ExecStart=/usr/bin/vncserver :1 -geometry 1920x1080 -localhost no ExecStop=/usr/bin/vncserver -kill :1 [Install] WantedBy=multi-user.target`
- **步骤4：启用并启动服务** `sudo systemctl daemon-reload sudo systemctl enable vncserver@:1.service sudo systemctl start vncserver@:1.service`

#### 2. **强制VNC服务监听所有IP**

- 修改启动命令添加`-localhost no`参数，确保服务绑定到`0.0.0.0`而非`127.0.0.1`： `vncserver :1 -localhost no`

#### 3. **检查防火墙规则**

- 开放VNC端口（默认5901）： `sudo ufw allow 5901/tcp sudo ufw reload`

#### 4. **验证会话独立性**

- **手动测试**：退出本地桌面后，通过SSH执行： `sudo systemctl status vncserver@:1.service`确认服务状态为`active (running)`。
- **端口监听检查**： `netstat -tuln | grep 5901 # 预期输出：tcp6 0 0 :::5901 :::* LISTEN`

------

### **二、Xvnc-session**

#### 1. **修复Xvnc-session脚本**

- **步骤1：备份并修改脚本** `sudo mv /etc/X11/Xvnc-session /etc/X11/Xvnc-session.bak sudo tee /etc/X11/Xvnc-session <<EOF #!/bin/sh unset SESSION_MANAGER unset DBUS_SESSION_BUS_ADDRESS export XKL_XMODMAP_DISABLE=1 export SHELL=/bin/bash [ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources exec startxfce4  # 改用XFCE轻量桌面 vncconfig -iconic & EOF`**关键修改**：替换GNOME为XFCE桌面，并禁用会话管理器。
- **步骤2：赋予执行权限** `sudo chmod +x /etc/X11/Xvnc-session`

#### 2. **安装轻量级桌面环境**

- **安装XFCE** `sudo apt install xfce4 xfce4-goodies`
- **验证xstartup文件** 确保用户目录下的`.vnc/xstartup`文件包含： `#!/bin/sh unset SESSION_MANAGER unset DBUS_SESSION_BUS_ADDRESS exec startxfce4`赋予权限： `chmod +x ~/.vnc/xstartup`

#### 3. **修复字体与依赖库**

- **安装必要字体包** `sudo apt install xfonts-75dpi xfonts-100dpi xfonts-base sudo ln -s /usr/share/fonts/X11 /usr/X11R6/lib/X11/fonts  # 创建字体软链接[2,12](@ref)`
- **安装缺失的共享库** `sudo apt install pixman-1 pixman-1-dev libxfont2  # 解决symbol lookup error[7,13](@ref)`

#### 4. **重建VNC服务配置**

- **编辑systemd服务文件** `sudo systemctl edit vncserver@:1.service`确保配置如下（替换`vncuser`）： `[Service] Type=forking User=vncuser Group=vncuser ExecStart=/usr/bin/vncserver :1 -geometry 1920x1080 -localhost no ExecStop=/usr/bin/vncserver -kill :1 Environment=DISPLAY=:1`
- **重载并重启服务** `sudo systemctl daemon-reload sudo systemctl restart vncserver@:1.service`