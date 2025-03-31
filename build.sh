#!/bin/sh
VERSION_DATE=$(date +"%m%d")
ASH_STATS_VERSION=1.$VERSION_DATE.$1
echo "$ASH_STATS_VERSION" > version.txt

docker build -t cyaque/ash-stats:$ASH_STATS_VERSION .

if [ "$1" = 'push' ]; then
    docker tag cyaque/ash-stats:$ASH_STATS_VERSION cyaque/ash-stats:latest
    docker push cyaque/ash-stats:$ASH_STATS_VERSION
    docker push cyaque/ash-stats:latest
fi