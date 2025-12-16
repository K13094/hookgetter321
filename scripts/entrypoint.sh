#!/bin/bash
set -e

echo "=============================================="
echo "  OSRS Hook Discovery Service"
echo "  Schedule: :01 and :31 of each hour"
echo "  Output: /app/data/hooks.json"
echo "=============================================="

# Create directories if needed
mkdir -p /app/data /app/output

# Function to run the gamepack check and deob
run_check() {
    echo ""
    echo "[HOOK-SERVICE] $(date -u +%Y-%m-%dT%H:%M:%SZ) - Checking for gamepack updates..."

    # Step 1: Download gamepack from Jagex
    /app/scripts/download-gamepack.sh

    # Step 2: Check if gamepack changed
    NEW_SHA=$(sha256sum /app/data/gamepack.jar | cut -d' ' -f1)
    OLD_SHA=$(cat /app/data/gamepack.sha256 2>/dev/null || echo "none")

    echo "[HOOK-SERVICE] Gamepack - Current: ${OLD_SHA:0:16}... New: ${NEW_SHA:0:16}..."

    # Step 3: Fetch rules from GitHub and check if changed
    RULES_URL="https://raw.githubusercontent.com/K13094/hookgetter321/main/rules/osrs-rules.yaml"
    RULES_FILE="/app/data/osrs-rules.yaml"

    echo "[HOOK-SERVICE] Fetching rules from GitHub..."
    curl -sL -o "$RULES_FILE" "$RULES_URL"

    if [ -f "$RULES_FILE" ] && [ -s "$RULES_FILE" ]; then
        NEW_RULES_SHA=$(sha256sum "$RULES_FILE" | cut -d' ' -f1)
        OLD_RULES_SHA=$(cat /app/data/rules.sha256 2>/dev/null || echo "none")
        echo "[HOOK-SERVICE] Rules - Current: ${OLD_RULES_SHA:0:16}... New: ${NEW_RULES_SHA:0:16}..."
    else
        NEW_RULES_SHA="fetch_failed"
        OLD_RULES_SHA="fetch_failed"
        echo "[HOOK-SERVICE] WARNING: Failed to fetch rules from GitHub"
    fi

    # Run deob if EITHER gamepack OR rules changed
    GAMEPACK_CHANGED="no"
    RULES_CHANGED="no"

    if [ "$NEW_SHA" != "$OLD_SHA" ]; then
        GAMEPACK_CHANGED="yes"
    fi

    if [ "$NEW_RULES_SHA" != "$OLD_RULES_SHA" ] && [ "$NEW_RULES_SHA" != "fetch_failed" ]; then
        RULES_CHANGED="yes"
    fi

    if [ "$GAMEPACK_CHANGED" = "yes" ] || [ "$RULES_CHANGED" = "yes" ]; then
        echo ""
        if [ "$GAMEPACK_CHANGED" = "yes" ] && [ "$RULES_CHANGED" = "yes" ]; then
            echo "[HOOK-SERVICE] *** GAMEPACK AND RULES CHANGED! Running deobfuscation... ***"
        elif [ "$GAMEPACK_CHANGED" = "yes" ]; then
            echo "[HOOK-SERVICE] *** GAMEPACK CHANGED! Running deobfuscation... ***"
        else
            echo "[HOOK-SERVICE] *** RULES CHANGED! Running deobfuscation... ***"
        fi
        echo ""

        # Clean up old deob output (hooks.json stays until replaced)
        echo "[HOOK-SERVICE] Cleaning up old deob output..."
        rm -rf /app/output/*

        # Run deobfuscation (uses rules already downloaded to /app/data)
        /app/scripts/run-deob.sh

        # Convert to hooks.json format
        /app/scripts/convert-hooks.sh

        # Save new SHAs
        echo "$NEW_SHA" > /app/data/gamepack.sha256
        echo "$NEW_RULES_SHA" > /app/data/rules.sha256

        echo ""
        echo "[HOOK-SERVICE] *** UPDATE COMPLETE! ***"
        echo "[HOOK-SERVICE] hooks.json available at: /app/data/hooks.json"
        echo ""
    else
        echo "[HOOK-SERVICE] No changes detected (gamepack and rules unchanged)."
    fi
}

# Function to wait until :01 or :31 of the hour
wait_for_schedule() {
    while true; do
        MINUTE=$(date +%M)
        SECOND=$(date +%S)

        # Target: 01 or 31 minutes (1 minute after Jagex's :00/:30)
        if [ "$MINUTE" = "01" ] || [ "$MINUTE" = "31" ]; then
            # We're in the target minute, break out
            break
        fi

        # Calculate seconds until next target
        if [ "$MINUTE" -lt "01" ]; then
            # Wait until :01
            WAIT_MIN=$((1 - MINUTE))
        elif [ "$MINUTE" -lt "31" ]; then
            # Wait until :31
            WAIT_MIN=$((31 - MINUTE))
        else
            # Wait until next hour's :01
            WAIT_MIN=$((61 - MINUTE))
        fi

        WAIT_SEC=$((WAIT_MIN * 60 - SECOND))
        echo "[HOOK-SERVICE] Waiting ${WAIT_SEC}s until next check ($(date -u -d "+${WAIT_SEC} seconds" +%H:%M:%S) UTC)..."
        sleep $WAIT_SEC
    done
}

# === FIRST RUN: Always run immediately on startup ===
echo ""
echo "[HOOK-SERVICE] *** INITIAL STARTUP - Running first check immediately ***"
run_check

# === SCHEDULED LOOP: Wait for :01/:31 after first run ===
while true; do
    # Sleep 60 seconds to avoid re-running in same minute as first run
    sleep 60

    # Wait for scheduled time (:01 or :31)
    wait_for_schedule

    # Run the check
    run_check

    # Sleep 60 seconds to avoid re-running in same minute
    sleep 60
done
