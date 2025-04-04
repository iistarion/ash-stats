#!/bin/sh
# Check if /host is mounted
if [ ! -d "/host" ] ; then
    HOST=""
else
    HOST="/host"
fi

if [ -z "$(ls -A /host/mnt/ 2>/dev/null)" ]; then
    MOUNT_POINTS="/"
else
    MOUNT_POINTS=$(echo /host/mnt/*/)
fi
MOUNT_DATA=""



DEFAULT_SLEEP_SEC=1
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

SLEEP_SEC_REAL=$(($SLEEP_SEC + 1))
CPU_MODEL=$(awk -F': ' '/model name/ {print $2; exit}' $HOST/proc/cpuinfo)
CPU_CORES=$(nproc)
CPU_FREQUENCY=$(grep "cpu MHz" /proc/cpuinfo | head -1)
CPU_FREQUENCY=$(echo $CPU_FREQUENCY | awk -F': ' '{print $2}')
UPTIME=$(uptime -s)
UNAME=$(uname -a)

NETWORK_PATH_RX="$NETWORK_PATH/rx_bytes"
NETWORK_PATH_TX="$NETWORK_PATH/tx_bytes"

RAM_TOTAL=$(awk '/MemTotal/ {print $2}' $HOST/proc/meminfo)
RAM_TOTAL_MB=$(echo "scale=1; $RAM_TOTAL / 1024" | bc)

ASH_STATS_VERSION=$(cat version.txt)
if [ "$OUTPUT_TYPE" = "json" ]; then
    echo "{ \"info\": { \"version\": \"$ASH_STATS_VERSION\", \"host_mount\": \"$HOST\", \"cpu_model\": \"$CPU_MODEL\", \"cpu_cores\": \"$CPU_CORES\", \"cpu_frequency\": \"$CPU_FREQUENCY\", \"ram_total\": \"$RAM_TOTAL_MB\", \"system\": \"$UNAME\", \"update_sec\": $SLEEP_SEC_REAL, \"output\": \"$OUTPUT_TYPE\", \"uptime\": \"$UPTIME\" } }"
else
    echo "VERSION: $ASH_STATS_VERSION"
    echo "CPU Model: $CPU_MODEL"
    echo "CPU Cores: $CPU_CORES"
    echo "CPU Frequency: $CPU_FREQUENCY"
    echo "Online since: $UPTIME"
    echo "System: $UNAME"
    echo "Update every: $SLEEP_SEC_REAL seconds"
    echo "Output type: $OUTPUT_TYPE"
fi

display_stats() {
    echo "=== SYSTEM MONITOR ==="
    echo "CPU Usage: $CPU_USAGE"
    echo "RAM: $RAM_USED_MB MB used of $RAM_TOTAL_MB MB"
    
    for line in $(printf "$MOUNT_DATA"); do
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
    CPU_JSON="\"cpu\": {\"usage\": $CPU_USAGE}"
    RAM_JSON="\"ram\": {\"used\": $RAM_USED_MB, \"total\": $RAM_TOTAL_MB}"
    index=0
    DISK_JSON="\"disk\": {"
    
    for line in $(printf "$MOUNT_DATA"); do
        path=$(echo "$line" | awk -F'|' '{print $1}')
        device=$(echo "$line" | awk -F'|' '{print $2}' | sed 's|\\|/|g')
        size=$(echo "$line" | awk -F'|' '{print $3}')
        used=$(echo "$line" | awk -F'|' '{print $4}')
        avail=$(echo "$line" | awk -F'|' '{print $5}')

        if [ $index -gt 0 ]; then
            DISK_JSON="${DISK_JSON},"
        fi

        DISK_JSON="${DISK_JSON}\"disk_${index}_used\": $used, \"disk_${index}_total\": $size, \"disk_${index}_device\": \"$device\", \"disk_${index}_path\": \"$path\""
        index=$((index + 1))
    done
    DISK_JSON="${DISK_JSON}}"
    
    NETWORK_JSON="\"network\": {\"download\": $RX_RATE, \"upload\": $TX_RATE}"

    echo "{ $CPU_JSON, $RAM_JSON, $DISK_JSON, $NETWORK_JSON }"
}

collect_mount_data() {
    local mount_data=""
    for path in $MOUNT_POINTS; do
        df_output=$(df -T "$path" 2>/dev/null | awk 'NR==2')
        device=$(echo "$df_output" | awk '{print $1}')
        size=$(echo "$df_output" | awk '{print $3}')
        used=$(echo "$df_output" | awk '{print $4}')
        avail=$(echo "$df_output" | awk '{print $5}')
        
        mount_data="${mount_data}${path}|${device}|${size}|${used}|${avail}\n"
    done
    echo "$mount_data"
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

    #Cpu Reading 1
    read cpu user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 guest1 guest_nice1 < /proc/stat
    TOTAL1=$(( user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1 ))

    # Network Traffic (RX/TX Rate)
    collect_network_data

    # Cpu Reading 2
    read cpu user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 guest2 guest_nice2 < /proc/stat
    TOTAL2=$(( user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2 ))
    DIFF_TOTAL=$(( TOTAL2 - TOTAL1 ))
    DIFF_IDLE=$(( idle2 - idle1 ))

    # CPU usage = (total difference - idle difference) * 100 / total difference
    if [ $DIFF_TOTAL -gt 0 ]; then
        CPU_USAGE=$(awk -v dtotal="$DIFF_TOTAL" -v didle="$DIFF_IDLE" 'BEGIN { printf "%.2f", ((dtotal - didle) * 100) / dtotal }')
    else
        CPU_USAGE="0.00"
    fi

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

