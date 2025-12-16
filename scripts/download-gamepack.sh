#!/bin/bash
# Downloads gamepack from OSRS jav_config

JAV_CONFIG_URL="https://oldschool.runescape.com/jav_config.ws"
GAMEPACK_PATH="/app/data/gamepack.jar"

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
TEMP_GAMEPACK="/app/data/gamepack_new_$(date +%s).jar"

# Show old gamepack info before anything
if [ -f "$GAMEPACK_PATH" ]; then
    OLD_SHA=$(sha256sum "$GAMEPACK_PATH" 2>/dev/null | cut -d' ' -f1)
    OLD_SIZE=$(stat -c%s "$GAMEPACK_PATH" 2>/dev/null || echo "unknown")
    echo "[DOWNLOAD] Old gamepack: ${OLD_SIZE} bytes, SHA: ${OLD_SHA:0:16}..."
else
    echo "[DOWNLOAD] No existing gamepack found"
fi

# Download to temp file first (fresh download, no overwrite issues)
echo "[DOWNLOAD] Fetching gamepack from: $GAMEPACK_URL"
echo "[DOWNLOAD] Downloading to temp file: $TEMP_GAMEPACK"

curl -sL \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -H "Expires: 0" \
    -H "If-None-Match: \"dummy\"" \
    -H "If-Modified-Since: Thu, 01 Jan 1970 00:00:00 GMT" \
    --connect-timeout 10 \
    --max-time 120 \
    -o "$TEMP_GAMEPACK" \
    "$GAMEPACK_URL"

CURL_EXIT=$?
echo "[DOWNLOAD] curl exit code: $CURL_EXIT"

if [ ! -f "$TEMP_GAMEPACK" ]; then
    echo "[DOWNLOAD] ERROR: Temp file not created"
    exit 1
fi

NEW_SIZE=$(stat -c%s "$TEMP_GAMEPACK" 2>/dev/null || stat -f%z "$TEMP_GAMEPACK" 2>/dev/null)
echo "[DOWNLOAD] Downloaded temp file: ${NEW_SIZE} bytes"

if [ "$NEW_SIZE" -lt 1000 ]; then
    echo "[DOWNLOAD] ERROR: Downloaded file too small (${NEW_SIZE} bytes)"
    echo "[DOWNLOAD] File contents:"
    head -5 "$TEMP_GAMEPACK"
    rm -f "$TEMP_GAMEPACK"
    exit 1
fi

NEW_SHA=$(sha256sum "$TEMP_GAMEPACK" | cut -d' ' -f1)
echo "[DOWNLOAD] New gamepack SHA: ${NEW_SHA:0:16}..."

# Now delete old and move new into place
echo "[DOWNLOAD] Replacing old gamepack..."
rm -f "$GAMEPACK_PATH"
rm -f /app/data/gamepack_new_*.jar 2>/dev/null  # Clean up any old temp files
mv "$TEMP_GAMEPACK" "$GAMEPACK_PATH"
sync

# Verify final file
if [ -f "$GAMEPACK_PATH" ]; then
    FINAL_SHA=$(sha256sum "$GAMEPACK_PATH" | cut -d' ' -f1)
    FINAL_SIZE=$(stat -c%s "$GAMEPACK_PATH" 2>/dev/null)
    echo "[DOWNLOAD] Final gamepack: ${FINAL_SIZE} bytes, SHA: ${FINAL_SHA:0:16}..."
else
    echo "[DOWNLOAD] ERROR: Failed to create final gamepack"
    exit 1
fi
