#!/bin/sh

TAG=$(date +"%m.%d")

docker build -t cyaque/ash-stats:1.$TAG$1 .
docker tag cyaque/ash-stats:1.$TAG$1 cyaque/ash-stats:latest

docker push cyaque/ash-stats:1.$TAG$1
docker push cyaque/ash-stats:latest