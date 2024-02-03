#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/utils/master/common.sh)

printLogo

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/ports.sh) && sleep 1
export -f selectPortSet && selectPortSet

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="kaon-1"
CHAIN_DENOM="tkyve"
BINARY_NAME="kyved"
BINARY_VERSION_TAG=v1.0.0-rc1
CHEAT_SHEET=""

printDelimiter
echo -e "Node moniker:       $NODE_MONIKER"
echo -e "Chain id:           $CHAIN_ID"
echo -e "Chain demon:        $CHAIN_DENOM"
echo -e "Binary version tag: $BINARY_VERSION_TAG"
printDelimiter && sleep 1

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/dependencies.sh)

echo "" && printGreen "Building binaries..." && sleep 1

cd $HOME || return
rm -rf kyve

wget https://github.com/KYVENetwork/chain/releases/download/v1.0.0-rc1/kyved_linux_amd64.tar.gz
tar -xvzf kyved_linux_amd64.tar.gz
chmod +x ./kyved
mv kyved $HOME/go/bin/
rm kyved_linux_amd64.tar.gz
sudo mkdir -p $HOME/go/bin/
sudo mv kyved $HOME/go/bin/

# kyved config keyring-backend os
kyved config chain-id $CHAIN_ID
kyved init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl https://raw.githubusercontent.com/KYVENetwork/networks/main/kaon-1/genesis.json > ~/.kyve/config/genesis.json
wget -O $HOME/.kyve/config/addrbook.json https://files.itrocket.net/testnet/kyve/addrbook.json

CONFIG_TOML=$HOME/.kyve/config/config.toml
PEERS="664e06d2d6110c5ba93f8ecfee66f150bad981bf@kyve-testnet-peer.itrocket.net:28656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_TOML
SEEDS="de7865a2a4936fd4bb00861ed887f219d8dd73d7@kyve-testnet-seed.itrocket.net:28656"
sed -i.bak -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $CONFIG_TOML

APP_TOML=$HOME/.kyve/config/app.toml
sed -i 's|^pruning *=.*|pruning = "custom"|g' $APP_TOML
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $APP_TOML
sed -i 's|^pruning-interval *=.*|pruning-interval = "19"|g' $APP_TOML
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $CONFIG_TOML
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $CONFIG_TOML
sed -i 's|^snapshot-interval *=.*|snapshot-interval = 0|g' $APP_TOML
sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.025tkyve"|g' $APP_TOML

# Customize ports
CLIENT_TOML=$HOME/.kyve/config/client.toml
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):$PORT_PPROF_LADDR\"/" $CONFIG_TOML
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:$PORT_PROXY_APP\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:$PORT_RPC\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:$PORT_P2P\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:$PORT_PPROF_LADDR\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":$PORT_PROMETHEUS\"%" $CONFIG_TOML && \
sed -i.bak -e "s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:$PORT_GRPC\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:$PORT_GRPC_WEB\"%; s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:$PORT_API\"%" $APP_TOML && \
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:$PORT_RPC\"%" $CLIENT_TOML

printGreen "Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/kyved.service > /dev/null << EOF
[Unit]
Description=Kyve Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which kyved) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

kyved tendermint unsafe-reset-all --home $HOME/.kyve

# Add snapshot here
curl https://testnet-files.itrocket.net/kyve/snap_kyve.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.kyve

sudo systemctl daemon-reload
sudo systemctl enable kyved
sudo systemctl start kyved

sudo systemctl restart kyved && sudo journalctl -u kyved -f -o cat

printDelimiter
printGreen "Check logs:            sudo journalctl -u $BINARY_NAME -f -o cat"
printGreen "Check synchronization: $BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up"
# printGreen "Check our cheat sheet: $CHEAT_SHEET"
printDelimiter
