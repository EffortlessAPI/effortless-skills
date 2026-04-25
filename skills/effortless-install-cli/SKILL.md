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

Verify both are present before installing:

```bash
which dotnet && dotnet --version    # need >= 8.0
which npm && npm --version
```

If `dotnet` is missing, stop and tell the user — install .NET SDK 8.0+ from https://dotnet.microsoft.com/download. Do not attempt to install .NET automatically.

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
