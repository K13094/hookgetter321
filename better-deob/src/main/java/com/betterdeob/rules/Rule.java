package com.betterdeob.rules;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Rule model for identification.
 *
 * Class signals supported:
 * - minLdcStrings (min)
 * - minLdcNumbers (min)
 * - stringHashEq (value = 0x... 64-bit)
 * - opcode3GramHashEq (value = 0x... 64-bit)
 * - fieldPattern (value = "DESC|PATTERN", min=occurrences, "*" wildcard token)
 *
 * Field rules (FieldRule) reuse Signal and support:
 * - fieldPattern
 * - readMin / writeMin
 * - intMultiplierConstEq / intMultiplierConstAny
 */
public final class Rule {
    public String id;
    public String type = "class";
    public Double threshold;

    public String superName = "*";
    public List<String> interfaces = new ArrayList<>();
    public Map<String, Integer> minFieldDescCounts;
    public Map<String, Integer> minMethodDescCounts;

    public List<Signal> signals = new ArrayList<>();

    public static final class Signal {
        public String kind;
        public String value;
        public Double weight;
        public Integer min;
    }
}
