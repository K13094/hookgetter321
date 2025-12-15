#!/bin/bash
# Converts BetterDeob output to RTBot hooks.json format

CLASSES_FILE="/app/output/mapping_classes.json"
FIELDS_FILE="/app/output/mapping_fields.json"
OUTPUT_FILE="/app/data/hooks.json"

echo "[CONVERT] Converting BetterDeob output to hooks.json..."

# Debug: list what's in the output directory
echo "[CONVERT] Contents of /app/output/:"
ls -la /app/output/ 2>/dev/null || echo "[CONVERT] Directory doesn't exist or is empty"

# Debug: show contents of mapping files
echo "[CONVERT] Contents of mapping_classes.json:"
cat "$CLASSES_FILE" 2>/dev/null || echo "(file not found)"
echo ""
echo "[CONVERT] Contents of mapping_fields.json:"
cat "$FIELDS_FILE" 2>/dev/null || echo "(file not found)"
echo ""

if [ ! -f "$CLASSES_FILE" ] || [ ! -f "$FIELDS_FILE" ]; then
    echo "[CONVERT] ERROR: Missing output files from BetterDeob"
    echo "[CONVERT] Expected: $CLASSES_FILE and $FIELDS_FILE"
    exit 1
fi

# Combine class and field mappings into hooks.json
jq -n \
  --slurpfile classes "$CLASSES_FILE" \
  --slurpfile fields "$FIELDS_FILE" \
  '{
    revision: 0,
    timestamp: (now * 1000 | floor),
    discoveredBy: "BetterDeob-Container",
    classes: $classes[0],
    fields: $fields[0]
  }' > "$OUTPUT_FILE"

if [ $? -eq 0 ] && [ -f "$OUTPUT_FILE" ]; then
    SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE" 2>/dev/null)
    echo "[CONVERT] Generated hooks.json (${SIZE} bytes)"
    echo "[CONVERT] Preview:"
    head -20 "$OUTPUT_FILE"
else
    echo "[CONVERT] ERROR: Failed to generate hooks.json"
    exit 1
fi
