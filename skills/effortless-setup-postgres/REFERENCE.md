# Effortless Setup: Postgres — Reference (long-tail)

This is the long-tail companion to [SKILL.md](SKILL.md). The core flow
(token-discipline pointer, base-id-as-SSoT, golden rules, build
discipline, Steps 0–6, verification) lives in SKILL.md. Anything below is
reference-only — only load it when you are actually doing the thing it
describes.

---

## Preflight install options

For each tool flagged MISSING by the preflight checks in SKILL.md, offer
the user a choice. **Do not pick for them** — install paths affect their
machine for years.

### `effortless` CLI

- **Option A (recommended):** install via the `effortless-cli` skill — clones the repo and registers `effortless` globally via npm. Load that skill and follow it.
- **Option B:** the user already has it under a different name (`ssotme` / `aicapture` / `aic`) — ask them to confirm and we'll alias.
- After install: `effortless -login` and `effortless -setAccountAPIKey airtable=pat...` if not already configured.

### PostgreSQL

Ask the user which path they prefer:

- **Native (macOS):** `brew install postgresql@16 && brew services start postgresql@16`
- **Native (Linux):** distro package (`apt install postgresql`, `dnf install postgresql-server`, etc.) + start the service
- **Docker:** `docker run -d --name pg -p 5432:5432 -e POSTGRES_HOST_AUTH_METHOD=trust postgres:16` (requires Docker — see below)
- **Postgres.app (macOS GUI):** download from postgresapp.com
- **Already running elsewhere:** ask for the connection string and we'll plug it into `init-db.sh` in Step 4.

If `pg_isready` fails but `psql` is installed, the binary is present but
the server isn't running — offer to start it (`brew services start
postgresql@16` / `sudo systemctl start postgresql` / `docker start pg`).

### Docker (only if the user picked the Docker postgres path, or asked for it)

- **macOS:** Docker Desktop (`brew install --cask docker`) or OrbStack (`brew install --cask orbstack`, lighter weight)
- **Linux:** distro package + `systemctl start docker` + add user to `docker` group
- If the user doesn't want Docker at all, fall back to a native postgres install above.

### Node (for Step 7 prototype app)

- macOS: `brew install node`
- Linux: distro package or `nvm install --lts`
- If the user doesn't plan to scaffold the prototype app, skip and revisit at Step 7.

---

## Step 7 — Scaffold the prototype app + `./start.sh`

Once the DB is initialized, build a **minimal Node prototype app** so the
end result of running this skill is something the user can click on.
Don't over-style it — basic CSS only. Branding, polished design, framework
swaps (React, Vue, etc.) come later, only when the user explicitly asks.

**Defaults (unless the user requested otherwise):**

- Node + Express + EJS, server-rendered pages reading from `vw_*` views
- One stylesheet (`public/style.css`) with simple typography, table, and card rules — nothing fancy
- Read-only routes for each major table; no auth
- App lives at `/app/` inside the project root

### `./start.sh` contract

Place a `start.sh` at the **project root** that:

1. Hard-codes a **random odd `API_PORT`** (e.g. `8731`) chosen once at scaffold time, and **`UI_PORT = API_PORT + 1`** (even — `8732` in that example). Same pair in `start.sh`, server `PORT` default, and Vite `server.port` + proxy target.
2. **`./start.sh` (no args)** always **kills** anything on both ports (`lsof -ti tcp:<port> | xargs kill -9`), then **restarts** the API and SPA dev servers.
3. Prints **both** clickable URLs on their own lines:
   - `http://localhost:<API_PORT>` (API)
   - `http://localhost:<UI_PORT>` (SPA)
4. Optional subcommands only: `build`, `db`. No `all` / `server` / `web` run modes.

Re-running `./start.sh` must be idempotent — stale processes on either port are killed before restart.

### Skeleton (server-only prototype; reserve `UI_PORT` for a future SPA)

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .run

API_PORT=8731   # random odd — pick once per project, never change
UI_PORT=$((API_PORT + 1))

free_port() {
  local p="$1"
  local pids
  pids=$(lsof -ti "tcp:${p}" 2>/dev/null || true)
  [[ -n "$pids" ]] && kill -9 $pids 2>/dev/null || true
}

case "${1:-}" in
  build) effortless build ;;
  db)    ./dev-postgres/init-db.sh ;;
  "")
    free_port "$API_PORT"
    free_port "$UI_PORT"

    ( cd app && PORT="$API_PORT" nohup node server.js > ../.run/app.log 2>&1 & echo $! > ../.run/app.pid )

    for _ in $(seq 1 30); do
      curl -sf "http://localhost:$API_PORT/" >/dev/null && break
      sleep 0.3
    done

    echo ""
    echo "  API:  http://localhost:${API_PORT}/"
    echo "  App:  http://localhost:${UI_PORT}/  (reserved for SPA)"
    echo ""
    ;;
  *)
    echo "Usage: ./start.sh [build|db]" >&2
    exit 1
    ;;
esac
```

Make it executable: `chmod +x start.sh`.

### First-run behavior

On the **initial** scaffold, after writing `start.sh` and the app, the
skill should:

1. Run `./start.sh` once.
2. Run `open "http://localhost:$API_PORT/"` (macOS) — so the user lands on
   a working prototype as the very last action of the skill.

This is the deliverable: a clickable prototype app at the end of
`effortless-setup-postgres`. Anything fancier (React shell, design
system, branding, auth) is out of scope unless the user asked for it when
invoking the skill.

---

## Common Issues

| Problem | Fix |
|---------|-----|
| `startIndex cannot be larger than length of string` during install | Silent registration failure (separate from cwd behavior — files were still written correctly). Append the transpiler entry to `effortless.json` by hand (see Steps 3 and 5 in SKILL.md). |
| Generated SQL files at project root after install | `-install` was run from the wrong cwd (likely from project root instead of from inside `/postgres/`). Delete the misplaced files at root and redo the install from inside `/postgres/`. See "GOLDEN RULE" section in SKILL.md. |
| Only `airtable-to-rulebook` registered in `effortless.json` | Silent registration failure on `rulebook-to-postgres` install. Manually append the `rulebook-to-postgres` and `initdb` entries (see Steps 3 and 5 in SKILL.md). |
| `effortless: command not found` | See `effortless-cli` skill. |
| `401 Unauthorized` | `effortless -setAccountAPIKey airtable=pat...` |
| `database does not exist` | `createdb <db-name>` first. |
| Empty rulebook | Verify baseId, verify API key has access. |
| `effortless.json not found` | Run `effortless -init` from project root. |
