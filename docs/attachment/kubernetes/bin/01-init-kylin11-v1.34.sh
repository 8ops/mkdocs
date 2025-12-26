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
sed -i 's/$releasever/10/g' /etc/yum.repos.d/docker-ce.repo

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
systemctl disable bluetooth || true
systemctl disable NetworkManager || true
systemctl disable NetworkManager-dispatcher || true
systemctl disable NetworkManager-wait-online || true
systemctl disable restorecond || true
systemctl disable ModemManager || true
systemctl disable rtkit-daemon || true
systemctl disable accounts-daemon || true
systemctl disable lightdm || true
systemctl disable ukui-input-gather || true
systemctl disable upower || true
systemctl disable firewalld || true
rm -f /usr/lib/systemd/system/ctrl-alt-del.target || true
rm -f /etc/systemd/system/ctrl-alt-del.service || true
systemctl daemon-reload
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
