#!/bin/bash
# Converts BetterDeob output to RTBot hooks.json format

CLASSES_FILE="/app/output/mapping_classes.json"
FIELDS_FILE="/app/output/mapping_fields.json"
OUTPUT_FILE="/app/data/hooks.json"

echo "[CONVERT] Converting BetterDeob output to hooks.json..."

if [ ! -f "$CLASSES_FILE" ] || [ ! -f "$FIELDS_FILE" ]; then
    echo "[CONVERT] ERROR: Missing output files from BetterDeob"
    echo "[CONVERT] Expected: $CLASSES_FILE and $FIELDS_FILE"
    exit 1
fi

# Use jq to merge and transform
jq -n \
  --slurpfile classes "$CLASSES_FILE" \
  --slurpfile fields "$FIELDS_FILE" \
  '{
    revision: 0,
    timestamp: (now * 1000 | floor),
    discoveredBy: "BetterDeob-Container",
    classes: $classes[0],
    hooks: (
      $fields[0] | to_entries | map({
        key: (.key | split(".")[1]),
        value: {
          name: (.key | split(".")[1]),
          className: (.value | split(":")[0] | split(".")[0]),
          fieldName: (.value | split(":")[0] | split(".")[1]),
          fieldType: (.value | split(":")[1]),
          isStatic: ((.key | split(".")[0]) == "Client"),
          multiplier: 1
        }
      }) | from_entries
    )
  }' > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    HOOK_COUNT=$(jq '.hooks | length' "$OUTPUT_FILE")
    CLASS_COUNT=$(jq '.classes | length' "$OUTPUT_FILE")
    echo "[CONVERT] Generated hooks.json with $CLASS_COUNT classes and $HOOK_COUNT hooks"
else
    echo "[CONVERT] ERROR: Failed to generate hooks.json"
    exit 1
fi
