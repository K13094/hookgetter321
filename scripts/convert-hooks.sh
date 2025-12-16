#!/bin/bash
# Converts BetterDeob output to RTBot hooks.json format
# Includes validation and statistics

CLASSES_FILE="/app/output/mapping_classes.json"
FIELDS_FILE="/app/output/mapping_fields.json"
MULTIPLIERS_FILE="/app/output/mapping_multipliers.json"
OUTPUT_FILE="/app/data/hooks.json"
TEMP_OUTPUT="/app/data/hooks_temp.json"

echo ""
echo "[CONVERT] =============================================="
echo "[CONVERT] Converting BetterDeob output to hooks.json"
echo "[CONVERT] =============================================="

# List output directory contents
echo ""
echo "[CONVERT] Contents of /app/output/:"
ls -la /app/output/ 2>/dev/null || echo "[CONVERT] Directory doesn't exist or is empty"

# Check input files exist
echo ""
echo "[CONVERT] === CHECKING INPUT FILES ==="

if [ ! -f "$CLASSES_FILE" ]; then
    echo "[CONVERT] ERROR: Missing $CLASSES_FILE"
    exit 1
fi

if [ ! -f "$FIELDS_FILE" ]; then
    echo "[CONVERT] ERROR: Missing $FIELDS_FILE"
    exit 1
fi

# Multipliers file is optional but expected
if [ ! -f "$MULTIPLIERS_FILE" ]; then
    echo "[CONVERT] WARNING: Missing $MULTIPLIERS_FILE - multipliers will be empty"
    echo "{}" > "$MULTIPLIERS_FILE"
fi

CLASSES_SIZE=$(stat -c%s "$CLASSES_FILE" 2>/dev/null || echo "0")
FIELDS_SIZE=$(stat -c%s "$FIELDS_FILE" 2>/dev/null || echo "0")
MULTIPLIERS_SIZE=$(stat -c%s "$MULTIPLIERS_FILE" 2>/dev/null || echo "0")

echo "[CONVERT] mapping_classes.json: $CLASSES_SIZE bytes"
echo "[CONVERT] mapping_fields.json: $FIELDS_SIZE bytes"
echo "[CONVERT] mapping_multipliers.json: $MULTIPLIERS_SIZE bytes"

# Validate input JSON files
echo ""
echo "[CONVERT] === VALIDATING INPUT JSON ==="

if ! jq empty "$CLASSES_FILE" 2>/dev/null; then
    echo "[CONVERT] ERROR: mapping_classes.json is not valid JSON!"
    echo "[CONVERT] Contents:"
    head -20 "$CLASSES_FILE"
    exit 1
fi
echo "[CONVERT] mapping_classes.json: Valid JSON"

if ! jq empty "$FIELDS_FILE" 2>/dev/null; then
    echo "[CONVERT] ERROR: mapping_fields.json is not valid JSON!"
    echo "[CONVERT] Contents:"
    head -20 "$FIELDS_FILE"
    exit 1
fi
echo "[CONVERT] mapping_fields.json: Valid JSON"

if ! jq empty "$MULTIPLIERS_FILE" 2>/dev/null; then
    echo "[CONVERT] ERROR: mapping_multipliers.json is not valid JSON!"
    echo "[CONVERT] Contents:"
    head -20 "$MULTIPLIERS_FILE"
    exit 1
fi
echo "[CONVERT] mapping_multipliers.json: Valid JSON"

# Count items in input files
INPUT_CLASS_COUNT=$(jq 'keys | length' "$CLASSES_FILE" 2>/dev/null || echo "0")
INPUT_FIELD_COUNT=$(jq 'keys | length' "$FIELDS_FILE" 2>/dev/null || echo "0")
INPUT_MULTIPLIER_COUNT=$(jq 'keys | length' "$MULTIPLIERS_FILE" 2>/dev/null || echo "0")
echo "[CONVERT] Input classes: $INPUT_CLASS_COUNT"
echo "[CONVERT] Input fields: $INPUT_FIELD_COUNT"
echo "[CONVERT] Input multipliers: $INPUT_MULTIPLIER_COUNT"

# Generate hooks.json
echo ""
echo "[CONVERT] === GENERATING HOOKS.JSON ==="

jq -n \
  --slurpfile classes "$CLASSES_FILE" \
  --slurpfile fields "$FIELDS_FILE" \
  --slurpfile multipliers "$MULTIPLIERS_FILE" \
  '{
    revision: 0,
    timestamp: (now * 1000 | floor),
    discoveredBy: "BetterDeob-Container",
    classes: $classes[0],
    fields: $fields[0],
    multipliers: $multipliers[0]
  }' > "$TEMP_OUTPUT"

JQ_EXIT=$?

if [ $JQ_EXIT -ne 0 ]; then
    echo "[CONVERT] ERROR: jq failed with exit code $JQ_EXIT"
    rm -f "$TEMP_OUTPUT"
    exit 1
fi

# Validate output JSON
echo ""
echo "[CONVERT] === VALIDATING OUTPUT ==="

if [ ! -f "$TEMP_OUTPUT" ]; then
    echo "[CONVERT] ERROR: Temp output file not created"
    exit 1
fi

if ! jq empty "$TEMP_OUTPUT" 2>/dev/null; then
    echo "[CONVERT] ERROR: Generated hooks.json is not valid JSON!"
    rm -f "$TEMP_OUTPUT"
    exit 1
fi
echo "[CONVERT] Output JSON is valid"

# Count items in output
OUTPUT_CLASS_COUNT=$(jq '.classes | keys | length' "$TEMP_OUTPUT" 2>/dev/null || echo "0")
OUTPUT_FIELD_COUNT=$(jq '.fields | keys | length' "$TEMP_OUTPUT" 2>/dev/null || echo "0")
OUTPUT_MULTIPLIER_COUNT=$(jq '.multipliers | keys | length' "$TEMP_OUTPUT" 2>/dev/null || echo "0")
OUTPUT_SIZE=$(stat -c%s "$TEMP_OUTPUT" 2>/dev/null || echo "0")

# Verify counts match input
if [ "$OUTPUT_CLASS_COUNT" != "$INPUT_CLASS_COUNT" ]; then
    echo "[CONVERT] WARNING: Output class count ($OUTPUT_CLASS_COUNT) != input count ($INPUT_CLASS_COUNT)"
fi

if [ "$OUTPUT_FIELD_COUNT" != "$INPUT_FIELD_COUNT" ]; then
    echo "[CONVERT] WARNING: Output field count ($OUTPUT_FIELD_COUNT) != input count ($INPUT_FIELD_COUNT)"
fi

if [ "$OUTPUT_MULTIPLIER_COUNT" != "$INPUT_MULTIPLIER_COUNT" ]; then
    echo "[CONVERT] WARNING: Output multiplier count ($OUTPUT_MULTIPLIER_COUNT) != input count ($INPUT_MULTIPLIER_COUNT)"
fi

# Move temp to final
echo ""
echo "[CONVERT] === INSTALLING HOOKS.JSON ==="
mv -f "$TEMP_OUTPUT" "$OUTPUT_FILE"
sync

# Final verification
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "[CONVERT] ERROR: Failed to install hooks.json"
    exit 1
fi

FINAL_SIZE=$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "?")

# Display results
echo ""
echo "[CONVERT] =============================================="
echo "[CONVERT] HOOKS.JSON GENERATED SUCCESSFULLY!"
echo "[CONVERT] =============================================="
echo "[CONVERT] Classes: $OUTPUT_CLASS_COUNT"
echo "[CONVERT] Fields: $OUTPUT_FIELD_COUNT"
echo "[CONVERT] Multipliers: $OUTPUT_MULTIPLIER_COUNT"
echo "[CONVERT] File size: $FINAL_SIZE bytes"
echo "[CONVERT] Location: $OUTPUT_FILE"
echo "[CONVERT] =============================================="

# Warnings for potentially incomplete results
if [ "$OUTPUT_CLASS_COUNT" -lt 10 ]; then
    echo ""
    echo "[CONVERT] WARNING: Only $OUTPUT_CLASS_COUNT classes found!"
    echo "[CONVERT] This might indicate incomplete deobfuscation."
fi

if [ "$OUTPUT_FIELD_COUNT" -lt 100 ]; then
    echo ""
    echo "[CONVERT] WARNING: Only $OUTPUT_FIELD_COUNT fields found!"
    echo "[CONVERT] This might indicate incomplete deobfuscation."
fi

# Show preview
echo ""
echo "[CONVERT] === PREVIEW (first 30 lines) ==="
head -30 "$OUTPUT_FILE"
echo ""
echo "[CONVERT] === END PREVIEW ==="
