package com.betterdeob;

import com.betterdeob.cli.CliArgs;
import com.betterdeob.core.*;
import com.betterdeob.passes.*;
import com.betterdeob.rules.*;

import java.nio.file.Path;

public final class Main {
    public static void main(String[] args) throws Exception {
        CliArgs cli = CliArgs.parse(args);

        Path jarPath = cli.inputJar();
        Path outDir  = cli.outputDir();

        RuleSet ruleSet = (cli.rulesPath() != null)
                ? RuleLoader.load(cli.rulesPath())
                : RuleLoader.loadFromResource("/default-rules.yaml");

        ClassGroup group = JarLoader.load(jarPath);

        DeobContext ctx = new DeobContext(outDir, ruleSet);
        ctx.setInputJar(jarPath);
        ctx.setThreads(cli.threads());

        Pipeline pipeline = new Pipeline()
                .add(new NormalizePass())
                .add(new ExtractFeaturesPass())
                .add(new IdentifyPass())
                .add(new IdentifyFieldsPass())
                .add(new ReportPass());

        pipeline.run(group, ctx);

        System.out.println("Done. Output in: " + outDir.toAbsolutePath());
    }
}
