#!/bin/bash
cd "$(dirname "$0")"

if [ -d "data/server/csgo/addons/sourcemod" ]; then
    cd data/fastdl
    git pull
    cd ../..

    cp -r data/custom/* data/server/
    cp -r data/fastdl/* data/server/csgo/
else
    #first start
    mkdir data/server
    cd data
    git clone https://github.com/QLGO/fastdl.git
    cd fastdl
    git pull
    cd ../..

    echo "Starting server for the first time. The Quake plugin will be installed on next restart"
fi

chown -R 1000:1000 data/server

docker-compose down
docker-compose up -d --force-recreate



