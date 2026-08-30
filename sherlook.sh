#!/usr/bin/env bash
# Sherlook Automate Engine v7.0.0 (Nexatis API Edition)
# Bugfix release: lower CPU auto-heal, fixed panel-delete data loss, pending-cleanup queue, refreshed UI

# ================= COLORS =================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ================= CONFIG =================
BASE_DIR="/etc/tor/sherlook_nodes"
DATA_DIR="/var/lib/tor/sherlook_nodes"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
INSTALL_PATH="/usr/local/bin/sherlook"
RAW_BASE="https://raw.githubusercontent.com/SherlookHolmz/multi/main"
RAW_ENGINE_URL="$RAW_BASE/sherlook.sh"
RAW_INSTALLER_URL="$RAW_BASE/install.sh"
# Installer resolves this placeholder to the exact commit installed.
PINNED_COMMIT="__INSTALLER_RESOLVES__"
SHERLOOK_VERSION="7.0.0"
PANEL_LOCK_FILE="$BASE_DIR/panel-write.lock"
PANEL_CONNECT_TIMEOUT=8
PANEL_REQUEST_TIMEOUT=25
PANEL_VERIFY_AFTER_WRITE=1
PANEL_MAX_RETRIES=3
LOCATION_CACHE="$DATA_DIR/onionoo_exit_countries.cache"
LOCATION_CATALOG="$DATA_DIR/location_catalog.tsv"
LOCATION_CACHE_TTL=21600
# CPU/network tuning (v7.0.0): the old defaults (interval=5s, full 3-source
# GeoIP re-verification of every node, every cycle) meant the daemon was
# almost never idle and kept forking curl/jq/bash processes back-to-back.
# AUTO_HEAL_INTERVAL: seconds between auto-heal passes.
AUTO_HEAL_INTERVAL=30
# How many auto-heal passes between full GeoIP re-verification passes for
# nodes that are already ONLINE and healthy. In between, only a cheap
# liveness check (process alive + SOCKS reachable) runs for those nodes.
HEALTH_FULL_RECHECK_EVERY=6
AUTO_HEAL_PARALLEL=10
EFFECTIVE_PARALLEL=10
BRIDGE_MODE=0
BRIDGE_PARALLEL=2
BRIDGE_FILE="$BASE_DIR/bridges.conf"
NODE_ROTATE_RETRIES=20
HEALTH_CONNECT_TIMEOUT=5
HEALTH_MAX_TIME=15
HEALTH_STALE_AFTER=90
QUARANTINE_BASE=300
QUARANTINE_MAX=3600


# Panel Config Cache
PANEL_CONF="$BASE_DIR/nexatis_panel.conf"

# How many "country mismatch / high-abuse" retries before we give up on a fresh deploy
MAX_QUALITY_ATTEMPTS=8
# How many quick NEWNYM (new circuit, no restart) tries before we escalate
MAX_NEWNYM_TRIES=2
# Maximum total public-IP validation cycles for one node deployment
MAX_TOTAL_VALIDATION_ATTEMPTS=20
# After this many country-specific failures, offer a fallback route while keeping the node label.
COUNTRY_FALLBACK_THRESHOLD=5
FALLBACK_AUTO_ON_NONINTERACTIVE=1
FALLBACK_ROUTE_ATTEMPTS=5
# After N consecutive wrong-country IPs, ask whether to keep trying or skip to fallback.
COUNTRY_FAILURE_PROMPT_ENABLED=1


# Format: "CountryCode : CountryName : TorPort"
declare -A NODES=(
    [01]="DE:Germany:9080" [02]="TR:Turkey:9081" [03]="US:United States:9082"
    [04]="FR:France:9083" [05]="AT:Austria:9084" [06]="BE:Belgium:9085"
    [07]="RO:Romania:9086" [08]="CA:Canada:9087" [09]="SG:Singapore:9088"
    [10]="JP:Japan:9089" [11]="IE:Ireland:9090" [12]="FI:Finland:9091"
    [13]="ES:Spain:9092" [14]="PL:Poland:9093" [15]="NL:Netherlands:9094"
    [16]="IT:Italy:9095" [17]="CH:Switzerland:9096" [18]="SE:Sweden:9097"
    [19]="NO:Norway:9098" [20]="DK:Denmark:9099" [21]="IS:Iceland:9100"
    [22]="AU:Australia:9101" [23]="IN:India:9102" [24]="HK:Hong Kong:9103"
    [25]="UA:Ukraine:9104" [26]="CZ:Czech Republic:9105" [27]="KR:South Korea:9106"
    [28]="ZA:South Africa:9107" [29]="MX:Mexico:9108" [30]="MY:Malaysia:9109"
    [31]="AZ:Azerbaijan:9110" [32]="CY:Cyprus:9111" [33]="GR:Greece:9112"
    [34]="PT:Portugal:9113" [35]="HU:Hungary:9114" [36]="LU:Luxembourg:9115"
    [37]="GB:United Kingdom:9116" [38]="AR:Argentina:9117" [39]="TW:Taiwan:9118"
    [40]="BG:Bulgaria:9119" [41]="IL:Israel:9120" [42]="MD:Moldova:9121"
    [43]="RU:Russia:9122" [44]="CL:Chile:9123" [45]="CR:Costa Rica:9124"
    [46]="VN:Vietnam:9125" [47]="ID:Indonesia:9126" [48]="SC:Seychelles:9127"
    [49]="HR:Croatia:9128" [50]="TN:Tunisia:9129"
    [51]="BR:Brazil:9130" [52]="PH:Philippines:9131" [53]="TH:Thailand:9132"
    [54]="EG:Egypt:9133" [55]="LV:Latvia:9134" [56]="LT:Lithuania:9135"
    [57]="EE:Estonia:9136" [58]="SI:Slovenia:9137" [59]="SK:Slovakia:9138"
    [60]="RS:Serbia:9139" [61]="GE:Georgia:9140" [62]="KZ:Kazakhstan:9141"
    [63]="AE:United Arab Emirates:9142" [64]="SA:Saudi Arabia:9143" [65]="QA:Qatar:9144"
    [66]="AL:Albania:9145" [67]="BA:Bosnia and Herzegovina:9146" [68]="BD:Bangladesh:9147"
    [69]="CO:Colombia:9148" [70]="EC:Ecuador:9149" [71]="GT:Guatemala:9150"
    [72]="KE:Kenya:9151" [73]="MA:Morocco:9152" [74]="NG:Nigeria:9153"
    [75]="NZ:New Zealand:9154" [76]="PE:Peru:9155" [77]="PK:Pakistan:9156"
    [78]="LK:Sri Lanka:9157" [79]="UY:Uruguay:9158" [80]="VE:Venezuela:9159"
    [81]="PA:Panama:9160" [82]="DO:Dominican Republic:9161" [83]="BO:Bolivia:9162"
)

declare -A EMOJIS=(
    [DE]="🇩🇪" [TR]="🇹🇷" [US]="🇺🇸" [FR]="🇫🇷" [AT]="🇦🇹" [BE]="🇧🇪"
    [RO]="🇷🇴" [CA]="🇨🇦" [SG]="🇸🇬" [JP]="🇯🇵" [IE]="🇮🇪" [FI]="🇫🇮"
    [ES]="🇪🇸" [PL]="🇵🇱" [NL]="🇳🇱" [IT]="🇮🇹" [CH]="🇨🇭" [SE]="🇸🇪"
    [NO]="🇳🇴" [DK]="🇩🇰" [IS]="🇮🇸" [AU]="🇦🇺" [IN]="🇮🇳" [HK]="🇭🇰"
    [UA]="🇺🇦" [CZ]="🇨🇿" [KR]="🇰🇷" [ZA]="🇿🇦" [MX]="🇲🇽" [MY]="🇲🇾"
    [AZ]="🇦🇿" [CY]="🇨🇾" [GR]="🇬🇷" [PT]="🇵🇹" [HU]="🇭🇺" [LU]="🇱🇺"
    [GB]="🇬🇧" [AR]="🇦🇷" [TW]="🇹🇼" [BG]="🇧🇬" [IL]="🇮🇱" [MD]="🇲🇩"
    [RU]="🇷🇺" [CL]="🇨🇱" [CR]="🇨🇷" [VN]="🇻🇳" [ID]="🇮🇩" [SC]="🇸🇨"
    [HR]="🇭🇷" [TN]="🇹🇳" [BR]="🇧🇷" [PH]="🇵🇭" [TH]="🇹🇭" [EG]="🇪🇬"
    [LV]="🇱🇻" [LT]="🇱🇹" [EE]="🇪🇪" [SI]="🇸🇮" [SK]="🇸🇰" [RS]="🇷🇸"
    [GE]="🇬🇪" [KZ]="🇰🇿" [AE]="🇦🇪" [SA]="🇸🇦" [QA]="🇶🇦"
    [AL]="🇦🇱" [BA]="🇧🇦" [BD]="🇧🇩" [CO]="🇨🇴" [EC]="🇪🇨" [GT]="🇬🇹"
    [KE]="🇰🇪" [MA]="🇲🇦" [NG]="🇳🇬" [NZ]="🇳🇿" [PE]="🇵🇪" [PK]="🇵🇰"
    [LK]="🇱🇰" [UY]="🇺🇾" [VE]="🇻🇪" [PA]="🇵🇦" [DO]="🇩🇴" [BO]="🇧🇴"
)

ONIONOO_URL="https://onionoo.torproject.org/details"
ONIONOO_TIMEOUT=12
ONIONOO_MIN_EXITS=1

declare -A LOW_SUPPLY_WARN=(
    [IS]=1 [SC]=1 [AZ]=1 [MD]=1 [CY]=1 [TN]=1 [GE]=1 [KZ]=1
    [QA]=1 [SA]=1 [AE]=1 [CR]=1 [AR]=1 [PK]=1 [BO]=1 [VE]=1
)

ORDER=({01..83})

# Preferred fallback countries when the requested exit country repeatedly fails
# GeoIP validation. The node keeps its original display/label country, while
# route_code records the country actually used for ExitNodes. Orders favor
# nearby / well-supplied Tor locations rather than arbitrary distant countries.
declare -A FALLBACK_COUNTRIES=(
    [LU]="DE FR NL BE CH AT"
    [BE]="NL FR DE LU CH GB"
    [NL]="DE BE FR GB DK"
    [CH]="DE FR AT IT NL BE"
    [AT]="DE CZ HU CH IT SI"
    [FR]="DE BE CH IT ES NL GB"
    [DE]="NL FR AT CH BE CZ DK PL"
    [GB]="IE FR NL BE DE DK"
    [IE]="GB FR NL"
    [ES]="PT FR IT"
    [PT]="ES FR"
    [IT]="CH AT FR DE SI"
    [SI]="AT IT HR DE"
    [HR]="SI AT HU IT"
    [CZ]="DE AT PL SK"
    [PL]="DE CZ SK SE"
    [SK]="CZ AT PL HU"
    [HU]="AT SK RO HR SI"
    [RO]="HU BG AT PL"
    [BG]="RO GR RS"
    [GR]="BG IT RO"
    [DK]="DE NL SE NO"
    [SE]="DK NO FI DE"
    [NO]="SE DK DE FI"
    [FI]="SE DE NO DK"
    [EE]="FI LV SE"
    [LV]="EE LT SE DE"
    [LT]="LV PL DE"
    [IS]="GB IE NO DK"
    [TR]="BG GR DE RO"
    [RS]="HU HR BG RO"
    [BA]="HR RS AT DE"
    [AL]="GR IT HR"
    [MD]="RO UA PL"
    [UA]="PL RO CZ"
    [RU]="FI DE SE PL"
    [CA]="US GB NL DE"
    [US]="CA GB NL DE FR"
    [MX]="US CA"
    [CR]="US MX CA"
    [PA]="US CR MX CA"
    [DO]="US PA MX"
    [BO]="CL PE BR AR"
    [PE]="CL BO US"
    [CL]="AR PE US"
    [AR]="CL BR UY"
    [UY]="AR BR CL"
    [BR]="AR CL US"
    [CO]="US MX PA"
    [EC]="US CO PE"
    [GT]="MX US CR"
    [VE]="CO BR US"
    [AU]="NZ SG JP"
    [NZ]="AU SG JP"
    [JP]="KR SG HK AU"
    [KR]="JP SG HK"
    [SG]="MY HK JP AU"
    [MY]="SG TH ID"
    [TH]="MY SG JP"
    [ID]="SG MY AU"
    [HK]="SG JP KR"
    [TW]="JP KR HK SG"
    [PH]="SG JP HK MY"
    [VN]="SG JP MY TH"
    [IN]="SG AE DE GB"
    [BD]="IN SG MY"
    [LK]="IN SG"
    [PK]="AE TR DE GB"
    [KZ]="RU DE PL"
    [GE]="TR DE PL"
    [AZ]="TR GE DE"
    [IL]="DE FR NL GB"
    [AE]="DE NL GB FR"
    [SA]="AE TR DE NL"
    [QA]="AE TR DE NL"
    [EG]="DE FR IT NL"
    [MA]="FR ES PT"
    [TN]="FR IT DE"
    [ZA]="GB NL DE FR"
    [NG]="GB FR DE NL"
    [KE]="GB DE FR NL"
    [SC]="FR DE GB"
)

expand_iso_locations() { return 0; }

# ================= CORE FUNCTIONS =================
# Resolve the country actually used by a node. The UI/API label remains the original node country.
node_route_code() {
    local code="$1" out_port="$2"
    local f="$DATA_DIR/${code}_${out_port}/route_code.txt"
    if [ -s "$f" ]; then
        tr -d '\r\n ' < "$f" | tr '[:lower:]' '[:upper:]'
    else
        printf '%s\n' "$code"
    fi
}

set_node_route_code() {
    local code="$1" out_port="$2" route="$3"
    mkdir -p "$DATA_DIR/${code}_${out_port}"
    printf '%s\n' "${route^^}" > "$DATA_DIR/${code}_${out_port}/route_code.txt"
}

clear_node_route_code() {
    local code="$1" out_port="$2"
    rm -f "$DATA_DIR/${code}_${out_port}/route_code.txt"
}

fallback_candidates() {
    local code="${1^^}" candidate count
    local -a candidates=()
    declare -A seen=()
    for candidate in ${FALLBACK_COUNTRIES[$code]:-}; do
        candidate="${candidate^^}"
        [ "$candidate" = "$code" ] && continue
        [ -n "${seen[$candidate]:-}" ] && continue
        seen[$candidate]=1
        candidates+=("$candidate")
    done
    # Generic fallback for countries without an explicit regional map.
    if [ ${#candidates[@]} -eq 0 ]; then
        for candidate in DE FR NL GB US CA; do
            [ "$candidate" = "$code" ] && continue
            candidates+=("$candidate")
        done
    fi
    printf '%s\n' "${candidates[@]}"
}

country_display_name() {
    local code="${1^^}"
    local idx
    for idx in "${ORDER[@]}"; do
        IFS=':' read -r c n p <<< "${NODES[$idx]}"
        if [ "$c" = "$code" ]; then
            printf '%s\n' "$n"
            return 0
        fi
    done
    country_name "$code"
}

choose_fallback_route() {
    local code="${1^^}" name="$2" out_port="$3" interactive="${4:-1}" route candidate count
    local -a candidates=()
    mapfile -t candidates < <(fallback_candidates "$code")
    [ ${#candidates[@]} -eq 0 ] && return 1

    if [ "$interactive" = "1" ] && [ -t 0 ] && [ -t 1 ]; then
        echo -e "\n${YELLOW}[!] $name ($code) failed to obtain a verified $code IP after $COUNTRY_FALLBACK_THRESHOLD attempts.${NC}"
        echo -e "  ${CYAN}[1]${NC} Continue trying $code"
        echo -e "  ${CYAN}[2]${NC} Use a nearby Tor country automatically (keep $name/$code label)"
        echo -e "  ${RED}[3]${NC} Stop this node"
        read -r -p "Choice [1-3]: " route_choice < /dev/tty || route_choice=2
        case "$route_choice" in
            1) return 2 ;;
            3) return 3 ;;
            2) ;;
            *) route_choice=2 ;;
        esac
    elif [ "$FALLBACK_AUTO_ON_NONINTERACTIVE" != "1" ]; then
        return 2
    fi

    for candidate in "${candidates[@]}"; do
        count=$(onionoo_exit_count "${candidate,,}")
        if [ "$count" = "-1" ] || [ "$count" -ge "$ONIONOO_MIN_EXITS" ] 2>/dev/null; then
            route="$candidate"
            break
        fi
    done
    [ -n "${route:-}" ] || return 1
    set_node_route_code "$code" "$out_port" "$route"
    printf '%s\n' "$route"
}

fallback_or_retry_deploy() {
    local code="$1" name="$2" out_port="$3" interactive="${4:-1}" route_choice route
    route=$(choose_fallback_route "$code" "$name" "$out_port" "$interactive")
    case "$?" in
        0)
            [ -n "$route" ] || return 1
            echo -e "${YELLOW}[!] ${EMOJIS[$code]} $name will keep its ${WHITE}$name${YELLOW} label, but route exits through ${WHITE}${route}${YELLOW}.${NC}"
            return 0
            ;;
        2) return 2 ;;
        3) return 3 ;;
        *) return 1 ;;
    esac
}

validate_node_ip() {
    local ip="$1" expected="$2" visual="${3:-0}"
    local result bad actual reason seen
    # Full 3-source cross-check (fast=0): this runs during interactive
    # deploy/rotate, not on every auto-heal tick, so the extra accuracy is
    # worth the two extra API calls here.
    result=$(check_ip_quality "$ip" "$expected" "$visual" 0)
    IFS='|' read -r bad actual reason seen <<< "$result"
    printf '%s|%s|%s|%s\n' "$bad" "$actual" "$reason" "$seen"
}

# Hide exact rejected IPs in the UI/log and show only their /16 range.
# The full IP is still stored internally in bad_exits.txt for diagnostics only.
ip_display_range() {
    local ip="$1"
    if is_valid_ipv4 "$ip"; then
        local a b c d
        IFS='.' read -r a b c d <<< "$ip"
        printf '%s.%s.0.0/16' "$a" "$b"
    else
        printf 'unknown'
    fi
}

prompt_country_failure_action() {
    local code="$1" name="$2" failed="$3"
    # Return codes: 0=continue same country, 2=auto fallback, 3=stop node.
    echo -e "\n${YELLOW}[!] ${EMOJIS[$code]} $name has reached $failed wrong-country IPs.${NC}"
    echo -e "  ${CYAN}[1]${NC} Keep trying ${WHITE}$name${NC}"
    echo -e "  ${CYAN}[2]${NC} Skip ${WHITE}$name${NC} and move to fallback countries automatically"
    echo -e "  ${RED}[3]${NC} Skip/stop this node"
    local action='2'
    if [ "$COUNTRY_FAILURE_PROMPT_ENABLED" = "1" ] && [ -t 0 ] && [ -t 1 ]; then
        read -r -p "Choice [1-3]: " action < /dev/tty || action=2
    elif [ "$FALLBACK_AUTO_ON_NONINTERACTIVE" = "1" ]; then
        action=2
    fi
    case "$action" in
        1) return 0 ;;
        3) return 3 ;;
        *) return 2 ;;
    esac
}


is_valid_ipv4() {
    local ip="${1//$'\r'/}"
    ip="${ip//$'\n'/}"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    local IFS='.' octet
    read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        (( 10#$octet <= 255 )) || return 1
    done
    return 0
}

command_or_empty() {
    command -v "$1" 2>/dev/null || true
}

node_pid_file() {
    local code="$1" port="$2"
    printf '%s/tor.pid\n' "$DATA_DIR/${code}_${port}"
}

stop_tor_node() {
    local code="$1" port="$2" pid_file pid
    pid_file=$(node_pid_file "$code" "$port")
    if [ -r "$pid_file" ]; then
        pid=$(tr -dc '0-9' < "$pid_file" 2>/dev/null || true)
        if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            for _ in 1 2 3 4 5; do
                kill -0 "$pid" 2>/dev/null || break
                sleep 1
            done
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi
    rm -f "$pid_file"
    # Compatibility cleanup for instances launched by older Sherlook builds.
    pkill -f "node_${code}_${port}\.conf" 2>/dev/null || true
}

run_tor_node() {
    local conf="$1" data_dir log_file code port verify_log launch_pid
    data_dir=$(awk '$1=="DataDirectory"{print $2; exit}' "$conf" 2>/dev/null || true)
    [ -n "$data_dir" ] || { echo -e "${RED}[!] DataDirectory missing in $conf.${NC}"; return 1; }
    mkdir -p "$data_dir"
    log_file="$data_dir/notices.log"
    verify_log="$data_dir/verify.log"
    touch "$log_file" "$verify_log" 2>/dev/null || true

    if id debian-tor >/dev/null 2>&1; then
        chown -R debian-tor:debian-tor "$data_dir" 2>/dev/null || true
    fi

    # Verify using the SAME account that will execute Tor. This catches
    # permissions/DataDirectory problems instead of reporting a misleading
    # generic config failure from a root-only validation.
    : > "$verify_log"
    if id debian-tor >/dev/null 2>&1 && command -v runuser >/dev/null 2>&1; then
        if ! runuser -u debian-tor -- tor -f "$conf" --verify-config >"$verify_log" 2>&1; then
            echo -e "${RED}[!] Tor config verification failed: $conf${NC}"
            echo -e "${YELLOW}[!] Exact verification error:${NC}"
            tail -n 60 "$verify_log" 2>/dev/null || true
            return 1
        fi
    else
        if ! tor -f "$conf" --verify-config >"$verify_log" 2>&1; then
            echo -e "${RED}[!] Tor config verification failed: $conf${NC}"
            tail -n 60 "$verify_log" 2>/dev/null || true
            return 1
        fi
    fi

    : > "$log_file"
    if id debian-tor >/dev/null 2>&1 && command -v runuser >/dev/null 2>&1; then
        runuser -u debian-tor -- tor -f "$conf" >>"$log_file" 2>&1 &
        launch_pid=$!
    elif id debian-tor >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
        sudo -u debian-tor tor -f "$conf" >>"$log_file" 2>&1 &
        launch_pid=$!
    else
        tor -f "$conf" >>"$log_file" 2>&1 &
        launch_pid=$!
    fi

    code=$(basename "$conf" | sed -n 's/^node_\([^_]*\)_.*$/\1/p')
    port=$(basename "$conf" | sed -n 's/^node_[^_]*_\([0-9]*\)\.conf$/\1/p')
    if [[ "$code" =~ ^[A-Z0-9]+$ && "$port" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "$launch_pid" > "$(node_pid_file "$code" "$port")"
        chmod 600 "$(node_pid_file "$code" "$port")"
    fi

    # Do not claim success just because the launcher process exists.
    # Wait briefly for the SOCKS listener; early Tor errors are preserved in log.
    local ready=0
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if ! kill -0 "$launch_pid" 2>/dev/null; then break; fi
        if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
            exec 3<&- 3>&-
            ready=1
            break
        fi
        sleep 1
    done

    if [ "$ready" -ne 1 ]; then
        echo -e "${RED}[!] Tor started but SOCKS $port did not become ready.${NC}"
        tail -n 80 "$log_file" 2>/dev/null || true
        stop_tor_node "$code" "$port"
        return 1
    fi
    return 0
}

node_process_running() {
    local code="$1" port="$2" pid_file pid args pattern
    pid_file=$(node_pid_file "$code" "$port")
    pattern="node_${code}_${port}\.conf"

    # Preferred path for 6.4.x nodes: the PID written by run_tor_node().
    if [ -r "$pid_file" ]; then
        pid=$(tr -dc '0-9' < "$pid_file" 2>/dev/null || true)
        if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
            args=$(ps -p "$pid" -o args= 2>/dev/null || true)
            if [[ "$args" == *"node_${code}_${port}.conf"* || "$args" == *"tor -f $BASE_DIR/node_${code}_${port}.conf"* ]]; then
                return 0
            fi
        fi
    fi

    # Compatibility path for nodes created by 6.3.x / V4.5, whose PID file
    # does not exist or was lost after an upgrade/reboot.
    pid=$(pgrep -f -- "$pattern" | head -n1 || true)
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        printf '%s\n' "$pid" > "$pid_file" 2>/dev/null || true
        chmod 600 "$pid_file" 2>/dev/null || true
        return 0
    fi
    return 1
}

append_bad_ip() {
    local bad_file="$1" ip="$2"
    is_valid_ipv4 "$ip" || return 0
    mkdir -p "$(dirname "$bad_file")"
    touch "$bad_file"
    grep -qxF "$ip" "$bad_file" 2>/dev/null || echo "$ip" >> "$bad_file"
    sort -u -o "$bad_file" "$bad_file" 2>/dev/null || true
}

country_name() {
    local code="${1^^}"
    local name=""
    if [ -r /usr/share/zoneinfo/iso3166.tab ]; then
        name=$(awk -v c="$code" '$1==c{$1=""; sub(/^ /,""); print; exit}' /usr/share/zoneinfo/iso3166.tab 2>/dev/null || true)
    fi
    [ -n "$name" ] && printf '%s\n' "$name" || printf '%s\n' "$code"
}

emoji_for_country() {
    local code="${1^^}"
    printf '%s' "${EMOJIS[$code]:-🌐}"
}

sync_dynamic_locations() {
    mkdir -p "$DATA_DIR" "$BASE_DIR"
    mapfile -t ORDER < <(printf '%s\n' "${!NODES[@]}" | sort -n)
    return 0
}

acquire_node_lock() {
    local code="$1" port="$2"
    local lock_file="$DATA_DIR/${code}_${port}/node.lock"
    mkdir -p "$(dirname "$lock_file")"
    exec {NODE_LOCK_FD}>"$lock_file"
    flock -n "$NODE_LOCK_FD"
}

release_node_lock() {
    if [[ -n "${NODE_LOCK_FD:-}" ]]; then
        flock -u "$NODE_LOCK_FD" 2>/dev/null || true
        eval "exec ${NODE_LOCK_FD}>&-" 2>/dev/null || true
        unset NODE_LOCK_FD
    fi
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[!] Error: Please run as root (sudo).${NC}"
        exit 1
    fi
}

refresh_onionoo_exit_catalog() {
    mkdir -p "$DATA_DIR"
    local tmp catalog now mtime age
    catalog="$LOCATION_CATALOG"
    now=$(date +%s)
    mtime=0
    [ -f "$catalog" ] && mtime=$(stat -c %Y "$catalog" 2>/dev/null || echo 0)
    age=$((now-mtime))
    if [ -s "$catalog" ] && (( age >= 0 && age < LOCATION_CACHE_TTL )); then
        return 0
    fi

    tmp=$(mktemp /tmp/sherlook_onionoo_catalog.XXXXXX) || return 1
    if ! curl -4 -fsS \
        --connect-timeout 5 \
        --max-time "$ONIONOO_TIMEOUT" \
        "${ONIONOO_URL}?flag=Exit&running=true&fields=country" \
        -o "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        return 1
    fi

    # Store one line per country: CC<TAB>running_exit_count.
    # The query is performed once per cache TTL instead of once per country.
    if ! jq -r '.relays // [] | .[]?.country // empty' "$tmp" 2>/dev/null \
        | tr '[:lower:]' '[:upper:]' \
        | awk 'NF{c[$1]++} END{for(k in c) print k "\t" c[k]}' \
        | sort > "${catalog}.new"; then
        rm -f "$tmp" "${catalog}.new"
        return 1
    fi
    mv -f "${catalog}.new" "$catalog"
    rm -f "$tmp"
    return 0
}

onionoo_exit_count() {
    local code="${1^^}" count
    refresh_onionoo_exit_catalog >/dev/null 2>&1 || true
    if [ -s "$LOCATION_CATALOG" ]; then
        count=$(awk -F '\t' -v c="$code" '$1==c{print $2; exit}' "$LOCATION_CATALOG" 2>/dev/null || true)
        [[ "$count" =~ ^[0-9]+$ ]] && { echo "$count"; return 0; }
    fi
    echo "-1"
}

check_country_exit_availability() {
    local code="$1"
    local name="$2"
    local count

    echo -e "${CYAN}[*] Checking Tor Exit availability for ${WHITE}$code - $name${CYAN}...${NC}"

    count=$(onionoo_exit_count "$code")

    if [ "$count" = "-1" ]; then
        echo -e "${YELLOW}[!] Onionoo availability check failed for $code.${NC}"
        echo -e "${YELLOW}[!] Continuing with Tor because the directory service could not be reached.${NC}"
        return 0
    fi

    if [ "$count" -lt "$ONIONOO_MIN_EXITS" ]; then
        echo -e "${RED}[-] No running Tor Exit relay was found for $code - $name.${NC}"
        echo -e "${YELLOW}[!] Location was NOT installed and no Tor instance will be started.${NC}"
        return 1
    fi

    echo -e "${GREEN}[+] $code - $name: $count running Tor Exit relay(s) reported by Onionoo.${NC}"
    return 0
}

cleanup_failed_node() {
    local code="$1"
    local out_port="$2"
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
    local inst_data_dir="$DATA_DIR/${code}_${out_port}"

    stop_tor_node "$code" "$out_port"
    sleep 1
    rm -f "$conf_file"
    rm -rf "$inst_data_dir"
}

node_is_installed() {
    local code="$1"
    local out_port="$2"
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
    local ip_file="$DATA_DIR/${code}_${out_port}/last_ip.txt"

    [ -f "$conf_file" ] &&
    pgrep -f "node_${code}_${out_port}.conf" > /dev/null &&
    [ -s "$ip_file" ] &&
    grep -Eq '^[0-9]+(\.[0-9]+){3}$' "$ip_file"
}

node_has_record() {
    local code="$1"
    local out_port="$2"
    [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ]
}

check_ip_quality() {
    local ip="$1"
    local expected_cc="${2^^}"
    local visual="${3:-0}"
    # fast=1 (default for routine auto-heal passes): ask only the first GeoIP
    # source and stop there if it already agrees with the expected country.
    # This is the common case (a healthy node matches on the first source),
    # so it avoids firing two extra curl processes + API calls per node on
    # every single auto-heal cycle. Full 3-source cross-checking still runs
    # whenever the quick source disagrees/is unavailable, or when the caller
    # explicitly asks for it (fast=0) -- e.g. right after deploying a node.
    local fast="${4:-1}"
    local tmpdir
    tmpdir=$(mktemp -d /tmp/sherlook_geo.XXXXXX) || { echo "1||GEOIP_UNAVAILABLE|"; return; }

    curl -4 -sS --connect-timeout 3 --max-time 6 "https://api.ipapi.is/?q=$ip" >"$tmpdir/a" 2>/dev/null & local p1=$!
    local p2="" p3=""
    if [ "$fast" != "1" ]; then
        curl -4 -sS --connect-timeout 3 --max-time 6 "https://ipwho.is/$ip" >"$tmpdir/b" 2>/dev/null & p2=$!
        curl -4 -sS --connect-timeout 3 --max-time 6 "https://ipapi.co/$ip/json/" >"$tmpdir/c" 2>/dev/null & p3=$!
    fi
    if [ "$visual" = "1" ]; then
        while kill -0 "$p1" 2>/dev/null || { [ -n "$p2" ] && kill -0 "$p2" 2>/dev/null; } || { [ -n "$p3" ] && kill -0 "$p3" 2>/dev/null; }; do
            ui_spin_frame "Verifying country / IP ${ip}"
            sleep 0.12
        done
    fi
    wait "$p1" 2>/dev/null || true
    [ -n "$p2" ] && wait "$p2" 2>/dev/null
    [ -n "$p3" ] && wait "$p3" 2>/dev/null
    [ "$visual" = "1" ] && printf '\r\033[K' >&2

    local api1 cc1
    api1=$(cat "$tmpdir/a" 2>/dev/null || true)
    cc1=$(printf '%s' "$api1" | jq -r '.location.country_code // .country_code // empty' 2>/dev/null | tr '[:lower:]' '[:upper:]')

    if [ "$fast" = "1" ] && [ "$cc1" = "$expected_cc" ]; then
        # Quick source already confirms the expected exit country -- treat
        # like a single-source pass without paying for two more API calls.
        local risk_level_fast
        risk_level_fast=$(jq -r '.abuser_score // .abuse_score // empty' "$tmpdir/a" 2>/dev/null || true)
        rm -rf "$tmpdir"
        if [[ "$risk_level_fast" =~ (High|VERY_HIGH|Very.High) ]]; then
            echo "1|${cc1}|HIGH_RISK|${cc1}"
        else
            echo "0|${cc1}|GEOIP_SINGLE_SOURCE|${cc1}"
        fi
        return
    fi

    # Either the fast path wasn't used, or the quick source didn't confirm
    # the expected country -- escalate to the full 3-source cross-check so
    # we never *weaken* accuracy, only skip redundant calls on the easy path.
    if [ "$fast" = "1" ]; then
        curl -4 -sS --connect-timeout 3 --max-time 6 "https://ipwho.is/$ip" >"$tmpdir/b" 2>/dev/null & p2=$!
        curl -4 -sS --connect-timeout 3 --max-time 6 "https://ipapi.co/$ip/json/" >"$tmpdir/c" 2>/dev/null & p3=$!
        wait "$p2" "$p3" 2>/dev/null || true
    fi

    local api2 api3 cc2 cc3
    api2=$(cat "$tmpdir/b" 2>/dev/null || true)
    api3=$(cat "$tmpdir/c" 2>/dev/null || true)

    cc2=$(printf '%s' "$api2" | jq -r '.country_code // .countryCode // empty' 2>/dev/null | tr '[:lower:]' '[:upper:]')
    cc3=$(printf '%s' "$api3" | jq -r '.country_code // empty' 2>/dev/null | tr '[:lower:]' '[:upper:]')

    local total=0 expected_hits=0 other_hits=0 high_risk=0 cc
    for cc in "$cc1" "$cc2" "$cc3"; do
        [ -n "$cc" ] || continue
        total=$((total+1))
        if [ "$cc" = "$expected_cc" ]; then
            expected_hits=$((expected_hits+1))
        else
            other_hits=$((other_hits+1))
        fi
    done

    local risk_level=""
    risk_level=$(jq -r '.abuser_score // .abuse_score // empty' "$tmpdir/a" 2>/dev/null || true)
    if [[ "$risk_level" =~ (High|VERY_HIGH|Very.High) ]]; then high_risk=1; fi

    local bad=0 reason=""
    if [ "$total" -eq 0 ]; then
        bad=0
        reason="GEOIP_UNAVAILABLE"
    elif [ "$expected_hits" -ge 2 ]; then
        bad=0
        reason="VERIFIED_${expected_hits}OF3"
    elif [ "$other_hits" -ge 2 ]; then
        bad=1
        reason="COUNTRY_MISMATCH"
    elif [ "$total" -eq 1 ] && [ "$expected_hits" -eq 1 ]; then
        bad=0
        reason="GEOIP_SINGLE_SOURCE"
    else
        bad=1
        reason="GEOIP_CONFLICT"
    fi

    if [ "$high_risk" -eq 1 ]; then
        bad=1
        reason="HIGH_RISK"
    fi

    local actual_cc=""
    if [ "$expected_hits" -ge 2 ]; then
        actual_cc="$expected_cc"
    elif [ -n "$cc1" ]; then
        actual_cc="$cc1"
    elif [ -n "$cc2" ]; then
        actual_cc="$cc2"
    elif [ -n "$cc3" ]; then
        actual_cc="$cc3"
    fi

    local seen=""
    for cc in "$cc1" "$cc2" "$cc3"; do
        [ -z "$cc" ] && continue
        [ -z "$seen" ] && seen="$cc" || seen="$seen,$cc"
    done
    rm -rf "$tmpdir"
    echo "${bad}|${actual_cc}|${reason}|${seen}"
}

write_node_conf() {
    local conf_file="$1" out_port="$2" _control_port="$3" _hashed_pass="$4" inst_data_dir="$5" code="$6"
    local route_code
    route_code=$(node_route_code "$code" "$out_port")

    # Proven minimal client torrc. Do not put dynamic IP exclusions,
    # ControlPort authentication, or diagnostic logging directives here.
    # Tor receives stdout/stderr through run_tor_node(), so a broken torrc
    # can never be hidden behind /dev/null.
    cat > "$conf_file" <<EOF
SocksPort 127.0.0.1:$out_port
DataDirectory $inst_data_dir
ExitNodes {$route_code}
StrictNodes 1
RunAsDaemon 0
EOF

    if bridge_available; then
        bridge_validate || return 1
        {
            echo 'UseBridges 1'
            echo 'ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy'
            cat "$BRIDGE_FILE"
        } >> "$conf_file"
    fi
    chown root:debian-tor "$conf_file" 2>/dev/null || true
    chmod 640 "$conf_file"
}

health_check_node() {
    local code="$1" name="$2" out_port="$3" silent="${4:-1}" repair="${5:-1}"
    # full=1: run the full 3-source GeoIP cross-check (used every
    # HEALTH_FULL_RECHECK_EVERY cycles). full=0 (default): use the fast
    # 1-source-with-escalation path in check_ip_quality -- cheap on CPU/
    # network for the common case where the node is already healthy.
    local full="${6:-0}"
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf" inst_data_dir="$DATA_DIR/${code}_${out_port}" ip_file="$DATA_DIR/${code}_${out_port}/last_ip.txt"
    [ -f "$conf_file" ] || return 0
    if node_quarantine_active "$code" "$out_port"; then return 4; fi
    local bootstrap_raw bootstrap_pct bootstrap_tag current_ip reason expected_route result bad actual seen
    bootstrap_raw=$(bootstrap_status "$code" "$out_port" "$inst_data_dir"); bootstrap_pct=${bootstrap_raw%%|*}; bootstrap_tag=${bootstrap_raw#*|}
    if ! node_process_running "$code" "$out_port"; then
        state_set "$code" "$out_port" DEAD "" "$bootstrap_pct" "PROCESS_DOWN"
        if [ "$repair" = "1" ]; then
            rotate_one_node "$code" "$name" "$out_port" "$silent"; local rc=$?
            (( rc == 0 )) && quarantine_clear "$code" "$out_port" || quarantine_record_failure "$code" "$out_port" "PROCESS_DOWN"
            return $rc
        fi
        return 1
    fi
    current_ip=$(get_node_ip "$out_port")
    if ! is_valid_ipv4 "$current_ip"; then
        state_set "$code" "$out_port" "SOCKS_DEAD" "" "$bootstrap_pct" "SOCKS_UNREACHABLE"
        if [ "$repair" = "1" ]; then
            rotate_one_node "$code" "$name" "$out_port" "$silent"; local rc=$?
            (( rc == 0 )) && quarantine_clear "$code" "$out_port" || quarantine_record_failure "$code" "$out_port" "SOCKS_UNREACHABLE"
            return $rc
        fi
        return 1
    fi
    expected_route=$(node_route_code "$code" "$out_port")
    local geo_fast=1; [ "$full" = "1" ] && geo_fast=0
    result=$(check_ip_quality "$current_ip" "$expected_route" 0 "$geo_fast"); IFS='|' read -r bad actual reason seen <<< "$result"
    # A live public IP is useful even when an external GeoIP provider is
    # temporarily unavailable. Keep the IP visible and mark the node as
    # ONLINE_UNVERIFIED instead of pretending that it is fully verified.
    if [ "$reason" = "GEOIP_UNAVAILABLE" ]; then
        printf '%s\n' "$current_ip" > "$ip_file"
        quarantine_clear "$code" "$out_port"
        [ "$bootstrap_pct" -lt 100 ] && bootstrap_pct=100
        state_set "$code" "$out_port" ONLINE_UNVERIFIED "$current_ip" "$bootstrap_pct" "GEOIP_UNAVAILABLE"
        return 2
    fi

    if [ "$bad" != "0" ]; then
        state_set "$code" "$out_port" "EXIT_GEOIP_FAIL" "$current_ip" "$bootstrap_pct" "$reason"
        if [ "$repair" = "1" ]; then
            rotate_one_node "$code" "$name" "$out_port" "$silent"; local rc=$?
            (( rc == 0 )) && quarantine_clear "$code" "$out_port" || quarantine_record_failure "$code" "$out_port" "$reason"
            return $rc
        fi
        return 1
    fi
    printf '%s\n' "$current_ip" > "$ip_file"
    quarantine_clear "$code" "$out_port"
    # A verified public IP through SOCKS proves a usable circuit. When the
    # bootstrap log is unavailable (common after upgrading a legacy node),
    # report it as operational rather than UNKNOWN.
    [ "$bootstrap_pct" -lt 100 ] && bootstrap_pct=100
    state_set "$code" "$out_port" ONLINE "$current_ip" "$bootstrap_pct" "VERIFIED:${seen}"
    return 0
}

background_auto_heal() {
    # full=1 forces the full 3-source GeoIP cross-check for every node this
    # pass (used every HEALTH_FULL_RECHECK_EVERY cycles by the daemon, and
    # for one-off manual runs via --auto-heal).
    local full="${1:-1}"
    check_root
    sync_dynamic_locations
    compute_effective_parallel
    if bridge_available; then bridge_validate || return 1; fi
    local idx details code name out_port running=0
    local -a pids=()
    for idx in "${ORDER[@]}"; do
        details="${NODES[$idx]}"; IFS=':' read -r code name out_port <<< "$details"
        [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] || continue
        health_check_node "$code" "$name" "$out_port" 1 1 "$full" & pids+=("$!"); running=$((running+1))
        if (( running >= EFFECTIVE_PARALLEL )); then
            wait "${pids[0]}" 2>/dev/null || true; pids=("${pids[@]:1}"); running=$((running-1))
        fi
    done
    for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
}

auto_heal_daemon() {
    check_root
    trap 'exit 0' INT TERM HUP
    local cycle=0 pass_start pass_end elapsed sleep_for full
    while true; do
        cycle=$((cycle+1))
        full=0
        # First pass after startup, and then every HEALTH_FULL_RECHECK_EVERY
        # cycles, do the thorough 3-source recheck; the rest are cheap.
        if (( cycle == 1 || cycle % HEALTH_FULL_RECHECK_EVERY == 0 )); then full=1; fi
        pass_start=$(date +%s)
        background_auto_heal "$full" || true
        pass_end=$(date +%s)
        elapsed=$(( pass_end - pass_start ))
        sleep_for=$(( AUTO_HEAL_INTERVAL - elapsed ))
        # If a pass already took longer than the interval (large node count,
        # slow network), don't stack the next pass right on top of it --
        # still give the CPU a short breather instead of hammering in a
        # tight loop.
        (( sleep_for < 3 )) && sleep_for=3
        sleep "$sleep_for"
    done
}

if [ "${1:-}" = "--version" ]; then
    printf '%s\n' "$SHERLOOK_VERSION"
    exit 0
fi

if [ "${1:-}" = "--auto-heal" ]; then
    background_auto_heal
    exit 0
fi
if [ "${1:-}" = "--auto-heal-daemon" ]; then
    auto_heal_daemon
    exit 0
fi


# ================= V6.5.0 HEALTH / BRIDGE / PANEL SAFETY =================

node_dir() { printf '%s\n' "$DATA_DIR/${1}_${2}"; }
node_index_by_code() {
    local wanted="${1^^}" idx c n p
    for idx in "${ORDER[@]}"; do
        IFS=":" read -r c n p <<< "${NODES[$idx]}"
        [ "${c^^}" = "$wanted" ] && { printf "%s\n" "$idx"; return 0; }
    done
    return 1
}

node_state_file() { printf '%s/state.env\n' "$(node_dir "$1" "$2")"; }
node_quarantine_file() { printf '%s/quarantine.env\n' "$(node_dir "$1" "$2")"; }

state_set() {
    local code="$1" port="$2" status="$3" ip="${4:-}" bootstrap="${5:-0}" reason="${6:-}"
    local dir; dir=$(node_dir "$code" "$port"); mkdir -p "$dir"
    umask 077
    cat > "$(node_state_file "$code" "$port")" <<EOF
STATUS=$(printf '%q' "$status")
IP=$(printf '%q' "$ip")
BOOTSTRAP=$(printf '%q' "$bootstrap")
REASON=$(printf '%q' "$reason")
UPDATED_AT=$(printf '%q' "$(date +%s)")
EOF
}

state_get() {
    local code="$1" port="$2" f; f=$(node_state_file "$code" "$port")
    [ -r "$f" ] || return 1
    # shellcheck disable=SC1090
    source "$f" 2>/dev/null || return 1
}

quarantine_clear() {
    rm -f "$(node_quarantine_file "$1" "$2")"
}

quarantine_record_failure() {
    local code="$1" port="$2" reason="${3:-HEALTH_FAIL}" dir now fails delay
    dir=$(node_dir "$code" "$port"); mkdir -p "$dir"
    now=$(date +%s)
    fails=0
    if [ -r "$(node_quarantine_file "$code" "$port")" ]; then
        # shellcheck disable=SC1090
        source "$(node_quarantine_file "$code" "$port")" 2>/dev/null || true
        fails=${FAIL_COUNT:-0}
    fi
    fails=$((fails+1))
    delay=$QUARANTINE_BASE
    if (( fails > 1 )); then delay=$(( QUARANTINE_BASE << (fails-1) )); fi
    (( delay > QUARANTINE_MAX )) && delay=$QUARANTINE_MAX
    umask 077
    cat > "$(node_quarantine_file "$code" "$port")" <<EOF
FAIL_COUNT=$fails
UNTIL=$((now+delay))
REASON=$(printf '%q' "$reason")
EOF
    state_set "$code" "$port" "QUARANTINED($fails)" "" 0 "$reason"
}

node_quarantine_active() {
    local code="$1" port="$2" f now until
    f=$(node_quarantine_file "$code" "$port")
    [ -r "$f" ] || return 1
    # shellcheck disable=SC1090
    source "$f" 2>/dev/null || return 1
    now=$(date +%s); until=${UNTIL:-0}
    if (( until > now )); then return 0; fi
    rm -f "$f"
    return 1
}

ctrl_query() {
    local port="$1" pass="$2" command="$3" timeout_sec="${4:-5}" out
    out=$(timeout "$timeout_sec" bash -c '
        exec 3<>/dev/tcp/127.0.0.1/"$0" || exit 10
        printf "AUTHENTICATE \\\"%s\\\"\\r\\n%s\\r\\nQUIT\\r\\n" "$1" "$2" >&3
        cat <&3
    ' "$port" "$pass" "$command" 2>/dev/null || true)
    printf '%s\n' "$out"
}

bootstrap_status() {
    local code="$1" port="$2" inst_data_dir="$3" log_file="$inst_data_dir/notices.log" ctrl_file="$inst_data_dir/control.env"
    local progress=0 tag="not_started" line

    # 6.4.x node torrc intentionally has no ControlPort. Prefer Tor's own
    # bootstrap notices, which also work for legacy nodes that do not have
    # control.env anymore.
    if [ -r "$log_file" ]; then
        line=$(grep -Eo 'Bootstrapped [0-9]+%[^$]*' "$log_file" 2>/dev/null | tail -n1 || true)
        if [[ "$line" =~ Bootstrapped[[:space:]]+([0-9]+)% ]]; then
            progress="${BASH_REMATCH[1]}"
            tag="bootstrap"
        fi
        local last_reason
        last_reason=$(grep -Ei 'WARN|ERR|failed|Unable|problem|connection|TLS|guard' "$log_file" 2>/dev/null | tail -n1 || true)
        if [ "$progress" -lt 100 ] && [ -n "$last_reason" ]; then
            tag=$(printf '%s' "$last_reason" | tr -s ' ' | cut -c1-90)
        fi
    fi

    # Backward compatibility: legacy nodes that still have a control.env can
    # provide a more precise bootstrap percentage when ControlPort answers.
    if [ -r "$ctrl_file" ]; then
        # shellcheck disable=SC1090
        source "$ctrl_file" 2>/dev/null || true
        if [ -n "${CTRL_PORT:-}" ] && [ -n "${CTRL_PASS:-}" ]; then
            local out cp ct
            out=$(ctrl_query "$CTRL_PORT" "$CTRL_PASS" 'GETINFO status/bootstrap-phase' 3)
            cp=$(printf '%s\n' "$out" | grep -oE 'PROGRESS=[0-9]+' | tail -n1 | cut -d= -f2 || true)
            ct=$(printf '%s\n' "$out" | grep -oE 'TAG=[^ ]+' | tail -n1 | cut -d= -f2 || true)
            [[ "$cp" =~ ^[0-9]+$ ]] && progress="$cp"
            [ -n "$ct" ] && tag="$ct"
        fi
    fi
    printf '%s|%s\n' "$progress" "$tag"
}

bridge_available() { [ "$BRIDGE_MODE" = "1" ] && [ -s "$BRIDGE_FILE" ]; }

bridge_validate() {
    if [ "$BRIDGE_MODE" = "1" ]; then
        command -v obfs4proxy >/dev/null 2>&1 || {
            echo -e "${RED}[!] Bridge mode enabled but obfs4proxy is missing.${NC}"
            return 1
        }
        [ -s "$BRIDGE_FILE" ] || {
            echo -e "${RED}[!] Bridge mode enabled but $BRIDGE_FILE is empty.${NC}"
            return 1
        }
    fi
    return 0
}

compute_effective_parallel() {
    EFFECTIVE_PARALLEL=$AUTO_HEAL_PARALLEL
    if bridge_available; then
        EFFECTIVE_PARALLEL=$BRIDGE_PARALLEL
        if (( EFFECTIVE_PARALLEL < 1 )); then EFFECTIVE_PARALLEL=1; fi
        if (( EFFECTIVE_PARALLEL > AUTO_HEAL_PARALLEL )); then EFFECTIVE_PARALLEL=$AUTO_HEAL_PARALLEL; fi
    fi
}

panel_conf_write() {
    mkdir -p "$BASE_DIR"; umask 077
    cat > "$PANEL_CONF" <<EOF
URL=$(printf '%q' "${URL:-}")
USER=$(printf '%q' "${USER:-}")
TOKEN=$(printf '%q' "${TOKEN:-}")
PANEL_CORE_ID=$(printf '%q' "${PANEL_CORE_ID:-}")
PANEL_INBOUND_INDEX=${PANEL_INBOUND_INDEX:-1}
PANEL_HOST_INDEX=${PANEL_HOST_INDEX:-0}
PANEL_AUTO_SYNC=${PANEL_AUTO_SYNC:-1}
EOF
    chmod 600 "$PANEL_CONF"
}

panel_conf_safe_load() {
    [ -r "$PANEL_CONF" ] || return 1
    # shellcheck disable=SC1090
    source "$PANEL_CONF" 2>/dev/null || return 1
    return 0
}

panel_request() {
    local method="$1" endpoint="$2" body_file="${3:-}" response_file="$4"
    local -a args=(curl -4 -skS --connect-timeout "$PANEL_CONNECT_TIMEOUT" --max-time "$PANEL_REQUEST_TIMEOUT"
        -X "$method" "$URL$endpoint"
        -H "Authorization: Bearer $TOKEN"
        -H 'Accept: application/json')
    if [ -n "$body_file" ]; then
        args+=( -H 'Content-Type: application/json' --data-binary "@$body_file" )
    fi
    "${args[@]}" -o "$response_file" -w '%{http_code}' 2>/dev/null || printf '000'
}

panel_http_ok() {
    [[ "$1" =~ ^2[0-9][0-9]$ ]]
}

panel_lock_acquire() {
    mkdir -p "$BASE_DIR"
    exec {PANEL_LOCK_FD}>"$PANEL_LOCK_FILE" || return 1
    flock -x "$PANEL_LOCK_FD"
}

panel_lock_release() {
    if [[ -n "${PANEL_LOCK_FD:-}" ]]; then
        flock -u "$PANEL_LOCK_FD" 2>/dev/null || true
        eval "exec ${PANEL_LOCK_FD}>&-" 2>/dev/null || true
        unset PANEL_LOCK_FD
    fi
}

panel_auth_preflight() {
    panel_conf_safe_load || return 1
    [ -n "${URL:-}" ] && [ -n "${TOKEN:-}" ] || return 1
    local tmp code
    tmp=$(mktemp /tmp/sherlook-panel-auth.XXXXXX) || return 1
    code=$(panel_request GET /api/cores "" "$tmp")
    rm -f "$tmp"
    case "$code" in
        200) return 0 ;;
        401) echo -e "${YELLOW}[!] Panel session expired (HTTP 401). Please login again from option 9.${NC}" >&2; return 2 ;;
        403) echo -e "${RED}[!] Token is valid but lacks Core read permission (HTTP 403). Use an admin/suitable API credential.${NC}" >&2; return 1 ;;
        *) return 1 ;;
    esac
}

panel_core_fetch() {
    local core_file="$1"; CORE_API_URL=""; PANEL_CORE_RESPONSE_FILE="$BASE_DIR/remote_core_response.json"
    local list_file detail_file code core_id configured
    list_file=$(mktemp /tmp/sherlook-cores.XXXXXX) || return 1
    detail_file=$(mktemp /tmp/sherlook-core.XXXXXX) || { rm -f "$list_file"; return 1; }
    code=$(panel_request GET /api/cores "" "$list_file")
    if [ "$code" != "200" ]; then
        echo -e "${RED}[!] GET /api/cores failed: HTTP $code${NC}" >&2
        rm -f "$list_file" "$detail_file"; return 1
    fi
    configured="${PANEL_CORE_ID:-}"
    core_id=$(jq -r --arg wanted "$configured" '
        if ($wanted|length)>0 and any(.cores[]?; ((.id|tostring)==$wanted)) then $wanted
        else (.cores[0].id // empty) end' "$list_file" 2>/dev/null)
    if [[ ! "$core_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}[!] No PasarGuard Core was found through /api/cores.${NC}" >&2
        rm -f "$list_file" "$detail_file"; return 1
    fi
    code=$(panel_request GET "/api/core/$core_id" "" "$detail_file")
    if [ "$code" != "200" ] || ! jq -e 'type=="object" and (.config|type=="object")' "$detail_file" >/dev/null 2>&1; then
        echo -e "${RED}[!] GET /api/core/$core_id failed or returned an invalid CoreResponse (HTTP $code).${NC}" >&2
        rm -f "$list_file" "$detail_file"; return 1
    fi
    jq -c '.config' "$detail_file" > "$core_file" || { rm -f "$list_file" "$detail_file"; return 1; }
    cp -f "$detail_file" "$PANEL_CORE_RESPONSE_FILE"
    CORE_API_URL="$URL/api/core/$core_id"
    PANEL_CORE_ID="$core_id"
    panel_conf_write >/dev/null 2>&1 || true
    rm -f "$list_file" "$detail_file"
    return 0
}

panel_load_hosts() {
    local out="$1" tmp code
    tmp=$(mktemp /tmp/sherlook-hosts.XXXXXX) || return 1
    code=$(panel_request GET /api/hosts "" "$tmp")
    if [ "$code" = "200" ] && jq -e 'type=="array"' "$tmp" >/dev/null 2>&1; then
        mv -f "$tmp" "$out"; return 0
    fi
    echo "[]" > "$out"
    echo -e "${YELLOW}[!] GET /api/hosts failed: HTTP $code${NC}" >&2
    rm -f "$tmp"
    return 1
}

panel_validate_templates() {
    local core_file="$1" hosts_file="$2" in_idx=$(( ${PANEL_INBOUND_INDEX:-1} - 1 )) host_idx=${PANEL_HOST_INDEX:-0}
    local n
    n=$(jq '.inbounds // [] | length' "$core_file" 2>/dev/null || echo 0)
    if (( in_idx < 0 || in_idx >= n )); then
        echo -e "${YELLOW}[!] Saved Panel inbound template is stale. Please reselect it.${NC}"
        return 1
    fi
    local proto; proto=$(jq -r ".inbounds[$in_idx].protocol // \"\"" "$core_file")
    [ -n "$proto" ] || return 1
    if [ -n "$hosts_file" ] && [ -s "$hosts_file" ] && (( host_idx > 0 )); then
        n=$(jq 'length' "$hosts_file" 2>/dev/null || echo 0)
        if (( host_idx > n )); then
            echo -e "${YELLOW}[!] Saved Panel host/SNI template is stale. Please reselect it.${NC}"
            return 1
        fi
        local addr; addr=$(jq -r ".[$((host_idx-1))].address | if type==\"array\" and length>0 then .[0] elif type==\"string\" then . else \"\" end" "$hosts_file" 2>/dev/null || true)
        [ -n "$addr" ] || { echo -e "${YELLOW}[!] Saved Panel host/SNI template has no usable address.${NC}"; return 1; }
    fi
    return 0
}

panel_prepare_templates() {
    panel_auth_preflight || return $?
    local core_file="$BASE_DIR/remote_core.json" hosts_file="$BASE_DIR/panel_hosts.json"
    panel_core_fetch "$core_file" || { echo -e "${RED}[!] Could not locate a panel Core API.${NC}"; return 1; }
    panel_load_hosts "$hosts_file"
    panel_validate_templates "$core_file" "$hosts_file" 2>/dev/null || true
    local in_count; in_count=$(jq '.inbounds | length' "$core_file" 2>/dev/null || echo 0)
    echo -e "${CYAN}Select inbound template:${NC}"
    local i tag port proto
    for ((i=0;i<in_count;i++)); do
        tag=$(jq -r ".inbounds[$i].tag // \"\"" "$core_file"); port=$(jq -r ".inbounds[$i].port // \"\"" "$core_file"); proto=$(jq -r ".inbounds[$i].protocol // \"\"" "$core_file")
        printf '  [%02d] %-10s port=%-6s %s\n' "$((i+1))" "$proto" "$port" "$tag"
    done
    read -r -p 'Inbound template: ' PANEL_INBOUND_INDEX < /dev/tty || return 1
    [[ "$PANEL_INBOUND_INDEX" =~ ^[0-9]+$ ]] || return 1
    local host_count; host_count=$(jq 'length' "$hosts_file" 2>/dev/null || echo 0)
    PANEL_HOST_INDEX=0
    if (( host_count > 0 )); then
        echo -e "${CYAN}Select host/SNI template (0=derive from inbound):${NC}"
        for ((i=0;i<host_count;i++)); do
            local rem addr; rem=$(jq -r ".[$i].remark // \"\"" "$hosts_file"); addr=$(jq -r ".[$i].address | if type==\"array\" and length>0 then .[0] elif type==\"string\" then . else \"\" end" "$hosts_file")
            printf '  [%02d] %-24s %s\n' "$((i+1))" "$rem" "$addr"
        done
        read -r -p 'Host template [0]: ' PANEL_HOST_INDEX < /dev/tty || return 1
        [[ "$PANEL_HOST_INDEX" =~ ^[0-9]+$ ]] || return 1
    fi
    PANEL_AUTO_SYNC=1
    panel_conf_write
    echo -e "${GREEN}[+] Panel templates saved securely (chmod 600, password not stored).${NC}"
}

# Removes the given node IDs from the panel (Core inbounds/outbounds/routing
# + hosts). Every failure path now prints WHY it failed, and the return code
# tells the caller exactly what state the panel ended up in, so callers can
# decide whether it is safe to also wipe the local node record:
#   0 = fully removed from panel (core + hosts confirmed)
#   1 = nothing was removed from panel (safe to retry later, local record
#       should be left alone)
#   2 = partially removed (core config updated, but the hosts/SNI entries
#       could not be confirmed removed) -- needs a manual/second look
panel_meta_file() { printf '%s/panel_meta.json' "$(node_dir "$1" "$2")"; }
panel_tombstone_file() { printf '%s/panel_tombstones/%s.json' "$BASE_DIR" "$1"; }
panel_meta_any_file() {
    local code="$1" port="$2" idx="${3:-}" f
    f="$(panel_meta_file "$code" "$port")"
    [ -r "$f" ] && { printf '%s\n' "$f"; return 0; }
    [ -n "$idx" ] && [ -r "$(panel_tombstone_file "$idx")" ] && { printf '%s\n' "$(panel_tombstone_file "$idx")"; return 0; }
    return 1
}

panel_meta_write() {
    local code="$1" port="$2" core_id="$3" in_tag="$4" out_tag="$5" inbound_port="$6" host_id="${7:-}"
    local dir; dir=$(node_dir "$code" "$port"); mkdir -p "$dir"
    jq -n --argjson core_id "$core_id" --arg in_tag "$in_tag" --arg out_tag "$out_tag" \
        --argjson inbound_port "$inbound_port" --arg host_id "$host_id" \
        '{core_id:$core_id,inbound_tag:$in_tag,outbound_tag:$out_tag,inbound_port:$inbound_port,host_id:(if $host_id=="" then null else ($host_id|tonumber) end),updated_at:(now|floor)}' \
        > "$(panel_meta_file "$code" "$port")"
    chmod 600 "$(panel_meta_file "$code" "$port")"
}


panel_find_host_id() {
    local hosts_file="$1" in_tag="$2" out_port="${3:-}" remark="${4:-}"
    jq -r --arg t "$in_tag" --arg p "$out_port" --arg r "$remark" '
        first(.[] | select((.inbound_tag // "")==$t) | select(($p=="" or ((.port//0|tostring)==$p))) | .id) //
        first(.[] | select(($r!="") and ((.remark//"")==$r)) | .id) // empty' "$hosts_file" 2>/dev/null
}

panel_core_build_delete() {
    local core_file="$1" out="$2" patterns="$3"
    jq --rawfile pattern_blob "$patterns" '
        ($pattern_blob | split("\n") | map(select(length>0)|split("\t"))) as $p |
        def drop_in($tag): ($tag != null and ($tag|tostring|length)>0) and any($p[]; . as $x | ($tag|tostring) == $x[0]);
        def drop_out($tag): ($tag != null and ($tag|tostring|length)>0) and any($p[]; . as $x | ($tag|tostring) == $x[1]);
        .inbounds = [(.inbounds // [])[] | select(drop_in(.tag)|not)] |
        .outbounds = [(.outbounds // [])[] | select(drop_out(.tag)|not)] |
        .routing = (.routing // {rules:[]}) |
        .routing.rules = [(.routing.rules // [])[] |
            select(any(.inboundTag[]?; drop_in(.)) | not) |
            select(drop_out(.outboundTag)|not)]' "$core_file" > "$out"
}

panel_delete_node_ids() {
    panel_auth_preflight || return $?
    panel_lock_acquire || { echo -e "${RED}[!] Could not acquire Panel write lock.${NC}"; return 1; }
    local rc=1
    local core_file="$BASE_DIR/remote_core.json" hosts_file="$BASE_DIR/panel_hosts.json" patterns="$BASE_DIR/panel_delete_patterns.tsv" new_core="$BASE_DIR/panel_core_delete.tmp.json"
    local delete_hosts_json="$BASE_DIR/panel_delete_hosts.json" core_payload="$BASE_DIR/panel_delete_core_payload.json" response="$BASE_DIR/panel_delete_response.json"
    trap 'panel_lock_release' RETURN
    if ! panel_core_fetch "$core_file"; then panel_lock_release; trap - RETURN; return 1; fi
    panel_load_hosts "$hosts_file" || true
    : > "$patterns"
    local idx code name out_port safe in_tag out_tag host_id meta_file
    local -a host_ids=()
    for idx in "$@"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        safe=$(printf '%s' "$name" | tr -d ' ' | tr -cd 'a-zA-Z0-9-')
        meta_file=$(panel_meta_any_file "$code" "$out_port" "$idx" 2>/dev/null || true)
        in_tag=""; out_tag=""; host_id=""
        if [ -n "$meta_file" ]; then
            in_tag=$(jq -r '.inbound_tag // empty' "$meta_file" 2>/dev/null || true)
            out_tag=$(jq -r '.outbound_tag // empty' "$meta_file" 2>/dev/null || true)
            host_id=$(jq -r '.host_id // empty' "$meta_file" 2>/dev/null || true)
        fi
        if [ -z "$in_tag" ]; then
            in_tag=$(jq -r --arg c "$code" --arg s "$safe" 'first(.inbounds[]? | select((.tag//"") | startswith($c+"-"+$s+"-IN-")) | .tag) // empty' "$core_file")
        fi
        if [ -z "$out_tag" ]; then
            out_tag=$(jq -r --arg c "$code" --arg s "$safe" --arg p "$out_port" 'first(.outbounds[]? | select((.tag//"")==($c+"-"+$s+"-OUT-"+$p)) | .tag) // empty' "$core_file")
        fi
        [ -n "$in_tag" ] && printf '%s\t%s\n' "$in_tag" "$out_tag" >> "$patterns"
        if [ -z "$host_id" ] && [ -s "$hosts_file" ] && [ -n "$in_tag" ]; then host_id=$(panel_find_host_id "$hosts_file" "$in_tag" "$out_port" "${EMOJIS[$code]} $name"); fi
        [[ "$host_id" =~ ^[0-9]+$ ]] && host_ids+=("$host_id")
    done
    if [ -s "$patterns" ] && ! panel_core_build_delete "$core_file" "$new_core" "$patterns"; then
        echo -e "${RED}[!] Failed to build the new Xray Core configuration.${NC}"; panel_lock_release; trap - RETURN; return 1
    fi
    local original_core_name core_type exclude_tags fallback_tags
    original_core_name=$(jq -r '.name // empty' "$PANEL_CORE_RESPONSE_FILE")
    core_type=$(jq -c '.type // null' "$PANEL_CORE_RESPONSE_FILE")
    exclude_tags=$(jq -c '.exclude_inbound_tags // []' "$PANEL_CORE_RESPONSE_FILE")
    fallback_tags=$(jq -c '.fallbacks_inbound_tags // []' "$PANEL_CORE_RESPONSE_FILE")
    if [ ! -s "$patterns" ]; then
        cp -f "$core_file" "$new_core"
    fi
    jq -n --arg name "$original_core_name" --argjson config "$(cat "$new_core")" --argjson type "$core_type" \
        --argjson ex "$exclude_tags" --argjson fb "$fallback_tags" \
        '{name:$name,config:$config,type:$type,exclude_inbound_tags:$ex,fallbacks_inbound_tags:$fb}' > "$core_payload"
    local code_http
    code_http=$(panel_request PUT "/api/core/${PANEL_CORE_ID}?restart_nodes=true" "$core_payload" "$response")
    if ! panel_http_ok "$code_http"; then
        echo -e "${RED}[!] Panel Core update failed: HTTP $code_http${NC}"; [ -s "$response" ] && jq -r '.detail // .' "$response" 2>/dev/null | head -n 8 >&2
        panel_lock_release; trap - RETURN; return 1
    fi
    # Verify the core change on the server, not by trusting the HTTP code alone.
    if [ "$PANEL_VERIFY_AFTER_WRITE" = "1" ]; then
        local verify="$BASE_DIR/panel_core_verify.json"; code_http=$(panel_request GET "/api/core/${PANEL_CORE_ID}" "" "$verify")
        if [ "$code_http" != "200" ]; then echo -e "${RED}[!] Core update returned success but could not be verified (HTTP $code_http).${NC}"; panel_lock_release; trap - RETURN; return 1; fi
        local still=0 t
        for t in $(cut -f1 "$patterns" 2>/dev/null); do
            if jq -e --arg t "$t" 'any(.config.inbounds[]?; .tag==$t) or any(.config.outbounds[]?; .tag==$t) or any(.config.routing.rules[]?.inboundTag[]?; .==$t) or any(.config.routing.rules[]?.outboundTag?; .==$t)' "$verify" >/dev/null 2>&1; then
                still=1
                break
            fi
        done
        if [ "$still" -ne 0 ]; then
            echo -e "${RED}[!] Core API returned success but the requested tags still exist; refusing to finalize deletion.${NC}"
            local rollback_payload="$BASE_DIR/panel_delete_rollback_verify.json"
            jq -n --arg name "$original_core_name" --argjson config "$(cat "$core_file")" --argjson type "$core_type" --argjson ex "$exclude_tags" --argjson fb "$fallback_tags" \
                '{name:$name,config:$config,type:$type,exclude_inbound_tags:$ex,fallbacks_inbound_tags:$fb}' > "$rollback_payload"
            panel_request PUT "/api/core/${PANEL_CORE_ID}?restart_nodes=true" "$rollback_payload" "$response" >/dev/null 2>&1 || true
            rm -f "$rollback_payload" "$verify" "$patterns" "$new_core" "$core_payload" "$delete_hosts_json" "$response"
            panel_lock_release; trap - RETURN; return 1
        fi
    fi
    if [ ${#host_ids[@]} -gt 0 ]; then
        jq -n --argjson ids "$(printf '%s\n' "${host_ids[@]}" | jq -R 'tonumber' | jq -s .)" '{ids:$ids}' > "$delete_hosts_json"
        code_http=$(panel_request POST /api/hosts/bulk/delete "$delete_hosts_json" "$response")
        if ! panel_http_ok "$code_http"; then
            echo -e "${YELLOW}[!] Host deletion failed (HTTP $code_http); attempting Core rollback so the node is not left half-deleted.${NC}"
            local rollback_payload="$BASE_DIR/panel_delete_rollback.json"
            jq -n --arg name "$original_core_name" --argjson config "$(cat "$core_file")" --argjson type "$core_type" --argjson ex "$exclude_tags" --argjson fb "$fallback_tags" \
                '{name:$name,config:$config,type:$type,exclude_inbound_tags:$ex,fallbacks_inbound_tags:$fb}' > "$rollback_payload"
            local rollback_code; rollback_code=$(panel_request PUT "/api/core/${PANEL_CORE_ID}?restart_nodes=true" "$rollback_payload" "$response")
            rm -f "$rollback_payload"
            if panel_http_ok "$rollback_code"; then
                echo -e "${YELLOW}[!] Core rollback succeeded. Nothing was finalized; retry the delete later.${NC}"
                rm -f "$patterns" "$new_core" "$core_payload" "$delete_hosts_json" "$response"
                panel_lock_release; trap - RETURN; return 1
            fi
            echo -e "${RED}[!] Core rollback also failed (HTTP $rollback_code). Panel is potentially inconsistent; do NOT delete local node data.${NC}"
            rm -f "$patterns" "$new_core" "$core_payload" "$delete_hosts_json" "$response"
            panel_lock_release; trap - RETURN; return 2
        fi
        # Reconcile: deleted IDs must no longer be returned by GET /api/hosts.
        panel_load_hosts "$hosts_file" || true
        for host_id in "${host_ids[@]}"; do
            if jq -e --argjson id "$host_id" '.[] | select(.id==$id)' "$hosts_file" >/dev/null 2>&1; then
                echo -e "${YELLOW}[!] Host ID $host_id still appears after deletion; keeping node in cleanup queue.${NC}"; rm -f "$patterns" "$new_core" "$core_payload" "$delete_hosts_json" "$response"; panel_lock_release; trap - RETURN; return 2
            fi
        done
    fi
    for idx in "$@"; do rm -f "$(panel_tombstone_file "$idx")"; done
    rm -f "$patterns" "$new_core" "$core_payload" "$delete_hosts_json" "$response" "$BASE_DIR/panel_core_verify.json"
    echo -e "${GREEN}[+] Selected node(s) removed from PasarGuard using exact Core/Host IDs and tags.${NC}"
    panel_lock_release; trap - RETURN; return 0
}

# ---- Pending Panel-cleanup queue -------------------------------------
# Tracks nodes whose local Tor instance was removed (or is about to be)
# while the matching Panel entry could NOT be confirmed removed -- so the
# user always has a way to go back and finish the Panel side later,
# instead of the node quietly staying orphaned on the Panel forever.
PANEL_PENDING_FILE="$BASE_DIR/panel_pending_delete.tsv"

panel_pending_queue_add() {
    local reason="$1"; shift
    mkdir -p "$BASE_DIR"; touch "$PANEL_PENDING_FILE"
    local idx code name out_port
    for idx in "$@"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        grep -q "^${idx}$(printf '\t')" "$PANEL_PENDING_FILE" 2>/dev/null && continue
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$idx" "$code" "$name" "$out_port" "$reason" "$(date +%s)" >> "$PANEL_PENDING_FILE"
    done
}

panel_pending_queue_remove() {
    local idx
    [ -f "$PANEL_PENDING_FILE" ] || return 0
    for idx in "$@"; do
        grep -v "^${idx}$(printf '\t')" "$PANEL_PENDING_FILE" > "${PANEL_PENDING_FILE}.tmp" 2>/dev/null || true
        mv -f "${PANEL_PENDING_FILE}.tmp" "$PANEL_PENDING_FILE"
    done
}

panel_pending_queue_count() {
    [ -f "$PANEL_PENDING_FILE" ] && [ -s "$PANEL_PENDING_FILE" ] && wc -l < "$PANEL_PENDING_FILE" | tr -d ' ' || echo 0
}

panel_pending_queue_show_and_retry() {
    draw_header
    echo -e "📌 ${MAGENTA}[ PENDING PANEL CLEANUP ]${NC}"
    echo '────────────────────────────────────────────────────────────'
    if [ "$(panel_pending_queue_count)" = "0" ]; then
        echo -e "${GREEN}[+] Nothing pending -- Panel is in sync.${NC}"
        read -r -p 'Press Enter...' < /dev/tty
        return
    fi
    echo -e "  ${WHITE}#   Country/Name              Port   Queued reason${NC}"
    local idx code name out_port reason ts
    while IFS=$'\t' read -r idx code name out_port reason ts; do
        [ -n "$idx" ] || continue
        printf '  [%02s] %-24s %-6s %s\n' "$idx" "$name" "$out_port" "$reason"
    done < "$PANEL_PENDING_FILE"
    echo '────────────────────────────────────────────────────────────'
    echo -e "These node(s) are gone locally but may still be listed on the Panel."
    read -r -p 'Retry removing ALL of these from the Panel now? [y/N]: ' go < /dev/tty || return
    if [[ "${go,,}" != "y" ]]; then return; fi
    local -a ids=()
    while IFS=$'\t' read -r idx _; do [ -n "$idx" ] && ids+=("$idx"); done < "$PANEL_PENDING_FILE"
    panel_delete_node_ids "${ids[@]}"
    local rc=$?
    if [ "$rc" = "0" ]; then
        panel_pending_queue_remove "${ids[@]}"
        echo -e "${GREEN}[+] Panel cleanup queue cleared.${NC}"
    else
        echo -e "${YELLOW}[!] Still not fully confirmed on the Panel -- left in the queue for another retry.${NC}"
    fi
    read -r -p 'Press Enter...' < /dev/tty
}

# ================= UI FUNCTIONS =================

UI_SPINNER_INDEX=0
UI_SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

ui_spin_frame() {
    local label="${1:-Working}"
    local frame="${UI_SPINNER_FRAMES[$UI_SPINNER_INDEX]}"
    UI_SPINNER_INDEX=$(( (UI_SPINNER_INDEX + 1) % ${#UI_SPINNER_FRAMES[@]} ))
    printf "\r\033[K${CYAN}[*] %s %s${NC}" "$frame" "$label" >&2
}

probe_public_ip() {
    local out_port="$1" tmp value
    tmp=$(mktemp /tmp/sherlook-ip.XXXXXX) || return 1
    curl -4 -sS --socks5-hostname "127.0.0.1:${out_port}" \
        https://api.ipify.org --connect-timeout 5 --max-time 12 >"$tmp" 2>/dev/null &
    local pid=$!
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        ui_spin_frame "Checking public IP via SOCKS ${out_port}"
        sleep 0.12
        i=$((i+1))
    done
    wait "$pid" 2>/dev/null || true
    value=$(tr -d '\0\r\n' <"$tmp" 2>/dev/null || true)
    rm -f "$tmp"
    printf '\r\033[K' >&2
    printf '%s\n' "$value"
}

parse_node_selection() {
    # Supports: 2-4,5,9,12,43 ; 3,5,9,12,43 ; 01,05,09 ; mixed ranges.
    local input="$1" token first last n idx swap
    local -a result=() tokens=()
    declare -A seen=()
    input="${input// /}"
    input="${input//;/,}"
    input="${input//–/-}"
    input="${input//—/-}"
    IFS=',' read -ra tokens <<< "$input"

    for token in "${tokens[@]}"; do
        [ -n "$token" ] || continue
        if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            first=$((10#${BASH_REMATCH[1]}))
            last=$((10#${BASH_REMATCH[2]}))
            if (( first > last )); then
                swap="$first"; first="$last"; last="$swap"
            fi
            for ((n=first; n<=last; n++)); do
                (( n >= 1 && n <= 83 )) || continue
                idx=$(printf '%02d' "$n")
                if [[ -n "${NODES[$idx]:-}" && -z "${seen[$idx]:-}" ]]; then
                    result+=("$idx")
                    seen[$idx]=1
                fi
            done
        elif [[ "$token" =~ ^[0-9]+$ ]]; then
            n=$((10#$token))
            (( n >= 1 && n <= 83 )) || continue
            idx=$(printf '%02d' "$n")
            if [[ -n "${NODES[$idx]:-}" && -z "${seen[$idx]:-}" ]]; then
                result+=("$idx")
                seen[$idx]=1
            fi
        else
            echo -e "${YELLOW}[!] Invalid selection token: ${token}${NC}" >&2
        fi
    done
    if [ "${#result[@]}" -gt 0 ]; then
        printf '%s\n' "${result[@]}"
    fi
}

draw_header() {
    clear
    echo -e "${MAGENTA} ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ███████╗██╗  ██╗███████╗██████╗ ██╗      ██████╗  ██████╗ ██╗  ██╗${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ██╔════╝██║  ██║██╔════╝██╔══██╗██║     ██╔═══██╗██╔═══██╗██║ ██╔╝${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ███████╗███████║█████╗  ██████╔╝██║     ██║   ██║██║   ██║█████╔╝ ${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ╚════██║██╔══██║██╔══╝  ██╔══██╗██║     ██║   ██║██║   ██║██╔═██╗ ${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ███████║██║  ██║███████╗██║  ██║███████╗╚██████╔╝╚██████╔╝██║  ██╗${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${YELLOW}          A U T O M A T E   E N G I N E   V 6 . 5 . 0                   ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ╚════════════════════════════════════════════════════════╝${NC}"
    local live_frame="${UI_SPINNER_FRAMES[$UI_SPINNER_INDEX]}"
    UI_SPINNER_INDEX=$(( (UI_SPINNER_INDEX + 1) % ${#UI_SPINNER_FRAMES[@]} ))
    echo -e " ${CYAN}${live_frame}${NC} ${WHITE}Sherlook 6.5.0${NC} ${YELLOW}|${NC} Live Tor Engine ${CYAN}•${NC} country/IP verification ${GREEN}●${NC}"
    if [ -n "${PANEL_PENDING_FILE:-}" ] && [ -s "${PANEL_PENDING_FILE:-/nonexistent}" ]; then
        local pend_n; pend_n=$(wc -l < "$PANEL_PENDING_FILE" | tr -d ' ')
        [ "$pend_n" != "0" ] && echo -e " ${YELLOW}⚠${NC}  ${YELLOW}${pend_n} node(s) waiting on a Panel cleanup retry${NC} ${WHITE}(Edit/Delete Nodes → option 5)${NC}"
    fi
    echo ""
}

draw_progress() {
    local text="$1"
    printf '
${CYAN}[*] %-54s${NC}' "$text"
    echo
}

deploy_node() {
    local code=$1; local name=$2; local out_port=$3
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
    local inst_data_dir="$DATA_DIR/${code}_${out_port}"
    local ip_file="$inst_data_dir/last_ip.txt"
    local ctrl_file="$inst_data_dir/control.env"
    local bad_file="$inst_data_dir/bad_exits.txt"

    clear_node_route_code "$code" "$out_port"
    if ! check_country_exit_availability "$code" "$name"; then
        cleanup_failed_node "$code" "$out_port"
        return 2
    fi

    mkdir -p "$BASE_DIR" "$inst_data_dir"
    touch "$bad_file"
    chown -R debian-tor:debian-tor "$inst_data_dir" 2>/dev/null || true

    if [ -n "${LOW_SUPPLY_WARN[$code]:-}" ]; then
        echo -e "${YELLOW}[!] Heads up: $name usually has very few Tor exit relays.${NC}"
    fi

    # 6.4.1: no ControlPort is required for node operation or IP rotation.
    # Keep an old control.env only as legacy data; it is never used to rotate a node.

    # Primary country gets the full 20-attempt budget. Each fallback route gets
    # its own independent 5-attempt budget. A fallback IP must still geolocate
    # to the actual fallback route; the original display label is preserved.
    local fallback_mode=0
    local fallback_index=0
    local fallback_candidates_arr=()
    local same_rejected_ip_limit=2
    local route_stuck=0
    local just_entered_fallback=0
    declare -A rejected_ip_counts=()
    mapfile -t fallback_candidates_arr < <(fallback_candidates "$code")

    while true; do
        local route_code="$(node_route_code "$code" "$out_port")"
        local attempt_limit="$MAX_TOTAL_VALIDATION_ATTEMPTS"
        if [ "$fallback_mode" -eq 1 ]; then
            attempt_limit="$FALLBACK_ROUTE_ATTEMPTS"
        fi

        write_node_conf "$conf_file" "$out_port" "$control_port" "$hashed_pass" "$inst_data_dir" "$code"
        chown debian-tor:debian-tor "$conf_file" 2>/dev/null || true

        if pgrep -f "node_${code}_${out_port}" > /dev/null; then
            stop_tor_node "$code" "$out_port"
            sleep 2
        fi

        if [ "$fallback_mode" -eq 1 ]; then
            echo -e "${YELLOW}[!] ${EMOJIS[$code]} $name keeps its original label; fallback route is ${WHITE}$route_code${YELLOW}. The public IP must still verify as ${route_code}.${NC}"
            echo -e "${CYAN}[*] Routing ${WHITE}$code - $name ${CYAN}➔ ExitNodes ${MAGENTA}$route_code${CYAN}, Port: ${MAGENTA}$out_port${CYAN}.${NC}"
        else
            echo -e "${CYAN}[*] Routing ${WHITE}$code - $name ${CYAN}➔ ExitNodes ${MAGENTA}$route_code${CYAN}, Port: ${MAGENTA}$out_port${CYAN}.${NC}"
        fi

        local tor_start_failed=0
        if ! run_tor_node "$conf_file"; then
            echo -e "${RED}[-] Tor could not start for route ${route_code}. See ${inst_data_dir}/notices.log${NC}"
            stop_tor_node "$code" "$out_port"
            tor_start_failed=1
        else
            echo -e "${CYAN}[*] Tor started. Validation begins at Attempt 1/${attempt_limit}.${NC}"
        fi

        local total_attempts=0
        local newnym_tries=0
        local last_ip=""
        local country_failures=0
        route_stuck=0
        rejected_ip_counts=()

        if [ "$tor_start_failed" -eq 0 ]; then
            while [ "$total_attempts" -lt "$attempt_limit" ]; do
                total_attempts=$((total_attempts+1))
                local public_ip
                public_ip=$(probe_public_ip "$out_port" || true)

            if [ -z "$public_ip" ] || ! is_valid_ipv4 "$public_ip"; then
                echo -e "${CYAN}[*] Waiting for Tor connection (Attempt $total_attempts/$attempt_limit)...${NC}"
            elif [ "$fallback_mode" -eq 1 ]; then
                echo -e "${CYAN}[*] Verifying fallback IP ${MAGENTA}$public_ip${CYAN} against GeoIP sources for ${WHITE}$route_code${WHITE}...${NC}"
                local fb_result fb_bad fb_actual fb_reason fb_seen
                fb_result=$(check_ip_quality "$public_ip" "$route_code" 1 0)
                IFS='|' read -r fb_bad fb_actual fb_reason fb_seen <<< "$fb_result"
                if [ "$fb_bad" = "0" ]; then
                    printf '%s\n' "$public_ip" > "$ip_file"
                    state_set "$code" "$out_port" ONLINE "$public_ip" 100 "VERIFIED:${fb_seen}"
                    quarantine_clear "$code" "$out_port"
                    echo -e "${GREEN}[+] FALLBACK VERIFIED: $public_ip → label=$code/$name route=$route_code${NC}"
                    echo -e "${GREEN}[+] GeoIP sources: ${fb_seen}${NC}"
                    echo -e "${GREEN}[+] Online -> ${WHITE}$code - $name ${GREEN}($public_ip)${NC}\n"
                    if panel_conf_safe_load && [ "${PANEL_AUTO_SYNC:-0}" = "1" ]; then panel_sync_single "$(node_index_by_code "$code")" >/dev/null 2>&1 || true; fi
                    return 0
                fi
                local fb_display_ip
                fb_display_ip=$(ip_display_range "$public_ip")
                echo -e "${RED}[-] Rejected fallback IP range ${fb_display_ip}: ${fb_reason} | detected=${fb_seen:-unknown} | expected=${route_code}${NC}"
                append_bad_ip "$bad_file" "$public_ip"
                rejected_ip_counts["$public_ip"]=$(( ${rejected_ip_counts["$public_ip"]:-0} + 1 ))
                if [ "${rejected_ip_counts[$public_ip]}" -ge "$same_rejected_ip_limit" ]; then
                    echo -e "${YELLOW}[!] ${public_ip} was rejected ${rejected_ip_counts[$public_ip]} times on fallback route ${route_code}. Moving on.${NC}"
                    route_stuck=1
                    stop_tor_node "$code" "$out_port"
                    sleep 1
                    break
                fi
            else
                echo -e "${CYAN}[*] Verifying ${MAGENTA}$public_ip${CYAN} against GeoIP sources for ${WHITE}$route_code${CYAN}...${NC}"
                local result is_bad actual_cc reason seen_ccs
                result=$(validate_node_ip "$public_ip" "$route_code" 1)
                IFS='|' read -r is_bad actual_cc reason seen_ccs <<< "$result"

                if [ "$is_bad" = "0" ]; then
                    printf '%s\n' "$public_ip" > "$ip_file"
                    state_set "$code" "$out_port" ONLINE "$public_ip" 100 "VERIFIED:${seen_ccs}"
                    quarantine_clear "$code" "$out_port"
                    echo -e "${GREEN}[+] VERIFIED: $public_ip → label=$code/$name route=$route_code${NC}"
                    echo -e "${GREEN}[+] GeoIP sources: ${seen_ccs}${NC}"
                    echo -e "${GREEN}[+] Online -> ${WHITE}$code - $name ${GREEN}($public_ip)${NC}\n"
                    if panel_conf_safe_load && [ "${PANEL_AUTO_SYNC:-0}" = "1" ]; then panel_sync_single "$(node_index_by_code "$code")" >/dev/null 2>&1 || true; fi
                    return 0
                fi

                country_failures=$((country_failures+1))
                local display_ip
                display_ip=$(ip_display_range "$public_ip")
                echo -e "${RED}[-] Rejected IP range ${display_ip}: ${reason} | detected=${seen_ccs:-unknown} | expected=${route_code}${NC}"
                append_bad_ip "$bad_file" "$public_ip"
                rejected_ip_counts["$public_ip"]=$(( ${rejected_ip_counts["$public_ip"]:-0} + 1 ))
                if [ "${rejected_ip_counts[$public_ip]}" -ge "$same_rejected_ip_limit" ]; then
                    echo -e "${YELLOW}[!] ${public_ip} was rejected ${rejected_ip_counts[$public_ip]} times on route ${route_code}. It will NOT be tested again on this route.${NC}"
                    echo -e "${CYAN}    > Forcing a fresh Tor instance / next route instead of looping on the same IP.${NC}"
                    route_stuck=1
                    stop_tor_node "$code" "$out_port"
                    sleep 1
                    if [ "$fallback_mode" -eq 0 ]; then
                        fallback_mode=1
                        fallback_index=0
                        just_entered_fallback=1
                    fi
                    break
                fi

                # IMPORTANT: when the primary country produces 5 wrong-country IPs,
                # do not wait for attempts 6..20. Ask immediately whether to keep
                # trying, skip to automatic fallback, or stop the node.
                if [ "$fallback_mode" -eq 0 ] && [ "$country_failures" -ge "$COUNTRY_FALLBACK_THRESHOLD" ]; then
                    if prompt_country_failure_action "$code" "$name" "$country_failures"; then
                        echo -e "${CYAN}[*] Continuing with ${name}; mismatch counter reset.${NC}"
                        country_failures=0
                    else
                        case "$?" in
                            3)
                                cleanup_failed_node "$code" "$out_port"
                                return 1
                                ;;
                            *)
                                fallback_mode=1
                                fallback_index=0
                                just_entered_fallback=1
                                # Stop the current primary-country Tor process before
                                # selecting the first fallback route. No more IP checks
                                # are performed for the primary route in this cycle.
                                stop_tor_node "$code" "$out_port"
                                sleep 1
                                break
                                ;;
                        esac
                    fi
                fi
            fi

            # NOTE (bugfix): do NOT unconditionally break here just because
            # fallback_mode==1. Every branch above that actually needs to
            # interrupt the attempt loop (rejected_ip_counts limit hit,
            # Tor restart failure, the 5-wrong-IP primary-country skip
            # action) already calls `break` itself at the point of decision.
            # The old unconditional check below used to fire on the very
            # FIRST rejected fallback IP -- before same_rejected_ip_limit or
            # attempt_limit were ever reached -- which meant every fallback
            # route effectively got only 1 attempt instead of its intended
            # FALLBACK_ROUTE_ATTEMPTS (5), burning through all fallback
            # countries almost instantly and reporting FAILED far sooner
            # than it should. Removed.

            if [ "$total_attempts" -lt "$attempt_limit" ]; then
                last_ip="$public_ip"
                echo -e "${YELLOW}    > Rotating the Tor instance after rejected country/IP validation...${NC}"
                stop_tor_node "$code" "$out_port"
                sleep 1
                if run_tor_node "$conf_file"; then
                    sleep 2
                else
                    echo -e "${RED}    > Tor restart failed; the current route will be abandoned instead of retrying the same IP.${NC}"
                    route_stuck=1
                    if [ "$fallback_mode" -eq 0 ]; then
                        fallback_mode=1
                        fallback_index=0
                    fi
                    break
                fi
            fi
            done
        fi

        # If the route got stuck on a repeated rejected IP, never ask the old
        # 20-attempt prompt again: move directly to the next route.
        if [ "$route_stuck" -eq 1 ]; then
            if [ "$fallback_mode" -eq 0 ]; then
                fallback_mode=1
                fallback_index=0
                just_entered_fallback=1
            fi
        fi

        # If the 5-wrong-IP action already switched to fallback, do NOT ask the
        # old 20-attempt question again. Go directly to the fallback selector.
        if [ "$fallback_mode" -eq 0 ]; then
            # Requested country exhausted its full 20-attempt budget.
            local fb_choice=2
            if [ -t 0 ] && [ -t 1 ]; then
                echo -e "\n${YELLOW}[!] ${name} failed to produce a verified ${code} IP after ${MAX_TOTAL_VALIDATION_ATTEMPTS} attempts.${NC}"
                echo -e "  ${CYAN}[1]${NC} Try ${code} again (new 20-attempt cycle)"
                echo -e "  ${CYAN}[2]${NC} Skip ${name} and move to fallback countries automatically (5 attempts each)"
                echo -e "  ${RED}[3]${NC} Skip/stop this node"
                read -r -p "Choice [1-3]: " fb_choice < /dev/tty || fb_choice=2
            fi

            case "$fb_choice" in
                1)
                    echo -e "${YELLOW}[*] Retrying ${name} with its original country ${code}.${NC}"
                    continue
                    ;;
                3)
                    cleanup_failed_node "$code" "$out_port"
                    return 1
                    ;;
                *)
                    ;;
            esac

            fallback_mode=1
            fallback_index=0
            just_entered_fallback=1
        else
            # Every fallback route gets exactly 5 attempts, then advances.
            if [ "$just_entered_fallback" -eq 1 ]; then
                just_entered_fallback=0
            else
                fallback_index=$((fallback_index+1))
            fi
        fi

        local next_route=""
        while [ "$fallback_index" -lt "${#fallback_candidates_arr[@]}" ]; do
            next_route="${fallback_candidates_arr[$fallback_index]}"
            fallback_index=$((fallback_index+1))
            local count
            count=$(onionoo_exit_count "${next_route,,}")
            if [ "$count" = "-1" ] || [ "$count" -ge "$ONIONOO_MIN_EXITS" ] 2>/dev/null; then
                break
            fi
            next_route=""
        done

        if [ -n "$next_route" ]; then
            set_node_route_code "$code" "$out_port" "$next_route"
            echo -e "${YELLOW}[!] ${name}: route ${WHITE}${route_code}${YELLOW} failed after ${attempt_limit} attempts. Moving automatically to next fallback route ${WHITE}${next_route}${YELLOW}; label remains ${WHITE}${name}${YELLOW}.${NC}"
            continue
        fi

        cleanup_failed_node "$code" "$out_port"
        echo -e "${RED}[-] FAILED: No usable fallback route remained for ${name}.${NC}"
        return 1
    done
}

# ================= IP ROTATION =================
get_node_ip() {
    local out_port="$1" value endpoint
    local -a endpoints=(
        "https://api.ipify.org"
        "https://checkip.amazonaws.com"
        "https://ifconfig.me/ip"
    )
    for endpoint in "${endpoints[@]}"; do
        value=$(curl -4 -sS --socks5-hostname "127.0.0.1:${out_port}" \
            "$endpoint" --connect-timeout "$HEALTH_CONNECT_TIMEOUT" --max-time "$HEALTH_MAX_TIME" 2>/dev/null \
            | tr -d '\r\n\0' || true)
        if is_valid_ipv4 "$value"; then
            printf '%s\n' "$value"
            return 0
        fi
    done
    return 1
}

rotate_one_node_core() {
    local code="$1" name="$2" out_port="$3" silent="${4:-0}"
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
    local inst_data_dir="$DATA_DIR/${code}_${out_port}"
    local bad_file="$inst_data_dir/bad_exits.txt"
    local ip_file="$inst_data_dir/last_ip.txt"
    [ -f "$conf_file" ] || return 2

    mkdir -p "$inst_data_dir"
    touch "$bad_file"
    local old_ip=""
    [ -s "$ip_file" ] && old_ip=$(head -n1 "$ip_file" | tr -d '\r\n')
    local expected_route="$(node_route_code "$code" "$out_port")"
    [ "$silent" = "1" ] || echo -e "${CYAN}🔄 $code - $name: changing IP...${NC}"

    # 6.4.1: Do not depend on ControlPort/NEWNYM. Rebuild the exact Tor
    # instance when a circuit/IP is unusable. This keeps the primary torrc
    # minimal and fixes legacy nodes whose control.env points to a dead port.
    local attempt=0 new_ip="" result bad actual reason seen
    local same_ip_count=0
    declare -A seen_ips=()
    [ -n "$old_ip" ] && seen_ips["$old_ip"]=1

    if ! node_process_running "$code" "$out_port"; then
        [ "$silent" = "1" ] || echo -e "${YELLOW}    > Tor process for $code is not running — rebuilding it now...${NC}"
        stop_tor_node "$code" "$out_port"
        if ! run_tor_node "$conf_file"; then
            state_set "$code" "$out_port" DEAD "" 0 "TOR_START_FAILED"
            return 1
        fi
        sleep 2
    fi

    while (( attempt < NODE_ROTATE_RETRIES )); do
        attempt=$((attempt+1))
        new_ip=$(get_node_ip "$out_port" || true)

        if ! is_valid_ipv4 "$new_ip"; then
            [ "$silent" = "1" ] || echo -e "${YELLOW}  • $code no public IP yet (attempt $attempt/$NODE_ROTATE_RETRIES)${NC}"
        else
            if [[ -n "${seen_ips[$new_ip]:-}" ]]; then
                same_ip_count=$((same_ip_count+1))
                [ "$silent" = "1" ] || echo -e "${YELLOW}  • $code received a previously-seen IP $new_ip; forcing a new Tor instance (attempt $attempt/$NODE_ROTATE_RETRIES)${NC}"
            else
                seen_ips["$new_ip"]=1
                result=$(check_ip_quality "$new_ip" "$expected_route" 0 0)
                IFS='|' read -r bad actual reason seen <<< "$result"
                if [ "$reason" = "GEOIP_UNAVAILABLE" ]; then
                    printf '%s\n' "$new_ip" > "$ip_file"
                    [ "$silent" = "1" ] || echo -e "${YELLOW}  • $code → $new_ip; GeoIP temporarily unavailable${NC}"
                    state_set "$code" "$out_port" ONLINE_UNVERIFIED "$new_ip" 100 "GEOIP_UNAVAILABLE"
                    return 0
                fi
                if [ "$bad" = "0" ]; then
                    printf '%s\n' "$new_ip" > "$ip_file"
                    [ "$silent" = "1" ] || echo -e "${GREEN}  ✓ $code → $new_ip (attempt $attempt/$NODE_ROTATE_RETRIES)${NC}"
                    state_set "$code" "$out_port" ONLINE "$new_ip" 100 "VERIFIED:${seen}"
                    quarantine_clear "$code" "$out_port"
                    return 0
                fi
                append_bad_ip "$bad_file" "$new_ip"
                local display_new_ip
                display_new_ip=$(ip_display_range "$new_ip")
                [ "$silent" = "1" ] || echo -e "${RED}  ✗ $code rejected IP range $display_new_ip for route $expected_route: $reason (attempt $attempt/$NODE_ROTATE_RETRIES)${NC}"
            fi
        fi

        if (( attempt < NODE_ROTATE_RETRIES )); then
            [ "$silent" = "1" ] || echo -e "${CYAN}    > Rebuilding Tor instance for $code to force a fresh circuit/IP...${NC}"
            stop_tor_node "$code" "$out_port"
            sleep 1
            if ! run_tor_node "$conf_file"; then
                state_set "$code" "$out_port" DEAD "" 0 "TOR_RESTART_FAILED"
                [ "$silent" = "1" ] || echo -e "${RED}    > Tor restart failed; retrying with the same route is skipped until process recovers.${NC}"
                sleep 1
                continue
            fi
            sleep 2
        fi
    done

    rm -f "$ip_file"
    state_set "$code" "$out_port" EXIT_GEOIP_FAIL "" 100 "NO_VERIFIED_NEW_IP"
    quarantine_record_failure "$code" "$out_port" "NO_VERIFIED_NEW_IP"
    echo "$(date '+%Y-%m-%d %H:%M:%S') rotation failed for $code" >> "$inst_data_dir/heal_fail.log"
    [ "$silent" = "1" ] || echo -e "${RED}  ✗ $code: no verified replacement IP found after $NODE_ROTATE_RETRIES rebuild attempts.${NC}"
    return 1
}

rotate_one_node() {
    local code="$1" name="$2" out_port="$3" silent="${4:-0}"
    if ! acquire_node_lock "$code" "$out_port"; then
        [ "$silent" = "1" ] || echo -e "${YELLOW}[!] $code is already being repaired; skipping duplicate rotation.${NC}"
        return 3
    fi
    rotate_one_node_core "$code" "$name" "$out_port" "$silent"
    local rc=$?
    release_node_lock
    return $rc
}

change_ip_menu() {
    check_root
    while true; do
        draw_header
        echo -e "${MAGENTA}🔄 IP Rotation${NC}"
        echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${CYAN}[1]${NC} Change IP of one active Node"
        echo -e "  ${CYAN}[2]${NC} Change IP of ALL active Nodes"
        echo -e "  ${RED}[0]${NC} Back"
        echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
        read -r -p "Enter choice: " ch < /dev/tty || return
        case "$ch" in
            1)
                for idx in "${ORDER[@]}"; do
                    IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
                    if [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] && pgrep -f "node_${code}_${out_port}.conf" >/dev/null 2>&1; then
                        echo -e "  ${CYAN}[$idx]${NC} ${EMOJIS[$code]} $name ($code) — $out_port"
                    fi
                done
                read -r -p "Node ID: " pick < /dev/tty || continue
                if [[ "$pick" =~ ^[0-9]+$ ]]; then
                    pick=$(printf "%02d" "$((10#$pick))" 2>/dev/null)
                    IFS=':' read -r code name out_port <<< "${NODES[$pick]:-}"
                    if [ -n "$code" ] && [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ]; then
                        rotate_one_node "$code" "$name" "$out_port" 0
                    else
                        echo -e "${RED}[!] Invalid/inactive Node.${NC}"
                    fi
                else
                    echo -e "${RED}[!] Invalid selection.${NC}"
                fi
                read -r -p "Press Enter..." < /dev/tty
                ;;
            2)
                local jobs=0 total=0 max_jobs=6
                echo -e "${YELLOW}[*] Rotating all active Nodes (up to $max_jobs in parallel)...${NC}"
                for idx in "${ORDER[@]}"; do
                    IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
                    if [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] && pgrep -f "node_${code}_${out_port}.conf" >/dev/null 2>&1; then
                        total=$((total+1))
                        rotate_one_node "$code" "$name" "$out_port" 1 &
                        jobs=$((jobs+1))
                        if [ "$jobs" -ge "$max_jobs" ]; then
                            wait -n 2>/dev/null || wait
                            jobs=$((jobs-1))
                        fi
                    fi
                done
                wait || true
                echo -e "${GREEN}[+] Bulk IP rotation finished for $total active Node(s).${NC}"
                read -r -p "Press Enter..." < /dev/tty
                ;;
            0) return ;;
        esac
    done
}

# ================= CORE MENUS =================

install_engine() {
    check_root
    draw_header
    echo -e "${YELLOW}[*] Updating package lists...${NC}"
    apt-get update -qq
    echo -e "${YELLOW}[*] Installing prerequisites...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        tor tor-geoipdb obfs4proxy curl jq nano openssl unzip zip cron ca-certificates util-linux

    systemctl stop tor 2>/dev/null || true
    systemctl disable tor 2>/dev/null || true
    mkdir -p "$BASE_DIR" "$DATA_DIR"
    chown -R debian-tor:debian-tor "$DATA_DIR" 2>/dev/null || true

    local source="$SCRIPT_PATH"
    [ -f "$source" ] || { echo -e "${RED}[!] Cannot locate engine source: $source${NC}"; return 1; }
    bash -n "$source" || { echo -e "${RED}[!] Engine syntax check failed; refusing to install.${NC}"; return 1; }
    install -m 755 "$source" "$INSTALL_PATH"
    install -d -m 755 /root/.sherlook
    install -m 755 "$source" /root/.sherlook/sherlook.sh

    cat > /etc/systemd/system/sherlook-heal.service <<EOF
[Unit]
Description=Sherlook Continuous Tor Node Health and IP Auto-Heal
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$INSTALL_PATH --auto-heal-daemon
Restart=always
RestartSec=2
User=root
MemoryMax=2G
NoNewPrivileges=false

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now sherlook-heal.service
    sync_dynamic_locations || true
    echo "*/15 * * * * root systemctl is-active --quiet sherlook-heal.service || systemctl restart sherlook-heal.service" > /etc/cron.d/sherlook_watchdog
    chmod 644 /etc/cron.d/sherlook_watchdog
    systemctl restart cron 2>/dev/null || true

    echo -e "${GREEN}[+] Sherlook v${SHERLOOK_VERSION} installed successfully.${NC}"
    echo -e "${GREEN}[+] Continuous Auto-Heal is active (~${AUTO_HEAL_INTERVAL}s scan interval).${NC}"
    echo -e "${GREEN}[+] Invalid/Waiting/non-IP output triggers immediate IP rotation/rebuild.${NC}"
    sleep 2
}

update_system() {
    check_root
    draw_header
    echo -e "${CYAN}[*] Checking GitHub for the newest Sherlook engine...${NC}"

    local api_url="https://api.github.com/repos/SherlookHolmz/multi/commits/main"
    local raw_base="https://raw.githubusercontent.com/SherlookHolmz/multi"
    local commit remote_tmp remote_version local_version backup patched

    remote_tmp=$(mktemp /tmp/sherlook-update.XXXXXX) || return 1
    patched=$(mktemp /tmp/sherlook-update-patched.XXXXXX) || { rm -f "$remote_tmp"; return 1; }
    trap 'rm -f "$remote_tmp" "$patched"' RETURN

    commit=$(curl -4 -fsSL --connect-timeout 10 --max-time 30 \
        -H 'Accept: application/vnd.github+json' \
        "$api_url" | jq -r '.sha // empty') || commit=""

    if [[ ! "$commit" =~ ^[0-9a-f]{40}$ ]]; then
        echo -e "${RED}[!] Could not resolve SherlookHolmz/multi@main.${NC}"
        return 1
    fi

    if ! curl -4 -fsSL --connect-timeout 10 --max-time 90 \
        -o "$remote_tmp" "$raw_base/$commit/sherlook.sh"; then
        echo -e "${RED}[!] Could not download the remote engine from commit $commit.${NC}"
        return 1
    fi

    bash -n "$remote_tmp" || {
        echo -e "${RED}[!] Remote engine failed Bash syntax validation; local installation was not changed.${NC}"
        return 1
    }

    remote_version=$(grep -m1 '^SHERLOOK_VERSION=' "$remote_tmp" | sed 's/^SHERLOOK_VERSION="//; s/"$//')
    local_version="$SHERLOOK_VERSION"
    if [[ ! "$remote_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}[!] Remote engine does not contain a valid semantic version.${NC}"
        return 1
    fi

    if [ "$(printf '%s\n' "$remote_version" "$local_version" | sort -V | head -n1)" != "$local_version" ]; then
        echo -e "${YELLOW}[!] Remote engine $remote_version is older than the installed engine $local_version; refusing downgrade.${NC}"
        return 1
    fi

    echo -e "${GREEN}[+] Remote version: $remote_version${NC}"
    echo -e "${GREEN}[+] Remote commit:  $commit${NC}"

    sed "s/^PINNED_COMMIT=\"__INSTALLER_RESOLVES__\"/PINNED_COMMIT=\"$commit\"/" \
        "$remote_tmp" > "$patched"
    # Also replace an older embedded pin when updating an already pinned install.
    sed -i "s/^PINNED_COMMIT=\"[0-9a-f]\{40\}\"/PINNED_COMMIT=\"$commit\"/" "$patched"
    bash -n "$patched" || {
        echo -e "${RED}[!] Patched remote engine failed syntax validation.${NC}"
        return 1
    }

    backup="$BASE_DIR/sherlook.sh.bak.$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BASE_DIR" /root/.sherlook
    [ -f "$INSTALL_PATH" ] && cp -a "$INSTALL_PATH" "$backup"

    # Preserve all node data/configuration. Only the engine binary/script is replaced.
    systemctl stop sherlook-heal.service 2>/dev/null || true
    install -m 755 "$patched" "$INSTALL_PATH.new"
    mv -f "$INSTALL_PATH.new" "$INSTALL_PATH"
    install -m 755 "$patched" /root/.sherlook/sherlook.sh

    if [ -f /etc/systemd/system/sherlook-heal.service ]; then
        sed -i "s#^ExecStart=.*#ExecStart=$INSTALL_PATH --auto-heal-daemon#" \
            /etc/systemd/system/sherlook-heal.service
        # Bugfix: older installs pinned MemoryMax=256M on this unit. Every
        # Tor process that auto-heal restarts (rotation, repair) becomes a
        # child of THIS cgroup, and 256M is not enough once more than a
        # handful of exit nodes are being rotated -- the kernel OOM-killer
        # can take out the whole cgroup (all running Tor nodes at once,
        # not just the one over budget) when the limit is hit. Raise it on
        # every update so existing installs are corrected automatically.
        sed -i "s#^MemoryMax=.*#MemoryMax=2G#" /etc/systemd/system/sherlook-heal.service
    fi
    systemctl daemon-reload
    systemctl enable --now sherlook-heal.service 2>/dev/null || true

    local installed_version
    installed_version=$($INSTALL_PATH --version 2>/dev/null || true)
    if [ "$installed_version" != "$remote_version" ]; then
        echo -e "${RED}[!] Post-update version check failed: got '$installed_version', expected '$remote_version'.${NC}"
        return 1
    fi

    echo -e "${GREEN}[+] Sherlook updated in-place: v${local_version} -> v${remote_version}${NC}"
    echo -e "${GREEN}[+] Existing node data/configuration was preserved.${NC}"
    echo -e "${GREEN}[+] Backup: ${backup}${NC}"
    echo -e "${GREEN}[+] Pinned to commit: ${commit}${NC}"
    sleep 2
    exec "$INSTALL_PATH"
}

uninstall_engine() {
    check_root
    draw_header
    echo -e "${RED}[!] WARNING: This will completely remove Tor and configurations.${NC}"
    read -p "❓ Are you sure? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi
    pkill -f "node_" 2>/dev/null || true
    systemctl stop tor 2>/dev/null || true
    apt-get remove --purge -y tor tor-geoipdb
    apt-get autoremove -y
    rm -rf "$BASE_DIR"
    rm -rf "$DATA_DIR"
    rm -f /etc/cron.d/sherlook_heal /etc/cron.d/sherlook_watchdog
    systemctl disable --now sherlook-heal.service 2>/dev/null || true
    rm -f /etc/systemd/system/sherlook-heal.service
    systemctl daemon-reload 2>/dev/null || true
    rm -f /usr/local/bin/sherlook /usr/local/bin/sherlook-install
    echo -e "${GREEN}[+] Uninstallation complete.${NC}"
    exit 0
}

list_locations() {
    sync_dynamic_locations || true
    echo -e "${YELLOW}Tor Exit Locations (${#ORDER[@]} total — green means last real health verification succeeded):${NC}\n"

    local C_CYAN='\033[1;36m'
    local C_GREEN='\033[1;32m'
    local C_WHITE='\033[1;37m'
    local NC='\033[0m'

    local CIRCLE_ON="${C_GREEN}●${NC}"
    local CIRCLE_OFF="${C_WHITE}○${NC}"

    local total=${#ORDER[@]}
    local half=$(( (total + 1) / 2 ))

    for ((i=1; i<=half; i++)); do
        local idx1=$(printf "%02d" $i)
        local idx2=$(printf "%02d" $((i+half)))

        IFS=':' read -r code1 name1 port1 <<< "${NODES[$idx1]}"
        local stat1="$CIRCLE_OFF"
        local st1=""; state_get "$code1" "$port1" && st1="${STATUS:-}"
        if [[ "$st1" == ONLINE || "$st1" == ONLINE_UNVERIFIED ]]; then
            stat1="$CIRCLE_ON"
        fi

        local col2_str=""
        if [[ -n "${NODES[$idx2]:-}" ]]; then
            IFS=':' read -r code2 name2 port2 <<< "${NODES[$idx2]}"
            local stat2="$CIRCLE_OFF"
            local st2=""; state_get "$code2" "$port2" && st2="${STATUS:-}"
            if [[ "$st2" == ONLINE || "$st2" == ONLINE_UNVERIFIED ]]; then
                stat2="$CIRCLE_ON"
            fi
            col2_str=$(printf "${C_CYAN}[%s]${NC} %b %-16s" "$idx2" "$stat2" "$name2")
        fi

        printf "  ${C_CYAN}[%s]${NC} %b %-16s    %b\n" "$idx1" "$stat1" "$name1" "$col2_str"
    done

    echo -e "\n  ${RED}00${NC} - ${WHITE}Back to main menu${NC}\n"
}

add_single_node() {
    check_root
    draw_header
    echo -e "${CYAN}» Option 4 - Add Location Node${NC}\n"
    list_locations
    read -p "$(echo -e ${MAGENTA}"Select location index: "${NC})" loc_idx
    if [[ "$loc_idx" == "00" || -z "$loc_idx" ]]; then return; fi
    if [[ "$loc_idx" =~ ^[0-9]+$ ]]; then
        p_idx=$(printf "%02d" "$((10#$loc_idx))" 2>/dev/null)
        if [[ -n "${NODES[$p_idx]:-}" ]]; then
            IFS=':' read -r code name out_port <<< "${NODES[$p_idx]}"

            if node_is_installed "$code" "$out_port"; then
                echo -e "\n${YELLOW}[!] Node $code - $name is already active. You cannot install it again.${NC}"
                sleep 2
            else
                deploy_node "$code" "$name" "$out_port"
                read -p "$(echo -e ${WHITE}"Press Enter to return..."${NC})"
            fi
        else
            echo -e "\n${RED}[!] Invalid location index.${NC}"; sleep 2
        fi
    else
        echo -e "\n${RED}[!] Invalid input.${NC}"; sleep 2
    fi
}

bulk_add_nodes() {
    check_root
    draw_header
    echo -e "${CYAN}» Option 5 - Bulk Add Nodes${NC}\n"
    echo -e "  ${GREEN}[1]${NC} Deploy All Supported Locations (Full World)"
    echo -e "  ${GREEN}[2]${NC} Custom Batch Deployment (Comma separated selection)"
    echo -e "  ${GREEN}[3]${NC} Deploy Main Countries (TR, US, FR, FI, ES, NL, GB, CA, LU, CH)"
    echo -e "  ${RED}[0]${NC} Go Back\n"

    read -p "$(echo -e ${CYAN}"Select deployment mode [0-3]: "${NC})" bulk_opt

    if [ "$bulk_opt" == "1" ]; then
        echo -e "${YELLOW}[!] Initiating deployment for ALL uninstalled nodes...${NC}"
        for idx in "${ORDER[@]}"; do
            IFS=':' read -r code name out_port <<< "${NODES[$idx]}"

            if node_is_installed "$code" "$out_port"; then
                continue
            fi

            echo -e "\n${CYAN}[*] Processing ${WHITE}$code - $name${CYAN}...${NC}"
            deploy_node "$code" "$name" "$out_port"
            sleep 1
        done
        echo -e "\n${GREEN}[+] Full deployment sequence complete!${NC}"
        read -r -p "$(echo -e ${WHITE}"Press Enter to return to main menu..."${NC})" < /dev/tty

    elif [ "$bulk_opt" == "2" ]; then
        list_locations
        echo -e "${YELLOW}Example: 1,4,15 or range: 1-4 or mixed: 1,4-7,15${NC}"
        read -r -p "$(echo -e ${CYAN}"Enter indices (e.g. 1,2,4-7): "${NC})" custom_list

        if [ -z "$custom_list" ] || [ "$custom_list" == "00" ] || [ "$custom_list" == "0" ]; then
            return
        fi

        mapfile -t selected < <(parse_node_selection "$custom_list")

        if [ "${#selected[@]}" -eq 0 ]; then
            echo -e "${RED}[!] No valid locations selected. Use examples: 2-4,5,9,12,43  OR  3,5,9,12,43${NC}"
            sleep 2
            return
        fi

        echo -e "${CYAN}[*] Selected ${#selected[@]} location(s).${NC}"
        echo -e "${YELLOW}[*] Discovery timeout: 20 seconds per location.${NC}"
        echo

        for p_idx in "${selected[@]}"; do
            IFS=':' read -r code name out_port <<< "${NODES[$p_idx]}"

            if node_is_installed "$code" "$out_port"; then
                echo -e "${YELLOW}[!] $code - $name is already active. Skipping...${NC}"
                continue
            fi

            echo -e "\n${CYAN}[*] Processing ${WHITE}$code - $name${CYAN}...${NC}"
            deploy_node "$code" "$name" "$out_port"
            sleep 1
        done

        echo -e "\n${GREEN}[+] Custom batch deployment sequence complete!${NC}"
        read -r -p "$(echo -e ${WHITE}"Press Enter to return to main menu..."${NC})" < /dev/tty

    elif [ "$bulk_opt" == "3" ]; then
        echo -e "${YELLOW}[!] Initiating deployment for Main Countries...${NC}"
        local main_list=("02" "03" "04" "08" "12" "13" "15" "17" "36" "37")
        for p_idx in "${main_list[@]}"; do
            IFS=':' read -r code name out_port <<< "${NODES[$p_idx]}"

            if node_is_installed "$code" "$out_port"; then
                echo -e "${YELLOW}[!] $code - $name is already active. Skipping...${NC}"
                continue
            fi

            echo -e "\n${CYAN}[*] Processing ${WHITE}$code - $name${CYAN}...${NC}"
            deploy_node "$code" "$name" "$out_port"
            sleep 1
        done
        echo -e "\n${GREEN}[+] Main Countries deployment sequence complete!${NC}"
        read -r -p "$(echo -e ${WHITE}"Press Enter to return to main menu..."${NC})" < /dev/tty
    fi
}

view_active_nodes() {
    check_root
    sync_dynamic_locations
    draw_header
    echo -e "${CYAN}» Option 6 - Active Nodes Monitor${NC}"
    echo -e "${YELLOW}[*] Running a real health probe for every installed node...${NC}"
    echo -e "${YELLOW}[*] IP = SOCKS public IP; COUNTRY = 2/3 GeoIP agreement; state is saved for Auto-Heal.${NC}\n"

    local idx code name out_port status ip bootstrap reason
    printf '%-5s %-4s %-22s %-8s %-20s %-18s %-22s\n' 'ID' 'CC' 'Location' 'PORT' 'STATUS' 'IP' 'BOOTSTRAP/REASON'
    echo '────────────────────────────────────────────────────────────────────────────────────────────────────────────'

    for idx in "${ORDER[@]}"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] || continue

        # Do NOT rotate nodes merely because the screen is opened. This is a
        # read/probe operation; Auto-Heal remains responsible for repairs.
        health_check_node "$code" "$name" "$out_port" 1 0 >/dev/null 2>&1 || true

        status='UNKNOWN'; ip='-'; bootstrap='-'; reason='-'
        if state_get "$code" "$out_port"; then
            status="${STATUS:-UNKNOWN}"
            ip="${IP:--}"
            bootstrap="${BOOTSTRAP:-0}%"
            reason="${REASON:--}"
        fi
        [ -z "$ip" ] && ip='-'
        [ -z "$reason" ] && reason='-'
        printf '[%02s] %-4s %-22s %-8s %-20s %-18s %-22s\n' "$idx" "$code" "$name" "$out_port" "$status" "$ip" "$bootstrap/$reason"
    done

    echo '────────────────────────────────────────────────────────────────────────────────────────────────────────────'
    echo -e "${GREEN}[+] ONLINE${NC}: SOCKS reachable and country verified by GeoIP majority."
    echo -e "${YELLOW}[!] ONLINE_UNVERIFIED${NC}: SOCKS is working and an IP exists, but GeoIP services did not answer."
    echo -e "${RED}[!] EXIT_GEOIP_FAIL${NC}: public IP exists but country did not reach the required confidence."
    echo -e "${RED}[!] DEAD / SOCKS_DEAD${NC}: node process or SOCKS listener is unavailable."
    echo
    read -r -p 'Press Enter to return...' < /dev/tty
}

edit_delete_nodes() {
    check_root
    delete_local_ids() { local idx code name out_port meta; for idx in "$@"; do IFS=':' read -r code name out_port <<< "${NODES[$idx]}"; meta=$(panel_meta_file "$code" "$out_port"); if [ -r "$meta" ]; then mkdir -p "$BASE_DIR/panel_tombstones"; cp -f "$meta" "$(panel_tombstone_file "$idx")" 2>/dev/null || true; fi; pkill -9 -f "node_${code}_${out_port}\.conf" 2>/dev/null || true; rm -f "$BASE_DIR/node_${code}_${out_port}.conf"; rm -rf "$DATA_DIR/${code}_${out_port}"; done; }
    repair_ids() { compute_effective_parallel; local max_jobs=$EFFECTIVE_PARALLEL jobs=0; local -a pids=(); local idx code name out_port; for idx in "$@"; do IFS=':' read -r code name out_port <<< "${NODES[$idx]}"; [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] || continue; rotate_one_node "$code" "$name" "$out_port" 0 & pids+=("$!"); jobs=$((jobs+1)); if ((jobs>=max_jobs)); then wait "${pids[0]}" 2>/dev/null || true; pids=("${pids[@]:1}"); jobs=$((jobs-1)); fi; done; for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done; }
    while true; do
        draw_header; echo -e "📌 ${MAGENTA}[ NODE MAINTENANCE ]${NC}"; echo '────────────────────────────────────────────────────────────'
        local idx code name out_port st st_color
        for idx in "${ORDER[@]}"; do
            IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
            [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] || continue
            st='UNKNOWN'; state_get "$code" "$out_port" && st="$STATUS"
            case "$st" in
                ONLINE) st_color="${GREEN}${st}${NC}" ;;
                ONLINE_UNVERIFIED) st_color="${CYAN}${st}${NC}" ;;
                DEAD|SOCKS_DEAD|EXIT_GEOIP_FAIL) st_color="${RED}${st}${NC}" ;;
                QUARANTINED*) st_color="${YELLOW}${st}${NC}" ;;
                *) st_color="${WHITE}${st}${NC}" ;;
            esac
            printf '[%02s] %-20s %-8s %b\n' "$idx" "$name" "$out_port" "$st_color"
        done
        echo '────────────────────────────────────────────────────────────'
        local pend; pend=$(panel_pending_queue_count)
        echo '[1] Repair selected       [2] Delete local selected'
        echo '[3] Delete local + Panel  [4] Refresh'
        if [ "$pend" != "0" ]; then
            echo -e "[5] ${YELLOW}Retry pending Panel cleanup (${pend})${NC}"
        fi
        echo '[0] Back'
        read -r -p 'Select action: ' action < /dev/tty || return
        case "$action" in
            1|2|3)
                read -r -p 'Node IDs (e.g. 1-21,25): ' selection < /dev/tty || continue
                mapfile -t selected < <(parse_node_selection "$selection"); [ ${#selected[@]} -gt 0 ] || { echo '[!] No valid IDs.'; sleep 1; continue; }
                if [ "$action" = 1 ]; then repair_ids "${selected[@]}"; fi
                if [ "$action" = 2 ]; then
                    read -r -p 'Type DELETE to confirm (LOCAL ONLY -- Panel entries will stay behind): ' c < /dev/tty
                    if [ "$c" = DELETE ]; then delete_local_ids "${selected[@]}"; fi
                fi
                if [ "$action" = 3 ]; then
                    read -r -p 'Type DELETE to confirm local+panel removal: ' c < /dev/tty
                    if [ "$c" = DELETE ]; then
                        panel_delete_node_ids "${selected[@]}"
                        local panel_rc=$?
                        if [ "$panel_rc" = "0" ]; then
                            delete_local_ids "${selected[@]}"
                            panel_pending_queue_remove "${selected[@]}"
                            echo -e "${GREEN}[+] Removed locally and from the Panel.${NC}"
                        elif [ "$panel_rc" = "2" ]; then
                            delete_local_ids "${selected[@]}"
                            panel_pending_queue_add "core-ok-hosts-unconfirmed" "${selected[@]}"
                            echo -e "${YELLOW}[!] Removed locally. The Panel's core config was updated but its Hosts list could not be confirmed -- queued for retry (menu option 5).${NC}"
                        else
                            echo -e "${RED}[!] Panel removal failed, so nothing was deleted locally either (your node is untouched). Fix the Panel connection (option 9) and try again.${NC}"
                            read -r -p 'Delete locally anyway and queue the Panel cleanup for later? [y/N]: ' force < /dev/tty
                            if [[ "${force,,}" = "y" ]]; then
                                delete_local_ids "${selected[@]}"
                                panel_pending_queue_add "panel-delete-failed" "${selected[@]}"
                                echo -e "${YELLOW}[!] Deleted locally and queued for a later Panel cleanup retry (menu option 5).${NC}"
                            fi
                        fi
                    fi
                fi
                read -r -p 'Press Enter...' < /dev/tty
                ;;
            5) [ "$pend" != "0" ] && panel_pending_queue_show_and_retry ;;
            4) continue ;;
            0) return ;;
        esac
    done
}

# ================= NEXATIS PANEL INTEGRATION =================

panel_login() {
    draw_header
    if panel_conf_safe_load && [ -n "${URL:-}" ] && [ -n "${TOKEN:-}" ]; then
        if panel_auth_preflight; then panel_menu; return; fi
    fi
    local p_domain p_port p_user p_pass base_url token_resp token
    read -r -p 'Panel domain: ' p_domain < /dev/tty || return
    read -r -p 'Panel port [443]: ' p_port < /dev/tty || return; [ -n "$p_port" ] || p_port=443
    base_url="https://${p_domain}:${p_port}"
    read -r -p 'Admin username: ' p_user < /dev/tty || return
    read -r -s -p 'Admin password: ' p_pass < /dev/tty || return; echo
    token_resp=$(curl -4 -skS --connect-timeout 8 --max-time 15 -X POST "$base_url/api/admin/token" \
        -H 'Content-Type: application/x-www-form-urlencoded' -H 'Accept: application/json' \
        --data-urlencode "grant_type=password" --data-urlencode "username=$p_user" --data-urlencode "password=$p_pass" 2>/dev/null || true)
    token=$(printf '%s' "$token_resp" | jq -r '.access_token // empty' 2>/dev/null)
    unset p_pass token_resp
    [ -n "$token" ] || { echo -e "${RED}[!] Login failed. Check credentials, TLS, and /api/admin/token availability.${NC}"; return 1; }
    URL="$base_url"; USER="$p_user"; TOKEN="$token"; PANEL_CORE_ID="${PANEL_CORE_ID:-}"; PANEL_INBOUND_INDEX=${PANEL_INBOUND_INDEX:-1}; PANEL_HOST_INDEX=${PANEL_HOST_INDEX:-0}; PANEL_AUTO_SYNC=1
    panel_conf_write
    if ! panel_auth_preflight; then echo -e "${RED}[!] Login token was issued but the account cannot read Cores. Check permissions.${NC}"; return 1; fi
    echo -e "${GREEN}[+] Login successful. Password was not stored.${NC}"
    panel_menu
}

panel_menu() {
    while true; do
        draw_header
        echo -e "📌 ${MAGENTA}[ NEXATIS CONTROL PANEL ]${NC}"
        local pend; pend=$(panel_pending_queue_count)
        echo '[1] Configure/validate templates'
        echo '[2] Add installed nodes to Panel'
        echo '[3] Delete selected nodes from Panel (Panel side only)'
        if [ "$pend" != "0" ]; then
            echo -e "[5] ${YELLOW}Retry pending Panel cleanup (${pend})${NC}"
        fi
        echo '[4] Logout'
        echo '[0] Back'
        read -r -p 'Selected option: ' panel_opt < /dev/tty || return
        case "$panel_opt" in
            1) panel_prepare_templates; read -r -p 'Press Enter...' < /dev/tty ;;
            2) panel_batch_create ;;
            3)
                read -r -p 'Node IDs: ' s < /dev/tty || continue
                mapfile -t ids < <(printf '%s\n' "$s" | sed 's/;/,/g' | awk -F',' '{for(i=1;i<=NF;i++) print $i}' | while read -r x; do if [[ "$x" =~ ^([0-9]+)-([0-9]+)$ ]]; then for ((n=BASH_REMATCH[1];n<=BASH_REMATCH[2];n++)); do printf "%02d\n" "$n"; done; else [[ "$x" =~ ^[0-9]+$ ]] && printf "%02d\n" "$x"; fi; done | sort -u)
                if [ ${#ids[@]} -gt 0 ]; then
                    panel_delete_node_ids "${ids[@]}"
                    local rc=$?
                    [ "$rc" = "0" ] && panel_pending_queue_remove "${ids[@]}"
                    [ "$rc" = "2" ] && panel_pending_queue_add "core-ok-hosts-unconfirmed" "${ids[@]}"
                fi
                read -r -p 'Press Enter...' < /dev/tty
                ;;
            5) [ "$pend" != "0" ] && panel_pending_queue_show_and_retry ;;
            4) rm -f "$PANEL_CONF"; unset URL USER TOKEN; echo '[+] Logged out.'; return ;;
            0) return ;;
        esac
    done
}

extract_json_from_response() {
    local resp="$1"
    if echo "$resp" | jq -e '.inbounds' >/dev/null 2>&1; then echo "$resp"; return 0; fi
    local nested=$(echo "$resp" | jq -r '.config // .content // .xray_config // empty' 2>/dev/null)
    if [ -n "$nested" ]; then
        if echo "$nested" | jq -e '.inbounds' >/dev/null 2>&1; then echo "$nested"; return 0; fi
        local parsed=$(echo "$nested" | jq 'fromjson' 2>/dev/null || echo "")
        if echo "$parsed" | jq -e '.inbounds' >/dev/null 2>&1; then echo "$parsed"; return 0; fi
    fi
    echo ""
}


panel_sync_single() {
    local idx="$1" code name out_port
    IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
    panel_auth_preflight || return $?
    panel_lock_acquire || return 1
    trap 'panel_lock_release' RETURN
    local core_file="$BASE_DIR/remote_core.json" hosts_file="$BASE_DIR/panel_hosts.json"
    panel_core_fetch "$core_file" || { panel_lock_release; trap - RETURN; return 1; }
    panel_load_hosts "$hosts_file" || true
    panel_validate_templates "$core_file" "$hosts_file" || { panel_lock_release; trap - RETURN; return 2; }
    local in_idx=$((PANEL_INBOUND_INDEX-1)) clone_inbound_json rand_port in_tag out_tag safe_name new_remark cloned_sni='' clone_host_json='{}'
    clone_inbound_json=$(jq ".inbounds[$in_idx]" "$core_file") || { panel_lock_release; trap - RETURN; return 1; }
    [ "$clone_inbound_json" != "null" ] || { panel_lock_release; trap - RETURN; return 1; }
    safe_name=$(printf '%s' "$name" | tr -d ' ' | tr -cd 'a-zA-Z0-9-'); new_remark="${EMOJIS[$code]} $name"
    if jq -e --arg c "$code" --arg s "$safe_name" '.[]? | select((.inbound_tag // "") | startswith($c+"-"+$s+"-IN-"))' "$hosts_file" >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] ${EMOJIS[$code]} $name is already represented by a Host in the Panel. Skipping duplicate.${NC}"
        panel_lock_release; trap - RETURN; return 0
    fi
    local -A used_ports=() used_intags=() used_outtags=()
    while IFS= read -r rand_port; do [ -n "$rand_port" ] && used_ports["$rand_port"]=1; done < <(jq -r '.inbounds[]?.port // empty' "$core_file")
    while IFS= read -r rand_port; do [ -n "$rand_port" ] && used_intags["$rand_port"]=1; done < <(jq -r '.inbounds[]?.tag // empty' "$core_file")
    while IFS= read -r rand_port; do [ -n "$rand_port" ] && used_outtags["$rand_port"]=1; done < <(jq -r '.outbounds[]?.tag // empty' "$core_file")
    local attempts=0
    while :; do
        attempts=$((attempts+1)); [ "$attempts" -le 20000 ] || { echo -e "${RED}[!] Could not allocate a free inbound port/tag after 20,000 attempts.${NC}"; panel_lock_release; trap - RETURN; return 1; }
        rand_port=$(( RANDOM % 30000 + 20000 )); in_tag="${code}-${safe_name}-IN-${rand_port}"; out_tag="${code}-${safe_name}-OUT-${out_port}"
        if [[ -z "${used_ports[$rand_port]:-}" && -z "${used_intags[$in_tag]:-}" && -z "${used_outtags[$out_tag]:-}" ]]; then break; fi
    done
    if (( PANEL_HOST_INDEX > 0 )); then clone_host_json=$(jq ".[$((PANEL_HOST_INDEX-1))]" "$hosts_file"); cloned_sni=$(jq -r ".[$((PANEL_HOST_INDEX-1))].address | if type==\"array\" and length>0 then .[0] elif type==\"string\" then . else \"\" end" "$hosts_file"); fi
    local additions="$BASE_DIR/panel_single_additions.json" core_payload="$BASE_DIR/panel_sync_payload.json" response="$BASE_DIR/panel_sync_response.json"
    jq -n --argjson tmpl "$clone_inbound_json" --arg c "$code" --arg n "$name" --arg p "$out_port" \
        --arg in_tag "$in_tag" --arg out_tag "$out_tag" --argjson in_port "$rand_port" \
        --arg addr "$cloned_sni" --argjson htmpl "$clone_host_json" --arg rem "$new_remark" \
        '{inbound:($tmpl|.port=$in_port|.tag=$in_tag),outbound:{tag:$out_tag,protocol:"socks",settings:{servers:[{address:"127.0.0.1",port:($p|tonumber)}]}},route:{type:"field",inboundTag:[$in_tag],outboundTag:$out_tag},host:(if ($htmpl|type)=="object" and ($htmpl|length)>0 then ($htmpl|del(.id,.created_at,.updated_at,.enable)|.inbound_tag=$in_tag|.port=$in_port|.remark=$rem|.is_disabled=false|.priority=(.priority // $in_port)) else {remark:$rem,inbound_tag:$in_tag,address:(if $addr=="" then [] else [$addr] end),port:$in_port,is_disabled:false,priority:$in_port} end)}' \
        > "$additions"
    jq --slurpfile a "$additions" '.inbounds += [$a[0].inbound] | .outbounds += [$a[0].outbound] | .routing = (.routing // {rules:[]}) | .routing.rules = ((.routing.rules // []) + [$a[0].route])' "$core_file" > "$BASE_DIR/panel_sync_core.json" || { panel_lock_release; trap - RETURN; return 1; }
    local original_core_name core_type exclude_tags fallback_tags
    original_core_name=$(jq -r '.name // empty' "$PANEL_CORE_RESPONSE_FILE"); core_type=$(jq -c '.type // null' "$PANEL_CORE_RESPONSE_FILE"); exclude_tags=$(jq -c '.exclude_inbound_tags // []' "$PANEL_CORE_RESPONSE_FILE"); fallback_tags=$(jq -c '.fallbacks_inbound_tags // []' "$PANEL_CORE_RESPONSE_FILE")
    jq -n --arg name "$original_core_name" --slurpfile config "$BASE_DIR/panel_sync_core.json" --argjson type "$core_type" --argjson ex "$exclude_tags" --argjson fb "$fallback_tags" \\
        '{name:$name,config:$config[0],type:$type,exclude_inbound_tags:$ex,fallbacks_inbound_tags:$fb}' > "$core_payload"
    local http; http=$(panel_request PUT "/api/core/${PANEL_CORE_ID}?restart_nodes=true" "$core_payload" "$response")
    if ! panel_http_ok "$http"; then
        echo -e "${RED}[!] Panel core sync failed: HTTP $http${NC}"; jq -r '.detail // .' "$response" 2>/dev/null | head -n 10 >&2; panel_lock_release; trap - RETURN; return 1
    fi
    http=$(panel_request POST /api/host/ "$additions" "$response")
    local host_id=""
    if panel_http_ok "$http"; then host_id=$(jq -r '.id // empty' "$response" 2>/dev/null); fi
    if [ -z "$host_id" ] && [ "$http" = "409" ]; then
        panel_load_hosts "$hosts_file" || true; host_id=$(panel_find_host_id "$hosts_file" "$in_tag" "$rand_port" "$new_remark")
        if [ -n "$host_id" ]; then echo -e "${YELLOW}[~] Host already existed; reconciled it to ID $host_id.${NC}"; fi
    fi
    if ! [[ "$host_id" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}[!] Host creation failed (HTTP $http); rolling Core back to its original configuration.${NC}"
        local rollback="$BASE_DIR/panel_sync_rollback.json" rollback_code
        jq -n --arg name "$original_core_name" --argjson config "$(cat "$core_file")" --argjson type "$core_type" --argjson ex "$exclude_tags" --argjson fb "$fallback_tags" '{name:$name,config:$config,type:$type,exclude_inbound_tags:$ex,fallbacks_inbound_tags:$fb}' > "$rollback"
        rollback_code=$(panel_request PUT "/api/core/${PANEL_CORE_ID}?restart_nodes=true" "$rollback" "$response")
        rm -f "$rollback" "$additions" "$core_payload" "$response" "$BASE_DIR/panel_sync_core.json"
        if panel_http_ok "$rollback_code"; then echo -e "${YELLOW}[!] Core rollback succeeded; no orphan was left behind.${NC}"; panel_lock_release; trap - RETURN; return 1; fi
        panel_meta_write "$code" "$out_port" "$PANEL_CORE_ID" "$in_tag" "$out_tag" "$rand_port" ""
        echo -e "${RED}[!] Core rollback failed (HTTP $rollback_code). Panel may be inconsistent; metadata was preserved for manual recovery.${NC}"
        panel_lock_release; trap - RETURN; return 2
    fi
    panel_meta_write "$code" "$out_port" "$PANEL_CORE_ID" "$in_tag" "$out_tag" "$rand_port" "$host_id"
    echo -e "${GREEN}[+] ${EMOJIS[$code]} $name synchronized to Panel (core=$PANEL_CORE_ID host=$host_id).${NC}"
    rm -f "$additions" "$core_payload" "$response" "$BASE_DIR/panel_sync_core.json"
    panel_lock_release; trap - RETURN; return 0
}


panel_batch_create() {
    panel_auth_preflight || return $?
    panel_lock_acquire || { echo -e "${RED}[!] Could not acquire Panel write lock.${NC}"; return 1; }
    trap 'panel_lock_release' RETURN
    panel_conf_safe_load || true
    local installed=() idx code name out_port
    for idx in "${ORDER[@]}"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        node_has_record "$code" "$out_port" && installed+=("$idx")
    done
    if [ ${#installed[@]} -eq 0 ]; then echo -e "${RED}[!] No deployed Tor nodes found.${NC}"; panel_lock_release; trap - RETURN; return; fi
    echo -e "\n📌 ${MAGENTA}[ INSTALLED NODES TO ADD ]${NC}"
    for idx in "${installed[@]}"; do IFS=':' read -r code name out_port <<< "${NODES[$idx]}"; printf '  [%s] %b %-22s TorPort:%s\n' "$idx" "${EMOJIS[$code]}" "$name" "$out_port"; done
    local user_selection selected_nodes=() parsed_id is_installed inst_node
    read -r -p "Select Node IDs (e.g. 01,05) or 'all' [Default: all]: " user_selection < /dev/tty || { panel_lock_release; trap - RETURN; return; }
    if [[ -z "$user_selection" || "${user_selection,,}" == all ]]; then selected_nodes=("${installed[@]}"); else
        while IFS= read -r parsed_id; do
            [ -n "$parsed_id" ] || continue; is_installed=0
            for inst_node in "${installed[@]}"; do [[ "$inst_node" == "$parsed_id" ]] && is_installed=1 && break; done
            [ "$is_installed" -eq 1 ] && selected_nodes+=("$parsed_id") || echo -e "${YELLOW}[!] Node $parsed_id is not installed/valid; skipping.${NC}"
        done < <(parse_node_selection "$user_selection")
    fi
    [ ${#selected_nodes[@]} -gt 0 ] || { echo -e "${RED}[!] No valid nodes selected.${NC}"; panel_lock_release; trap - RETURN; return; }
    local CORE_FILE="$BASE_DIR/remote_core.json" HOSTS_FILE="$BASE_DIR/panel_hosts.json"
    panel_core_fetch "$CORE_FILE" || { panel_lock_release; trap - RETURN; return 1; }
    panel_load_hosts "$HOSTS_FILE" || true
    local inb_count; inb_count=$(jq '.inbounds // [] | length' "$CORE_FILE")
    (( inb_count > 0 )) || { echo -e "${RED}[!] Selected Core has no inbounds to clone.${NC}"; panel_lock_release; trap - RETURN; return 1; }
    echo -e "\n📌 ${MAGENTA}[ SELECT INBOUND TO CLONE FROM ]${NC}"
    local i tag port proto net sec
    for ((i=0;i<inb_count;i++)); do tag=$(jq -r ".inbounds[$i].tag // \"\"" "$CORE_FILE"); port=$(jq -r ".inbounds[$i].port // \"\"" "$CORE_FILE"); proto=$(jq -r ".inbounds[$i].protocol // \"\"" "$CORE_FILE"); net=$(jq -r ".inbounds[$i].streamSettings.network // .settings.network // \"tcp\"" "$CORE_FILE"); sec=$(jq -r ".inbounds[$i].streamSettings.security // \"none\"" "$CORE_FILE"); printf '  [%d] port=%-6s %-10s %-8s %-8s %s\n' "$((i+1))" "$port" "$proto" "$net" "$sec" "$tag"; done
    local inb_sel real_index clone_inbound_json; read -r -p 'Select inbound to clone: ' inb_sel < /dev/tty || { panel_lock_release; trap - RETURN; return; }; [[ "$inb_sel" =~ ^[0-9]+$ ]] || { panel_lock_release; trap - RETURN; return 1; }; real_index=$((inb_sel-1)); (( real_index >= 0 && real_index < inb_count )) || { panel_lock_release; trap - RETURN; return 1; }; clone_inbound_json=$(jq ".inbounds[$real_index]" "$CORE_FILE")
    local cloned_sni='' clone_host_json='{}' host_count; host_count=$(jq 'length' "$HOSTS_FILE" 2>/dev/null || echo 0)
    if (( host_count > 0 )); then
        echo -e "\n📌 ${MAGENTA}[ SELECT HOST TO CLONE FROM ]${NC}"; for ((i=0;i<host_count;i++)); do local hr ha hp; hr=$(jq -r ".[$i].remark // \"\"" "$HOSTS_FILE"); ha=$(jq -r ".[$i].address | if type==\"array\" and length>0 then .[0] else (if type==\"string\" then . else \"\" end) end" "$HOSTS_FILE"); hp=$(jq -r ".[$i].port // \"-\"" "$HOSTS_FILE"); printf '  [%d] %-28s %-30s port=%s\n' "$((i+1))" "$hr" "$ha" "$hp"; done
        local host_sel; read -r -p 'Enter host # to clone (0=none): ' host_sel < /dev/tty || host_sel=0
        if [[ "$host_sel" =~ ^[0-9]+$ ]] && (( host_sel > 0 && host_sel <= host_count )); then clone_host_json=$(jq ".[$((host_sel-1))]" "$HOSTS_FILE"); cloned_sni=$(jq -r ".[$((host_sel-1))].address | if type==\"array\" and length>0 then .[0] elif type==\"string\" then . else \"\" end" "$HOSTS_FILE"); fi
    fi
    local add_tsv="$BASE_DIR/panel_batch_add.tsv" additions="$BASE_DIR/panel_batch_additions.json" core_payload="$BASE_DIR/panel_batch_core_payload.json" response="$BASE_DIR/panel_batch_response.json" core_new="$BASE_DIR/panel_batch_core.json"
    : > "$add_tsv"
    local -A used_ports=() used_intags=() used_outtags=()
    while IFS= read -r v; do [ -n "$v" ] && used_ports["$v"]=1; done < <(jq -r '.inbounds[]?.port // empty' "$CORE_FILE")
    while IFS= read -r v; do [ -n "$v" ] && used_intags["$v"]=1; done < <(jq -r '.inbounds[]?.tag // empty' "$CORE_FILE")
    while IFS= read -r v; do [ -n "$v" ] && used_outtags["$v"]=1; done < <(jq -r '.outbounds[]?.tag // empty' "$CORE_FILE")
    local rand_port safe_name in_tag out_tag new_remark attempts existing_host
    for idx in "${selected_nodes[@]}"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"; safe_name=$(printf '%s' "$name" | tr -d ' ' | tr -cd 'a-zA-Z0-9-'); new_remark="${EMOJIS[$code]} $name"
        existing_host=$(jq -r --arg c "$code" --arg s "$safe_name" 'first(.[]? | select((.inbound_tag//"")|startswith($c+"-"+$s+"-IN-")) | .id) // empty' "$HOSTS_FILE")
        if [[ "$existing_host" =~ ^[0-9]+$ ]]; then echo -e "${YELLOW}[~] $new_remark already exists as Host ID $existing_host; skipped.${NC}"; continue; fi
        attempts=0
        while :; do
            attempts=$((attempts+1)); [ "$attempts" -le 20000 ] || { echo -e "${RED}[!] Port allocation exhausted while adding $name.${NC}"; break 2; }
            rand_port=$(( RANDOM % 30000 + 20000 )); in_tag="${code}-${safe_name}-IN-${rand_port}"; out_tag="${code}-${safe_name}-OUT-${out_port}"
            if [[ -z "${used_ports[$rand_port]:-}" && -z "${used_intags[$in_tag]:-}" && -z "${used_outtags[$out_tag]:-}" ]]; then break; fi
        done
        used_ports["$rand_port"]=1; used_intags["$in_tag"]=1; used_outtags["$out_tag"]=1
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$idx" "$code" "$name" "$out_port" "$rand_port" "$in_tag" "$out_tag" "${EMOJIS[$code]:-🌐}" >> "$add_tsv"
    done
    [ -s "$add_tsv" ] || { echo -e "${YELLOW}[!] Nothing new to add.${NC}"; rm -f "$add_tsv"; panel_lock_release; trap - RETURN; return 0; }
    echo -e "\n${CYAN}⚙ Generating Core changes in one JSON pass...${NC}"
    jq -Rn --argjson tmpl "$clone_inbound_json" --argjson htmpl "$clone_host_json" --arg addr "$cloned_sni" '
      [inputs | split("\t") | {idx:(.[0]|tonumber),code:.[1],name:.[2],remark:((.[7] // "🌐")+" "+.[2]),out_port:(.[3]|tonumber),in_port:(.[4]|tonumber),in_tag:.[5],out_tag:.[6]}] as $rows |
      {inbounds:[$rows[] | . as $r | ($tmpl | .port=$r.in_port | .tag=$r.in_tag)],
       outbounds:[$rows[] | {tag:.out_tag,protocol:"socks",settings:{servers:[{address:"127.0.0.1",port:.out_port}]} }],
       routes:[$rows[] | {type:"field",inboundTag:[.in_tag],outboundTag:.out_tag}],
       hosts:[$rows[] | . as $r | (if ($htmpl|type)=="object" and ($htmpl|length)>0 then ($htmpl | del(.id,.created_at,.updated_at,.enable) | .remark=$r.remark | .inbound_tag=$r.in_tag | .port=$r.in_port | .is_disabled=false | .priority=(.priority // $r.in_port)) else {remark:$r.remark,inbound_tag:$r.in_tag,address:(if $addr=="" then [] else [$addr] end),port:$r.in_port,is_disabled:false,priority:$r.in_port} end)]}' < "$add_tsv" > "$additions"
    if ! jq --slurpfile a "$additions" '.inbounds += $a[0].inbounds | .outbounds += $a[0].outbounds | .routing=(.routing//{rules:[]}) | .routing.rules=((.routing.rules//[])+$a[0].routes)' "$CORE_FILE" > "$core_new"; then echo -e "${RED}[!] Generated Xray config is invalid JSON; nothing uploaded.${NC}"; panel_lock_release; trap - RETURN; return 1; fi
    if ! jq -e '(.inbounds|type=="array") and (.outbounds|type=="array") and (([.inbounds[].tag]|length)==([.inbounds[].tag]|unique|length))' "$core_new" >/dev/null; then echo -e "${RED}[!] Core validation failed (missing arrays or duplicate inbound tags).${NC}"; panel_lock_release; trap - RETURN; return 1; fi
    local original_core_name core_type exclude_tags fallback_tags
    original_core_name=$(jq -r '.name // empty' "$PANEL_CORE_RESPONSE_FILE"); core_type=$(jq -c '.type // null' "$PANEL_CORE_RESPONSE_FILE"); exclude_tags=$(jq -c '.exclude_inbound_tags // []' "$PANEL_CORE_RESPONSE_FILE"); fallback_tags=$(jq -c '.fallbacks_inbound_tags // []' "$PANEL_CORE_RESPONSE_FILE")
    jq -n --arg name "$original_core_name" --slurpfile config "$core_new" --argjson type "$core_type" --argjson ex "$exclude_tags" --argjson fb "$fallback_tags" '{name:$name,config:$config[0],type:$type,exclude_inbound_tags:$ex,fallbacks_inbound_tags:$fb}' > "$core_payload"
    echo -e "${CYAN}↳ Uploading Core /api/core/${PANEL_CORE_ID} ...${NC}"
    local http; http=$(panel_request PUT "/api/core/${PANEL_CORE_ID}?restart_nodes=true" "$core_payload" "$response")
    if ! panel_http_ok "$http"; then echo -e "${RED}[!] Core update failed: HTTP $http${NC}"; jq -r '.detail // .' "$response" 2>/dev/null | head -n 12 >&2; panel_lock_release; trap - RETURN; return 1; fi
    local verify_core="$BASE_DIR/panel_batch_verify.json"
    http=$(panel_request GET "/api/core/${PANEL_CORE_ID}" "" "$verify_core")
    if [ "$http" != "200" ] || ! jq -e --slurpfile a "$additions" '([ $a[0].inbounds[].tag ] - [.config.inbounds[]?.tag]) == [] and ([ $a[0].outbounds[].tag ] - [.config.outbounds[]?.tag]) == []' "$verify_core" >/dev/null 2>&1; then
        echo -e "${RED}[!] Core write could not be verified on the server. Aborting Host creation.${NC}"; rm -f "$add_tsv" "$additions" "$core_payload" "$response" "$core_new" "$verify_core"; panel_lock_release; trap - RETURN; return 2
    fi
    echo -e "${GREEN}[+] Core accepted and verified. Creating Hosts on /api/host/.${NC}"
    local host_len h h_code h_data host_id code2 name2 out_port2 in_tag2 out_tag2 failed=0 failed_tsv="$BASE_DIR/panel_batch_failed.tsv"
    : > "$failed_tsv"
    host_len=$(jq '.hosts | length' "$additions")
    for ((h=0;h<host_len;h++)); do
        h_data="$BASE_DIR/one_host.json"; jq ".hosts[$h]" "$additions" > "$h_data"; h_code=$(panel_request POST /api/host/ "$h_data" "$response"); host_id=""
        if panel_http_ok "$h_code"; then host_id=$(jq -r '.id // empty' "$response" 2>/dev/null); fi
        in_tag2=$(jq -r '.inbound_tag' "$h_data"); code2=$(awk -F'\t' -v t="$in_tag2" '$6==t{print $2; exit}' "$add_tsv"); name2=$(awk -F'\t' -v t="$in_tag2" '$6==t{print $3; exit}' "$add_tsv"); out_port2=$(awk -F'\t' -v t="$in_tag2" '$6==t{print $4; exit}' "$add_tsv"); out_tag2=$(awk -F'\t' -v t="$in_tag2" '$6==t{print $7; exit}' "$add_tsv")
        if [ -z "$host_id" ] && [ "$h_code" = "409" ]; then panel_load_hosts "$HOSTS_FILE" || true; host_id=$(panel_find_host_id "$HOSTS_FILE" "$in_tag2" "" "${EMOJIS[$code2]} $name2"); fi
        if [[ "$host_id" =~ ^[0-9]+$ ]]; then
            panel_meta_write "$code2" "$out_port2" "$PANEL_CORE_ID" "$in_tag2" "$out_tag2" "$(jq -r '.port' "$h_data")" "$host_id" || true
            echo -e "  ✅ $name2 -> Host ID $host_id"
        else
            echo -e "  ❌ $name2 -> Host creation failed (HTTP $h_code); this node will be rolled back from the Core."
            printf '%s\t%s\t%s\t%s\t%s\n' "$(awk -F'\t' -v t="$in_tag2" '$6==t{print $1; exit}' "$add_tsv")" "$in_tag2" "$out_tag2" "$code2" "$out_port2" >> "$failed_tsv"
            failed=$((failed+1))
        fi
    done
    if (( failed > 0 )); then
        echo -e "${YELLOW}[!] $failed Host(s) failed; rolling those Core entries back instead of leaving orphaned Xray objects.${NC}"
        local rolled_core="$BASE_DIR/panel_batch_rolled_core.json" rollback_payload="$BASE_DIR/panel_batch_rollback_payload.json"
        if jq --rawfile bad "$failed_tsv" '($bad|split("\n")|map(select(length>0)|split("\t"))) as $badrows |
          def drop_in($t): any($badrows[]; . as $r | $t==$r[1]);
          def drop_out($t): any($badrows[]; . as $r | $t==$r[2]);
          .inbounds=[(.inbounds//[])[]|select(drop_in(.tag)|not)]|
          .outbounds=[(.outbounds//[])[]|select(drop_out(.tag)|not)]|
          .routing=(.routing//{rules:[]})|.routing.rules=[(.routing.rules//[])[]|select(any(.inboundTag[]?; drop_in(.))|not)|select(drop_out(.outboundTag)|not)]' "$core_new" > "$rolled_core"; then
            jq -n --arg name "$original_core_name" --slurpfile config "$rolled_core" --argjson type "$core_type" --argjson ex "$exclude_tags" --argjson fb "$fallback_tags" '{name:$name,config:$config[0],type:$type,exclude_inbound_tags:$ex,fallbacks_inbound_tags:$fb}' > "$rollback_payload"
            local rb_http; rb_http=$(panel_request PUT "/api/core/${PANEL_CORE_ID}?restart_nodes=true" "$rollback_payload" "$response")
            if panel_http_ok "$rb_http"; then echo -e "${GREEN}[+] Rollback of failed Core entries succeeded.${NC}"; else echo -e "${RED}[!] Rollback failed (HTTP $rb_http). Manual Panel reconciliation is required.${NC}"; fi
        else
            echo -e "${RED}[!] Could not construct rollback Core JSON.${NC}"
        fi
        rm -f "$rolled_core" "$rollback_payload"
    fi
    echo -e "${GREEN}[+] Batch synchronization finished. No artificial 15-second wait was used; Core writes are server-verified and Host creates are reconciled by returned IDs.${NC}"
    rm -f "$add_tsv" "$additions" "$core_payload" "$response" "$core_new" "$BASE_DIR/one_host.json" "$failed_tsv" "$verify_core"
    panel_lock_release; trap - RETURN; if (( failed > 0 )); then return 2; else return 0; fi
}

if [ "${1:-}" = "--install" ]; then
    install_engine
    exit 0
fi

# ================= MENU LOOP =================
toggle_auto_heal() {
    check_root
    draw_header
    echo -e "📌 ${MAGENTA}[ AUTO-HEAL SERVICE ]${NC}\n"
    if systemctl is-active --quiet sherlook-heal.service 2>/dev/null; then
        echo -e "${GREEN}Auto-Heal is currently ACTIVE.${NC}"
        echo -e "${YELLOW}[!] While active, it will stop/restart any node it judges unhealthy${NC}"
        echo -e "${YELLOW}    (dead process, SOCKS unreachable, or wrong-country IP).${NC}\n"
        echo -e "  ${CYAN}[1]${NC} Stop it for this boot only (systemctl stop)"
        echo -e "  ${CYAN}[2]${NC} Stop it AND disable it permanently (survives reboot)"
        echo -e "  ${RED}[0]${NC} Leave it running / go back"
        read -r -p "Choice [0-2]: " ah_choice < /dev/tty || return
        case "$ah_choice" in
            1) systemctl stop sherlook-heal.service; echo -e "${GREEN}[+] Stopped. It will come back on the next reboot.${NC}" ;;
            2) systemctl disable --now sherlook-heal.service; echo -e "${GREEN}[+] Stopped and disabled. It will NOT come back automatically.${NC}" ;;
            *) echo -e "${CYAN}[*] No change.${NC}" ;;
        esac
    else
        echo -e "${YELLOW}Auto-Heal is currently INACTIVE.${NC}"
        echo -e "${CYAN}[!] Nodes that die or drift off-country will NOT be repaired automatically${NC}"
        echo -e "${CYAN}    while it's off -- use option [8] to rotate them by hand instead.${NC}\n"
        echo -e "  ${CYAN}[1]${NC} Start it now and enable it (recommended)"
        echo -e "  ${CYAN}[2]${NC} Start it for this boot only (won't survive reboot)"
        echo -e "  ${RED}[0]${NC} Leave it off / go back"
        read -r -p "Choice [0-2]: " ah_choice < /dev/tty || return
        case "$ah_choice" in
            1) systemctl enable --now sherlook-heal.service; echo -e "${GREEN}[+] Started and enabled.${NC}" ;;
            2) systemctl start sherlook-heal.service; echo -e "${GREEN}[+] Started for this boot only.${NC}" ;;
            *) echo -e "${CYAN}[*] No change.${NC}" ;;
        esac
    fi
    sleep 2
}

while true; do
    draw_header
    if command -v tor &> /dev/null && command -v jq &> /dev/null; then
        if systemctl is-active --quiet sherlook-heal.service 2>/dev/null; then
            echo -e "   ${WHITE}System Status:${NC} ${GREEN}Engine Ready + Auto-Heal Active${NC}"
        else
            echo -e "   ${WHITE}System Status:${NC} ${GREEN}Engine Ready${NC} ${YELLOW}(Auto-Heal service inactive)${NC}"
        fi
    else
        echo -e "   ${WHITE}System Status:${NC} ${RED}Not Ready${NC}"
    fi
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${CYAN}[1]${NC} ${WHITE}»${NC} Install Engine & Core Tools"
    echo -e "  ${CYAN}[2]${NC} ${WHITE}»${NC} Update System (Online)"
    echo -e "  ${CYAN}[3]${NC} ${WHITE}»${NC} Uninstall System"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}[4]${NC} ${WHITE}»${NC} Add Location Node (Single)"
    echo -e "  ${GREEN}[5]${NC} ${WHITE}»${NC} Bulk Add Nodes (Multiple/All)"
    echo -e "  ${GREEN}[6]${NC} ${WHITE}»${NC} View Active Nodes"
    echo -e "  ${GREEN}[7]${NC} ${WHITE}»${NC} Edit or Delete Nodes"
    echo -e "  ${CYAN}[8]${NC} ${WHITE}»${NC} 🔄 Change IP / IP Rotation"
    echo -e "  ${CYAN}[A]${NC} ${WHITE}»${NC} Toggle Auto-Heal Service (on/off)"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${YELLOW}[9]${NC} ${WHITE}»${NC} Panel Nexatis Integration"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${RED}[0]${NC} ${WHITE}»${NC} Exit Program"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}\n"

    if ! read -r -p "$(echo -e ${MAGENTA}"Enter choice [0-9/A]: "${NC})" main_choice < /dev/tty; then
        echo -e "\n${RED}[!] No terminal input available (are you piping this, e.g. curl | bash?). Exiting.${NC}"
        exit 1
    fi

    case "${main_choice,,}" in
        1) install_engine ;;
        2) update_system ;;
        8) change_ip_menu ;;
        3) uninstall_engine ;;
        4) add_single_node ;;
        5) bulk_add_nodes ;;
        6) view_active_nodes ;;
        7) edit_delete_nodes ;;
        a) toggle_auto_heal ;;
        9) check_root; panel_login ;;
        0) clear; exit 0 ;;
        *) ;;
    esac
done
