package com.betterdeob.solve;

import com.betterdeob.match.MatchResult;
import com.betterdeob.report.MappingReport;

import java.util.*;

public final class FieldSolver {
    private FieldSolver() {}

    public static void apply(MappingReport report, List<MatchResult> matches, Map<String, Double> perTargetThreshold) {
        matches.sort(Comparator
                .comparingDouble(MatchResult::confidence).reversed()
                .thenComparing(MatchResult::targetName)
                .thenComparing(MatchResult::obfName)
        );

        Set<String> usedObf = new HashSet<>();
        Set<String> usedTarget = new HashSet<>();

        for (MatchResult m : matches) {
            double thr = perTargetThreshold.getOrDefault(m.targetName(), 0.90);
            if (m.confidence() < thr) continue;

            if (usedTarget.contains(m.targetName())) {
                report.addRejected(m, "field target already assigned");
                continue;
            }
            if (usedObf.contains(m.obfName())) {
                report.addRejected(m, "obf field already used");
                continue;
            }

            usedTarget.add(m.targetName());
            usedObf.add(m.obfName());
            report.putFieldWithMultiplier(m.targetName(), m.obfName(), m.confidence(), m.evidence(), m.multiplier());
        }

        Set<String> allTargets = new TreeSet<>();
        for (MatchResult m : matches) allTargets.add(m.targetName());
        for (String t : allTargets) if (!report.fieldMappings().containsKey(t)) report.addUnresolvedField(t);
    }
}
