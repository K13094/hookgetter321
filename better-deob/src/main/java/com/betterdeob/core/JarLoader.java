package com.betterdeob.core;

import org.objectweb.asm.ClassReader;
import org.objectweb.asm.tree.ClassNode;

import java.io.InputStream;
import java.nio.file.Path;
import java.util.Enumeration;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

public final class JarLoader {
    private JarLoader() {}

    public static ClassGroup load(Path jarPath) throws Exception {
        ClassGroup group = new ClassGroup();

        try (JarFile jar = new JarFile(jarPath.toFile())) {
            Enumeration<JarEntry> entries = jar.entries();
            while (entries.hasMoreElements()) {
                JarEntry e = entries.nextElement();
                if (!e.getName().endsWith(".class")) continue;

                try (InputStream in = jar.getInputStream(e)) {
                    ClassReader cr = new ClassReader(in);
                    ClassNode cn = new ClassNode();
                    // Keep debug info; skip frames for speed. Add SKIP_DEBUG if you want smaller memory.
                    cr.accept(cn, ClassReader.SKIP_FRAMES);
                    group.add(cn);
                }
            }
        }

        System.out.println("Loaded classes: " + group.size());
        return group;
    }
}
