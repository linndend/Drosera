#!/bin/bash

echo "==============================="
echo     "SETUP DROSERA FULL NODE"
echo "==============================="

echo "============================================="
echo        "INSTALL DEPENDENCIES & ENV"
echo "============================================="

echo "🚀 Updating dan install dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip -y

echo "🚀 Install Docker..."
sleep 3
sudo apt update -y && sudo apt upgrade -y
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sleep 3

sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y && sudo apt upgrade -y
sleep 5
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sleep 3

echo "🚀 Install Drosera CLI..."
sleep 2
curl -L https://app.drosera.io/install | bash
export PATH="$HOME/.drosera/bin:$PATH"
sleep 5
source ~/.bashrc
droseraup

echo "🚀 Install Foundry..."
curl -L https://foundry.paradigm.xyz | bash
export PATH="$HOME/.foundry/bin:$PATH"
sleep 5
source ~/.bashrc
foundryup

echo "🚀 Install Bun..."
sleep 2
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$PATH"
source ~/.bashrc

echo "============================================="
echo                 "SETUP TRAP"
echo "============================================="

echo " Setup Trap Project..."
cd ~
mkdir -p ~/my-drosera-trap
cd ~/my-drosera-trap

read -p "🔑 Masukkan GITHUB EMAIL: " GITHUB_EMAIL 
read -p "🔑 Masukkan GITHUB USERNAME: " GITHUB_USERNAME 
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"

forge init -t drosera-network/trap-foundry-template
curl -fsSL https://bun.sh/install | bash
sleep 5
bun install
sleep 3
forge build

echo " Deploying Trap..."
read -p "🔑 Private Key EVM: " PRIVATE_KEY
DROSERA_PRIVATE_KEY="$PRIVATE_KEY" drosera apply

echo -e "\e[0;37m Login on website: \e[4;35mhttps://app.drosera.io/"
sleep 10
echo "Connect wallet burner"
sleep 10
echo "Click on Traps Owned to see your deployed Traps OR search your Trap address"
sleep 10
echo "Open your Trap on Dashboard and Click on Send Bloom Boost and deposit some Holesky ETH on it"
sleep 20
drosera dryrun

echo " Setting private trap config and whitelist operator..."
cd ~/my-drosera-trap
read -p " Operator Wallet Address: " OPERATOR_ADDRESS "
cat <<EOF >> drosera.toml
private_trap = true
whitelist = ["$OPERATOR_ADDRESS"]
EOF

DROSERA_PRIVATE_KEY="$PRIVATE_KEY" drosera apply

echo "============================================="
echo               "INSTALL OPERATOR"
echo "============================================="

echo " Install Operator CLI..."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin

echo " Registering Operator..."
drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key "$PRIVATE_KEY"

echo "============================================="
echo                "SYSTEMD SERVICE"
echo "============================================="

echo "📦 Make systemd service drosera..."
read -p "🔑 VPS Public IP Address: " VPS_IP 
read -p "🔐 ETH Private Key: " PRIVATE_KEY

sudo tee /etc/systemd/system/drosera.service > /dev/null <<EOF
[Unit]
Description=Drosera Node Service
After=network-online.target

[Service]
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path $HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \
    --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com \
    --eth-backup-rpc-url https://1rpc.io/holesky \
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \
    --eth-private-key ${PRIVATE_KEY} \
    --listen-address 0.0.0.0 \
    --network-external-p2p-address ${VPS_IP} \
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF


echo "============================================="
echo             "SETUP UFW & RUN"
echo "============================================="

echo "️ Setting firewall and open port..."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw enable
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp

echo " Running node Drosera..."
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

drosera-operator optin --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --trap-config-address

echo "✅ Setup complete!"
echo "🔍 Checking node status..."
sleep 2
journalctl -u drosera.service -f

