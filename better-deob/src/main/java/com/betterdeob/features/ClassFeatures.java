package com.betterdeob.features;

import com.betterdeob.bytecode.OpcodeNames;
import org.objectweb.asm.tree.*;

import java.util.*;

/**
 * Per-class extracted features used for matching.
 *
 * High-precision matching is achieved by combining multiple independent signals:
 * - structure (field/method descriptor counts, inheritance, interfaces)
 * - literals (string hash)
 * - bytecode context patterns around field accesses (by field descriptor)
 * - bytecode "style" fingerprint (opcode 3-gram hash)
 */
public record ClassFeatures(
        String name,
        String superName,
        List<String> interfaces,
        int access,
        Map<String, Integer> fieldDescCounts,
        Map<String, Integer> methodDescCounts,
        int totalMethods,
        int totalFields,
        int totalLdcStrings,
        int totalLdcNumbers,
        long stringLiteralHash64,
        long opcode3GramHash64,
        Map<String, Map<String, Integer>> fieldUsagePatternsByDesc
) {
    // Pattern window: 2 opcodes BEFORE field insn + FIELD opcode + next 4 opcodes AFTER (fixed 7 tokens).
    public static final int FIELD_WINDOW_BEFORE = 2;
    public static final int FIELD_WINDOW_AFTER  = 4;
    public static final int FIELD_WINDOW_LEN    = 1 + FIELD_WINDOW_BEFORE + FIELD_WINDOW_AFTER;

    public static ClassFeatures extract(ClassNode cn) {
        Map<String, Integer> fieldDescCounts = new HashMap<>();
        for (FieldNode fn : cn.fields) fieldDescCounts.merge(fn.desc, 1, Integer::sum);

        Map<String, Integer> methodDescCounts = new HashMap<>();
        int ldcStrings = 0, ldcNumbers = 0;

        long strHash = 0xcbf29ce484222325L;     // FNV-1a seed
        long gramHash = 0xcbf29ce484222325L;    // FNV-1a seed

        // Declared fields in this class (name:desc) for local field-usage patterning
        Set<String> declaredFields = new HashSet<>();
        for (FieldNode fn : cn.fields) declaredFields.add(fn.name + ":" + fn.desc);

        Map<String, Map<String, Integer>> patternsByDesc = new HashMap<>();

        for (MethodNode mn : cn.methods) {
            methodDescCounts.merge(mn.desc, 1, Integer::sum);
            if (mn.instructions == null) continue;

            // Build a linear opcode list (skipping non-op nodes) for n-grams + for BEFORE lookup
            List<AbstractInsnNode> opNodes = new ArrayList<>();
            List<Integer> opcodes = new ArrayList<>();
            for (AbstractInsnNode insn = mn.instructions.getFirst(); insn != null; insn = insn.getNext()) {
                int op = insn.getOpcode();
                if (op >= 0) {
                    opNodes.add(insn);
                    opcodes.add(op);
                }

                if (insn instanceof LdcInsnNode ldc) {
                    Object c = ldc.cst;
                    if (c instanceof String s) {
                        ldcStrings++;
                        strHash = fnv1a64(strHash, s);
                    } else if (c instanceof Number) {
                        ldcNumbers++;
                    }
                }
            }

            // opcode 3-gram fingerprint
            for (int i = 0; i + 2 < opcodes.size(); i++) {
                int a = opcodes.get(i), b = opcodes.get(i + 1), c = opcodes.get(i + 2);
                gramHash = fnv1a64(gramHash, a);
                gramHash = fnv1a64(gramHash, b);
                gramHash = fnv1a64(gramHash, c);
            }

            // Field usage patterns (declared fields only)
            for (int i = 0; i < opNodes.size(); i++) {
                AbstractInsnNode insn = opNodes.get(i);
                if (!(insn instanceof FieldInsnNode fin)) continue;
                if (!cn.name.equals(fin.owner)) continue;
                if (!declaredFields.contains(fin.name + ":" + fin.desc)) continue;

                String pat = buildFieldWindow(opNodes, i);
                patternsByDesc
                        .computeIfAbsent(fin.desc, k -> new HashMap<>())
                        .merge(pat, 1, Integer::sum);
            }
        }

        List<String> ifaces = (cn.interfaces == null) ? List.of() : List.copyOf(cn.interfaces);

        Map<String, Map<String, Integer>> frozen = new HashMap<>();
        for (var e : patternsByDesc.entrySet()) frozen.put(e.getKey(), Map.copyOf(e.getValue()));

        return new ClassFeatures(
                cn.name,
                cn.superName,
                ifaces,
                cn.access,
                Map.copyOf(fieldDescCounts),
                Map.copyOf(methodDescCounts),
                cn.methods.size(),
                cn.fields.size(),
                ldcStrings,
                ldcNumbers,
                strHash,
                gramHash,
                Map.copyOf(frozen)
        );
    }

    private static String buildFieldWindow(List<AbstractInsnNode> opNodes, int fieldIndex) {
        List<String> toks = new ArrayList<>(FIELD_WINDOW_LEN);

        // BEFORE padding
        for (int j = fieldIndex - FIELD_WINDOW_BEFORE; j < fieldIndex; j++) {
            if (j < 0) toks.add("NONOP");
            else toks.add(OpcodeNames.name(opNodes.get(j).getOpcode()));
        }

        // FIELD opcode
        toks.add(OpcodeNames.name(opNodes.get(fieldIndex).getOpcode()));

        // AFTER padding
        int afterStart = fieldIndex + 1;
        for (int j = afterStart; j < afterStart + FIELD_WINDOW_AFTER; j++) {
            if (j >= opNodes.size()) toks.add("NONOP");
            else toks.add(OpcodeNames.name(opNodes.get(j).getOpcode()));
        }

        return String.join(" ", toks);
    }

    private static long fnv1a64(long seed, String s) {
        long h = seed;
        for (int i = 0; i < s.length(); i++) {
            h ^= s.charAt(i);
            h *= 0x100000001b3L;
        }
        return h;
    }

    private static long fnv1a64(long seed, int v) {
        long h = seed;
        // 4 bytes little-endian
        h ^= (v & 0xFF); h *= 0x100000001b3L;
        h ^= ((v >>> 8) & 0xFF); h *= 0x100000001b3L;
        h ^= ((v >>> 16) & 0xFF); h *= 0x100000001b3L;
        h ^= ((v >>> 24) & 0xFF); h *= 0x100000001b3L;
        return h;
    }
}
