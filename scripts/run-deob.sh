#!/bin/bash
# Runs BetterDeob with OSRS rules

cd /app/better-deob

echo "[DEOB] Running BetterDeob with OSRS rules..."
echo "[DEOB] Input: /app/data/gamepack.jar"
echo "[DEOB] Output: /app/output"

./gradlew run --no-daemon --args="-i /app/data/gamepack.jar -o /app/output --rules src/main/resources/osrs-rules.yaml" 2>&1

if [ $? -eq 0 ]; then
    echo "[DEOB] Deobfuscation complete!"
else
    echo "[DEOB] ERROR: Deobfuscation failed"
    exit 1
fi
