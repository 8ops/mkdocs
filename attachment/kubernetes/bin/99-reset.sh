#!/bin/bash

# set -ex

# 1, reset kubernetes cluster 
printf '\n\n1, reset kubernetes cluster\n'
command -v kubeadm && kubeadm reset --force --cri-socket /run/containerd/containerd.sock
# kubeadm reset --force --cri-socket /var/run/dockershim.sock

# 2, release network
printf '\n\n2, release network\n'
ip link set dev docker0 down || /bin/true
ip link set dev flannel.1 down || /bin/true
ip link set dev cni0 down || /bin/true
ip link set dev kube-ipvs0 down || /bin/true
ip link set dev cilium_net down || /bin/true
ip link set dev cilium_host down || /bin/true
ip link set dev cilium_vxlan down || /bin/true
ip link delete docker0 || /bin/true
ip link delete flannel.1 || /bin/true
ip link delete cni0 || /bin/true
ip link delete kube-ipvs0 || /bin/true
ip link delete cilium_net || /bin/true
ip link delete cilium_host || /bin/true
ip link delete cilium_vxlan || /bin/true
ip route | awk '$0!~/proto/{printf("ip r del %s\n", $1)}' | sh

# show network device
printf '\n\n ---- show network device ---- \n'
#ip link show
ip address show
ip route show
printf '  \n ----------------------------- \n\n'

# 3, release fireward
printf '\n\n3, release fireward\n'
iptables -F && iptables -X && ipvsadm -C
iptables -t nat -F && iptables -t nat -X
iptables -t mangle -F && iptables -t mangle -X

# show iptables
printf '\n\n ---- show iptables ---- \n'
iptables -t filter -vnxL
iptables -t filter -vnxL
ipvsadm -ln
printf '  \n ----------------------- \n\n'

# crictl images | awk 'NR>1{printf("crictl rmi %s\n",$3)}' |sh

# 4, stop services
printf '\n\n4, stop services\n'
systemctl stop kubelet
systemctl stop docker
systemctl stop containerd

# 6, remove packages
printf '\n\n6, remove packages\n'

# unhold packages
printf '\n\n5, unhold packages\n'
apt-mark unhold kubeadm
apt-mark unhold kubectl
apt-mark unhold kubelet
apt-mark unhold docker
apt-mark unhold containerd

# apt-mark showhold
printf '\n\n ---- apt-mark showhold ---- \n'
apt-mark showhold
printf '  \n --------------------------- \n\n'

# remove held packages
apt remove -y --purge --allow-change-held-packages kubeadm  || /bin/true
apt remove -y --purge --allow-change-held-packages kubelet || /bin/true
apt remove -y --purge --allow-change-held-packages kubectl  || /bin/true
apt remove -y --purge --allow-change-held-packages kubernetes-cni || /bin/true
apt remove -y --purge --allow-change-held-packages containerd  || /bin/true
apt remove -y --purge --allow-change-held-packages containerd.io  || /bin/true # deprecated
apt remove -y --purge --allow-change-held-packages docker-ce  || /bin/true.    # deprecated
apt remove -y --purge --allow-change-held-packages cri-o  || /bin/true
apt remove -y --purge --allow-change-held-packages cri-o-runc || /bin/true

# release auto-remove
apt auto-remove -y

# show release packages detail
printf '\n\n ---- show release packages detail ---- \n'
dpkg -l | awk '$2~/kube|cni|cri|containerd|docker/'
printf '  \n -------------------------------------- \n\n'

# 7, release directory or files
printf '\n\n7, release directory or files\n'
[ -e /data1/lib ] && mv /data1/lib{,-$(date +%Y%m%d)}
rm -rf /etc/systemd/system/kubelet.service.d /var/lib/kubelet
rm -rf /var/lib/docker /etc/docker /run/docker /run/docker.sock /run/dockershim.sock
rm -rf /var/lib/etcd /var/lib/calico
rm -rf /opt/containerd /etc/containerd /run/containerd /var/lib/containerd
rm -rf /etc/crio/ /etc/crictl.yaml
rm -rf /opt/cni /etc/cni /var/lib/cni /run/flannel /run/cilium
rm -rf ~/.kube /etc/kubernetes
rm -rf ~/.cache/helm ~/.config/helm


printf '\n\n ---- Completed ---- \n\n'
exit 0
