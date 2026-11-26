---
name: effortless-diagnostics
description: >
  ERB project health — slow vw_* views (cache a slow-changing sub-DAG at the parent:
  XyzOverride / DefaultXyz / Xyz), DAG integrity, broken FK targets, JOIN anti-patterns,
  moving base-table reads to vw_* views, diagnostic queries. ERB projects only.
audience: customer
---

# ERB Diagnostics & Migration

Most "bugs" in an ERB project are **hub/spoke drift** — a rule exists in the
hub but a generated spoke hasn't been rebuilt to match, or a piece of app code
has gone out of sync with the view it consumes. The queries below help you
spot that state, not assign blame.

## Slow views: cache the slow-changing sub-DAG at the parent

A project's database (the editor, a Loops run, local dev) holds the rulebook's **mock data**: a
few dozen rows a table. **A `vw_*` view that takes more than 1-2 seconds to read whole there is a
model problem**, and real data makes it far worse (it is usually quadratic). The cause is almost
always an expensive sub-DAG (a lookup through a rollup through a lookup) recomputed for every row,
whose value is static, immutable or slow-changing. Check after every rebuild:

```bash
bash ~/.claude/skills/effortless-diagnostics/view-timings.sh "$DATABASE_URL"            # every view; exit 1 if any > 1500 ms
bash ~/.claude/skills/effortless-diagnostics/view-timings.sh "$DATABASE_URL" --columns vw_x  # which column is the cost
```

In a Loops run this is automatic: the run times every view after each build (`viewTimings` on
`/__boot/status`) and Loops puts a SLOW VIEWS note ahead of the next message. Treat that note as
work for this turn, after what the customer asked.

**The fix is in the rulebook: override / default / final.** For the expensive field `Xyz`:

```json
{ "name": "XyzOverride", "type": "raw", "datatype": "number", "nullable": true,
  "Description": "A settled or hand-set value. Blank: Xyz is computed (DefaultXyz)." },
{ "name": "DefaultXyz", "type": "lookup", "datatype": "number", "formula": "<the expensive formula, unchanged>" },
{ "name": "Xyz", "type": "calculated", "datatype": "number",
  "formula": "=IF(ISBLANK({{XyzOverride}}), {{DefaultXyz}}, {{XyzOverride}})" }
```

- **Every consumer reads `Xyz`**, never `DefaultXyz` (rename the old field to `DefaultXyz` and give
  the final value the old name, so consumers need no change).
- The generated SQL is a `CASE`, so **a filled override never evaluates the sub-DAG**. That is the
  cache: fill it where the value is settled (a closed period, a price at the time of the sale, an
  imported historical row, a parent whose children no longer change), at write time by the app or
  by a rule-driven refresh. Leave it blank where the value must stay live.
- The same three fields are how a person customizes a computed value: the override wins, blank
  goes back to the rule. One shape for both.
- **Cache at the parent**: when many children read the same expensive value through a parent (a
  rollup on an estimate read by every one of its timelogs), put the override on the parent, so one
  row holds it and every child's lookup is one hop.
- Never an index, a materialized view or a hand-written SQL function for this: the rule would then
  live outside the rulebook. Rebuild and time the view again; say what you cached and why.

### What rulebook-to-postgres already does, and the cache you can turn on

- **`optimize_reads` is ON by default** (`dag_depth_over:1`). The tool rewrites only the BODY of a
  slow `calc_*` function, never a view: a COUNTIFS/SUMIFS/MINIFS/MAXIFS that scans a child and
  filters or sums one of the child's computed fields reads that field's own body inline instead of
  calling its `calc_*` once per scanned row, and the owner's own operand is evaluated once. A field
  with a `FunctionOverride` is never inlined. `-p optimize_reads=none` turns it off. Measured: PKO
  `vw_role_schema_views` 28.6 s -> 7.4 s, South Park `vw_statements` 9.5 s -> 1.75 s, same rows.
- **`memo_fields` is OFF by default; turn it on only when asked for** (owner, 2026-11-26). Some
  shapes cannot share work inside a per-row function: a parent value read by every child, a deep
  stratified chain (South Park's Statements -> Firings -> Statements). For those,
  `-p memo_fields=Table.Field,Table.Field` in the `rulebooktopostgres` CommandLine keeps each named
  field's values in an UNLOGGED `erb_memo_<t>_<f>` table: the function keeps its name and answers
  from the cache, a statement trigger on every table the value can reach empties and refills it on a
  write, and `06-refresh-memos.sql` fills it after the seed. The views are unchanged. It is an extra
  object per field and every write pays a refill, so offer it, say the cost, and add it only on a yes.
- **A view is always `SELECT t.<col>, …, calc_<table>_<field>(t.<pk>) AS <field> FROM <table> t`.**
  Never put a join, LATERAL, CTE or subquery into a `vw_*`, not even to make it fast.

## Diagnostic Queries Against the Rulebook (start here — cheapest)

### Validate DAG (check for missing FK targets)

```bash
cat effortless-rulebook.json | python3 -c "
import sys,json; d=json.load(sys.stdin)
tables={k for k,v in d.items() if isinstance(v,dict) and 'schema' in v}
for k,v in d.items():
  if isinstance(v,dict) and 'schema' in v:
    for f in v['schema']:
      if f['type']=='relationship' and f.get('RelatedTo') not in tables:
        print(f'  BROKEN FK: {k}.{f[\"name\"]} -> {f.get(\"RelatedTo\")} (not found)')
"
```

## Diagnostic Queries Against Generated Code (secondary)

```bash
# Find JOIN anti-patterns in Go code
grep -r "JOIN" cmd/api/*.go | grep -v "// " | wc -l
# Should be ~0 for a healthy codebase

# Find base table reads
grep -rE "FROM (bids|rfps|companies|contacts|documents)\s" cmd/api/*.go
# Should mostly be INSERTs, UPDATEs, DELETEs

# Find view usage
grep -r "FROM vw_" cmd/api/*.go | wc -l
# Should be high - this is where reads happen
```

---

## Migration Path for Legacy Code

When fixing JOIN anti-patterns:

1. Identify what fields the JOIN is fetching
2. Verify those fields exist in the source view (check the rulebook first)
3. Remove the JOIN, select from the view directly
4. If a field is missing, extend the hub (rulebook-direct or via Airtable) so it shows up in the next build's view — patching the app to recompute it duplicates the rule

### Before
```go
rows, _ := db.Query(`
    SELECT b.bid_id, b.rfp, c.company_name, r.title
    FROM bids b
    JOIN companies c ON b.submitted_by_vendor = c.companie_id
    JOIN rfps r ON b.rfp = r.rfp_id
    WHERE b.bid_id = $1`, bidID)
```

### After
```go
rows, _ := db.Query(`
    SELECT bid_id, rfp, company_name, rfp_title
    FROM vw_bids
    WHERE bid_id = $1`, bidID)
```

---

## See also

- `effortless-query` — for the rulebook one-liners these diagnostics rely on.
- `effortless-sql` — for the "always read from `vw_*`" rule and the one way to customize generated SQL (`ERBCustomizations` rows).
- `effortless-conventions` — for the DAG / FK rules that define what "broken" means.
- `effortless-workflow` — for the input-spoke options when a diagnostic finds a missing field (hub-direct, Airtable, reverse-sync) and why those persist while generated-file edits don't.
