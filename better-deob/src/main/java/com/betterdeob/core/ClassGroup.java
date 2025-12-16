package com.betterdeob.core;

import org.objectweb.asm.tree.ClassNode;

import java.util.*;

public final class ClassGroup {
    private final Map<String, ClassNode> classes = new LinkedHashMap<>();

    public void add(ClassNode cn) { classes.put(cn.name, cn); }
    public ClassNode get(String name) { return classes.get(name); }
    public Collection<ClassNode> all() { return classes.values(); }
    public Set<String> names() { return classes.keySet(); }
    public int size() { return classes.size(); }
}
