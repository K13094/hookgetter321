package com.betterdeob.passes;

import com.betterdeob.bytecode.OpcodePattern;
import com.betterdeob.features.FieldFeatures;

import java.util.List;

public final class FieldSignals {
    private FieldSignals() {}

    public static boolean fieldPattern(FieldFeatures ff, com.betterdeob.rules.Rule.Signal s, List<String> ev) {
        if (s.value == null || s.value.isBlank()) return false;
        String patStr = s.value;
        int pipe = patStr.indexOf('|');
        if (pipe >= 0) patStr = patStr.substring(pipe + 1).trim();

        OpcodePattern pat;
        try { pat = OpcodePattern.parse(patStr); } catch (Exception ex) { return false; }

        int hits = 0;
        for (var e : ff.usagePatterns().entrySet()) if (pat.matches(e.getKey())) hits += e.getValue();
        int min = (s.min == null) ? 1 : s.min;
        if (hits >= min) {
            ev.add("fieldPattern hit pattern=\"" + pat + "\" hits=" + hits);
            return true;
        }
        return false;
    }

    public static boolean minCount(int got, Integer min, String label, List<String> ev) {
        int m = (min == null) ? 1 : min;
        if (got >= m) {
            ev.add(label + " >= " + m + " (got " + got + ")");
            return true;
        }
        return false;
    }

    public static boolean multConstEq(FieldFeatures ff, String hexOrDec, List<String> ev) {
        Integer target = parseInt32(hexOrDec);
        if (target == null) return false;

        int hits = ff.imulConstantsReads().getOrDefault(target, 0) + ff.imulConstantsWrites().getOrDefault(target, 0);
        if (hits > 0) {
            ev.add("imulConstEq hit: " + toHex(target) + " hits=" + hits);
            return true;
        }
        return false;
    }

    public static boolean multConstAny(FieldFeatures ff, Integer min, List<String> ev) {
        int m = (min == null) ? 1 : min;
        int total = 0;
        for (int v : ff.imulConstantsReads().values()) total += v;
        for (int v : ff.imulConstantsWrites().values()) total += v;
        if (total >= m) {
            ev.add("imulConstAny >= " + m + " (got " + total + ")");
            return true;
        }
        return false;
    }

    private static Integer parseInt32(String s) {
        if (s == null || s.isBlank()) return null;
        try {
            String t = s.trim().toLowerCase();
            long v = t.startsWith("0x") ? Long.parseUnsignedLong(t.substring(2), 16) : Long.parseLong(t);
            return (int) v;
        } catch (Exception e) {
            return null;
        }
    }

    private static String toHex(int v) {
        return "0x" + Integer.toHexString(v);
    }
}
