#!/bin/bash
# OSRS Hook Discovery Service - Main entrypoint
# Handles exit code 99 from download script to trigger container restart

echo "=============================================="
echo "  OSRS Hook Discovery Service"
echo "  Schedule: :01 and :31 of each hour"
echo "  Output: /app/data/hooks.json"
echo "=============================================="

# Create directories if needed
mkdir -p /app/data /app/output

# Function to display hooks.json stats
display_hooks_stats() {
    if [ -f "/app/data/hooks.json" ]; then
        echo ""
        echo "[HOOKS] =============================================="
        echo "[HOOKS] HOOKS.JSON STATISTICS"

        # Count classes and fields using jq
        CLASS_COUNT=$(jq '.classes | keys | length' /app/data/hooks.json 2>/dev/null || echo "?")
        FIELD_COUNT=$(jq '.fields | keys | length' /app/data/hooks.json 2>/dev/null || echo "?")
        FILE_SIZE=$(stat -c%s /app/data/hooks.json 2>/dev/null || echo "?")

        echo "[HOOKS] Classes identified: $CLASS_COUNT"
        echo "[HOOKS] Fields identified: $FIELD_COUNT"
        echo "[HOOKS] File size: $FILE_SIZE bytes"
        echo "[HOOKS] Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "[HOOKS] =============================================="

        # Warnings for low counts
        if [ "$CLASS_COUNT" != "?" ] && [ "$CLASS_COUNT" -lt 10 ]; then
            echo "[HOOKS] WARNING: Only $CLASS_COUNT classes found - might be incomplete!"
        fi
        if [ "$FIELD_COUNT" != "?" ] && [ "$FIELD_COUNT" -lt 100 ]; then
            echo "[HOOKS] WARNING: Only $FIELD_COUNT fields found - might be incomplete!"
        fi
    fi
}

# Function to run the gamepack check and deob
run_check() {
    echo ""
    echo "[HOOK-SERVICE] $(date -u +%Y-%m-%dT%H:%M:%SZ) - Checking for gamepack updates..."

    # Step 1: Download gamepack from Jagex
    /app/scripts/download-gamepack.sh
    DOWNLOAD_EXIT=$?

    # Handle exit code 99 = deletion failed, need to restart container
    if [ $DOWNLOAD_EXIT -eq 99 ]; then
        echo ""
        echo "[FATAL] =============================================="
        echo "[FATAL] Download script returned exit code 99"
        echo "[FATAL] This means file deletion failed (NFS/volume issue)"
        echo "[FATAL] Restarting container to clear state..."
        echo "[FATAL] =============================================="
        sleep 5
        exit 1  # Docker restart policy will restart the container
    fi

    # Handle other download errors
    if [ $DOWNLOAD_EXIT -ne 0 ]; then
        echo "[HOOK-SERVICE] ERROR: Download failed with exit code $DOWNLOAD_EXIT"
        echo "[HOOK-SERVICE] Will retry on next scheduled run"
        return 1
    fi

    # Step 2: Check if gamepack changed
    NEW_SHA=$(sha256sum /app/data/gamepack.jar | cut -d' ' -f1)
    OLD_SHA=$(cat /app/data/gamepack.sha256 2>/dev/null || echo "none")

    echo "[HOOK-SERVICE] Gamepack - Current: ${OLD_SHA:0:16}... New: ${NEW_SHA:0:16}..."

    # Step 3: Fetch rules from GitHub (EVERY RUN, not just on gamepack change)
    RULES_URL="https://raw.githubusercontent.com/K13094/hookgetter321/main/rules/osrs-rules.yaml"
    RULES_FILE="/app/data/osrs-rules.yaml"

    echo "[HOOK-SERVICE] Fetching rules from GitHub..."
    curl -sL --max-time 30 -o "$RULES_FILE" "$RULES_URL"

    if [ -f "$RULES_FILE" ] && [ -s "$RULES_FILE" ]; then
        NEW_RULES_SHA=$(sha256sum "$RULES_FILE" | cut -d' ' -f1)
        OLD_RULES_SHA=$(cat /app/data/rules.sha256 2>/dev/null || echo "none")
        RULES_LINES=$(wc -l < "$RULES_FILE")
        echo "[HOOK-SERVICE] Rules - Current: ${OLD_RULES_SHA:0:16}... New: ${NEW_RULES_SHA:0:16}... ($RULES_LINES lines)"
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
        sync
        sleep 1

        # Run deobfuscation (uses rules already downloaded to /app/data)
        /app/scripts/run-deob.sh

        # Convert to hooks.json format
        /app/scripts/convert-hooks.sh

        # Save new SHAs
        echo "$NEW_SHA" > /app/data/gamepack.sha256
        echo "$NEW_RULES_SHA" > /app/data/rules.sha256

        # Display hooks stats
        display_hooks_stats

        echo ""
        echo "[HOOK-SERVICE] *** UPDATE COMPLETE! ***"
        echo "[HOOK-SERVICE] hooks.json available at: /app/data/hooks.json"
        echo ""
    else
        echo "[HOOK-SERVICE] No changes detected (gamepack and rules unchanged)."

        # Still show current stats
        display_hooks_stats
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
        echo "[HOOK-SERVICE] Waiting ${WAIT_SEC}s until next check ($(date -u -d "+${WAIT_SEC} seconds" +%H:%M:%S 2>/dev/null || echo "soon") UTC)..."
        sleep $WAIT_SEC
    done
}

# === FIRST RUN: Always run immediately on startup ===
echo ""
echo "[HOOK-SERVICE] *** INITIAL STARTUP - Running first check immediately ***"
run_check || true  # Don't exit on first run failure

# === SCHEDULED LOOP: Wait for :01/:31 after first run ===
while true; do
    # Sleep 60 seconds to avoid re-running in same minute as first run
    sleep 60

    # Wait for scheduled time (:01 or :31)
    wait_for_schedule

    # Run the check
    run_check || true  # Don't exit on check failure, continue to next run

    # Sleep 60 seconds to avoid re-running in same minute
    sleep 60
done
