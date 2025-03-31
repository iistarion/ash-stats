#!/bin/sh
display_stats() {
    echo "=== SYSTEM MONITOR ==="
    echo "CPU: $CPU_MODEL | Cores: $CPU_CORES | Usage: $CPU_USAGE"
    echo "RAM: $RAM_USED_MB MB used of $RAM_TOTAL_MB MB"
    echo "Disk: Used: $DISK_USED_KB KB of $DISK_TOTAL_KB KB"
    echo "I/O: Read: $DISK_READ_KB KB/s | Write: $DISK_WRITE_KB KB/s"
    echo "Network: Download: $RX_RATE KB/s | Upload: $TX_RATE KB/s"
}

display_stats_json() {
    CPU_JSON="\"cpu\": {\"model\": \"$CPU_MODEL\", \"cores\": $CPU_CORES, \"usage\": $CPU_USAGE}"
    RAM_JSON="\"ram\": {\"used\": $RAM_USED_MB, \"total\": $RAM_TOTAL_MB}"
    DISK_JSON="\"disk\": {\"used\": $DISK_USED_KB, \"total\": $DISK_TOTAL_KB, \"read\": $DISK_READ_KB, \"write\": $DISK_WRITE_KB}"
    NETWORK_JSON="\"network\": {\"download\": $RX_RATE, \"upload\": $TX_RATE}"

    echo "{ $CPU_JSON, $RAM_JSON, $DISK_JSON, $NETWORK_JSON }"
}

DEFAULT_SLEEP_SEC=2
DEFAULT_OUTPUT_TYPE="pretty"
NETWORK_PATH="/sys/class/net/eth0/statistics"

SLEEP_SEC=$DEFAULT_SLEEP_SEC
OUTPUT_TYPE=$DEFAULT_OUTPUT_TYPE

# Parse arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        [2-9]*|[1-9][0-9]*)  # If argument is a number >=2
            SLEEP_SEC=$(( $1 - 1 ))
            ;;
        json|pretty)
            OUTPUT_TYPE="$1"
            ;;
        --network-path)
            shift
            if [ -z "$1" ]; then
                echo "Error: Missing value for --network-path"
                exit 1
            fi
            NETWORK_PATH="$1"
            ;;
        *)
            echo "Invalid argument: $1"
            echo "Usage: $0 [SLEEP_SEC (minimum 2s)] [OUTPUT_TYPE (json|pretty*)] [--network-path <path>]"
            echo "* OUTPUT_TYPE defaults to 'pretty' if not specified."
            echo "Note: SLEEP_SEC must be at least 2 seconds to allow network statistics calculation."
            exit 1
            ;;
    esac
    shift
done

NETWORK_PATH_RX="$NETWORK_PATH/rx_bytes"
NETWORK_PATH_TX="$NETWORK_PATH/tx_bytes"

CPU_MODEL=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo)
CPU_CORES=$(nproc)

RAM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
RAM_TOTAL_MB=$(echo "scale=1; $RAM_TOTAL / 1024" | bc)

DISK_SPACE=$(df -P | awk 'NR>1 && $1 ~ /^\/dev\// && $1 !~ /overlay/ {used+=$3; total+=$2} END {print used,total}')
DISK_TOTAL_KB=$(echo "$DISK_SPACE" | cut -d ' ' -f 2)

while true; do
    sleep "$SLEEP_SEC"

    # CPU Information
    CPU_USAGE=$(awk -v OFMT="%.2f" 'NR==1 {total=$2+$4+$5; if (total > 0) {usage=($2+$4)*100/total; print usage} else {print 0.00}}' < /proc/stat)

    # RAM Information
    RAM_AVAILABLE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    RAM_USED=$((RAM_TOTAL - RAM_AVAILABLE))
    RAM_USED_MB=$(echo "scale=1; $RAM_USED / 1024" | bc)

    # Disk Information
    IOSTAT_OUTPUT=$(iostat -dk 1 2 | tail -n +4)
    DISK_READ_KB=$(echo "$IOSTAT_OUTPUT" | awk '$1 ~ /^sd/ {sum+=$3} END {print sum}')
    DISK_WRITE_KB=$(echo "$IOSTAT_OUTPUT" | awk '$1 ~ /^sd/ {sum+=$4} END {print sum}')
    
    # Disk Space Usage (Total and Used)
    DISK_USED_KB=$(echo "$DISK_SPACE" | cut -d ' ' -f 1)

    # Network Traffic (RX/TX Rate)
    RX=$(cat $NETWORK_PATH_RX)
    TX=$(cat $NETWORK_PATH_TX)
    sleep 1
    RX2=$(cat $NETWORK_PATH_RX)
    TX2=$(cat $NETWORK_PATH_TX)
    RX_RATE=$(( (RX2 - RX) / 1024 ))
    TX_RATE=$(( (TX2 - TX) / 1024 ))

    if [ "$OUTPUT_TYPE" = "json" ]; then
        display_stats_json
    else
        display_stats
    fi
done

