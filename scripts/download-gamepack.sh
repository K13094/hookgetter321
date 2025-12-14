#!/bin/bash
# Downloads gamepack from OSRS jav_config

JAV_CONFIG_URL="https://oldschool.runescape.com/jav_config.ws"
GAMEPACK_PATH="/app/data/gamepack.jar"

echo "[DOWNLOAD] Fetching jav_config from: $JAV_CONFIG_URL"

# Parse jav_config to get gamepack URL
CODEBASE=$(curl -s "$JAV_CONFIG_URL" | grep "codebase=" | cut -d'=' -f2 | tr -d '\r')
INITIAL_JAR=$(curl -s "$JAV_CONFIG_URL" | grep "initial_jar=" | cut -d'=' -f2 | tr -d '\r')

GAMEPACK_URL="${CODEBASE}${INITIAL_JAR}"

echo "[DOWNLOAD] Fetching gamepack from: $GAMEPACK_URL"
curl -s -o "$GAMEPACK_PATH" "$GAMEPACK_URL"

if [ -f "$GAMEPACK_PATH" ]; then
    SIZE=$(stat -c%s "$GAMEPACK_PATH" 2>/dev/null || stat -f%z "$GAMEPACK_PATH" 2>/dev/null)
    echo "[DOWNLOAD] Downloaded gamepack.jar (${SIZE} bytes)"
else
    echo "[DOWNLOAD] ERROR: Failed to download gamepack"
    exit 1
fi
