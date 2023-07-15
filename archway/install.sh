#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/utils/master/common.sh)

printLogo

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/ports.sh) && sleep 1
export -f selectPortSet && selectPortSet

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="archway-1"
CHAIN_DENOM="aarch"
BINARY_NAME="archwayd"
BINARY_VERSION_TAG="v1.0.1"
CHEAT_SHEET="https://nodes.r1m-team.com/archway"

printDelimiter
echo -e "Node moniker:       $NODE_MONIKER"
echo -e "Chain id:           $CHAIN_ID"
echo -e "Chain demon:        $CHAIN_DENOM"
echo -e "Binary version tag: $BINARY_VERSION_TAG"
printDelimiter && sleep 1

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/dependencies.sh)

echo "" && printGreen "Building binaries..." && sleep 1


cd $HOME || return
rm -rf archway
git clone https://github.com/archway-network/archway.git
cd archway || return
git checkout $BINARY_VERSION_TAG
make install

archwayd version # v1.0.1

archwayd config keyring-backend os
archwayd config chain-id $CHAIN_ID
archwayd init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -s https://snapshots.nodestake.top/archway/genesis.json > $HOME/.archway/config/genesis.json
curl -s https://snapshots.nodestake.top/archway/addrbook.json > $HOME/.archway/config/addrbook.json

CONFIG_TOML=$HOME/.archway/config/config.toml
PEERS="72a7b231c9a9b512b26c617f351875fdd674a1a5@63.35.183.9:26656,a0cb55dd87938cd8c6bed5a8795e594544782613@202.61.239.140:26656,c76207c41de6c80e17644b64266343c3974cb8a2@51.89.16.119:26656,6a47b42564eee3bf7d5e6fe0b0c2b8d530fab2b2@51.79.177.229:26661,0bb5727df4719c50f2efd8fbb87777413786fa69@65.109.54.222:26656,32c8f4217bc1a5fa13e61b6c7c1107a76e3798f1@104.128.62.172:26656,e3ec24b645c5131e28be8fe1ffac9322f2ca6496@51.159.98.175:16656,0eaaea39348aa6ebd0282e0dc7170b23c3588672@51.89.42.38:26656,d310efeeaea3522150142fee16bde0caf76ef545@188.40.122.98:26656,be317f639f5012fded29d3195097ad4cef4eb884@148.113.8.181:50656,ebc272824924ea1a27ea3183dd0b9ba713494f83@146.19.24.25:26946,bd9332cd0a99f5830ea457a32a56b32790f68716@135.181.58.28:27456,61d26a471cf693905ce7c31664491937221e889b@65.109.116.50:36656,3ba7bf08f00e228026177e9cdc027f6ef6eb2b39@35.232.234.58:26656,f1294dd1da4a32d06598d336318c48ea387e91b9@128.140.12.6:11556,4398bd773ac885b7365de3604eb487be10c54563@195.3.223.9:26946,294e959a584eaaa05e879912fd4152c5fa8ef970@136.243.40.12:26694,5127f00a6a8b508b8fe206d2d12d49e0625d0dc3@65.108.11.234:17656,fc5030b85b88aef75b61d6b18ae436a06001cdf3@162.19.218.142:26656,5a46d12b3dfc7f5b2481296c3b3b289bfb06fdcf@94.250.203.6:21656,b96b188c049814c0c848d285ebbfa5af77396387@65.108.238.219:11556,ec8c242651733a553fecee53011abada2a54a730@141.94.193.28:42656,a0f159294571f4cac529be11c0c9b3deca5fc6b5@65.108.6.45:56656,46f748608bb01809f3d915ccb24a03866d59a5bf@51.89.7.236:26662,666d7be0f944d02d08debf9e25d6084ad4edf7c8@34.66.169.221:26656,09cd985b8a747bae279f16b72ccdc5cba659a13a@159.69.184.48:26656,93750f4d48cfd8306307f968843f4ade0e7c4b95@35.224.91.64:26656,f1b210360e2df8242cbbd9a54662abfd1d6a9faf@136.243.67.189:11556,9f79f70679318acf1baef1917c741b4886ae2c82@37.187.144.187:29656,f1d0c2cf4ba42e3ce725cc8e7acde309c7f1643c@35.193.197.39:26656,964e38899d4cfdeb7dbfa5af778416d934f09284@65.108.238.166:11556,c342901b991fe4ce5d37b324e7db2b20f24ca68c@34.72.199.104:26656,aa70d60e3c94780d7362b2c2216cd1db9596ab8f@5.181.190.135:26656,bdc28ade9835f8baaa6048f66c5983dea1469625@65.108.77.106:27049,ae3ec5da5e90a2544307bc1dc4b8dfc4b14402a1@34.133.216.95:26656,7527ac22ed20e4e136d0d045202e31364b2453b2@211.216.47.217:26656,c5cda2b6059cd707da94ca3ea84e4c35b8f6e4a2@65.109.32.148:26796,2002511bf221798f07a8077e9d46442dbb2d44b9@185.188.249.46:15656,4cb619bf7aad1da2dea6a929904f810bc057f467@194.36.145.127:26656,11caf374b721c681a577d12f3f76efcace46d133@188.166.74.9:26656,4725bdd693175d4bc1e65782b2d62ee6026a5136@5.9.106.214:20156,5380c6a4f7c39efec373a55f98fb4022355d4be2@107.135.15.67:26756,3bc337e84829c066cb1f8f89a1c96334b3abc700@162.55.1.176:26656,68cac650b02d5f62fa1365cff979da7977abea26@65.109.33.48:26656,aaec8e923b77b9e2f79a9cecfeb77a9dfea2dacf@141.94.139.219:26656,17c579988684ca167be22c59a0719715cb038422@5.9.100.26:3000,996a4e60bea02401787178cac264fddf23301921@65.109.20.54:11556,0d5f59e3ee58d7ec16fa68a69d7645f9b2b6fc36@195.154.94.166:28572,a61ded98a0cc22c3dd18db1f7de256ed759edb44@103.234.71.245:26656,e7327dbbea09c8bea987e04a664b29f0078c6577@162.19.69.49:51656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_TOML
SEEDS=""
sed -i.bak -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $CONFIG_TOML

APP_TOML=$HOME/.archway/config/app.toml
sed -i 's|^pruning *=.*|pruning = "custom"|g' $APP_TOML
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $APP_TOML
sed -i 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|g' $APP_TOML
sed -i 's|^pruning-interval *=.*|pruning-interval = "19"|g' $APP_TOML
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $CONFIG_TOML
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $CONFIG_TOML
sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0aconst"|g' $APP_TOML

# Customize ports
CLIENT_TOML=$HOME/.archway/config/client.toml
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):$PORT_PPROF_LADDR\"/" $CONFIG_TOML
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:$PORT_PROXY_APP\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:$PORT_RPC\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:$PORT_P2P\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:$PORT_PPROF_LADDR\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":$PORT_PROMETHEUS\"%" $CONFIG_TOML && \
sed -i.bak -e "s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:$PORT_GRPC\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:$PORT_GRPC_WEB\"%; s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:$PORT_API\"%" $APP_TOML && \
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:$PORT_RPC\"%" $CLIENT_TOML

printGreen "Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/archwayd.service > /dev/null <<EOF
[Unit]
Description=archwayd Daemon
After=network-online.target
[Service]
User=$USER
ExecStart=$(which archwayd) start
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

archwayd tendermint unsafe-reset-all --home $HOME/.archway --keep-addr-book

# Add snapshot here
SNAP_NAME=$(curl -s https://snapshots.nodestake.top/archway/ | egrep -o ">20.*\.tar.lz4" | tr -d ">")
curl -o - -L https://snapshots.nodestake.top/archway/${SNAP_NAME}  | lz4 -c -d - | tar -x -C $HOME/.archway

sudo systemctl daemon-reload
sudo systemctl enable archwayd
sudo systemctl start archwayd

printDelimiter
printGreen "Check logs:            sudo journalctl -u $BINARY_NAME -f -o cat"
printGreen "Check synchronization: $BINARY_NAME status 2>&1 | jq .SyncInfo.catching_up"
printGreen "Check our cheat sheet: $CHEAT_SHEET"
printDelimiter
