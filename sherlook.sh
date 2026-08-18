#!/usr/bin/env bash
# Sherlook Automate Engine v6.2.2
# Stable wrapper: keeps the pinned v6.x engine, applies 6.2.2 fixes atomically,
# and never replaces a working cached engine when the network is unavailable.
set -euo pipefail

VERSION="6.2.2"
RAW_URL="https://raw.githubusercontent.com/SherlookHolmz/multi/1f53d18d5cc80ceaf21a093b75fd1133432e5f84/sherlook.sh"
CACHE_DIR="/var/lib/tor/sherlook_nodes"
CACHE_FILE="$CACHE_DIR/.sherlook-base.sh"
PATCHED_FILE="$CACHE_DIR/.sherlook-engine-${VERSION}.sh"

fail(){ printf '[Sherlook %s] ERROR: %s\n' "$VERSION" "$*" >&2; exit 1; }

mkdir -p "$CACHE_DIR"

fetch_base(){
    local tmp
    tmp=$(mktemp "${CACHE_DIR}/base.XXXXXX")
    if curl -4 -fL --retry 10 --retry-all-errors --retry-delay 2         --connect-timeout 8 --max-time 120 -sS -o "$tmp" "$RAW_URL"; then
        if head -n1 "$tmp" | grep -q '^#!'; then
            install -m 755 "$tmp" "$CACHE_FILE"
            rm -f "$tmp"
            return 0
        fi
    fi
    rm -f "$tmp"
    [ -s "$CACHE_FILE" ] && return 0
    fail "unable to obtain Sherlook base engine and no cached engine is available"
}

patch_engine(){
python3 - "$CACHE_FILE" "$PATCHED_FILE" <<'PY'
import re, sys
src_path, out_path = sys.argv[1:]
s = open(src_path, encoding="utf-8").read()

s = re.sub(r'^SHERLOOK_VERSION="[^"]+"$', 'SHERLOOK_VERSION="6.2.2"', s, flags=re.M)
s = re.sub(r'^NODE_ROTATE_RETRIES=\d+$', 'NODE_ROTATE_RETRIES=14', s, flags=re.M)
s = re.sub(r'^MAX_TOTAL_VALIDATION_ATTEMPTS=\d+$', 'MAX_TOTAL_VALIDATION_ATTEMPTS=32', s, flags=re.M)
if 'HEAL_REBUILD_AFTER=' not in s:
    s=s.replace('NODE_ROTATE_RETRIES=14\n',
                'NODE_ROTATE_RETRIES=14\nHEAL_REBUILD_AFTER=3\nHEAL_IP_FAILURE_LIMIT=2\nHEAL_STATE_TTL=30\nNETWORK_RETRY_LIMIT=6\n',1)
else:
    s=re.sub(r'^HEAL_REBUILD_AFTER=\d+$','HEAL_REBUILD_AFTER=3',s,flags=re.M)
    s=re.sub(r'^HEAL_IP_FAILURE_LIMIT=\d+$','HEAL_IP_FAILURE_LIMIT=2',s,flags=re.M)
    s=re.sub(r'^HEAL_STATE_TTL=\d+$','HEAL_STATE_TTL=30',s,flags=re.M)
    if 'NETWORK_RETRY_LIMIT=' not in s:
        s=s.replace('HEAL_STATE_TTL=30\n','HEAL_STATE_TTL=30\nNETWORK_RETRY_LIMIT=6\n',1)

# Never expand ISO-3166 into candidate locations.
s = s.replace('\nexpand_iso_locations\n',
              '\n# 6.2.2: Onionoo running Tor Exits are the only Location source.\n', 1)

old_order = '''    mapfile -t ORDER < <(printf '%s\\n' "${!NODES[@]}" | sort -n)
}'''
new_order = '''    # 6.2.2: keep only countries present in the last known-good running Exit cache.
    if [ -s "$LOCATION_CACHE" ]; then
        declare -A TOR_EXIT_CC=()
        while IFS= read -r _cc; do
            [[ "$_cc" =~ ^[A-Z]{2}$ ]] && TOR_EXIT_CC["$_cc"]=1
        done < "$LOCATION_CACHE"

        local _key _details _cc _name _port
        for _key in "${!NODES[@]}"; do
            _details="${NODES[$_key]}"
            IFS=':' read -r _cc _name _port <<< "$_details"
            if [ -z "${TOR_EXIT_CC[$_cc]:-}" ]; then
                unset 'NODES[$_key]'
            fi
        done
    else
        NODES=()
    fi

    mapfile -t ORDER < <(printf '%s\\n' "${!NODES[@]}" | sort -n)
}'''
if old_order not in s:
    raise SystemExit("location order anchor not found")
s=s.replace(old_order,new_order,1)

old_check = '''    if [ "$count" = "-1" ]; then
        echo -e "${YELLOW}[!] Onionoo availability check failed for $code.${NC}"
        echo -e "${YELLOW}[!] Continuing with Tor because the directory service could not be reached.${NC}"
        return 0
    fi'''
new_check = '''    if [ "$count" = "-1" ]; then
        if [ -s "$LOCATION_CACHE" ] && grep -qx "$code" "$LOCATION_CACHE"; then
            echo -e "${YELLOW}[!] Onionoo temporarily unavailable; using the last known-good Exit cache for $code.${NC}"
            return 0
        fi
        echo -e "${RED}[-] Cannot verify a Tor Exit for $code while Onionoo is unavailable.${NC}"
        echo -e "${YELLOW}[!] Install will not proceed with an unverified country.${NC}"
        return 1
    fi'''
if old_check in s:
    s=s.replace(old_check,new_check,1)

new_send = r'''send_newnym() {
    local control_port="$1" pass="$2"
    local response=""
    response=$(
        exec 3<>"/dev/tcp/127.0.0.1/${control_port}" 2>/dev/null || exit 2
        printf 'AUTHENTICATE "%s"
SIGNAL NEWNYM
QUIT
' "$pass" >&3
        timeout 4 cat <&3 2>/dev/null || true
        exec 3<&- 3>&-
    ) || true
    grep -q '250 OK' <<<"$response"
}
'''
s,n=re.subn(r'send_newnym\(\) \{.*?\n\}\n\nwrite_node_conf\(\)',new_send+'\nwrite_node_conf()',s,flags=re.S)
if n != 1:
    raise SystemExit("send_newnym target not found")

state_helper = r'''write_node_state() {
    local code="$1" port="$2" state="$3" ip="${4:-}" reason="${5:-}"
    local dir="$DATA_DIR/${code}_${port}"
    mkdir -p "$dir"
    {
        printf 'state=%s
' "$state"
        printf 'ip=%s
' "$ip"
        printf 'reason=%s
' "$reason"
        printf 'updated=%s
' "$(date +%s)"
    } > "$dir/state.env"
}

'''
if 'write_node_state() {' not in s:
    s=s.replace('health_check_node() {',state_helper+'health_check_node() {',1)

health = r'''health_check_node() {
    local code="$1" name="$2" out_port="$3" silent="${4:-1}"
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
    local inst_data_dir="$DATA_DIR/${code}_${out_port}"
    local ip_file="$inst_data_dir/last_ip.txt"
    [ -f "$conf_file" ] || return 0

    if ! acquire_node_lock "$code" "$out_port"; then
        return 3
    fi

    local current_ip="" old_ip="" result bad actual reason seen
    [ -s "$ip_file" ] && old_ip=$(head -n1 "$ip_file" | tr -d '
')
    write_node_state "$code" "$out_port" "HEALING" "$old_ip" "health-check"

    if ! node_process_running "$code" "$out_port"; then
        release_node_lock
        rotate_one_node "$code" "$name" "$out_port" "$silent"
        return $?
    fi

    current_ip=$(get_node_ip "$out_port" || true)
    if ! is_valid_ipv4 "$current_ip"; then
        release_node_lock
        rotate_one_node "$code" "$name" "$out_port" "$silent"
        return $?
    fi

    result=$(check_ip_quality "$current_ip" "$code")
    IFS='|' read -r bad actual reason seen <<< "$result"

    if [ "$bad" = "0" ]; then
        printf '%s
' "$current_ip" > "$ip_file"
        write_node_state "$code" "$out_port" "ONLINE" "$current_ip" "verified"
        release_node_lock
        return 0
    fi

    append_bad_ip "$inst_data_dir/bad_exits.txt" "$current_ip"
    write_node_state "$code" "$out_port" "HEALING" "$current_ip" "$reason"
    release_node_lock
    rotate_one_node "$code" "$name" "$out_port" "$silent"
    return $?
}
'''
s,n=re.subn(r'health_check_node\(\) \{.*?\n\}\n\nbackground_auto_heal\(\)',health+'\nbackground_auto_heal()',s,flags=re.S)
if n != 1:
    raise SystemExit("health target not found")

rotate = r'''rotate_one_node_core() {
    local code="$1" name="$2" out_port="$3" silent="${4:-0}"
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
    local inst_data_dir="$DATA_DIR/${code}_${out_port}"
    local ctrl_file="$inst_data_dir/control.env"
    local bad_file="$inst_data_dir/bad_exits.txt"
    local ip_file="$inst_data_dir/last_ip.txt"
    [ -f "$conf_file" ] && [ -f "$ctrl_file" ] || return 2

    source "$ctrl_file" 2>/dev/null || return 2
    local old_ip=""
    [ -s "$ip_file" ] && old_ip=$(head -n1 "$ip_file" | tr -d '
')

    local attempt=0 new_ip="" result bad actual reason seen
    local rebuilds=0
    write_node_state "$code" "$out_port" "HEALING" "$old_ip" "rotation-start"
    [ "$silent" = "1" ] || echo -e "${CYAN}🔄 $code - $name: changing IP...${NC}"

    for attempt in 1 2 3; do
        if send_newnym "$CTRL_PORT" "$CTRL_PASS"; then
            sleep 2
        else
            sleep 1
        fi

        new_ip=$(get_node_ip "$out_port" || true)
        if ! is_valid_ipv4 "$new_ip"; then
            continue
        fi
        if [ "$new_ip" = "$old_ip" ]; then
            append_bad_ip "$bad_file" "$new_ip"
            continue
        fi

        result=$(check_ip_quality "$new_ip" "$code")
        IFS='|' read -r bad actual reason seen <<< "$result"
        if [ "$bad" = "0" ]; then
            printf '%s
' "$new_ip" > "$ip_file"
            write_node_state "$code" "$out_port" "ONLINE" "$new_ip" "verified"
            [ "$silent" = "1" ] || echo -e "${GREEN}  ✓ $code → $new_ip${NC}"
            return 0
        fi
        append_bad_ip "$bad_file" "$new_ip"
    done

    if is_valid_ipv4 "$old_ip"; then
        append_bad_ip "$bad_file" "$old_ip"
    fi

    for rebuilds in 1 2 3; do
        write_node_conf "$conf_file" "$out_port" "$CTRL_PORT" "$HASHED_PASS" "$inst_data_dir" "$code"
        pkill -f "node_${code}_${out_port}\.conf" 2>/dev/null || true
        sleep 1
        run_tor_node "$conf_file"

        for attempt in 1 2 3 4; do
            sleep 2
            new_ip=$(get_node_ip "$out_port" || true)
            if ! is_valid_ipv4 "$new_ip"; then
                continue
            fi
            if [ "$new_ip" = "$old_ip" ]; then
                append_bad_ip "$bad_file" "$new_ip"
                continue
            fi

            result=$(check_ip_quality "$new_ip" "$code")
            IFS='|' read -r bad actual reason seen <<< "$result"
            if [ "$bad" = "0" ]; then
                printf '%s
' "$new_ip" > "$ip_file"
                write_node_state "$code" "$out_port" "ONLINE" "$new_ip" "verified"
                [ "$silent" = "1" ] || echo -e "${GREEN}  ✓ $code → $new_ip (rebuild $rebuilds)${NC}"
                return 0
            fi

            append_bad_ip "$bad_file" "$new_ip"
        done
    done

    rm -f "$ip_file"
    write_node_state "$code" "$out_port" "FAILED" "" "NO_VERIFIED_IP"
    echo "$(date '+%Y-%m-%d %H:%M:%S') rotation failed for $code" >> "$inst_data_dir/heal_fail.log"
    [ "$silent" = "1" ] || echo -e "${RED}  ✗ $code: no verified replacement IP found.${NC}"
    return 1
}
'''
s,n=re.subn(r'rotate_one_node_core\(\) \{.*?\n\}\n\nrotate_one_node\(\)',rotate+'\nrotate_one_node()',s,flags=re.S)
if n != 1:
    raise SystemExit("rotate target not found")

old_net = r'''        if [ -z "$public_ip" ] || ! [[ "$public_ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
            connect_attempts=$((connect_attempts+1))
            total_attempts=$((total_attempts+1))
            echo -e "${CYAN}[*] Waiting for Tor connection (Attempt $total_attempts/$MAX_TOTAL_VALIDATION_ATTEMPTS)...${NC}"
            sleep 3
            continue
        fi'''
new_net = r'''        if [ -z "$public_ip" ] || ! [[ "$public_ip" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
            if ! curl -4 -fsS --connect-timeout 3 --max-time 5 https://api.ipify.org -o /dev/null 2>/dev/null; then
                echo -e "${YELLOW}[!] Upstream network is unavailable; keeping the partial install intact and retrying...${NC}"
                sleep 5
                continue
            fi
            connect_attempts=$((connect_attempts+1))
            total_attempts=$((total_attempts+1))
            echo -e "${CYAN}[*] Waiting for Tor connection (Attempt $total_attempts/$MAX_TOTAL_VALIDATION_ATTEMPTS)...${NC}"
            sleep 2
            continue
        fi'''
if old_net in s:
    s=s.replace(old_net,new_net,1)

s=s.replace('Available Tor Exit Locations (dynamic + built-in):',
            'Available Tor Exit Locations (Tor Exit-only):')
s=s.replace('A U T O M A T E   E N G I N E   V 6 . 1',
            'A U T O M A T E   E N G I N E   V 6 . 2 . 2')

old_status='''            if node_process_running "$code" "$out_port"; then status="ONLINE"; else status="HEALING"; fi'''
new_status='''            status="HEALING"
            state_file="$DATA_DIR/${code}_${out_port}/state.env"
            if [ -s "$state_file" ]; then
                state_value=$(awk -F= '$1=="state"{print $2; exit}' "$state_file" 2>/dev/null || true)
                state_ip=$(awk -F= '$1=="ip"{print $2; exit}' "$state_file" 2>/dev/null || true)
                if [ "$state_value" = "ONLINE" ] && is_valid_ipv4 "$state_ip"; then
                    status="ONLINE"
                    display_ip="$state_ip"
                elif [ "$state_value" = "FAILED" ]; then
                    status="FAILED"
                fi
            fi'''
if old_status in s:
    s=s.replace(old_status,new_status,1)

open(out_path,'w',encoding='utf-8').write(s)
PY
chmod 755 "$PATCHED_FILE"
}

fetch_base
patch_engine
exec bash "$PATCHED_FILE" "$@"
