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
yum install -y yum-utils
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.34/rpm/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.34/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
}

function op_package(){
apt install -y -q apt-transport-https ca-certificates curl software-properties-common tree socat
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
# op_package
op_kubectl

printf '\n\n ---- Completed ---- \n'
exit 0
