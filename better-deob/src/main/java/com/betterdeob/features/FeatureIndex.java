package com.betterdeob.features;

import org.objectweb.asm.tree.ClassNode;

import java.util.*;
import java.util.concurrent.*;

public final class FeatureIndex {
    private final Map<String, ClassFeatures> classFeatures;
    private final Map<String, List<FieldFeatures>> fieldFeaturesByOwner;

    private FeatureIndex(Map<String, ClassFeatures> classFeatures, Map<String, List<FieldFeatures>> fieldFeaturesByOwner) {
        this.classFeatures = classFeatures;
        this.fieldFeaturesByOwner = fieldFeaturesByOwner;
    }

    public ClassFeatures of(String internalName) { return classFeatures.get(internalName); }
    public ClassFeatures of(ClassNode cn) { return classFeatures.get(cn.name); }

    public List<FieldFeatures> fieldsOf(String ownerInternalName) {
        return fieldFeaturesByOwner.getOrDefault(ownerInternalName, List.of());
    }

    public int size() { return classFeatures.size(); }

    public static FeatureIndex build(Collection<ClassNode> classes, int threads) {
        Map<String, ClassFeatures> clsMap = new ConcurrentHashMap<>();
        Map<String, List<FieldFeatures>> fldMap = new ConcurrentHashMap<>();

        ExecutorService pool = Executors.newFixedThreadPool(Math.max(1, threads));
        try {
            List<Future<?>> futures = new ArrayList<>();
            for (ClassNode cn : classes) {
                futures.add(pool.submit(() -> {
                    clsMap.put(cn.name, ClassFeatures.extract(cn));
                    fldMap.put(cn.name, FieldFeatures.extractAll(cn));
                }));
            }
            for (Future<?> f : futures) {
                try { f.get(); } catch (ExecutionException ee) { throw new RuntimeException(ee.getCause()); }
            }
        } catch (InterruptedException ie) {
            Thread.currentThread().interrupt();
            throw new RuntimeException(ie);
        } finally {
            pool.shutdownNow();
        }

        return new FeatureIndex(new TreeMap<>(clsMap), new TreeMap<>(fldMap));
    }
}
