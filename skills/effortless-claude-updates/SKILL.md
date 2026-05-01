---
name: effortless-claude-updates
description: >
  Use to check whether the locally-installed effortless-claude skill set is up
  to date with the upstream repo (github.com/effortlessapi/effortless-claude).
  Triggers: "are my effortless skills up to date", "check for effortless skill
  updates", "any new effortless-claude commits", "is effortless claude stale",
  "what's new in effortless-claude". Also use proactively at the start of an
  effortless project session if it's been more than the recommended cadence
  since the last check (the cadence depends on upstream commit frequency —
  see the workflow below).
audience: customer
---

# effortless-claude-updates — is the local skill set stale?

This skill is the **read-only check** for whether `~/.claude/skills/effortless-*`
is behind upstream. It does **not** do the actual update — that's
`effortless-orchestrator`'s job. This skill answers two questions:

1. **Is my local clone behind upstream?** (and by how much / what changed)
2. **How often should I be checking?** (based on upstream commit cadence)

If the answer to #1 is "yes, behind", hand off to `effortless-orchestrator`
for the install. Don't `git pull` or run `install.sh` from this skill — that's
the orchestrator's job and the user should know they're authorizing an update.

## The workflow

### Step 1 — Locate the local SSoT clone

The user's local clone of `effortless-claude` is wherever they cloned it.
Common spots:

```bash
# Check git remotes in likely locations
for d in ~/effortless-claude ~/src/effortless-claude ~/code/effortless-claude \
         ~/projects/effortless-claude ./effortless-claude; do
  if [ -d "$d/.git" ]; then
    remote=$(git -C "$d" remote get-url origin 2>/dev/null)
    case "$remote" in *effortlessapi/effortless-claude*) echo "$d";; esac
  fi
done
```

If no clone is found, ask the user for the path. (If they don't have a clone,
they can't update — point them at the orchestrator's setup section.)

### Step 2 — Read local HEAD (read-only)

```bash
cd <path-to-clone>
git log -1 --format='%H %ci %s'   # current local commit
git rev-parse HEAD                 # SHA only, for compare
```

Do **not** `git pull`, `git fetch`, or modify the clone. The skill is read-only.

### Step 3 — Fetch upstream commit history (read-only)

Prefer `gh` if available (richer metadata, no rate limit concerns when authed):

```bash
gh api repos/effortlessapi/effortless-claude/commits \
  --jq '.[] | {sha: .sha[0:7], date: .commit.author.date, msg: .commit.message | split("\n")[0]}' \
  | head -20
```

Fallback to the public REST endpoint via `curl` if `gh` isn't installed:

```bash
curl -s 'https://api.github.com/repos/effortlessapi/effortless-claude/commits?per_page=20' \
  | python3 -c "import sys,json; [print(c['sha'][:7], c['commit']['author']['date'], c['commit']['message'].split(chr(10))[0]) for c in json.load(sys.stdin)]"
```

### Step 4 — Compute "behind by N commits" and what changed

Count commits between local HEAD and upstream HEAD. With `gh`:

```bash
LOCAL=$(git -C <path-to-clone> rev-parse HEAD)
gh api "repos/effortlessapi/effortless-claude/compare/$LOCAL...main" \
  --jq '{ahead: .ahead_by, behind: .behind_by, commits: [.commits[] | {sha: .sha[0:7], msg: .commit.message | split("\n")[0]}]}'
```

If `behind: 0` → local is current, tell the user.
If `behind: N > 0` → list the N commit messages so the user can decide if any
of them affect their current work. Don't summarize them as "minor" or "safe to
skip" — the user reads the messages and decides.

### Step 5 — Compute cadence and recommend a re-check interval

From the last 20 upstream commits, compute the median gap between commits in
days. Map to a cadence recommendation:

| Median gap between commits | Recommended check cadence |
|---|---|
| < 2 days (very active) | Check daily, or at start of each session |
| 2–7 days (weekly) | Check weekly |
| 7–30 days (monthly) | Check monthly, or only on demand |
| > 30 days (quiet) | On demand only — no scheduled check needed |

Report the cadence + the date the user should next check (today + interval).

### Step 6 — If behind, hand off to the orchestrator

Tell the user something like:

> Local is behind by N commits since YYYY-MM-DD. Recent changes:
> - `<sha>` <message>
> - ...
>
> To update, run the install flow from `effortless-orchestrator`:
> `cd <clone>; git pull; bash install.sh --yes`
>
> (Or just say "update effortless skills" and that flow will load.)

Do NOT run `git pull` or `install.sh` yourself from this skill. The user
authorizes the update by triggering the orchestrator. This keeps the
"check" and "act" steps cleanly separated and matches the broader rule that
effortless skills don't drive git on the user's behalf.

## What this skill does NOT do

- **Does not modify any local clone** — no `git pull`, `git fetch`, no writes.
- **Does not run the installer** — that's `effortless-orchestrator`.
- **Does not edit `~/.claude/skills/`** — read-only.
- **Does not auto-schedule itself.** If the user wants a recurring check
  (daily/weekly), they can set that up via `/loop` or `/schedule` — but this
  skill doesn't create those on its own.

## When to use proactively

At the start of an effortless project session, if you notice it's been a while
since this check ran (or if the user opens an effortless project after several
days away), it's reasonable to run Step 3 alone (fetch upstream HEAD only,
~one API call) and mention "by the way, upstream has N new commits since you
last pulled — want me to show what changed?" Don't do the full workflow
unprompted — one cheap signal is enough to surface the question.
