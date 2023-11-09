#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/utils/master/common.sh)

printLogo

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/ports.sh) && sleep 1
export -f selectPortSet && selectPortSet

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="mantrachain-testnet-1"
CHAIN_DENOM="uaum"
BINARY_NAME="mantrachaind"
BINARY_VERSION_TAG="1.0.0"
CHEAT_SHEET="https://r1m.team/mantra-services"

printDelimiter
echo -e "Node moniker:       $NODE_MONIKER"
echo -e "Chain id:           $CHAIN_ID"
echo -e "Chain demon:        $CHAIN_DENOM"
echo -e "Binary version tag: $BINARY_VERSION_TAG"
printDelimiter && sleep 1

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/dependencies.sh)

echo "" && printGreen "Building binaries..." && sleep 1

wget https://snapshots-testnet.stake-town.com/mantra/mantrachaind-linux-amd64.zip
unzip mantrachaind-linux-amd64.zip -d $HOME/go/bin/

sudo wget -P /usr/lib https://github.com/CosmWasm/wasmvm/releases/download/v1.3.0/libwasmvm.x86_64.so

mantrachaind config keyring-backend os
mantrachaind config chain-id $CHAIN_ID
mantrachaind init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s https://snapshots-testnet.stake-town.com/mantra/genesis.json > $HOME/.mantrachain/config/genesis.json
curl -s https://snapshots-testnet.stake-town.com/mantra/addrbook.json > $HOME/.mantrachain/config/addrbook.json

CONFIG_TOML=$HOME/.mantrachain/config/config.toml
PEERS="dc0e4f03c75caf3c19474ffbead6f71ba37d96f8@35.192.223.187:26656,eaeb4872c88fa5d3a3fea9deb93cecb552dbe7a3@65.109.65.248:47656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_TOML
SEEDS=""
sed -i.bak -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $CONFIG_TOML

APP_TOML=$HOME/.mantrachain/config/app.toml
sed -i 's|^pruning *=.*|pruning = "custom"|g' $APP_TOML
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $APP_TOML
sed -i 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|g' $APP_TOML
sed -i 's|^pruning-interval *=.*|pruning-interval = "19"|g' $APP_TOML
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $CONFIG_TOML
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $CONFIG_TOML
sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.0002uaum"|g' $APP_TOML

# Customize ports
CLIENT_TOML=$HOME/.mantrachain/config/client.toml
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):$PORT_PPROF_LADDR\"/" $CONFIG_TOML
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:$PORT_PROXY_APP\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:$PORT_RPC\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:$PORT_P2P\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:$PORT_PPROF_LADDR\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":$PORT_PROMETHEUS\"%" $CONFIG_TOML && \
sed -i.bak -e "s%^address = \"localhost:9090\"%address = \"0.0.0.0:$PORT_GRPC\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:$PORT_GRPC_WEB\"%; s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:$PORT_API\"%" $APP_TOML && \
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:$PORT_RPC\"%" $CLIENT_TOML

printGreen "Install and configure cosmovisor..." && sleep 1

go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.4.0
mkdir -p ~/.mantrachain/cosmovisor/genesis/bin
mkdir -p ~/.mantrachain/cosmovisor/upgrades
cp ~/go/bin/mantrachaind ~/.mantrachain/cosmovisor/genesis/bin

printGreen "Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/mantrachaind.service > /dev/null << EOF
[Unit]
Description=Mantra Chain Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=3
LimitNOFILE=10000
Environment="DAEMON_NAME=mantrachaind"
Environment="DAEMON_HOME=$HOME/.mantrachain"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"
Environment="UNSAFE_SKIP_BACKUP=true"
[Install]
WantedBy=multi-user.target
EOF

mantrachaind tendermint unsafe-reset-all --home $HOME/.mantrachain --keep-addr-book

# Add snapshot here
URL="https://snapshots-testnet.stake-town.com/mantra/mantrachain-testnet-1_latest.tar.lz4"
curl -L $URL | lz4 -dc - | tar -xf - -C $HOME/.mantrachain
[[ -f $HOME/.mantrachain/data/upgrade-info.json ]]  && cp $HOME/.mantrachain/data/upgrade-info.json $HOME/.mantrachain/cosmovisor/genesis/upgrade-info.json

sudo systemctl daemon-reload
sudo systemctl enable mantrachaind
sudo systemctl start mantrachaind

printDelimiter
printGreen "Check logs:            sudo journalctl -u $BINARY_NAME -f -o cat"
printGreen "Check synchronization: $BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up"
printGreen "Check our cheat sheet: $CHEAT_SHEET"
printDelimiter
