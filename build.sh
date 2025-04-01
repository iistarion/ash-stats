#!/bin/sh
VERSION_DATE=$(date +"%m%d")
if [ "$1" = 'push' ] || [ -z "$1" ] ; then
    ARG0=01
else
    ARG0="$1"
fi

ASH_STATS_VERSION=1.$VERSION_DATE.$ARG0
echo "$ASH_STATS_VERSION" > version.txt

echo "Building version: '$ASH_STATS_VERSION'"

docker build -t cyaque/ash-stats:$ASH_STATS_VERSION .

if [ "$1" = 'push' ] || [ "$2" = 'push' ]; then
    docker tag cyaque/ash-stats:$ASH_STATS_VERSION cyaque/ash-stats:latest
    docker push cyaque/ash-stats:$ASH_STATS_VERSION
    docker push cyaque/ash-stats:latest
fi