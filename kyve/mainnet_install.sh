#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/utils/master/common.sh)

printLogo

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/ports.sh) && sleep 1
export -f selectPortSet && selectPortSet

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="kyve-1"
CHAIN_DENOM="ukyve"
BINARY_NAME="kyved"
BINARY_VERSION_TAG="v2.1.0"
CHEAT_SHEET="https://r1m.team/kyve-mainnet-services/"

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
git clone https://github.com/KYVENetwork/chain.git kyve
cd kyve || return
git checkout $BINARY_VERSION_TAG

make install ENV=mainnet

kyved config set client keyring-backend os
kyved config set client chain-id "$CHAIN_ID"
kyved init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s https://snapshots-1.stake-town.com/kyve/genesis.json > $HOME/.kyve/config/genesis.json
curl -s https://snapshots-1.stake-town.com/kyve/addrbook.json > $HOME/.kyve/config/addrbook.json

CONFIG_TOML=$HOME/.kyve/config/config.toml
PEERS=""
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_TOML
SEEDS="ade4d8bc8cbe014af6ebdf3cb7b1e9ad36f412c0@seeds.polkachu.com:11056"
sed -i.bak -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $CONFIG_TOML

APP_TOML=$HOME/.kyve/config/app.toml
sed -i 's|^pruning *=.*|pruning = "custom"|g' $APP_TOML
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $APP_TOML
sed -i 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|g' $APP_TOML
sed -i 's|^pruning-interval *=.*|pruning-interval = "19"|g' $APP_TOML
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $CONFIG_TOML
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $CONFIG_TOML
sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.001ukyve"|g' $APP_TOML

# Customize ports
CLIENT_TOML=$HOME/.kyve/config/client.toml
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):$PORT_PPROF_LADDR\"/" $CONFIG_TOML
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:$PORT_PROXY_APP\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:$PORT_RPC\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:$PORT_P2P\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:$PORT_PPROF_LADDR\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":$PORT_PROMETHEUS\"%" $CONFIG_TOML &&
sed -i.bak -e "s%^address = \"localhost:9090\"%address = \"0.0.0.0:$PORT_GRPC\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:$PORT_GRPC_WEB\"%; s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:$PORT_API\"%" $APP_TOML &&
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:$PORT_RPC\"%" $CLIENT_TOML

printGreen "Install and configure cosmovisor..." && sleep 1

go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.4.0
mkdir -p ~/.kyve/cosmovisor/genesis/bin
mkdir -p ~/.kyve/cosmovisor/upgrades
cp ~/go/bin/kyved ~/.kyve/cosmovisor/genesis/bin

printGreen "Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/kyved.service >/dev/null <<EOF
[Unit]
Description=Kyve Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=3
LimitNOFILE=10000
Environment="DAEMON_NAME=kyved"
Environment="DAEMON_HOME=$HOME/.kyve"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="UNSAFE_SKIP_BACKUP=true"
[Install]
WantedBy=multi-user.target
EOF

kyved tendermint unsafe-reset-all --home $HOME/.kyve --keep-addr-book

# Add snapshot here
URL="https://snapshots-1.stake-town.com/kyve/kyve-1_latest.tar.lz4"
curl -L $URL | lz4 -dc - | tar -xf - -C $HOME/.kyve
[[ -f $HOME/.kyve/data/upgrade-info.json ]] && cp $HOME/.kyve/data/upgrade-info.json $HOME/.kyve/cosmovisor/genesis/upgrade-info.json

sudo systemctl daemon-reload
sudo systemctl enable kyved
sudo systemctl start kyved

printDelimiter
printGreen "Check logs:            sudo journalctl -u $BINARY_NAME -f -o cat"
printGreen "Check synchronization: $BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up"
printGreen "Check our cheat sheet: $CHEAT_SHEET"
printDelimiter
