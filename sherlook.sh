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
        while IFS=$'\t' read -r catalog_code catalog_name catalog_port; do
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
            printf '%s\t%s\t%s\n' "$catalog_code" "$catalog_name" "$max_port" >> "$LOCATION_CATALOG"
        done < "$LOCATION_CACHE"
    fi

    # Also persist statically defined locations once, while leaving their
    # original ports untouched.
    : > "$LOCATION_CATALOG.tmp"
    for key in "${!NODES[@]}"; do
        IFS=':' read -r catalog_code catalog_name catalog_port <<< "${NODES[$key]}"
        printf '%s\t%s\t%s\n' "$catalog_code" "$catalog_name" "$catalog_port" >> "$LOCATION_CATALOG.tmp"
    done
    sort -t $'\t' -k1,1 -u "$LOCATION_CATALOG.tmp" > "$LOCATION_CATALOG" 2>/dev/null || mv -f "$LOCATION_CATALOG.tmp" "$LOCATION_CATALOG"
    rm -f "$LOCATION_CATALOG.tmp"

    mapfile -t ORDER < <(printf '%s\n' "${!NODES[@]}" | sort -n)
}
