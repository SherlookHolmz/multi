#!/usr/bin/env bash
# Sherlook Multi v6.2.6
# Standalone bootstrap + pinned engine loader + hardened overrides.
set -euo pipefail

VERSION='6.2.6'
RAW_BASE='https://raw.githubusercontent.com/SherlookHolmz/multi/main'
RAW_WRAPPER_URL="$RAW_BASE/sherlook.sh"
RAW_INSTALLER_URL="$RAW_BASE/install.sh"
BASE_ENGINE_REF='57d99b790d0187765a34ce5f196570f845f652f9'
BASE_ENGINE_URL="https://raw.githubusercontent.com/SherlookHolmz/multi/${BASE_ENGINE_REF}/sherlook.sh"
CACHE_DIR='/root/.sherlook'
BASE_ENGINE="$CACHE_DIR/base-${BASE_ENGINE_REF}.sh"
PATCHED_ENGINE="$CACHE_DIR/sherlook-${VERSION}.sh"
OVERLAY="$CACHE_DIR/overlay-${VERSION}.sh"
LOCK_FILE="$CACHE_DIR/update.lock"
INSTALL_PATH='/usr/local/bin/sherlook'

root_check() {
  [ "${EUID:-$(id -u)}" -eq 0 ] || { echo '[!] Run as root.' >&2; exit 1; }
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "[!] Missing command: $1" >&2; exit 1; }
}

fetch_file() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -4 -fsSL --retry 4 --retry-all-errors --connect-timeout 10 --max-time 120 -o "$out" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url"
  else
    echo '[!] curl or wget is required.' >&2
    return 1
  fi
}

extract_overlay() {
  mkdir -p "$CACHE_DIR"
  awk 'BEGIN{p=0} /^__SHERLOOK_OVERLAY_BEGIN__$/{p=1;next} p{print}' "$0" > "$OVERLAY"
  [ -s "$OVERLAY" ] || { echo '[!] Embedded hardening overlay is missing.' >&2; return 1; }
  chmod 600 "$OVERLAY"
}

patch_engine() {
  local src="$1" out="$PATCHED_ENGINE.tmp"
  python3 - "$src" "$OVERLAY" "$out" "$VERSION" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]); overlay = Path(sys.argv[2]); out = Path(sys.argv[3]); version = sys.argv[4]
text = src.read_text(encoding='utf-8')
over = overlay.read_text(encoding='utf-8')
marker = 'if [ "${1:-}" = "--version" ]; then'
if marker not in text:
    raise SystemExit('[!] Pinned engine entrypoint marker not found; refusing to patch.')
if '__SHERLOOK_626_PATCHED__' not in text:
    text = text.replace(marker, '# __SHERLOOK_626_PATCHED__\n' + over + '\n\n' + marker, 1)
text = text.replace('SHERLOOK_VERSION="6.2.3"', f'SHERLOOK_VERSION="{version}"', 1)
text = text.replace('A U T O M A T E   E N G I N E   V 6 . 1', f'A U T O M A T E   E N G I N E   V {version.replace(".", " . ")}', 1)
out.write_text(text, encoding='utf-8')
PY
  bash -n "$out"
  install -m 755 "$out" "$PATCHED_ENGINE"
  rm -f "$out"
}

ensure_engine() {
  root_check
  need_cmd bash; need_cmd python3; need_cmd jq; need_cmd flock
  mkdir -p "$CACHE_DIR"; chmod 700 "$CACHE_DIR"
  extract_overlay
  exec 9>"$LOCK_FILE"; flock -x 9
  if [ ! -s "$BASE_ENGINE" ] || [ "${SHERLOOK_FORCE_UPDATE:-0}" = 1 ]; then
    local tmp="$CACHE_DIR/base.tmp.$$.sh"
    fetch_file "$BASE_ENGINE_URL" "$tmp"
    bash -n "$tmp"
    install -m 755 "$tmp" "$BASE_ENGINE"
    rm -f "$tmp"
  fi
  patch_engine "$BASE_ENGINE"
  flock -u 9
}

bootstrap_install_if_needed() {
  root_check
  [ -x "$INSTALL_PATH" ] && [ "$(readlink -f "$0" 2>/dev/null || true)" = "$(readlink -f "$INSTALL_PATH" 2>/dev/null || true)" ] && return 0
  [ "${SHERLOOK_NO_BOOTSTRAP:-0}" = 1 ] && return 0
  local tmp
  tmp=$(mktemp /tmp/sherlook-bootstrap.XXXXXX.sh)
  trap 'rm -f "$tmp"' RETURN
  fetch_file "$RAW_INSTALLER_URL" "$tmp"
  bash -n "$tmp"
  SHERLOOK_NO_BOOTSTRAP=1 bash "$tmp"
  rm -f "$tmp"
  exit 0
}

case "${1:-}" in
  --version)
    echo "$VERSION"
    exit 0
    ;;
  --refresh)
    SHERLOOK_FORCE_UPDATE=1 ensure_engine
    echo "[+] Sherlook engine cache refreshed: v$VERSION"
    exit 0
    ;;
  --no-bootstrap)
    shift
    ;;
esac

bootstrap_install_if_needed
ensure_engine
exec "$PATCHED_ENGINE" "$@"

__SHERLOOK_OVERLAY_BEGIN__
# __SHERLOOK_626_PATCHED__
SHERLOOK_VERSION='6.2.6'
LOGO_VERSION='6.2.6'
HEALTH_GEO_TTL=30
PANEL_NODE_MAP="$BASE_DIR/panel_node_map.json"

# ---------- Common helpers ----------
_atomic_write() {
  local dst="$1" mode="${2:-600}" tmp
  tmp=$(mktemp "${dst}.tmp.XXXXXX") || return 1
  cat > "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$dst"
}

parse_panel_selection() {
  local input="$1" token a b n idx
  local -a result=(); declare -A seen=()
  input="${input//[[:space:]]/}"; input="${input//;/,}"
  IFS=',' read -ra parts <<< "$input"
  for token in "${parts[@]}"; do
    [ -z "$token" ] && continue
    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      a=$((10#${BASH_REMATCH[1]})); b=$((10#${BASH_REMATCH[2]}))
      ((a>b)) && { n=$a; a=$b; b=$n; }
      for ((n=a;n<=b;n++)); do
        idx=$(printf '%02d' "$n")
        if [[ -n "${NODES[$idx]:-}" && -z "${seen[$idx]:-}" ]]; then result+=("$idx"); seen[$idx]=1; fi
      done
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      idx=$(printf '%02d' "$((10#$token))")
      if [[ -n "${NODES[$idx]:-}" && -z "${seen[$idx]:-}" ]]; then result+=("$idx"); seen[$idx]=1; fi
    fi
  done
  printf '%s\n' "${result[@]}"
}

node_process_running() {
  local code="$1" port="$2"
  pgrep -f "node_${code}_${port}\.conf" >/dev/null 2>&1
}

node_status_for_ui() {
  local code="$1" port="$2" ip
  [ -f "$BASE_DIR/node_${code}_${port}.conf" ] || { printf '%s\n' NOT_INSTALLED; return; }
  ip=$(get_node_ip "$port" 2>/dev/null || true)
  if is_valid_ipv4 "$ip"; then
    printf '%s\n' ONLINE
  elif node_process_running "$code" "$port"; then
    printf '%s\n' HEALING
  else
    printf '%s\n' DEAD
  fi
}

health_check_node() {
  local code="$1" name="$2" out_port="$3" silent="${4:-1}"
  local conf="$BASE_DIR/node_${code}_${out_port}.conf" data="$DATA_DIR/${code}_${out_port}"
  local ip_file="$data/last_ip.txt" health_ip="$data/health_ip.txt" health_ts="$data/health_checked_at"
  [ -f "$conf" ] || return 0
  acquire_node_lock "$code" "$out_port" || return 3

  local current old expected now ts result bad actual reason seen
  current=$(get_node_ip "$out_port" 2>/dev/null || true)
  if ! is_valid_ipv4 "$current"; then
    rm -f "$health_ip" "$health_ts"
    release_node_lock
    [ "$silent" = 1 ] || echo -e "${RED}[!] $code live SOCKS is unreachable; auto-healing.${NC}"
    rotate_one_node "$code" "$name" "$out_port" "$silent"
    return $?
  fi

  old=''; [ -s "$ip_file" ] && old=$(head -n1 "$ip_file" | tr -d '\r\n')
  ts=0; [ -s "$health_ts" ] && ts=$(cat "$health_ts" 2>/dev/null || echo 0)
  now=$(date +%s)
  expected=$(node_route_code "$code" "$out_port")

  if [ "$current" != "$old" ] || [ "$current" != "$(cat "$health_ip" 2>/dev/null || true)" ] || [ $((now-ts)) -ge "$HEALTH_GEO_TTL" ]; then
    result=$(check_ip_quality "$current" "$expected")
    IFS='|' read -r bad actual reason seen <<< "$result"
    if [ "$bad" != 0 ]; then
      append_bad_ip "$data/bad_exits.txt" "$current"
      rm -f "$health_ip" "$health_ts"
      release_node_lock
      [ "$silent" = 1 ] || echo -e "${RED}[!] $code live validation failed: $reason (detected=${seen:-unknown}, expected=$expected). Rotating.${NC}"
      rotate_one_node "$code" "$name" "$out_port" "$silent"
      return $?
    fi
    printf '%s\n' "$current" > "$ip_file"
  fi
  printf '%s\n' "$current" > "$health_ip"
  printf '%s\n' "$now" > "$health_ts"
  release_node_lock
  return 0
}

background_auto_heal() {
  check_root
  sync_dynamic_locations
  local idx details code name port running=0
  local -a pids=()
  for idx in "${ORDER[@]}"; do
    details="${NODES[$idx]}"; IFS=':' read -r code name port <<< "$details"
    [ -f "$BASE_DIR/node_${code}_${port}.conf" ] || continue
    health_check_node "$code" "$name" "$port" 1 &
    pids+=("$!"); running=$((running+1))
    if ((running >= AUTO_HEAL_PARALLEL)); then
      wait "${pids[0]}" 2>/dev/null || true
      pids=("${pids[@]:1}"); running=$((running-1))
    fi
  done
  local p; for p in "${pids[@]}"; do wait "$p" 2>/dev/null || true; done
}

# ---------- Header / status consistency ----------
draw_header() {
  clear
  echo -e "${MAGENTA} ╔════════════════════════════════════════════════════════╗${NC}"
  echo -e "${MAGENTA} ║${CYAN}   ███████╗██╗  ██╗███████╗██████╗ ██╗      ██████╗  ██████╗ ██╗  ██╗${MAGENTA} ║${NC}"
  echo -e "${MAGENTA} ║${CYAN}   ██╔════╝██║  ██║██╔════╝██╔══██╗██║     ██╔═══██╗██╔═══██╗██║ ██╔╝${MAGENTA} ║${NC}"
  echo -e "${MAGENTA} ║${CYAN}   ███████╗███████║█████╗  ██████╔╝██║     ██║   ██║██║   ██║█████╔╝ ${MAGENTA} ║${NC}"
  echo -e "${MAGENTA} ║${CYAN}   ╚════██║██╔══██║██╔══╝  ██╔══██╗██║     ██║   ██║██║   ██║██╔═██╗ ${MAGENTA} ║${NC}"
  echo -e "${MAGENTA} ║${CYAN}   ███████║██║  ██║███████╗██║  ██║███████╗╚██████╔╝╚██████╔╝██║  ██╗${MAGENTA} ║${NC}"
  echo -e "${MAGENTA} ║${CYAN}   ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝${MAGENTA} ║${NC}"
  printf '%b\n' "${MAGENTA} ║${YELLOW}              A U T O M A T E   E N G I N E   V ${LOGO_VERSION}${MAGENTA}             ║${NC}"
  echo -e "${MAGENTA} ║${GREEN}          Hardened Health • Auto-Heal • Panel Sync          ${MAGENTA}║${NC}"
  echo -e "${MAGENTA} ╚════════════════════════════════════════════════════════╝${NC}\n"
}

view_active_nodes() {
  check_root
  while true; do
    draw_header
    echo -e "${CYAN}» Unified Active Nodes Monitor${NC}"
    printf '  %-4s %-4s %-22s %-8s %-10s %-16s\n' ID CC Location TorPort Status LiveIP
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    local idx code name port st ip
    for idx in "${ORDER[@]}"; do
      IFS=':' read -r code name port <<< "${NODES[$idx]}"
      [ -f "$BASE_DIR/node_${code}_${port}.conf" ] || continue
      st=$(node_status_for_ui "$code" "$port"); ip=$(get_node_ip "$port" 2>/dev/null || echo '—')
      case "$st" in
        ONLINE) printf '  %-4s %-4s %-22s %-8s %b %-16s\n' "$idx" "$code" "$name" "$port" "${GREEN}ONLINE${NC}" "$ip" ;;
        HEALING) printf '  %-4s %-4s %-22s %-8s %b %-16s\n' "$idx" "$code" "$name" "$port" "${YELLOW}HEALING${NC}" "$ip" ;;
        *) printf '  %-4s %-4s %-22s %-8s %b %-16s\n' "$idx" "$code" "$name" "$port" "${RED}DEAD${NC}" "$ip" ;;
      esac
    done
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────${NC}"
    read -r -t 3 -n 1 -s key < /dev/tty && break || true
  done
}

# ---------- Panel mapping ----------
panel_map_init() {
  mkdir -p "$BASE_DIR"; chmod 700 "$BASE_DIR"
  [ -s "$PANEL_NODE_MAP" ] || printf '{}\n' > "$PANEL_NODE_MAP"
  jq -e 'type=="object"' "$PANEL_NODE_MAP" >/dev/null 2>&1 || printf '{}\n' > "$PANEL_NODE_MAP"
  chmod 600 "$PANEL_NODE_MAP"
}

panel_map_get() {
  local idx="$1" field="$2"; panel_map_init
  jq -r --arg i "$idx" --arg f "$field" '.[$i][$f] // empty' "$PANEL_NODE_MAP" 2>/dev/null || true
}

panel_map_set() {
  local idx="$1" code="$2" name="$3" in_tag="$4" out_tag="$5" host_id="$6" core_url="$7"
  panel_map_init; local tmp
  tmp=$(mktemp "$PANEL_NODE_MAP.tmp.XXXXXX")
  jq --arg i "$idx" --arg c "$code" --arg n "$name" --arg it "$in_tag" --arg ot "$out_tag" --arg h "$host_id" --arg u "$core_url" \
    '.[$i]={code:$c,name:$n,in_tag:$it,out_tag:$ot,host_id:(if $h=="" then null else $h end),core_url:$u,updated_at:now|floor}' \
    "$PANEL_NODE_MAP" > "$tmp"
  chmod 600 "$tmp"; mv -f "$tmp" "$PANEL_NODE_MAP"
}

panel_map_del() {
  local idx="$1"; panel_map_init; local tmp; tmp=$(mktemp "$PANEL_NODE_MAP.tmp.XXXXXX")
  jq --arg i "$idx" 'del(.[$i])' "$PANEL_NODE_MAP" > "$tmp" && chmod 600 "$tmp" && mv -f "$tmp" "$PANEL_NODE_MAP"
}

panel_mapping_valid() {
  local idx="$1" core="$2" it ot hid
  it=$(panel_map_get "$idx" in_tag); ot=$(panel_map_get "$idx" out_tag); hid=$(panel_map_get "$idx" host_id)
  [ -n "$it" ] && [ -n "$ot" ] || return 1
  jq -e --arg t "$it" '.inbounds[]? | select(.tag==$t)' <<< "$core" >/dev/null 2>&1 || return 1
  jq -e --arg t "$ot" '.outbounds[]? | select(.tag==$t)' <<< "$core" >/dev/null 2>&1 || return 1
  if [ -n "$hid" ]; then
    panel_get_hosts | jq -e --arg i "$hid" '.[]? | select((.id|tostring)==$i)' >/dev/null 2>&1 || return 1
  fi
  return 0
}

# ---------- Panel API helpers ----------
panel_get_hosts() {
  local raw
  raw=$(curl -4 -fsS --max-time 20 -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' "$URL/api/hosts" 2>/dev/null || true)
  if echo "$raw" | jq -e 'type=="array"' >/dev/null 2>&1; then printf '%s\n' "$raw"; else echo "$raw" | jq -c '.data // []' 2>/dev/null || echo '[]'; fi
}

panel_find_core() {
  PANEL_CORE_URL=''; PANEL_CORE_RAW=''; PANEL_CORE_JSON=''
  local ep resp id got
  local -a eps=(/api/admin/cores /api/cores /api/core /api/node/cores /api/admin/core)
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
  raw_obj=$(printf '%s' "$PANEL_CORE_RAW" | jq -c 'if type=="object" and has("data") then .data else . end' 2>/dev/null || true)
  [ -n "$raw_obj" ] || raw_obj='{}'
  payload=$(printf '%s' "$raw_obj" | jq --argjson cfg "$cfg" 'if .config!=null then .config=$cfg elif .xray_config!=null then .xray_config=$cfg elif .content!=null then .content=$cfg else .config=$cfg end')
  tmp=$(mktemp); printf '%s\n' "$payload" > "$tmp"
  resp=$(curl -4 -sS -w '\n%{http_code}' -X PUT "$PANEL_CORE_URL?restart_nodes=true" --max-time 30 \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -H 'Accept: application/json' -d @"$tmp" 2>/dev/null || true)
  rm -f "$tmp"; code=$(tail -n1 <<<"$resp"); [[ "$code" =~ ^2[0-9][0-9]$ ]]
}

panel_delete_host() {
  local id="$1" path resp code
  [ -n "$id" ] || return 1
  for path in /api/hosts/$id /api/host/$id /api/admin/hosts/$id /api/admin/host/$id; do
    resp=$(curl -4 -sS -w '\n%{http_code}' -X DELETE "$URL$path" -H "Authorization: Bearer $TOKEN" 2>/dev/null || true)
    code=$(tail -n1 <<<"$resp")
    [[ "$code" =~ ^2[0-9][0-9]$ ]] && return 0
  done
  return 1
}

panel_delete_hosts_fallback() {
  local hosts_json="$1" ids_csv="$2" keep ep tmp resp code
  keep=$(jq -c --arg csv "$ids_csv" '($csv|split(",")) as $ids | map(select((.id|tostring) as $id | ($ids|index($id)) == null))' <<< "$hosts_json") || return 1
  for ep in /api/hosts /api/admin/hosts; do
    tmp=$(mktemp); printf '%s\n' "$keep" > "$tmp"
    resp=$(curl -4 -sS -w '\n%{http_code}' -X PUT "$URL$ep" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d @"$tmp" 2>/dev/null || true)
    rm -f "$tmp"; code=$(tail -n1 <<<"$resp")
    [[ "$code" =~ ^2[0-9][0-9]$ ]] && return 0
  done
  return 1
}

panel_delete_nodes() {
  panel_session_ok || return 2
  local -a ids=("$@"); ((${#ids[@]}>0)) || return 1
  panel_find_core || return 1
  local core="$PANEL_CORE_JSON" idx code name port safe in_tag out_tag hosts hlen i hid htag hrem
  local -a host_ids=()
  for idx in "${ids[@]}"; do
    IFS=':' read -r code name port <<< "${NODES[$idx]}"
    in_tag=$(panel_map_get "$idx" in_tag); out_tag=$(panel_map_get "$idx" out_tag)
    safe=$(printf '%s' "$name" | tr -d ' ' | tr -cd '[:alnum:]-')
    if [ -n "$in_tag" ]; then
      core=$(jq -c --arg t "$in_tag" '.inbounds |= map(select(.tag != $t))' <<< "$core") || return 1
    else
      core=$(jq -c --arg p "${code}-${safe}-" 'if .inbounds then .inbounds |= map(select(((.tag|type)!="string") or (.tag|startswith($p)|not))) else . end' <<< "$core") || return 1
    fi
    if [ -n "$out_tag" ]; then
      core=$(jq -c --arg t "$out_tag" '.outbounds |= map(select(.tag != $t))' <<< "$core") || return 1
    else
      core=$(jq -c --arg p "${code}-${safe}-OUT-" 'if .outbounds then .outbounds |= map(select(((.tag|type)!="string") or (.tag|startswith($p)|not))) else . end' <<< "$core") || return 1
    fi
    core=$(jq -c --arg it "$in_tag" --arg ot "$out_tag" '
      if .routing.rules then .routing.rules |= map(select(not(($ot!="" and .outboundTag?==$ot) or ($it!="" and ((.inboundTag?//[])|type)=="array" and (((.inboundTag?//[])|index($it))!=null))))) else . end' <<< "$core") || return 1
    hosts=$(panel_get_hosts); hlen=$(jq 'length' <<< "$hosts" 2>/dev/null || echo 0)
    for ((i=0;i<hlen;i++)); do
      hid=$(jq -r ".[$i].id // empty" <<< "$hosts"); htag=$(jq -r ".[$i].inbound_tag // empty" <<< "$hosts"); hrem=$(jq -r ".[$i].remark // empty" <<< "$hosts")
      if { [ -n "$in_tag" ] && [ "$htag" = "$in_tag" ]; } || { [ -z "$in_tag" ] && [ "$hrem" = "${EMOJIS[$code]} $name" ]; }; then
        [ -n "$hid" ] && host_ids+=("$hid")
      fi
    done
    panel_map_del "$idx"
  done
  panel_save_core "$core" || return 1
  local -A unique=(); local id failed=0
  for id in "${host_ids[@]}"; do unique["$id"]=1; done
  for id in "${!unique[@]}"; do panel_delete_host "$id" || failed=1; done
  if [ "$failed" -eq 1 ] && ((${#unique[@]}>0)); then
    hosts=$(panel_get_hosts); local csv=''
    for id in "${!unique[@]}"; do [ -n "$csv" ] && csv+=','; csv+="$id"; done
    panel_delete_hosts_fallback "$hosts" "$csv" && failed=0 || true
  fi
  [ "$failed" -eq 0 ]
}

panel_select_template() {
  panel_find_core || return 1
  local i count tag port proto net sec sel real hosts hcount htag rem addr hp hsel
  count=$(jq '.inbounds|length' <<< "$PANEL_CORE_JSON" 2>/dev/null || echo 0)
  ((count>0)) || return 1
  echo -e "${MAGENTA}[ SELECT INBOUND TEMPLATE ]${NC}"
  for ((i=0;i<count;i++)); do
    tag=$(jq -r ".inbounds[$i].tag // \"\"" <<< "$PANEL_CORE_JSON")
    port=$(jq -r ".inbounds[$i].port // \"\"" <<< "$PANEL_CORE_JSON")
    proto=$(jq -r ".inbounds[$i].protocol // \"\"" <<< "$PANEL_CORE_JSON")
    net=$(jq -r ".inbounds[$i] | if .streamSettings.network then .streamSettings.network elif .settings.network then .settings.network else \"tcp\" end" <<< "$PANEL_CORE_JSON")
    sec=$(jq -r ".inbounds[$i] | if .streamSettings.security then .streamSettings.security else \"none\" end" <<< "$PANEL_CORE_JSON")
    printf '  [%d] %-7s %-12s %-8s %-9s %s\n' "$((i+1))" "$port" "$proto" "$net" "$sec" "$tag"
  done
  read -r -p 'Select inbound template: ' sel < /dev/tty || return 1
  [[ "$sel" =~ ^[0-9]+$ ]] && ((sel>=1&&sel<=count)) || return 1
  PANEL_CLONE_INBOUND_JSON=$(jq -c ".inbounds[$((sel-1))]" <<< "$PANEL_CORE_JSON")
  hosts=$(panel_get_hosts); hcount=$(jq 'length' <<< "$hosts" 2>/dev/null || echo 0)
  PANEL_CLONE_HOST_JSON='{}'; PANEL_CLONED_SNI=''
  if ((hcount>0)); then
    echo -e "${MAGENTA}[ SELECT HOST TEMPLATE ]${NC}"
    for ((i=0;i<hcount;i++)); do
      htag=$(jq -r ".[$i].inbound_tag // \"\"" <<< "$hosts"); rem=$(jq -r ".[$i].remark // \"\"" <<< "$hosts"); addr=$(jq -r ".[$i].address | if type==\"array\" and length>0 then .[0] elif type==\"string\" then . else \"\" end" <<< "$hosts"); hp=$(jq -r ".[$i].port // \"\"" <<< "$hosts")
      printf '  [%d] %-22s %-28s %-25s %s\n' "$((i+1))" "$htag" "$rem" "$addr" "$hp"
    done
    read -r -p 'Select host template (0=skip): ' hsel < /dev/tty || hsel=0
    if [[ "$hsel" =~ ^[0-9]+$ ]] && ((hsel>0&&hsel<=hcount)); then
      PANEL_CLONE_HOST_JSON=$(jq -c ".[$((hsel-1))]" <<< "$hosts")
      PANEL_CLONED_SNI=$(jq -r '.address | if type=="array" and length>0 then .[0] elif type=="string" then . else "" end' <<< "$PANEL_CLONE_HOST_JSON")
    fi
  fi
}

panel_sync_selected_nodes() {
  panel_session_ok || return 2
  local -a ids=("$@"); ((${#ids[@]}>0)) || return 1
  panel_select_template || return 1
  local core="$PANEL_CORE_JSON" idx code name port safe in_tag out_tag in_port host_json item map_id exists
  local -a made=()
  for idx in "${ids[@]}"; do
    IFS=':' read -r code name port <<< "${NODES[$idx]}"
    if panel_mapping_valid "$idx" "$core"; then
      echo -e "${YELLOW}[!] [$idx] valid panel mapping already exists; skipping.${NC}"
      continue
    fi
    panel_map_del "$idx"
    safe=$(printf '%s' "$name" | tr -d ' ' | tr -cd '[:alnum:]-')
    while :; do
      in_port=$((RANDOM%6000+3000)); in_tag="${code}-${safe}-IN-${in_port}"; out_tag="${code}-${safe}-OUT-${port}"
      exists=$(jq -e --arg t "$in_tag" '.inbounds[]?|select(.tag==$t)' <<< "$core" >/dev/null 2>&1 && echo 1 || echo 0)
      [ "$exists" = 0 ] && break
    done
    core=$(jq -c --arg t "$in_tag" --arg p "$in_port" --argjson obj "$PANEL_CLONE_INBOUND_JSON" 'if .inbounds==null then .inbounds=[] else . end | .inbounds += [($obj|.port=($p|tonumber)|.tag=$t)]' <<< "$core")
    core=$(jq -c --arg t "$out_tag" --arg p "$port" 'if .outbounds==null then .outbounds=[] else . end | .outbounds += [{tag:$t,protocol:"socks",settings:{servers:[{address:"127.0.0.1",port:($p|tonumber)}]}}]' <<< "$core")
    core=$(jq -c --arg i "$in_tag" --arg o "$out_tag" 'if .routing==null then .routing={rules:[]} elif .routing.rules==null then .routing.rules=[] else . end | .routing.rules += [{type:"field",inboundTag:[$i],outboundTag:$o}]' <<< "$core")
    host_json='{}'
    if [ "$PANEL_CLONE_HOST_JSON" != '{}' ]; then
      host_json=$(jq -c --arg t "$in_tag" --arg p "$in_port" --arg r "${EMOJIS[$code]} $name" --argjson obj "$PANEL_CLONE_HOST_JSON" '$obj|.inbound_tag=$t|.port=($p|tonumber)|.remark=$r|.enable=1|del(.id,.created_at,.updated_at)')
    elif [ -n "$PANEL_CLONED_SNI" ]; then
      host_json=$(jq -nc --arg t "$in_tag" --arg p "$in_port" --arg r "${EMOJIS[$code]} $name" --arg a "$PANEL_CLONED_SNI" '{inbound_tag:$t,remark:$r,address:[$a],port:($p|tonumber),enable:1}')
    fi
    made+=("$idx|$code|$name|$in_tag|$out_tag|$host_json")
  done
  ((${#made[@]}>0)) || return 0
  panel_save_core "$core" || { echo -e "${RED}[!] Core upload failed; local nodes were not altered.${NC}"; return 1; }
  for item in "${made[@]}"; do
    IFS='|' read -r idx code name in_tag out_tag host_json <<< "$item"
    map_id=''
    if [ "$host_json" != '{}' ]; then
      local ep hr hc
      for ep in /api/host /api/hosts /api/admin/host /api/admin/hosts; do
        hr=$(curl -4 -sS -w '\n%{http_code}' -X POST "$URL$ep" -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d "$host_json" 2>/dev/null || true)
        hc=$(tail -n1 <<< "$hr")
        if [[ "$hc" =~ ^2[0-9][0-9]$ || "$hc" == 409 ]]; then map_id=$(head -n -1 <<< "$hr" | jq -r '.id // .data.id // empty' 2>/dev/null | head -n1); break; fi
      done
    fi
    panel_map_set "$idx" "$code" "$name" "$in_tag" "$out_tag" "$map_id" "$PANEL_CORE_URL"
  done
  echo -e "${GREEN}[+] Panel mapping committed for ${#made[@]} node(s).${NC}"
}

install_and_panel_sync() {
  local -a ids=("$@"); ((${#ids[@]}>0)) || return 1
  local idx code name port answer='n' ; local -a ready=()
  if panel_session_ok; then read -r -p 'Also add successful nodes to Panel? [Y/n]: ' answer < /dev/tty || answer=y; fi
  for idx in "${ids[@]}"; do
    IFS=':' read -r code name port <<< "${NODES[$idx]}"
    if node_has_record "$code" "$port"; then
      ready+=("$idx"); continue
    fi
    deploy_node "$code" "$name" "$port" || true
    node_has_record "$code" "$port" && ready+=("$idx")
  done
  if [[ "${answer,,}" == y || "${answer,,}" == yes || -z "$answer" ]]; then
    ((${#ready[@]}>0)) && panel_sync_selected_nodes "${ready[@]}"
  fi
}

panel_batch_create() {
  panel_session_ok || { echo -e "${YELLOW}[!] Connect to Panel first via option 9.${NC}"; return; }
  draw_header; list_locations
  local raw; read -r -p 'Node IDs to INSTALL+ADD (e.g. 1-21, 1,3,7-12): ' raw < /dev/tty || return
  local -a ids=(); mapfile -t ids < <(parse_panel_selection "$raw"); ((${#ids[@]}>0)) || return
  install_and_panel_sync "${ids[@]}"
  read -r -p 'Press Enter...' < /dev/tty || true
}

panel_session_ok() {
  [ -s "$PANEL_CONF" ] || return 1
  # shellcheck disable=SC1090
  source "$PANEL_CONF" 2>/dev/null || return 1
  [ -n "${URL:-}" ] && [ -n "${TOKEN:-}" ]
}

panel_login() {
  check_root; draw_header; mkdir -p "$BASE_DIR"; chmod 700 "$BASE_DIR"
  if [ -s "$PANEL_CONF" ]; then
    source "$PANEL_CONF" 2>/dev/null || true
    if [ -n "${URL:-}" ] && [ -n "${TOKEN:-}" ]; then
      echo -e "${GREEN}[+] Saved token found for $URL${NC}"
      read -r -p 'Use saved session? [Y/n]: ' use < /dev/tty || use=y
      if [[ -z "$use" || "${use,,}" == y ]]; then panel_menu; return; fi
    fi
  fi
  local p_url p_user p_pass resp token
  read -r -p 'Panel URL: ' p_url < /dev/tty || return
  p_url="${p_url%/}"; [[ "$p_url" =~ ^https?:// ]] || p_url="https://$p_url"
  read -r -p 'Admin username: ' p_user < /dev/tty || return
  read -r -s -p 'Admin password: ' p_pass < /dev/tty || return; echo
  resp=$(curl -4 -fsS --connect-timeout 8 --max-time 30 -X POST "$p_url/api/admin/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' \
    --data-urlencode "username=$p_user" --data-urlencode "password=$p_pass" 2>/dev/null || true)
  token=$(echo "$resp" | jq -r '.access_token // empty' 2>/dev/null || true)
  unset p_pass resp
  [ -n "$token" ] || { echo -e "${RED}[!] Panel login failed.${NC}"; return 1; }
  umask 077
  printf 'URL=%q\nTOKEN=%q\n' "$p_url" "$token" > "$PANEL_CONF"
  chmod 600 "$PANEL_CONF"
  echo -e "${GREEN}[+] Token stored securely (password is not stored).${NC}"
  panel_menu
}

panel_menu() {
  while true; do
    draw_header
    echo -e "${MAGENTA}[ PANEL NEXATIS / PASARGUARD INTEGRATION ]${NC}"
    echo '1) Install + Add (single/bulk)'; echo '2) Add already-installed node(s)'; echo '3) Delete node(s) from Panel'; echo '4) Inspect core'; echo '5) Logout'; echo '0) Back'
    local op raw
    read -r -p 'Option: ' op < /dev/tty || return
    case "$op" in
      1) panel_batch_create ;;
      2) list_locations; read -r -p 'Installed node IDs: ' raw < /dev/tty || continue; mapfile -t ids < <(parse_panel_selection "$raw"); ((${#ids[@]}>0)) && panel_sync_selected_nodes "${ids[@]}" ;;
      3) list_locations; read -r -p 'Delete Panel resources (e.g. 1-21): ' raw < /dev/tty || continue; mapfile -t ids < <(parse_panel_selection "$raw"); ((${#ids[@]}>0)) && panel_delete_nodes "${ids[@]}" || echo -e "${RED}[!] Panel cleanup failed; local node was not touched by this action.${NC}" ;;
      4) panel_find_core && echo -e "${GREEN}[+] Core endpoint: $PANEL_CORE_URL${NC}" || echo -e "${RED}[!] Core not found.${NC}"; read -r -p 'Press Enter...' < /dev/tty || true ;;
      5) rm -f "$PANEL_CONF"; return ;;
      0) return ;;
    esac
  done
}

# ---------- Maintenance safety: preserve local node if panel deletion fails ----------
edit_delete_nodes() {
  check_root
  while true; do
    draw_header
    echo -e "${MAGENTA}[ NODE MAINTENANCE / AUTO-REPAIR ]${NC}"
    local idx code name port st; local -a active=()
    for idx in "${ORDER[@]}"; do
      IFS=':' read -r code name port <<< "${NODES[$idx]}"
      [ -f "$BASE_DIR/node_${code}_${port}.conf" ] || continue
      active+=("$idx"); st=$(node_status_for_ui "$code" "$port")
      printf '  [%s] %-20s %-8s %s\n' "$idx" "$name" "$port" "$st"
    done
    echo '1) Repair/Rebuild selected'; echo '2) Delete selected (LOCAL + PANEL)'; echo '3) Auto-repair all DEAD/HEALING'; echo '4) Refresh'; echo '0) Back'
    local action raw; read -r -p 'Action: ' action < /dev/tty || return
    case "$action" in
      1) read -r -p 'Node IDs: ' raw < /dev/tty || continue; mapfile -t selected < <(parse_panel_selection "$raw"); for idx in "${selected[@]}"; do IFS=':' read -r code name port <<< "${NODES[$idx]}"; [ -f "$BASE_DIR/node_${code}_${port}.conf" ] && rotate_one_node "$code" "$name" "$port" 0 & done; wait || true ;;
      2)
        read -r -p 'Node IDs: ' raw < /dev/tty || continue; mapfile -t selected < <(parse_panel_selection "$raw"); ((${#selected[@]}>0)) || continue
        local cp='n'; if panel_session_ok; then read -r -p 'Delete Panel Host + Inbound + Outbound + Routing too? [Y/n]: ' cp < /dev/tty || cp=n; fi
        if [[ "${cp,,}" == y || "${cp,,}" == yes ]]; then
          if ! panel_delete_nodes "${selected[@]}"; then echo -e "${RED}[!] Panel cleanup failed; LOCAL deletion cancelled for safety.${NC}"; read -r -p 'Press Enter...' < /dev/tty || true; continue; fi
        fi
        for idx in "${selected[@]}"; do IFS=':' read -r code name port <<< "${NODES[$idx]}"; pkill -9 -f "node_${code}_${port}\.conf" 2>/dev/null || true; rm -f "$BASE_DIR/node_${code}_${port}.conf"; rm -rf "$DATA_DIR/${code}_${port}"; panel_map_del "$idx"; done
        echo -e "${GREEN}[+] Selected node(s) removed.${NC}" ;;
      3)
        for idx in "${active[@]}"; do IFS=':' read -r code name port <<< "${NODES[$idx]}"; st=$(node_status_for_ui "$code" "$port"); [ "$st" = ONLINE ] || rotate_one_node "$code" "$name" "$port" 1 & done; wait || true ;;
      4) ;;
      0) return ;;
    esac
  done
}

# ---------- Non-blocking update ----------
update_system() {
  check_root; draw_header
  echo -e "${CYAN}[*] Sherlook Update — current v${VERSION}${NC}"
  local tmp wraptmp remote_version backup target_new
  tmp=$(mktemp /tmp/sherlook-update.XXXXXX.sh); wraptmp=$(mktemp /tmp/sherlook-installer-update.XXXXXX.sh)
  trap 'rm -f "$tmp" "$wraptmp"' RETURN
  fetch_file "$RAW_WRAPPER_URL" "$tmp"
  bash -n "$tmp"
  grep -q "VERSION='6\.2\.6'\|VERSION=\"6\.2\.6\"" "$tmp" || { echo -e "${RED}[!] Remote wrapper is not v6.2.6; refusing update.${NC}"; return 1; }
  fetch_file "$RAW_INSTALLER_URL" "$wraptmp"; bash -n "$wraptmp"
  remote_version=$(grep -m1 -E "^VERSION=['\"]" "$tmp" | sed -E "s/^VERSION=['\"]([^'\"]+).*/\1/")
  echo -e "${GREEN}[+] Remote version: $remote_version${NC}"
  mkdir -p "$BASE_DIR" "$CACHE_DIR"
  backup="$BASE_DIR/sherlook.sh.bak.$(date +%Y%m%d_%H%M%S)"
  [ -f "$INSTALL_PATH" ] && cp -a "$INSTALL_PATH" "$backup"
  install -m 755 "$tmp" "$INSTALL_PATH.new"; mv -f "$INSTALL_PATH.new" "$INSTALL_PATH"
  install -m 755 "$tmp" "$CACHE_DIR/sherlook.sh"
  install -m 755 "$wraptmp" "$CACHE_DIR/install.sh"
  install -m 755 "$wraptmp" /usr/local/bin/sherlook-install
  systemctl daemon-reload 2>/dev/null || true
  systemctl restart sherlook-heal.service --no-block 2>/dev/null || true
  echo -e "${GREEN}[+] Update installed atomically. Backup: $backup${NC}"
  echo -e "${YELLOW}[*] Health service restart queued asynchronously; UI is not blocked.${NC}"
  exec "$INSTALL_PATH"
}

# Version dispatch remains below all overrides.
