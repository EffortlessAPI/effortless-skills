---
name: effortless-proposal
description: >
  Designing a project's priced PROPOSAL (effortlessapi.com's Proposal page): phases,
  epics, personas, user stories, acceptance criteria, prices, what is included,
  summaries, the totals. Adding a story to the proposal is NOT building it. Triggers:
  "make a proposal", "add a story/epic/phase", "price this", "summarize the proposal".
  ERB projects only.
audience: customer
---

# effortless-proposal: the proposal is rows, not a build

A project's proposal is the priced menu a prospect reads, picks from and agrees to
on effortlessapi.com (`/projects/<id>/proposal`). The page reads it straight from
the ERB delivery tables in `effortless-rulebook/effortless-rulebook.json`. Every
row you change shows on the page as soon as the rulebook is saved.

## The one rule: describing work is not doing it

A story in the proposal is work **offered for sale**. Most of it is not built
yet and will not be until the prospect agrees and pays. So, when you work on
the proposal:

- Change **rows in the ERB delivery tables only** (list below).
- Do NOT add or change domain tables, fields, sample data, the app (`app/`,
  `app/APP.md`, `docs/app.md`), screens or SQL. Do not load `effortless-app`.
  Do not wait for a rebuild or check the preview: nothing there changed.
- Never add, rename or remove an ERB table or field. Rows only.
- Change the project itself only when the person explicitly asks for that ("build
  it", "add it to the app", "change the rules"). Then say plainly that you are
  now changing the project, not the proposal.

## The shape: Phase -> Epic -> Story -> Criteria

| Table | One row is | Key fields |
|---|---|---|
| `ERBBuildPhases` | a release on the roadmap (timing) | `ERBBuildPhaseId` (`phase-1`), `PhaseNumber` 1,2,3, `Title`, `Description` (a paragraph or two: what the phase delivers), `PriceAdjustment` (see "Pricing a phase or an epic as a whole") |
| `ERBEpics` | a set of value inside a phase | `ERBEpicId` (kebab-case, `getting-started`), `Title`, `Description` (a sentence or two: the value it gives), `PriceAdjustment`, `SortOrder` |
| `ERBRoles` | a persona: who does the stories | `ERBRoleId` (kebab, `customer`), `Title`, `Description`, `SortOrder`; new ones `DefaultCRUD` `"CRUD"`, `IsAdminEquivalent` false, `IsTenantExempt` false |
| `ERBUserStories` | what is priced and picked | see below |
| `ERBAcceptanceCriteria` | one checkable sentence that says the story is done | `ERBAcceptanceCriterionId` (`<story>-AC1`), `ERBUserStory`, `Criterion`, `SortOrder`, `IsAccepted` false |
| `ERBFeatures` | optional: a named capability inside an epic | `ERBFeatureId`, `Title`, `ERBEpic`, `SortOrder` |
| `ERBEffortClasses` | complexity bands (already seeded) | `G1` Routine weight 1, `G2` Involved 1.6, `G3` Demanding 2.5 |
| `ERBStoryDependencies` | a second, third... prerequisite | `ERBStoryDependencyId` (`US-004-needs-US-002`), `ERBUserStory`, `DependsOnStory` |
| `ERBProposalSections` | the prose: project summary and argument | see "Summaries" |
| `ERBProposalLines`, `ERBDiscountTiers` | money beyond stories; volume discounts | see REFERENCE.md |

**A story** (`ERBUserStories`):

- `ERBUserStoryId` and `ReqId`: `US-001`, `US-002`... (same value, next free number).
- `ShortTitle`: what the person GETS, 2-5 words ("My shifts this week"). The page leads with it.
- `StoryText`: "As a <persona title>, I can <do something>, so that <outcome>."
- `Description`: what the story gives, in plain words, one or two sentences
  ("The first thing a volunteer sees: today, tomorrow, the rest of the week.").
  The page prints it under the title, like a paragraph in a document: write it
  for every story. Not the "As a..." sentence again, and no table names.
- `ERBRole`: one persona id (a plain id, must exist in `ERBRoles`). Prefer a real
  persona over the admin.
- `ERBBuildPhase`, `ERBEpic` (row ids that exist), `ERBFeature` (optional), `ERBEffortClass` (`G1`/`G2`/`G3`).
- `Price`: dollars, a stored final number, **never blank**.
- `Priority`: 1 first, within its epic.
- `IsOffered` true (false hides it from the menu), `IsIncludedByDefault` (ticked
  when a prospect first opens it), `IsRequired` (the base: locked in every pick).
- `DependsOnStory`: one prerequisite; more as `ERBStoryDependencies` rows. No loops.
- Leave `IsInScope` false: the prospect's agreement sets it, not you.

The page: phases show as a roadmap only when there are two or more; a phase
groups its stories by epic; a story has its own page with its text, its criteria,
its persona, effort and what it builds on. Personas are a filter and a chart, not
a level. Charts follow the pick: money by phase, by epic, by persona, by effort.

## Placeholders

Before the chat opens, www adds one placeholder row to each empty level: phase
`phase-1` "The first release", epic `getting-started` "Getting started", persona
`customer`, story `US-001` "Sign in and see my work" ($100), criterion
`US-001-AC1`. Reword and reuse them (keep the ids) or remove them once real rows
exist. Never leave a placeholder that does not fit the project.

## Work in two steps: propose, then apply

1. **Read** what is there first: `ERBBuildPhases`, `ERBEpics`, `ERBRoles`,
   `ERBUserStories` (with their criteria) and the domain's table list (to know
   what the app is about). Never assume the rows are as you left them: the owner
   edits the same rows on the page.
2. **Propose.** Say what you would change, grouped by phase and epic, one line
   per change, with prices, then the new totals:

   ```
   Phase 1 · Getting started
   + US-004 "Wish a helper happy birthday" (Client, G1, $100, included) - 3 criteria
   ~ US-002 price $150 -> $200
   - US-003 "Export to Excel" (and its 2 criteria)
   Totals: 6 stories, $950 offered; first-open pick $700 (was $600).
   ```
3. **Ask** with AskUserQuestion: "Make these changes to the proposal?" with
   options like "Yes, make them" / "Change something first". Apply nothing
   before the yes. Skip the question only when the person's message already is
   the yes ("go ahead", "do it", answering your list), or they said up front to
   just do it.
4. **Apply** in one edit (all rows together), then say exactly what you
   changed, one line per change, in the page's words ("Added epic Payments and
   earnings", "Changed US-002 (price)", "Removed US-007", "Added 3 acceptance
   criteria to US-004"), and the new totals. The page's change log records the
   same. Speak of epics, user stories, acceptance criteria, personas and
   phases, never of tables, rows, sections or groups. While your turn runs the
   rulebook is yours alone (the page holds its saves), so an edit is never
   refused for being out of date.

A question with no change in it ("what's the total?", "which stories need
X?") is answered from the rows, with no edit and no confirmation.

## "Make a proposal"

Small project (the default unless the person names releases):

1. One phase (reword `phase-1`: e.g. "The first release") and one epic (reword
   `getting-started`) to start from. Add more epics only when the stories fall
   into clearly separate sets of value (3+ stories each).
2. One or two non-admin personas from the app's actual users (the domain
   tables, `app/APP.md` if it exists). Reuse `ERBRoles` rows that exist.
3. Five to twelve stories, each a single thing one persona can do, in the order
   they would be built (Priority). Sign-in / the base first.
4. Two to four acceptance criteria per story: observable, checkable, specific
   ("A volunteer sees only their own shifts", not "works well").
5. A price on every story (below). The core stories `IsIncludedByDefault`
   true; nice-to-haves offered but not included.
6. The three versions (below): `IsRequired` on the minimal set.
7. Dependencies where one story truly needs another.
8. The summaries: masthead, thesis, the phase and epic descriptions.

Bigger: phases are releases (timing: "Launch", "Scale"), epics are sets of value
inside them. Ask once if it is unclear whether something is a phase or an epic.

## Prices and totals

- **Keep prices low: a very conservative bid, priced to close.** An agent
  builds a whole first release in about an hour, and that hour's app is far
  from finished, so 20 stories come to about $3,000, never $30,000. A story is
  tens or hundreds of dollars, not thousands. There is no minimum: a $100 app
  is quoted at $100.
- **Use the proposal's own yardstick first**: when stories are already priced,
  price new ones like the existing ones of the same effort class.
- With nothing to go by, start at **G1 $100, G2 $200, G3 $400** per story,
  less for a trivial one (a label, a line of text: $50), more for many criteria, and say they are starting numbers to adjust.
- Effort class by the work: G1 a list, form or view over data that exists;
  G2 a new workflow, rules or an integration; G3 something hard (payments,
  real-time, a new engine).
- **Every amount in proposal text is a figure, never a typed number.** In any
  `ERBProposalSections` `Title` or `Body`, write `{{total}}`, not `$4,500`: a
  typed price goes stale the moment a tick or a price changes, and the reader
  sees two numbers that disagree. The page and the PDF fill these in from the
  pick: `{{total}}`, `{{one-time}}`, `{{third-party}}`, `{{monthly}}`,
  `{{yearly}}`, `{{discount}}`, `{{picked}}`, `{{stories}}`, `{{phase 1}}`,
  `{{epic <id>}}`, `{{story <id>}}`, `{{line <id>}}`, `{{yearly-line <id>}}`,
  and arithmetic and percents over them: `{{total * 60%}}`,
  `{{total - phase 1 - phase 2}}`. Use row ids, not titles. Split a payment by
  percents, never by subtracting a fixed amount: unticking can take it below
  zero. `{{monthly}}` and `{{yearly}}` always both show, whichever way the client
  has set the switch. The one-line lists you propose in the chat are not
  proposal text: they keep plain prices.
- **Pricing a phase or an epic as a whole.** `ERBBuildPhases.PriceAdjustment`
  and `ERBEpics.PriceAdjustment` are an amount the phase or epic carries itself,
  in dollars, plus or minus, counted ONCE whenever any of its stories is picked.
  A level's price is its picked stories plus that amount. Use it when the person
  asks for one price for a phase or an epic ("Discovery is $1,500 flat"): put the
  price in `PriceAdjustment` and set its stories' `Price` to 0; the page then
  shows them as "included", never "$0". Use a minus amount for something taken
  off a set ("$200 off when you take all of Accounts"). Leave it blank otherwise:
  story by story is the default. Do not put the same money in both places. A
  price for the whole proposal that is not a story is a line (REFERENCE.md).
- `ImageUrl` on a phase, an epic or a story is a picture the person adds on the
  page (they upload it there). Do not invent one or point at a web address you
  have not been given.
- Never write our private estimating into the rulebook or the chat (hours,
  rates, cost, margin): the rulebook holds the final price only.
- Totals you report: **offered** (sum of `Price` of every offered story, plus
  every `PriceAdjustment` of a phase or an epic),
  **first-open pick** (stories `IsIncludedByDefault` or `IsRequired`, plus every
  prerequisite of those, counted once, plus the `PriceAdjustment` of each phase
  and epic that has a story in it), and per phase / epic when useful. Lines
  and discounts follow the arithmetic in REFERENCE.md.

## Included, base, saved picks

- `IsIncludedByDefault`: what a prospect sees ticked when they first open it
  (prerequisites come along).
- `IsRequired`: the base every pick must include; locked on the page.
- `IsOffered` false: kept, but off the menu.
- **Three versions, always (owner, 2026-11-07).** A prospect sees three picks
  at once: **Everything** (every offered story), **Suggested stories** (the
  `IsIncludedByDefault` ones, what they first open on) and **Minimal stories**
  (the `IsRequired` base). Set the flags so the three differ: offer more than
  you include, and for the base start from the included stories and take out
  every one the app still works without, until taking out one more would break
  it; mark what is left `IsRequired` (sign-in and the few stories everything
  else stands on). effortlessapi.com makes the three named picks from these
  flags the first time the proposal has stories; from then on they are
  ordinary picks the owner keeps up to date on the page.
- **Saved picks are not rows.** Named picks (Save / Save as on the page, an
  owner's pick as the default a prospect opens on) live on effortlessapi.com,
  not in the rulebook. A tick cycles all-in / all-out / back to the saved pick.
  You can recommend a pick; the person saves it on the page.

## Summaries

| Summary of | Where it goes |
|---|---|
| the whole proposal: who it is for | `ERBProposalSections` row `SectionKey` `masthead`: `Title` (eyebrow, e.g. "Common Table Community Kitchen") |
| the one line it argues + 2-3 sentences | row `SectionKey` `thesis`: `Title` (the page's headline), `Body` (the lede) |
| a phase | `ERBBuildPhases.Description` (a paragraph or two; Markdown works) |
| an epic | `ERBEpics.Description` (a sentence or two) |
| a story | `ERBUserStories.Description` (one or two sentences) |
| an argument section | another `ERBProposalSections` row: `SectionKey` (kebab), `Title`, `Body` (`**bold**` works), `SortOrder`, `ClientVisible` true |

Section rows: `ERBProposalSectionId` = the key (`masthead`, `thesis`, ...);
leave `Mode` blank. Write for the prospect: what they get and why it matters,
from the stories you can see. No jargon, no table names.

## Deleting

- A story: remove its `ERBAcceptanceCriteria` rows, its `ERBStoryDependencies`
  rows (both sides), and clear any `DependsOnStory` that names it.
- A phase or epic: clear the references to it first (or move the stories).
- A persona: never the admin (`IsAdminEquivalent`), never one `ERBUsers` or the
  permission tables still name; move its stories to another persona first.

## Integrity

Every reference names a row that exists; dependencies never loop; ids are stable
(rename the `Title`, not the id); prices are numbers. After an edit, read the
rows back if in doubt.

## What happens after

The owner publishes a version from the page (Publish, in the bar at its top); the prospect sees
only published versions, picks and agrees in principle. Building starts after
that, in the project's own chat. Publishing, lines, discounts and estimates are
also editable in the page's Owner tools.

See REFERENCE.md for proposal lines, discount tiers and the totals arithmetic.
