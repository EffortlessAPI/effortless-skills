---
name: effortless-leopold-loop
description: >
  Use whenever the user mentions the "Leopold loop", "the loop", "a turn of the loop",
  "do a turn", "rebuild the rulebook", "update the app to match the rules", or any
  reference to the iterative ERB development cycle. This is the user's name for the
  CHANGE-RULE → REBUILD → CONSUME-VIEWS workflow that makes ERB feel effortless.
  Load this skill on first mention so you understand what the user expects to happen.
---

# The Leopold Loop

The "Leopold loop" is the user's name for the iterative ERB development cycle. It is the **core workflow** that makes ERB feel effortless compared to hand-coding ("naked Claude"). When the user mentions the loop in any form, they are invoking this entire mental model — load this skill so you respond in the right paradigm.

## The Loop

```
   1. CHANGE THE RULE (once, in Airtable — the SSoT)
            |
            v
   2. effortless build  (one command)
            |
            v
   3. EVERY DOWNSTREAM LAYER UPDATES AUTOMATICALLY
      - effortless-rulebook.json (canonical projection)
      - postgres/01-05*.sql (tables, functions, views, seed data)
      - ODXML schema
      - C#/Go/Python/etc. base classes, ORM context, sync services
            |
            v
   4. APP CODE (server, client) JUST CONSUMES THE GENERATED VIEWS
      - reads from vw_* views
      - treats calculated fields (e.g. is_stopped) as opaque
      - NEVER reimplements business logic that lives in the rulebook
            |
            v
   5. NEXT TURN OF THE LOOP — repeat from step 1
```

## Why it's "effortless"

A single rule change propagates through every layer with **zero hand-written migrations, DTOs, ORM updates, API serializers, or client types**. The business logic ("a customer is stopped when CurrentColor is Red") lives in **exactly one place** — the Airtable formula → generated SQL function → exposed in the view as `is_stopped`. The app just reads `is_stopped`. If the rule flips ("now Green means stopped"), the loop runs once and *no app code changes*.

Compare to "naked Claude" (hand-coding every layer): the same change requires editing a migration, seed data, DTO, ORM model, API serializer, client type, and client logic — and probably missing one and shipping a bug. The Leopold loop exists specifically to eliminate that class of failure.

## Phrases that mean "do a turn of the loop"

When the user says any of these, they expect the same sequence of actions:

- *"Do a turn of the loop"* / *"Run the loop"* / *"Take a turn"*
- *"Rebuild the rulebook"*
- *"Update the app to match the current rules"*
- *"Re-sync everything"*
- *"Push the rule change through"*
- *"Make the app reflect the new schema"*

All of these mean: **propagate the current Airtable state through every downstream layer, then update only the app's schema-surface code.**

## What "do a turn of the Leopold loop" actually entails

1. **Run `effortless build`** from the project root. This is atomic — fire and forget.
   Do NOT read the generated files afterwards. (Ask permission first if your project's CLAUDE.md requires it.)
2. **Commit the build output immediately** — `git add -A && git commit -m "effortless build: <reason>"`.
   This is **critical**: the commit captures the exact diff on `effortless-rulebook.json` and
   all generated files. Future steps (and future phases) can reference `git diff HEAD~1 -- effortless-rulebook/effortless-rulebook.json`
   to get a **100% accurate, high-fidelity** description of what changed in the schema.
   This diff is the most trustworthy input for deciding what app code needs updating.
3. **Run `init-db.sh`** if the project has a postgres target — this reloads the database.
4. **Query the rulebook for schema changes** — use a lightweight one-liner to see what
   tables/fields exist now (see `effortless-query`). Do NOT read generated SQL files.
   Or use `psql -c "\d vw_tablename"` to see the current view columns.
   Or — even better — use `git diff HEAD~1 -- effortless-rulebook/effortless-rulebook.json`
   from the commit you just made. This is the highest-fidelity view of what changed.
5. **Update the app code only where it touches the schema surface** — column names that changed, new fields the UI now needs to display, removed tables to clean up references to. **Never reimplement** rule logic in the app; consume the calculated fields from the view as opaque truth.
6. **Restart the app** — run `./start.sh` from the project root.

## MANDATORY: Always Build After Airtable Changes

**Every time** Airtable schema or data is modified (via API, OMNI, or manual UI changes), an `effortless build` MUST follow. No exceptions. The build is what propagates the change through the entire stack. Without it, the generated code is stale and the app is out of sync with the SSoT.

## Anti-patterns (these BREAK the loop — never do them)

- **Reimplementing rule logic in the client** — e.g. computing `isStopped = customer.color === 'Red'` in JS instead of using `customer.is_stopped` from the view. This duplicates the rule in two places. When the rule changes in Airtable next time, the client silently goes wrong because nobody updated the duplicated copy. **The whole point of the loop is that the rule lives in exactly one place.**
- **Hand-editing generated files** — `postgres/01-05*.sql`, `dotnet/.../BaseClasses/*.cs`, etc. They get blown away on the next build. If you need to override generated SQL, use the `*b-customize-*` files (see `effortless-sql` skill), and only after exhausting Airtable as the source of the change.
- **Adding columns/fields directly in SQL or C#** — changes must originate in Airtable so they survive `effortless build`. Use the `effortless-airtable` skill for scalar fields and `effortless-airtable-omni` for formulas/lookups/rollups.
- **Caching the rulebook output and forgetting to rebuild** — always rebuild before reasoning about the current state. Stale generated code is a common source of confusion.
- **Skipping the build and editing generated SQL "just this once"** — there is no "just this once". The next build erases it and the bug returns. Always go around the loop.
- **Treating `effortless-rulebook.json` as the SSoT** — it is a *projection* of the SSoT. Airtable is the SSoT. The only exception is the rare reverse-sync case (Path B in `effortless-workflow`), and that requires explicit permission.

## How this skill relates to others

- **`effortless-claude`** — the big-picture mental model; references this skill for the loop itself.
- **`effortless-workflow`** — Path A (Airtable-first, the normal loop) vs Path B (Rulebook-first, reverse sync).
- **`effortless-pipeline`** — the mechanics of `effortless build` itself.
- **`effortless-airtable`** / **`effortless-airtable-omni`** — *how* to make the rule change in step 1.
- **`effortless-sql`** — verifying step 3's generated output and using `*b-customize-*` overrides correctly.

## TL;DR for future-you

If the user says "the loop" or "Leopold loop" and you're not sure what to do: **load this skill, then run a turn of it.** Don't grep the project for "leopold". Don't ask the user to explain. The loop is a workflow, not a string.
