#!/bin/bash
# Downloads gamepack from OSRS jav_config

JAV_CONFIG_URL="https://oldschool.runescape.com/jav_config.ws"
GAMEPACK_PATH="/app/data/gamepack.jar"

echo "[DOWNLOAD] Fetching jav_config from: $JAV_CONFIG_URL"

# Fetch jav_config once (follow redirects with -L)
JAV_CONFIG=$(curl -sL "$JAV_CONFIG_URL")

# Parse jav_config to get gamepack URL
CODEBASE=$(echo "$JAV_CONFIG" | grep "codebase=" | cut -d'=' -f2 | tr -d '\r')
INITIAL_JAR=$(echo "$JAV_CONFIG" | grep "initial_jar=" | cut -d'=' -f2 | tr -d '\r')

if [ -z "$CODEBASE" ] || [ -z "$INITIAL_JAR" ]; then
    echo "[DOWNLOAD] ERROR: Failed to parse jav_config"
    echo "[DOWNLOAD] CODEBASE='$CODEBASE' INITIAL_JAR='$INITIAL_JAR'"
    exit 1
fi

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
