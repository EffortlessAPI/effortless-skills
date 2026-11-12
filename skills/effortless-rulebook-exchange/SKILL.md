---
name: effortless-rulebook-exchange
description: >
  Rulebook Exchange: two parties (agents or people) send a rulebook, evaluate it, amend it and
  diff it, instead of a request plus prose. Any transport (MCP, HTTPS, git, a spreadsheet).
  Triggers: "send the rulebook instead", "rulebook as the message", "MCP is fuzzy", "agents
  talking past each other", "shared context between agents".
audience: customer
---

# Rulebook Exchange

Two parties exchange a formal model of meaning, the rulebook, instead of a request and a prose
reply. Each side evaluates the model, amends it, and sends it back; the difference between the
two models is the answer. The exchange does not depend on how the rulebook travels. This
describes the idea and the parts of it that exist today; it is not a finished product (see
"What exists today").

## What a message usually carries

An API call, a tool call or an email carries two things:

| Layer | Example | Formal? |
|---|---|---|
| Shape | a schema: `leaseId: string`, `asOf: date` | yes, but only syntax |
| Meaning | a description: "Returns the late fee owed on a lease" | no, prose |

The receiver reads the prose and infers what every term means: what counts as late, whether
grace days are calendar or business days, what "owed" includes. The reply comes back the same
way, resting on assumptions neither side wrote down. Each side interprets the other, every time.
A schema does not reach that layer.

## The exchange

1. **Send the rulebook.** It defines every predicate in the domain: tables, fields, lookups,
   aggregations, formulas, and example rows. `Leases.LateFee` is not described, it is defined:
   `=IF({{DaysLate}} > {{GraceDays}}, {{MonthlyRent}} * {{LateFeePercent}}, 0)`.
2. **The request becomes trivial.** With the whole context present, a question is "evaluate
   `LateFee` for lease L-104" or "complete this model". There is nothing left to explain.
3. **The receiver evaluates the model and answers.** It computes the formulas; it does not
   guess what they mean.
4. **The receiver amends the model.** Facts that were missing, a rule it reads differently,
   parts that do not belong: each becomes a change to a row, field or formula.
5. **It sends the amended rulebook back.** The sender diffs it against what it sent. The diff
   is structural and deterministic: these fields added, this formula changed, these rows
   removed. Every assumption the receiver made is in the diff, or it was not made.

## The exchange fixes little; the rulebook carries the rest

The exchange itself defines only:

- **the payload**: a rulebook, with its format version;
- **the round trip**: send a rulebook, receive a rulebook;
- **a structural diff**: added, removed, changed. It works on any rulebook.

Everything else is **content**, and the exchange picks no winners. A rename can be recorded as a
stable id in `ERBTables` / `ERBFields`, as an `EntityTables` row, or as a rename row in a
`ModelChanges` table. Permissions can be a `<Role>CRUD` matrix or permission rows
(`effortless-security`), and a per-role subset of a rulebook is still a rulebook. Each is tables
in the payload; patterns emerge and spread without the exchange changing, the way HTTPS carries
HTML or JSON without choosing.

A rulebook can also carry the definition of its own conventions: if `ModelChanges` derives
"this field used to be called X" with formulas, the receiver gets the convention and its meaning
in the same payload. A tool that acts on a convention outside the rulebook (a diff tool that
reads `ModelChanges` to report renames) has that convention coded into the tool; that is the
tool's choice, not the exchange's.

## A common misreading

"This makes tool calls deterministic." That is a different, smaller point. ssotme://
transpilers are deterministic (same rulebook, same tool version, same output), but this is about
what the message carries: a model both sides evaluate instead of a request plus prose. What
each side chooses to ask or amend stays a judgement call; what those choices are about no
longer is.

## Worked example (the live rulebook widget's late-fee rulebook)

Party A sends `late-fee.rulebook.json`: `LateFeePolicies` (parameters `GraceDays`,
`LateFeePercent`), `Leases` (data, each pointing at a policy), and the `LateFee` formula above.
Party B works for a landlord in a jurisdiction that caps late fees. It returns the rulebook
amended; A's diff reads:

| Change | Kind |
|---|---|
| `LateFeePolicies.LateFeeCap` added (raw, currency) | new parameter |
| `Leases.LateFeeCap` added (lookup through `LateFeePolicy`) | new lookup |
| `Leases.LateFee` formula: `IF(... , MIN(MonthlyRent * LateFeePercent, LateFeeCap), 0)` | rule changed |
| `LateFeePolicies.GraceDays` description: "calendar days, counted from the due date" | meaning pinned |
| row `standard`: `LateFeeCap = 50` | data |

In prose, B's reply would have been "the fee is $50, there's a cap here", and A would have had
to guess where the cap came from and whether it applies to other leases. As a diff, the cap is a
parameter, the rule that uses it is visible, and A's own rulebook now computes $50 too.

## Evaluation, not interpretation

Both sides still run something: a formula engine, SQL, generated TypeScript. That is
*evaluation*: mechanical, and checked across substrates by the conformance suite
(`effortless-rulebooks`). *Interpretation*, a reader working out what a term means from prose,
is what descriptions need on both ends. In a rulebook it is left in one place: linking the raw
fields to the world (below).

## Where ssotme:// fits

ssotme:// (`effortless-ssotme-protocol`) turns one rulebook into artifacts through registered
transpilers. The exchange sits on top of it:

- **It is how a party evaluates.** Running the rulebook (Postgres, TypeScript, the formula
  engine) is running transpilers. ssotme:// promises the same rulebook and tool version give the
  same output, so both parties compute the same values.
- **The spreadsheet round trip is two transpiler runs**: `rulebook-to-xlsx` out,
  `xlsx-to-rulebook` back.
- **One contract at two scales.** In ssotme:// the rulebook is the contract between the model and
  every tool: each transpiler respects its shape. In the exchange the same rulebook is the
  contract between the parties.
- **Both are transport-neutral.** ssotme:// tools run from the `effortless` CLI, over HTTP, or as
  tools on our MCP server; the exchange runs over any channel (below). Neither depends on MCP.

## People in the exchange

A rulebook converts to a spreadsheet (`rulebook-to-xlsx`) and back (`xlsx-to-rulebook`). A party
can hand the model to a person, who edits rows and formulas in Excel; the edited workbook comes
back as a rulebook and is diffed the same way. The person takes part in the exchange instead of
reading a summary of it.

## What stays ambiguous

1. **The raw fields.** Formulas define derived predicates in terms of raw fields; a raw field's
   meaning is its name, its description and its data. Two parties can agree on every formula and
   still read `GraceDays` as calendar vs business days, or `Revenue` as booked vs collected.
   Example rows pin a meaning down far better than prose; a description or a new field settles
   it, as in the example. The ambiguity is confined to named leaves that can be pointed at.
2. **Writing the model.** Turning intent into a rulebook (by an LLM or a person) is a judgement
   call. The result can be inspected and diffed, so a wrong encoding is visible.

## Carrying it

Nothing in the exchange names its transport. Any channel that can move a file works:

| Transport | How the rulebook travels |
|---|---|
| MCP | a resource or a tool argument/result with a rulebook media type (for example `application/vnd.effortless.rulebook+json`); formally, an extension `com.effortlessapi/rulebook-exchange` that both sides declare, with a plain-text fallback for a side that does not. MCP fits because it already carries typed resources and named extensions; see `effortless-mcp` for our server |
| HTTPS | a POST whose body is the rulebook, the response the amended one |
| git | a commit is the amended rulebook; the diff is the commit's diff |
| A file (email, chat, drive) | the rulebook as an attachment, or as a workbook for a person |

## Prior art

KQML and FIPA-ACL (1990s) had agents exchange messages in a content language against a shared
ontology. They stalled mainly on aligning ontologies between parties and on grounding terms.
What differs here: the definitions execute (formulas, lookups, aggregations, not only
classification), example data travels with them, a person can edit the same model as a
spreadsheet, and two versions diff mechanically.

## What exists today

| Piece | Where |
|---|---|
| Query a rulebook's structure | `effortless-query`; `query_rulebook` on our MCP server |
| Reject a malformed model | `validate_dag` (`effortless-diagnostics`) |
| Diff, apply, rebase, describe two rulebooks | effortlessapi.com `packages/rulebook-patch` (`diff`, `apply`, `rebase`, `describe`); a renamed key shows as removed + added today |
| Spreadsheet round trip | `rulebook-to-xlsx`, `xlsx-to-rulebook` |
| Per-role schemas and types | `rulebook-to-rbac` (`effortless-security`) |

Not built: a published JSON Schema for the rulebook format and for the change set, the exchange
as a defined operation on any transport, and a diff that reads rename conventions.

## See also

- `effortless-schema`: the rulebook's JSON structure, the payload.
- `effortless-ssotme-protocol`: the transpiler protocol each party evaluates with.
- `effortless-cmcc`: why a rulebook can carry a domain's full meaning.
- `effortless-mcp`: our MCP server, one way to carry the exchange.
