#!/usr/bin/env bash
# Sherlook Automate Engine v6.3.1
set -euo pipefail
VERSION="6.3.1"
RAW_URL="https://raw.githubusercontent.com/SherlookHolmz/multi/1f53d18d5cc80ceaf21a093b75fd1133432e5f84/sherlook.sh"
CACHE_DIR="/var/lib/tor/sherlook_nodes"
CACHE_FILE="$CACHE_DIR/.sherlook-base.sh"
PATCHED_FILE="$CACHE_DIR/.sherlook-engine-${VERSION}.sh"
fail(){ printf '[Sherlook %s] ERROR: %s\n' "$VERSION" "$*" >&2; exit 1; }
mkdir -p "$CACHE_DIR"
fetch_base(){
  local tmp; tmp=$(mktemp "${CACHE_DIR}/base.XXXXXX")
  if curl -4 -fL --retry 8 --retry-all-errors --retry-delay 2 --connect-timeout 8 --max-time 120 -sS -o "$tmp" "$RAW_URL"; then
    if head -n1 "$tmp" | grep -q '^#!'; then install -m 755 "$tmp" "$CACHE_FILE"; rm -f "$tmp"; return 0; fi
  fi
  rm -f "$tmp"; [ -s "$CACHE_FILE" ] && return 0
  fail "unable to obtain Sherlook base engine and no cached engine is available"
}
pm_build_patch(){
python3 - "$CACHE_FILE" "$PATCHED_FILE" <<'PY'
import re,sys
src,out=sys.argv[1:]
s=open(src,encoding='utf-8').read()
s=re.sub(r'^SHERLOOK_VERSION="[^"]+"$','SHERLOOK_VERSION="6.3.1"',s,flags=re.M)
s=re.sub(r'^RAW_INSTALLER_URL=.*$','RAW_INSTALLER_URL="$RAW_BASE/install-sherlook"',s,flags=re.M)
s=re.sub(r'^LOCATION_CACHE_TTL=\d+$','LOCATION_CACHE_TTL=1800',s,flags=re.M)
s=re.sub(r'^AUTO_HEAL_INTERVAL=\d+$','AUTO_HEAL_INTERVAL=5',s,flags=re.M)
s=re.sub(r'^AUTO_HEAL_PARALLEL=\d+$','AUTO_HEAL_PARALLEL=12',s,flags=re.M)
s=re.sub(r'^NODE_ROTATE_RETRIES=\d+$','NODE_ROTATE_RETRIES=10',s,flags=re.M)
s=s.replace('A U T O M A T E   E N G I N E   V 6 . 1','A U T O M A T E   E N G I N E   V 6 . 3 . 1')

# --- FIX #1 (crash): the anchor variable used below must be the one that was
# actually assigned above. The old patch built `pre` but then referenced the
# never-defined `pre_marker`, so this heredoc raised NameError on every single
# run and the wrapper aborted immediately (nothing downstream ever executed).
pre_marker = 'if [ "${1:-}" = "--version" ]; then'
if pre_marker not in s: raise SystemExit('entrypoint anchor missing')

core=r'''
# ===== 6.3.1 CANONICAL STATE + TOR EXIT CATALOG =====
declare -A SHERLOOK_EXIT_AVAILABLE=()
declare -a LOCATION_ORDER=()
write_node_state(){ local c="$1" p="$2" st="$3" ip="${4:-}" rs="${5:-}" d="$DATA_DIR/${c}_${p}"; mkdir -p "$d"; printf 'state=%s\nip=%s\nreason=%s\nupdated=%s\n' "$st" "$ip" "$rs" "$(date +%s)" > "$d/state.env"; }
read_node_state(){ local c="$1" p="$2" f="$DATA_DIR/${c}_${p}/state.env" v=""; [ -s "$f" ] && v=$(awk -F= '$1=="state"{print $2;exit}' "$f" 2>/dev/null || true); [ -n "$v" ] && printf '%s\n' "$v" || { [ -f "$BASE_DIR/node_${c}_${p}.conf" ] && printf 'DEAD\n' || printf 'STOPPED\n'; }; }
read_node_ip_state(){ local c="$1" p="$2" v=""; v=$(awk -F= '$1=="ip"{print $2;exit}' "$DATA_DIR/${c}_${p}/state.env" 2>/dev/null || true); if is_valid_ipv4 "$v"; then printf '%s\n' "$v"; return 0; fi; v=$(head -n1 "$DATA_DIR/${c}_${p}/last_ip.txt" 2>/dev/null|tr -d '\r\n'||true); is_valid_ipv4 "$v" && printf '%s\n' "$v"; }
# FIX #2 (state/UI mismatch): the old version only cross-checked the live
# process when the *cached* state was already ONLINE, so a node stuck on
# HEALING/STARTING (e.g. a rotation that got interrupted) stayed HEALING
# forever, while other menus that stat the .conf file directly reported DEAD
# for the exact same node. The process check now runs unconditionally, so
# every menu (delete list, IP-rotation list, live table) shows the same,
# truthful status.
status_for_menu(){ local c="$1" p="$2" st; st=$(read_node_state "$c" "$p"); if [ "$st" = STOPPED ]; then echo "$st"; return 0; fi; if [ -f "$BASE_DIR/node_${c}_${p}.conf" ] && ! node_process_running "$c" "$p"; then echo DEAD; else echo "$st"; fi; }
eval "$(declare -f rotate_one_node_core | sed '1s/^rotate_one_node_core /legacy_rotate_one_node_core /')"
rotate_one_node_core(){ local c="$1" n="$2" p="$3" s="${4:-0}"; local d="$DATA_DIR/${c}_${p}" ipf="$d/last_ip.txt"; write_node_state "$c" "$p" HEALING "$(read_node_ip_state "$c" "$p"||true)" rotation-start; if [ -f "$BASE_DIR/node_${c}_${p}.conf" ] && ! node_process_running "$c" "$p"; then run_tor_node "$BASE_DIR/node_${c}_${p}.conf"; sleep 3; fi; legacy_rotate_one_node_core "$c" "$n" "$p" "$s"; local rc=$? ip=""; [ -s "$ipf" ]&&ip=$(head -n1 "$ipf"|tr -d '\r\n'); if [ "$rc" = 0 ]&&is_valid_ipv4 "$ip"; then write_node_state "$c" "$p" ONLINE "$ip" verified; else rm -f "$ipf"; write_node_state "$c" "$p" FAILED "" NO_VERIFIED_REPLACEMENT; fi; return $rc; }
rotate_one_node(){ local c="$1" n="$2" p="$3" s="${4:-0}"; if ! acquire_node_lock "$c" "$p"; then [ "$s" = 1 ]||echo -e "${YELLOW}[!] $c is already being repaired; skipping duplicate rotation.${NC}"; return 3; fi; rotate_one_node_core "$c" "$n" "$p" "$s"; local rc=$?; release_node_lock; return $rc; }
health_check_node(){ local c="$1" n="$2" p="$3" s="${4:-1}" conf="$BASE_DIR/node_${c}_${p}.conf" d="$DATA_DIR/${c}_${p}"; [ -f "$conf" ]||return 0; if ! acquire_node_lock "$c" "$p"; then return 3; fi; local ip old result bad actual reason seen; old=$(read_node_ip_state "$c" "$p"||true); write_node_state "$c" "$p" HEALING "$old" health-check; if ! node_process_running "$c" "$p"; then release_node_lock; rotate_one_node "$c" "$n" "$p" "$s"; return $?; fi; ip=$(get_node_ip "$p"||true); if ! is_valid_ipv4 "$ip"; then release_node_lock; rotate_one_node "$c" "$n" "$p" "$s"; return $?; fi; result=$(check_ip_quality "$ip" "$c"); IFS='|' read -r bad actual reason seen<<<"$result"; if [ "$bad" = 0 ]; then printf '%s\n' "$ip">"$d/last_ip.txt"; write_node_state "$c" "$p" ONLINE "$ip" verified; release_node_lock; return 0; fi; append_bad_ip "$d/bad_exits.txt" "$ip"; write_node_state "$c" "$p" HEALING "$ip" "$reason"; release_node_lock; rotate_one_node "$c" "$n" "$p" "$s"; }
background_auto_heal(){ check_root; sync_dynamic_locations; local i c n p; local -a jobs=(); for i in "${ORDER[@]}"; do IFS=':' read -r c n p<<<"${NODES[$i]:-}"; [ -f "$BASE_DIR/node_${c}_${p}.conf" ]||continue; health_check_node "$c" "$n" "$p" 1 & jobs+=("$!"); if [ "${#jobs[@]}" -ge "$AUTO_HEAL_PARALLEL" ]; then wait "${jobs[0]}" 2>/dev/null||true; jobs=("${jobs[@]:1}"); fi; done; for i in "${jobs[@]}"; do wait "$i" 2>/dev/null||true; done; }
auto_heal_daemon(){ check_root; trap 'exit 0' INT TERM HUP; while true; do background_auto_heal; sleep "$AUTO_HEAL_INTERVAL"; done; }
# FIX #3 (blank rows): name resolution now always falls back to the country
# code itself if country_name() can't resolve a label, so a location can
# never render as a bare marker with no text next to it.
sync_dynamic_locations(){ mkdir -p "$DATA_DIR" "$BASE_DIR"; local t=1 tmp code key name port idx base already next=0; local -A old_port=() old_name=() installed=(); local -a avail=() ordered=(); for key in "${!NODES[@]}"; do IFS=':' read -r code name port<<<"${NODES[$key]}"; [ -n "$code" ]||continue; old_port[$code]="$port"; old_name[$code]="$name"; done; if [ -s "$LOCATION_CACHE" ]; then local mt=$(stat -c %Y "$LOCATION_CACHE" 2>/dev/null||echo 0); local now=$(date +%s); (( now-mt<LOCATION_CACHE_TTL ))&&t=0; fi; if ((t)); then tmp=$(mktemp /tmp/sherlook_country.XXXXXX); if curl -4 -fsS --connect-timeout 5 --max-time "$ONIONOO_TIMEOUT" "${ONIONOO_URL}?flag=Exit&running=true&fields=country" -o "$tmp" 2>/dev/null; then jq -r '.relays // [] | .[].country // empty' "$tmp" 2>/dev/null|tr '[:lower:]' '[:upper:]'|grep -E '^[A-Z]{2}$'|sort -u>"${LOCATION_CACHE}.tmp"||true; [ -s "${LOCATION_CACHE}.tmp" ]&&mv -f "${LOCATION_CACHE}.tmp" "$LOCATION_CACHE"; fi; rm -f "$tmp" "${LOCATION_CACHE}.tmp"; fi; SHERLOOK_EXIT_AVAILABLE=(); if [ -s "$LOCATION_CACHE" ]; then while IFS= read -r code; do [[ "$code" =~ ^[A-Z]{2}$ ]]||continue; SHERLOOK_EXIT_AVAILABLE[$code]=1; avail+=("$code"); done<"$LOCATION_CACHE"; fi; for idx in $(printf '%s\n' "${!NODES[@]}"|sort -n); do IFS=':' read -r code name port<<<"${NODES[$idx]}"; [ -n "${SHERLOOK_EXIT_AVAILABLE[$code]:-}" ]||continue; ordered+=("$code"); unset 'SHERLOOK_EXIT_AVAILABLE[$code]'; done; for code in "${avail[@]}"; do [ -n "${SHERLOOK_EXIT_AVAILABLE[$code]:-}" ]||continue; ordered+=("$code"); unset 'SHERLOOK_EXIT_AVAILABLE[$code]'; done; for conf in "$BASE_DIR"/node_??_*.conf "$BASE_DIR"/node_???_*.conf; do [ -f "$conf" ]||continue; base=$(basename "$conf" .conf); base=${base#node_}; code=${base%%_*}; port=${base#*_}; port=${port%%_*}; [[ "$code" =~ ^[A-Z]{2}$ ]]&&installed[$code]="$port"; done; NODES=(); ORDER=(); LOCATION_ORDER=(); for code in "${ordered[@]}"; do next=$((next+1)); port="${old_port[$code]:-${installed[$code]:-9080}}"; name="${old_name[$code]:-$(country_name "$code")}"; name="${name:-$code}"; key=$(printf '%02d' "$next"); NODES[$key]="$code:$name:$port"; ORDER+=("$key"); LOCATION_ORDER+=("$key"); done; for code in "${!installed[@]}"; do already=0; for key in "${LOCATION_ORDER[@]}"; do IFS=':' read -r c _ _<<<"${NODES[$key]}"; [ "$c" = "$code" ]&& {  already=1;break;}; done; ((already))&&continue; next=$((next+1)); port="${old_port[$code]:-${installed[$code]}}"; name="${old_name[$code]:-$(country_name "$code")}"; name="${name:-$code}"; key=$(printf '%02d' "$next"); NODES[$key]="$code:$name:$port"; ORDER+=("$key"); LOCATION_ORDER+=("$key"); done; :>"$LOCATION_CATALOG.tmp"; for key in "${LOCATION_ORDER[@]}"; do IFS=':' read -r code name port<<<"${NODES[$key]}"; printf '%s\t%s\t%s\n' "$code" "$name" "$port">>"$LOCATION_CATALOG.tmp"; done; mv -f "$LOCATION_CATALOG.tmp" "$LOCATION_CATALOG"; }
'''
s=s.replace(pre_marker,core+'\n'+pre_marker,1)
ui_marker='# ================= MENU LOOP ================='
if ui_marker not in s: raise SystemExit('menu anchor missing')
ui=r'''
# ===== 6.3.1 MANAGEMENT UI =====
eval "$(declare -f deploy_node | sed '1s/^deploy_node /legacy_deploy_node /')"
deploy_node(){ local c="$1" n="$2" p="$3"; mkdir -p "$DATA_DIR/${c}_${p}"; write_node_state "$c" "$p" STARTING "" deploy-start; legacy_deploy_node "$c" "$n" "$p"; local rc=$? ip=""; [ -s "$DATA_DIR/${c}_${p}/last_ip.txt" ]&&ip=$(head -n1 "$DATA_DIR/${c}_${p}/last_ip.txt"|tr -d '\r\n'); [ "$rc" = 0 ]&&write_node_state "$c" "$p" ONLINE "$ip" verified || [ -f "$BASE_DIR/node_${c}_${p}.conf" ]&&write_node_state "$c" "$p" FAILED "" deploy-failed; return $rc; }
node_is_installed(){ local c="$1" p="$2"; [ -f "$BASE_DIR/node_${c}_${p}.conf" ]||return 1; case "$(read_node_state "$c" "$p")" in ONLINE|HEALING|STARTING)return 0;;*)return 1;;esac; }
list_locations(){ sync_dynamic_locations||true; echo -e "${YELLOW}Available Tor Exit Locations (live Onionoo + cache):${NC}\n"; local total=${#LOCATION_ORDER[@]} half=$(( (total+1)/2 )) i a b ca na pa cb nb pb s1 s2 right; ((total==0))&& {  echo -e "${RED}No verified running Tor Exit countries are currently available.${NC}\n"; return; }; for((i=0;i<half;i++)); do a=${LOCATION_ORDER[$i]}; IFS=':' read -r ca na pa<<<"${NODES[$a]}"; [ -n "$ca" ]||continue; na="${na:-$ca}"; s1=$'\033[1;37m○\033[0m'; node_is_installed "$ca" "$pa"&&s1=$'\033[1;32m●\033[0m'; right=""; if((i+half<total));then b=${LOCATION_ORDER[$((i+half))]}; IFS=':' read -r cb nb pb<<<"${NODES[$b]}"; if [ -n "$cb" ]; then nb="${nb:-$cb}"; s2=$'\033[1;37m○\033[0m'; node_is_installed "$cb" "$pb"&&s2=$'\033[1;32m●\033[0m'; right=$(printf '  \033[1;36m[%02d]\033[0m %b %-20s' "$((10#$b))" "$s2" "$nb"); fi; fi; printf '  \033[1;36m[%02d]\033[0m %b %-20s%s\n' "$((10#$a))" "$s1" "$na" "$right"; done; echo -e "\n  ${RED}[00]${NC} Back\n"; }
add_single_node(){ check_root; draw_header; echo -e "${CYAN}» Option 4 - Add Location Node${NC}\n"; sync_dynamic_locations; list_locations; read -r -p "Select location index: " x; [[ "$x" == 00 || -z "$x" ]]&&return; local k=$(printf '%02d' "$((10#$x))" 2>/dev/null||true); [[ " ${LOCATION_ORDER[*]} " == *" $k "* ]]|| { echo "Invalid location index.";sleep 1;return;}; local c n p; IFS=':' read -r c n p<<<"${NODES[$k]}"; node_is_installed "$c" "$p"&& {  echo -e "${YELLOW}[!] $c - $n is already online/being healed.${NC}";sleep 2;return;}; deploy_node "$c" "$n" "$p"; read -r -p "Press Enter..." < /dev/tty||true; }
bulk_add_nodes(){ check_root; draw_header; sync_dynamic_locations; echo -e "${CYAN}» Option 5 - Bulk Add Nodes${NC}\n  [1] All current Tor Exits\n  [2] Custom indices\n  [3] Main countries\n  [0] Back\n"; read -r -p "Select: " m; case "$m" in 1) for k in "${LOCATION_ORDER[@]}";do IFS=':' read -r c n p<<<"${NODES[$k]}"; node_is_installed "$c" "$p"||deploy_node "$c" "$n" "$p"; done;; 2) list_locations; read -r -p "Indices (e.g. 1,2,4-6): " list; list=${list// /}; IFS=',' read -ra arr<<<"$list"; for part in "${arr[@]}";do if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]];then a=${BASH_REMATCH[1]};b=${BASH_REMATCH[2]};for((x=a;x<=b;x++));do k=$(printf '%02d' "$x");[[ " ${LOCATION_ORDER[*]} " == *" $k "* ]]||continue; IFS=':' read -r c n p<<<"${NODES[$k]}";node_is_installed "$c" "$p"||deploy_node "$c" "$n" "$p";done;elif [[ "$part" =~ ^[0-9]+$ ]];then k=$(printf '%02d' "$part");[[ " ${LOCATION_ORDER[*]} " == *" $k "* ]]||continue;IFS=':' read -r c n p<<<"${NODES[$k]}";node_is_installed "$c" "$p"||deploy_node "$c" "$n" "$p";fi;done;;3) for wanted in TR US FR CA FI ES NL CH GB LU;do for k in "${LOCATION_ORDER[@]}";do IFS=':' read -r c n p<<<"${NODES[$k]}";[ "$c" = "$wanted" ]||continue;node_is_installed "$c" "$p"||deploy_node "$c" "$n" "$p";break;done;done;;*)return;;esac;read -r -p "Press Enter..." < /dev/tty||true; }
change_ip_menu(){ check_root; while true;do draw_header;sync_dynamic_locations;echo -e "${MAGENTA}🔄 IP Rotation / Repair${NC}\n  [1] One installed Node\n  [2] All installed Nodes\n  [0] Back\n"; local -a ids=();local k c n p ch pick;for k in "${ORDER[@]}";do IFS=':' read -r c n p<<<"${NODES[$k]}";[ -f "$BASE_DIR/node_${c}_${p}.conf" ]||continue;ids+=("$k");done;read -r -p "Choice: " ch< /dev/tty||return;case "$ch" in 1)for k in "${ids[@]}";do IFS=':' read -r c n p<<<"${NODES[$k]}";printf ' [%s] %s %-20s Port:%-6s Status:%-8s IP:%s\n' "$k" "${EMOJIS[$c]:-🌐}" "$n" "$p" "$(status_for_menu "$c" "$p")" "$(read_node_ip_state "$c" "$p"||echo Waiting...)";done;read -r -p "Node ID: " pick< /dev/tty||continue;k=$(printf '%02d' "$((10#$pick))" 2>/dev/null||true);IFS=':' read -r c n p<<<"${NODES[$k]:-:::}";[ -n "$c" ]&&[ -f "$BASE_DIR/node_${c}_${p}.conf" ]&&rotate_one_node "$c" "$n" "$p" 0||echo "Invalid Node ID.";read -r -p "Press Enter..."< /dev/tty||true;;2)for k in "${ids[@]}";do IFS=':' read -r c n p<<<"${NODES[$k]}";rotate_one_node "$c" "$n" "$p" 1&done;wait||true;read -r -p "Press Enter..."< /dev/tty||true;;0)return;;esac;done; }
view_active_nodes(){ check_root;while true;do draw_header;sync_dynamic_locations;printf '%s\n' '┌──────┬──────┬──────────────────────┬─────────────┬──────────────┬──────────────────┐' '│ ID   │ CC   │ Location             │ Tor Port    │ Status       │ Live IP          │' '├──────┼──────┼──────────────────────┼─────────────┼──────────────┼──────────────────┤';local f=0 k c n p st ip;for k in "${ORDER[@]}";do IFS=':' read -r c n p<<<"${NODES[$k]}";[ -f "$BASE_DIR/node_${c}_${p}.conf" ]||continue;f=1;st=$(status_for_menu "$c" "$p");ip=$(read_node_ip_state "$c" "$p"||echo Waiting...);printf '│ %-4s │ %-4s │ %-20s │ %-11s │ %-12s │ %-16s │\n' "$k" "$c" "$n" "$p" "$st" "$ip";done;[ "$f" = 0 ]&&printf '│ %-80s │\n' 'No installed nodes found.';printf '%s\n' '└──────┴──────┴──────────────────────┴─────────────┴──────────────────┘';echo 'Refresh: 3s; press any key to return.';read -t 3 -n1 -s q&&break;done; }
edit_delete_nodes(){ check_root;draw_header;sync_dynamic_locations;echo -e "${MAGENTA}[ NODE MANAGEMENT ]${NC}";local -a ids=();local k c n p;for k in "${ORDER[@]}";do IFS=':' read -r c n p<<<"${NODES[$k]}";[ -f "$BASE_DIR/node_${c}_${p}.conf" ]||continue;ids+=("$k");printf ' [%s] %s %-20s Port:%-6s Status:%-8s IP:%s\n' "$k" "${EMOJIS[$c]:-🌐}" "$n" "$p" "$(status_for_menu "$c" "$p")" "$(read_node_ip_state "$c" "$p"||echo Waiting...)";done;[ "${#ids[@]}" = 0 ]&& { echo 'No installed nodes.';sleep 2;return;};echo '[99] DELETE ALL INSTALLED NODE RECORDS';read -r -p 'Select ID (0 cancel): ' x;[[ "$x" = 0 || -z "$x" ]]&&return;if [[ "$x" = 99 ]];then for k in "${ids[@]}";do IFS=':' read -r c n p<<<"${NODES[$k]}";pkill -9 -f "node_${c}_${p}\.conf" 2>/dev/null||true;rm -f "$BASE_DIR/node_${c}_${p}.conf";rm -rf "$DATA_DIR/${c}_${p}";done;else k=$(printf '%02d' "$((10#$x))" 2>/dev/null||true);IFS=':' read -r c n p<<<"${NODES[$k]:-:::}";[ -n "$c" ]&&rm -f "$BASE_DIR/node_${c}_${p}.conf"&&rm -rf "$DATA_DIR/${c}_${p}"||true;fi;sleep 2; }
'''
s=s.replace(ui_marker,ui+'\n'+ui_marker,1)
open(out,'w',encoding='utf-8').write(s)
PY
chmod 755 "$PATCHED_FILE"
}
fetch_base
pm_build_patch
exec bash "$PATCHED_FILE" "$@"
