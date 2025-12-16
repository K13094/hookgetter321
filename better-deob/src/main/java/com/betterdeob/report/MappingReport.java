package com.betterdeob.report;

import com.betterdeob.match.MatchResult;

import java.util.*;

public final class MappingReport {
    private final Map<String, String> classMappings = new TreeMap<>();
    private final Map<String, String> fieldMappings = new TreeMap<>();
    private final Map<String, Integer> fieldMultipliers = new TreeMap<>();
    private final Map<String, Object> evidence = new LinkedHashMap<>();
    private final List<String> unresolvedTargets = new ArrayList<>();
    private final List<String> unresolvedFieldTargets = new ArrayList<>();
    private final List<Map<String, Object>> conflicts = new ArrayList<>();

    public Map<String, String> classMappings() { return classMappings; }
    public Map<String, String> fieldMappings() { return fieldMappings; }
    public Map<String, Integer> fieldMultipliers() { return fieldMultipliers; }
    public Map<String, Object> evidence() { return evidence; }
    public List<String> unresolvedTargets() { return unresolvedTargets; }
    public List<String> unresolvedFieldTargets() { return unresolvedFieldTargets; }
    public List<Map<String, Object>> conflicts() { return conflicts; }

    public void putClass(String target, String obf, double confidence, List<String> ev) {
        classMappings.put(target, obf);
        evidence.put("class:" + target, meta(obf, confidence, ev));
    }

    public void putField(String targetField, String obfField, double confidence, List<String> ev) {
        fieldMappings.put(targetField, obfField);
        evidence.put("field:" + targetField, meta(obfField, confidence, ev));
    }

    public void putFieldWithMultiplier(String targetField, String obfField, double confidence, List<String> ev, Integer multiplier) {
        fieldMappings.put(targetField, obfField);
        if (multiplier != null) {
            fieldMultipliers.put(targetField, multiplier);
        }
        evidence.put("field:" + targetField, meta(obfField, confidence, ev));
    }

    public void addUnresolved(String target) {
        unresolvedTargets.add(target);
        evidence.put("unresolvedClasses", unresolvedTargets);
    }

    public void addUnresolvedField(String target) {
        unresolvedFieldTargets.add(target);
        evidence.put("unresolvedFields", unresolvedFieldTargets);
    }

    @SuppressWarnings("unchecked")
    public void addRejected(MatchResult m, String reason) {
        List<Object> rej = (List<Object>) evidence.computeIfAbsent("rejected", k -> new ArrayList<>());
        Map<String, Object> meta = new LinkedHashMap<>();
        meta.put("target", m.targetName());
        meta.put("obf", m.obfName());
        meta.put("confidence", m.confidence());
        meta.put("reason", reason);
        meta.put("evidence", m.evidence());
        rej.add(meta);
    }

    public void addConflict(String obfField, List<MatchResult> candidates, MatchResult winner, String reason) {
        Map<String, Object> conflict = new LinkedHashMap<>();
        conflict.put("obfField", obfField);

        List<Map<String, Object>> competingTargets = new ArrayList<>();
        for (MatchResult m : candidates) {
            Map<String, Object> c = new LinkedHashMap<>();
            c.put("target", m.targetName());
            c.put("confidence", m.confidence());
            competingTargets.add(c);
        }
        conflict.put("competingTargets", competingTargets);
        conflict.put("winner", winner != null ? winner.targetName() : null);
        conflict.put("reason", reason);

        conflicts.add(conflict);
        evidence.put("conflicts", conflicts);
    }

    private static Map<String, Object> meta(String obf, double confidence, List<String> ev) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("obf", obf);
        m.put("confidence", confidence);
        m.put("evidence", ev);
        return m;
    }
}
