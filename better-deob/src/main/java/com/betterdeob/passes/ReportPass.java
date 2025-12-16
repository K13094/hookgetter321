package com.betterdeob.passes;

import com.betterdeob.core.*;
import com.betterdeob.report.MappingReport;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;

public final class ReportPass implements Pass {
    @Override public String name() { return "Report"; }

    @Override
    public void run(ClassGroup group, DeobContext ctx) throws Exception {
        Path out = ctx.outDir();
        Files.createDirectories(out);

        MappingReport report = ctx.report();

        ObjectMapper om = new ObjectMapper().enable(SerializationFeature.INDENT_OUTPUT);

        om.writeValue(out.resolve("mapping_classes.json").toFile(), report.classMappings());
        om.writeValue(out.resolve("mapping_fields.json").toFile(), report.fieldMappings());
        om.writeValue(out.resolve("mapping_multipliers.json").toFile(), report.fieldMultipliers());
        om.writeValue(out.resolve("evidence.json").toFile(), report.evidence());

        var summary = new java.util.LinkedHashMap<String, Object>();
        summary.put("classesInJar", group.size());
        summary.put("mappedClasses", report.classMappings().size());
        summary.put("mappedFields", report.fieldMappings().size());
        summary.put("mappedMultipliers", report.fieldMultipliers().size());
        summary.put("unresolvedClasses", report.unresolvedTargets().size());
        summary.put("unresolvedFields", report.unresolvedFieldTargets().size());
        summary.put("inputJar", ctx.inputJar() == null ? null : ctx.inputJar().toString());
        if (ctx.inputJar() != null) summary.put("inputJarSha256", sha256Hex(Files.readAllBytes(ctx.inputJar())));
        om.writeValue(out.resolve("summary.json").toFile(), summary);

        System.out.println("Wrote mapping_classes.json, mapping_fields.json, mapping_multipliers.json, evidence.json, summary.json");
    }

    private static String sha256Hex(byte[] data) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] dig = md.digest(data);
        StringBuilder sb = new StringBuilder();
        for (byte b : dig) sb.append(String.format("%02x", b));
        return sb.toString();
    }
}
