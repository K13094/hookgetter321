package com.betterdeob.core;

public interface Pass {
    String name();
    void run(ClassGroup group, DeobContext ctx) throws Exception;
}
