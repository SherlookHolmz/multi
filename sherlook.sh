#!/usr/bin/env bash
# Sherlook Multi v6.2.5 — hardened synchronized launcher/engine updater
set -euo pipefail

VERSION="6.2.5"
RAW_URL="https://raw.githubusercontent.com/SherlookHolmz/multi/main/sherlook.sh"
CACHE_DIR="/root/.sherlook"
BASE_ENGINE="$CACHE_DIR/upstream-sherlook.sh"
PATCHED_ENGINE="$CACHE_DIR/sherlook-6.2.5.sh"
LOCK_FILE="$CACHE_DIR/update.lock"

root_check() {
    [ "${EUID:-$(id -u)}" -eq 0 ] || { echo "[!] Run as root." >&2; exit 1; }
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || { echo "[!] Missing command: $1" >&2; exit 1; }
}

extract_overlay() {
    awk 'found{print} /^__OVERLAY_BEGIN__$/ {found=1; next}' "$0" > "$CACHE_DIR/overlay-6.2.5.sh"
}

fetch_file() {
    local url="$1" out="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -4 -fsSL --retry 5 --retry-all-errors --connect-timeout 10 --max-time 120 -o "$out" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$out" "$url"
    else
        echo '[!] curl or wget is required.' >&2
        return 1
    fi
}

patch_engine() {
    local src="$1" overlay="$CACHE_DIR/overlay-6.2.5.sh" out="$PATCHED_ENGINE.tmp"
    python3 - "$src" "$overlay" "$out" <<'PY'
from pathlib import Path
import sys
src, overlay, out = map(Path, sys.argv[1:])
text = src.read_text(encoding='utf-8')
over = overlay.read_text(encoding='utf-8')
marker = 'if [ "${1:-}" = "--version" ]; then'
if marker not in text:
    raise SystemExit('[!] Upstream entrypoint marker not found; refusing to patch.')
if 'SHERLOOK v6.2.5 FINAL HARDENING OVERRIDES' in text:
    patched = text
else:
    patched = text.replace(marker, over + '\n\n' + marker, 1)
patched = patched.replace('SHERLOOK_VERSION="6.2.3"', 'SHERLOOK_VERSION="6.2.5"', 1)
out.write_text(patched, encoding='utf-8')
PY
    bash -n "$out"
    install -m 755 "$out" "$PATCHED_ENGINE"
    rm -f "$out"
}

ensure_engine() {
    root_check
    need_cmd bash
    need_cmd python3
    need_cmd jq
    need_cmd flock
    mkdir -p "$CACHE_DIR"
    chmod 700 "$CACHE_DIR"
    extract_overlay
    chmod 600 "$CACHE_DIR/overlay-6.2.5.sh"

    exec 9>"$LOCK_FILE"
    flock -x 9
    local refresh=0
    [ "${SHERLOOK_FORCE_UPDATE:-0}" = 1 ] && refresh=1
    [ ! -s "$BASE_ENGINE" ] && refresh=1

    if [ "$refresh" -eq 1 ]; then
        local tmp="$CACHE_DIR/upstream.tmp.$$.sh"
        fetch_file "$RAW_URL" "$tmp"
        bash -n "$tmp"
        install -m 755 "$tmp" "$BASE_ENGINE"
        rm -f "$tmp"
    fi

    patch_engine "$BASE_ENGINE"
    flock -u 9
}

case "${1:-}" in
    --version)
        echo "$VERSION"
        exit 0
        ;;
    --refresh)
        SHERLOOK_FORCE_UPDATE=1 ensure_engine
        exec "$PATCHED_ENGINE" --version
        ;;
esac

ensure_engine
exec "$PATCHED_ENGINE" "$@"

__OVERLAY_BEGIN__
# ===== SHERLOOK v6.2.5 OVERLAY =====
SHERLOOK_VERSION="6.2.5"
PANEL_NODE_MAP="$BASE_DIR/panel_node_map.json"
HEALTH_GEO_TTL=60

# ---------- Unified status / auto-heal ----------
node_process_running() {
    local code="$1" port="$2"
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$"; then return 0; fi
    pgrep -f "node_${code}_${port}\\.conf" >/dev/null 2>&1
}

node_status_for_ui() {
    local code="$1" port="$2" ip
    [ -f "$BASE_DIR/node_${code}_${port}.conf" ] || { printf '%s\\n' NOT_INSTALLED; return; }
    ip=$(get_node_ip "$port" 2>/dev/null || true)
    if is_valid_ipv4 "$ip"; then printf '%s\\n' ONLINE
    elif node_process_running "$code" "$port"; then printf '%s\\n' HEALING
    else printf '%s\\n' DEAD; fi
}

health_check_node() {
    local code="$1" name="$2" out_port="$3" silent="${4:-1}"
    local conf_file="$BASE_DIR/node_${code}_${out_port}.conf"
    local data_dir="$DATA_DIR/${code}_${out_port}"
    local ip_file="$data_dir/last_ip.txt" health_ip="$data_dir/health_ip.txt" health_ts="$data_dir/health_checked_at"
    [ -f "$conf_file" ] || return 0
    acquire_node_lock "$code" "$out_port" || return 3

    local current_ip old_ip expected now last_ts result bad actual reason seen
    current_ip=$(get_node_ip "$out_port" 2>/dev/null || true)
    if ! is_valid_ipv4 "$current_ip"; then
        rm -f "$health_ts" "$health_ip"
        release_node_lock
        [ "$silent" = 1 ] || echo -e "${RED}[!] $code SOCKS is unreachable; repairing.${NC}"
        rotate_one_node "$code" "$name" "$out_port" "$silent"
        return $?
    fi

    old_ip=""; [ -s "$ip_file" ] && old_ip=$(head -n1 "$ip_file" | tr -d '\r\n')
    last_ts=0; [ -s "$health_ts" ] && last_ts=$(cat "$health_ts" 2>/dev/null || echo 0)
    now=$(date +%s)
    expected=$(node_route_code "$code" "$out_port")

    if [ "$current_ip" != "$old_ip" ] || [ "$current_ip" != "$(cat "$health_ip" 2>/dev/null || true)" ] || [ $((now-last_ts)) -ge "$HEALTH_GEO_TTL" ]; then
        result=$(check_ip_quality "$current_ip" "$expected")
        IFS='|' read -r bad actual reason seen <<< "$result"
        if [ "$bad" != 0 ]; then
            append_bad_ip "$data_dir/bad_exits.txt" "$current_ip"
            rm -f "$health_ts" "$health_ip"
            release_node_lock
            [ "$silent" = 1 ] || echo -e "${RED}[!] $code failed live validation: $reason (detected=${seen:-unknown}, expected=$expected). Repairing.${NC}"
            rotate_one_node "$code" "$name" "$out_port" "$silent"
            return $?
        fi
        printf '%s\\n' "$current_ip" > "$ip_file"
        printf '%s\\n' "$current_ip" > "$health_ip"
    fi
    printf '%s\\n' "$current_ip" > "$health_ip"
    printf '%s\\n' "$now" > "$health_ts"
    release_node_lock
    return 0
}

background_auto_heal() {
    check_root
    sync_dynamic_locations
    local idx details code name out_port running=0
    local -a pids=()
    for idx in "${ORDER[@]}"; do
        details="${NODES[$idx]}"; IFS=':' read -r code name out_port <<< "$details"
        [ -f "$BASE_DIR/node_${code}_${out_port}.conf" ] || continue
        health_check_node "$code" "$name" "$out_port" 1 &
        pids+=("$!"); running=$((running+1))
        if ((running >= AUTO_HEAL_PARALLEL)); then
            wait "${pids[0]}" 2>/dev/null || true
            pids=("${pids[@]:1}"); running=$((running-1))
        fi
    done
    local pid; for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
}

# ---------- Selection helpers ----------
parse_panel_selection() {
    local input="$1" token a b n idx
    local -a result=(); declare -A seen=()
    input="${input// /}"; input="${input//;/,}"
    IFS=',' read -ra parts <<< "$input"
    for token in "${parts[@]}"; do
        if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            a=$((10#${BASH_REMATCH[1]})); b=$((10#${BASH_REMATCH[2]}))
            if ((a>b)); then n=$a; a=$b; b=$n; fi
            for ((n=a;n<=b;n++)); do
                idx=$(printf '%02d' "$n")
                if [[ -n "${NODES[$idx]:-}" && -z "${seen[$idx]:-}" ]]; then result+=("$idx"); seen[$idx]=1; fi
            done
        elif [[ "$token" =~ ^[0-9]+$ ]]; then
            idx=$(printf '%02d' "$((10#$token))")
            if [[ -n "${NODES[$idx]:-}" && -z "${seen[$idx]:-}" ]]; then result+=("$idx"); seen[$idx]=1; fi
        fi
    done
    printf '%s\\n' "${result[@]}"
}

# ---------- Panel metadata ----------
panel_map_init() {
    mkdir -p "$(dirname "$PANEL_NODE_MAP")"
    [ -s "$PANEL_NODE_MAP" ] || printf '%s\\n' '{}' > "$PANEL_NODE_MAP"
    jq -e 'type=="object"' "$PANEL_NODE_MAP" >/dev/null 2>&1 || printf '%s\\n' '{}' > "$PANEL_NODE_MAP"
}

panel_map_get() {
    local idx="$1" field="$2"; panel_map_init
    jq -r --arg i "$idx" --arg f "$field" '.[$i][$f] // empty' "$PANEL_NODE_MAP" 2>/dev/null || true
}

panel_map_set() {
    local idx="$1" code="$2" name="$3" in_tag="$4" out_tag="$5" host_id="$6" core_url="$7"
    panel_map_init; local tmp
    tmp=$(mktemp)
    jq --arg i "$idx" --arg c "$code" --arg n "$name" --arg it "$in_tag" --arg ot "$out_tag" --arg h "$host_id" --arg u "$core_url" \
       '.[$i]={code:$c,name:$n,in_tag:$it,out_tag:$ot,host_id:(if $h=="" then null else ($h|tonumber) end),core_url:$u}' \
       "$PANEL_NODE_MAP" > "$tmp" && mv -f "$tmp" "$PANEL_NODE_MAP"
}

panel_map_del() {
    local idx="$1"; panel_map_init; local tmp; tmp=$(mktemp)
    jq --arg i "$idx" 'del(.[$i])' "$PANEL_NODE_MAP" > "$tmp" && mv -f "$tmp" "$PANEL_NODE_MAP"
}

panel_session_ok() {
    [ -s "$PANEL_CONF" ] || return 1
    source "$PANEL_CONF" 2>/dev/null || return 1
    [ -n "${URL:-}" ] && [ -n "${TOKEN:-}" ]
}

panel_get_hosts() {
    local raw
    raw=$(curl -4 -fsS --max-time 20 -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' "$URL/api/hosts" 2>/dev/null || true)
    if echo "$raw" | jq -e 'type=="array"' >/dev/null 2>&1; then printf '%s\\n' "$raw"; else echo "$raw" | jq -c '.data // []' 2>/dev/null || echo '[]'; fi
}

panel_find_core() {
    PANEL_CORE_URL=""; PANEL_CORE_RAW=""; PANEL_CORE_JSON=""
    local ep resp id got
    local -a eps=("/api/admin/cores" "/api/cores" "/api/core" "/api/node/cores" "/api/admin/core")
    for ep in "${eps[@]}"; do
        resp=$(curl -4 -fsS --max-time 20 -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' "$URL$ep/1" 2>/dev/null || true)
        got=$(extract_json_from_response "$resp")
        if [ -n "$got" ]; then PANEL_CORE_URL="$URL$ep/1"; PANEL_CORE_RAW="$resp"; PANEL_CORE_JSON="$got"; return 0; fi
        resp=$(curl -4 -fsS --max-time 20 -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' "$URL$ep" 2>/dev/null || true)
        for id in $(echo "$resp" | jq -r '.[].id // .data[].id // empty' 2>/dev/null); do
            resp=$(curl -4 -fsS --max-time 20 -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' "$URL$ep/$id" 2>/dev/null || true)
            got=$(extract_json_from_response "$resp")
            if [ -n "$got" ]; then PANEL_CORE_URL="$URL$ep/$id"; PANEL_CORE_RAW="$resp"; PANEL_CORE_JSON="$got"; return 0; fi
        done
    done
    return 1
}

panel_save_core() {
    local cfg="$1" raw_obj payload tmp resp code
    raw_obj=$(printf '%s' "$PANEL_CORE_RAW" | jq -c 'if type=="object" and has("data") then .data else . end' 2>/dev/null); [ -n "$raw_obj" ] || raw_obj='{}'
    payload=$(printf '%s' "$raw_obj" | jq --argjson cfg "$cfg" 'if .config!=null then .config=$cfg elif .xray_config!=null then .xray_config=$cfg elif .content!=null then .content=$cfg else .config=$cfg end')
    tmp=$(mktemp); printf '%s\\n' "$payload" > "$tmp"
    resp=$(curl -4 -sS -w '\n%{http_code}' -X PUT "$PANEL_CORE_URL?restart_nodes=true" --max-time 30 \
        -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -H 'Accept: application/json' -d @"$tmp" 2>/dev/null || true)
    rm -f "$tmp"; code=$(tail -n1 <<<"$resp"); [[ "$code" =~ ^2[0-9][0-9]$ ]]
}

panel_delete_host() {
    local id="$1" path code resp
    [ -n "$id" ] || return 1
    for path in "/api/hosts/$id" "/api/host/$id" "/api/admin/hosts/$id" "/api/admin/host/$id"; do
        resp=$(curl -4 -sS -w '\n%{http_code}' -X DELETE "$URL$path" -H "Authorization: Bearer $TOKEN" 2>/dev/null || true)
        code=$(tail -n1 <<<"$resp")
        [[ "$code" =~ ^2[0-9][0-9]$ ]] && return 0
    done
    return 1
}

panel_delete_nodes() {
    panel_session_ok || { echo -e "${YELLOW}[!] Panel session unavailable.${NC}"; return 2; }
    local -a ids=("$@"); ((${#ids[@]}>0)) || return 1
    panel_find_core || { echo -e "${RED}[!] Panel core not found.${NC}"; return 1; }
    local core="$PANEL_CORE_JSON" idx code name port in_tag out_tag safe prefix hosts hlen i hid htag hremark
    for idx in "${ids[@]}"; do
        IFS=':' read -r code name port <<< "${NODES[$idx]}"
        in_tag=$(panel_map_get "$idx" in_tag); out_tag=$(panel_map_get "$idx" out_tag)
        safe=$(printf '%s' "$name" | tr -d ' ' | tr -cd '[:alnum:]-')
        prefix="${code}-${safe}-"
        if [ -n "$in_tag" ]; then
            core=$(jq -c --arg t "$in_tag" 'if .inbounds then .inbounds=[.inbounds[]|select(.tag!=$t)] else . end' <<<"$core")
            core=$(jq -c --arg t "$in_tag" --arg o "$out_tag" 'if .routing.rules then .routing.rules=[.routing.rules[]|select(not((.outboundTag==$o and ($o|length)>0) or ((.inboundTag//[])|index($t)!=null and ($t|length)>0)))] else . end' <<<"$core")
        else
            core=$(jq -c --arg p "$prefix" 'if .inbounds then .inbounds=[.inbounds[]|select(((.tag|type)!="string") or (.tag|startswith($p)|not))] else . end' <<<"$core")
        fi
        if [ -n "$out_tag" ]; then
            core=$(jq -c --arg t "$out_tag" 'if .outbounds then .outbounds=[.outbounds[]|select(.tag!=$t)] else . end' <<<"$core")
        else
            core=$(jq -c --arg p "${code}-${safe}-OUT-" 'if .outbounds then .outbounds=[.outbounds[]|select(((.tag|type)!="string") or (.tag|startswith($p)|not))] else . end' <<<"$core")
        fi

        hosts=$(panel_get_hosts); hlen=$(jq 'length' <<<"$hosts" 2>/dev/null || echo 0)
        for ((i=0;i<hlen;i++)); do
            hid=$(jq -r ".[$i].id // empty" <<<"$hosts"); htag=$(jq -r ".[$i].inbound_tag // empty" <<<"$hosts"); hremark=$(jq -r ".[$i].remark // empty" <<<"$hosts")
            if { [ -n "$in_tag" ] && [ "$htag" = "$in_tag" ]; } || { [ -z "$in_tag" ] && [ "$hremark" = "${EMOJIS[$code]} $name" ]; }; then
                if panel_delete_host "$hid"; then echo -e "  ${GREEN}✓ Host $hid deleted for [$idx] $name.${NC}"; else echo -e "  ${YELLOW}! Host $hid could not be deleted through DELETE endpoint.${NC}"; fi
            fi
        done
        panel_map_del "$idx"
    done
    panel_save_core "$core" || { echo -e "${RED}[!] Panel core cleanup failed.${NC}"; return 1; }
    echo -e "${GREEN}[+] Panel Inbound + Outbound + Routing + matching Host cleanup completed.${NC}"
}

panel_select_template() {
    panel_find_core || return 1
    local i count tag port proto net sec sel real hosts hcount htag rem addr hp hsel
    count=$(jq '.inbounds|length' <<<"$PANEL_CORE_JSON" 2>/dev/null || echo 0)
    echo -e "${MAGENTA}[ SELECT INBOUND TEMPLATE ]${NC}"
    for ((i=0;i<count;i++)); do
        tag=$(jq -r ".inbounds[$i].tag // \"\"" <<<"$PANEL_CORE_JSON")
        port=$(jq -r ".inbounds[$i].port // \"\"" <<<"$PANEL_CORE_JSON")
        proto=$(jq -r ".inbounds[$i].protocol // \"\"" <<<"$PANEL_CORE_JSON")
        net=$(jq -r ".inbounds[$i] | if .streamSettings.network then .streamSettings.network elif .settings.network then .settings.network else \"tcp\" end" <<<"$PANEL_CORE_JSON")
        sec=$(jq -r ".inbounds[$i] | if .streamSettings.security then .streamSettings.security else \"none\" end" <<<"$PANEL_CORE_JSON")
        printf '  [%d] %-7s %-12s %-8s %-9s %s\\n' "$((i+1))" "$port" "$proto" "$net" "$sec" "$tag"
    done
    read -r -p "Select inbound template [1-$count]: " sel < /dev/tty || return 1
    [[ "$sel" =~ ^[0-9]+$ ]] || return 1; ((sel>=1 && sel<=count)) || return 1
    real=$((sel-1)); PANEL_CLONE_INBOUND_JSON=$(jq -c ".inbounds[$real]" <<<"$PANEL_CORE_JSON")
    hosts=$(panel_get_hosts); hcount=$(jq 'length' <<<"$hosts" 2>/dev/null || echo 0)
    PANEL_CLONE_HOST_JSON='{}'; PANEL_CLONED_SNI=''
    echo -e "${MAGENTA}[ SELECT HOST TEMPLATE ]${NC}"
    if ((hcount>0)); then
        for ((i=0;i<hcount;i++)); do
            htag=$(jq -r ".[$i].inbound_tag // \"\"" <<<"$hosts"); rem=$(jq -r ".[$i].remark // \"\"" <<<"$hosts"); addr=$(jq -r ".[$i].address | if type==\"array\" and length>0 then .[0] elif type==\"string\" then . else \"\" end" <<<"$hosts"); hp=$(jq -r ".[$i].port // \"\"" <<<"$hosts")
            printf '  [%d] %-22s %-28s %-25s %s\\n' "$((i+1))" "$htag" "$rem" "$addr" "$hp"
        done
        read -r -p "Select host template [1-$hcount] (0=skip): " hsel < /dev/tty || hsel=0
        if [[ "$hsel" =~ ^[0-9]+$ ]] && ((hsel>0 && hsel<=hcount)); then
            PANEL_CLONE_HOST_JSON=$(jq -c ".[$((hsel-1))]" <<<"$hosts")
            PANEL_CLONED_SNI=$(jq -r '.address | if type=="array" and length>0 then .[0] elif type=="string" then . else "" end' <<<"$PANEL_CLONE_HOST_JSON")
        fi
    else
        read -r -p 'Template SNI/Address (empty=none): ' PANEL_CLONED_SNI < /dev/tty || PANEL_CLONED_SNI=''
    fi
}

panel_sync_selected_nodes() {
    panel_session_ok || return 2
    local -a ids=("$@"); ((${#ids[@]}>0)) || return 1
    panel_select_template || return 1
    local core="$PANEL_CORE_JSON" idx code name port safe in_tag out_tag in_port exists host_json map_id
    local -a made_tags=()
    for idx in "${ids[@]}"; do
        IFS=':' read -r code name port <<< "${NODES[$idx]}"
        if [ -n "$(panel_map_get "$idx" in_tag)" ]; then echo -e "${YELLOW}[!] [$idx] mapping already exists; skipping.${NC}"; continue; fi
        safe=$(printf '%s' "$name" | tr -d ' ' | tr -cd '[:alnum:]-')
        while true; do
            in_port=$((RANDOM%6000+3000)); in_tag="${code}-${safe}-IN-${in_port}"; out_tag="${code}-${safe}-OUT-${port}"
            exists=$(jq -e --arg t "$in_tag" '.inbounds[]?|select(.tag==$t)' <<<"$core" >/dev/null 2>&1 && echo 1 || echo 0); [ "$exists" = 0 ] && break
        done
        core=$(jq -c --arg t "$in_tag" --arg p "$in_port" --argjson obj "$PANEL_CLONE_INBOUND_JSON" 'if .inbounds==null then .inbounds=[] else . end | .inbounds += [($obj|.port=($p|tonumber)|.tag=$t)]' <<<"$core")
        core=$(jq -c --arg t "$out_tag" --arg p "$port" 'if .outbounds==null then .outbounds=[] else . end | .outbounds += [{tag:$t,protocol:"socks",settings:{servers:[{address:"127.0.0.1",port:($p|tonumber)}]}}]' <<<"$core")
        core=$(jq -c --arg i "$in_tag" --arg o "$out_tag" 'if .routing==null then .routing={rules:[]} elif .routing.rules==null then .routing.rules=[] else . end | .routing.rules += [{type:"field",inboundTag:[$i],outboundTag:$o}]' <<<"$core")
        host_json='{}'
        if [ "$PANEL_CLONE_HOST_JSON" != '{}' ]; then
            host_json=$(jq -c --arg t "$in_tag" --arg p "$in_port" --arg r "${EMOJIS[$code]} $name" --argjson obj "$PANEL_CLONE_HOST_JSON" '$obj|.inbound_tag=$t|.port=($p|tonumber)|.remark=$r|.enable=1|del(.id,.created_at,.updated_at)')
        elif [ -n "$PANEL_CLONED_SNI" ]; then
            host_json=$(jq -nc --arg t "$in_tag" --arg p "$in_port" --arg r "${EMOJIS[$code]} $name" --arg a "$PANEL_CLONED_SNI" '{inbound_tag:$t,remark:$r,address:[$a],port:($p|tonumber),enable:1}')
        fi
        made_tags+=("$idx|$code|$name|$in_tag|$out_tag|$host_json")
        echo -e "  ${GREEN}✓ [$idx]${NC} $name prepared -> inbound:$in_port outbound:$port"
    done
    panel_save_core "$core" || { echo -e "${RED}[!] Core upload failed; aborting host injection.${NC}"; return 1; }
    local item tag host_resp http_code new_id
    for item in "${made_tags[@]}"; do
        IFS='|' read -r idx code name in_tag out_tag host_json <<< "$item"
        new_id=''
        if [ "$host_json" != '{}' ]; then
            for ep in /api/host /api/hosts /api/admin/host /api/admin/hosts; do
                host_resp=$(curl -4 -sS -w '\n%{http_code}' -X POST "$URL$ep" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d "$host_json" 2>/dev/null || true)
                http_code=$(tail -n1 <<<"$host_resp")
                if [[ "$http_code" =~ ^2[0-9][0-9]$ || "$http_code" == 409 ]]; then new_id=$(head -n -1 <<<"$host_resp" | jq -r '.id // .data.id // empty' 2>/dev/null | head -n1); break; fi
            done
        fi
        panel_map_set "$idx" "$code" "$name" "$in_tag" "$out_tag" "$new_id" "$PANEL_CORE_URL"
    done
    echo -e "${GREEN}[+] ${#made_tags[@]} node(s) added to Panel and mapped for future cleanup.${NC}"
}

# ---------- Combined install + panel ----------
install_and_panel_sync() {
    local -a ids=("$@"); ((${#ids[@]}>0)) || return 1
    local do_panel='n'
    panel_session_ok && read -r -p 'Also add successful nodes to Panel? [Y/n]: ' do_panel < /dev/tty || true
    local idx code name port
    local -a ready=()
    for idx in "${ids[@]}"; do
        IFS=':' read -r code name port <<< "${NODES[$idx]}"
        if node_is_installed "$code" "$port"; then ready+=("$idx"); continue; fi
        deploy_node "$code" "$name" "$port" || true
        node_is_installed "$code" "$port" && ready+=("$idx")
    done
    if [[ "${do_panel,,}" == y || "${do_panel,,}" == yes ]]; then
        ((${#ready[@]}>0)) && panel_sync_selected_nodes "${ready[@]}"
    fi
}

# ---------- UI overrides ----------
view_active_nodes() {
    check_root
    while true; do
        draw_header
        echo -e "${CYAN}» Unified Active Nodes Monitor${NC}"
        echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
        printf '  %-4s %-4s %-22s %-8s %-10s %-16s\\n' ID CC Location TorPort Status LiveIP
        echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
        local idx code name port st ip
        for idx in "${ORDER[@]}"; do
            IFS=':' read -r code name port <<< "${NODES[$idx]}"
            [ -f "$BASE_DIR/node_${code}_${port}.conf" ] || continue
            st=$(node_status_for_ui "$code" "$port"); ip=$(get_node_ip "$port" 2>/dev/null || echo '—')
            case "$st" in
                ONLINE) printf '  %-4s %-4s %-22s %-8s %b %-16s\\n' "$idx" "$code" "$name" "$port" "${GREEN}ONLINE${NC}" "$ip" ;;
                HEALING) printf '  %-4s %-4s %-22s %-8s %b %-16s\\n' "$idx" "$code" "$name" "$port" "${YELLOW}HEALING${NC}" "$ip" ;;
                *) printf '  %-4s %-4s %-22s %-8s %b %-16s\\n' "$idx" "$code" "$name" "$port" "${RED}DEAD${NC}" "$ip" ;;
            esac
        done
        echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
        read -r -t 3 -n 1 -s key < /dev/tty && break || true
    done
}

add_single_node() {
    check_root; draw_header; list_locations
    local raw idx code name port
    read -r -p 'Select location index: ' raw < /dev/tty || return
    [[ "$raw" =~ ^[0-9]+$ ]] || return
    idx=$(printf '%02d' "$((10#$raw))"); [ -n "${NODES[$idx]:-}" ] || return
    IFS=':' read -r code name port <<< "${NODES[$idx]}"
    node_is_installed "$code" "$port" && { echo -e "${YELLOW}[!] Already installed. Use panel menu to sync it.${NC}"; return; }
    install_and_panel_sync "$idx"
    read -r -p 'Press Enter...' < /dev/tty || true
}

bulk_add_nodes() {
    check_root; draw_header
    echo -e "${CYAN}» Bulk Add Nodes (install + optional panel sync)${NC}"
    echo '1) All supported'; echo '2) Custom (1,2,4-7)'; echo '3) Main countries'; echo '0) Back'
    local mode; read -r -p 'Mode: ' mode < /dev/tty || return
    local -a selected=() main=(02 03 04 08 12 13 15 17 36 37)
    local idx raw token a b n
    if [ "$mode" = 1 ]; then selected=("${ORDER[@]}")
    elif [ "$mode" = 3 ]; then selected=("${main[@]}")
    elif [ "$mode" = 2 ]; then
        list_locations; read -r -p 'Indices: ' raw < /dev/tty || return
        mapfile -t selected < <(parse_panel_selection "$raw")
    else return; fi
    install_and_panel_sync "${selected[@]}"
    read -r -p 'Press Enter...' < /dev/tty || true
}

edit_delete_nodes() {
    check_root
    while true; do
        draw_header
        echo -e "${MAGENTA}[ NODE MAINTENANCE / AUTO-REPAIR ]${NC}"
        local idx code name port st
        for idx in "${ORDER[@]}"; do
            IFS=':' read -r code name port <<< "${NODES[$idx]}"
            [ -f "$BASE_DIR/node_${code}_${port}.conf" ] || continue
            st=$(node_status_for_ui "$code" "$port")
            printf '  [%s] %-20s %-8s %s\\n' "$idx" "$name" "$port" "$st"
        done
        echo -e "${BLUE}────────────────────────────────────────────────────────────────${NC}"
        echo '1) Repair/Rebuild selected'; echo '2) Delete selected (LOCAL + PANEL)'; echo '3) Auto-repair all DEAD/HEALING'; echo '4) Refresh'; echo '0) Back'
        local action raw; read -r -p 'Action: ' action < /dev/tty || return
        case "$action" in
            1)
                read -r -p 'Node IDs (1,2,4-7): ' raw < /dev/tty || continue
                mapfile -t selected < <(parse_panel_selection "$raw")
                local id c n p; for id in "${selected[@]}"; do IFS=':' read -r c n p <<< "${NODES[$id]}"; [ -f "$BASE_DIR/node_${c}_${p}.conf" ] && rotate_one_node "$c" "$n" "$p" 0 & done; wait || true ;;
            2)
                read -r -p 'Node IDs to delete (e.g. 1-21): ' raw < /dev/tty || continue
                mapfile -t selected < <(parse_panel_selection "$raw"); [ ${#selected[@]} -gt 0 ] || continue
                local cp='n'; panel_session_ok && read -r -p 'Delete panel Host + Inbound + Outbound + Routing too? [Y/n]: ' cp < /dev/tty || true
                if [[ "${cp,,}" == y || "${cp,,}" == yes ]]; then panel_delete_nodes "${selected[@]}"; fi
                local id c n p
                for id in "${selected[@]}"; do IFS=':' read -r c n p <<< "${NODES[$id]}"; pkill -9 -f "node_${c}_${p}\\.conf" 2>/dev/null || true; rm -f "$BASE_DIR/node_${c}_${p}.conf"; rm -rf "$DATA_DIR/${c}_${p}"; done
                echo -e "${GREEN}[+] Selected node(s) removed.${NC}" ;;
            3)
                local -a dead=(); local id c n p
                for id in "${ORDER[@]}"; do IFS=':' read -r c n p <<< "${NODES[$id]}"; [ -f "$BASE_DIR/node_${c}_${p}.conf" ] || continue; st=$(node_status_for_ui "$c" "$p"); [ "$st" = ONLINE ] || dead+=("$id"); done
                for id in "${dead[@]}"; do IFS=':' read -r c n p <<< "${NODES[$id]}"; rotate_one_node "$c" "$n" "$p" 1 & done; wait || true ;;
            4) ;;
            0) return ;;
        esac
    done
}

panel_batch_create() {
    panel_session_ok || { echo -e "${YELLOW}[!] Connect to Panel first via option 9.${NC}"; return; }
    draw_header; list_locations
    local raw; read -r -p 'Node IDs to INSTALL+ADD (e.g. 1-21): ' raw < /dev/tty || return
    mapfile -t ids < <(parse_panel_selection "$raw"); [ ${#ids[@]} -gt 0 ] || return
    local id code name port
    for id in "${ids[@]}"; do
        IFS=':' read -r code name port <<< "${NODES[$id]}"
        if ! node_is_installed "$code" "$port"; then deploy_node "$code" "$name" "$port" || true; fi
    done
    local -a ready=()
    for id in "${ids[@]}"; do IFS=':' read -r code name port <<< "${NODES[$id]}"; node_is_installed "$code" "$port" && ready+=("$id"); done
    ((${#ready[@]}>0)) && panel_sync_selected_nodes "${ready[@]}"
    read -r -p 'Press Enter...' < /dev/tty || true
}

panel_menu() {
    while true; do
        draw_header
        echo -e "${MAGENTA}[ PANEL NEXATIS / PASARGUARD INTEGRATION ]${NC}"
        echo '1) Install + Add (single/bulk)'; echo '2) Add already-installed node(s)'; echo '3) Delete node(s) from Panel'; echo '4) Inspect core'; echo '5) Logout'; echo '0) Back'
        local op raw; read -r -p 'Option: ' op < /dev/tty || return
        case "$op" in
            1) panel_batch_create ;;
            2) list_locations; read -r -p 'Installed node IDs: ' raw < /dev/tty || continue; mapfile -t ids < <(parse_panel_selection "$raw"); ((${#ids[@]}>0)) && panel_sync_selected_nodes "${ids[@]}" ;;
            3) list_locations; read -r -p 'Delete Panel resources (e.g. 1-21): ' raw < /dev/tty || continue; mapfile -t ids < <(parse_panel_selection "$raw"); ((${#ids[@]}>0)) && panel_delete_nodes "${ids[@]}" ;;
            4) panel_find_core && echo -e "${GREEN}[+] Core endpoint: $PANEL_CORE_URL${NC}" || echo -e "${RED}[!] Core not found.${NC}"; read -r -p 'Press Enter...' < /dev/tty || true ;;
            5) rm -f "$PANEL_CONF"; return ;;
            0) return ;;
        esac
    done
}

# Replace the old version handling only after all overrides are defined.

# ===== SHERLOOK v6.2.5 FINAL HARDENING OVERRIDES =====
SHERLOOK_VERSION="6.2.5"
LOGO_VERSION="6.2.5"
PANEL_NODE_MAP="$BASE_DIR/panel_node_map.json"
HEALTH_GEO_TTL=30

panel_map_set() {
    local idx="$1" code="$2" name="$3" in_tag="$4" out_tag="$5" host_id="$6" core_url="$7"
    panel_map_init
    local tmp
    tmp=$(mktemp "$PANEL_NODE_MAP.tmp.XXXXXX") || return 1
    jq --arg i "$idx" --arg c "$code" --arg n "$name" --arg it "$in_tag" --arg ot "$out_tag" --arg h "$host_id" --arg u "$core_url" \
       '.[$i]={code:$c,name:$n,in_tag:$it,out_tag:$ot,host_id:(if $h=="" then null else $h end),core_url:$u,updated_at:now|floor}' \
       "$PANEL_NODE_MAP" > "$tmp" || { rm -f "$tmp"; return 1; }
    mv -f "$tmp" "$PANEL_NODE_MAP"
    chmod 600 "$PANEL_NODE_MAP" 2>/dev/null || true
}

node_process_running() {
    local code="$1" port="$2"
    pgrep -f "node_${code}_${port}\.conf" >/dev/null 2>&1
}

panel_delete_hosts_fallback() {
    local hosts_json="$1" ids_csv="$2" keep ep tmp resp code
    keep=$(jq -c --arg csv "$ids_csv" 'split(",") as $ids | map(select((.id|tostring) as $id | ($ids|index($id)) == null))' <<<"$hosts_json" 2>/dev/null) || return 1
    for ep in /api/hosts /api/admin/hosts; do
        tmp=$(mktemp /tmp/sherlook_hosts.XXXXXX) || continue
        printf '%s\n' "$keep" > "$tmp"
        resp=$(curl -4 -sS -w '\n%{http_code}' -X PUT "$URL$ep" \
            -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -H 'Accept: application/json' \
            -d @"$tmp" 2>/dev/null || true)
        rm -f "$tmp"
        code=$(tail -n1 <<<"$resp")
        [[ "$code" =~ ^2[0-9][0-9]$ ]] && return 0
    done
    return 1
}

panel_delete_nodes() {
    panel_session_ok || { echo -e "${YELLOW}[!] Panel session unavailable.${NC}"; return 2; }
    local -a ids=("$@")
    ((${#ids[@]}>0)) || return 1
    panel_find_core || { echo -e "${RED}[!] Panel core not found.${NC}"; return 1; }

    local core="$PANEL_CORE_JSON" idx code name port safe prefix in_tag out_tag hosts hlen i hid htag hrem
    local -a host_ids=()
    local changed=0

    for idx in "${ids[@]}"; do
        IFS=':' read -r code name port <<< "${NODES[$idx]}"
        in_tag=$(panel_map_get "$idx" in_tag)
        out_tag=$(panel_map_get "$idx" out_tag)
        safe=$(printf '%s' "$name" | tr -d ' ' | tr -cd '[:alnum:]-')
        prefix="${code}-${safe}-"

        if [ -n "$in_tag" ]; then
            core=$(jq -c --arg t "$in_tag" 'if .inbounds then .inbounds=[.inbounds[]|select(.tag!=$t)] else . end' <<<"$core") || return 1
            changed=1
        else
            core=$(jq -c --arg p "$prefix" 'if .inbounds then .inbounds=[.inbounds[]|select(((.tag|type)!="string") or (.tag|startswith($p)|not))] else . end' <<<"$core") || return 1
        fi

        if [ -n "$out_tag" ]; then
            core=$(jq -c --arg t "$out_tag" 'if .outbounds then .outbounds=[.outbounds[]|select(.tag!=$t)] else . end' <<<"$core") || return 1
        else
            core=$(jq -c --arg p "${code}-${safe}-OUT-" 'if .outbounds then .outbounds=[.outbounds[]|select(((.tag|type)!="string") or (.tag|startswith($p)|not))] else . end' <<<"$core") || return 1
        fi
        changed=1

        # Remove both the explicit inbound->outbound rule and any route that references the inbound.
        if [ -n "$in_tag" ] || [ -n "$out_tag" ]; then
            core=$(jq -c --arg it "$in_tag" --arg ot "$out_tag" '
                if .routing.rules then
                    .routing.rules=[.routing.rules[] | select(
                        not(
                            ($ot != "" and (.outboundTag? == $ot)) or
                            ($it != "" and ((.inboundTag? // []) | type == "array") and (((.inboundTag? // []) | index($it)) != null))
                        )
                    )]
                else . end' <<<"$core") || return 1
        fi

        hosts=$(panel_get_hosts)
        hlen=$(jq 'length' <<<"$hosts" 2>/dev/null || echo 0)
        for ((i=0;i<hlen;i++)); do
            hid=$(jq -r ".[$i].id // empty" <<<"$hosts")
            htag=$(jq -r ".[$i].inbound_tag // empty" <<<"$hosts")
            hrem=$(jq -r ".[$i].remark // empty" <<<"$hosts")
            if { [ -n "$in_tag" ] && [ "$htag" = "$in_tag" ]; } || { [ -z "$in_tag" ] && [ "$hrem" = "${EMOJIS[$code]} $name" ]; }; then
                [ -n "$hid" ] && host_ids+=("$hid")
            fi
        done
        panel_map_del "$idx"
    done

    if [ "$changed" -eq 1 ]; then
        panel_save_core "$core" || { echo -e "${RED}[!] Panel core cleanup failed. Local node was NOT deleted by this operation.${NC}"; return 1; }
    fi

    local -A unique=()
    local id
    for id in "${host_ids[@]}"; do unique["$id"]=1; done
    local failed=0
    for id in "${!unique[@]}"; do
        if panel_delete_host "$id"; then
            echo -e "  ${GREEN}✓ Host $id deleted.${NC}"
        else
            failed=1
        fi
    done

    if [ "$failed" -eq 1 ] && ((${#unique[@]}>0)); then
        hosts=$(panel_get_hosts)
        local csv=""
        for id in "${!unique[@]}"; do [ -n "$csv" ] && csv+=','; csv+="$id"; done
        if panel_delete_hosts_fallback "$hosts" "$csv"; then
            echo -e "  ${GREEN}✓ Remaining matching Host records removed using bulk fallback.${NC}"
            failed=0
        fi
    fi

    if [ "$failed" -eq 1 ]; then
        echo -e "${YELLOW}[!] Core resources were deleted, but one or more Host DELETE operations were rejected by the panel API.${NC}"
        return 1
    fi
    echo -e "${GREEN}[+] Panel cleanup completed: Inbound + Outbound + Routing + matching Host(s).${NC}"
}

panel_login() {
    check_root
    draw_header
    mkdir -p "$BASE_DIR"
    chmod 700 "$BASE_DIR"

    if [ -s "$PANEL_CONF" ]; then
        # shellcheck disable=SC1090
        source "$PANEL_CONF" 2>/dev/null || true
        if [ -n "${URL:-}" ] && [ -n "${TOKEN:-}" ]; then
            echo -e "${GREEN}[+] Saved token found for ${WHITE}$URL${NC}"
            read -r -p 'Use saved session? [Y/n]: ' use_saved < /dev/tty || use_saved=y
            if [[ -z "$use_saved" || "${use_saved,,}" == y ]]; then panel_menu; return; fi
        fi
    fi

    local p_url p_user p_pass resp token
    read -r -p 'Panel URL (https://panel.example.com[:port]): ' p_url < /dev/tty || return
    p_url="${p_url%/}"
    [[ "$p_url" =~ ^https?:// ]] || p_url="https://$p_url"
    read -r -p 'Admin username: ' p_user < /dev/tty || return
    read -r -s -p 'Admin password: ' p_pass < /dev/tty || return
    echo

    resp=$(curl -4 -fsS --connect-timeout 8 --max-time 30 -X POST "$p_url/api/admin/token" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode 'grant_type=password' \
        --data-urlencode "username=$p_user" \
        --data-urlencode "password=$p_pass" 2>/dev/null || true)
    token=$(echo "$resp" | jq -r '.access_token // empty' 2>/dev/null || true)
    unset p_pass resp
    [ -n "$token" ] || { echo -e "${RED}[!] Panel login failed.${NC}"; return 1; }

    umask 077
    printf 'URL=%q\nTOKEN=%q\n' "$p_url" "$token" > "$PANEL_CONF"
    chmod 600 "$PANEL_CONF"
    echo -e "${GREEN}[+] Panel session stored securely: token only.${NC}"
    panel_menu
}

logo_draw_header() {
    clear
    echo -e "${MAGENTA} ╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ███████╗██╗  ██╗███████╗██████╗ ██╗      ██████╗  ██████╗ ██╗  ██╗${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ██╔════╝██║  ██║██╔════╝██╔══██╗██║     ██╔═══██╗██╔═══██╗██║ ██╔╝${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ███████╗███████║█████╗  ██████╔╝██║     ██║   ██║██║   ██║█████╔╝ ${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ╚════██║██╔══██║██╔══╝  ██╔══██╗██║     ██║   ██║██║   ██║██╔═██╗ ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ███████║██║  ██║███████╗██║  ██║███████╗╚██████╔╝╚██████╔╝██║  ██╗${MAGENTA} ║${NC}"
    echo -e "${MAGENTA} ║${CYAN}   ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝${MAGENTA} ║${NC}"
    printf '%b\n' "${MAGENTA} ║${YELLOW}              A U T O M A T E   E N G I N E   V ${LOGO_VERSION}${MAGENTA}             ║${NC}"
    echo -e "${MAGENTA} ║${GREEN}          Hardened Health • Auto-Heal • Panel Sync          ${MAGENTA}║${NC}"
    echo -e "${MAGENTA} ╚════════════════════════════════════════════════════════╝${NC}"
    echo
}
draw_header() { logo_draw_header; }
