#!/bin/bash

########################################################################################
# 
# kubernetes env init
# curl -s https://books.8ops.top/attachment/kubernetes/0-init.sh | bash
# 
# @8ops 
# 
########################################################################################

function op_limits(){
cat > /etc/security/limits.d/kubernetes <<EOF
*        soft     nproc          655350 
*        hard     nproc          655350
*        soft     nofile         655350
*        hard     nofile         655350
root     soft     nproc          655350
root     hard     nproc          655350 
root     soft     nofile         655350
root     hard     nofile         655350
EOF
ulimit -SHn 655350
}

function op_swap(){
swapoff -a
sed -i '/swap/d' /etc/fstab
free -g
}

function op_module(){
cat > /etc/modules-load.d/99-containerd.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay 
modprobe br_netfilter
lsmod | grep -P "overlay|br_netfilter"
}

function op_sysctl(){
cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
vm.swappiness = 0
vm.overcommit_memory = 1
fs.inotify.max_user_watches = 1048576
EOF
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
sysctl --system
sysctl net.ipv4.ip_forward
}

function op_source(){
apt install -y -q gnupg

# # ubuntu
# cat > /etc/apt/sources.list.d/ubuntu.sources <<EOF
# Types: deb
# URIs: https://mirrors.aliyun.com/ubuntu/
# Suites: noble noble-updates noble-backports
# Components: main restricted universe multiverse
# Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
# 
# Types: deb
# URIs: http://security.ubuntu.com/ubuntu/
# Suites: noble-security
# Components: main restricted universe multiverse
# Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
# EOF

# cat > /etc/apt/sources.list <<EOF
# deb https://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ noble main restricted universe multiverse
# deb https://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ noble-security main restricted universe multiverse
# deb https://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ noble-updates main restricted universe multiverse
# # deb https://mirrors.aliyun.com/ubuntu/ noble-proposed main restricted universe multiverse
# # deb-src https://mirrors.aliyun.com/ubuntu/ noble-proposed main restricted universe multiverse
# deb https://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ noble-backports main restricted universe multiverse
# EOF

# kubernetes
export KUBE_VERSION_FOR_APT=v1.35
mkdir -p /etc/apt/keyrings
curl -kfsSL https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBE_VERSION_FOR_APT}/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://mirrors.aliyun.com/kubernetes-new/core/stable/${KUBE_VERSION_FOR_APT}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# containerd.io
apt install ca-certificates curl gnupg
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list

apt update
}

function op_package(){
apt install -y -q apt-transport-https ca-certificates curl software-properties-common tree socat vim iputils-ping
systemctl disable --now \
  plymouth-quit-wait.service \
  plymouth-quit.service \
  plymouth-read-write.service \
  plymouth-start.service \
  systemd-ask-password-wall.path \
  systemd-ask-password-plymouth.path
systemctl disable --now snapd.apparmor.service snapd.seeded.service
systemctl disable --now bluetooth.service
systemctl disable --now cups.service cups.socket
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer
systemctl disable --now systemd-resolved.service
}

function op_kubectl(){
grep -q kubectl ~/.bashrc || cat >> ~/.bashrc <<EOF
# kubelet
which kubectl &>/dev/null && source <(kubectl completion bash)
EOF
. ~/.bashrc
}

function op_kubernetes(){
# op kubelet
cat <<EOF | tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="--cgroup-driver=systemd --node-ip=$(hostname -I | awk '{print $1}')"
EOF
# disable udev
echo 'ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_FS_USAGE}!="crypto", GOTO="persistent_storage_end"' | tee /etc/udev/rules.d/99-persistent-storage.rules
echo 'LABEL="persistent_storage_end"' | tee -a /etc/udev/rules.d/99-persistent-storage.rules
udevadm control --reload-rules && udevadm trigger

}

########################################################################################
op_limits
op_swap
op_module
op_sysctl
op_source
op_package
op_kubectl
op_kubernetes

printf '\n\n ---- Completed ---- \n'
exit 0
