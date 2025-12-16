package com.betterdeob.rules;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Field identification rule.
 *
 * ownerTarget: semantic class id this field belongs to (e.g., "Client").
 * desc: JVM field descriptor required (e.g., "I", "J", "Ljava/lang/String;", "[I").
 *
 * Constraints:
 * - isStatic: true/false (optional)
 * - accessMaskAll: bits that must all be present (optional)
 * - accessMaskNone: bits that must be absent (optional)
 *
 * Signals (reuse Rule.Signal):
 * - fieldPattern: value = "DESC|PATTERN" or "PATTERN" (7-token window), min occurrences (default 1)
 * - intMultiplierConstEq: value = "0xDEADBEEF" (unsigned 32-bit) matches if observed IMUL constant equals value
 * - intMultiplierConstAny: min = required occurrences of any IMUL constant seen with reads/writes
 * - readMin / writeMin (min counts)
 */
public final class FieldRule {
    public String id;             // e.g., "Client.localPlayer"
    public String ownerTarget;     // e.g., "Client"
    public String desc;           // e.g., "I"

    public Double threshold;      // optional override

    public Boolean isStatic;      // optional
    public Integer accessMaskAll; // optional
    public Integer accessMaskNone;// optional

    public Map<String, Integer> minOwnerFieldDescCounts; // optional: require owner class has certain field counts

    public List<Rule.Signal> signals = new ArrayList<>();
}
