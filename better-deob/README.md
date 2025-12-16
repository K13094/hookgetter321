# better-deob (starter)

A conservative, rule-driven bytecode analysis + deobfuscation *foundation* using ASM.

This project is intentionally generic:
- Loads a target JAR
- Builds a fast feature index (parallelized)
- Runs YAML rules to propose mappings with confidence + evidence
- Solves 1:1 mappings deterministically
- Writes JSON outputs

It **does not** ship OSRS-specific hook logic. You extend it by adding rules/matchers.

## Requirements
- Java 17+
- Gradle 8+ (or use the Gradle wrapper you generate locally)

## Quick start

```bash
# from project root
gradle build
gradle run --args="--in /path/to/target.jar --out out"
```

Outputs:
- `out/mapping.json`  (targetName -> obfInternalName)
- `out/evidence.json` (why a match was chosen / rejected)
- `out/summary.json`  (counts + sha256 of input jar)

## Add your own rules

Edit `src/main/resources/default-rules.yaml` or pass your own:

```bash
gradle run --args="--in gamepack.jar --out out --rules myrules.yaml"
```

Rule model (classRules):
- Fast constraints:
  - `superName` (exact internal name or "*")
  - `interfaces` (list)
  - `minFieldDescCounts` (descriptor -> minCount)
  - `minMethodDescCounts` (descriptor -> minCount)
- Signals (scored):
  - `minLdcStrings` (min)
  - `minLdcNumbers` (min)
  - `stringHashEq` (value = 0x... 64-bit hash of all string literals)

## How to make it “always correct”
In practice you don’t get “always correct” from a single weak heuristic.
You get reliability by layering:

1) **Strong anchors** (very distinctive classes) with strict constraints  
2) **Graph propagation** (neighbors via field types, call graph, inheritance)  
3) **Multi-signal scoring** (several independent proofs, not just one count)  
4) **Fail closed**: if confidence < threshold, mark unresolved instead of guessing  
5) **Fixtures/CI**: run against multiple known JARs and assert stable anchors

This starter implements (3) + (4) + deterministic outputs. Add (1)(2)(5) as you grow.

## Suggested next steps (high-impact)
- Implement a call graph + field usage graph in the feature index.
- Add opcode-pattern signals (n-gram / subsequence signatures).
- Add incremental diffing (fingerprints) to speed up across versions.
- Add a `NormalizePass` with conservative constant folding and dead-code pruning.

## License
Choose a license when you publish (MIT/Apache-2.0 are common for tools).


## Bytecode field pattern signals (higher precision)

This build includes a `fieldPattern` signal that matches a **fixed-length opcode window** around field accesses
for fields **declared in the class** (owner == class).

**Window length: 7 tokens**
- 2 opcodes BEFORE
- the FIELD opcode (`GETFIELD`, `PUTFIELD`, `GETSTATIC`, `PUTSTATIC`)
- 4 opcodes AFTER
- Pads with `NONOP` as needed

Patterns are tokenized (space-separated), and `*` matches any token.

YAML format:
```yaml
- kind: fieldPattern
  value: "I|* * GETFIELD * IMUL LDC IADD"
  min: 10
  weight: 1.0
```

`value` format is: `"FIELD_DESC|OPCODE_PATTERN"` where `FIELD_DESC` is the field descriptor
(e.g. `I`, `Z`, `J`, `Ljava/lang/String;`, `[I`).

## Opcode 3-gram fingerprint signal
For higher precision, we compute a per-class **opcode 3-gram 64-bit hash** (`opcode3GramHash64`).
This is useful as a *supporting* signal because it captures bytecode "style" across the class.

YAML format:
```yaml
- kind: opcode3GramHashEq
  value: "0x0123abcd..."
  weight: 1.0
```

## “Always correct” reality check (and the practical solution)
You can’t guarantee “always correct” across all future obfuscation changes without ongoing maintenance.
What you *can* do is maximize correctness by:

1) Using **multiple independent signals** per target (structure + literals + patterns + graph neighbors)  
2) Setting **high thresholds** and **failing closed** (unresolved is safer than wrong)  
3) Shipping **fixtures + CI** so community PRs keep accuracy stable over time  

## Field-level mapping

This build supports `fieldRules` in YAML. Field rules are evaluated **after** class mapping
and only inside the mapped owner class.

Outputs:
- `out/mapping_classes.json`
- `out/mapping_fields.json`

Field rules can match by:
- Field descriptor (`desc`)
- Static/instance (`isStatic`)
- Access bit masks (optional)
- Bytecode usage patterns around that exact field (`fieldPattern`)
- Read/write counts
- IMUL constant heuristics for obfuscated int fields (`intMultiplierConstAny`, `intMultiplierConstEq`)
