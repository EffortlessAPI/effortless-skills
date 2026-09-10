---
name: effortless-progress-report
description: >
  Delivery / status / priced-plan reports derived from the rulebook via
  rulebook-to-progress-report; also adds the delivery spine (ERBUserStories,
  ERBAcceptanceCriteria, ERBBuildPhases, ERBEffortClasses) to a rulebook that lacks
  one — via the editor's Modules → Delivery, or by hand.
  Triggers: "progress report", "delivery report", "how far along is this", "what's
  accepted / what's left", "priced plan", "add user stories to the rulebook". ERB
  projects only.
audience: customer
---

# Effortless Progress Report — the rulebook says where the project stands

`rulebook-to-progress-report` turns `effortless-rulebook.json` into a delivery
report: **one self-contained HTML file** carrying the argument for the delivery
approach, the full priced plan, and a scope selector a reader can drive — turning
user stories on and off and watching every figure, the prose included, re-derive.

## The idea, in one paragraph

A status document is the artifact most likely to be wrong. It is written once
from figures true on the day, and then the plan changes; next quarter's version
still claims four phases after the plan has five. That is not carelessness — it
is what happens whenever a document is a **copy** of a model rather than a
**view** of one.

So: **project status is not a document you write. It is data you keep in the
rulebook, and the report is a projection of it** — exactly like the database,
the API and the security model. Change a story's phase, tick an acceptance
criterion, move a price, and every figure in the report says something different
on the next build. There is no second copy to keep in step.

That is why this skill is mostly about **the rulebook**, not about the tool. The
tool is twelve lines of `effortless.json`. The work is getting delivery status
into the single source of truth where it belongs.

---

## 1. Does this rulebook already have a delivery spine?

```bash
python3 - <<'PY'
import json
d = json.load(open("effortless-rulebook/effortless-rulebook.json"))
aliases = d.get("_meta", {}).get("erb", {}).get("aliases", {})
need = ["ERBUserStories","ERBAcceptanceCriteria","ERBBuildPhases","ERBFeatures",
        "ERBEpics","ERBPackages","ERBEffortClasses","ERBDeliveryDisciplines"]
for t in need:
    physical = aliases.get(t, {}).get("table", t)
    n = len(d.get(physical, {}).get("data", []))
    tag = f" (mapped to {physical})" if physical != t else ""
    print(f"{'OK ' if n else 'MISSING'}  {t:24} {n} rows{tag}")
print("delivery module:", "on" if d.get("_meta", {}).get("erb", {}).get("modules", {}).get("delivery", {}).get("enabled") else "off")
PY
```

- **All eight present** → go to step 2.
- **Some missing** → go to §"Adding a delivery spine" below, then step 2.
- **The rulebook already has these tables under other names** (`UserStories`,
  `EffortClasses`, a `Category` field on features…) → do **not** rename them. Map
  them once in `_meta.erb.aliases` (see §"Keeping your own names") and the tool reads
  them as the canonical tables.

---

## 2. Install

```bash
mkdir -p progress-report
cd progress-report
effortless -install rulebook-to-progress-report -i ../effortless-rulebook/effortless-rulebook.json
cd ..
```

Expected `ProjectTranspilers` entry in `effortless.json`:

```json
{
  "IsSSoTTranspiler": false,
  "Name": "rulebooktoprogressreport",
  "RelativePath": "/progress-report",
  "CommandLine": "rulebook-to-progress-report -i ../effortless-rulebook/effortless-rulebook.json",
  "IsDisabled": false,
  "Description": "Delivery report — status, scope and price, derived from the rulebook."
}
```

## 3. Build

```bash
effortless build
```

| File | Purpose |
|---|---|
| `progress-report/progress-report.html` | The interactive report — hand this to a reader |
| `progress-report/narrative.html` | The argument alone, led by the current bid |
| `progress-report/report-summary.md` | **Read this first.** Headline figures, and which sections still speak in the tool's generic voice |

## 4. Report back

Tell the user the path to `progress-report/progress-report.html`, the headline
figures from `report-summary.md`, and — if any sections are still generic — that
adding `ProposalSections` rows will put the argument in their own words.

---

## Adding a delivery spine to a rulebook that has none

This is the substance of the skill. The eight tables are a **delivery model**,
not report decoration: they are how a project keeps its own status.

The easiest way: open the rulebook editor (`effortless-rulebook-editor` skill),
go to **Modules**, and switch on **Delivery**. The editor creates all nine tables
with their descriptions, seeds `ERBEffortClasses` (G1–G3) and
`ERBDeliveryDisciplines` (Build 70 / Assurance 30), adds the Progress Report tab,
and enables the `rulebooktoprogressreport` build step. Then add stories.

By hand works too — edit the JSON like anything else. **Never generate the
rulebook from a script**; it is the source of truth, not a build artifact.

Every table and field below is an **ERB canonical name** (the contract is
`docs/ERB-MODEL.md` in Versioned-Stable-SSoTme-Tools).

### The shape

```
ERBPackages             a body of work someone would buy or schedule as a unit
 └ ERBEpics             an epic
    └ ERBFeatures       a capability
       └ ERBUserStories THE ATOM — the thing a reader selects
          └ ERBAcceptanceCriteria   what "done" means, one row per criterion

ERBBuildPhases          a price and a date. Stories are assigned to one.
ERBEffortClasses        complexity bands. A story's band × its criteria = its price share.
ERBDeliveryDisciplines  how every price divides (Build 70% / Assurance 30%, …)
ERBProposalSections     your own prose for the document (optional)
```

### Minimum viable spine

One row per table generates a report. Copy this, then grow it:

```json
{
  "ERBPackages": { "data": [
    { "ERBPackageId": "core", "Title": "Core platform",
      "PrimaryPhase": "phase-1", "SortOrder": 1 } ] },

  "ERBEpics": { "data": [
    { "ERBEpicId": "accounts", "Title": "Accounts",
      "ERBPackage": "core", "SortOrder": 1 } ] },

  "ERBFeatures": { "data": [
    { "ERBFeatureId": "signin", "Title": "Sign in", "ERBEpic": "accounts", "ERBPackage": "core" } ] },

  "ERBEffortClasses": { "data": [
    { "ERBEffortClassId": "G1", "Title": "Routine",   "ComplexityWeight": 1,   "SortOrder": 1 },
    { "ERBEffortClassId": "G2", "Title": "Involved",  "ComplexityWeight": 1.6, "SortOrder": 2 },
    { "ERBEffortClassId": "G3", "Title": "Demanding", "ComplexityWeight": 2.5, "SortOrder": 3 } ] },

  "ERBDeliveryDisciplines": { "data": [
    { "ERBDeliveryDisciplineId": "build",  "Title": "Build",     "SharePercent": 70,
      "Description": "Modelling and generation", "ClientVisible": true, "SortOrder": 1 },
    { "ERBDeliveryDisciplineId": "assure", "Title": "Assurance", "SharePercent": 30,
      "Description": "Testing and acceptance",   "ClientVisible": true, "SortOrder": 2 } ] },

  "ERBBuildPhases": { "data": [
    { "ERBBuildPhaseId": "phase-1", "PhaseNumber": 1,
      "Title": "Phase 1 — Core platform", "QuotedPrice": 120000,
      "DurationMonths": 3, "PhaseKind": "fixed-price", "IsCurrentBid": true } ] },

  "ERBUserStories": { "data": [
    { "ERBUserStoryId": "acc-01", "ReqId": "ACC-01",
      "StoryText": "As a user I can sign in so that my work is mine.",
      "ERBBuildPhase": "phase-1", "ERBEpic": "accounts", "ERBFeature": "signin",
      "ERBEffortClass": "G1" } ] },

  "ERBAcceptanceCriteria": { "data": [
    { "ERBAcceptanceCriterionId": "acc-01-a", "ERBUserStory": "acc-01",
      "Criterion": "A valid email and password signs the user in.",
      "SortOrder": 1 } ] }
}
```

### Five things to get right

1. **`ERBUserStories.ERBEpic` is read directly**, not inferred through `ERBFeature`.
   Set both `ERBEpic` and `ERBFeature` on every story.
2. **Name the most demanding effort class `G3`.** `{hardStories}` and the
   client-side code both look for that exact literal. Name it something else and
   the figure is `0` everywhere — quietly, with no error.
3. **Client-visible `SharePercent` must sum to 100.** Every price divides by
   these; otherwise the parts stop adding back to the total.
4. **No `ComplexityWeight` may be `0`.** Pricing is `criteria × weight`; a zero
   band prices its stories at $0.
5. **Exactly one phase carries `IsCurrentBid`.** It is the phase the document is
   asking for, and `{bid.*}` resolves to it.

### Then make the dependency graph real

`ERBUserStories.DependsOnStory` names the one story that must be accepted first.
It drives the whole scope cascade: removing a story removes everything
transitively downstream, adding one pulls in its whole ancestor chain. Must be
acyclic.

Without it the report still generates — the scope selector just has nothing to
cascade, so removing a story removes only that story.

### Keeping your own names

A rulebook that already carries this spine under other names keeps them. Map
once in `_meta.erb.aliases` — canonical table → your table, and any field whose
name differs:

```json
"_meta": { "erb": { "modules": { "delivery": { "enabled": true } },
  "aliases": {
    "ERBEpics":              { "table": "ERBFeatureCategories", "fields": { "ERBEpicId": "ERBFeatureCategoryId" } },
    "ERBFeatures":           { "table": "ERBFeatures",          "fields": { "ERBEpic": "Category" } },
    "ERBEffortClasses":      { "table": "EffortClasses" },
    "ERBDeliveryDisciplines":{ "table": "DeliveryDisciplines" },
    "ERBBuildPhases":        { "table": "BuildPhases" },
    "ERBUserStories":        { "table": "UserStories", "fields": { "ERBBuildPhase": "BuildPhase", "ERBEpic": "Epic", "ERBFeature": "Feature", "ERBEffortClass": "EffortClass" } },
    "ERBAcceptanceCriteria": { "table": "AcceptanceCriteria", "fields": { "ERBUserStory": "UserStory" } } } } }
```

Keys not listed map to themselves. A table's key is found under the canonical
name, `<Singular>Id` of your table name, or `Id` — anything else must be named in
`fields`, or the tool refuses and says which three names it tried.

### Meta tables

`ERBProposalSections`, `ERBDeliveryDisciplines` and `ERBEffortClasses` are **meta
tables**: they drive this document, not the domain. With the Schema module on,
`ERBTables` mirrors every table and marks these `IsMetaTable`; that flag (or the
table's absence from a hand-kept `ERBTables`) is what keeps them out of the
security model.

---

## Keeping status current

Once the spine exists, "where does the project stand?" is a rulebook edit, and
the report follows on the next build:

| To record | Set |
|---|---|
| A criterion is signed off | `ERBAcceptanceCriteria.IsAccepted` (+ `AcceptedBy`, `AcceptedAt`) |
| A task's progress | `ImplementationTasks.DevProgressPercent` |
| Work is waiting on the client | `ERBUserStories.Roadblock` → a `Roadblocks` row |
| A blocker cleared | `Roadblocks.IsResolved` — it drops out of the report entirely |
| Scope moved between phases | `ERBUserStories.ERBBuildPhase` |
| The bid moved on | `BuildPhases.IsCurrentBid` |

`{accepted}`, `{acceptedPct}`, `{roadblocks}` and the per-phase figures all
re-derive. Nothing else has to be touched.

---

## Making the argument yours

The shipped narrative is a real argument for rulebook-first delivery, and it is
deliberately impersonal: **no numbers, no domain nouns.** `report-summary.md`
names the sections still running on it.

Add `ProposalSections` rows to speak in the project's own voice:

```json
{ "ProposalSectionId": "ps-01",
  "SectionKey": "security",
  "Mode": "append",
  "Body": "For a platform handling {rules} regulated business rules across {roles} roles, that matters more than usual.",
  "SortOrder": 1,
  "ClientVisible": true }
```

- **`SectionKey`** — one of `what-this-is`, `cost-curve`, `mechanism`, `cadence`,
  `explainability`, `security`, `lock-in`, `outcome`, plus the three shell keys
  `masthead`, `thesis`, `terms`.
- **`Mode`** — `append` (default), `prepend`, or `replace`.
- **`Body`** — `**bold**`, `*italic*`, and any `{placeholder}`.

**An unknown placeholder fails the build**, naming the section and listing every
valid key — rather than printing a literal `{brace}` in front of a client.

Put in a `ProposalSections` row anything **specific to the project** and anything
the **rulebook cannot evidence**. A retrospective judgement ("16 of the 25 proved
easier than expected") reads as a *measurement* when written in the same voice as
a derived figure — it belongs here, where it reads as the judgement it is.

Full placeholder list and every field: **[REFERENCE.md](REFERENCE.md)**.

---

## When it refuses

The tool emits `error.txt` instead of a report rather than publishing a wrong
number. Each message names the fix:

| Message | Fix |
|---|---|
| *missing N required table(s)* | Add them — see "Adding a delivery spine" |
| *ComplexityWeight of 0* | Give the band a weight, or move its stories |
| *shares sum to N%, not 100%* | Fix `DeliveryDisciplines.SharePercent` |
| *quoted at N but carries no units of work* | The phase has no stories, or its stories have no criteria |
| *N acceptance criteria have no text* | A field name changed — the tool reads `Criterion` |
| *more than one BuildPhase carries IsCurrentBid* | Exactly one |
| *unknown placeholder(s)* | Correct the token; the message lists every valid key |
| *carries no Effortless tables* | The request envelope arrived instead of the rulebook — check `-i` points at the rulebook |

---

## Do not

- **Do not put hours, team size, headcount or FTE counts in the output.** Effort
  is modelled in a rulebook as an internal feasibility instrument — "is this date
  achievable at the assumed throughput?" — and it is not a staffing commitment.
  The model layer does not carry it at all. What is committed to a reader is the
  **acceptance criteria and the date**, never the means. Where a client-facing
  figure needs a magnitude, use the acceptance-criteria count.
- **Do not derive price from hours.** `QuotedPrice` and `DurationMonths` are RAW
  inputs — a commercial judgement about what the delivered thing is worth on a
  calendar. Re-deriving price from effort will not reconcile, and reconciling it
  re-imports the hourly model this approach exists to reject.
- **Do not hand-edit the generated HTML.** It is regenerated on every build. If a
  number belongs in the prose it is a `{placeholder}`; if prose belongs in the
  document it is a `ProposalSections` row.
- **Do not write a status document alongside the rulebook.** That is the second
  copy this tool exists to eliminate.
- **Do not register the meta tables in `ERBTables`.**

---

## Related skills

| Skill | When |
|---|---|
| `effortless-schema` | the JSON structure of a rulebook table you are adding |
| `effortless-conventions` | PK / FK / DAG naming rules for new tables |
| `effortless-rulebook-editor` | edit the spine in a browser instead of the JSON |
| `effortless-rulespeak` | the same rulebook as plain-English business rules |
| `effortless-pipeline` | `effortless.json` and how the build resolves transpilers |
