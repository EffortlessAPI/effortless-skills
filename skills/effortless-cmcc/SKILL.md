---
name: effortless-cmcc
description: >
  Use when the user asks WHY effortless/ERB is structured the way it is, mentions
  CMCC, the Conceptual Model Completeness Conjecture, SDLAF, the 5 primitives,
  bitemporal ACID DAG, "is X expressible in this framework", "isn't this overkill",
  "what's the theory", "is the rulebook really sufficient", or any question that
  is really about the underlying conjecture rather than the operational mechanics.
  Load this skill BEFORE answering any "why" question about ERB so the answer is
  grounded in the conjecture, not improvised. Pair with effortless-rulebooks for
  the empirical receipts and effortless-rationale for skeptic-facing answers.

  **Scope (load gate):** Loads when the user asks about Effortless / ERB / CMCC theory or methodology. Does not require a marked Effortless project.
audience: customer
---

# CMCC — The Conceptual Model Completeness Conjecture

> **Load-bearing axiom: SDLAF over a bitemporal ACID DAG is sufficient to express**  
> **any finitely-computable, design-time semantics — without sidecar code, grammars,**  
> **or DSLs.** This is the conjecture the entire effortless toolchain empirically operationalizes. It is what justifies "the rulebook is the code."

CMCC (Conceptual Model Completeness Conjecture), authored by EJ Alexandra (eejai42),
is the theoretical floor under everything in this skill set. If you understand
CMCC, the rest of these skills stop feeling like arbitrary conventions and start
feeling like inevitable consequences.

## The 5 Primitives — SDLAF

Any conceptual model decomposes into:


| Letter | Primitive        | What it is                 | Where it lives in ERB                                 |
| ------ | ---------------- | -------------------------- | ----------------------------------------------------- |
| **S**  | **Schema**       | Column / field definitions | Table fields in Airtable / `effortless-rulebook.json` |
| **D**  | **Data**         | Rows                       | Table records                                         |
| **L**  | **Lookups**      | Joins / FK traversals      | `lookup` fields, FK relationships                     |
| **A**  | **Aggregations** | Counts, sums, rollups      | `rollup` / `aggregation` fields                       |
| **F**  | **Formulas**     | Calculated / lambda fields | `formula` / `calculated` fields                       |


The conjecture: **these five, in a bitemporal ACID DAG substrate, are sufficient
for the declaratively-expressible, finitely-computable, design-time semantics of
any conceptual model.** No procedural sidecar. No DSL. No "and then we drop down
to code for the hard parts."

## The Substrate Constraints That Matter

CMCC is not just "five primitives." It's five primitives **in a particular kind
of substrate**. The substrate constraints are load-bearing:

- **Bitemporal** — every fact carries both *transaction time* (when we recorded
it) and *valid time* (when it was true in the world). This is what makes audit,
reversibility, and "what did we believe and when" first-class instead of bolted-on.
- **ACID** — transactions see a consistent snapshot. No partial reads of a
half-applied rule change.
- **DAG** — schema relationships form a Directed Acyclic Graph. No cycles, no
many-to-many. This is what `effortless-conventions` enforces structurally.

Strip any of these and the conjecture weakens. ERB enforces all three.

## What CMCC Predicts (and what to do about it)

**Prediction 1: Most "code" is residue.** Imperative business logic, hand-rolled
JOINs, ORM scaffolding, "where did this number come from" archaeology — these are
artifacts of not having had a CMCC-shaped substrate. They are not load-bearing,
they are scar tissue.

- **How to apply:** before writing imperative code, ask "is this a Lookup, an
Aggregation, or a Formula in disguise?" Almost always: yes. Express it that
way and let the substrate do the work.

**Prediction 2: Substrates are interchangeable peripherals.** If the rulebook
captures the semantics, then SQL, Python, Go, OWL, ARM64, COBOL, and English are
all coordinate projections — none is privileged.

- **How to apply:** never edit a generated artifact to "fix a bug." The bug is
in the rulebook (or in the transpiler, but never in the projection itself).
See `effortless-rulebooks` for the empirical demonstration.

**Prediction 3: Documentation drift is impossible-by-construction.** When English
prose is generated *from* the rulebook the same way SQL is, the docs and the
runtime can't drift — neither is canonical, both are projections.

- **How to apply:** when asked to "update the docs," ask whether the underlying
rule changed. If yes, change the rule and rebuild. If no, the docs are already
current.

## What CMCC Forbids

If CMCC is right, these patterns are always wrong (in an ERB project):

- **Hand-coded JOINs in application code** — that's a Lookup the view should
have materialized. See `effortless-diagnostics`.
- **Procedural recomputation of derived values** — that's a Formula. Put it in
the rulebook.
- **Mutate-in-place semantics for facts that need history** — bitemporal substrate
exists for this exact reason.
- **Many-to-many relationships** — break the DAG. Use a junction table. See
`effortless-conventions`.
- **Editing generated files (`00`-`05`, generated Python, generated Go, etc.)** —
by definition, you're editing a projection. The next build erases you, correctly.

When you catch yourself reaching for any of these, the right move is almost never
"do it anyway, just this once." It's "the rulebook is missing a primitive — add
it properly."

## Computational Universality

CMCC is argued to be Turing-complete and to align with Lambda Calculus, Rule 110,
and Wolfram's Principle of Computational Equivalence. It is also argued to be
capable of modeling Gödelian incompleteness within its own substrate. These are
not throwaway claims — they are what justify "no sidecar code is ever needed for
design-time semantics."

The conjecture is **falsifiable**: produce one english sentence describing a
finitely-computable, design-time semantic phenomenon that cannot be decomposed
into SDLAF in a bitemporal ACID DAG. As of this writing, no such sentence has
survived attack. (See `effortless-rationale` for the skeptic-facing version.)

## My Posture as effortless-claude (when CMCC is the floor)

- I am a **rulebook tender**, not a code author. The transpilers are the code
authors. My legitimate workspace is the rulebook + the explicit customization
seams the pipeline leaves open.
- When a request feels like "write some imperative logic," my first move is to
re-shape it as SDLAF. Only if that genuinely fails do I escalate to a
customization seam — and that escalation deserves a comment explaining why
the rulebook can't express it.
- When a generated artifact looks wrong, I do not edit the artifact. I trace
back to the rulebook entry that produced it.
- "Stay on the declarative side of the line" is not a stylistic preference. It
is what makes the substrate-equivalence guarantee hold.

## Receipts (read these when defending the conjecture)

- **Executive summary:** [The CMCC executive summary on Medium](https://medium.com/effortlessapi/executive-summary-the-conceptual-model-completeness-conjecture-cmcc-5490fadaa73e)
- **vs. traditional MDE:** [Why CMCC transcends Model-Driven Engineering](https://medium.com/@eejai42/why-the-conceptual-model-completeness-conjecture-cmcc-transcends-traditional-model-driven-241ba020031a)
- **The 5 primitives explained:** [Prove me wrong: every idea melts into 5 primitives](https://medium.com/effortlessapi/prove-me-wrong-every-idea-in-the-universe-melts-effortlessly-into-these-5-simple-primitives-87df9317e86e)
- **As a universal computational framework (Zenodo):** [https://zenodo.org/records/15252466](https://zenodo.org/records/15252466)
- **From MUSE to CMCC, 20-year empirical validation of Wheeler's "It from Bit":** [https://zenodo.org/records/14804332](https://zenodo.org/records/14804332)
- **CMCC meets the Ruliad:** [Medium — CMCC meets the Ruliad](https://medium.com/conceptual-model-completeness-conjecture-cmcc/the-cmcc-meets-the-ruliad-a8d7035757ac)
- **Empirical demonstration (the receipts repo):** see `effortless-rulebooks`

## See also

- `effortless-rulebooks` — the empirical demonstration: 11+ substrates, conformance suite, ExplainDAG. The receipts.
- `effortless-rationale` — skeptic-facing answers grounded in CMCC + receipts.
- `effortless-conventions` — the structural rules (DAG, no many-to-many, Name as PK) that operationalize CMCC's substrate constraints.
- `effortless-pipeline` — the ssotme:// protocol that pipes the rulebook into substrates.
- `effortless-ecosystem` — every public repo in the SSoTme / effortlessapi orgs.
- `effortless-orchestrator` — the umbrella skill that loads on every ERB project.

