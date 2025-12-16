package com.betterdeob.rules;

import java.util.ArrayList;
import java.util.List;

public final class RuleSet {
    private double thresholdDefault = 0.90;
    private final List<Rule> classRules = new ArrayList<>();
    private final List<FieldRule> fieldRules = new ArrayList<>();

    public double thresholdDefault() { return thresholdDefault; }
    public void setThresholdDefault(double v) { thresholdDefault = v; }

    public List<Rule> classRules() { return classRules; }
    public List<FieldRule> fieldRules() { return fieldRules; }
}
