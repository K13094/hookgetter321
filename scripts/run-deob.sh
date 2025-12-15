#!/bin/bash
# Runs BetterDeob with OSRS rules

cd /app/better-deob

echo "[DEOB] Running BetterDeob with OSRS rules..."
echo "[DEOB] Input: /app/data/gamepack.jar"
echo "[DEOB] Output: /app/output"

# BetterDeob uses --in and --out (not -i and -o)
./gradlew run --no-daemon --args="--in /app/data/gamepack.jar --out /app/output" 2>&1

if [ $? -eq 0 ]; then
    echo "[DEOB] Deobfuscation complete!"
    # List output files for debugging
    echo "[DEOB] Output files:"
    ls -la /app/output/ 2>/dev/null || echo "[DEOB] No output directory found"
else
    echo "[DEOB] ERROR: Deobfuscation failed"
    exit 1
fi
