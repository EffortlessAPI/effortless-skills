---
name: effortless-rulebook-editor
description: >
  Use when the user wants to open, launch, or start a browser-based viewer/editor
  for an effortless-rulebook.json — "open the rulebook editor", "edit the rulebook
  in a browser", "launch the editor", "start the rulebook viewer". Installs and runs
  the `effortless-rulebook-editor` transpiler, which emits a self-rebuilding Docker
  stack (Postgres + generated API + generated Vite UI) that watches the rulebook
  file and rebuilds automatically.

  **Scope (load gate):** Effortless projects only — project root must contain `effortless.json` AND a CLAUDE.md identifying the project as ERB methodology. Do NOT load otherwise.
audience: customer
---

# effortless-rulebook-editor

A one-command, browser-based viewer/editor for `effortless-rulebook.json`,
backed by a real (if small) live stack — not a static file preview.

## What it is

`effortless-rulebook-editor` is a meta-transpiler: instead of generating
application code, it emits the small set of files needed to run a
self-contained, self-rebuilding Docker container for *any* Effortless
project:

- **Postgres**, running inside the container, seeded fresh from the
  mounted rulebook on every boot.
- A generated **Node/Express API** that reads that Postgres data.
- A generated **Vite admin UI** that browses the API in the browser.
- A filesystem watcher: edit `effortless-rulebook.json` on disk, refresh the
  browser, and the container rebuilds everything automatically — no manual
  restart.

## What's editable today

**Name, Description, and `_meta`** — via the UI's edit panel on the home
view (Save button, backed by the generated API's one write endpoint,
`PATCH /api/meta`). This is intentional, finished infrastructure for exactly
those three fields, not a placeholder — it's the seed of a larger write-back
roadmap.

**Everything else — tables, fields, formulas, data rows — is view-only.**
Browse them in the generated UI; to change them, hand-edit
`effortless-rulebook.json` and refresh (the container picks it up
automatically). This still goes through the same rulebook-first workflow as
any other edit — see `effortless-workflow`.

## How to invoke it

**Install it into the SAME folder as the rulebook it edits — never the
project root.** `edit-rulebook.sh` is only unambiguous when it sits next to
its own `effortless-rulebook.json`: a project can have more than one rulebook
(e.g. a second bounded context, or a sandbox variant), and each one gets its
own editor instance, own generated files, own container. Installing at the
project root works for exactly one rulebook and silently becomes wrong the
moment a second one shows up.

From the project root, with the rulebook at `effortless-rulebook/effortless-rulebook.json`:

```bash
effortless -install effortless-rulebook-editor -i effortless-rulebook.json
```

registered with `RelativePath: "/effortless-rulebook"` in `effortless.json` —
this lands `edit-rulebook.sh` and the rest of the generated files directly
inside `effortless-rulebook/`, alongside the rulebook itself:

```bash
./effortless-rulebook/edit-rulebook.sh
```

For a second rulebook living elsewhere (e.g. `billing-rulebook/billing-rulebook.json`),
install a second, independent instance the same way, pointed at that folder
(`RelativePath: "/billing-rulebook"`) — each rulebook gets its own editor,
its own container name derived from that path, and its own ports.

Then open the URLs the script prints (Postgres and the generated
API/UI run inside one container). Edit the rulebook file and refresh the
browser — the container's watcher detects the change and rebuilds.

Host ports are **unpinned by default** — Docker assigns free ephemeral ports
and the script prints the actual URLs after starting the container. Set
`RULEBOOK_EDITOR_API_PORT` / `RULEBOOK_EDITOR_UI_PORT` to pin specific ports
instead (e.g. for a stable bookmark, or to run multiple rulebooks' editors on
known ports side by side).

Tool resolution defaults to normal published/`[latest]` versions. Only set
`LOCAL_TOOL_URLS=1` if you are actively developing
`rulebook-to-node-postgres-api` / `rulebook-to-vite-admin-portal` themselves
and want the container to pick up local `dotnet run` source changes instead.

## See also

- `effortless-schema` / `effortless-query` — for understanding what you're
  looking at in the generated UI (field types, the derived-file query ladder).
- `effortless-workflow` — for how edits beyond Name/Description/`_meta`
  should flow through the rulebook file itself, not around it.
- `effortless-rulebook-devops` — if the project already has a promotion
  pipeline (dev/staging/production), the editor is a *dev-only* viewer; it
  doesn't participate in that pipeline.
