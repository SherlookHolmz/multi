#!/usr/bin/env bash
# Sherlook Automate Engine v6.1 (PasarGuard API Edition)
# Stability-focused rebuild with atomic updates, full ISO locations, fast health checks, and continuous auto-heal

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
SHERLOOK_VERSION="6.1.0"
LOCATION_CACHE="$DATA_DIR/onionoo_exit_countries.cache"
LOCATION_CATALOG="$DATA_DIR/location_catalog.tsv"
LOCATION_CACHE_TTL=21600
AUTO_HEAL_INTERVAL=5
AUTO_HEAL_PARALLEL=16
NODE_ROTATE_RETRIES=12
HEALTH_CONNECT_TIMEOUT=2
HEALTH_MAX_TIME=5

# Panel Config Cache
PANEL_CONF="$BASE_DIR/pasargad_panel.conf"

# How many "country mismatch / high-abuse" retries before we give up on a fresh deploy
MAX_QUALITY_ATTEMPTS=8
# How many quick NEWNYM (new circuit, no restart) tries before we escalate to
# excluding the bad exit IP and doing a full restart
MAX_NEWNYM_TRIES=2
# Maximum total public-IP validation cycles for one node deployment
MAX_TOTAL_VALIDATION_ATTEMPTS=20

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

# Tor Exit preflight.
# A location is only considered installable when Onionoo currently reports at
# least one running Tor relay with the Exit flag in that country.
ONIONOO_URL="https://onionoo.torproject.org/details"
ONIONOO_TIMEOUT=12
ONIONOO_MIN_EXITS=1

# Countries with historically small Tor exit pools. These are warnings only;
# the actual availability check is always performed dynamically.
declare -A LOW_SUPPLY_WARN=(
    [IS]=1 [SC]=1 [AZ]=1 [MD]=1 [CY]=1 [TN]=1 [GE]=1 [KZ]=1
    [QA]=1 [SA]=1 [AE]=1 [CR]=1 [AR]=1 [PK]=1 [BO]=1 [VE]=1
)

ORDER=({01..83})

# v6.1: Keep all historical nodes/ports, then add every ISO-3166 alpha-2
# country/territory available on the host. The menu does not depend on Onionoo.
expand_iso_locations() {
    local file="/usr/share/zoneinfo/iso3166.tab"
    [ -r "$file" ] || return 0

    local code name key existing next=83 port=9163
    while read -r code name; do
        [[ "$code" =~ ^[A-Z]{2}$ ]] || continue

        local present=0
        for key in "${!NODES[@]}"; do
            IFS=':' read -r existing _ _ <<< "${NODES[$key]}"
            if [ "$existing" = "$code" ]; then
                present=1
                break
            fi
        done
        (( present )) && continue

        next=$((next + 1))
        NODES[$(printf '%02d' "$next")]="$code:${name:-$code}:$port"
        ORDER+=("$(printf '%02d' "$next")")
        port=$((port + 1))
    done < "$file"
}
expand_iso_locations

# ================= CORE FUNCTIONS =================

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

run_tor_node() {
    local conf="$1"
    if id debian-tor >/dev/null 2>&1 && command -v runuser >/dev/null 2>&1; then
        runuser -u debian-tor -- tor -f "$conf" >/dev/null 2>&1 &
    elif id debian-tor >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
        sudo -u debian-tor tor -f "$conf" >/dev/null 2>&1 &
    else
        tor -f "$conf" >/dev/null 2>&1 &
    fi
}

node_process_running() {
    local code="$1" port="$2"
    pgrep -f "node_${code}_${port}\.conf" >/dev/null 2>&1
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

    # First load previously discovered locations/ports so installed nodes never
    # change port merely because Onionoo temporarily reports a different set.
    local catalog_code catalog_name catalog_port catalog_idx line
    local max_port=9080 next_idx=0 key n
    for key in "${!NODES[@]}"; do
        n=$((10#$key)); (( n > next_idx )) && next_idx=$n
        IFS=':' read -r _ _ catalog_port <<< "${NODES[$key]}"
        [[ "$catalog_port" =~ ^[0-9]+$ ]] && (( catalog_port > max_port )) && max_port=$catalog_port
    done

    if [ -s "$LOCATION_CATALOG" ]; then
        while IFS=$'\\t' read -r catalog_code catalog_name catalog_port; do
            [[ "$catalog_code" =~ ^[A-Z]{2}$ ]] || continue
            [[ "$catalog_port" =~ ^[0-9]+$ ]] || continue
            local present=0
            for key in "${!NODES[@]}"; do
                IFS=':' read -r existing_code _ _ <<< "${NODES[$key]}"
                if [ "$existing_code" = "$catalog_code" ]; then present=1; break; fi
            done
            (( present )) && continue
            next_idx=$((next_idx+1))
            NODES[$(printf '%02d' "$next_idx")]="$catalog_code:${catalog_name:-$catalog_code}:$catalog_port"
            (( catalog_port > max_port )) && max_port=$catalog_port
        done < "$LOCATION_CATALOG"
    fi

    local now cache_mtime stale=1
    if [ -s "$LOCATION_CACHE" ]; then
        cache_mtime=$(stat -c %Y "$LOCATION_CACHE" 2>/dev/null || echo 0)
        now=$(date +%s)
        if (( now - cache_mtime < LOCATION_CACHE_TTL )); then stale=0; fi
    fi

    if (( stale )); then
        local tmp
        tmp=$(mktemp /tmp/sherlook_country.XXXXXX) || return 0
        if curl -4 -fsS --connect-timeout 5 --max-time "$ONIONOO_TIMEOUT" \
            "${ONIONOO_URL}?flag=Exit&running=true&fields=country" -o "$tmp" 2>/dev/null; then
            jq -r '.relays // [] | .[].country // empty' "$tmp" 2>/dev/null \
                | tr '[:lower:]' '[:upper:]' \
                | grep -E '^[A-Z]{2}$' | sort -u > "$LOCATION_CACHE.tmp" || true
            if [ -s "$LOCATION_CACHE.tmp" ]; then mv -f "$LOCATION_CACHE.tmp" "$LOCATION_CACHE"; fi
        fi
        rm -f "$tmp" "$LOCATION_CACHE.tmp"
    fi

    # Add every country currently reporting at least one running Tor exit.
    if [ -s "$LOCATION_CACHE" ]; then
        while IFS= read -r catalog_code; do
            [ -z "$catalog_code" ] && continue
            local present=0
            for key in "${!NODES[@]}"; do
                IFS=':' read -r existing_code _ _ <<< "${NODES[$key]}"
                if [ "$existing_code" = "$catalog_code" ]; then present=1; break; fi
            done
            (( present )) && continue

            next_idx=$((next_idx+1))
            max_port=$((max_port+1))
            catalog_name=$(country_name "$catalog_code")
            NODES[$(printf '%02d' "$next_idx")]="$catalog_code:$catalog_name:$max_port"
            EMOJIS[$catalog_code]="$(emoji_for_country "$catalog_code")"
            printf '%s\\t%s\\t%s\\n' "$catalog_code" "$catalog_name" "$max_port" >> "$LOCATION_CATALOG"
        done < "$LOCATION_CACHE"
    fi

    # Also persist statically defined locations once, while leaving their
    # original ports untouched.
    : > "$LOCATION_CATALOG.tmp"
    for key in "${!NODES[@]}"; do
        IFS=':' read -r catalog_code catalog_name catalog_port <<< "${NODES[$key]}"
        printf '%s\\t%s\\t%s\\n' "$catalog_code" "$catalog_name" "$catalog_port" >> "$LOCATION_CATALOG.tmp"
    done
    sort -t $'\\t' -k1,1 -u "$LOCATION_CATALOG.tmp" > "$LOCATION_CATALOG" 2>/dev/null || mv -f "$LOCATION_CATALOG.tmp" "$LOCATION_CATALOG"
    rm -f "$LOCATION_CATALOG.tmp"

    mapfile -t ORDER < <(printf '%s\\n' "${!NODES[@]}" | sort -n)
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

    pkill -f "node_${code}_${out_port}.conf" 2>/dev/null || true
    sleep 1
    rm -f "$conf_file"
    rm -rf "$inst_data_dir"
}

node_is_installed() {
    local code="$1"
    local out_port="$2"
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
    local ip_file="$DATA_DIR/${code}_${out_port}/last_ip.txt"

    # A node only counts as "installed" if its Tor process is actually
    # alive right now. Previously this only checked that last_ip.txt had
    # ever held a valid-looking IP, so a node whose process died (and
    # whose auto-heal cycle hadn't caught up yet) stayed "ON" forever in
    # list_locations/add_single_node — blocking reinstall — while
    # edit_delete_nodes (which filters on pgrep) could no longer see it
    # to delete it. Requiring a live process here keeps both menus in sync.
    [ -f "$conf_file" ] &&
    pgrep -f "node_${code}_${out_port}.conf" > /dev/null &&
    [ -s "$ip_file" ] &&
    grep -Eq '^[0-9]+(\.[0-9]+){3}$' "$ip_file"
}

# True if a node has an install record on disk at all (conf file present),
# regardless of whether the Tor process is currently alive. Used by the
# delete menu so dead-but-still-configured nodes can be cleaned up, and by
# node_has_record() callers that need to distinguish "never installed"
# from "installed but currently down".
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

    cc1=$(echo "$api1" | jq -r '.location.country_code // .country_code // empty' 2>/dev/null | tr '[:lower:]' '[:upper:]')
    cc2=$(echo "$api2" | jq -r '.country_code // .countryCode // empty' 2>/dev/null | tr '[:lower:]' '[:upper:]')
    cc3=$(echo "$api3" | jq -r '.country_code // empty' 2>/dev/null | tr '[:lower:]' '[:upper:]')

    local verified=0 mismatch=0 high_risk=0
    for cc in "$cc1" "$cc2" "$cc3"; do
        if [ -n "$cc" ]; then
            verified=1
            [ "$cc" != "$expected_cc" ] && mismatch=1
        fi
    done
    if echo "$api1" | grep -iq '"abuser_score".*"High"'; then high_risk=1; fi

    local bad=0 reason=""
    if [ "$verified" -eq 0 ]; then bad=1; reason="GEOIP_UNAVAILABLE"
    elif [ "$mismatch" -eq 1 ]; then bad=1; reason="COUNTRY_MISMATCH"
    elif [ "$high_risk" -eq 1 ]; then bad=1; reason="HIGH_RISK"
    else reason="VERIFIED"; fi

    local actual_cc=""
    if [ -n "$cc1" ]; then actual_cc="$cc1"
    elif [ -n "$cc2" ]; then actual_cc="$cc2"
    elif [ -n "$cc3" ]; then actual_cc="$cc3"; fi

    local seen=""
    for cc in "$cc1" "$cc2" "$cc3"; do
        [ -z "$cc" ] && continue
        [ -z "$seen" ] && seen="$cc" || seen="$seen,$cc"
    done
    rm -rf "$tmpdir"
    echo "${bad}|${actual_cc}|${reason}|${seen}"
}

send_newnym() {
    local control_port="$1" pass="$2"
    (
        exec 3<>"/dev/tcp/127.0.0.1/${control_port}" 2>/dev/null || exit 1
        printf 'AUTHENTICATE "%s"\r\nSIGNAL NEWNYM\r\nQUIT\r\n' "$pass" >&3
        timeout 3 cat <&3 >/dev/null 2>&1
        exec 3<&- 3>&-
    ) 2>/dev/null || true
}

write_node_conf() {
    local conf_file="$1" out_port="$2" control_port="$3" hashed_pass="$4"
    local inst_data_dir="$5" code="$6"
    local bad_file="$inst_data_dir/bad_exits.txt"
    local exclude_line=""

    if [ -s "$bad_file" ]; then
        local bad_list
        bad_list=$(grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}(/([0-9]|[12][0-9]|3[0-2]))?$' "$bad_file" | paste -sd, - 2>/dev/null || true)
        if [ -n "$bad_list" ]; then
            exclude_line="ExcludeExitNodes $bad_list"
        fi
    fi

    cat <<EOF > "$conf_file"
SocksPort 127.0.0.1:$out_port
ControlPort 127.0.0.1:$control_port
HashedControlPassword $hashed_pass
DataDirectory $inst_data_dir
GeoIPExcludeUnknown 1
ExitNodes {$code}
StrictNodes 1
$exclude_line
RunAsDaemon 1
AvoidDiskWrites 1
Log err file $inst_data_dir/notices.log
EOF
}

health_check_node() {
    local code="$1" name="$2" out_port="$3" silent="${4:-1}"
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
    local inst_data_dir="$DATA_DIR/${code}_${out_port}"
    local ip_file="$inst_data_dir/last_ip.txt"
    [ -f "$conf_file" ] || return 0

    if ! acquire_node_lock "$code" "$out_port"; then
        return 3
    fi

    local current_ip="" old_ip="" result bad actual reason seen
    [ -s "$ip_file" ] && old_ip=$(head -n1 "$ip_file" | tr -d '\r\n')

    if ! node_process_running "$code" "$out_port"; then
        [ "$silent" = "1" ] || echo -e "${YELLOW}[!] $code process is down; rotating immediately.${NC}"
        release_node_lock
        rotate_one_node "$code" "$name" "$out_port" "$silent"
        return $?
    fi

    current_ip=$(get_node_ip "$out_port")
    if ! is_valid_ipv4 "$current_ip"; then
        # Two fast probes avoid rotating for a single transient ipify failure,
        # but any persistent non-IP/Waiting/empty response rotates immediately.
        sleep 1
        current_ip=$(get_node_ip "$out_port")
    fi

    if ! is_valid_ipv4 "$current_ip"; then
        [ "$silent" = "1" ] || echo -e "${RED}[!] $code returned no valid public IP; rotating now.${NC}"
        release_node_lock
        rotate_one_node "$code" "$name" "$out_port" "$silent"
        return $?
    fi

    if [ "$current_ip" != "$old_ip" ] || ! is_valid_ipv4 "$old_ip"; then
        result=$(check_ip_quality "$current_ip" "$code")
        IFS='|' read -r bad actual reason seen <<< "$result"
        if [ "$bad" = "0" ]; then
            printf '%s\n' "$current_ip" > "$ip_file"
            release_node_lock
            return 0
        fi
        append_bad_ip "$inst_data_dir/bad_exits.txt" "$current_ip"
        [ "$silent" = "1" ] || echo -e "${RED}[!] $code rejected IP $current_ip ($reason); rotating now.${NC}"
        release_node_lock
        rotate_one_node "$code" "$name" "$out_port" "$silent"
        return $?
    fi

    release_node_lock
    return 0
}

background_auto_heal() {
    check_root
    sync_dynamic_locations
    local idx details code name out_port
    local -a pids=()
    local running=0

    for idx in "${ORDER[@]}"; do
        details="${NODES[$idx]}"
        IFS=':' read -r code name out_port <<< "$details"
        [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] || continue
        health_check_node "$code" "$name" "$out_port" 1 &
        pids+=("$!")
        running=$((running+1))
        if (( running >= AUTO_HEAL_PARALLEL )); then
            wait "${pids[0]}" 2>/dev/null || true
            pids=("${pids[@]:1}")
            running=$((running-1))
        fi
    done
    for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
}

auto_heal_daemon() {
    check_root
    trap 'exit 0' INT TERM HUP
    while true; do
        background_auto_heal
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
    echo -e "${MAGENTA} ║${YELLOW}          A U T O M A T E   E N G I N E   V 6 . 1                   ${MAGENTA}║${NC}"
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

    if ! check_country_exit_availability "$code" "$name"; then
        cleanup_failed_node "$code" "$out_port"
        return 2
    fi

    mkdir -p "$BASE_DIR" "$inst_data_dir"
    touch "$bad_file"
    chown -R debian-tor:debian-tor "$inst_data_dir" 2>/dev/null || true

    if [ -n "${LOW_SUPPLY_WARN[$code]:-}" ]; then
        echo -e "${YELLOW}[!] Heads up: $name usually has very few Tor exit relays.${NC}"
        echo -e "${YELLOW}    The node will NOT be accepted unless the public IP verifies as $code.${NC}"
    fi

    local ctrl_pass hashed_pass control_port
    if [ -f "$ctrl_file" ]; then
        source "$ctrl_file" 2>/dev/null || true
        ctrl_pass="$CTRL_PASS"
        hashed_pass="$HASHED_PASS"
        control_port="$CTRL_PORT"
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

    write_node_conf "$conf_file" "$out_port" "$control_port" "$hashed_pass" "$inst_data_dir" "$code"
    chown debian-tor:debian-tor "$conf_file" 2>/dev/null || true

    if pgrep -f "node_${code}_${out_port}.conf" > /dev/null; then
        pkill -f "node_${code}_${out_port}.conf" 2>/dev/null || true
        sleep 2
    fi

    echo -e "${CYAN}[*] Routing ${WHITE}$code - $name ${CYAN}➔ Tor Port: ${MAGENTA}$out_port${CYAN}. Please wait...${NC}"
    run_tor_node "$conf_file"
    draw_progress "Bootstrapping Tor connection"

    local connect_attempts=0
    local total_attempts=0
    local newnym_tries=0
    local last_ip=""

    while [ "$total_attempts" -lt "$MAX_TOTAL_VALIDATION_ATTEMPTS" ]; do
        local public_ip
        public_ip=$(curl -4 -sS --socks5-hostname 127.0.0.1:"$out_port" https://api.ipify.org --connect-timeout 5 --max-time 12 | tr -d '\0\r\n' || true)

        if [ -z "$public_ip" ] || ! [[ "$public_ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
            connect_attempts=$((connect_attempts+1))
            total_attempts=$((total_attempts+1))
            echo -e "${CYAN}[*] Waiting for Tor connection (Attempt $total_attempts/$MAX_TOTAL_VALIDATION_ATTEMPTS)...${NC}"
            sleep 3
            continue
        fi

        echo -e "${CYAN}[*] Verifying ${MAGENTA}$public_ip${CYAN} against multiple GeoIP sources for ${WHITE}$code${CYAN}...${NC}"
        local result is_bad actual_cc reason seen_ccs
        result=$(check_ip_quality "$public_ip" "$code")
        IFS='|' read -r is_bad actual_cc reason seen_ccs <<< "$result"
        total_attempts=$((total_attempts+1))

        if [ "$is_bad" == "0" ]; then
            echo "$public_ip" > "$ip_file"
            echo -e "${GREEN}[+] VERIFIED: $public_ip → $code - $name${NC}"
            echo -e "${GREEN}[+] GeoIP sources: ${seen_ccs}${NC}"
            echo -e "${GREEN}[+] Online -> ${WHITE}$code - $name ${GREEN}($public_ip)${NC}\n"
            return 0
        fi

        echo -e "${RED}[-] Rejected $public_ip: ${reason} | detected=${seen_ccs:-unknown} | expected=$code${NC}"

        if ! grep -qxF "$public_ip" "$bad_file" 2>/dev/null; then
            echo "$public_ip" >> "$bad_file"
            sort -u -o "$bad_file" "$bad_file" 2>/dev/null || true
        fi

        if [ "$public_ip" == "$last_ip" ]; then
            newnym_tries=$MAX_NEWNYM_TRIES
        fi
        last_ip="$public_ip"

        if [ "$newnym_tries" -lt "$MAX_NEWNYM_TRIES" ]; then
            echo -e "${CYAN}    > Requesting a new circuit (NEWNYM)...${NC}"
            send_newnym "$control_port" "$ctrl_pass"
            newnym_tries=$((newnym_tries+1))
            sleep 6
        else
            echo -e "${YELLOW}    > Same/bad exit detected. Rebuilding Tor with this IP excluded...${NC}"
            write_node_conf "$conf_file" "$out_port" "$control_port" "$hashed_pass" "$inst_data_dir" "$code"
            pkill -f "node_${code}_${out_port}.conf" 2>/dev/null || true
            sleep 2
            run_tor_node "$conf_file"
            sleep 7
            newnym_tries=0
        fi
    done

    cleanup_failed_node "$code" "$out_port"
    echo -e "${RED}[-] FAILED: No verified $code exit IP was available after $MAX_TOTAL_VALIDATION_ATTEMPTS attempts.${NC}"
    echo -e "${YELLOW}[!] The node was NOT marked online and no wrong-country IP was accepted.${NC}\n"
    return 1
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

    local attempt new_ip result bad actual reason seen
    for attempt in $(seq 1 "$NODE_ROTATE_RETRIES"); do
        send_newnym "$CTRL_PORT" "$CTRL_PASS" || true
        sleep $((attempt <= 3 ? 2 : 4))
        new_ip=$(get_node_ip "$out_port")

        if is_valid_ipv4 "$new_ip"; then
            if [ "$new_ip" = "$old_ip" ]; then
                continue
            fi
            result=$(check_ip_quality "$new_ip" "$code")
            IFS='|' read -r bad actual reason seen <<< "$result"
            if [ "$bad" = "0" ]; then
                printf '%s\n' "$new_ip" > "$ip_file"
                [ "$silent" = "1" ] || echo -e "${GREEN}  ✓ $code → $new_ip${NC}"
                return 0
            fi
            append_bad_ip "$bad_file" "$new_ip"
            [ "$silent" = "1" ] || echo -e "${RED}  ✗ $code rejected $new_ip: $reason${NC}"
        else
            [ "$silent" = "1" ] || echo -e "${YELLOW}  • $code still has no valid IP (attempt $attempt/$NODE_ROTATE_RETRIES)${NC}"
        fi
    done

    # Escalate: fully rebuild Tor with known-bad exits excluded.
    if is_valid_ipv4 "$old_ip"; then append_bad_ip "$bad_file" "$old_ip"; fi
    write_node_conf "$conf_file" "$out_port" "$CTRL_PORT" "$HASHED_PASS" "$inst_data_dir" "$code"
    pkill -f "node_${code}_${out_port}\.conf" 2>/dev/null || true
    sleep 1
    run_tor_node "$conf_file"

    for attempt in $(seq 1 "$NODE_ROTATE_RETRIES"); do
        sleep 2
        new_ip=$(get_node_ip "$out_port")
        if is_valid_ipv4 "$new_ip"; then
            [ "$new_ip" != "$old_ip" ] || continue
            result=$(check_ip_quality "$new_ip" "$code")
            IFS='|' read -r bad actual reason seen <<< "$result"
            if [ "$bad" = "0" ]; then
                printf '%s\n' "$new_ip" > "$ip_file"
                [ "$silent" = "1" ] || echo -e "${GREEN}  ✓ $code → $new_ip (full restart)${NC}"
                return 0
            fi
            append_bad_ip "$bad_file" "$new_ip"
            write_node_conf "$conf_file" "$out_port" "$CTRL_PORT" "$HASHED_PASS" "$inst_data_dir" "$code"
            pkill -f "node_${code}_${out_port}\.conf" 2>/dev/null || true
            sleep 1
            run_tor_node "$conf_file"
        fi
    done

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
                IFS=':' read -r code name out_port <<< "${NODES[$pick]:-}"
                if [ -n "$code" ] && [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ]; then
                    rotate_one_node "$code" "$name" "$out_port" 0
                else
                    echo -e "${RED}[!] Invalid/inactive Node.${NC}"
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
        tor tor-geoipdb curl jq nano openssl unzip zip cron ca-certificates util-linux

    systemctl stop tor 2>/dev/null || true
    systemctl disable tor 2>/dev/null || true
    mkdir -p "$BASE_DIR" "$DATA_DIR"
    chown -R debian-tor:debian-tor "$DATA_DIR" 2>/dev/null || true

    # Install the exact currently-running engine atomically.
    local source="$SCRIPT_PATH"
    [ -f "$source" ] || { echo -e "${RED}[!] Cannot locate engine source: $source${NC}"; return 1; }
    bash -n "$source" || { echo -e "${RED}[!] Engine syntax check failed; refusing to install.${NC}"; return 1; }
    install -m 755 "$source" "$INSTALL_PATH"
    install -d -m 755 /root/.sherlook
    install -m 755 "$source" /root/.sherlook/sherlook.sh

    cat > /etc/systemd/system/sherlook-heal.service <<EOF
[Unit]
Description=Sherlook Continuous Tor Node Health and IP Auto-Heal
After=network-online.target tor.service
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
    echo -e "${CYAN}[*] Sherlook Update — current v${SHERLOOK_VERSION}${NC}"

    local tmp tmp_installer remote_version
    tmp=$(mktemp /tmp/sherlook_update.XXXXXX) || return 1
    tmp_installer=$(mktemp /tmp/sherlook_installer_update.XXXXXX) || { rm -f "$tmp"; return 1; }
    if ! curl -4 -fL --retry 5 --retry-delay 1 --connect-timeout 10 --max-time 60 \
        -o "$tmp" "$RAW_ENGINE_URL"; then
        echo -e "${RED}[!] Update download failed.${NC}"
        rm -f "$tmp" "$tmp_installer"
        return 1
    fi

    if ! head -n1 "$tmp" | grep -q '^#!'; then
        echo -e "${RED}[!] Remote payload is not a shell script; refusing update.${NC}"
        rm -f "$tmp"
        return 1
    fi
    if ! bash -n "$tmp"; then
        echo -e "${RED}[!] Remote script failed bash syntax validation; refusing update.${NC}"
        rm -f "$tmp" "$tmp_installer"
        return 1
    fi

    if curl -4 -fL --retry 3 --connect-timeout 10 --max-time 60 -o "$tmp_installer" "$RAW_INSTALLER_URL" 2>/dev/null; then
        if ! head -n1 "$tmp_installer" | grep -q '^#!' || ! bash -n "$tmp_installer"; then
            rm -f "$tmp_installer"
            tmp_installer=""
        fi
    else
        rm -f "$tmp_installer"
        tmp_installer=""
    fi

    remote_version=$(grep -m1 '^SHERLOOK_VERSION=' "$tmp" | sed -E 's/^SHERLOOK_VERSION="([^"]+)"/\1/' || true)
    [ -n "$remote_version" ] || remote_version="unknown"
    echo -e "${GREEN}[+] Remote version: ${remote_version}${NC}"

    local backup="$BASE_DIR/sherlook.sh.bak.$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BASE_DIR" /root/.sherlook
    if [ -f "$INSTALL_PATH" ]; then cp -a "$INSTALL_PATH" "$backup"; fi

    install -m 755 "$tmp" "$INSTALL_PATH.new"
    mv -f "$INSTALL_PATH.new" "$INSTALL_PATH"
    install -m 755 "$tmp" /root/.sherlook/sherlook.sh
    rm -f "$tmp"
    if [ -n "$tmp_installer" ] && [ -f "$tmp_installer" ]; then
        install -m 755 "$tmp_installer" /root/.sherlook/install.sh
        install -m 755 "$tmp_installer" /usr/local/bin/sherlook-install
    fi
    rm -f "$tmp_installer"

    # Re-sync the service definition through the freshly installed script.
    systemctl daemon-reload 2>/dev/null || true
    systemctl restart sherlook-heal.service 2>/dev/null || true

    echo -e "${GREEN}[+] Update installed atomically. Backup: $backup${NC}"
    echo -e "${YELLOW}[*] Restarting Sherlook with the new engine...${NC}"
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
    rm -f /usr/local/bin/sherlook
    echo -e "${GREEN}[+] Uninstallation complete.${NC}"
    exit 0
}

list_locations() {
    sync_dynamic_locations || true
    echo -e "${YELLOW}Available Tor Exit Locations (dynamic + built-in):${NC}\n"

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
    if [[ "$loc_idx" == "00" ]]; then return; fi
    p_idx=$(printf "%02d" "$loc_idx" 2>/dev/null)
    if [[ -n "${NODES[$p_idx]:-}" ]]; then
        IFS=':' read -r code name out_port <<< "${NODES[$p_idx]}"

        if node_is_installed "$code" "$out_port"; then
            echo -e "\n${YELLOW}[!] Node $code - $name is already active. You cannot install it again.${NC}"
            sleep 2
        else
            deploy_node "$code" "$name" "$out_port"
            read -p "$(echo -e ${WHITE}"Press Enter to return..."${NC})"
        fi
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
    while true; do
        draw_header
        sync_dynamic_locations
        echo -e "${CYAN}» Option 6 - Active Nodes Monitor${NC}"
        echo -e "${YELLOW}[*] Health daemon checks every ${AUTO_HEAL_INTERVAL}s. This screen only reads current state.${NC}\n"
        echo -e "${BLUE}┌──────┬──────┬──────────────────────┬─────────────┬──────────────┬──────────────────┐${NC}"
        echo -e "${BLUE}│${WHITE} ID   ${BLUE}│${WHITE} CC   ${BLUE}│${WHITE} Location             ${BLUE}│${WHITE} Tor Port    ${BLUE}│${WHITE} Status       ${BLUE}│${WHITE} Live IP          ${BLUE}│${NC}"
        echo -e "${BLUE}├──────┼──────┼──────────────────────┼─────────────┼──────────────┼──────────────────┤${NC}"

        local found=0 idx details code name out_port display_ip status
        for idx in "${ORDER[@]}"; do
            details="${NODES[$idx]}"
            IFS=':' read -r code name out_port <<< "$details"
            [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] || continue
            found=1
            display_ip="Waiting..."
            local ip_file="$DATA_DIR/${code}_${out_port}/last_ip.txt"
            [ -s "$ip_file" ] && is_valid_ipv4 "$(head -n1 "$ip_file" | tr -d '\r\n')" && display_ip=$(head -n1 "$ip_file" | tr -d '\r\n')
            if node_process_running "$code" "$out_port"; then status="ONLINE"; else status="HEALING"; fi
            if [ "$status" = "ONLINE" ]; then
                printf "${BLUE}│ ${CYAN}%-4s ${BLUE}│ ${WHITE}%-4s ${BLUE}│ ${WHITE}%-20s ${BLUE}│ ${MAGENTA}%-11s ${BLUE}│ ${GREEN}%-12s ${BLUE}│ ${GREEN}%-16s ${BLUE}│${NC}\n" "$idx" "$code" "$name" "$out_port" "$status" "$display_ip"
            else
                printf "${BLUE}│ ${CYAN}%-4s ${BLUE}│ ${WHITE}%-4s ${BLUE}│ ${WHITE}%-20s ${BLUE}│ ${MAGENTA}%-11s ${BLUE}│ ${YELLOW}%-12s ${BLUE}│ ${YELLOW}%-16s ${BLUE}│${NC}\n" "$idx" "$code" "$name" "$out_port" "$status" "$display_ip"
            fi
        done
        [ "$found" -eq 0 ] && printf "${BLUE}│ ${YELLOW}%-82s ${BLUE}│${NC}\n" "No installed nodes found."
        echo -e "${BLUE}└──────┴──────┴──────────────────────┴─────────────┴──────────────┴──────────────────┘${NC}\n"
        echo -e "${MAGENTA}[ Continuous Health Monitor ]${NC} Refreshes every 3 seconds. Press any key to return."
        if read -t 3 -n 1 -s key; then break; fi
    done
}

edit_delete_nodes() {
    draw_header
    echo -e "📌 ${MAGENTA}[ DELETE ACTIVE NODE ]${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"
    local active_nodes=()
    for idx in "${ORDER[@]}"; do
        IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
        if node_has_record "$code" "$out_port"; then
            active_nodes+=("$idx")
            local emoji="${EMOJIS[$code]}"
            local status_label="${GREEN}RUNNING${NC}"
            if ! pgrep -f "node_${code}_${out_port}.conf" > /dev/null; then
                status_label="${RED}DEAD${NC}"
            fi
            printf "  ${CYAN}[%s]${NC} %s %-18s \tTorPort:${MAGENTA}%-6s${NC} \t%b\n" "$idx" "$emoji" "$name" "$out_port" "$status_label"
        fi
    done
    if [ ${#active_nodes[@]} -eq 0 ]; then
        echo -e "  ${RED}No installed nodes to delete.${NC}"; sleep 2; return
    fi
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"
    echo -e "  ${RED}[99] DELETE ALL ACTIVE NODES (Clear All)${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────${NC}"

    read -p "$(echo -e ${CYAN}"Select ID to stop/delete (or 0 to cancel): "${NC})" del_sel

    if [[ "$del_sel" == "0" || -z "$del_sel" ]]; then return; fi

    if [[ "$del_sel" == "99" ]]; then
        echo -e "\n${YELLOW}[!] Deleting ALL active nodes... Please wait.${NC}"
        for idx in "${active_nodes[@]}"; do
            IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
            pkill -9 -f "node_${code}_${out_port}.conf" 2>/dev/null || true
        done
        sleep 1.5
        for idx in "${active_nodes[@]}"; do
            IFS=':' read -r code name out_port <<< "${NODES[$idx]}"
            rm -f "$BASE_DIR/node_${code}_${out_port}.conf"
            rm -rf "$DATA_DIR/${code}_${out_port}" 2>/dev/null || true
        done
        echo -e "${GREEN}[+] All nodes removed successfully.${NC}"; sleep 2
        return
    fi

    del_sel=$(printf "%02d" $((10#$del_sel)) 2>/dev/null || echo "")
    if [[ -n "${NODES[$del_sel]:-}" ]]; then
        IFS=':' read -r code name out_port <<< "${NODES[$del_sel]}"
        pkill -9 -f "node_${code}_${out_port}.conf" 2>/dev/null || true
        sleep 1
        rm -f "$BASE_DIR/node_${code}_${out_port}.conf"
        rm -rf "$DATA_DIR/${code}_${out_port}" 2>/dev/null || true
        echo -e "${GREEN}[+] Node removed.${NC}"; sleep 2
    fi
}

# ================= PASARGAD PANEL INTEGRATION =================

panel_login() {
    draw_header
    echo -e "⏳ ${CYAN}Connecting to Pasargad panel...${NC}"

    if [ -f "$PANEL_CONF" ]; then
        source "$PANEL_CONF" 2>/dev/null || true
        if [ -n "$URL" ] && [ -n "$TOKEN" ]; then
            echo -e "\n${GREEN}[+] Saved session found:${NC} ${WHITE}$URL${NC}"
            read -p "$(echo -e ${CYAN}"❓ Do you want to use the saved session? (Y/n): "${NC})" use_saved
            if [[ -z "$use_saved" || "${use_saved,,}" == "y" ]]; then
                echo -e "${GREEN}🟢 Login resumed successfully!${NC}"
                sleep 1
                panel_menu
                return
            fi
        fi
    fi

    echo -e "${YELLOW}[~] Detecting panel URL...${NC}"
    read -p "$(echo -e "  Panel domain (e.g. panel.example.com) []: ")" p_domain
    read -p "$(echo -e "  Panel port (e.g. 8443) []: ")" p_port

    local base_url="https://${p_domain}:${p_port}"

    read -p "  Admin username: " p_user
    read -s -p "  Admin password: " p_pass
    echo ""

    mkdir -p "$BASE_DIR"
    echo "URL=$base_url" > "$PANEL_CONF"
    echo "USER=$p_user" >> "$PANEL_CONF"
    echo "PASS=$p_pass" >> "$PANEL_CONF"

    echo -e "${YELLOW}[~] Logging in...${NC}"
    local token_resp=$(curl -s -X POST "$base_url/api/admin/token" \
        -d "grant_type=password&username=$p_user&password=$p_pass" | tr -d '\0')
    local token=$(echo "$token_resp" | jq -r '.access_token' 2>/dev/null || echo "null")

    if [ "$token" == "null" ] || [ -z "$token" ]; then
        echo -e "${RED}[!] Login failed. Ensure details are correct.${NC}"; sleep 2
    else
        echo "TOKEN=$token" >> "$PANEL_CONF"
        echo -e "${GREEN}🟢 Login successful!${NC}"
        sleep 1
        panel_menu
    fi
}

panel_menu() {
    while true; do
        draw_header
        echo -e "📌 ${MAGENTA}[ PASARGAD CONTROL PANEL ]${NC}"
        echo -e "${BLUE}=============================================${NC}"
        echo -e "  ${GREEN}[1]${NC} Auto-Extract Panel Configurations"
        echo -e "  ${RED}[2]${NC} Logout (Exit Panel)"
        echo -e "  ${YELLOW}[0]${NC} Return to Main Menu"
        echo -e "${BLUE}=============================================${NC}\n"
        read -p "$(echo -e ${CYAN}"Selected option: "${NC})" panel_opt

        if [ "$panel_opt" == "0" ]; then
            break
        elif [ "$panel_opt" == "2" ]; then
            rm -f "$PANEL_CONF"; break
        elif [ "$panel_opt" == "1" ]; then
            panel_batch_create
        fi
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

    echo -e "\n${YELLOW}[~] 🤖 Simulating browser... Scanning Pasargad for Core configurations...${NC}"

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
           "$FINAL_FILE" > tmp.json && mv tmp.json "$FINAL_FILE"

        jq --arg t "$out_tag" --arg p "$out_port" \
           'if has("outbounds") and .outbounds != null then . else .outbounds = [] end | .outbounds += [{"tag": $t, "protocol": "socks", "settings": {"servers": [{"address": "127.0.0.1", "port": ($p|tonumber)}]}}]' \
           "$FINAL_FILE" > tmp.json && mv tmp.json "$FINAL_FILE"

        jq --arg intag "$in_tag" --arg outtag "$out_tag" \
           'if has("routing") and .routing != null then . else .routing = {"rules": []} end | if .routing.rules == null then .routing.rules = [] else . end | .routing.rules += [{"type": "field", "inboundTag": [$intag], "outboundTag": $outtag}]' \
           "$FINAL_FILE" > tmp.json && mv tmp.json "$FINAL_FILE"

        if [ "$clone_host_json" != "{}" ] && [ "$clone_host_json" != "null" ]; then
            jq --arg tag "$in_tag" --arg p "$rand_port" --arg rem "$new_remark" --argjson obj "$clone_host_json" \
               '. += [($obj | .inbound_tag=$tag | .port=($p|tonumber) | .remark=$rem | .enable=1 | del(.id, .created_at, .updated_at))]' \
               "$NEW_HOSTS_FILE" > tmp_hosts.json && mv tmp_hosts.json "$NEW_HOSTS_FILE" || true
        else
            jq --arg tag "$in_tag" --arg p "$rand_port" --arg rem "$new_remark" --arg addr "$cloned_sni" \
               '. += [{"inbound_tag": $tag, "remark": $rem, "address": [$addr], "port": ($p|tonumber), "enable": 1}]' \
               "$NEW_HOSTS_FILE" > tmp_hosts.json && mv tmp_hosts.json "$NEW_HOSTS_FILE" || true
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

    local host_len=$(jq 'length' "$NEW_HOSTS_FILE")
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
            local is_arr=$(echo "$current_hosts" | jq 'type == "array"')

            if [ "$is_arr" == "true" ]; then
                echo "$current_hosts" > "$BASE_DIR/all_hosts_tmp.json"
            else
                echo "$current_hosts" | jq -c '.data // []' > "$BASE_DIR/all_hosts_tmp.json"
            fi

            jq --argjson newh "$h_data" '. += [$newh]' "$BASE_DIR/all_hosts_tmp.json" > tmp_h.json && mv tmp_h.json "$BASE_DIR/all_hosts_tmp.json"

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
    echo -e "  ${YELLOW}[9]${NC} ${WHITE}»${NC} Panel Pasarguard Integration"
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
