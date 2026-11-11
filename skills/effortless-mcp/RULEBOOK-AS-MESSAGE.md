# The rulebook as the message

How two agents (AI or human) can exchange a formal model of meaning instead of requests and
prose. This describes an idea and the parts of it that exist today; it is not a feature of the
MCP server yet (see "What exists today").

## What an MCP message carries

An MCP tool call carries two things:

| Layer | Example | Formal? |
|---|---|---|
| Shape | JSON Schema: `leaseId: string`, `asOf: date` | yes, but only syntax |
| Meaning | the tool's `description`: "Returns the late fee owed on a lease" | no, prose |

The receiver reads the prose and infers what every term means: what counts as late, whether
grace days are calendar or business days, what "owed" includes. The reply comes back the same
way: a value or a paragraph, resting on assumptions neither side wrote down. Each side
interprets the other, every time. That is where the ambiguity in agent-to-agent exchanges lives,
and JSON Schema does not reach it.

## The idea: send the model, not the request

1. **Send the rulebook.** It defines every predicate in the domain: tables, fields, lookups,
   aggregations, formulas, and example rows. `Leases.LateFee` is not described, it is defined:
   `=IF({{DaysLate}} > {{GraceDays}}, {{MonthlyRent}} * {{LateFeePercent}}, 0)`.
2. **The request becomes trivial.** With the whole context present, a question is "evaluate
   `LateFee` for lease L-104" or "complete this model". There is nothing left to explain.
3. **The receiver queries the model and answers.** It evaluates the formulas; it does not
   guess what they mean.
4. **The receiver amends the model.** Facts that were missing, a rule it reads differently,
   parts that do not belong: each becomes a change to a row, field or formula.
5. **It sends the amended rulebook back.** The sender computes the diff against what it sent.
   The diff is structural and deterministic: these fields added, this formula changed, these
   rows removed. Every assumption the receiver made is in the diff, or it was not made.

Same transport, same request/response rhythm. What changes is what the message carries.

## A common misreading

"This makes MCP tool calls deterministic." That is a different (smaller) point. ssotme://
transpilers are deterministic (same rulebook, same tool version, same output), but the point
here is about the *message*: replacing request-plus-prose with a model both sides evaluate.
The model's choices (what to ask, what to amend) stay judgement calls; what they are about no
longer is.

## Worked example (the live rulebook widget's late-fee rulebook)

Agent A sends `late-fee.rulebook.json`: `LateFeePolicies` (parameters `GraceDays`,
`LateFeePercent`), `Leases` (data, each pointing at a policy), and the `LateFee` formula above.
Agent B works for a landlord in a jurisdiction that caps late fees. It replies with the rulebook
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

## What travels with the model

The rulebook can carry its own metadata and access rules, so they travel too:

- **`ERBTables` / `ERBFields`**: every table and field as a row, with a stable id. That is what
  lets a diff tell a rename from a delete plus an add.
- **Roles and permissions**: `ERBRoles`, the `<Role>CRUD` matrix and row filters
  (`effortless-security`). Who may see and change what is part of the message, not a separate
  OAuth scope the other side cannot see.
- **A per-role subset is still a rulebook.** Hand each party the schema for its role: a valid
  model with only what it may read. Any appropriate subset of the whole works the same way.

## Evaluation, not interpretation

Both sides still run something: a formula engine, SQL, generated TypeScript. That is
*evaluation*: mechanical, and checked across substrates by the conformance suite
(`effortless-rulebooks`). *Interpretation*, a reader working out what a term means from prose,
is what MCP descriptions and most model-driven tools need on both ends. In a rulebook it is left
in one place: linking the raw fields to the world (below).

## Humans on the same channel

The rulebook converts to a spreadsheet (`rulebook-to-xlsx`) and back (`xlsx-to-rulebook`). An
agent can hand the model to a person, who edits rows and formulas in Excel; the edited workbook
comes back as a rulebook, and the diff against the original is computed the same way. The person
is a participant in the exchange, not a reader of a summary of it.

## What stays ambiguous

1. **The raw fields.** Formulas define derived predicates in terms of raw fields; a raw field's
   meaning is its name, its description and its data. Two parties can agree on every formula and
   still read `GraceDays` as calendar vs business days, or `Revenue` as booked vs collected.
   Example rows pin a meaning down far better than prose; a description or a new field settles
   it, as in the example. The ambiguity does not disappear, but it is confined to named leaves
   that can be pointed at and fixed.
2. **Writing the model.** Turning intent into a rulebook (by an LLM or a person) is a judgement
   call. The result can be inspected and diffed, so a wrong encoding is visible.

## How it relates to MCP

MCP is a transport, and for commands ("fetch this file", "run this build") a tool call with a
JSON Schema is the right size. The difference shows when the payload is a domain: definitions,
rules and permissions squeezed into tool names and descriptions. A rulebook can ride MCP as a
payload (a resource, or a tool argument and result); the transport does not need to change.

## Prior art

KQML and FIPA-ACL (1990s) had agents exchange messages in a content language against a shared
ontology. They stalled mainly on aligning ontologies between parties and on grounding terms.
What differs here: the definitions execute (formulas, lookups, aggregations, not only
classification), example data travels with them, a person can edit the same model as a
spreadsheet, and two versions diff mechanically.

## What exists today

| Piece | Where |
|---|---|
| Query a rulebook's structure | `query_rulebook` (this server), `effortless-query` |
| Reject a malformed model | `validate_dag` (this server) |
| Diff, apply, rebase, describe two rulebooks | effortlessapi.com `packages/rulebook-patch` (`diff`, `apply`, `rebase`, `describe`); it treats a renamed key as removed + added today |
| Spreadsheet round trip | `rulebook-to-xlsx`, `xlsx-to-rulebook` |
| Per-role schemas and types | `rulebook-to-rbac` (`effortless-security`) |

Not built: an MCP tool or resource that exchanges a rulebook as the message and returns the
diff, and rename detection by `ERBTables` / `ERBFields` id.
