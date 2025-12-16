package com.betterdeob.solve;

import com.betterdeob.match.MatchResult;
import com.betterdeob.report.MappingReport;
import com.betterdeob.rules.Rule;
import com.betterdeob.rules.RuleSet;

import java.util.*;

public final class Solver {
    private Solver() {}

    /**
     * Deterministic solver:
     * - Sort by confidence DESC, then by target name, then by obf name
     * - Assign 1:1 (target -> obf), also preventing obf reuse
     * - Respects per-rule threshold override if provided
     */
    public static MappingReport solve(List<MatchResult> matches, double defaultThreshold, RuleSet rules) {
        Map<String, Double> thresholds = new HashMap<>();
        for (Rule r : rules.classRules()) {
            thresholds.put(r.id, (r.threshold != null) ? r.threshold : defaultThreshold);
        }

        matches.sort(Comparator
                .comparingDouble(MatchResult::confidence).reversed()
                .thenComparing(MatchResult::targetName)
                .thenComparing(MatchResult::obfName)
        );

        MappingReport report = new MappingReport();

        Map<String, MatchResult> bestByTarget = new HashMap<>();
        Map<String, MatchResult> usedByObf = new HashMap<>();

        for (MatchResult m : matches) {
            double thr = thresholds.getOrDefault(m.targetName(), defaultThreshold);
            if (m.confidence() < thr) continue;

            if (bestByTarget.containsKey(m.targetName())) {
                report.addRejected(m, "target already assigned");
                continue;
            }
            if (usedByObf.containsKey(m.obfName())) {
                report.addRejected(m, "obf already used");
                continue;
            }

            bestByTarget.put(m.targetName(), m);
            usedByObf.put(m.obfName(), m);
            report.putClass(m.targetName(), m.obfName(), m.confidence(), m.evidence());
        }

        // unresolved: any target that appeared in candidates but got no assignment
        Set<String> allTargets = new TreeSet<>();
        for (MatchResult m : matches) allTargets.add(m.targetName());
        for (String t : allTargets) {
            if (!report.classMappings().containsKey(t)) report.addUnresolved(t);
        }

        return report;
    }
}
