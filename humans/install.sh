#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/utils/master/common.sh)

printLogo

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/ports.sh) && sleep 1
export -f selectPortSet && selectPortSet

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="humans_1089-1"
CHAIN_DENOM="aHEART"
BINARY_NAME="humansd"
BINARY_VERSION_TAG="v1.0.0"
CHEAT_SHEET="https://r1m.team/humans/"

printDelimiter
echo -e "Node moniker:       $NODE_MONIKER"
echo -e "Chain id:           $CHAIN_ID"
echo -e "Chain demon:        $CHAIN_DENOM"
echo -e "Binary version tag: $BINARY_VERSION_TAG"
printDelimiter && sleep 1

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/dependencies.sh)

echo "" && printGreen "Building binaries..." && sleep 1


cd $HOME || return
rm -rf humans
git clone https://github.com/humansdotai/humans.git
cd $HOME/humans || return
git checkout $BINARY_VERSION_TAG

make install

humansd config keyring-backend os
humansd config chain-id $CHAIN_ID
humansd init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s https://snapshots.kjnodes.com/humans/genesis.json > $HOME/.humansd/config/genesis.json
curl -s https://snapshots.kjnodes.com/humans/addrbook.json > $HOME/.humansd/config/addrbook.json

CONFIG_TOML=$HOME/.humansd/config/config.toml
PEERS=""
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_TOML
SEEDS="400f3d9e30b69e78a7fb891f60d76fa3c73f0ecc@humans.rpc.kjnodes.com:12259"
sed -i.bak -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $CONFIG_TOML

APP_TOML=$HOME/.humansd/config/app.toml
sed -i 's|^create_empty_blocks *=.*|create_empty_blocks = false|' $APP_TOML
sed -i 's|^prometheus-retention-time *=.*|prometheus-retention-time = 1000000000000|' $APP_TOML
sed -i 's|^enabled *=.*|enabled = true|' $APP_TOML
sed -i '/^\[api\]$/,/^\[/ s/enable = false/enable = true/' $APP_TOML
sed -i 's|^swagger *=.*|swagger = true|' $APP_TOML
sed -i 's|^max-open-connections *=.*|max-open-connections = 100|' $APP_TOML
sed -i 's|^rpc-read-timeout *=.*|rpc-read-timeout = 5|' $APP_TOML
sed -i 's|^rpc-write-timeout *=.*|rpc-write-timeout = 3|' $APP_TOML
sed -i 's|^rpc-max-body-bytes *=.*|rpc-max-body-bytes = 1000000|' $APP_TOML
sed -i 's|^enabled-unsafe-cors *=.*|enabled-unsafe-cors = false|' $APP_TOML
sed -i 's|^create_empty_blocks *=.*|create_empty_blocks = false|' $CONFIG_TOML
sed -i 's|^prometheus *=.*|prometheus = true|' $CONFIG_TOML
sed -i 's|^create_empty_blocks_interval *=.*|create_empty_blocks_interval = "30s"|' $CONFIG_TOML
sed -i 's|^timeout_propose *=.*|timeout_propose = "30s"|' $CONFIG_TOML
sed -i 's|^timeout_propose_delta *=.*|timeout_propose_delta = "5s"|' $CONFIG_TOML
sed -i 's|^timeout_prevote *=.*|timeout_prevote = "10s"|' $CONFIG_TOML
sed -i 's|^timeout_prevote_delta *=.*|timeout_prevote_delta = "5s"|' $CONFIG_TOML
sed -i 's|^cors_allowed_origins *=.*|cors_allowed_origins = ["*.humans.ai","*.humans.zone"]|' $CONFIG_TOML
sed -i 's|^timeout_prevote_delta *=.*|timeout_prevote_delta = "5s"|' $CONFIG_TOML

# Customize ports
CLIENT_TOML=$HOME/.humansd/config/client.toml
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):$PORT_PPROF_LADDR\"/" $CONFIG_TOML
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:$PORT_PROXY_APP\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:$PORT_RPC\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:$PORT_P2P\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:$PORT_PPROF_LADDR\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":$PORT_PROMETHEUS\"%" $CONFIG_TOML && \
sed -i.bak -e "s%^address = \"localhost:9090\"%address = \"0.0.0.0:$PORT_GRPC\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:$PORT_GRPC_WEB\"%; s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:$PORT_API\"%" $APP_TOML && \
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:$PORT_RPC\"%" $CLIENT_TOML

printGreen "Install and configure cosmovisor..." && sleep 1

go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.4.0
mkdir -p ~/.humansd/cosmovisor/genesis/bin
mkdir -p ~/.humansd/cosmovisor/upgrades
cp ~/go/bin/humansd $HOME/.humansd/cosmovisor/genesis/bin

printGreen "Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/humansd.service > /dev/null << EOF
[Unit]
Description=humans node service
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start --metrics --pruning=nothing --evm.tracer=json --minimum-gas-prices=1800000000aheart json-rpc.api eth,net,web3,miner --api.enable
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.humansd"
Environment="DAEMON_NAME=humansd"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:$HOME/.humansd/cosmovisor/current/bin"

[Install]
WantedBy=multi-user.target
EOF

humansd tendermint unsafe-reset-all --home $HOME/.humansd --keep-addr-book

# Add snapshot here
URL="https://snapshots.kjnodes.com/humans/snapshot_latest.tar.lz4"
curl $URL | lz4 -dc - | tar -xf - -C $HOME/.humansd
[[ -f $HOME/.humansd/data/upgrade-info.json ]] && cp $HOME/.humansd/data/upgrade-info.json $HOME/.humansd/cosmovisor/genesis/upgrade-info.json

sudo systemctl daemon-reload
sudo systemctl enable humansd
sudo systemctl start humansd

printDelimiter
printGreen "Check logs:            sudo journalctl -u $BINARY_NAME -f -o cat"
printGreen "Check synchronization: $BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up"
printGreen "Check our cheat sheet: $CHEAT_SHEET"
printDelimiter
