# Rulebook Portal

A **read-only**, fully-containerized reference implementation for browsing
the **effortless-claude** rulebook: `effortless-rulebook/effortless-rulebook.json`
is the only durable state; the Postgres database, the API, and the web UI are
all ephemeral projections of it, rebuilt fresh every time you run
`docker compose up --build`.

```
effortless-rulebook.json  ─┐
skills/*/SKILL.md           ├─ read-only bind mounts ──►  api container
rulespeak/rulespeak.md     ─┘         │
                                       ▼
                              scratch Postgres (tmpfs)
                                       │
                                       ▼
                              web container (nginx + SPA)
```

Nothing in this stack writes back to the rulebook, to `skills/`, or to
`rulespeak/`. This is a browsing tool, not an editor.

## Run it

```bash
cd portal
./start.sh
```

or directly:

```bash
cd portal
docker compose up --build
```

- **UI** → http://localhost:8080
- **API** → http://localhost:5177
- **Postgres** → localhost:55432 (scratch, tmpfs — wiped on stop)

`Ctrl-C` (or `docker compose down`) tears down all three containers. The only
prerequisite is Docker — no host `npm install`, no host-run Node/Vite
processes.

## How it works

1. **Boot** — `docker compose up --build` builds three images (`db` is
   stock `postgres:16-alpine`, `api` and `web` are built from this repo) and
   starts them. The `db` service is RAM-backed (tmpfs), so it's truly
   ephemeral.
2. **Seed** — the `api` container waits for Postgres, reads
   `effortless-rulebook.json` (bind-mounted read-only from the host), and
   **generically** creates one `portal.<table>` table per rulebook table —
   whatever tables the rulebook happens to define, not a hardcoded list. Every
   schema field becomes a column; relationship-typed fields are tracked as
   soft foreign keys for label resolution and dangling-reference reporting.
3. **Drift check** — for the `SkillBodies` table specifically, each row's
   `FullText` snapshot is compared byte-for-byte against the live file at its
   `Path` on disk (also bind-mounted read-only). A missing file or changed
   content is flagged as drifted.
4. **Browse** — the `web` container serves a static Vite build via nginx,
   which reverse-proxies `/api/*` to the `api` container so the browser only
   ever talks to one origin. The UI lets you browse every table, drill into
   relationship links, view the drift report, and read the generated
   RuleSpeak document.

## Integrity

The portal loads even a rulebook with a **dangling foreign-key reference** (a
row pointing at another table's row that doesn't exist) so it can *show* the
problem rather than crash. Such issues appear as an amber chip in the top bar
and a dedicated list on the home view.

## Layout

```
portal/
  docker-compose.yml   db (tmpfs postgres) + api + web, all containerized
  start.sh             docker compose up --build, foreground, Ctrl-C tears down
  server/              Node/Express read-only API
    Dockerfile
    index.js           boot + read-only REST endpoints
    db.js              generic table seeding, drift detection, integrity report
    rulebook.js         read rulebook + rulespeak.md, listTables() helper
  web/                 Vite frontend (read-only browser)
    Dockerfile          multi-stage: vite build -> nginx
    nginx.conf           serves the SPA + proxies /api to the api container
    src/main.js          table list / browser / row detail / drift / rulespeak views
    src/md.js            tiny markdown renderer (used for SKILL.md + rulespeak previews)
    src/styles.css       theme-aware console styling
```
