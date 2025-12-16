package com.betterdeob.match;

import java.util.List;

public record MatchResult(
        String targetName,
        String obfName,
        double confidence,
        List<String> evidence,
        Integer multiplier
) {
    // Constructor without multiplier (for class matches)
    public MatchResult(String targetName, String obfName, double confidence, List<String> evidence) {
        this(targetName, obfName, confidence, evidence, null);
    }
}
