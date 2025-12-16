package com.betterdeob.cli;

import java.nio.file.Path;
import java.nio.file.Paths;

public final class CliArgs {
    private final Path inputJar;
    private final Path outputDir;
    private final Path rulesPath;
    private final int threads;

    private CliArgs(Path inputJar, Path outputDir, Path rulesPath, int threads) {
        this.inputJar = inputJar;
        this.outputDir = outputDir;
        this.rulesPath = rulesPath;
        this.threads = threads;
    }

    public Path inputJar() { return inputJar; }
    public Path outputDir() { return outputDir; }
    public Path rulesPath() { return rulesPath; }
    public int threads() { return threads; }

    public static CliArgs parse(String[] args) {
        Path in = null;
        Path out = Paths.get("out");
        Path rules = null;
        int threads = Math.max(1, Runtime.getRuntime().availableProcessors() - 1);

        for (int i = 0; i < args.length; i++) {
            String a = args[i];
            switch (a) {
                case "--in" -> in = Paths.get(requireNext(args, ++i, "--in requires a path"));
                case "--out" -> out = Paths.get(requireNext(args, ++i, "--out requires a path"));
                case "--rules" -> rules = Paths.get(requireNext(args, ++i, "--rules requires a path"));
                case "--threads" -> threads = Integer.parseInt(requireNext(args, ++i, "--threads requires a number"));
                case "--help" -> { printHelpAndExit(); return null; }
                default -> { System.err.println("Unknown arg: " + a); printHelpAndExit(); return null; }
            }
        }

        if (in == null) {
            System.err.println("Missing required --in <jar>");
            printHelpAndExit();
        }

        if (threads < 1) threads = 1;
        return new CliArgs(in, out, rules, threads);
    }

    private static String requireNext(String[] args, int idx, String err) {
        if (idx >= args.length) throw new IllegalArgumentException(err);
        return args[idx];
    }

    private static void printHelpAndExit() {
        System.out.println("""
                better-deob (starter)

                Usage:
                  gradle run --args="--in gamepack.jar [--out outDir] [--rules rules.yaml] [--threads N]"

                Output:
                  out/mapping.json
                  out/evidence.json
                  out/summary.json

                Notes:
                  - This is a conservative static analysis / mapping foundation.
                  - Add rules/matchers to increase precision.
                """);
        System.exit(0);
    }
}
