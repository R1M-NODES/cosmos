#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/utils/master/common.sh)

printLogo

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/ports.sh) && sleep 1
export -f selectPortSet && selectPortSet

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="lava-mainnet-1"
CHAIN_DENOM="ulava"
BINARY_NAME="lavad"
BINARY_VERSION_TAG="v5.3.0"
CHEAT_SHEET="https://r1m.team/lava-mainnet-services/"

printDelimiter
echo -e "Node moniker:       $NODE_MONIKER"
echo -e "Chain id:           $CHAIN_ID"
echo -e "Chain demon:        $CHAIN_DENOM"
echo -e "Binary version tag: $BINARY_VERSION_TAG"
printDelimiter && sleep 1

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/dependencies.sh)

echo "" && printGreen "Building binaries..." && sleep 1

cd $HOME || return
rm -rf lava
git clone https://github.com/lavanet/lava.git
cd $HOME/lava || return
git checkout $BINARY_VERSION_TAG

export LAVA_BINARY=lavad && make install

lavad config keyring-backend os
lavad config chain-id $CHAIN_ID
lavad init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -Ls https://snapshots-1.stake-town.com/lava/genesis.json >$HOME/.lava/config/genesis.json
curl -Ls https://snapshots-1.stake-town.com/lava/addrbook.json >$HOME/.lava/config/addrbook.json

CONFIG_TOML=$HOME/.lava/config/config.toml
PEERS=""
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_TOML
SEEDS="ade4d8bc8cbe014af6ebdf3cb7b1e9ad36f412c0@seeds.polkachu.com:19956"
sed -i.bak -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $CONFIG_TOML
sed -i 's|^timeout_propose =.*|timeout_propose = "10s"|g' $CONFIG_TOML
sed -i 's|^timeout_propose_delta =.*|timeout_propose_delta = "500ms"|g' $CONFIG_TOML
sed -i 's|^timeout_prevote =.*|timeout_prevote = "1s"|g' $CONFIG_TOML
sed -i 's|^timeout_prevote_delta =.*|timeout_prevote_delta = "500ms"|g' $CONFIG_TOML
sed -i 's|^timeout_precommit =.*|timeout_precommit = "500ms"|g' $CONFIG_TOML
sed -i 's|^timeout_precommit_delta =.*|timeout_precommit_delta = "1s"|g' $CONFIG_TOML
sed -i 's|^timeout_commit =.*|timeout_commit = "15s"|g' $CONFIG_TOML
sed -i 's|^create_empty_blocks =.*|create_empty_blocks = true|g' $CONFIG_TOML
sed -i 's|^create_empty_blocks_interval =.*|create_empty_blocks_interval = "15s"|g' $CONFIG_TOML
sed -i 's|^timeout_broadcast_tx_commit =.*|timeout_broadcast_tx_commit = "151s"|g' $CONFIG_TOML
sed -i 's|^skip_timeout_commit =.*|skip_timeout_commit = false|g' $CONFIG_TOML

APP_TOML=$HOME/.lava/config/app.toml
sed -i 's|^pruning *=.*|pruning = "custom"|g' $APP_TOML
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $APP_TOML
sed -i 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|g' $APP_TOML
sed -i 's|^pruning-interval *=.*|pruning-interval = "19"|g' $APP_TOML
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $CONFIG_TOML
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $CONFIG_TOML
sed -i -e 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.000000001ulava"|g' $APP_TOML

CLIENT_TOML=$HOME/.lava/config/client.toml
sed -i -e 's/broadcast-mode = ".*"/broadcast-mode = "sync"/g' $CLIENT_TOML

# Customize ports
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):$PORT_PPROF_LADDR\"/" $CONFIG_TOML
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:$PORT_PROXY_APP\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:$PORT_RPC\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:$PORT_P2P\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:$PORT_PPROF_LADDR\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":$PORT_PROMETHEUS\"%" $CONFIG_TOML &&
sed -i.bak -e "s%^address = \"localhost:9090\"%address = \"0.0.0.0:$PORT_GRPC\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:$PORT_GRPC_WEB\"%; s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:$PORT_API\"%" $APP_TOML &&
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:$PORT_RPC\"%" $CLIENT_TOML

printGreen "Install and configure cosmovisor..." && sleep 1

go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.4.0
mkdir -p ~/.lava/cosmovisor/genesis/bin
mkdir -p ~/.lava/cosmovisor/upgrades
cp ~/go/bin/lavad $HOME/.lava/cosmovisor/genesis/bin

printGreen "Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/lavad.service >/dev/null <<EOF
[Unit]
Description=Lava Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=3
LimitNOFILE=10000
Environment="DAEMON_NAME=lavad"
Environment="DAEMON_HOME=$HOME/.lava"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="UNSAFE_SKIP_BACKUP=true"
[Install]
WantedBy=multi-user.target
EOF

lavad tendermint unsafe-reset-all --home $HOME/.lava --keep-addr-book

# Add snapshot here
URL="https://snapshots-1.stake-town.com/lava/lava-mainnet-1_latest.tar.lz4"
curl -L $URL | tar -Ilz4 -xf - -C $HOME/.lava
[[ -f $HOME/.lava/data/upgrade-info.json ]] && cp $HOME/.lava/data/upgrade-info.json $HOME/.lava/cosmovisor/genesis/upgrade-info.json

sudo systemctl daemon-reload
sudo systemctl enable lavad
sudo systemctl start lavad

printDelimiter
printGreen "Check logs:            sudo journalctl -u $BINARY_NAME -f -o cat"
printGreen "Check synchronization: $BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up"
printDelimiter
