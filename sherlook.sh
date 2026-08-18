#!/usr/bin/env bash
# Sherlook Automate Engine v6.2.1
# Compatibility wrapper: fetches the current Sherlook Multi engine and applies
# the 6.2.1 health/recovery hardening before executing it.
set -euo pipefail

VERSION="6.2.1"
RAW_URL="https://raw.githubusercontent.com/SherlookHolmz/multi/1f53d18d5cc80ceaf21a093b75fd1133432e5f84/sherlook.sh"
CACHE_DIR="/var/lib/tor/sherlook_nodes"
CACHE_FILE="$CACHE_DIR/.sherlook-base.sh"
PATCHED_FILE="$CACHE_DIR/.sherlook-engine-${VERSION}.sh"

log(){ printf '[Sherlook %s] %s\n' "$VERSION" "$*"; }
fail(){ printf '[Sherlook %s] ERROR: %s\n' "$VERSION" "$*" >&2; exit 1; }

mkdir -p "$CACHE_DIR"

fetch_base(){
  local tmp
  tmp=$(mktemp "${CACHE_DIR}/base.XXXXXX")
  if curl -4 -fL --retry 4 --retry-delay 1 --connect-timeout 10 --max-time 90 -sS -o "$tmp" "$RAW_URL"; then
    if head -n1 "$tmp" | grep -q '^#!'; then
      install -m 755 "$tmp" "$CACHE_FILE"
      rm -f "$tmp"
      return 0
    fi
  fi
  rm -f "$tmp"
  [ -s "$CACHE_FILE" ] && return 0
  fail "unable to obtain the Sherlook base engine"
}

patch_engine(){
python3 - "$CACHE_FILE" "$PATCHED_FILE" <<'PY'
import re, sys
src_path, out_path = sys.argv[1:]
s = open(src_path, encoding='utf-8').read()

# Version / retry configuration.
s = re.sub(r'^SHERLOOK_VERSION="[^"]+"$', 'SHERLOOK_VERSION="6.2.1"', s, flags=re.M)
s = re.sub(r'^NODE_ROTATE_RETRIES=\d+$', 'NODE_ROTATE_RETRIES=20', s, flags=re.M)
if 'HEAL_REBUILD_AFTER=' not in s:
    s = s.replace('NODE_ROTATE_RETRIES=20\n', 'NODE_ROTATE_RETRIES=20\nHEAL_REBUILD_AFTER=4\nHEAL_IP_FAILURE_LIMIT=3\nHEAL_STATE_TTL=30\n')

# Make NEWNYM report success/failure instead of swallowing all failures.
new_send = r'''send_newnym() {
    local control_port="$1" pass="$2"
    local response=""
    response=$(
        exec 3<>"/dev/tcp/127.0.0.1/${control_port}" 2>/dev/null || exit 2
        printf 'AUTHENTICATE "%s"\r\nSIGNAL NEWNYM\r\nQUIT\r\n' "$pass" >&3
        timeout 4 cat <&3 2>/dev/null || true
        exec 3<&- 3>&-
    ) || true
    grep -q '250 OK' <<<"$response"
}
'''
s, n = re.subn(r'send_newnym\(\) \{.*?\n\}\n\nwrite_node_conf\(\)', new_send + '\nwrite_node_conf()', s, flags=re.S)
if n != 1:
    raise SystemExit('send_newnym patch target not found')

# Add a small persistent node-state writer immediately before health_check_node.
state_helper = r'''write_node_state() {
    local code="$1" port="$2" state="$3" ip="${4:-}" reason="${5:-}"
    local dir="$DATA_DIR/${code}_${port}"
    mkdir -p "$dir"
    {
        printf 'state=%s\n' "$state"
        printf 'ip=%s\n' "$ip"
        printf 'reason=%s\n' "$reason"
        printf 'updated=%s\n' "$(date +%s)"
    } > "$dir/state.env"
}

'''
if 'write_node_state() {' not in s:
    s = s.replace('health_check_node() {', state_helper + 'health_check_node() {', 1)

# Replace health_check_node with strict, single-owner recovery logic.
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
    [ -s "$ip_file" ] && old_ip=$(head -n1 "$ip_file" | tr -d '\r\n')
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

    # Always validate the observed live IP. Do not trust last_ip.txt just because
    # the process is still running.
    result=$(check_ip_quality "$current_ip" "$code")
    IFS='|' read -r bad actual reason seen <<< "$result"

    if [ "$bad" = "0" ]; then
        printf '%s\n' "$current_ip" > "$ip_file"
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
s, n = re.subn(r'health_check_node\(\) \{.*?\n\}\n\nbackground_auto_heal\(\)', health + '\nbackground_auto_heal()', s, flags=re.S)
if n != 1:
    raise SystemExit('health_check_node patch target not found')

# Replace the whole rotation core with a 20-attempt bounded state machine.
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
    [ -s "$ip_file" ] && old_ip=$(head -n1 "$ip_file" | tr -d '\r\n')

    local attempt=0 consecutive_failures=0 same_ip_failures=0 rebuilds=0
    local new_ip="" result bad actual reason seen
    write_node_state "$code" "$out_port" "HEALING" "$old_ip" "rotation-start"

    while [ "$attempt" -lt "$NODE_ROTATE_RETRIES" ]; do
        attempt=$((attempt + 1))

        # First preference: rotate circuit without killing the process.
        if [ "$consecutive_failures" -lt "$HEAL_REBUILD_AFTER" ]; then
            if send_newnym "$CTRL_PORT" "$CTRL_PASS"; then
                sleep $((attempt <= 3 ? 2 : 4))
            else
                sleep 1
            fi
        else
            # Escalation: rebuild Tor using the accumulated bad-exit set.
            rebuilds=$((rebuilds + 1))
            write_node_conf "$conf_file" "$out_port" "$CTRL_PORT" "$HASHED_PASS" "$inst_data_dir" "$code"
            pkill -f "node_${code}_${out_port}\\.conf" 2>/dev/null || true
            sleep 1
            run_tor_node "$conf_file"
            sleep 2
            consecutive_failures=0
        fi

        new_ip=$(get_node_ip "$out_port" || true)

        if ! is_valid_ipv4 "$new_ip"; then
            consecutive_failures=$((consecutive_failures + 1))
            write_node_state "$code" "$out_port" "HEALING" "$old_ip" "NO_VALID_IP_ATTEMPT_${attempt}"
            continue
        fi

        if [ "$new_ip" = "$old_ip" ]; then
            same_ip_failures=$((same_ip_failures + 1))
            consecutive_failures=$((consecutive_failures + 1))
            # If Tor keeps giving the same exit, blacklist it before rebuilding.
            if [ "$same_ip_failures" -ge "$HEAL_IP_FAILURE_LIMIT" ]; then
                append_bad_ip "$bad_file" "$new_ip"
                consecutive_failures=$HEAL_REBUILD_AFTER
            fi
            continue
        fi

        result=$(check_ip_quality "$new_ip" "$code")
        IFS='|' read -r bad actual reason seen <<< "$result"

        if [ "$bad" = "0" ]; then
            printf '%s\n' "$new_ip" > "$ip_file"
            write_node_state "$code" "$out_port" "ONLINE" "$new_ip" "verified"
            [ "$silent" = "1" ] || echo -e "${GREEN}  ✓ $code → $new_ip (verified on attempt $attempt/$NODE_ROTATE_RETRIES)${NC}"
            return 0
        fi

        append_bad_ip "$bad_file" "$new_ip"
        consecutive_failures=$((consecutive_failures + 1))
        same_ip_failures=0
        write_node_state "$code" "$out_port" "HEALING" "$new_ip" "$reason"
        [ "$silent" = "1" ] || echo -e "${YELLOW}  • $code rejected $new_ip: $reason (attempt $attempt/$NODE_ROTATE_RETRIES)${NC}"

        # Force an earlier rebuild after repeated validation failures.
        if [ "$consecutive_failures" -ge "$HEAL_REBUILD_AFTER" ]; then
            consecutive_failures=$HEAL_REBUILD_AFTER
        fi
    done

    # Final fail-safe: never claim ONLINE with an unverified IP.
    rm -f "$ip_file"
    write_node_state "$code" "$out_port" "FAILED" "" "NO_VERIFIED_IP_AFTER_${NODE_ROTATE_RETRIES}_ATTEMPTS"
    echo "$(date '+%Y-%m-%d %H:%M:%S') rotation failed for $code after $NODE_ROTATE_RETRIES attempts; rebuilds=$rebuilds" >> "$inst_data_dir/heal_fail.log"
    [ "$silent" = "1" ] || echo -e "${RED}  ✗ $code: no verified replacement IP after $NODE_ROTATE_RETRIES attempts.${NC}"
    return 1
}
'''
s, n = re.subn(r'rotate_one_node_core\(\) \{.*?\n\}\n\nrotate_one_node\(\)', rotate + '\nrotate_one_node()', s, flags=re.S)
if n != 1:
    raise SystemExit('rotate_one_node_core patch target not found')

# Make the active monitor trust the persisted health state, not just pgrep.
old = '''            if node_process_running "$code" "$out_port"; then status="ONLINE"; else status="HEALING"; fi'''
new = '''            status="HEALING"
            state_file="$DATA_DIR/${code}_${out_port}/state.env"
            if [ -s "$state_file" ]; then
                state_value=$(awk -F= '$1=="state"{print $2; exit}' "$state_file" 2>/dev/null || true)
                state_ip=$(awk -F= '$1=="ip"{print $2; exit}' "$state_file" 2>/dev/null || true)
                state_ts=$(awk -F= '$1=="updated"{print $2; exit}' "$state_file" 2>/dev/null || echo 0)
                if [ "$state_value" = "ONLINE" ] && is_valid_ipv4 "$state_ip"; then
                    status="ONLINE"
                    display_ip="$state_ip"
                elif [ "$state_value" = "FAILED" ]; then
                    status="FAILED"
                fi
            fi'''
if old not in s:
    raise SystemExit('monitor status target not found')
s = s.replace(old, new, 1)

# Ensure installer/service gets the new version without changing panel integration.
open(out_path, 'w', encoding='utf-8').write(s)
PY
chmod 755 "$PATCHED_FILE"
}

fetch_base
patch_engine
exec bash "$PATCHED_FILE" "$@"
