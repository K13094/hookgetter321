package com.betterdeob.core;

import java.util.ArrayList;
import java.util.List;

public final class Pipeline {
    private final List<Pass> passes = new ArrayList<>();

    public Pipeline add(Pass p) { passes.add(p); return this; }

    public void run(ClassGroup group, DeobContext ctx) throws Exception {
        for (Pass p : passes) {
            long t0 = System.currentTimeMillis();
            System.out.println("== Pass: " + p.name());
            p.run(group, ctx);
            long dt = System.currentTimeMillis() - t0;
            System.out.println("   Done in " + dt + "ms");
        }
    }
}
