#!/bin/bash
# Converts BetterDeob output to RTBot hooks.json format

MAPPING_FILE="/app/output/mapping.json"
OUTPUT_FILE="/app/data/hooks.json"

echo "[CONVERT] Converting BetterDeob output to hooks.json..."
echo "[CONVERT] Looking for: $MAPPING_FILE"

# Debug: list what's in the output directory
echo "[CONVERT] Contents of /app/output/:"
ls -la /app/output/ 2>/dev/null || echo "[CONVERT] Directory doesn't exist or is empty"

if [ ! -f "$MAPPING_FILE" ]; then
    echo "[CONVERT] ERROR: Missing mapping.json from BetterDeob"
    echo "[CONVERT] Expected: $MAPPING_FILE"
    exit 1
fi

echo "[CONVERT] Found mapping.json, converting..."

# Copy the mapping.json directly as hooks.json with metadata wrapper
# BetterDeob's mapping.json is already in a usable format
jq '{
    revision: 0,
    timestamp: (now * 1000 | floor),
    discoveredBy: "BetterDeob-Container",
    mapping: .
}' "$MAPPING_FILE" > "$OUTPUT_FILE"

if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null)
    echo "[CONVERT] Generated hooks.json (${SIZE} bytes)"
    echo "[CONVERT] Preview:"
    head -20 "$OUTPUT_FILE"
else
    echo "[CONVERT] ERROR: Failed to generate hooks.json"
    exit 1
fi
