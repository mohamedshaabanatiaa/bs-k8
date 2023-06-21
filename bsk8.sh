#!/usr/bin/env bash
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
network_dir="/etc/cni/net.d/"
plugin_dirs= [ 
  "/opt/cni/bin/",
  "/usr/lib/cni",
]
EOM
sudo systemctl restart crio
sudo apt install -y cri-tools
sudo crictl --runtime-endpoint unix:///var/run/crio/crio.sock version
sudo crictl info
