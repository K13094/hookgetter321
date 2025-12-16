#!/bin/bash
# Downloads gamepack from OSRS jav_config with method rotation
# Exit code 99 = deletion failed, trigger container restart

JAV_CONFIG_URL="https://oldschool.runescape.com/jav_config.ws"
GAMEPACK_PATH="/app/data/gamepack.jar"
TEMP_GAMEPACK="/app/data/gamepack_temp.jar"
LAST_METHOD_FILE="/app/data/last_download_method.txt"

# Download methods - rotate through these to ensure fresh downloads
DOWNLOAD_METHODS=("random_query" "no_cache_headers" "force_revalidate" "pragma_expires" "unique_useragent")

echo "=============================================="
echo "[DOWNLOAD] GAMEPACK DOWNLOAD STARTED"
echo "[DOWNLOAD] Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=============================================="

# ============================================
# STEP 1: SELECT DOWNLOAD METHOD (ROTATION)
# ============================================
echo ""
echo "[DOWNLOAD] === DOWNLOAD METHOD SELECTION ==="

LAST_METHOD=$(cat "$LAST_METHOD_FILE" 2>/dev/null || echo "none")
echo "[DOWNLOAD] Last method used: $LAST_METHOD"

# Find next method in rotation (different from last)
CURRENT_METHOD=""
FOUND_LAST=false
for METHOD in "${DOWNLOAD_METHODS[@]}" "${DOWNLOAD_METHODS[@]}"; do
    if [ "$FOUND_LAST" = true ] && [ "$METHOD" != "$LAST_METHOD" ]; then
        CURRENT_METHOD="$METHOD"
        break
    fi
    if [ "$METHOD" = "$LAST_METHOD" ]; then
        FOUND_LAST=true
    fi
done

# Default to first method if no last method or rotation complete
if [ -z "$CURRENT_METHOD" ]; then
    CURRENT_METHOD="${DOWNLOAD_METHODS[0]}"
    if [ "$CURRENT_METHOD" = "$LAST_METHOD" ]; then
        CURRENT_METHOD="${DOWNLOAD_METHODS[1]}"
    fi
fi

echo "[DOWNLOAD] Selected method: $CURRENT_METHOD (rotating from $LAST_METHOD)"

# ============================================
# STEP 2: SHOW CURRENT STATE
# ============================================
echo ""
echo "[DOWNLOAD] === FILES IN /app/data BEFORE ANYTHING ==="
ls -la /app/data/ 2>/dev/null || echo "[DOWNLOAD] Directory does not exist yet"
echo "[DOWNLOAD] === END FILE LIST ==="

# ============================================
# STEP 3: WAIT FOR VPN/NETWORK
# ============================================
echo ""
echo "[DOWNLOAD] === FETCHING JAV_CONFIG ==="

MAX_RETRIES=30
RETRY_DELAY=5

for i in $(seq 1 $MAX_RETRIES); do
    echo "[DOWNLOAD] Fetching jav_config from: $JAV_CONFIG_URL (attempt $i/$MAX_RETRIES)"

    JAV_CONFIG=$(curl -sL \
        -H "Cache-Control: no-cache, no-store, must-revalidate" \
        -H "Pragma: no-cache" \
        --connect-timeout 10 \
        --max-time 30 \
        "$JAV_CONFIG_URL")

    CODEBASE=$(echo "$JAV_CONFIG" | grep "codebase=" | cut -d'=' -f2 | tr -d '\r')
    INITIAL_JAR=$(echo "$JAV_CONFIG" | grep "initial_jar=" | cut -d'=' -f2 | tr -d '\r')

    if [ -n "$CODEBASE" ] && [ -n "$INITIAL_JAR" ]; then
        echo "[DOWNLOAD] Successfully parsed jav_config"
        echo "[DOWNLOAD] CODEBASE: $CODEBASE"
        echo "[DOWNLOAD] INITIAL_JAR: $INITIAL_JAR"
        break
    fi

    if [ $i -eq $MAX_RETRIES ]; then
        echo "[DOWNLOAD] ERROR: Failed to parse jav_config after $MAX_RETRIES attempts"
        exit 1
    fi

    echo "[DOWNLOAD] Waiting ${RETRY_DELAY}s for network/VPN..."
    sleep $RETRY_DELAY
done

GAMEPACK_URL="${CODEBASE}${INITIAL_JAR}"

# ============================================
# STEP 4: CHECK OLD GAMEPACK
# ============================================
echo ""
echo "[DOWNLOAD] === CHECKING OLD GAMEPACK ==="

if [ -f "$GAMEPACK_PATH" ]; then
    OLD_SHA=$(sha256sum "$GAMEPACK_PATH" 2>/dev/null | cut -d' ' -f1)
    OLD_SIZE=$(stat -c%s "$GAMEPACK_PATH" 2>/dev/null || echo "unknown")
    echo "[DOWNLOAD] OLD GAMEPACK EXISTS:"
    echo "[DOWNLOAD]   Size: ${OLD_SIZE} bytes"
    echo "[DOWNLOAD]   SHA256: $OLD_SHA"
else
    OLD_SHA="none"
    echo "[DOWNLOAD] No existing gamepack found"
fi

# ============================================
# STEP 5: FORCE DELETE OLD GAMEPACK
# ============================================
echo ""
echo "[DOWNLOAD] === FORCE DELETING OLD GAMEPACK ==="

if [ -f "$GAMEPACK_PATH" ]; then
    echo "[DOWNLOAD] Step 5.1: First deletion attempt"
    rm -vf "$GAMEPACK_PATH"
    sync
    sleep 2

    if [ -f "$GAMEPACK_PATH" ]; then
        echo "[DOWNLOAD] Step 5.2: File still exists! Second attempt with directory refresh"
        ls -la /app/data/ > /dev/null 2>&1
        rm -vf "$GAMEPACK_PATH"
        sync
        sleep 2
    fi

    if [ -f "$GAMEPACK_PATH" ]; then
        echo "[DOWNLOAD] Step 5.3: File STILL exists! Third attempt with force"
        rm -rf "$GAMEPACK_PATH"
        sync
        sleep 3
    fi

    # Final verification
    if [ -f "$GAMEPACK_PATH" ]; then
        echo ""
        echo "[FATAL] =============================================="
        echo "[FATAL] CANNOT DELETE OLD GAMEPACK!"
        echo "[FATAL] File: $GAMEPACK_PATH"
        echo "[FATAL] This is likely a TrueNAS/NFS volume issue"
        echo "[FATAL] Triggering container restart in 10 seconds..."
        echo "[FATAL] =============================================="
        ls -la "$GAMEPACK_PATH"
        sleep 10
        exit 99  # Special exit code for restart
    fi

    echo "[DOWNLOAD] SUCCESS: Old gamepack deleted!"
else
    echo "[DOWNLOAD] No old gamepack to delete"
fi

echo ""
echo "[DOWNLOAD] === FILES AFTER DELETION ==="
ls -la /app/data/
echo "[DOWNLOAD] === END FILE LIST ==="

# ============================================
# STEP 6: CLEAN UP TEMP FILE
# ============================================
echo ""
echo "[DOWNLOAD] === CLEANING UP TEMP FILES ==="
rm -f "$TEMP_GAMEPACK" 2>/dev/null
echo "[DOWNLOAD] Temp file cleaned"

# ============================================
# STEP 7: DOWNLOAD WITH SELECTED METHOD
# ============================================
echo ""
echo "[DOWNLOAD] === DOWNLOADING NEW GAMEPACK ==="
echo "[DOWNLOAD] URL: $GAMEPACK_URL"
echo "[DOWNLOAD] Method: $CURRENT_METHOD"
echo "[DOWNLOAD] Starting download at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Build curl command based on method
case "$CURRENT_METHOD" in
    "random_query")
        DOWNLOAD_URL="${GAMEPACK_URL}?nocache=$(date +%s)${RANDOM}"
        echo "[DOWNLOAD] Using random query param: $DOWNLOAD_URL"
        curl -L \
            --connect-timeout 30 \
            --max-time 180 \
            -o "$TEMP_GAMEPACK" \
            "$DOWNLOAD_URL" 2>&1 | tail -20
        ;;
    "no_cache_headers")
        echo "[DOWNLOAD] Using no-cache headers"
        curl -L \
            -H "Cache-Control: no-cache, no-store, must-revalidate" \
            --connect-timeout 30 \
            --max-time 180 \
            -o "$TEMP_GAMEPACK" \
            "$GAMEPACK_URL" 2>&1 | tail -20
        ;;
    "force_revalidate")
        echo "[DOWNLOAD] Using force revalidate headers"
        curl -L \
            -H "If-None-Match: \"random-${RANDOM}-$(date +%s)\"" \
            -H "If-Modified-Since: Thu, 01 Jan 1970 00:00:00 GMT" \
            --connect-timeout 30 \
            --max-time 180 \
            -o "$TEMP_GAMEPACK" \
            "$GAMEPACK_URL" 2>&1 | tail -20
        ;;
    "pragma_expires")
        echo "[DOWNLOAD] Using pragma/expires headers"
        curl -L \
            -H "Pragma: no-cache" \
            -H "Expires: 0" \
            --connect-timeout 30 \
            --max-time 180 \
            -o "$TEMP_GAMEPACK" \
            "$GAMEPACK_URL" 2>&1 | tail -20
        ;;
    "unique_useragent")
        echo "[DOWNLOAD] Using unique user-agent"
        curl -L \
            -A "OSRS-Hook-Service/1.0 (Build ${RANDOM}-$(date +%s))" \
            --connect-timeout 30 \
            --max-time 180 \
            -o "$TEMP_GAMEPACK" \
            "$GAMEPACK_URL" 2>&1 | tail -20
        ;;
esac

CURL_EXIT=$?
echo ""
echo "[DOWNLOAD] curl exit code: $CURL_EXIT"
echo "[DOWNLOAD] Download finished at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ============================================
# STEP 8: VERIFY DOWNLOAD
# ============================================
echo ""
echo "[DOWNLOAD] === FILES AFTER DOWNLOAD ==="
ls -la /app/data/
echo "[DOWNLOAD] === END FILE LIST ==="

if [ ! -f "$TEMP_GAMEPACK" ]; then
    echo ""
    echo "[DOWNLOAD] ERROR: Temp file not created!"
    echo "[DOWNLOAD] Trying wget as fallback..."
    wget -q -O "$TEMP_GAMEPACK" "$GAMEPACK_URL" 2>&1 || true

    if [ ! -f "$TEMP_GAMEPACK" ]; then
        echo "[DOWNLOAD] ERROR: wget also failed"
        exit 1
    fi
fi

NEW_SIZE=$(stat -c%s "$TEMP_GAMEPACK" 2>/dev/null || echo "0")
NEW_SHA=$(sha256sum "$TEMP_GAMEPACK" | cut -d' ' -f1)

echo ""
echo "[DOWNLOAD] === NEW GAMEPACK INFO ==="
echo "[DOWNLOAD]   Size: ${NEW_SIZE} bytes"
echo "[DOWNLOAD]   SHA256: $NEW_SHA"

if [ "$NEW_SIZE" -lt 1000 ]; then
    echo "[DOWNLOAD] ERROR: Downloaded file too small (${NEW_SIZE} bytes)"
    cat "$TEMP_GAMEPACK" 2>/dev/null | head -5
    rm -f "$TEMP_GAMEPACK"
    exit 1
fi

# ============================================
# STEP 9: COMPARE OLD AND NEW
# ============================================
echo ""
echo "[DOWNLOAD] === SHA COMPARISON ==="
echo "[DOWNLOAD] OLD SHA: $OLD_SHA"
echo "[DOWNLOAD] NEW SHA: $NEW_SHA"
if [ "$OLD_SHA" = "$NEW_SHA" ]; then
    echo "[DOWNLOAD] !!! SHA MATCH - GAMEPACK UNCHANGED !!!"
else
    echo "[DOWNLOAD] *** SHA DIFFERENT - GAMEPACK HAS CHANGED! ***"
fi

# ============================================
# STEP 10: MOVE TEMP TO FINAL LOCATION
# ============================================
echo ""
echo "[DOWNLOAD] === INSTALLING NEW GAMEPACK ==="
echo "[DOWNLOAD] Moving: $TEMP_GAMEPACK -> $GAMEPACK_PATH"
mv -v "$TEMP_GAMEPACK" "$GAMEPACK_PATH"
sync
sleep 1

# ============================================
# STEP 11: FINAL VERIFICATION
# ============================================
echo ""
echo "[DOWNLOAD] === FINAL VERIFICATION ==="

if [ -f "$GAMEPACK_PATH" ]; then
    FINAL_SHA=$(sha256sum "$GAMEPACK_PATH" | cut -d' ' -f1)
    FINAL_SIZE=$(stat -c%s "$GAMEPACK_PATH" 2>/dev/null)
    echo "[DOWNLOAD] FINAL GAMEPACK:"
    echo "[DOWNLOAD]   Path: $GAMEPACK_PATH"
    echo "[DOWNLOAD]   Size: ${FINAL_SIZE} bytes"
    echo "[DOWNLOAD]   SHA256: $FINAL_SHA"

    if [ "$FINAL_SHA" = "$NEW_SHA" ]; then
        echo "[DOWNLOAD] VERIFIED: SHA matches!"
    else
        echo "[DOWNLOAD] ERROR: SHA mismatch after move!"
        exit 1
    fi
else
    echo "[DOWNLOAD] ERROR: Final gamepack not found!"
    exit 1
fi

# ============================================
# STEP 12: SAVE DOWNLOAD METHOD USED
# ============================================
echo ""
echo "[DOWNLOAD] === SAVING DOWNLOAD METHOD ==="
echo "$CURRENT_METHOD" > "$LAST_METHOD_FILE"
echo "[DOWNLOAD] Saved method: $CURRENT_METHOD (for rotation)"

# ============================================
# COMPLETE
# ============================================
echo ""
echo "[DOWNLOAD] === ALL FILES AT END ==="
ls -la /app/data/
echo "[DOWNLOAD] === END FILE LIST ==="
echo ""
echo "=============================================="
echo "[DOWNLOAD] GAMEPACK DOWNLOAD COMPLETE"
echo "[DOWNLOAD] Method used: $CURRENT_METHOD"
echo "[DOWNLOAD] Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=============================================="
