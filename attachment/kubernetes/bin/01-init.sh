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
cat > /etc/security/limits.conf <<EOF
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
EOF
sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
sysctl --system
sysctl net.ipv4.ip_forward
}

function op_source(){
apt install -y -q gnupg

cat > /etc/apt/sources.list <<EOF
deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse

# kubernetes
deb [arch=amd64] https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
# docker-ce
deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu focal stable
EOF

curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | apt-key add -
curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
apt update
}

function op_package(){
apt install -y -q apt-transport-https ca-certificates curl software-properties-common tree
}

function op_kubectl(){
grep -q kubectl ~/.bashrc || cat >> ~/.bashrc <<EOF
# kubelet
which kubectl &>/dev/null && source <(kubectl completion bash)
EOF
. ~/.bashrc
}

########################################################################################
op_limits
op_swap
op_module
op_sysctl
op_source
op_package
op_kubectl

printf '\n\n ---- Completed ---- \n'
exit 0
