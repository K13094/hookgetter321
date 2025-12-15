#!/bin/bash
# Downloads gamepack from OSRS jav_config

JAV_CONFIG_URL="https://oldschool.runescape.com/jav_config.ws"
GAMEPACK_PATH="/app/data/gamepack.jar"

# Wait for VPN/network to be ready (retry up to 30 times with 5s delay = 2.5 min max)
MAX_RETRIES=30
RETRY_DELAY=5

for i in $(seq 1 $MAX_RETRIES); do
    echo "[DOWNLOAD] Fetching jav_config from: $JAV_CONFIG_URL (attempt $i/$MAX_RETRIES)"

    # Fetch jav_config (follow redirects with -L, 10s timeout)
    JAV_CONFIG=$(curl -sL --connect-timeout 10 --max-time 30 "$JAV_CONFIG_URL")

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

echo "[DOWNLOAD] Fetching gamepack from: $GAMEPACK_URL"
curl -sL -o "$GAMEPACK_PATH" "$GAMEPACK_URL"

if [ -f "$GAMEPACK_PATH" ]; then
    SIZE=$(stat -c%s "$GAMEPACK_PATH" 2>/dev/null || stat -f%z "$GAMEPACK_PATH" 2>/dev/null)
    if [ "$SIZE" -gt 1000 ]; then
        echo "[DOWNLOAD] Downloaded gamepack.jar (${SIZE} bytes)"
    else
        echo "[DOWNLOAD] ERROR: Downloaded file too small (${SIZE} bytes)"
        exit 1
    fi
else
    echo "[DOWNLOAD] ERROR: Failed to download gamepack"
    exit 1
fi
