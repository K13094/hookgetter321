package com.betterdeob.solve;

import com.betterdeob.match.MatchResult;
import com.betterdeob.report.MappingReport;

import java.util.*;

/**
 * Field solver using Hungarian algorithm for optimal 1:1 bipartite matching.
 * Maximizes total confidence across all field assignments.
 */
public final class FieldSolver {
    private FieldSolver() {}

    public static void apply(MappingReport report, List<MatchResult> matches, Map<String, Double> perTargetThreshold) {
        // Phase 1: Filter by threshold and group by owner class
        Map<String, List<MatchResult>> ownerToMatches = new LinkedHashMap<>();
        Map<String, List<MatchResult>> obfToCandidates = new LinkedHashMap<>();

        for (MatchResult m : matches) {
            double thr = perTargetThreshold.getOrDefault(m.targetName(), 0.90);
            if (m.confidence() >= thr) {
                // Group by obfuscated owner class for per-class Hungarian
                String obfOwner = m.obfName().split("\\.")[0];
                ownerToMatches.computeIfAbsent(obfOwner, k -> new ArrayList<>()).add(m);
                obfToCandidates.computeIfAbsent(m.obfName(), k -> new ArrayList<>()).add(m);
            }
        }

        Map<String, MatchResult> obfToWinner = new HashMap<>();
        Set<String> allTargets = new HashSet<>();

        // Phase 2: Run Hungarian algorithm for each owner class
        for (Map.Entry<String, List<MatchResult>> entry : ownerToMatches.entrySet()) {
            String owner = entry.getKey();
            List<MatchResult> ownerMatches = entry.getValue();

            // Build target -> obf -> match mapping
            Map<String, Map<String, MatchResult>> targetToObfMatch = new LinkedHashMap<>();
            Set<String> obfFields = new LinkedHashSet<>();

            for (MatchResult m : ownerMatches) {
                targetToObfMatch
                    .computeIfAbsent(m.targetName(), k -> new LinkedHashMap<>())
                    .put(m.obfName(), m);
                obfFields.add(m.obfName());
                allTargets.add(m.targetName());
            }

            List<String> targetList = new ArrayList<>(targetToObfMatch.keySet());
            List<String> obfList = new ArrayList<>(obfFields);

            int numTargets = targetList.size();
            int numObf = obfList.size();

            if (numTargets == 0 || numObf == 0) continue;

            // Build cost matrix: cost[i][j] = cost of assigning target i to obf j
            // We want max confidence, so cost = 1.0 - confidence
            // Priority is incorporated as a small bonus (higher priority = lower cost)
            double[][] cost = new double[numTargets][numObf];
            double IMPOSSIBLE = 1e9;

            for (int i = 0; i < numTargets; i++) {
                Arrays.fill(cost[i], IMPOSSIBLE);
                String target = targetList.get(i);
                Map<String, MatchResult> obfMatches = targetToObfMatch.get(target);

                for (int j = 0; j < numObf; j++) {
                    String obf = obfList.get(j);
                    MatchResult match = obfMatches.get(obf);
                    if (match != null) {
                        // Cost = 1 - confidence - priority_bonus
                        // Priority bonus: 0.01 per priority point (significant factor)
                        double priorityBonus = match.priority() * 0.01;
                        cost[i][j] = 1.0 - match.confidence() - priorityBonus;
                    }
                }
            }

            // Run Hungarian algorithm
            int[] assignment = hungarian(cost, numTargets, numObf);

            // Process assignments
            for (int i = 0; i < numTargets; i++) {
                int j = assignment[i];
                if (j >= 0 && j < numObf && cost[i][j] < IMPOSSIBLE / 2) {
                    String target = targetList.get(i);
                    String obf = obfList.get(j);
                    MatchResult match = targetToObfMatch.get(target).get(obf);
                    if (match != null) {
                        // Use putFieldWithMultiplier to include multiplier data
                        report.putFieldWithMultiplier(target, obf, match.confidence(), match.evidence(), match.multiplier());
                        obfToWinner.put(obf, match);
                    }
                }
            }
        }

        // Phase 3: Report conflicts
        for (Map.Entry<String, List<MatchResult>> entry : obfToCandidates.entrySet()) {
            List<MatchResult> candidates = entry.getValue();
            if (candidates.size() > 1) {
                String obfField = entry.getKey();
                MatchResult winner = obfToWinner.get(obfField);
                report.addConflict(obfField, candidates, winner, "hungarian algorithm");
            }
        }

        // Phase 4: Mark unresolved targets
        for (String t : allTargets) {
            if (!report.fieldMappings().containsKey(t)) {
                report.addUnresolvedField(t);
            }
        }
    }

    /**
     * Hungarian algorithm for minimum cost assignment (Kuhn-Munkres).
     * Handles rectangular matrices by padding to square.
     *
     * @param cost Cost matrix [numRows][numCols]
     * @param numRows Number of actual rows (targets)
     * @param numCols Number of actual columns (obf fields)
     * @return Assignment array where result[i] = column assigned to row i, or -1 if unassigned
     */
    private static int[] hungarian(double[][] cost, int numRows, int numCols) {
        int n = Math.max(numRows, numCols);

        // Pad to square matrix
        double[][] c = new double[n][n];
        double LARGE = 1e15;

        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
                if (i < numRows && j < numCols) {
                    c[i][j] = cost[i][j];
                } else {
                    c[i][j] = LARGE; // Dummy entries
                }
            }
        }

        // Hungarian algorithm using potential method
        double[] u = new double[n + 1]; // Row potentials
        double[] v = new double[n + 1]; // Column potentials
        int[] p = new int[n + 1];       // p[j] = row assigned to column j
        int[] way = new int[n + 1];     // way[j] = previous column in augmenting path

        Arrays.fill(p, 0);

        for (int i = 1; i <= n; i++) {
            p[0] = i;
            int j0 = 0; // Virtual column
            double[] minv = new double[n + 1];
            boolean[] used = new boolean[n + 1];
            Arrays.fill(minv, Double.MAX_VALUE);
            Arrays.fill(used, false);

            do {
                used[j0] = true;
                int i0 = p[j0];
                double delta = Double.MAX_VALUE;
                int j1 = 0;

                for (int j = 1; j <= n; j++) {
                    if (!used[j]) {
                        double cur = c[i0 - 1][j - 1] - u[i0] - v[j];
                        if (cur < minv[j]) {
                            minv[j] = cur;
                            way[j] = j0;
                        }
                        if (minv[j] < delta) {
                            delta = minv[j];
                            j1 = j;
                        }
                    }
                }

                // Update potentials
                for (int j = 0; j <= n; j++) {
                    if (used[j]) {
                        u[p[j]] += delta;
                        v[j] -= delta;
                    } else {
                        minv[j] -= delta;
                    }
                }

                j0 = j1;
            } while (p[j0] != 0);

            // Augment along the path
            do {
                int j1 = way[j0];
                p[j0] = p[j1];
                j0 = j1;
            } while (j0 != 0);
        }

        // Extract result: assignment[row] = col
        int[] result = new int[numRows];
        Arrays.fill(result, -1);

        for (int j = 1; j <= n; j++) {
            if (p[j] > 0 && p[j] <= numRows && j <= numCols) {
                result[p[j] - 1] = j - 1;
            }
        }

        return result;
    }
}
