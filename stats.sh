#!/bin/ash

# Default sleep time in seconds
DEFAULT_SLEEP_SEC=5

# Check for command line argument (seconds)
if [[ $# -ge 1 && $1 -ge 1 ]]; then
	SLEEP_SEC="$1"
else
	SLEEP_SEC=$DEFAULT_SLEEP_SEC
fi

while true; do
clear

# CPU Information
CPU_MODEL=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo)
CPU_CORES=$(nproc)
CPU_USAGE=$(awk -v OFMT="%.2f" 'NR==1 {total=$2+$4+$5; if (total > 0) {usage=($2+$4)*100/total; print usage "%"} else {print
"0.00%"}}' < /proc/stat)
CPU_LOAD=$(awk '{print $1, $2, $3}' /proc/loadavg)

# RAM Information
RAM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
RAM_AVAILABLE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)

# Check if RAM_TOTAL and RAM_AVAILABLE are non-zero
if [ "$RAM_TOTAL" -gt 0 ] && [ "$RAM_AVAILABLE" -gt 0 ]; then
# RAM division: Total and Available RAM in MB
RAM_TOTAL_MB=$(echo "scale=1; $RAM_TOTAL / 1024" | bc)
RAM_AVAILABLE_MB=$(echo "scale=1; $RAM_AVAILABLE / 1024" | bc)

# RAM Percentage calculation: (Total - Available) / Total * 100
RAM_PERC=$(echo "scale=1; 100 - ($RAM_AVAILABLE / $RAM_TOTAL) * 100" | bc)
else
RAM_PERC="N/A"
RAM_TOTAL_MB="N/A"
RAM_AVAILABLE_MB="N/A"
fi

# Disk Information
DISK_TOTAL=$(df -m / | tail -n 1 | awk '{print $2 " MB"}')
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}')
DISK_FILESYSTEM=$(df -T / | awk 'NR==2 {print $2}')

# GPU Information (if available, using /sys)
GPU=$(ls /sys/class/drm/ | grep "card" | cut -d"/" -f5)

# Swap Usage
SWAP_TOTAL=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
SWAP_FREE=$(awk '/SwapFree/ {print $2}' /proc/meminfo)

# Check if SWAP_TOTAL and SWAP_FREE are non-zero
if [ "$SWAP_TOTAL" -gt 0 ] && [ "$SWAP_FREE" -gt 0 ]; then
# Swap division: Total and Free swap in MB
SWAP_TOTAL_MB=$(echo "scale=1; $SWAP_TOTAL / 1024" | bc)
SWAP_FREE_MB=$(echo "scale=1; $SWAP_FREE / 1024" | bc)

# Swap Percentage calculation: (Total - Free) / Total * 100
SWAP_PERC=$(echo "scale=1; 100 - ($SWAP_FREE / $SWAP_TOTAL) * 100" | bc)
else
SWAP_PERC="N/A"
SWAP_TOTAL_MB="N/A"
SWAP_FREE_MB="N/A"
fi

# I/O Stats (Disk Read & Write)
IO=$(awk 'NR==4 {print "Read: " $6 " KB/s | Write: " $10 " KB/s"}' <(iostat -dk 1 2))

# Network Connections (using netstat as alternative)
CONNECTIONS=$(netstat -tuna | wc -l)

# Network Traffic (RX/TX Rate)
RX=$(cat /sys/class/net/eth0/statistics/rx_bytes)
TX=$(cat /sys/class/net/eth0/statistics/tx_bytes)
sleep 1
RX2=$(cat /sys/class/net/eth0/statistics/rx_bytes)
TX2=$(cat /sys/class/net/eth0/statistics/tx_bytes)

# RX/TX Rate calculation (difference between two reads divided by 1024 to get KB/s)
RX_RATE=$(( (RX2 - RX) / 1024 ))
TX_RATE=$(( (TX2 - TX) / 1024 ))

# Running Processes
PROCESSES=$(ps -e | wc -l)

# Uptime
UPTIME=$(uptime | awk '{print $3, $4, $5}')

# Output
echo "=== SYSTEM MONITOR ==="
echo "CPU: $CPU_MODEL | Cores: $CPU_CORES | Usage: $CPU_USAGE | Load Avg: $CPU_LOAD"
echo "RAM: $RAM_PERC ($RAM_AVAILABLE_MB MB available of $RAM_TOTAL_MB MB)"
echo "Swap: $SWAP_PERC ($SWAP_FREE_MB MB free of $SWAP_TOTAL_MB MB)"
echo "Disk: $DISK_USAGE of $DISK_TOTAL ($DISK_FILESYSTEM)"
echo "GPU: ${GPU:-'No GPU detected'}"
echo "I/O: $IO"
echo "Network: Connections: $CONNECTIONS | RX: $RX_RATE KB/s | TX: $TX_RATE KB/s"
echo "Processes: $PROCESSES"
echo "Uptime: $UPTIME"

sleep "$SLEEP_SEC"
done
