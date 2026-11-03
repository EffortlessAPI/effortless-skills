---
name: effortless-sql
description: >
  ERB-generated SQL — read vw_* views vs write base tables, generated files 00–05,
  ERBCustomizations rows (the one way to customize; legacy *b-customize-* files never
  reach a stage), calc_*/get_* functions, view structure. ERB projects only.
audience: customer
---

# ERB Generated SQL Patterns

> **The mechanics in one paragraph.** Files `00`–`05` under `postgres/` are
> mechanical output of the rulebook hub — every `effortless build` rewrites
> them. Edits there are not "forbidden"; they just don't survive the next
> build. To make a change stick, edit the hub (`effortless-rulebook.json`,
> via whichever input spoke you prefer). If the hub genuinely can't express
> what you need, add an `ERBCustomizations` row: the SQL travels with the
> rulebook and `update-effortless-schema.sql` applies it on every stage (except
> the `01b` row). Never a hand-edited `*b-customize-*.sql` file: that is legacy,
> it runs in Dev only, and a Publish never carries it. A row is
> not for defining tables or columns either. You also rarely need to read the
> generated SQL into context — `psql -c "\d vw_<table>"` gives you the same
> view structure for ~zero tokens.

> **Local-dev DBs are regenerated, not migrated.** `init-db.sh` drops and
> recreates the local DB on every build, so a `migrations/` folder /
> migrations tracking table / incremental delta would just be wiped next
> build. Schema changes belong in the hub → `effortless build`. The lone
> exception is `bases.effortlessapi.com`-hosted DBs (`postgres/apply-migration.sh`,
> see `effortless-bases`) where the DB *can't* be dropped, so deltas are
> the delivery mechanism — but the schema still originates in the hub.
> Canonical statement lives in `effortless-workflow`.

## Reading the generated SQL: usually unnecessary

Generated SQL files (00–05) are a *projection* of the rulebook for Postgres to
consume. You can read them, but it's expensive in context tokens and the
pipeline is deterministic enough that you usually don't need to.

If you need to know what a view contains:
- **Cheapest:** `psql -d <dbname> -c "\d vw_tablename"` (≈ zero context tokens)
- **Also cheap:** Query the rulebook schema with a one-liner (see `effortless-query`)
- **Expensive:** `cat postgres/03-create-views.sql` — works, but burns context

The view `vw_<tablename>` will always contain:
- All raw fields from the table (snake_case)
- All calculated/lookup/aggregation fields as additional columns
- FK lookup fields as `<fk_name>_<field>` (e.g., `customer_name`)

(Canonical Token Discipline section lives in `effortless-orchestrator`.)

---

## CRITICAL: Always Read From Views, Never Base Tables

**NEVER SELECT from base tables. ALWAYS use `vw_*` views for ALL read operations.**

This isn't a stylistic rule — it's how the substrate is shaped: views (`vw_*`) include raw fields *plus* every calculated/lookup/aggregation field, computed by the SQL functions generated from the rulebook. Base tables only have the raw columns, and the views aren't updatable in Postgres (they contain function-call columns), so writes have to go to the base table anyway.

```sql
-- WRONG: Reading from base table
SELECT * FROM customers WHERE hair_color = 'red';

-- RIGHT: Reading from view, naming the columns the caller uses
SELECT customer_id, name FROM vw_customers WHERE is_red_headed = true;
```

### Name the columns: `SELECT *` on a view runs every rule

Each `vw_*` column is a `calc_*` function call, and Postgres evaluates only the
columns a query names. `SELECT customer_id, name, is_vip FROM vw_customers` costs
three functions; `SELECT * FROM vw_customers` costs all of them — every lookup and
every aggregation over child tables — for every row (a 27-row, 60-column view:
280 ms whole, 0.5 ms for three columns). Name the columns in app SQL and over
the generated API (`GET /api/tables/<T>?fields=A,B,C`, see
`effortless-rulebook-editor`). `SELECT *` belongs only where the whole row is shown.

A role's own schema narrows this for you: `role_<id>.<table>` lists only the columns that
role may read, so `SELECT *` there evaluates only those (259 ms through `public.vw_*`, 2-3 ms
through a 22-column role view). Hide a persona's roll-up columns in `ERBFields.<Role>CRUD`;
see `effortless-security`.

### Before Writing ANY Query or Filter Logic:

1. **Check the view first** - Run `\d vw_tablename` or read `03-create-views.sql` to see ALL available fields
2. **Look for existing calculated fields** - The view likely already has `is_*`, `*_count`, `*_status` fields that answer your question
3. **Use calculated fields, don't recompute** - If `is_red_headed` exists, use it. Do NOT write `LOWER(hair_color) = 'red'`

### Why This Matters:

- Business logic belongs in the rulebook (rulebook-direct edits, or Airtable formulas if connected), not in ad-hoc queries
- Views contain pre-calculated fields that encapsulate business rules
- Computing things yourself (e.g., `LOWER(field) = 'value'`) duplicates logic and risks inconsistency
- The whole point of ERB is that the view already did the work for you

### The Rule:

| Operation | Use |
|-----------|-----|
| SELECT / READ | `vw_*` views ONLY |
| INSERT | Base table |
| UPDATE | Base table |
| DELETE | Base table |

### CRITICAL: Never JOIN one view onto another — add a lookup field

The subtle violation of "read from views" is not a base-table read — it's **JOINing two `vw_*` views** to pull a related entity's field. This is a JOIN anti-pattern: the relationship belongs in the rulebook as a **lookup field**, not in app SQL.

```sql
-- WRONG: joining vw_wards onto vw_mail_items to get the ward's name
SELECT m.mail_item_id, w.last_name AS ward_last_name
  FROM vw_mail_items m
  JOIN vw_wards w ON w.ward_id = m.ward
 WHERE m.mail_item_id = $1;

-- RIGHT: add a lookup field to the rulebook, then read one view
--   MailItems.WardLastName  (type: lookup)
--   formula: =INDEX(Wards!{{LastName}}, MATCH(MailItems!{{Ward}}, Wards!{{WardId}}, 0))
SELECT mail_item_id, ward_last_name
  FROM vw_mail_items
 WHERE mail_item_id = $1;
```

Why this is the rule, not a style preference:
- The view's whole job is to already contain every field a row needs, including cross-FK lookups. A JOIN means the rulebook was missing a lookup — fix the rulebook, don't join in the app.
- Lookups compose: a lookup may target another table's **calculated** field (the generated `calc_*` function just calls the related `calc_*`), so even "display label" coalescing belongs on the source entity, not in app SQL.
- Once the lookup exists, every consumer (board, API, export) gets the column for free with no repeated JOIN.

If a JOIN is fetching N fields from a related table, add N lookup fields (or one calculated field on the *source* entity that the lookup targets), rebuild, then collapse the query to a single-view read. See `effortless-diagnostics` for the find-and-migrate workflow.

---

## CRITICAL: Never Modify Generated Files

**NEVER directly edit generated SQL files.** The postgres/ folder contains:

### Generated Files (NEVER EDIT):
- `00-bootstrap.sql` - Database initialization
- `01-drop-and-create-tables.sql` - DDL for all tables (raw fields only)
- `02-create-functions.sql` - `calc_*()` and `get_*()` PL/pgSQL functions (1:1 with calculated/lookup/aggregation fields)
- `03-create-views.sql` - `vw_*` views combining raw tables + calculated fields via function calls,
  plus `fk_labels_<table>` views: one display label (`<field>__fk_label`, the related row's Name)
  per relationship field, which the generated API joins into its reads. They are not part of the
  `vw_*` contract (each `vw_*` mirrors the rulebook exactly); in app SQL, use a lookup field instead.
- `04-create-policies.sql` - Row-level security (RLS) policies
- `05-insert-data.sql` - INSERT statements from rulebook data

These files are regenerated by `effortless build` and ANY manual changes will be lost. You can edit them to test a hypothesis, but the next build rewrites them — for a change that persists, edit the hub.

### The two layers: migrated vs derived

Every object the pipeline emits falls into exactly one of two categories, and
they have **opposite** change semantics. Getting this wrong is the single most
expensive mistake in an ERB project.

| | **Migrated layer** | **Derived layer** |
|---|---|---|
| Objects | tables, columns | `vw_*` views, `calc_*`/`get_*` functions, RLS policies, role schemas |
| Holds data? | **yes** | **no** |
| How it changes | additive migrations, forever | **dropped and recreated from the rulebook** |
| In production? | `ALTER`, never `DROP` | full drop + recreate, every deploy |
| Can it drift? | yes — that's why there's a ledger | **no — impossible by construction** |

The derived layer holds no state. It is a pure function of the rulebook. The
rulebook ships **in the same git commit** as the code that reads it, so
recreating the derived layer from that commit's rulebook is correct by
definition — there is no "state" to migrate toward and nothing to get wrong.

**Therefore: never hand-write a migration that drops and recreates a view or a
`calc_*` function.** That is the most common and most wasteful anti-pattern in
ERB projects. Migrations that carry hundreds of lines of view DDL are doing, by
hand and fallibly, work that one generated script does correctly every time.
A migration should contain **only** additive table/column changes.

### Customizing the generated SQL: `ERBCustomizations` rows, one way

When the hub cannot express something, the SQL goes in a **row of the rulebook's
`ERBCustomizations` table** (details below). That is the one mechanism. The SQL
travels **with** the rulebook, so it is carried by `ERBVersions`, survives
relocation and keeps the rulebook a complete description of the system. Where a
row reaches:

- **A stage, production, a restored copy:** `update-effortless-schema.sql` runs
  the rows (except the `01b` row: see the gap below).
- **Dev:** `reset-rulebook-db.sh` does not run `update-effortless-schema.sql`. It
  runs the files on disk: override rows through `postgres/function-overrides/`
  (rewritten every build), every other row through the lettered file seeded from
  it, which is written **once** and never overwritten. So after you change such
  a row, delete its seeded file; the next build writes it again from the row.

#### Legacy: `*b-customize-*.sql` files. Do not write SQL into them.

Older projects carry hand-edited `postgres/NNb-customize-*.sql` files
(`01b-customize-schema` … `05b-customize-data`). They are the **legacy** way
(owner, 2026-11-02): imprecise, outside the rulebook, and hard to represent. The
same file names are also where the build seeds a row's copy for Dev, which is
why a hand edit there looks like it works. Know what they do and do not do:

- **Dev runs them**, each after its `NN-` counterpart (`reset-rulebook-db.sh`, or
  the editor's Dev build, which also lays a project's own lettered `NNx-*.sql`
  and `function-overrides/*.sql` over the generated SQL).
- **A Publish never carries them.** It is a fresh rulebook-to-postgres build from
  the rulebook alone, and a stage moves forward by `update-effortless-schema.sql`,
  which reads the rows, not the files. (A stage made by copying Dev's database
  starts with whatever the files built except RLS policies, which the copy leaves
  out, and keeps what a release does not drop: helpers not named `calc_*`/`get_*`,
  views not named `vw_*` that depend on none of those, indexes, data. Do not rely
  on that.) Freuman's Standards Based Grading, 2026-11-02: a
  hand-written function in `02b-customize-functions.sql` ran in Dev and
  Production ran the generated one.
- **The Loops release refuses them** (branch `release-refuses-legacy-customize`
  of loops.effortlessapi.com until merged): any lettered `NNx-*.sql` whose SQL,
  comments removed, differs from what the rows seed into it, and any
  `function-overrides/*.sql` the rulebook does not generate. It names the file
  and its first SQL line. A comments-only file, or an exact seeded copy of its
  row, passes.

**When you find SQL in one, move it out**, one statement at a time:

| Found in | Becomes |
|---|---|
| `02b` / `03b`: a replacement for a generated `calc_*`/`get_*` function or `vw_*` view | a `FunctionOverride` row (below) |
| `02b`: a new helper function | the row named `02b-customize-functions.sql` |
| `03b`: a new view | the row named `03b-customize-views.sql` |
| `04b`: an RLS policy or GRANT | the row named `04b-customize-policies.sql` (or the RBAC policy layer) |
| `05b`: idempotent seed data | the row named `05b-customize-data.sql` (or a static rulebook table) |
| `01b`: an index or constraint | ask the owner (see the `01b` gap); a table or column is a rulebook field; an FK comes from a relationship field |

**First check whether the rulebook already says it.** A legacy override often
patched a formula the rulebook has since learned to express; then the right move
is to delete it, not to freeze its old logic in a row. Compare the two on real
data before deciding (Freuman's `most_recent_score` override matched the
rulebook's own rule on every row, so it was deleted). Then:

- SQL that became a **named row** (`02b`-`05b`): **delete the file**. The next
  build seeds it from the row, and the release accepts that exact copy. A
  header-only file left behind is what Dev would run, without the SQL.
- SQL that became an **override row**, or was deleted: leave a comments-only file
  (or delete it); nothing seeds it unless a row has that name.

#### What belongs in a row, and what never does

Rows are for SQL the rulebook's **field model** cannot express: hand-tuned
functions, extra views, materialized views, RLS policies, role GRANTs, idempotent
seed data, and (with the `01b` gap in mind) indexes.

> **A row is not a place to define tables or add columns.** A table created in
> the `01b-customize-schema.sql` row (or a legacy `01b` file) gets **no view, no
> calculated fields, no RuleSpeak and no Explainer DAG**: it opts out of
> everything ERB does, on exactly the data that most needs it. Tables and columns
> are rulebook tables and fields, always.

### ERBCustomizations — the rulebook holds the whole model

`ERBCustomizations` is a rulebook table whose rows carry **real SQL**. This is
how substrate-specific work stays *inside* the rulebook instead of leaking into
loose `.sql` files beside it. The rulebook then holds 100% of the model: the
declarative part (tables, formulas) **and** the Postgres-specific part
(hand-tuned functions, materialized views, RLS, grants).

```json
"ERBCustomizations": {
  "schema": [
    { "name": "ERBCustomizationId", "datatype": "string", "type": "raw" },
    { "name": "Name", "datatype": "string", "type": "raw" },
    { "name": "CustomizationType", "datatype": "string", "type": "raw" },
    { "name": "SQLCode", "datatype": "string", "type": "raw" },
    { "name": "SQLTarget", "datatype": "string", "type": "raw" }
  ]
}
```

**How rulebook-to-postgres reads a row** (its `Program.cs`; get this exactly
right, a wrong row is ignored by the build without a warning):

- **An override row** (`CustomizationType` `FunctionOverride` or `SchemaOverride`,
  handled the same) replaces **one** generated object. Its `SQLCode` does the
  replacing: a `CREATE OR REPLACE` with the generated object's **exact name and
  signature**, run after the generated one (a different signature makes an
  overload, and the generated function stays in use). Name the row after that
  object (`calc_x`, `vw_x`): `Name` is its key (two rows with one `Name`, the last
  wins), its label in the script and its `function-overrides/` file name, and for
  a table override it is the table that gets dropped. Anything up to a first `:`
  in `Name` is stripped. `SQLTarget` is not read. The kind comes from keywords in
  the first non-comment line of `SQLCode`, tested in this order: `POLICY` or `ROW
  LEVEL SECURITY`, then `FUNCTION`/`PROCEDURE`, then `VIEW`, then `TABLE`; no
  keyword counts as a function. (So a `calc_x_policy_y` function counts as a
  policy.)
- **Any other row is routed by its `Name`, which must be a file name**:
  `02b-customize-functions.sql`, `03b-customize-views.sql`,
  `04b-customize-policies.sql`, `05b-customize-data.sql` or
  `01b-customize-schema.sql`. Use exactly these: some old aliases build the Dev
  file but miss the update script (`04b-customize-rls.sql`,
  `03d-customize-policies.sql`), and when two aliases exist only the first is
  used. `CustomizationType` is not read for these. `SQLTarget` must be empty or
  `Postgres`. **A row with any other `Name` is ignored by the build** (the build
  report lists it, with no warning).

Prefer an override to adding to a whole file: it keeps the rest of the object
following the rulebook automatically.

**The `01b` gap.** `update-effortless-schema.sql` runs the `02b`, `03b`, `04b`
and `05b` rows (steps 6, 8, 9 and 10 below) but has **no section for
`01b-customize-schema.sql`**. That row reaches only Dev, through its seeded file.
So nothing designated carries a hand-written index to a stage. Ask the owner how
to carry one (an additive migration, or an idempotent `CREATE INDEX IF NOT
EXISTS` in the `05b` row) before relying on it in production. FK constraints
come from rulebook relationships (`99-fk-constraints.sql`), not from a row.

**Hard-coding a function = one `FunctionOverride` row.** When a generated
`calc_*`/`get_*` function (or a `vw_*` view) is too slow or needs a hand-written
form, add a row: `CustomizationType` `FunctionOverride`, `Name` the object it
replaces (`calc_x` or `vw_x`), `SQLCode` the full `CREATE OR REPLACE ...` with
the same signature. Then `effortless build`. Since rulebook-to-postgres
**v2026.11.02.1548** the row rides in `update-effortless-schema.sql` (section 8b,
after the generated functions and views, functions before views, inside the
transaction), so it follows the project **everywhere its database is
installed**: a stage's Publish, production, a restored copy; Dev gets it from
`function-overrides/`. Before that version only `function-overrides/` had it,
which `reset-rulebook-db.sh` alone runs, and a Publish quietly put the slow
generated function back (a 100x slower class page in Production, 2026-11-02).
Rules that follow from it:

- Never edit `postgres/function-overrides/*.sql`: they are regenerated from the
  rows. Edit the row.
- **A broken override fails differently in Dev and on a stage.** Dev's reset only
  warns (`[WARN] … failed (non-fatal)`) and keeps the generated version; on a
  stage it rolls the whole script back, with the error's line just below
  `-- Override (<kind>): <Name>`. So a broken override shows first at Publish.
  Fix the row.
- An override is a COPY of a rule: when the formula it replaces changes, change
  the row too (say so in its `SQLCode` header).
- Only function and view overrides ride the derived script. A **table** override
  (it drops the table) is a migration's job, and a **policy** override is listed,
  not applied, because policies are rebuilt after the derived script. Both run
  only from `function-overrides/` in Dev's reset.

**A row whose `SQLCode` is only a boilerplate header comment is dead weight** —
it causes a comments-only `*b-` file to be seeded and implies a customization that
doesn't exist. Delete those rows.

#### Hand-maintained objects (the exception, not the default)

By default **everything follows the rulebook**: every view and `calc_*` function
is dropped and recreated on each derived-layer rebuild. An object that must be
maintained by hand can be marked to survive the drop — but this is an
exceptional situation. Opting *out* of automation is a deliberate, documented
act; there is no way to opt in, because following the rulebook is the default.

---

## The two scripts

`effortless build` emits two entry points. They share the derived-layer logic
and differ only in whether tables are dropped.

### `reset-rulebook-db.sh` — LOCALHOST ONLY

Drops and recreates **everything**, then reseeds from the rulebook. This is "the
loop": the dev database becomes a byte-for-byte mirror of the rulebook. Refuses
to run against a non-localhost connection.

*(Formerly `init-db.sh`. The rename exists because "init" understated what it
does — it is a destructive reset, and it was being run against databases that
held real data.)*

### `update-effortless-schema.sql` — SAFE IN PRODUCTION

One generated file that brings any database in line with the current rulebook
**without touching row data**, in this order:

1. Add missing tables and columns (additive only — never drops a table or column)
2. Drop all `vw_*` views
3. Drop all `calc_*`/`get_*` functions, **leaf-up through the DAG** (a calc
   function may call another; alphabetical order hits dependency errors)
4. Upsert data from tables marked static (reference data that is part of the model)
5. Recreate all `calc_*` functions
6. Re-run the `02b-customize-functions.sql` row from ERBCustomizations
7. Recreate all `vw_*` views
8. Re-run the `03b-customize-views.sql` row
   8b. Apply the `FunctionOverride` / `SchemaOverride` rows for functions, then
   views (rulebook-to-postgres v2026.11.02.1548 on)
9. Re-run the `04b-customize-policies.sql` row. The RBAC policy layer is not in
   this file: it runs after the whole file (see below)
10. Re-run the `05b-customize-data.sql` row (there is no step for the `01b` row)

Steps 5–10 alternate generated/custom on purpose: each custom layer builds on the
generated layer beneath it.

**This is what a routine promotion runs.** Version to version, most migrations
are nothing more than re-running the current `update-effortless-schema.sql`.
Always right, never wrong, by construction. A hand-authored migration is needed
only for genuine table/column changes that step 1 cannot infer — and it should
contain *nothing else*.

**The order of preference, every time the database must change:**

1. **The rulebook** — tables, fields, formulas. `update-effortless-schema.sql`
   does whatever the rulebook says.
2. **An `ERBCustomizations` row** — where the generated SQL needs correcting,
   tuning or extending (a hand-written function, a view, RLS, grants, seed data).
   Re-running the derived script re-applies it on every stage. An index has no
   designated row yet (the `01b` gap): ask the owner.
3. **A custom migration** — only what fits neither: a table/column change the
   additive step cannot infer, a data fix. Tables and columns only, never view or
   function DDL. (Whether an additive `CREATE INDEX IF NOT EXISTS` belongs here
   is the owner's call until the `01b` gap is closed.)

### Pairing with the RBAC policy layer

`effortless-rbac-to-postgres-policies` emits
`drop-update-effortless-postgres-policies.sql`, which follows the identical
model: RLS policies and role schemas are derived objects, so they are dropped
and recreated from the rulebook rather than migrated.

**Ordering matters:** policies reference columns and views, so the RBAC script
runs *after* the whole derived script, as its own file. Role-schema copies of
`vw_*` views are rebuilt in the same pass, which removes an entire class of
failure (a migration that recreates a public view and forgets its role-schema
mirrors). Never hand-migrate a policy or a role schema.

See `effortless-rbac` for the RBAC model itself.

## Converting a legacy project to the derived-layer format

Older projects keep domain tables in `01b-customize-schema.sql` and loose
`*b-customize-*.sql` files beside the rulebook. Converting is mechanical and
worth doing: promoted tables gain views, calculated fields, RuleSpeak and the
Explainer DAG they were silently missing.

**1. Inventory the customize file.** Sort every statement into four piles:

| Pile | Examples | Destination |
|---|---|---|
| Domain entities | anything with a lifecycle, a money amount, or an FK into a rulebook table | **the rulebook** |
| Columns `ALTER`ed onto rulebook tables | `created_at`, `notes`, a bolted-on FK | **the rulebook**, on that table |
| Deployment plumbing | sessions, API tokens, sync logs | **the rulebook**, as tables (a stage needs them; a row would not carry them) |
| Indexes | `CREATE INDEX` | ask the owner first (the `01b` gap); if it is the `01b-customize-schema.sql` row, it reaches Dev only |

The giveaway for pile 1 is the table's own comment. If it describes what the
business does ("what we owe each consignor, per sale"), it is domain data.

**2. Promote piles 1 to 3 into the rulebook.** Define each table with its raw fields,
`relationship` fields for FKs (plus the matching inverse on the target table),
and `lookup` fields for anything the app currently JOINs to get. This is the
moment to reclaim hand-maintained columns as calculated fields — a `status` the
app keeps in step by hand is usually derivable:

```jsonc
{ "name": "IsPaid", "datatype": "boolean", "type": "calculated",
  "formula": "=IF({{PaidAt}}=\"\", FALSE, TRUE)" }
```

**3. Pile 4 (indexes): ask the owner first** (the `01b` gap). If the answer is
the `01b-customize-schema.sql` row: one row with that `Name` (the `Name` routes
it; `CustomizationType` `Schema` is only a label), the SQL in `SQLCode`, then
**delete the file** so the next build seeds it from the row. It reaches Dev
only.

**4. Delete empty stub rows.** A row whose `SQLCode` is only a boilerplate
header seeds a comments-only file and implies a customization that doesn't exist.
Delete duplicates too — two rows naming the same file under different names
(`01b-…` and `03a-…`) is the mismatch that hides real content: the build uses
only the first alias it finds.

**5. Rebuild and verify.** Check that each promoted table now has a `vw_*` view
and that its calculated fields compute. Then run `update-effortless-schema.sql`
against a scratch copy and confirm the view/function counts match a fresh
`reset-rulebook-db.sh` build of the same rulebook, and row counts are unchanged.

> **Watch the column names.** Rulebook FK fields generate as the field name
> (`product`, `sales_order`), not the old hand-written `product_id`. Any index
> you carry over must be updated to match, or it will fail with
> `column "…_id" does not exist`.

**6. Migrate the data.** Steps 1-5 change the schema. Existing rows in the old
tables still need moving, and app code still reads the old column names. On a
dev database a reset handles it; anywhere else this is a real data migration.

---

## Generated SQL Details

### Table Creation (01)
- Tables contain ONLY raw fields (no calculated/lookup/aggregation columns)
- Primary key is always `{table_name}_id TEXT PRIMARY KEY`
- Column names are snake_case versions of PascalCase field names
- Each column has a `COMMENT` with the field's Description

```sql
CREATE TABLE workflow_steps (
  workflow_step_id TEXT PRIMARY KEY,
  label TEXT,
  sequence_position INTEGER,
  requires_human_approval BOOLEAN,
  is_step_of TEXT,              -- FK to workflows (no _id suffix in schema)
  assigned_role TEXT             -- FK to roles
);
COMMENT ON COLUMN workflow_steps.label IS 'Human-readable name...';
```

### Functions (02)
- One `get_{table}_{field}(p_{pk} TEXT)` function per raw field (single-row retrieval)
- One `calc_{table}_{field}(p_{pk} TEXT)` function per calculated/lookup/aggregation field
- All functions are `LANGUAGE plpgsql STABLE SECURITY DEFINER`

```sql
-- Lookup: resolves FK to get a field from related table
CREATE OR REPLACE FUNCTION calc_workflow_steps_assigned_role_label(p_workflow_step_id TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT label FROM roles
          WHERE role_id = (SELECT assigned_role FROM workflow_steps
                           WHERE workflow_step_id = p_workflow_step_id));
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Aggregation: counts related rows
CREATE OR REPLACE FUNCTION calc_workflows_count_of_workflow_steps(p_workflow_id TEXT)
RETURNS INTEGER AS $$
BEGIN
  RETURN (SELECT COUNT(*) FROM workflow_steps WHERE is_step_of = p_workflow_id)::integer;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
```

### Views (03)
- One `vw_{table_name}` view per table
- SELECTs all raw fields from base table + all calculated fields via function calls
- All views use `WITH (security_invoker = ON)`

```sql
CREATE OR REPLACE VIEW vw_workflow_steps WITH (security_invoker = ON) AS
SELECT
  t.workflow_step_id,
  t.label,
  t.sequence_position,
  t.requires_human_approval,
  t.is_step_of,
  calc_workflow_steps_is_step_of_title(t.workflow_step_id) AS is_step_of_title,
  t.assigned_role,
  calc_workflow_steps_assigned_role_label(t.workflow_step_id) AS assigned_role_label,
  calc_workflow_steps_assigned_role_filled_by(t.workflow_step_id) AS assigned_role_filled_by
FROM workflow_steps t;
```

---

## View Field Naming Conventions

### FK Lookup Fields
For any foreign key `foo`, the view includes:
- `foo` - the raw FK value (the ID)
- `foo_name` - display name of related entity
- `foo_label` - alternative display (if the related entity uses Label instead of Name)
- `foo_{field}` - any field from the related entity

### Calculated Field Patterns
- `*_count` / `count_of_*` - count of related items
- `*_amount` - monetary totals
- `is_*` - boolean flags
- `*_status` - status lookups
- `*_at` - timestamps

---

## See also

- `effortless-orchestrator` — canonical Token Discipline section; this skill restates the same rule from the SQL angle.
- `effortless-query` — for the rulebook one-liners that replace `cat`-ing the generated SQL.
- `effortless-conventions` — for the naming patterns that explain why view columns look the way they do.
- `effortless-workflow` — for the rule that a customization is an `ERBCustomizations` row for infra only, never a business entity (and never a legacy `*b-customize-*.sql` file).
- `effortless-diagnostics` — for finding JOIN anti-patterns and broken FK targets.
