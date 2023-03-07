#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/common.sh)

printLogo

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="nibiru-itn-1"
CHAIN_DENOM="unibi"
BINARY_NAME="nibid"
BINARY_VERSION_TAG="v0.19.2"
CHEAT_SHEET=""

printDelimiter
echo -e "Node moniker:       $NODE_MONIKER"
echo -e "Chain id:           $CHAIN_ID"
echo -e "Chain demon:        $CHAIN_DENOM"
echo -e "Binary version tag: $BINARY_VERSION_TAG"
printDelimiter && sleep 1

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/dependencies.sh)

echo "Building binaries..." && sleep 1

cd $HOME || return
rm -rf nibiru
git clone https://github.com/NibiruChain/nibiru
cd $HOME/nibiru || return
git checkout v0.19.2
make install
nibid version # v0.19.2

nibid config keyring-backend os
nibid config chain-id $CHAIN_ID
nibid init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s https://rpc.itn-1.nibiru.fi/genesis | jq -r .result.genesis > $HOME/.nibid/config/genesis.json
curl -s https://snapshots2-testnet.nodejumper.io/nibiru-testnet/addrbook.json > $HOME/.nibid/config/addrbook.json

CONFIG_TOML=$HOME/.nibid/config/config.toml
PEERS=""
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_TOML
SEEDS="3f472746f46493309650e5a033076689996c8881@nibiru-testnet.rpc.kjnodes.com:39659,a431d3d1b451629a21799963d9eb10d83e261d2c@seed-1.itn-1.nibiru.fi:26656,6a78a2a5f19c93661a493ecbe69afc72b5c54117@seed-2.itn-1.nibiru.fi:26656"
sed -i.bak -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $CONFIG_TOML

APP_TOML=$HOME/.nibid/config/app.toml
sed -i 's|^pruning *=.*|pruning = "custom"|g' $APP_TOML
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "1000"|g' $APP_TOML
sed -i 's|^pruning-interval *=.*|pruning-interval = "10"|g' $APP_TOML
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):26656\"/" $CONFIG_TOML
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $CONFIG_TOML
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $CONFIG_TOML
sed -i 's|^snapshot-interval *=.*|snapshot-interval = 1000|g' $APP_TOML
sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.025unibi"|g' $APP_TOML

echo "Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/nibid.service > /dev/null << EOF
[Unit]
Description=Nibiru Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which nibid) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

nibid tendermint unsafe-reset-all --home $HOME/.nibid --keep-addr-book

# Add snapshot here
SNAP_NAME=$(curl -s https://snapshots2-testnet.nodejumper.io/nibiru-testnet/info.json | jq -r .fileName)
curl "https://snapshots2-testnet.nodejumper.io/nibiru-testnet/${SNAP_NAME}" | lz4 -dc - | tar -xf - -C $HOME/.nibid

sudo systemctl daemon-reload
sudo systemctl enable nibid
sudo systemctl start nibid

printDelimiter
echo -e "Check logs:            sudo journalctl -u $BINARY_NAME -f -o cat"
echo -e "Check synchronization: $BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up"
printDelimiter