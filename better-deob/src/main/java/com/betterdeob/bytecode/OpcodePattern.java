package com.betterdeob.bytecode;

import java.util.Arrays;
import java.util.List;

/**
 * Simple opcode token pattern:
 * - Tokens separated by spaces
 * - "*" matches any single token
 * Example: "GETFIELD * IMUL"
 */
public final class OpcodePattern {
    private final String[] tokens;

    private OpcodePattern(String[] tokens) {
        this.tokens = tokens;
    }

    public static OpcodePattern parse(String pattern) {
        if (pattern == null || pattern.isBlank()) {
            throw new IllegalArgumentException("pattern is blank");
        }
        String[] t = pattern.trim().split("\\s+");
        return new OpcodePattern(t);
    }

    public boolean matches(String candidate) {
        String[] c = candidate.trim().split("\\s+");
        return matches(c);
    }

    public boolean matches(String[] candidateTokens) {
        if (candidateTokens.length != tokens.length) return false;
        for (int i = 0; i < tokens.length; i++) {
            String p = tokens[i];
            if ("*".equals(p)) continue;
            if (!p.equals(candidateTokens[i])) return false;
        }
        return true;
    }

    public int length() { return tokens.length; }

    @Override public String toString() { return String.join(" ", tokens); }
}
