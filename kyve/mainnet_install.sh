#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/utils/master/common.sh)

printLogo

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/ports.sh) && sleep 1
export -f selectPortSet && selectPortSet

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="kyve-1"
CHAIN_DENOM="uKYVE"
BINARY_NAME="kyved"
BINARY_VERSION_TAG="v1.4.0"
CHEAT_SHEET="https://r1m.team/kyve"

printDelimiter
echo -e "Node moniker:       $NODE_MONIKER"
echo -e "Chain id:           $CHAIN_ID"
echo -e "Chain demon:        $CHAIN_DENOM"
echo -e "Binary version tag: $BINARY_VERSION_TAG"
printDelimiter && sleep 1

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/dependencies.sh)

echo "" && printGreen "Building binaries..." && sleep 1

cd $HOME || return
rm -rf chain
git clone https://github.com/KYVENetwork/chain.git
cd chain
git checkout $BINARY_VERSION_TAG
make install
kyved version

kyved config keyring-backend os
kyved config chain-id $CHAIN_ID
kyved init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s hhttps://ss.kyve.nodestake.top/genesis.json > $HOME/.kyve/config/genesis.json
curl -s https://ss.kyve.nodestake.top/addrbook.json > $HOME/.kyve/config/addrbook.json

CONFIG_TOML=$HOME/.kyve/config/config.toml
PEERS=""
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_TOML
SEEDS="87d0dbb4844cf353d218e49aa57cb47e4fd6b8e0@rpc.kyve.nodestake.top:666"
sed -i.bak -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $CONFIG_TOML

APP_TOML=$HOME/.kyve/config/app.toml
sed -i 's|^pruning *=.*|pruning = "nothing"|g' $APP_TOML
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $CONFIG_TOML
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $CONFIG_TOML
sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.025unls"|g' $APP_TOML

# Customize ports
CLIENT_TOML=$HOME/.kyve/config/client.toml
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):$PORT_PPROF_LADDR\"/" $CONFIG_TOML
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:$PORT_PROXY_APP\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:$PORT_RPC\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:$PORT_P2P\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:$PORT_PPROF_LADDR\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":$PORT_PROMETHEUS\"%" $CONFIG_TOML && \
sed -i.bak -e "s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:$PORT_GRPC\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:$PORT_GRPC_WEB\"%; s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:$PORT_API\"%" $APP_TOML && \
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:$PORT_RPC\"%" $CLIENT_TOML

printGreen "Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/kyved.service > /dev/null <<EOF
[Unit]
Description=kyved Daemon
After=network-online.target
[Service]
User=$USER
ExecStart=$(which kyved) start
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

kyved tendermint unsafe-reset-all --home $HOME/.kyve --keep-addr-book

# Add snapshot here
URL="https://s3.imperator.co/mainnets-snapshots/kyve/kyve_4565442.tar.lz4"
curl $URL | lz4 -dc - | tar -xf - -C $HOME/.kyve

sudo systemctl daemon-reload
sudo systemctl enable kyved
sudo systemctl start kyved

printDelimiter
printGreen "Check logs:            sudo journalctl -u nolusd -f -o cat"
printGreen "Check synchronization: $BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up"
printGreen "Check our cheat sheet: $CHEAT_SHEET"
printDelimiter
