#!/bin/sh

# Mounting the host's network statistics directory (/sys/class/net/eth0/statistics) 
# as a read-only volume inside the container at /mnt/eth0.

# "ash-stats" arguments:
# - "5": Specifies the interval (in seconds) for collecting statistics.
# - "json": Specifies the output format for the statistics.
# - "--network-path /mnt/eth0": Points to the mounted directory inside the container 
#   where the network statistics are located.


docker run --rm -v /sys/class/net/eth0/statistics:/mnt/eth0:ro --name ash-stats cyaque/ash-stats 5 json --network-path /mnt/eth0