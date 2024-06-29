#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/utils/master/common.sh)

printLogo

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/ports.sh) && sleep 1
export -f selectPortSet && selectPortSet

read -r -p "Enter node moniker: " NODE_MONIKER

CHAIN_ID="zgtendermint_16600-2"
CHAIN_DENOM="ua0gi"
BINARY_NAME="0gchaind"
BINARY_VERSION_TAG="v0.2.3"
CHEAT_SHEET="https://r1m.team/0G/"

printDelimiter
echo -e "Node moniker:       $NODE_MONIKER"
echo -e "Chain id:           $CHAIN_ID"
echo -e "Chain demon:        $CHAIN_DENOM"
echo -e "Binary version tag: $BINARY_VERSION_TAG"
printDelimiter && sleep 1

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/cosmos/master/utils/dependencies.sh)

echo "" && printGreen "Building binaries..." && sleep 1


cd $HOME || return
rm -rf 0g-chain
git clone https://github.com/0glabs/0g-chain
cd 0g-chain || return
git checkout $BINARY_VERSION_TAG

make install

0gchaind config keyring-backend os
0gchaind config chain-id $CHAIN_ID
0gchaind init "$NODE_MONIKER" --chain-id $CHAIN_ID

curl -L https://testnet-files.itrocket.net/og/genesis.json > $HOME/.0gchain/config/genesis.json
curl -L https://testnet-files.itrocket.net/og/addrbook.json > $HOME/.0gchain/config/addrbook.json

CONFIG_TOML=$HOME/.0gchain/config/config.toml
PEERS="c76473c97fa718d1c4c48910c17318883300a36b@og-testnet-peer.itrocket.net:11656,74aec2220dd95e5373d7ee0ecd2f5b04dbbf77f0@84.247.165.200:12656,eb58130a54776a4ac25e6a5e6a863cc3b3e85cbc@178.63.20.93:12656,0c1c663b22cd5e401efeb440238a436fecc4f632@144.91.83.240:12656,5b3202f4ee36451778646317ae569df1513fdbb2@38.242.230.75:12656,81470361f57c1205c83789a1c043d44c4ad41106@184.174.38.78:12656,cfe299faebfa81a2a4191ff93c8f6136887238da@185.250.36.142:26656,46bb48ee99f5c5020af1a84e3e37a749eafbe610@88.198.56.20:26656,ffdf7a8cc6dbbd22e25b1590f61da149349bdc2e@135.181.229.206:26656,e4db7e0bd50c4aaee9fe6c40dc7226902ebc5c39@185.208.206.169:12656,42628aa178fd7ef14b00da72194aebe6f05f6785@95.216.245.48:26656,3694bd51c48dd1d688c182b86b3e28f59c6ba8ab@65.21.237.37:12656,75453d9f63ccb69a5cbee82a921e2ef803615d51@211.218.55.32:26656,579213b6d2035d6e9d8f99533aa7073762f2a8be@37.60.252.229:26656,8456adc12b10b19944c43ebe6c609154df1f1d8e@37.60.251.134:26656,3ea8a414244c866b9c7d32bf3253a35727d27ab4@164.68.104.82:12656,bb2fe5bd605cd10f50614ca0901d5838b7c72d9b@161.97.108.196:12656,bdde1603eabeed372c96f2731664fae9eb1d6906@109.123.255.114:12656,c5a40e059dcd8a41e967c569d2128ce1cc901a2c@194.163.137.167:12656,0ada3d654c01607d585793943b37335a97a56691@213.239.195.210:12656,9b99a08208d6f95ce7be1a2d4d6525fa9d6d56b4@178.18.253.71:12656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $CONFIG_TOML
SEEDS="8f21742ea5487da6e0697ba7d7b36961d3599567@og-testnet-seed.itrocket.net:47656"
sed -i.bak -e "s/^seeds =.*/seeds = \"$SEEDS\"/" $CONFIG_TOML

APP_TOML=$HOME/.0gchain/config/app.toml
sed -i 's|^pruning *=.*|pruning = "custom"|g' $APP_TOML
sed -i 's|^pruning-keep-recent  *=.*|pruning-keep-recent = "100"|g' $APP_TOML
sed -i 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|g' $APP_TOML
sed -i 's|^pruning-interval *=.*|pruning-interval = "19"|g' $APP_TOML
sed -i -e "s/^filter_peers *=.*/filter_peers = \"true\"/" $CONFIG_TOML
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $CONFIG_TOML
sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.0025ua0gi"|g' $APP_TOML

# Customize ports
CLIENT_TOML=$HOME/.0gchain/config/client.toml
sed -i.bak -e "s/^external_address *=.*/external_address = \"$(wget -qO- eth0.me):$PORT_PPROF_LADDR\"/" $CONFIG_TOML
sed -i.bak -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:$PORT_PROXY_APP\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:$PORT_RPC\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:$PORT_P2P\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:$PORT_PPROF_LADDR\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":$PORT_PROMETHEUS\"%" $CONFIG_TOML &&
sed -i.bak -e "s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:$PORT_GRPC\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:$PORT_GRPC_WEB\"%; s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:$PORT_API\"%; s%^address = \"127.0.0.1:8545\"%address = \"0.0.0.0:$PORT_EVM_RPC\"%; s%^ws-address = \"127.0.0.1:8546\"%ws-address = \"0.0.0.0:$PORT_EVM_WS\"%; s%^metrics-address = \"127.0.0.1:6065\"%metrics-address = \"0.0.0.0:$PORT_EVM_METRICS\"%" $APP_TOML && \
sed -i.bak -e "s%^node = \"tcp://localhost:26657\"%node = \"tcp://localhost:$PORT_RPC\"%" $CLIENT_TOML

# create service file
sudo tee /etc/systemd/system/0gchaind.service > /dev/null <<EOF
[Unit]
Description=0G node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.0gchain
ExecStart=$(which 0gchaind) start --home $HOME/.0gchain
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# reset and download snapshot
0gchaind tendermint unsafe-reset-all --home $HOME/.0gchain
if curl -s --head curl https://testnet-files.itrocket.net/og/snap_og.tar.lz4 | head -n 1 | grep "200" > /dev/null; then
  curl https://testnet-files.itrocket.net/og/snap_og.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.0gchain
    else
  echo no have snap
fi

# enable and start service
sudo systemctl daemon-reload
sudo systemctl enable 0gchaind
sudo systemctl restart 0gchaind && sudo journalctl -u 0gchaind -f
