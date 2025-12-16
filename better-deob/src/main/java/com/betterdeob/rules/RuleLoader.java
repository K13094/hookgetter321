package com.betterdeob.rules;

import org.yaml.snakeyaml.Yaml;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

public final class RuleLoader {
    private RuleLoader() {}

    public static RuleSet load(Path yamlPath) throws Exception {
        try (InputStream in = Files.newInputStream(yamlPath)) {
            return parse(in);
        }
    }

    public static RuleSet loadFromResource(String resourcePath) throws Exception {
        try (InputStream in = RuleLoader.class.getResourceAsStream(resourcePath)) {
            if (in == null) throw new IllegalArgumentException("Missing resource: " + resourcePath);
            return parse(in);
        }
    }

    @SuppressWarnings("unchecked")
    private static RuleSet parse(InputStream in) {
        Yaml yaml = new Yaml();
        Map<String, Object> root = yaml.load(in);

        RuleSet set = new RuleSet();
        Object td = root.get("thresholdDefault");
        if (td instanceof Number n) set.setThresholdDefault(n.doubleValue());

        Object classRulesObj = root.get("classRules");
        if (classRulesObj instanceof List<?> rulesList) {
            for (Object o : rulesList) {
                Map<String, Object> m = (Map<String, Object>) o;
                Rule r = new Rule();
                r.id = (String) m.get("id");
                r.type = (String) m.getOrDefault("type", "class");

                Object thr = m.get("threshold");
                if (thr instanceof Number n) r.threshold = n.doubleValue();

                r.superName = (String) m.getOrDefault("superName", "*");

                Object ifs = m.get("interfaces");
                if (ifs instanceof List<?> l) r.interfaces = (List<String>) l;

                r.minFieldDescCounts = (Map<String, Integer>) m.get("minFieldDescCounts");
                r.minMethodDescCounts = (Map<String, Integer>) m.get("minMethodDescCounts");

                Object sigs = m.get("signals");
                if (sigs instanceof List<?> sl) {
                    for (Object so : sl) r.signals.add(parseSignal((Map<String, Object>) so));
                }

                set.classRules().add(r);
            }
        }

        Object fieldRulesObj = root.get("fieldRules");
        if (fieldRulesObj instanceof List<?> frl) {
            for (Object o : frl) {
                Map<String, Object> m = (Map<String, Object>) o;
                FieldRule fr = new FieldRule();
                fr.id = (String) m.get("id");
                fr.ownerTarget = (String) m.get("ownerTarget");
                fr.desc = (String) m.get("desc");

                Object thr = m.get("threshold");
                if (thr instanceof Number n) fr.threshold = n.doubleValue();

                Object isStatic = m.get("isStatic");
                if (isStatic instanceof Boolean b) fr.isStatic = b;

                Object ama = m.get("accessMaskAll");
                if (ama instanceof Number n) fr.accessMaskAll = n.intValue();

                Object amn = m.get("accessMaskNone");
                if (amn instanceof Number n) fr.accessMaskNone = n.intValue();

                fr.minOwnerFieldDescCounts = (Map<String, Integer>) m.get("minOwnerFieldDescCounts");

                Object sigs = m.get("signals");
                if (sigs instanceof List<?> sl) {
                    for (Object so : sl) fr.signals.add(parseSignal((Map<String, Object>) so));
                }

                set.fieldRules().add(fr);
            }
        }

        return set;
    }

    private static Rule.Signal parseSignal(Map<String, Object> sm) {
        Rule.Signal s = new Rule.Signal();
        s.kind = (String) sm.get("kind");
        s.value = (String) sm.get("value");
        Object w = sm.get("weight");
        if (w instanceof Number n) s.weight = n.doubleValue();
        Object min = sm.get("min");
        if (min instanceof Number n) s.min = n.intValue();
        return s;
    }
}
