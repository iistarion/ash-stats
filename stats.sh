#!/bin/sh

# Check if /host is mounted
if [ ! -d "/host/proc" ] || [ ! -d "/host/sys" ]; then
    echo "/host mount is missing or inaccessible, reading container stats."
    HOST=""
else
    HOST="/host"
fi
ASH_STATS_VERSION=$(cat version.txt)
ASH_STATS_VERSION_JSON="{ \"ash_stats_version\": \"$ASH_STATS_VERSION\" }"
echo "$ASH_STATS_VERSION_JSON"

display_stats() {
    echo "=== SYSTEM MONITOR ==="
    echo "CPU: $CPU_MODEL | Cores: $CPU_CORES | Usage: $CPU_USAGE"
    echo "RAM: $RAM_USED_MB MB used of $RAM_TOTAL_MB MB"
    for line in $(echo -e "$MOUNT_DATA"); do
        path=$(echo "$line" | awk -F'|' '{print $1}')
        device=$(echo "$line" | awk -F'|' '{print $2}')
        size=$(echo "$line" | awk -F'|' '{print $3}')
        used=$(echo "$line" | awk -F'|' '{print $4}')
        avail=$(echo "$line" | awk -F'|' '{print $5}')

        echo "Disk $device ($path): Used $used of $size (Available: $avail)"
    done
    echo "Network: Download: $RX_RATE KB/s | Upload: $TX_RATE KB/s"
}

display_stats_json() {
    CPU_JSON="\"cpu\": {\"model\": \"$CPU_MODEL\", \"cores\": $CPU_CORES, \"usage\": $CPU_USAGE}"
    RAM_JSON="\"ram\": {\"used\": $RAM_USED_MB, \"total\": $RAM_TOTAL_MB}"
    DISK_JSON="\"disks\":["
    first=true
    for line in $(echo -e "$MOUNT_DATA"); do
        path=$(echo "$line" | awk -F'|' '{print $1}')
        device=$(echo "$line" | awk -F'|' '{print $2}')
        size=$(echo "$line" | awk -F'|' '{print $3}')
        used=$(echo "$line" | awk -F'|' '{print $4}')
        avail=$(echo "$line" | awk -F'|' '{print $5}')

        if [ "$first" = true ]; then
            first=false
        else
            DISK_JSON="${DISK_JSON},"
        fi

        DISK_JSON="${DISK_JSON}{\"used\": $used, \"total\": $size, \"device\": \"$device\", \"path\": \"$path\"}"
    done
    DISK_JSON="${DISK_JSON}]"
    
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
        [2-9]*|[1-9][0-9]*)
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

CPU_MODEL=$(awk -F': ' '/model name/ {print $2; exit}' $HOST/proc/cpuinfo)
CPU_CORES=$(nproc)

RAM_TOTAL=$(awk '/MemTotal/ {print $2}' $HOST/proc/meminfo)
RAM_TOTAL_MB=$(echo "scale=1; $RAM_TOTAL / 1024" | bc)

#!/bin/sh
if [ -z "$(ls -A /mnt/ 2>/dev/null)" ]; then
    MOUNT_POINTS="/"
else
    MOUNT_POINTS=$(echo /mnt/*/)
fi
MOUNT_DATA=""

collect_mount_data() {
    local mount_data=""
    for path in $MOUNT_POINTS; do
        device=$(df -T "$path" 2>/dev/null | awk 'NR==2 {print $1}')
        size=$(df -T "$path" 2>/dev/null | awk 'NR==2 {print $3}')
        used=$(df -T "$path" 2>/dev/null | awk 'NR==2 {print $4}')
        avail=$(df -T "$path" 2>/dev/null | awk 'NR==2 {print $5}')
        
        mount_data="${mount_data}${path}|${device}|${size}|${used}|${avail}\n"
    done
    echo -e "$mount_data"
}
MOUNT_DATA=$(collect_mount_data)

collect_network_data() {
    RX=$(cat $NETWORK_PATH_RX)
    TX=$(cat $NETWORK_PATH_TX)
    sleep 1
    RX2=$(cat $NETWORK_PATH_RX)
    TX2=$(cat $NETWORK_PATH_TX)
    RX_RATE=$(( (RX2 - RX) / 1024 ))
    TX_RATE=$(( (TX2 - TX) / 1024 ))
}

while true; do
    sleep "$SLEEP_SEC"

    # Network Traffic (RX/TX Rate)
    collect_network_data

    # CPU Information
    CPU_USAGE=$(awk -v OFMT="%.2f" 'NR==1 {total=$2+$4+$5; if (total > 0) {usage=($2+$4)*100/total; print usage} else {print 0.00}}' < $HOST/proc/stat)

    # RAM Information
    RAM_AVAILABLE=$(awk '/MemAvailable/ {print $2}' $HOST/proc/meminfo)
    RAM_USED=$((RAM_TOTAL - RAM_AVAILABLE))
    RAM_USED_MB=$(echo "scale=1; $RAM_USED / 1024" | bc)

    # Disk Information
    MOUNT_DATA=$(collect_mount_data)

    # Print
    if [ "$OUTPUT_TYPE" = "json" ]; then
        display_stats_json
    else
        display_stats
    fi
done

