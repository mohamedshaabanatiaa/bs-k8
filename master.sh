#!/usr/bin/env bash

########Forwarding IPv4 and letting iptables see bridged traffic 
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
# Apply sysctl params without reboot
sudo sysctl --system

#######CRIO-Install
export OS=xUbuntu_22.04
export CRIO_VERSION=1.24
sudo apt update
sudo apt install apt-transport-https ca-certificates curl gnupg2 software-properties-common -y
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /"| sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$OS/ /"|sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/$OS/Release.key | sudo apt-key add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key add -
sudo apt update
sudo apt install cri-o cri-o-runc -y
sudo systemctl start crio
sudo systemctl enable crio
sudo apt install containernetworking-plugins -y
rm /etc/crio/crio.conf
cat << EOM > /etc/crio/crio.conf
network_dir= "/etc/cni/net.d/"
plugin_dirs= [ 
  "/opt/cni/bin/",
  "/usr/lib/cni",
]
EOM
sudo systemctl restart crio
sudo apt install -y cri-tools
sudo crictl --runtime-endpoint unix:///var/run/crio/crio.sock version
sudo crictl info

######Install kubeadm kubelet kubectl
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
mkdir /etc/apt/keyrings/
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

################Run kubeadm
kubeadm init --pod-network-cidr=10.85.0.0/16 --cri-socket=unix:///var/run/crio/crio.sock
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl taint nodes $(kubectl get nodes --no-headers) node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes $(kubectl get nodes --no-headers) node-role.kubernetes.io/master:NoSchedule-

###############Intsall cilium
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
cilium install
cilium status --wait
cilium connectivity test


