package com.betterdeob.bytecode;

import org.objectweb.asm.util.Printer;

public final class OpcodeNames {
    private OpcodeNames() {}

    public static String name(int opcode) {
        if (opcode < 0) return "NONOP";
        String[] ops = Printer.OPCODES;
        if (opcode >= ops.length) return "OP_" + opcode;
        String n = ops[opcode];
        return (n == null) ? ("OP_" + opcode) : n;
    }
}
