#!/bin/ash
display_stats() {
    echo "=== SYSTEM MONITOR ==="
    echo "CPU: $CPU_MODEL | Cores: $CPU_CORES | Usage: $CPU_USAGE"
    echo "RAM: $RAM_USED_MB MB used of $RAM_TOTAL_MB MB"
    echo "Disk: $DISK_USAGE"
    echo "I/O: Read: $DISK_READ | Write: $DISK_WRITE"
    echo "Network: Download: $RX_RATE KB/s | Upload: $TX_RATE KB/s"
}

display_stats_json() {
    CPU_JSON="\"cpu\": {\"model\": \"$CPU_MODEL\", \"cores\": $CPU_CORES, \"usage\": \"$CPU_USAGE\"}"
    RAM_JSON="\"ram\": {\"used_mb\": $RAM_USED_MB, \"total_mb\": $RAM_TOTAL_MB}"
    DISK_JSON="\"disk\": {\"usage\": \"$DISK_USAGE\", \"read\": \"$DISK_READ\", \"write\": \"$DISK_WRITE\"}"
    NETWORK_JSON="\"network\": {\"download_kb_s\": $RX_RATE, \"upload_kb_s\": $TX_RATE}"

    echo "{ $CPU_JSON, $RAM_JSON, $DISK_JSON, $NETWORK_JSON }"
}

# Default sleep time in seconds
DEFAULT_SLEEP_SEC=1

# Default output type
DEFAULT_OUTPUT_TYPE="pretty"

# Parse command line arguments
SLEEP_SEC=$DEFAULT_SLEEP_SEC
OUTPUT_TYPE=$DEFAULT_OUTPUT_TYPE

for arg in "$@"; do
    if [ "$arg" -ge 1 ] 2>/dev/null; then
        SLEEP_SEC="$arg"
    elif [ "$arg" = "json" ] || [ "$arg" = "pretty" ]; then
        OUTPUT_TYPE="$arg"
    else
        echo "Invalid argument: $arg"
        echo "Usage: $0 [SLEEP_SEC] [OUTPUT_TYPE (json|pretty*)]"
        echo "*: OUTPUT_TYPE defaults to 'pretty' if not specified."
        exit 1
    fi
done

while true; do
    # CPU Information
    CPU_MODEL=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo)
    CPU_CORES=$(nproc)
    CPU_USAGE=$(awk -v OFMT="%.2f" 'NR==1 {total=$2+$4+$5; if (total > 0) {usage=($2+$4)*100/total; print usage "%"} else {print "0.00%"}}' < /proc/stat)

    # RAM Information
    RAM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    RAM_AVAILABLE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    RAM_USED=$((RAM_TOTAL - RAM_AVAILABLE))
    RAM_TOTAL_MB=$(echo "scale=1; $RAM_TOTAL / 1024" | bc)
    RAM_USED_MB=$(echo "scale=1; $RAM_USED / 1024" | bc)

    # Disk Information
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
    DISK_READ=$(iostat -dk 1 2 | awk 'NR==4 {print $6}')
    DISK_WRITE=$(iostat -dk 1 2 | awk 'NR==4 {print $10}')

    # Network Traffic (RX/TX Rate)
    RX=$(cat /sys/class/net/eth0/statistics/rx_bytes)
    TX=$(cat /sys/class/net/eth0/statistics/tx_bytes)
    sleep 1
    RX2=$(cat /sys/class/net/eth0/statistics/rx_bytes)
    TX2=$(cat /sys/class/net/eth0/statistics/tx_bytes)
    RX_RATE=$(( (RX2 - RX) / 1024 ))
    TX_RATE=$(( (TX2 - TX) / 1024 ))


    if [ "$OUTPUT_TYPE" = "json" ]; then
        display_stats_json
    else
        display_stats
    fi

    sleep "$SLEEP_SEC"
done

