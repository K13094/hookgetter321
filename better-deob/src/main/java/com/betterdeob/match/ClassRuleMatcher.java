package com.betterdeob.match;

import com.betterdeob.bytecode.OpcodePattern;
import com.betterdeob.features.ClassFeatures;
import com.betterdeob.features.FeatureIndex;
import com.betterdeob.rules.Rule;
import com.betterdeob.rules.RuleSet;
import org.objectweb.asm.tree.ClassNode;

import java.util.*;

public final class ClassRuleMatcher {
    private final RuleSet rules;

    public ClassRuleMatcher(RuleSet rules) {
        this.rules = rules;
    }

    public List<MatchResult> matchAll(ClassNode cn, FeatureIndex idx) {
        ClassFeatures f = idx.of(cn);
        if (f == null) return List.of();

        List<MatchResult> out = new ArrayList<>();
        for (Rule r : rules.classRules()) {
            if (!"class".equalsIgnoreCase(r.type)) continue;

            List<String> ev = new ArrayList<>();
            if (!passesConstraints(r, f, ev)) continue;

            double score = 0.0;
            double max = 0.0;

            if (r.signals != null) {
                for (Rule.Signal s : r.signals) {
                    double w = (s.weight == null) ? 0.1 : s.weight;
                    max += w;

                    boolean hit = switch (String.valueOf(s.kind)) {
                        case "minLdcStrings" -> minAtLeast(f.totalLdcStrings(), s.min, "totalLdcStrings", ev);
                        case "minLdcNumbers" -> minAtLeast(f.totalLdcNumbers(), s.min, "totalLdcNumbers", ev);
                        case "stringHashEq" -> hashEq64(f.stringLiteralHash64(), s.value, "stringLiteralHash64", ev);
                        case "opcode3GramHashEq" -> hashEq64(f.opcode3GramHash64(), s.value, "opcode3GramHash64", ev);
                        case "fieldPattern" -> fieldPatternHit(f, s, ev);
                        default -> false;
                    };

                    if (hit) score += w;
                }
            }

            // Confidence is normalized score; strong constraints help but don't let weak signals pass.
            double conf = (max <= 0.0) ? 0.90 : clamp01(score / max);
            conf = clamp01(conf * 0.93 + structuralBonus(r) * 0.07);

            out.add(new MatchResult(r.id, cn.name, conf, ev));
        }

        return out;
    }

    /**
     * fieldPattern signal:
     * value: "DESC|PATTERN"
     * Pattern tokens must match the fixed window length used by ClassFeatures:
     *  - 2 BEFORE + FIELD + 4 AFTER  => 7 tokens
     * "*" matches any token.
     */
    private boolean fieldPatternHit(ClassFeatures f, Rule.Signal s, List<String> ev) {
        if (s.value == null || s.value.isBlank()) return false;

        String[] parts = s.value.split("\\|", 2);
        if (parts.length != 2) return false;

        String desc = parts[0].trim();
        String patStr = parts[1].trim();
        int min = (s.min == null) ? 1 : s.min;

        OpcodePattern pat;
        try { pat = OpcodePattern.parse(patStr); }
        catch (Exception ex) { return false; }

        Map<String, Integer> patterns = f.fieldUsagePatternsByDesc().get(desc);
        if (patterns == null || patterns.isEmpty()) return false;

        int hits = 0;
        for (var e : patterns.entrySet()) {
            if (pat.matches(e.getKey())) hits += e.getValue();
        }

        if (hits >= min) {
            ev.add("fieldPattern hit desc=" + desc + " pattern=\"" + pat + "\" hits=" + hits);
            return true;
        }
        return false;
    }

    private boolean passesConstraints(Rule r, ClassFeatures f, List<String> ev) {
        if (r.superName != null && !"*".equals(r.superName)) {
            if (!r.superName.equals(f.superName())) return false;
            ev.add("superName matches: " + r.superName);
        }

        if (r.interfaces != null && !r.interfaces.isEmpty()) {
            for (String i : r.interfaces) {
                if (!f.interfaces().contains(i)) return false;
            }
            ev.add("interfaces contain: " + r.interfaces);
        }

        if (r.minFieldDescCounts != null) {
            if (!minCountsOk("field", r.minFieldDescCounts, f.fieldDescCounts(), ev)) return false;
        }
        if (r.minMethodDescCounts != null) {
            if (!minCountsOk("method", r.minMethodDescCounts, f.methodDescCounts(), ev)) return false;
        }
        return true;
    }

    private double structuralBonus(Rule r) {
        double b = 0.0;
        if (r.minFieldDescCounts != null && !r.minFieldDescCounts.isEmpty()) b += 0.5;
        if (r.minMethodDescCounts != null && !r.minMethodDescCounts.isEmpty()) b += 0.5;
        if (r.interfaces != null && !r.interfaces.isEmpty()) b += 0.5;
        if (r.superName != null && !"*".equals(r.superName)) b += 0.5;
        return Math.min(1.0, b / 2.0);
    }

    private boolean minCountsOk(String label, Map<String, Integer> req, Map<String, Integer> have, List<String> ev) {
        for (var e : req.entrySet()) {
            int got = have.getOrDefault(e.getKey(), 0);
            if (got < e.getValue()) return false;
            ev.add(label + " desc count ok: " + e.getKey() + " >= " + e.getValue() + " (got " + got + ")");
        }
        return true;
    }

    private boolean minAtLeast(int got, Integer min, String what, List<String> ev) {
        int m = (min == null) ? 1 : min;
        if (got >= m) {
            ev.add(what + " >= " + m + " (got " + got + ")");
            return true;
        }
        return false;
    }

    private boolean hashEq64(long actual, String hex, String label, List<String> ev) {
        if (hex == null || hex.isBlank()) return false;
        long target;
        try {
            String h = hex.startsWith("0x") ? hex.substring(2) : hex;
            target = Long.parseUnsignedLong(h, 16);
        } catch (NumberFormatException nfe) { return false; }

        if (actual == target) {
            ev.add(label + " matches: 0x" + Long.toHexString(target));
            return true;
        }
        return false;
    }

    private double clamp01(double v) {
        if (v < 0) return 0;
        if (v > 1) return 1;
        return v;
    }
}
