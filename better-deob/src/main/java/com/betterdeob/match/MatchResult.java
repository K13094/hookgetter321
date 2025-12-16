package com.betterdeob.match;

import java.util.List;

public record MatchResult(
        String targetName,
        String obfName,
        double confidence,
        int priority,
        List<String> evidence,
        Integer multiplier
) {
    // Constructor without multiplier (for class matches)
    public MatchResult(String targetName, String obfName, double confidence, List<String> evidence) {
        this(targetName, obfName, confidence, 0, evidence, null);
    }

    // Constructor with priority but no multiplier (for field matches from pythondeob)
    public MatchResult(String targetName, String obfName, double confidence, int priority, List<String> evidence) {
        this(targetName, obfName, confidence, priority, evidence, null);
    }
}
