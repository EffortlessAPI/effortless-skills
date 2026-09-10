# `rulebook-to-progress-report` — the input contract

> **Names.** Every table and field in this contract is an **ERB canonical name** (see
> `docs/ERB-MODEL.md` in Versioned-Stable-SSoTme-Tools). The rulebook editor's
> **Modules → Delivery** creates them. A rulebook that already keeps its delivery spine
> under other names (`UserStories`, `EffortClasses`, a `Category` field, …) does not
> rename anything: it maps them once in `_meta.erb.aliases` and the tool reads them as
> the canonical tables. Fields the contract does not know are carried through.


**What a rulebook must carry for this tool to produce a delivery report, and
what the report does with each part of it.**

This file is the authoritative contract. It is written to be read by a person
*or* by an agent aligning a rulebook to this format — the `effortless-progress-report`
skill in `effortless-skills` is a guided walkthrough of everything below.

> **This file is mirrored** into that skill as `REFERENCE.md`, because a skill
> is installed on machines with no copy of this repo. **This copy leads; change
> both together.**

---

## What comes out

Two self-contained HTML files and a build log:

| File | What it is |
|---|---|
| `progress-report/progress-report.html` | The interactive delivery report — the argument, the priced plan, and a scope selector a reader can drive |
| `progress-report/narrative.html` | The argument alone, led by whichever phase is the current bid |
| `progress-report/report-summary.md` | What was generated, and which sections still carry the shipped generic argument |

No CDN beyond webfonts, no build step, no server. Open from `file://`, email it,
or drop it on a static host.

---

## How content is resolved

Three layers, in this order:

```
the shipped template     the generic ERB delivery argument — ships with the tool
      +
derived facts            every number, computed from YOUR rulebook
      +
ProposalSections rows    prose that tightens it to YOUR domain
      ↓
                one delivery report
```

The template contains **no numbers and no domain nouns**. Numbers are
`{placeholders}` resolved from the rulebook, so the prose cannot drift from what
it describes. Domain specifics — the regulator, the form, the industry — arrive
through `ERBProposalSections`.

**A rulebook with no `ERBProposalSections` rows still produces a complete, honest
report** — just a generic one. `report-summary.md` names which sections are
still generic, so you know where your own voice would earn the most.

---

## Required tables

Without these there is no report. The tool refuses and names every missing one
at once.

| Table | Fields it must carry | What the report does with it |
|---|---|---|
| `ERBUserStories` | `ERBUserStoryId`, `ReqId`, `StoryText`, `ERBBuildPhase`, `ERBEpic`, `ERBFeature`, `ERBEffortClass` | the atom of scope; one row per selectable item |
| `ERBAcceptanceCriteria` | `ERBAcceptanceCriterionId`, `ERBUserStory`, `Criterion` | what is being committed to; the unit of pricing |
| `ERBBuildPhases` | `ERBBuildPhaseId`, `PhaseNumber`, `Title`, `QuotedPrice`, `DurationMonths`, `PhaseKind` | price and schedule |
| `ERBFeatures` | `ERBFeatureId`, `ERBEpic`, `ERBPackage` | routes a story to its package |
| `ERBEpics` | `ERBEpicId`, `Title`, `ERBPackage`, `SortOrder` | epics |
| `ERBPackages` | `ERBPackageId`, `Title`, `PrimaryPhase`, `SortOrder` | packages |
| `ERBEffortClasses` | `ERBEffortClassId`, `Title`, `ComplexityWeight`, `SortOrder` | the complexity weight that drives pricing |
| `ERBDeliveryDisciplines` | `ERBDeliveryDisciplineId`, `Title`, `SharePercent`, `Description`, `ClientVisible`, `SortOrder` | how every price divides |

### The chain that has to join up

A story reaches its package through the feature graph, and a broken link there
is the single most common alignment failure:

```
ERBUserStories.ERBFeature      →  ERBFeatures.ERBFeatureId
ERBFeatures.ERBEpic            →  ERBEpics.ERBEpicId                    (the epic)
ERBFeatures.ERBPackage   ─┐
ERBEpics.ERBPackage      ─┴→  ERBPackages.ERBPackageId              (first non-blank wins)
ERBUserStories.ERBBuildPhase   →  ERBBuildPhases.ERBBuildPhaseId
ERBUserStories.ERBEpic         →  ERBEpics.ERBEpicId
ERBUserStories.ERBEffortClass  →  ERBEffortClasses.ERBEffortClassId
ERBAcceptanceCriteria.ERBUserStory → ERBUserStories.ERBUserStoryId
```

`ERBUserStories.Epic` is read directly, *not* inferred through `ERBFeature`. Set both.

### Three hard constraints

**`ComplexityWeight` must be non-zero** on every effort class a story uses.
Pricing is `criteria × weight = units of work`; a band weighted zero contributes
nothing to the phase it sits in and prices its stories at $0 — silently, in a
document someone is about to send a client. The tool refuses.

**Client-visible `SharePercent` must sum to 100** (±0.5). Every price in the
document is split by these; if they do not sum to 100 the parts stop adding back
to the total being quoted. The tool refuses.

**Every quoted phase must contain work.** A phase with a `QuotedPrice` but no
stories — or stories with no acceptance criteria — has an undefined rate per
unit. The tool refuses rather than emitting zeroes.

---

## Optional tables

Absent means the corresponding content is simply omitted. Nothing errors.

| Table | What it adds |
|---|---|
| `ImplementationTasks` | the per-story task breakdown in the drill-down |
| `TaskArchetypes` | readable archetype names on those tasks |
| `Roadblocks` | external dependencies; the `{roadblocks}` family of facts |
| `ERBRoles`, `ERBTables`, `ERBFields` | the security figures the argument cites |
| `BusinessRules`, `GlossaryTerms`, `PlatformNavigation` | available as facts |
| `ERBProposalSections` | your own prose (see below) |

---

## Fields with meaning beyond their name

| Field | Effect |
|---|---|
| `ERBUserStories.DependsOnStory` | **drives the scope cascade.** Deselecting a story deselects everything transitively downstream; selecting one pulls in its whole ancestor chain. Must be acyclic. |
| `ERBUserStories.EffortClass` | selects the `ComplexityWeight`, so it **moves the price**. Set it by what the work *is*, never by a keyword in the story text. |
| `ERBUserStories.NeedsNewRulebookModelling` | feeds the "needs no new core modelling" count (`{modelled}`) |
| `ERBUserStories.SpikeCoveragePercent` | marks a story as prototyped before the bid (`{spikedStories}`) |
| `ERBUserStories.Roadblock` | marks the story as waiting on someone outside the build — shown as *external wait*, which is **not** the same as dependency-blocked |
| `ERBUserStories.RulebookGapNote` | the note shown when a story needs new modelling |
| `ERBBuildPhases.PhaseKind` | `fixed-price` \| `time-and-materials` \| `priced-option`. Drives the commercial grouping. |
| `ERBBuildPhases.IsCurrentBid` | the one phase this document is asking for. Exactly one. |
| `ERBAcceptanceCriteria.SortOrder` | the order criteria are read in |
| `ERBAcceptanceCriteria.DependsOnCriterion` | per-criterion readiness in the drill-down |
| `ERBAcceptanceCriteria.IsAccepted` | the acceptance ledger — `{accepted}`, `{acceptedPct}` |
| `Roadblocks.IsResolved` | a resolved roadblock drops out of the report entirely |
| `ERBDeliveryDisciplines.ClientVisible` | only client-visible disciplines are shown, and only those must sum to 100 |

### The `G3` naming convention

`{hardStories}` counts stories whose `ERBEffortClass` is literally **`G3`**, and
the client-side code re-derives the same figure the same way as the reader
changes scope. **Name your most demanding effort class `G3`.** Name it something
else and `{hardStories}` is `0` everywhere — quietly, with no error.

### `PhaseKind` and the commercial table

`IsInBaseBid` and `IsFixedPrice` are **calculated** fields. Generated Postgres
evaluates them, but a tool reading the JSON directly has no database, so they
are `null` on the row and the tool mirrors their formulas:

```
IsInBaseBid  = PhaseKind <> "priced-option"
IsFixedPrice = PhaseKind =  "fixed-price"
```

**These formulas exist in three places.** If you change one in a rulebook,
change all three: the rulebook's own `ERBBuildPhases` schema, `PhaseRec` in
`workload/services/ReportRecords.cs`, and `drawComm()` in
`workload/templates/scope.js` — which re-derives the table client-side as the
reader changes scope.

The commercial table is **live**. The generated rows are the no-JavaScript
fallback (correct for the full programme); `drawComm()` replaces them from the
stories actually in scope on every render. It was originally static only, which
made it the one table on the page that kept quoting the whole programme while
every other figure moved — and it is the table a reader takes to be the bid.

---

## Placeholders

Any of these may appear as `{name}` in a `ERBProposalSections.Body` or `Title`.
An **unknown placeholder fails the build**, naming the section and listing every
valid key — rather than printing a literal `{brace}` in front of a client.

### The model itself — never moves with scope

`tables` `fields` `computed` `computedPct` `rawPct` `metaTables` `securedTables`
`roles` `fieldGrants` `rules` `glossary` `routes` `tasks` `epics` `packages`
`phases`

Deselecting a story does not shrink the rulebook, so these are fixed. Anything
that describes the *model* belongs here.

### Scope — re-derives live as the reader changes what they are buying

`stories` `criteria` `modelled` `hardStories` `total` `accepted`

These render inside a span the client rewrites on every scope change, so the
prose restates itself rather than contradicting the tables below it. The span
carries the full-scope value, so **the document is correct with JavaScript
disabled**.

### Everything else

`unmodelled` `spikedStories` `unspikedStories` `baseTotal` `fixedTotal`
`fixedCriteria` `optionTotal` `monthsLow` `monthsHigh` `programmeMonths`
`roadblocks` `customerBlocks` `worstBlockDays` `acceptedPct`

### Per-phase families

`ERBBuildPhases.IsCurrentBid` marks the one phase the document is asking for.
**Exactly one** phase may carry it — two fails the build; none fails only when a
`{bid.*}` token is referenced or the narrative document is emitted. Which phase
is being sold is a commercial decision, so it is a rulebook fact and the tool
never carries its own copy of it.

| Token | Resolves to |
|---|---|
| `{bid.id}` `{bid.title}` `{bid.name}` `{bid.kind}` `{bid.price}` `{bid.criteria}` `{bid.stories}` `{bid.months}` `{bid.epics}` `{bid.packages}` | the phase marked `IsCurrentBid` |
| `{phase.<BuildPhaseId>.<field>}` | any phase by id — same fields, e.g. `{phase.phase-2.price}` |
| `{rest.phases}` `{rest.stories}` `{rest.criteria}` `{rest.total}` | everything that is *not* the current bid |

`{bid.name}` is the title after the em-dash ("SF330 Document Builder"), for
prose that has already said which phase it means; `{bid.title}` is the whole
thing.

### Format specs

Python-style, and only the two a prose document needs:

| Spec | `1162` renders as |
|---|---|
| `{criteria}` | `1162` |
| `{criteria:,}` | `1,162` |
| `{bid.price:,.0f}` | `164,000` |
| `{programmeMonths:,.1f}` | `9.8` |

---

## `ERBProposalSections` — the override surface

A **meta table**: it drives this document only. Like `ERBDeliveryDisciplines` and
`ERBEffortClasses`, it is deliberately **absent from `ERBTables`**, which is how a
rulebook marks a table as never generated into the database or the security
model. Do not register it there.

| Field | Meaning |
|---|---|
| `ERBProposalSectionId` | PK |
| `SectionKey` | which section this targets (below) |
| `Title` | heading override; blank keeps the shipped heading |
| `Body` | prose — `**bold**`, `*italic*`, and any `{placeholder}` |
| `Mode` | `replace` \| `append` \| `prepend` (default `append`) |
| `SortOrder` | order within a `SectionKey` |
| `ClientVisible` | literal `false` hides the row; absent means visible |

Markdown support is deliberately tiny — `**bold**`, `*italic*`, and the named
HTML entities the template uses. Prose here is written by people, and a fuller
dialect would invite raw HTML into a field rendered straight into a client-facing
document.

### The eight argument sections

| Key | The generic argument it carries |
|---|---|
| `what-this-is` | what a rulebook is, and why the spec executing changes things |
| `cost-curve` | why the 200th feature doesn't cost dramatically more than the 12th |
| `mechanism` | the eight-step chain from "logic in the rulebook" to "fixed price" |
| `cadence` | twice-weekly reviews, two-day turnaround |
| `explainability` | every number can show its work |
| `security` | a schema per role; audit evidence is a query |
| `lock-in` | what the client owns, and what happens if you disappear |
| `outcome` | buying an outcome, not a quantity of labour; the phase table |

Four are flagged as wanting a domain voice — `what-this-is`, `cost-curve`,
`security`, `lock-in` — and `report-summary.md` reports any still running on the
shipped text.

### The three shell sections

The same table also reaches the prose around the argument, so nothing
domain-specific has to be hardcoded in the tool:

| Key | What it controls | `Title` | `Body` |
|---|---|---|---|
| `masthead` | the headline and deck at the top of both documents | the `<h1>` | the paragraph(s) under it |
| `thesis` | the one-sentence band under the masthead | — | the sentence |
| `terms` | the letter-of-intent terms at the end of the report | — | extra clauses (`append`) or your own terms entirely (`replace`) |

Without a row, each falls back to generic wording that is true of any ERB
delivery and names no domain.

⚠️ **`terms` `replace` discards the shipped letter-of-intent language**, which
states plainly that the document is *not* a contract and no offer capable of
acceptance. If you replace it, say that yourself or say something you mean
instead.

### What belongs in an override

Anything **specific to your project** — its sources, its domain, its regulator —
and anything the **rulebook cannot evidence**.

That second category is the one people get wrong. A retrospective judgement
("16 of the 25 proved easier than expected") reads as a *measurement* when it is
written in the same voice as a derived figure. Put it in `ERBProposalSections`,
where it reads as the judgement it is. A number in the template must be
derivable, or it does not belong there at all.

---

## Parameters

All optional. The defaults produce a complete document from a rulebook alone.

| Parameter | Default | Effect |
|---|---|---|
| `-p narrative=true\|false\|only` | `true` | `true` emits both documents; `false` the report alone; `only` the narrative alone |
| `-p outDir=NAME` | `progress-report` | folder every file lands in |
| `-o NAME` / `-p output=NAME` | `progress-report.html` | the interactive report's filename |
| `-p narrativeOutput=NAME` | `narrative.html` | the narrative's filename |
| `-p title=...` | `Delivery Report` | the report's browser-tab title |
| `-p narrativeTitle=...` | `The Spine Is Already Modelled` | the narrative's browser-tab title |
| `-p video=URL` | — | adds an "About this bid" poster to the narrative |
| `-p monthsLow=N` `-p monthsHigh=N` | `8` / `10` | the committed calendar window the whole programme runs inside |
| `-p generatedOn=YYYY-MM-DD` | today (UTC) | pin the date stamped on the document |

`monthsLow`/`monthsHigh` cannot be derived: phases **overlap**, so the window is
never the sum of their durations.

`-p video` renders a **link, not an `<iframe>`**. Artifact and document viewers
commonly refuse external frames, and an embedded player then renders as an empty
black box for every reader, with no error anywhere. In print the poster is
dropped and the URL is printed instead.

Pin `generatedOn` when you need a reproducible build: a client-facing artifact
should be generated from ONE known rulebook commit and cite it, so a reader who
recounts gets the same numbers.

---

## What must never appear in the output

**No hours. No team size. No headcount. No FTE count. No hours-derived rate.**

`BackendHours`, `FrontendHours`, `DeliveryCapacityUnits` and their relatives are
an internal **feasibility instrument** — they answer "is this date achievable at
the assumed throughput?" — and they are not a staffing commitment. Capacity may
be one person, fifteen people, a model, or any mix, and may vary day to day.

The model layer does not carry them at all — *absent*, rather than carried and
hidden — so they cannot leak. **Keep it that way.** What is committed to a
client is the acceptance criteria and the date, never the means. Where a
client-facing figure needs a magnitude, the **acceptance-criteria count** is the
one to use, because it is what is actually being promised.

This is also why price is a raw input rather than a derived one. `QuotedPrice`
and `DurationMonths` are commercial judgements about what the delivered platform
is worth on a calendar. Re-deriving price from hours would not reconcile, and
reconciling it would re-import the hourly model this delivery approach exists to
reject.

---

## The smallest rulebook that produces a report

Every required table, one row each. This generates.

```json
{
  "ERBPackages":          { "data": [
    { "ERBPackageId": "core", "Title": "Core platform",
      "PrimaryPhase": "phase-1", "SortOrder": 1 } ] },
  "ERBEpics": { "data": [
    { "ERBEpicId": "accounts", "Title": "Accounts",
      "ERBPackage": "core", "SortOrder": 1 } ] },
  "ERBFeatures":          { "data": [
    { "ERBFeatureId": "signin", "ERBEpic": "accounts", "ERBPackage": "core" } ] },
  "ERBEffortClasses":        { "data": [
    { "ERBEffortClassId": "G1", "Title": "Routine",
      "ComplexityWeight": 1,   "SortOrder": 1 },
    { "ERBEffortClassId": "G3", "Title": "Demanding",
      "ComplexityWeight": 2.5, "SortOrder": 3 } ] },
  "ERBDeliveryDisciplines":  { "data": [
    { "ERBDeliveryDisciplineId": "build", "Title": "Build", "SharePercent": 70,
      "Description": "Modelling and generation", "ClientVisible": true,
      "SortOrder": 1 },
    { "ERBDeliveryDisciplineId": "assure", "Title": "Assurance", "SharePercent": 30,
      "Description": "Testing and acceptance",  "ClientVisible": true,
      "SortOrder": 2 } ] },
  "ERBBuildPhases":          { "data": [
    { "ERBBuildPhaseId": "phase-1", "PhaseNumber": 1,
      "Title": "Phase 1 — Core platform", "QuotedPrice": 120000,
      "DurationMonths": 3, "PhaseKind": "fixed-price", "IsCurrentBid": true } ] },
  "ERBUserStories":          { "data": [
    { "ERBUserStoryId": "acc-01", "ReqId": "ACC-01",
      "StoryText": "As a user I can sign in so that my work is mine.",
      "ERBBuildPhase": "phase-1", "ERBEpic": "accounts", "ERBFeature": "signin",
      "ERBEffortClass": "G1" } ] },
  "ERBAcceptanceCriteria":   { "data": [
    { "ERBAcceptanceCriterionId": "acc-01-a", "ERBUserStory": "acc-01",
      "Criterion": "A valid email and password signs the user in.",
      "SortOrder": 1 } ] }
}
```

Grow it from there: more stories, then `DependsOnStory` to make the scope
cascade real, then `ERBProposalSections` to make the argument yours.

---

## Alignment checklist

Working through a rulebook to make it generate a report:

- [ ] All eight required tables exist and carry their listed fields.
- [ ] Every `ERBUserStories.Feature` resolves to an `ERBFeatures` row.
- [ ] Every `ERBUserStories.Epic` resolves to an `ERBEpics` row.
- [ ] Every feature or its category names an `ERBPackage`.
- [ ] Every story's `ERBEffortClass` resolves, and no weight is `0`.
- [ ] The most demanding effort class is named **`G3`**.
- [ ] Every story has at least one `ERBAcceptanceCriteria` row with non-empty `Criterion`.
- [ ] Client-visible `SharePercent` sums to 100.
- [ ] Every phase with a `QuotedPrice` contains stories that carry criteria.
- [ ] Exactly one phase has `IsCurrentBid`.
- [ ] `PhaseKind` is one of the three recognised values on every phase.
- [ ] `DependsOnStory` is acyclic (a story never transitively depends on itself).
- [ ] `ERBProposalSections` is **not** registered in `ERBTables`.
- [ ] No hours, capacity or headcount field is referenced by any override prose.

Then run the tool and read `progress-report/report-summary.md`.
