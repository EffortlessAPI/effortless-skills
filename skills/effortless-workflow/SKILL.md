---
name: effortless-workflow
description: >
  Use when making changes to an ERB project — modifying effortless-rulebook.json,
  Airtable schema or data, or running effortless build. Covers Path A (Airtable-first)
  vs Path B (Rulebook-first reverse sync) and permission checkpoints.

  **Scope (load gate):** Effortless projects only — project root must contain `effortless.json` AND a CLAUDE.md identifying the project as ERB methodology. Do NOT load otherwise.
audience: customer
---

# ERB Change Workflow

## CRITICAL: Always Ask Before Modifying

**Before modifying `effortless-rulebook.json`, Airtable schema/data, or running `effortless build`, ALWAYS ask the user for permission.** These are consequential operations that affect the single source of truth and trigger code regeneration.

## Two Paths for Making Schema/Data Changes

There are exactly two valid workflows. **Always prefer Path A** when possible.

### Path A: Airtable-First (Preferred)

This is the standard flow. Airtable is the authoritative source.

1. **Modify Airtable** — Add/change fields, data, or formulas in the Airtable base
   - API key resolution: `AIRTABLE_API_KEY` env var > `~/.ssotme/ssotme.key` (`APIKeys.airtable`) > project settings
   - Set the key via: `effortless -setAccountAPIKey airtable=patXXXXXXXX.XXXXXXXX`
   - If no API key is available, tell the user — they may set it or make the change in Airtable UI
2. **ALWAYS run `effortless build`** from the project root — this pulls from Airtable and regenerates everything downstream. **This step is mandatory after every Airtable modification — no exceptions.**

```
Airtable (you edit here)
    |  airtable-to-rulebook
    v
effortless-rulebook.json (regenerated)
    |  rulebook-to-postgres, etc.
    v
All generated files (regenerated)
```

### Path B: Rulebook-First (Reverse Sync)

Use this when Airtable is not accessible, or when it's more practical to edit the JSON directly (e.g., bulk changes, offline work).

1. **Edit `effortless-rulebook.json` directly** — Make your schema/data changes in the JSON
2. **Push changes back to Airtable** — Run `effortless build -id` from the `effortless-rulebook/push-to-airtable/` subfolder
   - The `-id` flag tells effortless to include disabled transpilers — this is necessary because `rulebook-to-airtable` is typically disabled in `effortless.json` (since most of the time Airtable is authoritative, not the JSON)
   - This must be run directly from the `push-to-airtable/` subfolder, not from the project root
3. **Then run the normal build** — `effortless build` from project root to regenerate downstream files

```
effortless-rulebook.json (you edit here)
    |  rulebook-to-airtable (via build -id from push-to-airtable/)
    v
Airtable (synced back)
    |  then normal: effortless build from root
    v
All generated files (regenerated)
```

## Permission Checkpoints

**STOP and ask the user before ANY of these actions:**
- Editing `effortless-rulebook.json`
- Modifying Airtable schema or data (via API or any other method)
- Running `effortless build` (from root or any subfolder)
- Running any individual transpiler

These are not routine file edits — they affect the source of truth and trigger cascading regeneration.

## "Just add a small table" is the #1 trap

When the user says "make a Foo table" / "add a Bar entity" / "I need an X table" — that is a Path A change. The entity goes in Airtable; `effortless build` regenerates `public.foo` + `vw_foo`. Do NOT hand-write the table in `01b-customize-schema.sql`. The `01b-05b` files are for infrastructure the rulebook cannot model (auth tenants, JWT helpers, role GRANTs) — never for business entities. If you're typing `CREATE TABLE app.users (...)` or similar, you've taken a wrong turn.

## Don't drive git on the user's behalf

Effortless skills are read-only with respect to git. Before `effortless build`, check the tree with
`git status --porcelain` (read-only); if non-obvious changes are present, **ask the user for permission
to build** — they may want to commit or stash first so the resulting diff cleanly isolates the regenerated
output from hand-written follow-ons. After the build, do NOT auto-commit; leave the dirty tree for the
user to commit when they choose.

(Exception: `effortless-setup-postgres` performs one-time bootstrap commits during initial project
creation — that flow is explicitly authorized to drive git. Nothing else is.)

## NO SILENT FALLBACK ALLOWED

If you cannot make a change in Airtable (e.g., API limitations for formula fields, no API key):
1. **STOP** - Do not silently fall back to manual edits of generated files
2. **ASK THE USER** - Explain what you cannot do via API and present the options:
   - **Path A**: User makes the change manually in Airtable's UI, then runs `effortless build`
   - **Path B**: You edit `effortless-rulebook.json` directly, then push to Airtable via `effortless build -id` from `push-to-airtable/`
   - **Customization files**: Use `*b-customize-*` files for logic that can't be expressed in Airtable
3. **Wait for user direction** - do not proceed without explicit permission

---

## See also

- `effortless-orchestrator` — for the bigger mental model and the schema-change decision tree this skill operationalizes.
- `effortless-leopold-loop` — for the iterative cycle Path A produces.
- `effortless-airtable` / `effortless-airtable-omni` — for *how* to make the change in Path A (API vs OMNI).
- `effortless-pipeline` — for the `-id` flag mechanics referenced in Path B.
- `effortless-sql` — for the rule that `*b-customize-*.sql` is the ONLY hand-edited surface, and never for business entities.
