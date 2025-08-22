#!/usr/bin/env sh
# stats.sh - A simple system monitoring script

# Version: 1.0
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error and exit immediately.
# IFS: Set the Internal Field Separator to newline and tab, which helps in handling spaces
# in filenames and other inputs correctly.
set -eu

# Set default PATH to include common directories for system commands.
# LC_ALL: Set locale to C for consistent output across different environments.
# umask: Set file creation permissions to read/write for the owner only.
PATH="/usr/sbin:/usr/bin:/sbin:/bin"
export LC_ALL=C
umask 077

# Default values for options
OUTPUT=0; INTERVAL=1; COUNT=1; IFACES=""; DISKS=""

# Helper functions for logging and error handling
warn(){ printf '%s\n' "WARN: $*" >&2; }
die(){ printf '%s\n' "ERR: $*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }
need_num(){ case "$1" in (''|*[!0-9]*) die "Invalid number: $1";; esac; }

# Function to display usage information
usage(){ cat <<'EOF'
System Monitor Script
Usage: stats.sh [options]
  -o, --output MODE         json (default), text
  -i, --interval SEC        Sample interval (default 1)
  -c, --count N             Samples to print (1; 0=forever)
      --iface CSV           Only these interfaces (eth0,wlan0)
      --disks CSV           Only these disks/mounts (/,/home or sda,sdb)
      --units MODE          bytes|human (default bytes)
  -v, --version             Show version and exit
  -h, --help                Show this help and exit
EOF
}

# Parse command-line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o|--output)
        shift; [ "$#" -gt 0 ] || OUTPUT=0;
        case "$1" in
            json) OUTPUT=0;;
            text) OUTPUT=1;;
            *) die "Invalid output mode: $1";;
        esac;;
        -i|--interval)
        shift; [ "$#" -gt 0 ] || die "Missing SEC for --interval"
        need_num "$1"; INTERVAL="$1";;
        -c|--count)
        shift; [ "$#" -gt 0 ] || die "Missing N for --count"
        need_num "$1"; COUNT="$1";;
        --iface)
        shift; [ "$#" -gt 0 ] || die "Missing CSV for --iface"
        IFACES="$1";;
        --disks)
        shift; [ "$#" -gt 0 ] || die "Missing CSV for --disks"
        DISKS="$1";;
        -v|--version)
        [ -f version.txt ] && cat version.txt || printf 'unknown\n'
        exit 0;;
        -h|--help) usage; exit 0;;
        --) shift; break;;
        -*) die "Unknown option: $1";;
        *)  break;;
    esac
    shift
done

# Validate options
[ "$INTERVAL" -ge 1 ] || die "Interval must be >=1"
export OUTPUT INTERVAL COUNT IFACES DISKS

# Cleanup actions before exiting
cleanup(){
    echo "Cleaning up..."
}

# Trap signals to ensure cleanup is called on exit
on_err() {
    if [ -n "${1:-}" ]; then
        echo "Error on line $1"
    else
        echo "An error occurred"
    fi
    exit 1
}
trap 'on_err ${LINENO:-}' INT TERM HUP QUIT
trap 'cleanup' EXIT

# Required tools, check if stat is readable
PROC_ROOT="${PROC_ROOT:-/proc}"
SYS_ROOT="${SYS_ROOT:-/sys}"
[ -r "$PROC_ROOT/stat" ] || warn "Missing $PROC_ROOT/stat (running in container without mounts?)"

SYS_NET_DIR="${SYS_NET_DIR:-${HOST:+$HOST/sys/class/net}}"
[ -n "$SYS_NET_DIR" ] || SYS_NET_DIR="/sys/class/net"

RX_RATE=0; TX_RATE=0; NET_ROWS=""

# Check if we can use "df" command
have df || die "Missing df command"

# Returns the current date and time in UTC format.
now_iso(){ date -u "+%Y-%m-%dT%H:%M:%SZ"; }

# Prints one sample of system data (cpu, ram, disk, network) in text format
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
# text mode (after totals line)
    [ -n "$NET_ROWS" ] && while IFS='|' read -r n rx tx; do
        [ -n "$n" ] || continue
        printf 'Network %s: %s KB/s down, %s KB/s up\n' "$n" "$rx" "$tx"
    done <<EOF
    $NET_ROWS
EOF
}

# Escapes JSON special characters in a string
escape_json(){ printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

# Prints one sample of system data in JSON format
display_stats_json() {
    CPU_JSON="\"cpu\": {\"usage\": $CPU_USAGE}"
    RAM_JSON="\"ram\": {\"used\": $RAM_USED_MB, \"total\": $RAM_TOTAL_MB}"
    index=0
    DISK_JSON="\"disk\": ["
    
first=1
while IFS='|' read -r path device size used avail; do
    [ -n "$path" ] || continue
    path=$(escape_json "$path")
    device=$(escape_json "$device")
    [ $first -eq 0 ] && DISK_JSON="${DISK_JSON},"
    DISK_JSON="${DISK_JSON}{\"device\": \"$device\", \"used\": $used, \"total\": $size, \"path\": \"$path\"}"
    first=0
done <<EOF
${MOUNT_DATA-}
EOF
    DISK_JSON="${DISK_JSON}]"
    
NETWORK_JSON=""
if [ -n "$NET_ROWS" ]; then
    NETWORK_JSON="$NETWORK_JSON\"network\":["
    first=1
    while IFS='|' read -r n rx tx; do
        [ -n "$n" ] || continue
        [ $first -eq 1 ] || NETWORK_JSON="$NETWORK_JSON,"
        NETWORK_JSON="$NETWORK_JSON{\"name\":\"$n\",\"download\":$rx,\"upload\":$tx}"
        first=0
    done <<EOF
$NET_ROWS
EOF
    NETWORK_JSON="$NETWORK_JSON]"
fi
NETWORK_JSON="$NETWORK_JSON"

    echo "{ $CPU_JSON, $RAM_JSON, $DISK_JSON, $NETWORK_JSON }"
}

collect_mount_data() {
  LC_ALL=C df -P -k 2>/dev/null |
  awk -v disks="${DISKS:-}" '
    BEGIN{
      n=split(disks, want, ","); for(i=1;i<=n;i++) if (length(want[i])) inc[want[i]]=1
    }
    NR>1 {
      fs=$1; size=$2; used=$3; avail=$4; mnt=$6
      gsub("\\\\040"," ", mnt)   # unescape spaces
      if (fs ~ /^(tmpfs|devtmpfs|overlay|squashfs|proc|sysfs|cgroup|rpc_pipefs|debugfs|tracefs|none|rootfs)$/) next
      if (n>0) {
        keep=0; for(k in inc) if (mnt==k || fs==k) { keep=1; break }
        if (!keep) next
      }
      printf "%s|%s|%d|%d|%d\n", mnt, fs, int(size/1024), int(used/1024), int(avail/1024)
    }'
}

# ---- auto ifaces if none were passed ----
_auto_ifaces() {
  for d in "$SYS_NET_DIR"/*; do
    [ -e "$d" ] || continue
    i=${d##*/}
    case "$i" in lo|veth*|docker*|br-*|virbr*|vmnet*|zt*|tailscale*|wg*|ham*) continue;; esac
    printf '%s ' "$i"
  done
}

# ---- build explicit list from CSV (trim + ignore missing) ----
_ifaces_from_csv() {
  set -f
  oldIFS=$IFS; IFS=,
  for x in $IFACES; do
    IFS=$oldIFS
    i=$(printf '%s' "$x" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -n "$i" ] && [ -d "$SYS_NET_DIR/$i" ] && printf '%s ' "$i"
  done
  set +f
}

# ---- collect per-iface + totals with a single 1s delta ----
collect_network_data() {
  # pick list (explicit if provided, else auto)
  if [ -n "${IFACES:-}" ]; then
    IFACE_LIST=$(_ifaces_from_csv)
  else
    IFACE_LIST=$(_auto_ifaces)
  fi
  # none -> zeros
  [ -n "${IFACE_LIST:-}" ] || { RX_RATE=0; TX_RATE=0; NET_ROWS=""; return; }

  # snapshot A
  SNAP=""
  for i in $IFACE_LIST; do
    rb="$SYS_NET_DIR/$i/statistics/rx_bytes"
    tb="$SYS_NET_DIR/$i/statistics/tx_bytes"
    r=0; t=0
    [ -r "$rb" ] && r=$(cat "$rb" 2>/dev/null || printf 0)
    [ -r "$tb" ] && t=$(cat "$tb" 2>/dev/null || printf 0)
    SNAP="${SNAP}${i}|${r}|${t}
"
  done

  sleep 1

  # snapshot B + compute
  RX_RATE=0; TX_RATE=0; NET_ROWS=""
  while IFS='|' read -r name r1 t1; do
    [ -n "$name" ] || continue
    rb="$SYS_NET_DIR/$name/statistics/rx_bytes"
    tb="$SYS_NET_DIR/$name/statistics/tx_bytes"
    r2=0; t2=0
    [ -r "$rb" ] && r2=$(cat "$rb" 2>/dev/null || printf 0)
    [ -r "$tb" ] && t2=$(cat "$tb" 2>/dev/null || printf 0)
    dr=$((r2 - r1)); dt=$((t2 - t1))
    [ "$dr" -ge 0 ] || dr=0
    [ "$dt" -ge 0 ] || dt=0
    rk=$((dr / 1024)); tk=$((dt / 1024))
    NET_ROWS="${NET_ROWS}${name}|${rk}|${tk}
"
    RX_RATE=$((RX_RATE + rk))
    TX_RATE=$((TX_RATE + tk))
  done <<EOF
$SNAP
EOF
}

# Collects one sample of system data and prints it in the specified format
one_sample(){
    #Cpu Reading 1
    read cpu user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 guest1 guest_nice1 < "$PROC_ROOT/stat"
    TOTAL1=$(( user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1 ))

    # Network Traffic (RX/TX Rate)
    collect_network_data

    # Cpu Reading 2
    read cpu user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 guest2 guest_nice2 < "$PROC_ROOT/stat"
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
    RAM_AVAILABLE=$(awk '/MemAvailable/ {print $2}' $PROC_ROOT/meminfo)
    RAM_USED=$((RAM_TOTAL - RAM_AVAILABLE))
    RAM_USED_MB=$(echo "scale=1; $RAM_USED / 1024" | bc)

    # Disk Information
    MOUNT_DATA="$(collect_mount_data)"
    
    if [ $OUTPUT -eq 0 ]; then
        display_stats_json
    elif [ $OUTPUT -eq 1 ]; then
        display_stats
    fi
}

# Reads system information
read_system_info(){
    if [ -r version.txt ]; then
        ASH_STATS_VERSION=$(cat version.txt)
    else
        ASH_STATS_VERSION="unknown"
    fi
    UNAME=$(uname -srm)
    CPU_MODEL=$(awk -F ': ' '/model name/ {print $2; exit}' $PROC_ROOT/cpuinfo)
    CPU_CORES=$(awk -F ': ' '/cpu cores/ {print $2; exit}' $PROC_ROOT/cpuinfo)
    CPU_FREQUENCY=$(awk -F ': ' '/cpu MHz/ {print $2; exit}' $PROC_ROOT/cpuinfo)
    RAM_TOTAL=$(awk '/MemTotal/ {print $2}' $PROC_ROOT/meminfo)
    RAM_TOTAL_MB=$(echo "scale=1; $RAM_TOTAL / 1024" | bc)
    SLEEP_SEC_REAL=$((INTERVAL > 0 ? INTERVAL : 1))
    UPTIME=$(awk '{print int($1)}' $PROC_ROOT/uptime | xargs -I{} date -u -d "@{}" +"%Y-%m-%dT%H:%M:%SZ")
}

# Prints system information collection
print_system_info(){
    if [ $OUTPUT -eq 0 ]; then
        OUTPUT_TYPE="json"
    elif [ $OUTPUT -eq 1 ]; then
        OUTPUT_TYPE="text"
    fi
    START_TIME=$(now_iso)
    if [ $OUTPUT -eq 0 ]; then
        echo "{ \"info\": { \"version\": \"$ASH_STATS_VERSION\", \"host_mount\": \"$PROC_ROOT\", \"cpu_model\": \"$CPU_MODEL\", \"cpu_cores\": \"$CPU_CORES\", \"cpu_frequency\": \"$CPU_FREQUENCY\", \"ram_total\": \"$RAM_TOTAL_MB\", \"system\": \"$UNAME\", \"update_sec\": $SLEEP_SEC_REAL, \"output\": \"$OUTPUT_TYPE\", \"start_time\": \"$START_TIME\" } }"
    else
        echo "VERSION: $ASH_STATS_VERSION"
        echo "CPU Model: $CPU_MODEL"
        echo "CPU Cores: $CPU_CORES"
        echo "CPU Frequency: $CPU_FREQUENCY"
        echo "Online since: $START_TIME"
        echo "System: $UNAME"
        echo "Update every: $SLEEP_SEC_REAL seconds"
        echo "Output type: $OUTPUT_TYPE"
    fi
}

PRE_SLEEP=0; [ "$INTERVAL" -gt 1 ] && PRE_SLEEP=$((INTERVAL - 1))

# Main function to encapsulate the script logic
main(){
    read_system_info
    print_system_info
    n=0
    if [ $COUNT -eq 0 ]; then
        while :; do
            [ "$PRE_SLEEP" -gt 0 ] && sleep "$PRE_SLEEP"
            one_sample
        done
    else
        while [ "$n" -lt "${COUNT:-1}" ]; do
            [ "$PRE_SLEEP" -gt 0 ] && sleep "$PRE_SLEEP"
            one_sample
            n=$((n + 1))
        done
    fi
}

main "$@"
