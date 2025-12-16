package com.betterdeob.passes;

import com.betterdeob.core.*;

public final class NormalizePass implements Pass {
    @Override public String name() { return "Normalize"; }

    @Override
    public void run(ClassGroup group, DeobContext ctx) {
        // Conservative starter: no bytecode rewriting.
        // Add transforms later (dead code removal, constant folding, etc.).
        System.out.println("Normalize: no-op (starter).");
    }
}
