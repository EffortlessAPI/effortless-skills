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

1. Picks an **odd port** (the API/server port) and an **even port = odd+1** (reserved for a future SPA UI).
2. Kills anything currently bound to either port (`lsof -ti tcp:<port> | xargs kill -9`), so re-running `start.sh` is always idempotent.
3. Starts the Node app in the background, redirecting logs to `./.run/app.log`.
4. Waits until the server responds on the API port (poll `curl -sf http://localhost:<port>/` for up to ~10s).
5. Prints a **clickable** `http://localhost:<port>/` line — most terminals (iTerm2, VS Code, Warp, Terminal.app) make these Ctrl/Cmd+clickable automatically. Print it on its own line, no surrounding punctuation that breaks link detection.
6. Exits 0, leaving the server running.

Pick ports deterministically per project (e.g., hash of project slug into
the 3001–9999 odd range) so re-runs use the same pair. Persist the chosen
ports in `./.run/ports.env` for `start.sh` to source on subsequent runs.

### Skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .run

# Resolve / persist port pair (odd = API, even = UI)
if [[ -f .run/ports.env ]]; then
  source .run/ports.env
else
  API_PORT=3011  # odd; pick deterministically per project
  UI_PORT=$((API_PORT + 1))
  printf 'API_PORT=%s\nUI_PORT=%s\n' "$API_PORT" "$UI_PORT" > .run/ports.env
fi

# Free the ports
for p in "$API_PORT" "$UI_PORT"; do
  pids=$(lsof -ti tcp:"$p" 2>/dev/null || true)
  [[ -n "$pids" ]] && kill -9 $pids 2>/dev/null || true
done

# Start app
( cd app && PORT="$API_PORT" nohup node server.js > ../.run/app.log 2>&1 & echo $! > ../.run/app.pid )

# Wait for ready
for _ in $(seq 1 30); do
  curl -sf "http://localhost:$API_PORT/" >/dev/null && break
  sleep 0.3
done

echo ""
echo "  App ready — Ctrl/Cmd+Click to open:"
echo ""
echo "    http://localhost:$API_PORT/"
echo ""
echo "  (UI port reserved: $UI_PORT)"
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
