#!/bin/bash
# Downloads gamepack from OSRS jav_config

JAV_CONFIG_URL="https://oldschool.runescape.com/jav_config.ws"
GAMEPACK_PATH="/app/data/gamepack.jar"

echo "=============================================="
echo "[DOWNLOAD] GAMEPACK DOWNLOAD STARTED"
echo "[DOWNLOAD] Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=============================================="

# Show ALL files in /app/data at start
echo ""
echo "[DOWNLOAD] === FILES IN /app/data BEFORE ANYTHING ==="
ls -la /app/data/ 2>/dev/null || echo "[DOWNLOAD] Directory does not exist yet"
echo "[DOWNLOAD] === END FILE LIST ==="
echo ""

# Wait for VPN/network to be ready (retry up to 30 times with 5s delay = 2.5 min max)
MAX_RETRIES=30
RETRY_DELAY=5

for i in $(seq 1 $MAX_RETRIES); do
    echo "[DOWNLOAD] Fetching jav_config from: $JAV_CONFIG_URL (attempt $i/$MAX_RETRIES)"

    # Fetch jav_config (follow redirects with -L, 10s timeout, no caching)
    JAV_CONFIG=$(curl -sL \
        -H "Cache-Control: no-cache, no-store, must-revalidate" \
        -H "Pragma: no-cache" \
        -H "Expires: 0" \
        --connect-timeout 10 \
        --max-time 30 \
        "$JAV_CONFIG_URL")

    # Parse jav_config to get gamepack URL
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
        echo "[DOWNLOAD] CODEBASE='$CODEBASE' INITIAL_JAR='$INITIAL_JAR'"
        exit 1
    fi

    echo "[DOWNLOAD] Waiting ${RETRY_DELAY}s for network/VPN..."
    sleep $RETRY_DELAY
done

GAMEPACK_URL="${CODEBASE}${INITIAL_JAR}"
TEMP_GAMEPACK="/app/data/gamepack_temp.jar"

echo ""
echo "[DOWNLOAD] === CHECKING OLD GAMEPACK ==="

# Show old gamepack info before anything
if [ -f "$GAMEPACK_PATH" ]; then
    OLD_SHA=$(sha256sum "$GAMEPACK_PATH" 2>/dev/null | cut -d' ' -f1)
    OLD_SIZE=$(stat -c%s "$GAMEPACK_PATH" 2>/dev/null || echo "unknown")
    OLD_MTIME=$(stat -c%y "$GAMEPACK_PATH" 2>/dev/null || echo "unknown")
    OLD_INODE=$(stat -c%i "$GAMEPACK_PATH" 2>/dev/null || echo "unknown")
    echo "[DOWNLOAD] OLD GAMEPACK EXISTS:"
    echo "[DOWNLOAD]   Path: $GAMEPACK_PATH"
    echo "[DOWNLOAD]   Size: ${OLD_SIZE} bytes"
    echo "[DOWNLOAD]   SHA256: $OLD_SHA"
    echo "[DOWNLOAD]   Modified: $OLD_MTIME"
    echo "[DOWNLOAD]   Inode: $OLD_INODE"
else
    OLD_SHA="none"
    echo "[DOWNLOAD] No existing gamepack found at $GAMEPACK_PATH"
fi

# Clean up any previous temp file
echo ""
echo "[DOWNLOAD] === CLEANING UP TEMP FILES ==="
if [ -f "$TEMP_GAMEPACK" ]; then
    echo "[DOWNLOAD] Removing old temp file: $TEMP_GAMEPACK"
    rm -vf "$TEMP_GAMEPACK"
else
    echo "[DOWNLOAD] No temp file to clean up"
fi

# Check if data directory exists and is writable
echo ""
echo "[DOWNLOAD] === DIRECTORY CHECK ==="
if [ ! -d "/app/data" ]; then
    echo "[DOWNLOAD] ERROR: /app/data does not exist! Creating..."
    mkdir -p /app/data
fi
echo "[DOWNLOAD] Disk space:"
df -h /app/data/
echo "[DOWNLOAD] Directory permissions:"
ls -la /app/ | grep data

# Download to temp file first
echo ""
echo "[DOWNLOAD] === DOWNLOADING NEW GAMEPACK ==="
echo "[DOWNLOAD] URL: $GAMEPACK_URL"
echo "[DOWNLOAD] Destination: $TEMP_GAMEPACK"
echo "[DOWNLOAD] Starting download at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

curl -v -L \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -H "If-None-Match: \"force-download\"" \
    -H "If-Modified-Since: Thu, 01 Jan 1970 00:00:00 GMT" \
    --connect-timeout 30 \
    --max-time 180 \
    -o "$TEMP_GAMEPACK" \
    "$GAMEPACK_URL" 2>&1 | tail -30

CURL_EXIT=${PIPESTATUS[0]}
echo ""
echo "[DOWNLOAD] curl exit code: $CURL_EXIT"
echo "[DOWNLOAD] Download finished at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Debug: show what's in data dir now
echo ""
echo "[DOWNLOAD] === FILES IN /app/data AFTER DOWNLOAD ==="
ls -la /app/data/
echo "[DOWNLOAD] === END FILE LIST ==="

if [ ! -f "$TEMP_GAMEPACK" ]; then
    echo ""
    echo "[DOWNLOAD] ERROR: Temp file not created at $TEMP_GAMEPACK"
    echo "[DOWNLOAD] Trying alternate download method (wget)..."
    wget -O "$TEMP_GAMEPACK" "$GAMEPACK_URL" 2>&1 || true
    echo "[DOWNLOAD] Files after wget:"
    ls -la /app/data/
    if [ ! -f "$TEMP_GAMEPACK" ]; then
        echo "[DOWNLOAD] ERROR: wget also failed"
        exit 1
    fi
fi

NEW_SIZE=$(stat -c%s "$TEMP_GAMEPACK" 2>/dev/null || stat -f%z "$TEMP_GAMEPACK" 2>/dev/null || echo "0")
NEW_SHA=$(sha256sum "$TEMP_GAMEPACK" | cut -d' ' -f1)

echo ""
echo "[DOWNLOAD] === NEW GAMEPACK INFO ==="
echo "[DOWNLOAD]   Size: ${NEW_SIZE} bytes"
echo "[DOWNLOAD]   SHA256: $NEW_SHA"

if [ "$NEW_SIZE" -lt 1000 ]; then
    echo "[DOWNLOAD] ERROR: Downloaded file too small (${NEW_SIZE} bytes)"
    echo "[DOWNLOAD] File contents:"
    cat "$TEMP_GAMEPACK" 2>/dev/null | head -10
    rm -f "$TEMP_GAMEPACK"
    exit 1
fi

# Compare old and new
echo ""
echo "[DOWNLOAD] === COMPARISON ==="
echo "[DOWNLOAD] OLD SHA: $OLD_SHA"
echo "[DOWNLOAD] NEW SHA: $NEW_SHA"
if [ "$OLD_SHA" = "$NEW_SHA" ]; then
    echo "[DOWNLOAD] !!! SHA MATCH - GAMEPACK UNCHANGED !!!"
else
    echo "[DOWNLOAD] *** SHA DIFFERENT - GAMEPACK HAS CHANGED! ***"
fi

# Now delete old and move new into place
echo ""
echo "[DOWNLOAD] === REPLACING OLD GAMEPACK ==="
echo "[DOWNLOAD] Step 1: Deleting old gamepack at $GAMEPACK_PATH"
if [ -f "$GAMEPACK_PATH" ]; then
    rm -vf "$GAMEPACK_PATH"
    if [ -f "$GAMEPACK_PATH" ]; then
        echo "[DOWNLOAD] ERROR: Failed to delete old gamepack!"
        ls -la "$GAMEPACK_PATH"
    else
        echo "[DOWNLOAD] SUCCESS: Old gamepack deleted"
    fi
else
    echo "[DOWNLOAD] No old gamepack to delete"
fi

echo ""
echo "[DOWNLOAD] === FILES AFTER DELETION ==="
ls -la /app/data/
echo "[DOWNLOAD] === END FILE LIST ==="

echo ""
echo "[DOWNLOAD] Step 2: Moving temp to final location"
echo "[DOWNLOAD] From: $TEMP_GAMEPACK"
echo "[DOWNLOAD] To: $GAMEPACK_PATH"
mv -v "$TEMP_GAMEPACK" "$GAMEPACK_PATH"

echo ""
echo "[DOWNLOAD] Step 3: Syncing filesystem"
sync

# Verify final file
echo ""
echo "[DOWNLOAD] === FINAL VERIFICATION ==="
if [ -f "$GAMEPACK_PATH" ]; then
    FINAL_SHA=$(sha256sum "$GAMEPACK_PATH" | cut -d' ' -f1)
    FINAL_SIZE=$(stat -c%s "$GAMEPACK_PATH" 2>/dev/null)
    FINAL_MTIME=$(stat -c%y "$GAMEPACK_PATH" 2>/dev/null)
    FINAL_INODE=$(stat -c%i "$GAMEPACK_PATH" 2>/dev/null)
    echo "[DOWNLOAD] FINAL GAMEPACK:"
    echo "[DOWNLOAD]   Path: $GAMEPACK_PATH"
    echo "[DOWNLOAD]   Size: ${FINAL_SIZE} bytes"
    echo "[DOWNLOAD]   SHA256: $FINAL_SHA"
    echo "[DOWNLOAD]   Modified: $FINAL_MTIME"
    echo "[DOWNLOAD]   Inode: $FINAL_INODE"

    if [ "$FINAL_SHA" = "$NEW_SHA" ]; then
        echo "[DOWNLOAD] VERIFIED: Final SHA matches downloaded SHA"
    else
        echo "[DOWNLOAD] ERROR: Final SHA does not match!"
    fi
else
    echo "[DOWNLOAD] ERROR: Failed to create final gamepack"
    exit 1
fi

echo ""
echo "[DOWNLOAD] === ALL FILES IN /app/data AT END ==="
ls -la /app/data/
echo "[DOWNLOAD] === END FILE LIST ==="
echo ""
echo "=============================================="
echo "[DOWNLOAD] GAMEPACK DOWNLOAD COMPLETE"
echo "[DOWNLOAD] Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=============================================="
