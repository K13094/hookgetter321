package com.betterdeob.features;

import com.betterdeob.bytecode.OpcodeNames;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.*;

import java.util.*;

/**
 * Features for a single field declared in a class.
 */
public record FieldFeatures(
        String owner,
        String name,
        String desc,
        int access,
        boolean isStatic,
        int readCount,
        int writeCount,
        Map<String, Integer> usagePatterns,
        Map<Integer, Integer> imulConstantsReads,
        Map<Integer, Integer> imulConstantsWrites
) {
    public static List<FieldFeatures> extractAll(ClassNode ownerCn) {
        List<FieldNode> fields = ownerCn.fields;

        class Acc {
            int reads = 0, writes = 0;
            Map<String, Integer> patterns = new HashMap<>();
            Map<Integer, Integer> imulRead = new HashMap<>();
            Map<Integer, Integer> imulWrite = new HashMap<>();
        }

        Map<String, FieldNode> byKey = new HashMap<>();
        Map<String, Acc> acc = new HashMap<>();
        for (FieldNode fn : fields) {
            String key = fn.name + ":" + fn.desc;
            byKey.put(key, fn);
            acc.put(key, new Acc());
        }

        for (MethodNode mn : ownerCn.methods) {
            if (mn.instructions == null) continue;

            List<AbstractInsnNode> opNodes = new ArrayList<>();
            for (AbstractInsnNode insn = mn.instructions.getFirst(); insn != null; insn = insn.getNext()) {
                if (insn.getOpcode() >= 0) opNodes.add(insn);
            }

            for (int i = 0; i < opNodes.size(); i++) {
                AbstractInsnNode insn = opNodes.get(i);
                if (!(insn instanceof FieldInsnNode fin)) continue;
                if (!ownerCn.name.equals(fin.owner)) continue;

                String key = fin.name + ":" + fin.desc;
                Acc a = acc.get(key);
                if (a == null) continue;

                boolean isRead = (fin.getOpcode() == Opcodes.GETFIELD || fin.getOpcode() == Opcodes.GETSTATIC);
                boolean isWrite = (fin.getOpcode() == Opcodes.PUTFIELD || fin.getOpcode() == Opcodes.PUTSTATIC);
                if (isRead) a.reads++;
                if (isWrite) a.writes++;

                String pat = buildWindow(opNodes, i, 2, 4);
                a.patterns.merge(pat, 1, Integer::sum);

                if ("I".equals(fin.desc)) {
                    if (isRead) {
                        Integer c = findImulConstAfter(opNodes, i, 6);
                        if (c != null) a.imulRead.merge(c, 1, Integer::sum);
                    }
                    if (isWrite) {
                        Integer c = findImulConstBefore(opNodes, i, 6);
                        if (c != null) a.imulWrite.merge(c, 1, Integer::sum);
                    }
                }
            }
        }

        List<FieldFeatures> out = new ArrayList<>();
        for (FieldNode fn : fields) {
            String key = fn.name + ":" + fn.desc;
            Acc a = acc.get(key);
            out.add(new FieldFeatures(
                    ownerCn.name,
                    fn.name,
                    fn.desc,
                    fn.access,
                    (fn.access & Opcodes.ACC_STATIC) != 0,
                    a.reads,
                    a.writes,
                    Map.copyOf(a.patterns),
                    Map.copyOf(a.imulRead),
                    Map.copyOf(a.imulWrite)
            ));
        }
        return out;
    }

    private static String buildWindow(List<AbstractInsnNode> opNodes, int idx, int before, int after) {
        int len = 1 + before + after;
        List<String> toks = new ArrayList<>(len);
        for (int j = idx - before; j < idx; j++) toks.add(j < 0 ? "NONOP" : OpcodeNames.name(opNodes.get(j).getOpcode()));
        toks.add(OpcodeNames.name(opNodes.get(idx).getOpcode()));
        int start = idx + 1;
        for (int j = start; j < start + after; j++) toks.add(j >= opNodes.size() ? "NONOP" : OpcodeNames.name(opNodes.get(j).getOpcode()));
        return String.join(" ", toks);
    }

    private static Integer findImulConstAfter(List<AbstractInsnNode> opNodes, int fromIdx, int maxLookahead) {
        int end = Math.min(opNodes.size(), fromIdx + 1 + maxLookahead);
        for (int i = fromIdx + 1; i < end; i++) {
            if (opNodes.get(i).getOpcode() == Opcodes.IMUL) {
                for (int j = i - 1; j >= Math.max(fromIdx, i - 4); j--) {
                    Integer c = readIntConst(opNodes.get(j));
                    if (c != null) return c;
                }
            }
        }
        return null;
    }

    private static Integer findImulConstBefore(List<AbstractInsnNode> opNodes, int fieldPutIdx, int maxLookback) {
        int start = Math.max(0, fieldPutIdx - maxLookback);
        for (int i = fieldPutIdx - 1; i >= start; i--) {
            if (opNodes.get(i).getOpcode() == Opcodes.IMUL) {
                for (int j = i - 1; j >= Math.max(start, i - 4); j--) {
                    Integer c = readIntConst(opNodes.get(j));
                    if (c != null) return c;
                }
            }
        }
        return null;
    }

    private static Integer readIntConst(AbstractInsnNode insn) {
        int op = insn.getOpcode();
        if (op >= Opcodes.ICONST_M1 && op <= Opcodes.ICONST_5) return op - Opcodes.ICONST_0;
        if (op == Opcodes.BIPUSH || op == Opcodes.SIPUSH) return ((IntInsnNode) insn).operand;
        if (insn instanceof LdcInsnNode ldc && ldc.cst instanceof Integer i) return i;
        return null;
    }
}
