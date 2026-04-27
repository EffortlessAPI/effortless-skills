---
name: effortless-install-cli
description: >
  Use when installing, updating, or reinstalling the `effortless` CLI (also known as
  `ssotme` / `aicapture` / `aic`). Claude clones https://github.com/effortlessapi/cli
  and registers it as a global npm package — no MSI/PKG installer needed. Triggers:
  "install effortless", "install the cli", "update effortless cli", "the cli isn't
  installed", `effortless: command not found`, version mismatches, or before any
  workflow that requires the CLI when it isn't present on PATH.
---

# Install / Update the Effortless CLI

The `effortless` CLI ships from https://github.com/effortlessapi/cli as an npm package whose `bin` entries (`effortless`, `ssotme`, `aicapture`, `aic`) all shim through `cli.js`, which invokes the bundled .NET 8 binary (auto-built via `dotnet build` on first run). Because it is just an npm package, Claude can manage the install end-to-end — no installer GUI, no PKG/MSI, no user interaction.

**Canonical clone location:** `~/.effortless/cli`
**Canonical command name:** `effortless` (use this in all docs/scripts)

## Prerequisites

Verify all three before installing:

```bash
which dotnet && dotnet --version    # need >= 8.0
which npm && npm --version
node --version                      # need >= 18, prefer 20+
```

If `dotnet` is missing, stop and tell the user — install .NET SDK 8.0+ from https://dotnet.microsoft.com/download. Do not attempt to install .NET automatically.

### Node version — pick 20+, then install the CLI under THAT version

The CLI itself runs on Node 16+, but generated apps (Vite 5, modern React tooling) require **Node 18+** (Vite 5 calls `crypto.getRandomValues`, which is missing on Node 16 and crashes with `TypeError: crypto$2.getRandomValues is not a function`). Always install the CLI under the same Node version the user's apps will run on, otherwise `which effortless` resolves to a binary in a different nvm prefix and switching node versions silently "loses" the CLI.

When the user has nvm and an older default (e.g. v16), check + switch + reinstall:

```bash
source ~/.nvm/nvm.sh
nvm ls                              # see what's installed
nvm install 20 || true              # if not present
nvm use 20 && nvm alias default 20  # make 20 the new default
cd ~/.effortless/cli && npm install -g .   # re-register bin under v20's prefix
which effortless                    # should now be under v20.x.x/bin
```

Symptom that this is needed: the user reports a Vite/Node error like `crypto.getRandomValues is not a function`, ESM import errors that mention `node:` protocols, or "this worked a few days ago" after an nvm change. Before suggesting "downgrade Vite," check `node --version` first — the answer is almost always to move the user to Node 20.

App `node_modules` built against Node 16 should be rebuilt after switching: `cd app && rm -rf node_modules package-lock.json && npm install`.

**Important — `nvm alias default 20` only affects new shells.** The user's existing terminal session keeps the version that was active when the shell started. So after switching the default, running `./start.sh` (or any script) in the *same* terminal still inherits the old Node. Two ways to fix:

1. Tell the user to run `nvm use 20` in their terminal (or open a new one).
2. Bake the switch into the start script itself so it is shell-state-independent:

```bash
if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    . "$HOME/.nvm/nvm.sh"
    node_major=$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)
    if (( node_major < 18 )); then
        echo "Node $(node --version) is too old for Vite 5 — switching to Node 20 via nvm."
        nvm use 20 >/dev/null
    fi
fi
```

Option 2 is preferred for any project with a `start.sh` / dev-server entry point — it survives stale shells, fresh clones, and other developers' machines.

## Fresh install

```bash
mkdir -p ~/.effortless
rm -rf ~/.effortless/cli
git clone --depth 1 https://github.com/effortlessapi/cli ~/.effortless/cli
cd ~/.effortless/cli && npm install -g .
```

`npm install -g .` creates symlinks in the active npm global bin directory (e.g. `$(npm config get prefix)/bin/`) for all four bin names. Verify:

```bash
which effortless                    # should resolve in npm prefix, NOT /usr/local/bin
effortless -version                 # first run triggers dotnet build (~30-60s)
effortless -version                 # second run is instant
```

The first invocation prints `dotnet build` warnings — that is normal. Final line is the version, e.g. `2026-04-24.18.54`.

## Update

```bash
cd ~/.effortless/cli
git pull
rm -rf Windows/CLI/bin            # force rebuild against new sources
npm install -g .                  # refresh global symlinks (safe to re-run)
effortless -version
```

## Uninstall

```bash
npm uninstall -g ssotme           # the npm package name is "ssotme"
rm -rf ~/.effortless/cli
```

## Coexistence with the legacy PKG installer

Older machines may have `/usr/local/bin/{ssotme,aicapture}` symlinks pointing into `/Applications/SSoTme/` from the old PKG installer. The npm install does NOT touch those — it places its own symlinks in the npm global prefix. As long as the npm prefix bin dir comes before `/usr/local/bin` on PATH, the npm copy wins. Check with:

```bash
echo $PATH | tr ':' '\n' | grep -nE 'nvm|/usr/local/bin'
which -a effortless ssotme
```

If `/usr/local/bin` resolves first, either reorder PATH or remove the legacy symlinks (`sudo rm /usr/local/bin/ssotme /usr/local/bin/aicapture`) — but only with explicit user confirmation.

## When to run this skill automatically

Run the fresh install (without asking) when:
- `which effortless` returns nothing AND the user has just asked Claude to do something that requires the CLI (e.g. `effortless build`, `-init`, anything in effortless-pipeline / effortless-setup-postgres / effortless-leopold-loop).

Confirm with the user first when:
- A working `effortless` already exists and the user has not asked for an update — don't reinstall unsolicited.
- `dotnet` is missing — surface the prerequisite, do not try to bypass it.

## Quick smoke test after install

```bash
effortless -version       # prints version on last line, e.g. 2026-04-24.18.54
effortless -help | head -1 # banner version should derive from same package.json
effortless -info          # shows login state (will say "not logged in" if fresh)
```

`cli.js` self-syncs the .NET `<Version>` and `CLI_VERSION` constant from `package.json` before every build, so `-help` and `-version` should never drift. If they do, the clone is from before commit `55634ab` (2026-04-25) — `git pull` and reinstall.

If smoke tests pass, hand off to `effortless-cli` for usage and `effortless-pipeline` / `effortless-setup-postgres` for project-level workflows.
