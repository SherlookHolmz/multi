#!/usr/bin/env bash
# Sherlook Automate Engine v6.4.0 (Nexatis API Edition)
# Bugfix release: preserves the existing engine/UI while fixing torrc validation and in-place updates

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
SHERLOOK_VERSION="6.4.0"
LOCATION_CACHE="$DATA_DIR/onionoo_exit_countries.cache"
LOCATION_CATALOG="$DATA_DIR/location_catalog.tsv"
LOCATION_CACHE_TTL=21600
AUTO_HEAL_INTERVAL=5
AUTO_HEAL_PARALLEL=16
EFFECTIVE_PARALLEL=16
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
    local ip="$1" expected="$2"
    local result bad actual reason seen
    result=$(check_ip_quality "$ip" "$expected")
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

onionoo_exit_count() {
    local code="${1,,}"
    local tmp count

    tmp=$(mktemp /tmp/sherlook_onionoo.XXXXXX) || {
        echo "-1"
        return 0
    }

    if ! curl -4 -fsS \
        --connect-timeout 5 \
        --max-time "$ONIONOO_TIMEOUT" \
        "${ONIONOO_URL}?country=${code}&flag=Exit&running=true&fields=fingerprint,or_addresses,country,flags,last_seen" \
        -o "$tmp" 2>/dev/null; then
        rm -f "$tmp"
        echo "-1"
        return 0
    fi

    count=$(jq -r '.relays // [] | length' "$tmp" 2>/dev/null || echo "0")
    rm -f "$tmp"

    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    echo "$count"
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
    local tmpdir
    tmpdir=$(mktemp -d /tmp/sherlook_geo.XXXXXX) || { echo "1||GEOIP_UNAVAILABLE|"; return; }

    curl -4 -sS --connect-timeout 3 --max-time 6 "https://api.ipapi.is/?q=$ip" >"$tmpdir/a" 2>/dev/null & local p1=$!
    curl -4 -sS --connect-timeout 3 --max-time 6 "https://ipwho.is/$ip" >"$tmpdir/b" 2>/dev/null & local p2=$!
    curl -4 -sS --connect-timeout 3 --max-time 6 "https://ipapi.co/$ip/json/" >"$tmpdir/c" 2>/dev/null & local p3=$!
    wait "$p1" "$p2" "$p3" 2>/dev/null || true

    local api1 api2 api3 cc1 cc2 cc3
    api1=$(cat "$tmpdir/a" 2>/dev/null || true)
    api2=$(cat "$tmpdir/b" 2>/dev/null || true)
    api3=$(cat "$tmpdir/c" 2>/dev/null || true)

    cc1=$(printf '%s' "$api1" | jq -r '.location.country_code // .country_code // empty' 2>/dev/null | tr '[:lower:]' '[:upper:]')
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

send_newnym() {
    # 6.4.0 deliberately keeps the primary torrc minimal. A node may have a
    # legacy control.env, but NEWNYM is optional; callers must rebuild the
    # instance when this function returns non-zero.
    local control_port="${1:-}" pass="${2:-}" response
    [ -n "$control_port" ] || return 1
    exec 3<>"/dev/tcp/127.0.0.1/${control_port}" 2>/dev/null || return 1
    printf 'AUTHENTICATE "%s"\r\n' "$pass" >&3 || { exec 3<&- 3>&-; return 1; }
    response=$(timeout 3 cat <&3 2>/dev/null | head -n 5 || true)
    if ! grep -q '^250 OK' <<< "$response"; then
        exec 3<&- 3>&-
        return 1
    fi
    printf 'SIGNAL NEWNYM\r\nQUIT\r\n' >&3 || { exec 3<&- 3>&-; return 1; }
    response=$(timeout 3 cat <&3 2>/dev/null | head -n 5 || true)
    exec 3<&- 3>&-
    grep -q '^250 OK' <<< "$response"
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
    result=$(check_ip_quality "$current_ip" "$expected_route"); IFS='|' read -r bad actual reason seen <<< "$result"
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
    check_root
    sync_dynamic_locations
    compute_effective_parallel
    if bridge_available; then bridge_validate || return 1; fi
    local idx details code name out_port running=0
    local -a pids=()
    for idx in "${ORDER[@]}"; do
        details="${NODES[$idx]}"; IFS=':' read -r code name out_port <<< "$details"
        [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] || continue
        health_check_node "$code" "$name" "$out_port" 1 1 & pids+=("$!"); running=$((running+1))
        if (( running >= EFFECTIVE_PARALLEL )); then
            wait "${pids[0]}" 2>/dev/null || true; pids=("${pids[@]:1}"); running=$((running-1))
        fi
    done
    for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
}

auto_heal_daemon() {
    check_root
    trap 'exit 0' INT TERM HUP
    while true; do
        background_auto_heal || true
        sleep "$AUTO_HEAL_INTERVAL"
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


# ================= V6.4.0 HEALTH / BRIDGE / PANEL SAFETY =================

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

panel_auth_preflight() {
    panel_conf_safe_load || return 1
    [ -n "${URL:-}" ] && [ -n "${TOKEN:-}" ] || return 1
    local code
    code=$(curl -4 -sk -o /dev/null -w '%{http_code}' --max-time 8 "$URL/api/nodes" -H "Authorization: Bearer $TOKEN" -H 'accept: application/json' 2>/dev/null || echo 000)
    if [ "$code" = "401" ]; then
        echo -e "${YELLOW}[!] Panel session expired (HTTP 401). Please login again from option 9.${NC}"
        return 2
    fi
    [ "$code" != "000" ] || return 1
    return 0
}

panel_core_fetch() {
    local core_file="$1"; CORE_API_URL=""
    local eps=(/api/admin/cores /api/cores /api/core /api/node/cores /api/admin/core)
    local ep id resp extracted ids
    : > "$core_file"
    for ep in "${eps[@]}"; do
        resp=$(curl -4 -sk --max-time 10 -X GET "$URL$ep/1" -H "Authorization: Bearer $TOKEN" -H 'accept: application/json' 2>/dev/null || true)
        extracted=$(extract_json_from_response "$resp")
        if [ -n "$extracted" ]; then printf '%s\n' "$extracted" > "$core_file"; CORE_API_URL="$URL$ep/1"; return 0; fi
        resp=$(curl -4 -sk --max-time 10 -X GET "$URL$ep" -H "Authorization: Bearer $TOKEN" -H 'accept: application/json' 2>/dev/null || true)
        ids=$(printf '%s' "$resp" | jq -r '.[].id // .data[].id // empty' 2>/dev/null | head -n1)
        if [ -n "$ids" ]; then
            id="$ids"
            resp=$(curl -4 -sk --max-time 10 -X GET "$URL$ep/$id" -H "Authorization: Bearer $TOKEN" -H 'accept: application/json' 2>/dev/null || true)
            extracted=$(extract_json_from_response "$resp")
            if [ -n "$extracted" ]; then printf '%s\n' "$extracted" > "$core_file"; CORE_API_URL="$URL$ep/$id"; return 0; fi
        fi
    done
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

panel_load_hosts() {
    local out="$1" resp
    resp=$(curl -4 -sk --max-time 10 -X GET "$URL/api/hosts" -H "Authorization: Bearer $TOKEN" -H 'accept: application/json' 2>/dev/null || true)
    if printf '%s' "$resp" | jq -e 'type=="array"' >/dev/null 2>&1; then printf '%s\n' "$resp" > "$out"; return 0; fi
    printf '%s' "$resp" | jq -c '.data // []' > "$out" 2>/dev/null
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

panel_delete_node_ids() {
    panel_auth_preflight || return $?
    local core_file="$BASE_DIR/remote_core.json" hosts_file="$BASE_DIR/panel_hosts.json"
    panel_core_fetch "$core_file" || return 1
    panel_load_hosts "$hosts_file"
    local tmp="$BASE_DIR/panel_core_delete.tmp.json" idx code name out_port safe in_prefix out_tag
    local pattern_file="$BASE_DIR/panel_delete_patterns.txt"; : > "$pattern_file"
    for idx in "$@"; do IFS=':' read -r code name out_port <<< "${NODES[$idx]}"; safe=$(printf '%s' "$name" | tr -d ' ' | tr -cd 'a-zA-Z0-9-'); printf '%s|%s|%s\n' "$code" "$safe" "$out_port" >> "$pattern_file"; done
    jq --slurpfile patterns <(jq -R 'split("|")' "$pattern_file" | jq -s '.') '
      def hit($tag): any($patterns[0][]; . as $p | ((($tag // "") | startswith($p[0] + "-" + $p[1] + "-IN-")) or (($tag // "") == ($p[0] + "-" + $p[1] + "-OUT-" + $p[2]))));
      .inbounds = [(.inbounds // [])[] | select(hit(.tag)|not)] |
      .outbounds = [(.outbounds // [])[] | select(hit(.tag)|not)] |
      .routing.rules = [(.routing.rules // [])[] | select((hit(.outboundTag // "")) and false or (((.inboundTag // []) | map(hit(.)) | any) or hit(.outboundTag // "")) | not)]
    ' "$core_file" > "$tmp" 2>/dev/null || return 1
    mv -f "$tmp" "$core_file"
    local original; original=$(curl -4 -sk --max-time 10 -X GET "$CORE_API_URL" -H "Authorization: Bearer $TOKEN" -H 'accept: application/json' 2>/dev/null || true)
    local obj; obj=$(printf '%s' "$original" | jq -r 'if type=="object" and has("data") then .data else . end')
    jq --slurpfile conf "$core_file" 'if .config!=null then .config=$conf[0] elif .xray_config!=null then .xray_config=$conf[0] elif .content!=null then .content=$conf[0] else .config=$conf[0] end' <<< "$obj" > "$BASE_DIR/panel_delete_payload.json"
    local code_http; code_http=$(curl -4 -sk -o /dev/null -w '%{http_code}' -X PUT "$CORE_API_URL" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d @"$BASE_DIR/panel_delete_payload.json" 2>/dev/null || echo 000)
    [[ "$code_http" == 2* ]] || { echo -e "${RED}[!] Panel core delete failed (HTTP $code_http).${NC}"; return 1; }
    if [ -s "$hosts_file" ]; then
        jq --slurpfile patterns <(jq -R 'split("|")' "$pattern_file" | jq -s '.') '[.[] | select(((.inbound_tag // "") as $t | any($patterns[0][]; . as $p | ($t | startswith($p[0] + "-" + $p[1] + "-IN-")))) | not)]' "$hosts_file" > "$BASE_DIR/panel_hosts_filtered.json" || return 1
        code_http=$(curl -4 -sk -o /dev/null -w '%{http_code}' -X PUT "$URL/api/hosts" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d @"$BASE_DIR/panel_hosts_filtered.json" 2>/dev/null || echo 000)
        [[ "$code_http" == 2* ]] || echo -e "${YELLOW}[!] Host delete returned HTTP $code_http.${NC}"
    fi
    rm -f "$pattern_file" "$BASE_DIR/panel_delete_payload.json" "$BASE_DIR/panel_hosts_filtered.json"
    echo -e "${GREEN}[+] Selected node(s) removed from Panel configuration.${NC}"
}

# ================= UI FUNCTIONS =================

draw_header() {
    clear
    echo -e "${MAGENTA} ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ███████╗██╗  ██╗███████╗██████╗ ██╗      ██████╗  ██████╗ ██╗  ██╗${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ██╔════╝██║  ██║██╔════╝██╔══██╗██║     ██╔═══██╗██╔═══██╗██║ ██╔╝${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ███████╗███████║█████╗  ██████╔╝██║     ██║   ██║██║   ██║█████╔╝ ${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ╚════██║██╔══██║██╔══╝  ██╔══██╗██║     ██║   ██║██║   ██║██╔═██╗ ${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ███████║██║  ██║███████╗██║  ██║███████╗╚██████╔╝╚██████╔╝██║  ██╗${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${YELLOW}          A U T O M A T E   E N G I N E   V 6 . 4 . 0                   ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

draw_progress() {
    local text=$1
    for ((i=1; i<=20; i++)); do
        local percent=$((i * 5))
        printf "\r${CYAN}[*] %-40s ${MAGENTA}[${GREEN}" "$text"
        for ((j=1; j<=i; j++)); do printf "█"; done
        for ((j=i+1; j<=20; j++)); do printf " "; done
        printf "${MAGENTA}] ${YELLOW}%3d%%${NC}" "$percent"
        sleep 0.05
    done
    echo ""
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

    local ctrl_pass hashed_pass control_port
    if [ -f "$ctrl_file" ]; then
        source "$ctrl_file" 2>/dev/null || true
        ctrl_pass="$CTRL_PASS"; hashed_pass="$HASHED_PASS"; control_port="$CTRL_PORT"
    else
        ctrl_pass=$(openssl rand -hex 16)
        hashed_pass=$(tor --hash-password "$ctrl_pass" 2>/dev/null | tail -n1)
        control_port=$((out_port + 20000))
        cat <<EOF > "$ctrl_file"
CTRL_PASS="$ctrl_pass"
HASHED_PASS='$hashed_pass'
CTRL_PORT="$control_port"
EOF
        chmod 600 "$ctrl_file"
    fi

    # Primary country gets the full 20-attempt budget. Each fallback route gets
    # its own independent 5-attempt budget. A fallback IP must still geolocate
    # to the actual fallback route; the original display label is preserved.
    local fallback_mode=0
    local fallback_index=0
    local fallback_candidates_arr=()
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

        if [ "$tor_start_failed" -eq 0 ]; then
            while [ "$total_attempts" -lt "$attempt_limit" ]; do
                total_attempts=$((total_attempts+1))
            local public_ip
            public_ip=$(curl -4 -sS --socks5-hostname 127.0.0.1:"$out_port" https://api.ipify.org --connect-timeout 5 --max-time 12 2>/dev/null | tr -d '\0\r\n' || true)

            if [ -z "$public_ip" ] || ! is_valid_ipv4 "$public_ip"; then
                echo -e "${CYAN}[*] Waiting for Tor connection (Attempt $total_attempts/$attempt_limit)...${NC}"
            elif [ "$fallback_mode" -eq 1 ]; then
                echo -e "${CYAN}[*] Verifying fallback IP ${MAGENTA}$public_ip${CYAN} against GeoIP sources for ${WHITE}$route_code${WHITE}...${NC}"
                local fb_result fb_bad fb_actual fb_reason fb_seen
                fb_result=$(check_ip_quality "$public_ip" "$route_code")
                IFS='|' read -r fb_bad fb_actual fb_reason fb_seen <<< "$fb_result"
                if [ "$fb_bad" = "0" ]; then
                    printf '%s\n' "$public_ip" > "$ip_file"
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
            else
                echo -e "${CYAN}[*] Verifying ${MAGENTA}$public_ip${CYAN} against GeoIP sources for ${WHITE}$route_code${CYAN}...${NC}"
                local result is_bad actual_cc reason seen_ccs
                result=$(validate_node_ip "$public_ip" "$route_code")
                IFS='|' read -r is_bad actual_cc reason seen_ccs <<< "$result"

                if [ "$is_bad" = "0" ]; then
                    printf '%s\n' "$public_ip" > "$ip_file"
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

            if [ "$fallback_mode" -eq 1 ]; then
                # Primary-country loop was interrupted by the 5-failure skip action.
                break
            fi

            if [ "$total_attempts" -lt "$attempt_limit" ]; then
                if [ "$public_ip" = "$last_ip" ]; then
                    newnym_tries=$MAX_NEWNYM_TRIES
                fi
                last_ip="$public_ip"

                if [ "$newnym_tries" -lt "$MAX_NEWNYM_TRIES" ]; then
                    echo -e "${CYAN}    > Requesting a new circuit (NEWNYM)...${NC}"
                    if send_newnym "$control_port" "$ctrl_pass"; then
                        newnym_tries=$((newnym_tries+1))
                        sleep 6
                    else
                        echo -e "${YELLOW}    > ControlPort/NEWNYM unavailable; rebuilding this Tor instance instead.${NC}"
                        stop_tor_node "$code" "$out_port"
                        sleep 1
                        run_tor_node "$conf_file" || true
                        sleep 3
                        newnym_tries=0
                    fi
                else
                    echo -e "${YELLOW}    > Rebuilding Tor instance after repeated validation failures...${NC}"
                    stop_tor_node "$code" "$out_port"
                    sleep 1
                    run_tor_node "$conf_file" || true
                    sleep 3
                    newnym_tries=0
                fi
            fi
            done
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
        else
            # Every fallback route gets exactly 5 attempts, then advances.
            fallback_index=$((fallback_index+1))
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
    local ctrl_file="$inst_data_dir/control.env"
    local bad_file="$inst_data_dir/bad_exits.txt"
    local ip_file="$inst_data_dir/last_ip.txt"
    [ -f "$conf_file" ] && [ -f "$ctrl_file" ] || return 2

    source "$ctrl_file" 2>/dev/null || return 2
    local old_ip=""
    [ -s "$ip_file" ] && old_ip=$(head -n1 "$ip_file" | tr -d '\r\n')
    [ "$silent" = "1" ] || echo -e "${CYAN}🔄 $code - $name: changing IP...${NC}"

    if ! node_process_running "$code" "$out_port"; then
        [ "$silent" = "1" ] || echo -e "${YELLOW}    > Tor process for $code is not running — starting it now...${NC}"
        rm -f "$ip_file"
        write_node_conf "$conf_file" "$out_port" "$CTRL_PORT" "$HASHED_PASS" "$inst_data_dir" "$code"
        if ! run_tor_node "$conf_file"; then
            [ "$silent" = "1" ] || echo -e "${RED}    > Tor failed to start; see $inst_data_dir/notices.log${NC}"
            return 1
        fi
        sleep 5
    fi

    local attempt new_ip result bad actual reason seen
    local expected_route="$(node_route_code "$code" "$out_port")"
    local last_seen_ip="$old_ip"
    local same_ip_count=0

    # Attempt 1 is a real IP check immediately after Tor starts. NEWNYM is only
    # used after an initial result, so startup time is never mistaken for retries.
    for attempt in $(seq 1 "$NODE_ROTATE_RETRIES"); do
        new_ip=$(get_node_ip "$out_port")

        if is_valid_ipv4 "$new_ip"; then
            if [ "$new_ip" = "$old_ip" ]; then
                same_ip_count=$((same_ip_count+1))
                [ "$silent" = "1" ] || echo -e "${YELLOW}  • $code kept old IP $new_ip (attempt $attempt/$NODE_ROTATE_RETRIES)${NC}"
            else
                result=$(check_ip_quality "$new_ip" "$expected_route")
                IFS='|' read -r bad actual reason seen <<< "$result"
                if [ "$bad" = "0" ]; then
                    printf '%s\n' "$new_ip" > "$ip_file"
                    [ "$silent" = "1" ] || echo -e "${GREEN}  ✓ $code → $new_ip (attempt $attempt/$NODE_ROTATE_RETRIES)${NC}"
                    return 0
                fi
                append_bad_ip "$bad_file" "$new_ip"
                local display_new_ip
                display_new_ip=$(ip_display_range "$new_ip")
                [ "$silent" = "1" ] || echo -e "${RED}  ✗ $code rejected IP range $display_new_ip for route $expected_route: $reason (attempt $attempt/$NODE_ROTATE_RETRIES)${NC}"
                same_ip_count=0
            fi
        else
            [ "$silent" = "1" ] || echo -e "${YELLOW}  • $code no valid IP yet (attempt $attempt/$NODE_ROTATE_RETRIES)${NC}"
        fi

        # Change circuit after every failed validation. Rebuild Tor after repeated
        # identical/no-useful circuits instead of waiting until all 20 attempts end.
        if [ "$attempt" -lt "$NODE_ROTATE_RETRIES" ]; then
            if [ "$same_ip_count" -ge 2 ] || ! is_valid_ipv4 "$new_ip" || [ "$new_ip" = "$last_seen_ip" ]; then
                [ "$silent" = "1" ] || echo -e "${CYAN}    > Requesting a fresh Tor circuit (NEWNYM)...${NC}"
                send_newnym "$CTRL_PORT" "$CTRL_PASS" || true
                sleep 2
            else
                send_newnym "$CTRL_PORT" "$CTRL_PASS" || true
                sleep 1
            fi
        fi
        if is_valid_ipv4 "$new_ip"; then last_seen_ip="$new_ip"; fi

        # Every 5 failed attempts perform a full rebuild while retaining the same
        # 20-attempt budget. This gives dead nodes a genuine automatic recovery path.
        if [ "$attempt" -lt "$NODE_ROTATE_RETRIES" ] && (( attempt % 5 == 0 )); then
            [ "$silent" = "1" ] || echo -e "${YELLOW}    > ${code}: rebuilding Tor after $attempt failed validation attempts...${NC}"
            if is_valid_ipv4 "$new_ip"; then append_bad_ip "$bad_file" "$new_ip"; fi
            write_node_conf "$conf_file" "$out_port" "$CTRL_PORT" "$HASHED_PASS" "$inst_data_dir" "$code"
            stop_tor_node "$code" "$out_port"
            sleep 1
            run_tor_node "$conf_file"
            sleep 2
            same_ip_count=0
        fi
    done

    # The 20-attempt loop above already performs NEWNYM and periodic full rebuilds.
    # Do not start a second hidden retry loop here; that used to make the retry count
    # misleading and could make recovery appear to begin only on later attempts.

    rm -f "$ip_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') rotation failed for $code" >> "$inst_data_dir/heal_fail.log"
    [ "$silent" = "1" ] || echo -e "${RED}  ✗ $code: no verified replacement IP found.${NC}"
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
MemoryMax=256M
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
    echo -e "${YELLOW}Available Tor Exit Locations (${#ORDER[@]} total — availability is verified live when you deploy):${NC}\n"

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
        if node_is_installed "$code1" "$port1"; then
            stat1="$CIRCLE_ON"
        fi

        local col2_str=""
        if [[ -n "${NODES[$idx2]:-}" ]]; then
            IFS=':' read -r code2 name2 port2 <<< "${NODES[$idx2]}"
            local stat2="$CIRCLE_OFF"
            if node_is_installed "$code2" "$port2"; then
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

        custom_list="${custom_list// /}"
        custom_list="${custom_list//;/,}"

        declare -a selected=()
        declare -A seen=()

        IFS=',' read -ra ADDR <<< "$custom_list"

        for part in "${ADDR[@]}"; do
            [[ -z "$part" ]] && continue

            if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                first="${BASH_REMATCH[1]}"
                last="${BASH_REMATCH[2]}"

                if (( first > last )); then
                    tmp="$first"
                    first="$last"
                    last="$tmp"
                fi

                for ((n=first; n<=last; n++)); do
                    p_idx=$(printf "%02d" "$n")

                    if [[ -n "${NODES[$p_idx]:-}" && -z "${seen[$p_idx]:-}" ]]; then
                        selected+=("$p_idx")
                        seen[$p_idx]=1
                    fi
                done

            elif [[ "$part" =~ ^[0-9]+$ ]]; then
                p_idx=$(printf "%02d" "$part")

                if [[ -n "${NODES[$p_idx]:-}" && -z "${seen[$p_idx]:-}" ]]; then
                    selected+=("$p_idx")
                    seen[$p_idx]=1
                fi

            else
                echo -e "${YELLOW}[!] Invalid selection: $part${NC}"
            fi
        done

        if [ "${#selected[@]}" -eq 0 ]; then
            echo -e "${RED}[!] No valid locations selected.${NC}"
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
    parse_node_selection() {
        local input="$1" token a b n idx; local -a result=(); declare -A seen=()
        input="${input// /}"; input="${input//;/,}"; IFS=',' read -ra tokens <<< "$input"
        for token in "${tokens[@]}"; do
            [ -z "$token" ] && continue
            if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                a=$((10#${BASH_REMATCH[1]})); b=$((10#${BASH_REMATCH[2]})); ((a>b)) && { n=$a; a=$b; b=$n; }
                for ((n=a;n<=b;n++)); do idx=$(printf '%02d' "$n"); [[ -n "${NODES[$idx]:-}" && -z "${seen[$idx]:-}" ]] && result+=("$idx") && seen[$idx]=1; done
            elif [[ "$token" =~ ^[0-9]+$ ]]; then
                idx=$(printf '%02d' "$((10#$token))"); [[ -n "${NODES[$idx]:-}" && -z "${seen[$idx]:-}" ]] && result+=("$idx") && seen[$idx]=1
            fi
        done
        printf '%s\n' "${result[@]}"
    }
    delete_local_ids() { local idx code name out_port; for idx in "$@"; do IFS=':' read -r code name out_port <<< "${NODES[$idx]}"; pkill -9 -f "node_${code}_${out_port}\.conf" 2>/dev/null || true; rm -f "$BASE_DIR/node_${code}_${out_port}.conf"; rm -rf "$DATA_DIR/${code}_${out_port}"; done; }
    repair_ids() { compute_effective_parallel; local max_jobs=$EFFECTIVE_PARALLEL jobs=0; local -a pids=(); local idx code name out_port; for idx in "$@"; do IFS=':' read -r code name out_port <<< "${NODES[$idx]}"; [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] || continue; rotate_one_node "$code" "$name" "$out_port" 0 & pids+=("$!"); jobs=$((jobs+1)); if ((jobs>=max_jobs)); then wait "${pids[0]}" 2>/dev/null || true; pids=("${pids[@]:1}"); jobs=$((jobs-1)); fi; done; for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done; }
    while true; do
        draw_header; echo -e "📌 ${MAGENTA}[ NODE MAINTENANCE ]${NC}"; echo '────────────────────────────────────────────────────────────'
        local idx code name out_port st
        for idx in "${ORDER[@]}"; do IFS=':' read -r code name out_port <<< "${NODES[$idx]}"; [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] || continue; st='UNKNOWN'; state_get "$code" "$out_port" && st="$STATUS"; printf '[%02s] %-20s %-8s %s\n' "$idx" "$name" "$out_port" "$st"; done
        echo '────────────────────────────────────────────────────────────'
        echo '[1] Repair selected       [2] Delete local selected'
        echo '[3] Delete local + Panel  [4] Refresh'
        echo '[0] Back'
        read -r -p 'Select action: ' action < /dev/tty || return
        case "$action" in
            1|2|3)
                read -r -p 'Node IDs (e.g. 1-21,25): ' selection < /dev/tty || continue
                mapfile -t selected < <(parse_node_selection "$selection"); [ ${#selected[@]} -gt 0 ] || { echo '[!] No valid IDs.'; sleep 1; continue; }
                if [ "$action" = 1 ]; then repair_ids "${selected[@]}"; fi
                if [ "$action" = 2 ]; then read -r -p 'Type DELETE to confirm: ' c < /dev/tty; [ "$c" = DELETE ] && delete_local_ids "${selected[@]}"; fi
                if [ "$action" = 3 ]; then read -r -p 'Type DELETE to confirm local+panel removal: ' c < /dev/tty; if [ "$c" = DELETE ]; then panel_delete_node_ids "${selected[@]}" || true; delete_local_ids "${selected[@]}"; fi; fi
                read -r -p 'Press Enter...' < /dev/tty
                ;;
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
    token_resp=$(curl -4 -sk --max-time 15 -X POST "$base_url/api/admin/token" -d "grant_type=password&username=$p_user&password=$p_pass" 2>/dev/null || true)
    token=$(printf '%s' "$token_resp" | jq -r '.access_token // empty' 2>/dev/null)
    unset p_pass token_resp
    [ -n "$token" ] || { echo -e "${RED}[!] Login failed.${NC}"; return 1; }
    URL="$base_url"; USER="$p_user"; TOKEN="$token"; PANEL_INBOUND_INDEX=${PANEL_INBOUND_INDEX:-1}; PANEL_HOST_INDEX=${PANEL_HOST_INDEX:-0}; PANEL_AUTO_SYNC=1
    panel_conf_write
    echo -e "${GREEN}[+] Login successful. Password was not stored.${NC}"
    panel_menu
}

panel_menu() {
    while true; do
        draw_header
        echo -e "📌 ${MAGENTA}[ NEXATIS CONTROL PANEL ]${NC}"
        echo '[1] Configure/validate templates'
        echo '[2] Add installed nodes to Panel'
        echo '[3] Delete selected nodes from Panel'
        echo '[4] Logout'
        echo '[0] Back'
        read -r -p 'Selected option: ' panel_opt < /dev/tty || return
        case "$panel_opt" in
            1) panel_prepare_templates; read -r -p 'Press Enter...' < /dev/tty ;;
            2) panel_batch_create ;;
            3) read -r -p 'Node IDs: ' s < /dev/tty || continue; mapfile -t ids < <(printf '%s\n' "$s" | sed 's/;/,/g' | awk -F',' '{for(i=1;i<=NF;i++) print $i}' | while read -r x; do if [[ "$x" =~ ^([0-9]+)-([0-9]+)$ ]]; then for ((n=BASH_REMATCH[1];n<=BASH_REMATCH[2];n++)); do printf "%02d\n" "$n"; done; else [[ "$x" =~ ^[0-9]+$ ]] && printf "%02d\n" "$x"; fi; done | sort -u); [ ${#ids[@]} -gt 0 ] && panel_delete_node_ids "${ids[@]}"; read -r -p 'Press Enter...' < /dev/tty ;;
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
    local core_file="$BASE_DIR/remote_core.json" hosts_file="$BASE_DIR/panel_hosts.json"
    panel_core_fetch "$core_file" || return 1
    panel_load_hosts "$hosts_file"
    panel_validate_templates "$core_file" "$hosts_file" || return 2
    local in_idx=$((PANEL_INBOUND_INDEX-1)) clone_inbound_json clone_tag clone_sec rand_port in_tag out_tag safe_name new_remark cloned_sni='' clone_host_json='{}'
    clone_inbound_json=$(jq ".inbounds[$in_idx]" "$core_file") || return 1
    [ "$clone_inbound_json" != "null" ] || return 1
    safe_name=$(printf '%s' "$name" | tr -d ' ' | tr -cd 'a-zA-Z0-9-'); new_remark="${EMOJIS[$code]} $name"; in_tag=""
    local attempts=0
    while (( attempts < 1000 )); do
        attempts=$((attempts+1)); rand_port=$(( RANDOM % 6000 + 3000)); in_tag="${code}-${safe_name}-IN-${rand_port}"; out_tag="${code}-${safe_name}-OUT-${out_port}"
        if ! jq -e --arg t "$in_tag" --arg o "$out_tag" --argjson p "$rand_port" '.inbounds[]? | select((.tag // "")==$t or .port==$p)' "$core_file" >/dev/null 2>&1 && ! jq -e --arg o "$out_tag" '.outbounds[]? | select((.tag // "")==$o)' "$core_file" >/dev/null 2>&1; then break; fi
    done
    (( attempts < 1000 )) || return 1
    jq --arg p "$rand_port" --arg t "$in_tag" --argjson obj "$clone_inbound_json" 'if .inbounds==null then .inbounds=[] else . end | .inbounds += [($obj|.port=($p|tonumber)|.tag=$t)]' "$core_file" > "$BASE_DIR/panel_sync.tmp" && mv -f "$BASE_DIR/panel_sync.tmp" "$core_file"
    jq --arg t "$out_tag" --arg p "$out_port" 'if .outbounds==null then .outbounds=[] else . end | .outbounds += [{"tag":$t,"protocol":"socks","settings":{"servers":[{"address":"127.0.0.1","port":($p|tonumber)}]}}]' "$core_file" > "$BASE_DIR/panel_sync.tmp" && mv -f "$BASE_DIR/panel_sync.tmp" "$core_file"
    jq --arg i "$in_tag" --arg o "$out_tag" 'if .routing==null then .routing={"rules":[]} elif .routing.rules==null then .routing.rules=[] else . end | .routing.rules += [{"type":"field","inboundTag":[$i],"outboundTag":$o}]' "$core_file" > "$BASE_DIR/panel_sync.tmp" && mv -f "$BASE_DIR/panel_sync.tmp" "$core_file"
    if (( PANEL_HOST_INDEX > 0 )); then cloned_sni=$(jq -r ".[$((PANEL_HOST_INDEX-1))].address | if type==\"array\" and length>0 then .[0] elif type==\"string\" then . else \"\" end" "$hosts_file"); clone_host_json=$(jq ".[$((PANEL_HOST_INDEX-1))]" "$hosts_file"); fi
    local original; original=$(curl -4 -sk --max-time 12 -X GET "$CORE_API_URL" -H "Authorization: Bearer $TOKEN" -H 'accept: application/json' 2>/dev/null || true)
    local obj; obj=$(printf '%s' "$original" | jq -r 'if type=="object" and has("data") then .data else . end')
    jq --slurpfile conf "$core_file" 'if .config!=null then .config=$conf[0] elif .xray_config!=null then .xray_config=$conf[0] elif .content!=null then .content=$conf[0] else .config=$conf[0] end' <<< "$obj" > "$BASE_DIR/panel_sync_payload.json"
    local h; h=$(curl -4 -sk -o /dev/null -w '%{http_code}' --max-time 15 -X PUT "$CORE_API_URL?restart_nodes=true" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d @"$BASE_DIR/panel_sync_payload.json" 2>/dev/null || echo 000)
    [[ "$h" == 2* ]] || { echo -e "${RED}[!] Panel core sync failed: HTTP $h${NC}"; return 1; }
    local host_json
    if [ "$clone_host_json" != '{}' ] && [ "$clone_host_json" != 'null' ] && [ -n "$cloned_sni" ]; then host_json=$(jq --arg tag "$in_tag" --arg p "$rand_port" --arg rem "$new_remark" --argjson o "$clone_host_json" '$o|.inbound_tag=$tag|.port=($p|tonumber)|.remark=$rem|.enable=1|del(.id,.created_at,.updated_at)'); else host_json=$(jq -n --arg tag "$in_tag" --arg p "$rand_port" --arg rem "$new_remark" --arg addr "$cloned_sni" '{inbound_tag:$tag,remark:$rem,address:(if $addr=="" then [] else [$addr] end),port:($p|tonumber),enable:1}'); fi
    h=$(curl -4 -sk -o /dev/null -w '%{http_code}' --max-time 12 -X POST "$URL/api/hosts" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d "$host_json" 2>/dev/null || echo 000)
    if [[ ! "$h" == 2* && "$h" != 409 ]]; then
        local all; panel_load_hosts "$hosts_file" || true; jq --argjson n "$host_json" '. += [$n]' "$hosts_file" > "$BASE_DIR/panel_hosts_push.json"; curl -4 -sk -o /dev/null -w '%{http_code}' --max-time 12 -X PUT "$URL/api/hosts" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d @"$BASE_DIR/panel_hosts_push.json" >/dev/null 2>&1 || true
    fi
    rm -f "$BASE_DIR/panel_sync_payload.json" "$BASE_DIR/panel_sync.tmp"
    echo -e "${GREEN}[+] ${EMOJIS[$code]} $name synchronized to Panel.${NC}"
    return 0
}


panel_batch_create() {
    source "$PANEL_CONF" 2>/dev/null || true

    local installed=()
    for idx in "${ORDER[@]}"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        if node_is_installed "$code" "$out_port"; then
            installed+=("$idx")
        fi
    done

    if [ ${#installed[@]} -eq 0 ]; then
        echo -e "\n${RED}[!] No installed Tor nodes found. Please install nodes first.${NC}"; sleep 2; return
    fi

    echo -e "\n📌 ${MAGENTA}[ INSTALLED NODES TO ADD ]${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"
    for idx in "${installed[@]}"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        local emoji="${EMOJIS[$code]}"
        printf "  ${CYAN}[%s]${NC} %s %-18s \tTorPort:${MAGENTA}%s${NC}\n" "$idx" "$emoji" "$name" "$out_port"
    done
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"

    local selected_nodes=()
    read -p "$(echo -e ${CYAN}"Select Node IDs to add to Panel (e.g. 01,05) or type 'all' [Default: all]: "${NC})" user_selection

    if [[ -z "$user_selection" || "${user_selection,,}" == "all" ]]; then
        selected_nodes=("${installed[@]}")
    else
        IFS=',' read -ra SEL_ADDR <<< "$user_selection"
        for s in "${SEL_ADDR[@]}"; do
            local clean_s=$(echo "$s" | sed 's/^0*//' | tr -d ' ')
            if [ -n "$clean_s" ]; then
                local p_idx=$(printf "%02d" "$clean_s" 2>/dev/null)
                local is_installed=0
                for inst_node in "${installed[@]}"; do
                    if [[ "$inst_node" == "$p_idx" ]]; then
                        is_installed=1
                        break
                    fi
                done

                if [[ $is_installed -eq 1 ]]; then
                    local is_duplicate=0
                    for sel_node in "${selected_nodes[@]}"; do
                        if [[ "$sel_node" == "$p_idx" ]]; then
                            is_duplicate=1
                            break
                        fi
                    done
                    if [[ $is_duplicate -eq 0 ]]; then
                        selected_nodes+=("$p_idx")
                    fi
                else
                    echo -e "${YELLOW}[!] Node ID $p_idx is not installed or invalid. Skipping...${NC}"
                fi
            fi
        done
    fi

    if [ ${#selected_nodes[@]} -eq 0 ]; then
        echo -e "\n${RED}[!] No valid nodes selected. Returning to menu...${NC}"; sleep 2; return
    fi

    echo -e "\n${YELLOW}[~] 🤖 Simulating browser... Scanning Nexatis for Core configurations...${NC}"

    local CORE_FILE="$BASE_DIR/remote_core.json"
    local found_config=0
    local CORE_API_URL=""

    local core_endpoints=("/api/admin/cores" "/api/cores" "/api/core" "/api/node/cores" "/api/admin/core")

    echo -e "${CYAN}    > Searching for Cores...${NC}"
    for ep in "${core_endpoints[@]}"; do
        local test_resp=$(curl -s -X GET "$URL$ep/1" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
        local extracted=$(extract_json_from_response "$test_resp")

        if [ -n "$extracted" ]; then
            echo "$extracted" > "$CORE_FILE"
            CORE_API_URL="$URL$ep/1"
            found_config=1
            break
        fi

        local list_resp=$(curl -s -X GET "$URL$ep" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
        local core_ids=$(echo "$list_resp" | jq -r '.[].id // .data[].id // empty' 2>/dev/null | head -n 1)

        if [ -n "$core_ids" ]; then
            local fetch_resp=$(curl -s -X GET "$URL$ep/$core_ids" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
            local extracted2=$(extract_json_from_response "$fetch_resp")
            if [ -n "$extracted2" ]; then
                echo "$extracted2" > "$CORE_FILE"
                CORE_API_URL="$URL$ep/$core_ids"
                found_config=1
                break
            fi
        fi
    done

    if [ $found_config -eq 0 ]; then
        local nodes_resp=$(curl -s -X GET "$URL/api/nodes" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
        local node_ids=$(echo "$nodes_resp" | jq -r '.[].id // .data[].id // empty' 2>/dev/null)
        for nid in $node_ids; do
            local n_resp=$(curl -s -X GET "$URL/api/node/$nid" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
            local extracted3=$(extract_json_from_response "$n_resp")
            if [ -n "$extracted3" ]; then
                echo "$extracted3" > "$CORE_FILE"
                CORE_API_URL="$URL/api/node/$nid"
                found_config=1
                break
            fi
        done
    fi

    if [ $found_config -eq 0 ]; then
        echo -e "${RED}[!] Could not locate configurations automatically.${NC}"
        read -p "$(echo -e ${WHITE}"Press [Enter] to return..."${NC})"
        return
    fi

    echo -e "\n📌 ${MAGENTA}[ SELECT INBOUND TO CLONE FROM ]${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}#    Port    Protocol        Network    Security    Tag${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────${NC}"

    local inb_count=$(jq '.inbounds | length' "$CORE_FILE" 2>/dev/null || echo "0")
    for ((i=0; i<$inb_count; i++)); do
        local tag=$(jq -r ".inbounds[$i].tag // empty" "$CORE_FILE")
        local port=$(jq -r ".inbounds[$i].port // empty" "$CORE_FILE")
        local proto=$(jq -r ".inbounds[$i].protocol // empty" "$CORE_FILE")
        local net=$(jq -r '.inbounds['$i'] | if .streamSettings.network then .streamSettings.network elif .settings.network then .settings.network else "tcp" end' "$CORE_FILE")
        local sec=$(jq -r '.inbounds['$i'] | if .streamSettings.security then .streamSettings.security else "none" end' "$CORE_FILE")

        printf "  ${CYAN}[%d]${NC}  %-7s  %-12s    %-9s  %-9s  %s\n" "$((i+1))" "$port" "$proto" "$net" "$sec" "$tag"
    done
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${RED}[0] Go Back${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────${NC}"

    read -p "$(echo -e ${CYAN}"Select inbound to clone (e.g. 1): "${NC})" inb_sel
    if [ "$inb_sel" == "0" ] || [ -z "$inb_sel" ]; then return; fi

    local real_index=$((inb_sel - 1))
    local clone_tag=$(jq -r ".inbounds[$real_index].tag" "$CORE_FILE")
    local clone_port=$(jq -r ".inbounds[$real_index].port" "$CORE_FILE")
    local clone_inbound_json=$(jq ".inbounds[$real_index]" "$CORE_FILE")
    local clone_sec=$(jq -r ".inbounds[$real_index] | if .streamSettings.security then .streamSettings.security else \"none\" end" "$CORE_FILE")

    echo -e "\n📌 ${MAGENTA}[ SELECT HOST TO CLONE FROM ]${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${WHITE}#   Inbound Tag        Remark                         Address                Port${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"

    local cloned_sni=""
    local clone_host_json="{}"
    local HOSTS_FILE="$BASE_DIR/panel_hosts.json"

    local hosts_resp=$(curl -s -X GET "$URL/api/hosts" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
    local is_array=$(echo "$hosts_resp" | jq -r 'type == "array"' 2>/dev/null)

    if [ "$is_array" == "true" ]; then
        echo "$hosts_resp" > "$HOSTS_FILE"
    else
        local data_array=$(echo "$hosts_resp" | jq -c '.data // empty' 2>/dev/null)
        if [ -n "$data_array" ]; then
            echo "$data_array" > "$HOSTS_FILE"
        else
            echo "[]" > "$HOSTS_FILE"
        fi
    fi

    local host_count=$(jq 'length' "$HOSTS_FILE" 2>/dev/null || echo "0")

    if [ "$host_count" -gt 0 ]; then
        for ((i=0; i<$host_count; i++)); do
            local h_tag=$(jq -r ".[$i].inbound_tag // \"Unknown\"" "$HOSTS_FILE")
            local h_remark=$(jq -r ".[$i].remark // \"\"" "$HOSTS_FILE")

            local h_addr_raw=$(jq -r ".[$i].address | if type==\"array\" and length>0 then .[0] elif type==\"string\" then . else empty end" "$HOSTS_FILE")
            if [ -z "$h_addr_raw" ] || [ "$h_addr_raw" == "null" ]; then h_addr_raw="None"; fi
            local h_addr_disp="['$h_addr_raw']"

            local h_port=$(jq -r ".[$i].port // \"None\"" "$HOSTS_FILE")
            if [ "$h_port" == "null" ]; then h_port="None"; fi

            printf "  ${CYAN}[%-2d]${NC} %-18s %-30s %-22s %s\n" "$((i+1))" "$h_tag" "$h_remark" "$h_addr_disp" "$h_port"
        done

        echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "  ${RED}[0] Go Back${NC}"
        echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"

        read -p "$(echo -e ${CYAN}"Enter host # to clone SNI/Address from (or 0 to skip): "${NC})" host_sel
        if [ "$host_sel" == "0" ]; then return; fi

        if [[ "$host_sel" =~ ^[0-9]+$ ]] && [ "$host_sel" -gt 0 ]; then
            local real_host_idx=$((host_sel - 1))
            clone_host_json=$(jq ".[$real_host_idx]" "$HOSTS_FILE")
            cloned_sni=$(jq -r ".[$real_host_idx].address | if type==\"array\" and length>0 then .[0] elif type==\"string\" then . else \"\" end" "$HOSTS_FILE")
            if [ "$cloned_sni" == "null" ]; then cloned_sni=""; fi
        fi
    else
        echo -e "  ${YELLOW}No Hosts API found, falling back to Inbounds Data...${NC}"
        for ((i=0; i<$inb_count; i++)); do
            local tag=$(jq -r ".inbounds[$i].tag // empty" "$CORE_FILE")
            local proto=$(jq -r ".inbounds[$i].protocol // empty" "$CORE_FILE")
            local address=$(jq -r '.inbounds['$i'].streamSettings | if .realitySettings.serverNames then .realitySettings.serverNames[0] elif .tlsSettings.serverName then .tlsSettings.serverName else "None" end' "$CORE_FILE")
            local port=$(jq -r ".inbounds[$i].port // empty" "$CORE_FILE")
            if [ "$port" == "null" ] || [ -z "$port" ]; then port="None"; fi

            local h_addr_disp="['$address']"
            printf "  ${CYAN}[%-2d]${NC} %-18s %-30s %-22s %s\n" "$((i+1))" "$proto" "$tag" "$h_addr_disp" "$port"
        done

        echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────${NC}"
        read -p "$(echo -e ${CYAN}"Enter host # to clone SNI/Address from (or 0 to skip): "${NC})" host_sel
        if [ "$host_sel" == "0" ]; then return; fi

        if [[ "$host_sel" =~ ^[0-9]+$ ]] && [ "$host_sel" -gt 0 ]; then
            local real_host_idx=$((host_sel - 1))
            cloned_sni=$(jq -r ".inbounds[$real_host_idx].streamSettings | if .realitySettings.serverNames then .realitySettings.serverNames[0] elif .tlsSettings.serverName then .tlsSettings.serverName else \"\" end" "$CORE_FILE")
            if [ "$cloned_sni" == "null" ]; then cloned_sni=""; fi
        fi
    fi

    echo -e "\n⚡ ${YELLOW}Generating Inbounds, Outbounds & Routing in Memory...${NC}"

    local FINAL_FILE="$BASE_DIR/final_core_to_upload.json"
    local NEW_HOSTS_FILE="$BASE_DIR/final_hosts_to_upload.json"

    cp "$CORE_FILE" "$FINAL_FILE"
    echo "[]" > "$NEW_HOSTS_FILE"

    for idx in "${selected_nodes[@]}"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        local emoji="${EMOJIS[$code]}"

        local safe_name=$(echo "$name" | tr -d ' ' | tr -cd 'a-zA-Z0-9-')
        local new_remark="$emoji $name"

        local is_duplicate_host=$(jq -e ".[]? | select(.remark == \"$new_remark\")" "$HOSTS_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
        if [[ "$is_duplicate_host" == "yes" ]]; then
            echo -e "  ⚠️  ${YELLOW}$emoji $name is already configured in panel. Skipping to prevent duplicate...${NC}"
            continue
        fi

        local rand_port
        local in_tag
        local out_tag

        while true; do
            rand_port=$(( RANDOM % 6000 + 3000 ))
            in_tag="${code}-${safe_name}-IN-${rand_port}"
            out_tag="${code}-${safe_name}-OUT-${out_port}"

            local port_exists=$(jq -e ".inbounds[]? | select(.port == $rand_port)" "$FINAL_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
            local in_tag_exists=$(jq -e ".inbounds[]? | select(.tag == \"$in_tag\")" "$FINAL_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")
            local out_tag_exists=$(jq -e ".outbounds[]? | select(.tag == \"$out_tag\")" "$FINAL_FILE" >/dev/null 2>&1 && echo "yes" || echo "no")

            if [[ "$port_exists" == "no" && "$in_tag_exists" == "no" && "$out_tag_exists" == "no" ]]; then
                break
            fi
        done

        jq --arg p "$rand_port" --arg t "$in_tag" --argjson obj "$clone_inbound_json" \
           'if .inbounds == null then .inbounds = [] else . end | .inbounds += [($obj | .port=($p|tonumber) | .tag=$t)]' \
           "$FINAL_FILE" > "$BASE_DIR/tmp.json" && mv -f "$BASE_DIR/tmp.json" "$FINAL_FILE"

        jq --arg t "$out_tag" --arg p "$out_port" \
           'if has("outbounds") and .outbounds != null then . else .outbounds = [] end | .outbounds += [{"tag": $t, "protocol": "socks", "settings": {"servers": [{"address": "127.0.0.1", "port": ($p|tonumber)}]}}]' \
           "$FINAL_FILE" > "$BASE_DIR/tmp.json" && mv -f "$BASE_DIR/tmp.json" "$FINAL_FILE"

        jq --arg intag "$in_tag" --arg outtag "$out_tag" \
           'if has("routing") and .routing != null then . else .routing = {"rules": []} end | if .routing.rules == null then .routing.rules = [] else . end | .routing.rules += [{"type": "field", "inboundTag": [$intag], "outboundTag": $outtag}]' \
           "$FINAL_FILE" > "$BASE_DIR/tmp.json" && mv -f "$BASE_DIR/tmp.json" "$FINAL_FILE"

        if [ "$clone_host_json" != "{}" ] && [ "$clone_host_json" != "null" ]; then
            jq --arg tag "$in_tag" --arg p "$rand_port" --arg rem "$new_remark" --argjson obj "$clone_host_json" \
               '. += [($obj | .inbound_tag=$tag | .port=($p|tonumber) | .remark=$rem | .enable=1 | del(.id, .created_at, .updated_at))]' \
               "$NEW_HOSTS_FILE" > "$BASE_DIR/tmp_hosts.json" && mv -f "$BASE_DIR/tmp_hosts.json" "$NEW_HOSTS_FILE" || true
        else
            jq --arg tag "$in_tag" --arg p "$rand_port" --arg rem "$new_remark" --arg addr "$cloned_sni" \
               '. += [{"inbound_tag": $tag, "remark": $rem, "address": [$addr], "port": ($p|tonumber), "enable": 1}]' \
               "$NEW_HOSTS_FILE" > "$BASE_DIR/tmp_hosts.json" && mv -f "$BASE_DIR/tmp_hosts.json" "$NEW_HOSTS_FILE" || true
        fi

        echo -e "  ⚙️  $emoji $name | In:$rand_port ➔ Out:$out_port Prepared."
    done

    echo -e "\n🚀 ${MAGENTA}[ UPLOADING DIRECTLY TO PANEL VIA API ]${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"

    if [ -n "$CORE_API_URL" ]; then
        local original_core_resp=$(curl -s -X GET "$CORE_API_URL" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
        local core_obj=$(echo "$original_core_resp" | jq -r 'if type == "object" and has("data") then .data else . end')
        if [ -z "$core_obj" ] || [ "$core_obj" == "null" ]; then core_obj="{}"; fi

        jq --slurpfile newconf "$FINAL_FILE" 'if type == "object" then if .config != null then .config = $newconf[0] elif .xray_config != null then .xray_config = $newconf[0] elif .content != null then .content = $newconf[0] else .config = $newconf[0] end else . end' <<< "$core_obj" > "$BASE_DIR/payload_f_j.json"

        draw_progress "Uploading Core Configuration"

        local p_url="$CORE_API_URL"
        local payload="$BASE_DIR/payload_f_j.json"

        local put_resp=$(curl -s -w "\n%{http_code}" -X PUT "$p_url?restart_nodes=true" \
            --max-time 15 \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d @"$payload")

        local last_core_error=$(echo "$put_resp" | tail -n1)

        echo -e "${YELLOW}[~] Forcing Core Configuration update...${NC}"

        for (( i=15; i>=0; i-- )); do
            printf "\r${CYAN}[*] Xray restarting... Please wait: ${MAGENTA}[${YELLOW}%02d${MAGENTA}]${CYAN} seconds remaining${NC}" $i
            sleep 1
        done
        echo -e "\n${GREEN}[+] Xray restarted successfully! OK.${NC}"
    fi

    echo -e "${YELLOW}[~] Pushing Hosts to Panel...${NC}"
    draw_progress "Injecting Hosts"

    local host_len=$(jq 'length' "$NEW_HOSTS_FILE" 2>/dev/null || echo "0")
    for ((h=0; h<$host_len; h++)); do
        local h_data=$(jq -c ".[$h]" "$NEW_HOSTS_FILE")
        local h_success=0
        local h_code=""

        local host_endpoints=("/api/host" "/api/hosts" "/api/admin/host" "/api/admin/hosts")
        for hep in "${host_endpoints[@]}"; do
            local h_resp=$(curl -s -w "\n%{http_code}" -X POST "$URL$hep" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Content-Type: application/json" \
                -d "$h_data")
            h_code=$(echo "$h_resp" | tail -n1)

            if [[ "$h_code" == 2* || "$h_code" == "409" ]]; then
                h_success=1
                break
            fi
        done

        if [ $h_success -eq 0 ] && [[ "$h_code" == "405" || "$h_code" == "404" ]]; then
            local current_hosts=$(curl -s -X GET "$URL/api/hosts" -H "Authorization: Bearer $TOKEN" -H "accept: application/json" | tr -d '\0')
            local is_arr=$(echo "$current_hosts" | jq 'type == "array"' 2>/dev/null)

            if [ "$is_arr" == "true" ]; then
                echo "$current_hosts" > "$BASE_DIR/all_hosts_tmp.json"
            else
                echo "$current_hosts" | jq -c '.data // []' > "$BASE_DIR/all_hosts_tmp.json" 2>/dev/null
            fi

            jq --argjson newh "$h_data" '. += [$newh]' "$BASE_DIR/all_hosts_tmp.json" > "$BASE_DIR/tmp_h.json" && mv -f "$BASE_DIR/tmp_h.json" "$BASE_DIR/all_hosts_tmp.json"

            local bulk_resp=$(curl -s -w "\n%{http_code}" -X PUT "$URL/api/hosts" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Content-Type: application/json" \
                -d @"$BASE_DIR/all_hosts_tmp.json")
            local bulk_code=$(echo "$bulk_resp" | tail -n1)

            if [[ "$bulk_code" == 2* ]]; then
                h_success=1
                h_code=$bulk_code
            fi
        fi

        if [ $h_success -eq 1 ]; then
            echo -e " ✅ ${GREEN}Host $((h+1)) Injected Successfully!${NC}"
        else
            echo -e " ❌ ${RED}Failed to inject Host $((h+1)). Last API Error: $h_code${NC}"
        fi
    done

    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
    echo -e "🎉 ${GREEN}Process finished! Check your panel dashboard.${NC}"
    echo -e "💡 ${CYAN}Note: Restarting the Xray Core from your panel is highly recommended to apply changes.${NC}"
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}\n"

    read -r -p "$(echo -e ${WHITE}"Press [Enter] to continue..."${NC})" < /dev/tty
}

if [ "${1:-}" = "--install" ]; then
    install_engine
    exit 0
fi

# ================= MENU LOOP =================
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
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${YELLOW}[9]${NC} ${WHITE}»${NC} Panel Nexatis Integration"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}"
    echo -e "  ${RED}[0]${NC} ${WHITE}»${NC} Exit Program"
    echo -e "${BLUE} ────────────────────────────────────────────────────────${NC}\n"

    if ! read -r -p "$(echo -e ${MAGENTA}"Enter choice [0-9]: "${NC})" main_choice < /dev/tty; then
        echo -e "\n${RED}[!] No terminal input available (are you piping this, e.g. curl | bash?). Exiting.${NC}"
        exit 1
    fi

    case $main_choice in
        1) install_engine ;;
        2) update_system ;;
        8) change_ip_menu ;;
        3) uninstall_engine ;;
        4) add_single_node ;;
        5) bulk_add_nodes ;;
        6) view_active_nodes ;;
        7) edit_delete_nodes ;;
        9) check_root; panel_login ;;
        0) clear; exit 0 ;;
        *) ;;
    esac
done
