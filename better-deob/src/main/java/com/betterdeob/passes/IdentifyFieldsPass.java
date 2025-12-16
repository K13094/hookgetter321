package com.betterdeob.passes;

import com.betterdeob.core.*;
import com.betterdeob.features.FieldFeatures;
import com.betterdeob.match.MatchResult;
import com.betterdeob.report.MappingReport;
import com.betterdeob.rules.FieldRule;
import com.betterdeob.rules.Rule;
import com.betterdeob.solve.FieldSolver;

import java.util.*;

public final class IdentifyFieldsPass implements Pass {
    @Override public String name() { return "IdentifyFields"; }

    @Override
    public void run(ClassGroup group, DeobContext ctx) {
        MappingReport report = ctx.report();
        var rules = ctx.rules();
        var idx = ctx.featureIndex();

        if (rules.fieldRules().isEmpty()) {
            System.out.println("No fieldRules; skipping field identification.");
            return;
        }

        List<MatchResult> candidates = new ArrayList<>();

        for (FieldRule fr : rules.fieldRules()) {
            String ownerObf = report.classMappings().get(fr.ownerTarget);
            if (ownerObf == null) continue;

            // Optional owner structural guard
            if (fr.minOwnerFieldDescCounts != null) {
                var ownerCf = idx.of(ownerObf);
                if (ownerCf == null) continue;
                boolean ok = true;
                for (var e : fr.minOwnerFieldDescCounts.entrySet()) {
                    int got = ownerCf.fieldDescCounts().getOrDefault(e.getKey(), 0);
                    if (got < e.getValue()) { ok = false; break; }
                }
                if (!ok) continue;
            }

            List<FieldFeatures> fields = idx.fieldsOf(ownerObf);
            for (FieldFeatures ff : fields) {
                if (!ff.desc().equals(fr.desc)) continue;

                if (fr.isStatic != null && ff.isStatic() != fr.isStatic) continue;
                if (fr.accessMaskAll != null && (ff.access() & fr.accessMaskAll) != fr.accessMaskAll) continue;
                if (fr.accessMaskNone != null && (ff.access() & fr.accessMaskNone) != 0) continue;

                double hitW = 0.0;
                double maxW = 0.0;
                List<String> ev = new ArrayList<>();
                ev.add("ownerTarget=" + fr.ownerTarget + " ownerObf=" + ownerObf);

                for (Rule.Signal s : fr.signals) {
                    double w = (s.weight == null) ? 0.1 : s.weight;
                    maxW += w;

                    boolean hit = switch (String.valueOf(s.kind)) {
                        case "fieldPattern" -> FieldSignals.fieldPattern(ff, s, ev);
                        case "readMin" -> FieldSignals.minCount(ff.readCount(), s.min, "readCount", ev);
                        case "writeMin" -> FieldSignals.minCount(ff.writeCount(), s.min, "writeCount", ev);
                        case "intMultiplierConstEq" -> FieldSignals.multConstEq(ff, s.value, ev);
                        case "intMultiplierConstAny" -> FieldSignals.multConstAny(ff, s.min, ev);
                        default -> false;
                    };

                    if (hit) hitW += w;
                }

                double score = (maxW <= 0.0) ? 0.90 : Math.min(1.0, hitW / maxW);
                score = Math.min(1.0, score * 0.92 + 0.08); // small base

                // Extract decoder multiplier (most common IMUL constant on reads)
                Integer multiplier = extractDominantMultiplier(ff);

                String obfFieldKey = ownerObf + "." + ff.name() + ":" + ff.desc();
                candidates.add(new MatchResult(fr.id, obfFieldKey, score, ev, multiplier));
            }
        }

        double defaultThr = rules.thresholdDefault();
        Map<String, Double> thr = new HashMap<>();
        for (FieldRule fr : rules.fieldRules()) thr.put(fr.id, fr.threshold != null ? fr.threshold : defaultThr);

        FieldSolver.apply(report, candidates, thr);

        System.out.println("Identified fields: " + report.fieldMappings().size());
        System.out.println("Unresolved fields: " + report.unresolvedFieldTargets().size());
    }

    /**
     * Extract the most commonly used IMUL constant for reading this field.
     * This is the "decoder" multiplier used to get the real value.
     * Returns null if no multiplier is detected or field is not an int.
     */
    private static Integer extractDominantMultiplier(FieldFeatures ff) {
        if (!"I".equals(ff.desc())) return null;

        Map<Integer, Integer> readMults = ff.imulConstantsReads();
        if (readMults == null || readMults.isEmpty()) return null;

        // Find the most frequently used multiplier
        Integer dominant = null;
        int maxCount = 0;
        for (var entry : readMults.entrySet()) {
            if (entry.getValue() > maxCount) {
                maxCount = entry.getValue();
                dominant = entry.getKey();
            }
        }

        return dominant;
    }
}
