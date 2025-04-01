#!/bin/sh

# Mounting the host's network statistics directory (/sys/class/net/eth0/statistics) 
# as a read-only volume inside the container at /mnt/eth0.

# "ash-stats" arguments:
# - "5": Specifies the interval (in seconds) for collecting statistics.
# - "json": Specifies the output format for the statistics.
# - "--network-path /mnt/eth0": Points to the mounted directory inside the container 
#   where the network statistics are located.

# Get the content of version.txt
$VERSION = Get-Content version.txt

# Run the Docker container
docker run --rm --name ash-stats `
    -v /sys/class/net/eth0/statistics:/host/eth0:ro `
    -v /dev:/host/dev:ro `
    cyaque/ash-stats:$VERSION 5 json --network-path /host/eth0
