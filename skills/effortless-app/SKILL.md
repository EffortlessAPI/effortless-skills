---
name: effortless-app
description: >
  Build the app people use on top of a rulebook: personas, user stories per persona,
  routes, then a phone-first app over the generated API, with provenance on derived
  values and a persona picker. Triggers: "build an app for …", "make this an app",
  "build the screens", "who uses this", "add a page for …". ERB projects.
audience: customer
---

# Effortless App: from a description to the app people use

A rulebook alone is a model. This skill turns it into the app the people
named in the description actually open: who they are, what each of them does,
which screens that takes, and those screens, built over the rulebook's
generated API so every number can explain itself.

Use it whenever someone describes what they want, asks for an app or new
screens, or a new kind of user appears. Run the steps in order; each writes
something the next one reads. Keep going without asking, and state each
assumption in one line.

## 1. The rulebook first

- No rulebook yet → build it from the description with `effortless-bootstrap`
  (vocabulary, glossary, narrative, mock data, normalized schema).
- **Inferences at least as many as raw facts.** Count raw fields against
  calculated, lookup and aggregation fields (the abstract derivative share):
  aim for about 1:1. Every status, total, due date, flag and "how many" a
  screen will show is a field in the rulebook, often several hops from the
  raw facts (`Owners.OverdueHorseCount` from `Horses.IsOverdueForFarrier`
  from the last `FarrierVisits.VisitDate`). This is what makes the app worth
  having: a screen shows a value six hops away with no query written for it.
- 5-10 mock rows per table, enough that every status and branch shows.
- Check the build is clean before any screen (view health, build errors).

## 2. Personas

Who uses this, in their own words. Usually 2-4.

For each: a short `key`, a name people would say ("Barn manager", not
"Admin user"), and one line on who they are and what they come to do.
A persona is a kind of person with a different job, not a permission level.

## 3. User stories per persona

For each persona, 3-8 stories: "As a barn manager I see which horses are
overdue for the farrier, so I can book him this week." Each names the value
or action it needs. A story that needs a number the rulebook does not have
→ add that field to the rulebook now (step 1), not to the app.

Keep acceptance criteria out unless asked; the stories drive the routes.

## 4. Routes

The addresses of the app, nested two levels at most:

```
/horses                 every horse, its stall and farrier status          barn manager
/horses/:id             one horse: owner, feeding, vet and farrier visits  barn manager, owner
/owners/:id/bill        what one owner owes this month and why             owner
```

For each route: the path, one line on what it shows, the stories it serves,
and the personas who see it. Lists get a detail route (`/x/:id`) when a
record has things under it. The first route each persona sees is the one
they would open every morning, with the few numbers that matter on top.

Write steps 2-4 down where the project keeps docs (`app/APP.md` in Loops,
`docs/app.md` elsewhere): personas, stories, routes. The next change reads
it before touching a screen.

## 5. The app

Build exactly the routes from step 4. **An app is two folders, always: the
pages (`app/`, or `web/`) and its own server (`server/`, Express).** The pages
call only `/api/...` on the server; the server answers the project's custom
routes and passes the rest on to the generated API (the rulebook editor's API:
read the `vw_*` views, write base fields).

```
browser -> app/ (pages) -> /api/... -> server/ -> the generated API -> Postgres
```

- **The server is the default, in Dev and when published**, served from the
  same workload as the pages. Never build, describe or publish the app as a
  static site that calls the generated API or the database directly, unless
  the owner asked for a static app in so many words. No `server/` in the
  project → note it once if relevant; do **not** scaffold `server/` in the
  middle of another ask (content on Production, a screen change, a data
  migration). Only add `server/` when the customer explicitly asked for the
  project's own server in this message — a half-wired `server/` breaks Dev.
- **Custom code goes in the server**, one file per resource under
  `server/src/routes/`: a webhook, a call to another service with a secret
  key, an email, who may call what. Secrets live there, never in the pages.
- **Rules never go in the server** any more than in the pages: it passes what
  it does not answer on to the generated API unchanged.


- **Phones first.** Every route works at 360px wide: lists become one card
  per record, forms take the whole screen, the menu collapses. People use it
  standing in a barn, a shop or a car.
- **Never compute a rule in the app.** No sums, counts, dates or statuses
  worked out in a page; read them from view columns. Missing → rulebook.
- **Name the fields every read uses.** `GET /api/tables/<T>?fields=A,B,C`:
  the API evaluates only those columns (every view column is a function
  call; see `effortless-rulebook-editor`, convention 1). A list names its
  columns, a card names what it shows, a picker asks for `Name`; only a
  record page reads the whole row. A screen that fetches a whole table to
  use two columns is a defect, and the one that makes a wide view slow.
- **Provenance on the derived values.** Every calculated, lookup or
  aggregation value on the landing pages and the main pages is marked with
  the explainer (`data-er-dag="Table.Field"`, the rulebook's PascalCase
  names) so people can hover it for the rule behind it. Install the explainer
  with `effortless-explainer-dag` where the app does not already load it.
- **A persona picker.** With more than one persona, the app opens on "Who are
  you?" and each persona then sees only its routes; a switch in the header
  changes persona. This is not sign-in (anyone can pick any persona). Real
  sign-in is `effortless-magic-links`, only when asked.
- **Leave the rulebook's bookkeeping out**: ERB* tables and `__meta__` are
  never a route, a column or a menu entry.
- Prove it: the type check passes and one row from each view a route reads
  has the columns it uses.

### In Effortless Loops (the `app/` template)

The template already has the parts; use them, do not write your own tables,
forms or fetch code. `app/README.md` has the details.

- The server → when `server/` is present, it is already running beside the app
  in Dev and in every published stage (`server/README.md`). Add routes to it;
  do not start it, replace it or remove it. If it is missing, do not invent
  one while doing something else.
- Personas → `app/src/personas.ts` (`PERSONAS`); the template shows the
  picker and the header switch when the list is not empty.
- Routes → `app/src/routes.tsx` (`ROUTES`): `path` ('horses/:id'), `label`
  for the menu (none for detail routes), `personas`, `render(params)`.
- A list route → `<TablePage table="Horses" columns={[...]} formFields={[...]} detail="horses" />`.
- A detail route → `<RecordPage table="Horses" id={id} back="horses" fields={[...]}>` with
  its child records under it as `<ChildList table="VetVisits" parent={{ field: 'Horse', id }} ... />`
  (Add links the new record to the parent by itself).
- Filter and order with `where` and `sortBy` on view columns (`IsToday`, `ScheduledDate`).
- `RecordList` (and so `TablePage` and `ChildList`) puts provenance on derived columns by itself; anywhere else,
  wrap the value in `<span data-er-dag="Table.Field">`.
- The explainer is already loaded; do not install it again.

## 6. Tell them

In a few short sentences: who the app is for, what each persona opens first,
and one value to hover to see why it is what it is. Then invite the next
change.

## Changing the app later

A request names a new person → step 2 again. A new need → a story (step 3),
its field in the rulebook if needed, then its route. Update `APP.md` in the
same change, so it keeps matching the app.
