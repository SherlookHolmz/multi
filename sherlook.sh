#!/usr/bin/env bash
# ==============================================================================
#  Sherlook - Advanced Multi-Node Tor Proxy Management System
#  Version: 6.4.0 (Production Release)
#  Architecture: State-Machine, Single Source of Truth, Resilient Health Engine
# ==============================================================================

set -u

# ------------------------------------------------------------------------------
# GLOBAL CONSTANTS & DIRECTORIES
# ------------------------------------------------------------------------------
readonly VERSION="6.4.0"
readonly BASE_DIR="/tmp/sherlook"
readonly STATE_DIR="${BASE_DIR}/states"
readonly PID_DIR="${BASE_DIR}/pids"
readonly LOCK_DIR="${BASE_DIR}/locks"
readonly LOG_DIR="${BASE_DIR}/logs"
readonly TORRC_DIR="${BASE_DIR}/torrcs"
readonly LOG_FILE="${LOG_DIR}/sherlook.log"

readonly PROBE_TIMEOUT=8
readonly MAX_ROTATION_ATTEMPTS=5
readonly COOLDOWN_PERIOD_SEC=300

# Public IP Check Endpoints
IP_PROVIDERS=(
    "https://api.ipify.org"
    "https://icanhazip.com"
    "https://ifconfig.me/ip"
    "https://ipinfo.io/ip"
)

# ------------------------------------------------------------------------------
# INITIALIZATION & DIRECTORY SETUP
# ------------------------------------------------------------------------------
init_environment() {
    mkdir -p "${STATE_DIR}" "${PID_DIR}" "${LOCK_DIR}" "${LOG_DIR}" "${TORRC_DIR}"
    chmod 700 "${BASE_DIR}"
    if [[ ! -f "${LOG_FILE}" ]]; then
        touch "${LOG_FILE}"
        chmod 600 "${LOG_FILE}"
    fi
}

# ------------------------------------------------------------------------------
# LOGGING SYSTEM (Structured & Timestamped)
# ------------------------------------------------------------------------------
log_msg() {
    local level="$1"
    local node_id="$2"
    local event="$3"
    local msg="$4"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$timestamp] [$level] [NODE:$node_id] [$event] $msg" >> "${LOG_FILE}"
}

# ------------------------------------------------------------------------------
# CONCURRENCY & LOCKING MECHANISM
# ------------------------------------------------------------------------------
acquire_node_lock() {
    local node_id="$1"
    local lock_file="${LOCK_DIR}/node_${node_id}.lock"
    exec 200>"$lock_file"
    flock -x -w 10 200 || return 1
    return 0
}

release_node_lock() {
    local node_id="$1"
    exec 200>&-
}

# ------------------------------------------------------------------------------
# SINGLE SOURCE OF TRUTH (STATE MANAGEMENT)
# ------------------------------------------------------------------------------
set_node_state() {
    local node_id="$1"
    local status="$2"
    local country="${3:-UNKNOWN}"
    local tor_port="${4:-0}"
    local control_port="${5:-0}"
    local live_ip="${6:-Waiting...}"
    local fail_count="${7:-0}"
    local rotation_count="${8:-0}"
    local error_msg="${9:-None}"

    local state_file="${STATE_DIR}/node_${node_id}.state"
    local tmp_file="${state_file}.tmp"
    local now
    now=$(date +%s)

    cat <<EOF > "$tmp_file"
STATUS=$status
COUNTRY=$country
TOR_PORT=$tor_port
CONTROL_PORT=$control_port
LIVE_IP=$live_ip
LAST_CHECK=$now
FAIL_COUNT=$fail_count
ROTATION_COUNT=$rotation_count
ERROR_MSG=$error_msg
EOF
    mv -f "$tmp_file" "$state_file"
}

get_node_field() {
    local node_id="$1"
    local field="$2"
    local state_file="${STATE_DIR}/node_${node_id}.state"

    if [[ -f "$state_file" ]]; then
        grep "^${field}=" "$state_file" | cut -d'=' -f2-
    else
        echo "UNKNOWN"
    fi
}

# ------------------------------------------------------------------------------
# MULTI-PROVIDER PROBE & GEOIP VERIFICATION
# ------------------------------------------------------------------------------
validate_ipv4() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    return 1
}

probe_node_ip() {
    local tor_port="$1"
    local probed_ip=""

    for provider in "${IP_PROVIDERS[@]}"; do
        probed_ip=$(curl --socks5-hostname "127.0.0.1:${tor_port}" \
            --connect-timeout "$PROBE_TIMEOUT" \
            --max-time "$PROBE_TIMEOUT" \
            -s "$provider" | tr -d '[:space:]')

        if validate_ipv4 "$probed_ip"; then
            echo "$probed_ip"
            return 0
        fi
    done

    echo "FAILED"
    return 1
}

verify_geoip() {
    local ip="$1"
    local expected_cc="$2"

    if [[ "$ip" == "FAILED" || -z "$ip" ]]; then
        return 1
    fi

    local actual_cc
    actual_cc=$(curl -s --connect-timeout 5 "https://ipapi.co/${ip}/country/" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')

    if [[ -n "$actual_cc" && "$actual_cc" != "UNDEFINED" ]]; then
        if [[ "$actual_cc" == "$expected_cc" ]]; then
            return 0
        else
            log_msg "WARN" "SYS" "GEOIP_MISMATCH" "Expected $expected_cc but got $actual_cc for IP $ip"
            return 2
        fi
    fi

    return 0
}

# ------------------------------------------------------------------------------
# TOR CIRCUIT ROTATION & CONTROL PORT HANDLER
# ------------------------------------------------------------------------------
signal_newnym() {
    local control_port="$1"
    if command -v nc >/dev/null 2>&1; then
        (echo -e 'AUTHENTICATE ""\r\nSIGNAL NEWNYM\r\nQUIT\r') | nc -w 3 127.0.0.1 "$control_port" >/dev/null 2>&1
        return $?
    fi
    return 1
}

# ------------------------------------------------------------------------------
# HEALTH CHECK ENGINE & STATE MACHINE (Core Auto-Heal Logic)
# ------------------------------------------------------------------------------
health_check_node() {
    local node_id="$1"

    acquire_node_lock "$node_id" || return 1

    local current_status country tor_port control_port live_ip fail_count rot_count last_check
    current_status=$(get_node_field "$node_id" "STATUS")
    country=$(get_node_field "$node_id" "COUNTRY")
    tor_port=$(get_node_field "$node_id" "TOR_PORT")
    control_port=$(get_node_field "$node_id" "CONTROL_PORT")
    live_ip=$(get_node_field "$node_id" "LIVE_IP")
    fail_count=$(get_node_field "$node_id" "FAIL_COUNT")
    rot_count=$(get_node_field "$node_id" "ROTATION_COUNT")
    last_check=$(get_node_field "$node_id" "LAST_CHECK")

    [[ "$fail_count" =~ ^[0-9]+$ ]] || fail_count=0
    [[ "$rot_count" =~ ^[0-9]+$ ]] || rot_count=0
    [[ "$last_check" =~ ^[0-9]+$ ]] || last_check=0

    local now
    now=$(date +%s)

    # Cooldown Handler
    if [[ "$current_status" == "COOLDOWN" ]]; then
        local elapsed=$((now - last_check))
        if (( elapsed < COOLDOWN_PERIOD_SEC )); then
            release_node_lock "$node_id"
            return 0
        fi
        log_msg "INFO" "$node_id" "COOLDOWN_EXPIRED" "Resetting node from cooldown state"
        fail_count=0
        rot_count=0
    fi

    set_node_state "$node_id" "HEALING" "$country" "$tor_port" "$control_port" "$live_ip" "$fail_count" "$rot_count" "Probing network..."

    # Probe SOCKS5 Proxy
    local probed_ip
    probed_ip=$(probe_node_ip "$tor_port")

    if [[ "$probed_ip" != "FAILED" ]]; then
        if verify_geoip "$probed_ip" "$country"; then
            log_msg "INFO" "$node_id" "HEALTH_OK" "Node healthy with IP $probed_ip"
            set_node_state "$node_id" "HEALTHY" "$country" "$tor_port" "$control_port" "$probed_ip" 0 0 "None"
            release_node_lock "$node_id"
            return 0
        fi
    fi

    # Failure Branch -> Attempt Rotation / Circuit Repair
    ((fail_count++))
    log_msg "WARN" "$node_id" "HEALTH_FAILED" "Probe failed. Attempt $fail_count of $MAX_ROTATION_ATTEMPTS"

    if (( fail_count >= MAX_ROTATION_ATTEMPTS )); then
        log_msg "ERROR" "$node_id" "CIRCUIT_BREAKER" "Max failures reached. Moving to COOLDOWN"
        set_node_state "$node_id" "COOLDOWN" "$country" "$tor_port" "$control_port" "DEAD" "$fail_count" "$rot_count" "Circuit Breaker Active"
        release_node_lock "$node_id"
        return 1
    fi

    # Perform NEWNYM Rotation
    set_node_state "$node_id" "ROTATING" "$country" "$tor_port" "$control_port" "Rotating..." "$fail_count" "$rot_count" "Signal NEWNYM"
    signal_newnym "$control_port"
    sleep 3

    # Re-probe post rotation
    probed_ip=$(probe_node_ip "$tor_port")

    if [[ "$probed_ip" != "FAILED" ]]; then
        log_msg "INFO" "$node_id" "ROTATION_SUCCESS" "New IP acquired: $probed_ip"
        set_node_state "$node_id" "HEALTHY" "$country" "$tor_port" "$control_port" "$probed_ip" 0 "$((rot_count + 1))" "None"
    else
        log_msg "ERROR" "$node_id" "NODE_DEAD" "Node unresponsive after rotation"
        set_node_state "$node_id" "DEAD" "$country" "$tor_port" "$control_port" "DEAD" "$fail_count" "$rot_count" "Proxy Unreachable"
    fi

    release_node_lock "$node_id"
}

# ------------------------------------------------------------------------------
# AUTO-HEAL DAEMON (Background Monitor)
# ------------------------------------------------------------------------------
run_auto_heal_daemon() {
    init_environment
    log_msg "INFO" "SYS" "DAEMON_START" "Sherlook Auto-Heal Daemon v${VERSION} started"

    while true; do
        for state_file in "${STATE_DIR}"/node_*.state; do
            [[ -f "$state_file" ]] || continue
            local filename
            filename=$(basename "$state_file")
            local node_id
            node_id=$(echo "$filename" | sed -E 's/node_([0-9]+)\.state/\1/')

            if [[ -n "$node_id" ]]; then
                health_check_node "$node_id" &
            fi
        done
        wait
        sleep 15
    done
}

# ------------------------------------------------------------------------------
# NODE LIFECYCLE MANAGEMENT (Start / Stop / Delete)
# ------------------------------------------------------------------------------
start_node() {
    local node_id="$1"
    local country="$2"
    local tor_port="$3"
    local control_port="$4"

    acquire_node_lock "$node_id" || return 1

    local torrc_file="${TORRC_DIR}/torrc_${node_id}"
    local pid_file="${PID_DIR}/node_${node_id}.pid"

    cat <<EOF > "$torrc_file"
SocksPort 127.0.0.1:${tor_port}
ControlPort 127.0.0.1:${control_port}
DataDirectory ${BASE_DIR}/data_${node_id}
ExitNodes {${country}}
StrictNodes 1
CookieAuthentication 0
EOF

    tor -f "$torrc_file" >/dev/null 2>&1 &
    local pid=$!
    echo "$pid" > "$pid_file"

    set_node_state "$node_id" "HEALING" "$country" "$tor_port" "$control_port" "Waiting..." 0 0 "Initializing Tor"
    release_node_lock "$node_id"

    log_msg "INFO" "$node_id" "NODE_START" "Started Tor process PID $pid on port $tor_port ($country)"
}

stop_node() {
    local node_id="$1"
    acquire_node_lock "$node_id" || return 1

    local pid_file="${PID_DIR}/node_${node_id}.pid"
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        if kill -0 "$pid" >/dev/null 2>&1; then
            kill "$pid" >/dev/null 2>&1
            sleep 1
            kill -9 "$pid" >/dev/null 2>&1 || true
        fi
        rm -f "$pid_file"
    fi

    rm -f "${STATE_DIR}/node_${node_id}.state"
    rm -f "${TORRC_DIR}/torrc_${node_id}"
    rm -rf "${BASE_DIR}/data_${node_id}"

    release_node_lock "$node_id"
    log_msg "INFO" "$node_id" "NODE_STOP" "Stopped and cleaned up node $node_id"
}

# ------------------------------------------------------------------------------
# UI RENDERING FUNCTIONS (Single Source of Truth)
# ------------------------------------------------------------------------------
get_country_flag() {
    local cc="$1"
    case "$cc" in
        US) echo "🇺🇸" ;;
        FR) echo "🇫🇷" ;;
        CA) echo "🇨🇦" ;;
        FI) echo "🇫🇮" ;;
        ES) echo "🇪🇸" ;;
        NL) echo "🇳🇱" ;;
        CH) echo "🇨🇭" ;;
        SE) echo "🇸🇪" ;;
        NO) echo "🇳🇴" ;;
        IS) echo "🇮🇸" ;;
        UA) echo "🇺🇦" ;;
        AZ) echo "🇦🇿" ;;
        CY) echo "🇨🇾" ;;
        GR) echo "🇬🇷" ;;
        PT) echo "🇵🇹" ;;
        HU) echo "🇭🇺" ;;
        LU) echo "🇱🇺" ;;
        GB) echo "🇬🇧" ;;
        TW) echo "🇹🇼" ;;
        IL) echo "🇮🇱" ;;
        *)  echo "🌐" ;;
    esac
}

render_active_nodes_menu() {
    echo -e "\033[1;33m📌 [ DELETE / MANAGE ACTIVE NODES ]\033[0m"
    echo "──────────────────────────────────────────────────────────────────"

    local found=0
    for state_file in "${STATE_DIR}"/node_*.state; do
        [[ -f "$state_file" ]] || continue
        found=1

        local filename node_id country tor_port status flag
        filename=$(basename "$state_file")
        node_id=$(echo "$filename" | sed -E 's/node_([0-9]+)\.state/\1/')
        
        # Read directly from Authoritative State File!
        status=$(get_node_field "$node_id" "STATUS")
        country=$(get_node_field "$node_id" "COUNTRY")
        tor_port=$(get_node_field "$node_id" "TOR_PORT")
        flag=$(get_country_flag "$country")

        local status_color="\033[0;32m"
        if [[ "$status" == "DEAD" ]]; then status_color="\033[0;31m";
        elif [[ "$status" == "HEALING" || "$status" == "ROTATING" ]]; then status_color="\033[0;33m";
        elif [[ "$status" == "COOLDOWN" ]]; then status_color="\033[0;35m"; fi

        printf "[%s] %s %-18s TorPort:%-6s ${status_color}%-10s\033[0m\n" \
            "$node_id" "$flag" "$country" "$tor_port" "$status"
    done

    if [[ $found -eq 0 ]]; then
        echo " No active nodes found."
    else
        echo "──────────────────────────────────────────────────────────────────"
        echo "[99] DELETE ALL ACTIVE NODES (Clear All)"
    fi
    echo "──────────────────────────────────────────────────────────────────"
}

render_monitor_table() {
    echo "┌──────┬──────┬──────────────────────┬─────────────┬──────────────┬──────────────────┐"
    echo "│ ID   │ CC   │ Location             │ Tor Port    │ Status       │ Live IP          │"
    echo "├──────┼──────┼──────────────────────┼─────────────┼──────────────┼──────────────────┤"

    for state_file in "${STATE_DIR}"/node_*.state; do
        [[ -f "$state_file" ]] || continue
        local filename node_id status country tor_port live_ip
        filename=$(basename "$state_file")
        node_id=$(echo "$filename" | sed -E 's/node_([0-9]+)\.state/\1/')

        # Authoritative State Read
        status=$(get_node_field "$node_id" "STATUS")
        country=$(get_node_field "$node_id" "COUNTRY")
        tor_port=$(get_node_field "$node_id" "TOR_PORT")
        live_ip=$(get_node_field "$node_id" "LIVE_IP")

        printf "│ %-4s │ %-4s │ %-20s │ %-11s │ %-12s │ %-16s │\n" \
            "$node_id" "$country" "$country Node" "$tor_port" "$status" "$live_ip"
    done

    echo "└──────┴──────┴──────────────────────┴─────────────┴──────────────┴──────────────────┘"
}

# ------------------------------------------------------------------------------
# ATOMIC UPDATE ENGINE
# ------------------------------------------------------------------------------
update_sherlook() {
    echo "[+] Checking for updates..."
    local update_url="https://raw.githubusercontent.com/SherlookHolmz/sherlook/main/sherlook.sh"
    local tmp_bin="/tmp/sherlook_update.sh"

    if curl -s -f -L "$update_url" -o "$tmp_bin"; then
        if bash -n "$tmp_bin"; then
            local current_script
            current_script=$(readlink -f "$0")
            cp "$current_script" "${current_script}.bak"
            mv -f "$tmp_bin" "$current_script"
            chmod +x "$current_script"
            echo "[✓] Updated successfully to v6.4.0! Backup saved at ${current_script}.bak"
            exit 0
        else
            echo "[!] Downloaded binary failed syntax check. Aborting."
            rm -f "$tmp_bin"
        fi
    else
        echo "[!] Failed to fetch update from GitHub."
    fi
}

# ------------------------------------------------------------------------------
# MAIN CLI INTERFACE
# ------------------------------------------------------------------------------
main_menu() {
    init_environment

    while true; do
        clear
        echo "=================================================================="
        echo "              SHERLOOK PROXY MANAGEMENT SYSTEM v${VERSION}         "
        echo "=================================================================="
        echo ""
        render_active_nodes_menu
        echo ""
        render_monitor_table
        echo ""
        echo "Commands: [A] Add Node | [D] Delete Node | [U] Update | [R] Run Daemon | [Q] Quit"
        read -rp "Select option: " choice

        case "$choice" in
            [Aa])
                read -rp "Enter Node ID (e.g. 03): " nid
                read -rp "Enter Country Code (e.g. US): " ncc
                read -rp "Enter Tor Port (e.g. 9082): " tport
                read -rp "Enter Control Port (e.g. 9182): " cport
                start_node "$nid" "$ncc" "$tport" "$cport"
                ;;
            [Dd])
                read -rp "Enter ID to stop/delete (or 99 for All): " del_id
                if [[ "$del_id" == "99" ]]; then
                    for sf in "${STATE_DIR}"/node_*.state; do
                        [[ -f "$sf" ]] || continue
                        nid=$(basename "$sf" | sed -E 's/node_([0-9]+)\.state/\1/')
                        stop_node "$nid"
                    done
                else
                    stop_node "$del_id"
                fi
                ;;
            [Uu])
                update_sherlook
                ;;
            [Rr])
                echo "[+] Launching Auto-Heal Daemon in background..."
                run_auto_heal_daemon &
                echo "[✓] Daemon PID: $!"
                sleep 2
                ;;
            [Qq])
                echo "Exiting Sherlook."
                exit 0
                ;;
            *)
                ;;
        esac
    done
}

if [[ "${1:-}" == "--daemon" ]]; then
    run_auto_heal_daemon
else
    main_menu
fi
