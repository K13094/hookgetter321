#!/bin/bash
# Runs BetterDeob with OSRS rules

cd /app/better-deob

echo "[DEOB] Running BetterDeob with OSRS rules..."
echo "[DEOB] Input: /app/data/gamepack.jar"
echo "[DEOB] Output: /app/output"

# Rules file (already downloaded by entrypoint.sh)
RULES_FILE="/app/data/osrs-rules.yaml"

if [ -f "$RULES_FILE" ] && [ -s "$RULES_FILE" ]; then
    RULES_LINES=$(wc -l < "$RULES_FILE")
    RULES_SHA=$(sha256sum "$RULES_FILE" | cut -d' ' -f1)
    echo "[DEOB] Using rules file: $RULES_FILE ($RULES_LINES lines, SHA: ${RULES_SHA:0:16}...)"
    ./gradlew run --no-daemon --args="--in /app/data/gamepack.jar --out /app/output --rules $RULES_FILE" 2>&1
else
    echo "[DEOB] WARNING: No rules file at $RULES_FILE, trying local fallback..."
    if [ -f "src/main/resources/osrs-rules.yaml" ]; then
        echo "[DEOB] Using local rules file: src/main/resources/osrs-rules.yaml"
        ./gradlew run --no-daemon --args="--in /app/data/gamepack.jar --out /app/output --rules src/main/resources/osrs-rules.yaml" 2>&1
    else
        echo "[DEOB] No rules file found, running without rules"
        ./gradlew run --no-daemon --args="--in /app/data/gamepack.jar --out /app/output" 2>&1
    fi
fi

if [ $? -eq 0 ]; then
    echo "[DEOB] Deobfuscation complete!"
    # List output files for debugging
    echo "[DEOB] Output files:"
    ls -la /app/output/ 2>/dev/null || echo "[DEOB] No output directory found"
else
    echo "[DEOB] ERROR: Deobfuscation failed"
    exit 1
fi
