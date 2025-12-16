package com.betterdeob.core;

import com.betterdeob.features.FeatureIndex;
import com.betterdeob.report.MappingReport;
import com.betterdeob.rules.RuleSet;

import java.nio.file.Path;

public final class DeobContext {
    private final Path outDir;
    private final RuleSet rules;
    private Path inputJar;
    private int threads = Math.max(1, Runtime.getRuntime().availableProcessors() - 1);

    private FeatureIndex featureIndex;
    private MappingReport report = new MappingReport();

    public DeobContext(Path outDir, RuleSet rules) {
        this.outDir = outDir;
        this.rules = rules;
    }

    public Path outDir() { return outDir; }
    public RuleSet rules() { return rules; }
    public Path inputJar() { return inputJar; }
    public void setInputJar(Path inputJar) { this.inputJar = inputJar; }

    public int threads() { return threads; }
    public void setThreads(int threads) { this.threads = Math.max(1, threads); }

    public FeatureIndex featureIndex() { return featureIndex; }
    public void setFeatureIndex(FeatureIndex featureIndex) { this.featureIndex = featureIndex; }

    public MappingReport report() { return report; }
    public void setReport(MappingReport report) { this.report = report; }
}
