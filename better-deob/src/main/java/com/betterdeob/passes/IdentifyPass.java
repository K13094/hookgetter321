package com.betterdeob.passes;

import com.betterdeob.core.*;
import com.betterdeob.match.ClassRuleMatcher;
import com.betterdeob.match.MatchResult;
import com.betterdeob.report.MappingReport;
import com.betterdeob.solve.Solver;

import java.util.ArrayList;
import java.util.List;

public final class IdentifyPass implements Pass {
    @Override public String name() { return "Identify"; }

    @Override
    public void run(ClassGroup group, DeobContext ctx) {
        var idx = ctx.featureIndex();
        var rules = ctx.rules();

        ClassRuleMatcher matcher = new ClassRuleMatcher(rules);
        List<MatchResult> all = new ArrayList<>(group.size() * Math.max(1, rules.classRules().size()));

        group.all().forEach(cn -> all.addAll(matcher.matchAll(cn, idx)));

        MappingReport report = Solver.solve(all, rules.thresholdDefault(), rules);
        ctx.setReport(report);

        System.out.println("Identified targets: " + report.classMappings().size());
        System.out.println("Unresolved targets: " + report.unresolvedTargets().size());
    }
}
