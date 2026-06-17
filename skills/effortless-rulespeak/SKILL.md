---
name: effortless-rulespeak
description: >
  Use when generating plain-English RuleSpeak documentation from an
  effortless-rulebook.json — declarative business rules, vocabulary, fact
  types, definitional rules (DR-n), and traceability back to formulas.
  Installs `rulebook-to-rulespeak` and emits `rulespeak/rulespeak.md` on
  every build.

  Triggers: "generate rulespeak", "rulebook-to-rulespeak", "english rules
  document", "plain language rules", "business rules doc from rulebook",
  "rulespeak.md".

  **Scope (load gate):** Effortless projects with a rulebook hub. Does not
  require Airtable. Default for demo/POC bootstrap (see effortless-demo-app).
  For interactive in-app field provenance, use effortless-explainer-dag
  on demand instead.
audience: customer
---

# Effortless RuleSpeak — rulebook → plain English

`rulebook-to-rulespeak` renders `effortless-rulebook.json` into **RuleSpeak** —
a declarative, business-readable document of the same rules the formulas encode.
Every calculated, lookup, and aggregation field becomes a definitional rule;
relationships become fact types; tables become vocabulary.

This is the **default rules-documentation output** for demo apps and POCs.
It requires no web UI wiring — just install the transpiler and run `effortless build`.

For **clickable in-app field exploration** (hover cards, DAG pages), load
**effortless-explainer-dag** separately when the user asks — that is optional,
not part of the standard POC path.

## Install (from project root)

```bash
mkdir -p rulespeak
cd rulespeak
effortless -install rulebook-to-rulespeak -i ../effortless-rulebook/effortless-rulebook.json
cd ..
```

Expected `ProjectTranspilers` entry:

```json
{
  "Name": "rulebooktorulespeak",
  "RelativePath": "/rulespeak",
  "CommandLine": "rulebook-to-rulespeak -i ../effortless-rulebook/effortless-rulebook.json",
  "IsDisabled": false
}
```

## Build

```bash
effortless build
# or
./start.sh build
```

Output: `rulespeak/rulespeak.md`

## What the document contains

| Section | Content |
|---------|---------|
| **Business Vocabulary** | One term per table + derived fields |
| **Fact Types** | Cardinality from relationships |
| **Operative Rules** | Structural `must` / `must not` / `should` (from schema + optional `Constraints` table) |
| **Definitional Rules** | `DR-n` rows — one per calculated/lookup/aggregation field |
| **Traceability to Schema** | Each derived field mapped back to its formula (the hub SSoT) |

## Demo-app integration

During POC bootstrap (`effortless-demo-app` step F):

1. Install as above (after postgres transpiler, before or after first build).
2. Run `effortless build` — confirm `rulespeak/rulespeak.md` exists.
3. Mention the file in `CLAUDE.md` repo layout and optionally link from README
   under a developer-only section ("Business rules document").
4. **Do not** wire RuleSpeak into the React UI unless the user explicitly asks —
   the markdown file is the deliverable for POCs.

## Optional: semantic obligations

For deontic rules beyond schema flags (`nullable:false`), add a **`Constraints`**
table to the rulebook. Each row points at a boolean calculated field on an entity
and annotates it with `MustBeTrue` / `MustNotBeTrue` / `ShouldBeTrue`. See the
`rulebook-to-rulespeak` tool README (`UsingRulespeakConstraints.md`) for the full
column contract.

## See also

- `effortless-explainer-dag` — on-demand in-app DAG + hover RuleSpeak (not default for POCs)
- `effortless-pipeline` — transpiler install paths and build order
- `effortless-demo-app` — step F uses this skill, not explainer-dag
