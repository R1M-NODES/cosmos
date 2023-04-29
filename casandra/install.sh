#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/utils/master/common.sh)

printLogo

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/ports.sh) && sleep 1
export -f selectPortSet && selectPortSet

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="cascadia_6102-1"
CHAIN_DENOM="aCC"
BINARY_NAME="cascadiad"
BINARY_VERSION_TAG="v0.1.1"
CHEAT_SHEET="https://nodes.r1m-team.com/casandra"

printDelimiter
echo -e "Node moniker:       $NODE_MONIKER"
echo -e "Chain id:           $CHAIN_ID"
echo -e "Chain demon:        $CHAIN_DENOM"
echo -e "Binary version tag: $BINARY_VERSION_TAG"
printDelimiter && sleep 1

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/dependencies.sh)

echo "" && printGreen "Building binaries..." && sleep 1


cd $HOME || return
rm -rf cascadia
git clone https://github.com/cascadiafoundation/cascadia
cd $HOME/cascadia || return
git checkout v0.1.1
make install
cascadiad version # v0.1.1

cascadiad config keyring-backend os
cascadiad config chain-id $CHAIN_ID
cascadiad init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s https://snapshots-testnet.stake-town.com/cascadia/genesis.json > $HOME/.cascadiad/config/genesis.json
curl -s https://snapshots-testnet.stake-town.com/cascadia//addrbook.json > $HOME/.cascadiad/config/addrbook.json

CONFIG_TOML=$HOME/.cascadiad/config/config.toml
PEERS="b651ea2a0517e82c1a476e25966ab3de3159afe8@34.229.22.39:26656,3b389873f999763d3f937f63f765f0948411e296@44.192.85.92:26656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_TOML
SEEDS=""
sed -i.bak -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $CONFIG_TOML

APP_TOML=$HOME/.cascadiad/config/app.toml
sed -i 's|^pruning *=.*|pruning = "custom"|g' $APP_TOML
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $APP_TOML
sed -i 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|g' $APP_TOML
sed -i 's|^pruning-interval *=.*|pruning-interval = "19"|g' $APP_TOML
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $CONFIG_TOML
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $CONFIG_TOML
sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.0025aCC"|g' $APP_TOML

# Customize ports
CLIENT_TOML=$HOME/.cascadiad/config/client.toml
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):$PORT_PPROF_LADDR\"/" $CONFIG_TOML
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:$PORT_PROXY_APP\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:$PORT_RPC\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:$PORT_P2P\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:$PORT_PPROF_LADDR\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":$PORT_PROMETHEUS\"%" $CONFIG_TOML && \
sed -i.bak -e "s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:$PORT_GRPC\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:$PORT_GRPC_WEB\"%; s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:$PORT_API\"%" $APP_TOML && \
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:$PORT_RPC\"%" $CLIENT_TOML

printGreen "Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/cascadiad.service > /dev/null << EOF
[Unit]
Description=Casandra Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which cascadiad) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

cascadiad tendermint unsafe-reset-all --home $HOME/.cascadiad --keep-addr-book

# Add snapshot here
URL="https://snapshots-testnet.stake-town.com/cascadia//cascadia_6102-1_latest.tar.lz4"
curl $URL | lz4 -dc - | tar -xf - -C $HOME/.cascadiad

sudo systemctl daemon-reload
sudo systemctl enable cascadiad
sudo systemctl start cascadiad

printDelimiter
printGreen "Check logs:            sudo journalctl -u $BINARY_NAME -f -o cat"
printGreen "Check synchronization: $BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up"
printGreen "Check our cheat sheet: $CHEAT_SHEET"
printDelimiter
