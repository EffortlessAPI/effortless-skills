# effortless-proposal: reference

The arithmetic and the money tables. The page (`www-rulebook/src/lib/proposal.ts`)
and the server (`www-rulebook-server/src/services/proposals/model.js`, `totals`)
compute the same thing; this is what they do.

## Proposal lines (`ERBProposalLines`)

Money that is not a persona's story. Every amount is a stored number.

| Field | Values |
|---|---|
| `ERBProposalLineId` | kebab key, `maintenance` |
| `Title`, `Description` | as the prospect reads it |
| `Kind` | `build` (a deliverable we build that is not a story: counts toward the build total), `service` (time-based work), `license`, `maintenance`, `pass-through` (a third party's cost at cost, never discounted), `other` |
| `Basis` | `fixed` (`Amount`), `percent` (`Percent` of the build total), `hourly` (`Hours` x `HourlyRate`) |
| `Recurrence` | `one-time`, `monthly`, `yearly` |
| `IsOptional` | true: the prospect may leave it out |
| `IsIncludedByDefault` | for an optional line: ticked on first open |
| `IsEstimate` | true when someone else sets the real price (a licence, lab fees) |
| `LineGroup` | the heading it is listed under; blank lists it under its kind |
| `SortOrder` | display order |

## Discount tiers (`ERBDiscountTiers`)

`ERBDiscountTierId`, `Title`, `MinimumAmount`, `Percent` (0-100), `SortOrder`.
The highest tier whose `MinimumAmount` the discountable total reaches comes off.

## The totals of a pick, in order

1. **stories** = sum of the picked stories' `Price`.
2. **fixed and hourly lines** that are picked (non-optional lines always are).
3. **build total** = stories + one-time `build` lines.
4. **percent lines** = `Percent` of the build total.
5. **discountable** = every one-time amount that is not `pass-through`
   (stories, build, service, percent lines...). Recurring is never discounted.
6. **discount** = highest tier reached x discountable.
7. **our price** = discountable - discount. This is the price in the page's bar.
8. **one-time** = our price + pass-through. Recurring (monthly, yearly) is
   shown beside it, never added in.

A pick is always closed over prerequisites: picking a story brings every story
it needs (`DependsOnStory` and `ERBStoryDependencies`, transitively). Required
stories (and their prerequisites) are in every pick.

## Every field, for the rarely used ones

- `ERBBuildPhases`: `QuotedPrice`, `DurationMonths`, `PhaseKind`
  (`fixed-price`, `time-and-materials`, `priced-option`), `IsCurrentBid`.
- `ERBPackages` (rare; not shown on today's page): `ERBPackageId`, `Title`,
  `Description`, `PrimaryPhase`, `SortOrder`. `ERBEpics.ERBPackage` points at one.
- `ERBUserStories`: `NeedsNewRulebookModelling`, `SpikeCoveragePercent`,
  `RulebookGapNote`, `Roadblock`, `IsInScope` (set by the prospect's agreement,
  not by you).
- `ERBAcceptanceCriteria`: `DependsOnCriterion`, `IsAccepted`, `AcceptedAt`,
  `AcceptedBy` (delivery tracking: leave them alone).
- `ERBStatusSnapshots`: delivery history. Never edit.

## Ids

| Row | Pattern |
|---|---|
| phase | `phase-1`, `phase-2` |
| epic, feature, persona, line, section | kebab-case of the title, unique in its table |
| story | `US-001` upward, `ReqId` the same |
| criterion | `<story id>-AC1` upward |
| extra prerequisite | `<story>-needs-<story>` |
