package com.betterdeob.passes;

import com.betterdeob.core.*;
import com.betterdeob.features.FeatureIndex;

public final class ExtractFeaturesPass implements Pass {
    @Override public String name() { return "ExtractFeatures"; }

    @Override
    public void run(ClassGroup group, DeobContext ctx) {
        int threads = ctx.threads();
        FeatureIndex idx = FeatureIndex.build(group.all(), threads);
        ctx.setFeatureIndex(idx);
        System.out.println("FeatureIndex built for classes: " + idx.size() + " (threads=" + threads + ")");
    }
}
