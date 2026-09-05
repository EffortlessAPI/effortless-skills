---
name: effortless-claude-updates
description: >
  The effortless skill set itself — check for updates, apply them, add/edit/deprecate a
  skill. Triggers: "are my effortless skills up to date", "update/reinstall/refresh
  effortless skills", "what's new in effortless-claude", "add a new effortless skill".
  Not the CLI binary (that is effortless-cli).
audience: customer
---

# Effortless Skill Set — Check, Update, Author

The SSoT is `skills/` in a git clone of `EffortlessAPI/effortless-skills`. There are two ways it gets installed — **find out which one the user has first**, because the check/update steps differ:

| Install path | How to detect | Runtime location |
|---|---|---|
| **Plugin** (recommended): `effortless@effortless-skills` | `grep '"effortless-skills"' ~/.claude/plugins/installed_plugins.json` | managed by the plugin manager; skills appear as `effortless:<name>` |
| **Legacy** `install.sh` copies | `ls ~/.claude/skills/effortless-*` | `~/.claude/skills/effortless-*` |

**Never edit installed copies directly** (either path). Edit in the SSoT clone.

**Both present?** That's the footgun: two copies of every skill, and the loose ones never update. Fix: `bash <clone>/install.sh --uninstall` (or delete `~/.claude/skills/effortless-*`) and keep the plugin.

## Plugin path: check + update

```
/plugin                                   # → Marketplaces → effortless-skills → Update
claude plugin update effortless@effortless-skills     # non-interactive equivalent
```

Not installed yet? `/plugin marketplace add EffortlessAPI/effortless-skills` then `/plugin install effortless@effortless-skills`. No clone needed. The rest of this skill (clone-based check, `install.sh`) applies only to the legacy path — except **Author**, which always works against a clone.

## Legacy path — Check: is my local clone behind upstream?

This is read-only. Don't `git pull` or `git fetch` — just compare.

### 1. Locate the clone

```bash
for d in ~/effortless-skills ~/src/effortless-skills ~/code/effortless-skills \
         ~/projects/effortless-skills ./effortless-skills ~/effortless-claude ./effortless-claude; do
  if [ -d "$d/.git" ]; then
    remote=$(git -C "$d" remote get-url origin 2>/dev/null)
    case "$remote" in *[Ee]ffortless[Aa][Pp][Ii]/effortless-skills*|*effortlessapi/effortless-claude*) echo "$d";; esac
  fi
done
```

If none found, ask the user. No clone → no update path; recommend cloning.

### 2. Compare local HEAD to upstream

```bash
LOCAL=$(git -C <clone> rev-parse HEAD)
gh api "repos/EffortlessAPI/effortless-skills/compare/$LOCAL...main" \
  --jq '{ahead: .ahead_by, behind: .behind_by, commits: [.commits[] | {sha: .sha[0:7], msg: .commit.message | split("\n")[0]}]}'
```

Fallback if `gh` is missing:

```bash
curl -s 'https://api.github.com/repos/EffortlessAPI/effortless-skills/commits?per_page=20' \
  | python3 -c "import sys,json; [print(c['sha'][:7], c['commit']['author']['date'], c['commit']['message'].split(chr(10))[0]) for c in json.load(sys.stdin)]"
```

If `behind: 0` — current. Done.
If `behind: N > 0` — list the messages. Don't summarize as "minor" / "safe to skip"; the user reads and decides.

### 3. Recommend a re-check cadence

From the last 20 upstream commits, compute median gap in days:

| Median gap | Recommended cadence |
|---|---|
| < 2 days | Daily, or each session start |
| 2–7 days | Weekly |
| 7–30 days | Monthly |
| > 30 days | On demand only |

## Legacy path — Update: apply the latest

**Per the read-only-git memory: ASK before running git commands.** The user authorizes each step.

```bash
cd <clone>
git status                  # confirm clean tree first
git pull
bash install.sh --yes       # copies skills/* into ~/.claude/skills/
ls ~/.claude/skills/effortless-*  # verify
```

`install.sh` dynamically discovers all `skills/*/` directories and also cleans up entries listed in `DEPRECATED_SKILLS.md`.

### Install modes

```bash
bash install.sh              # interactive — asks per skill
bash install.sh --yes        # non-interactive
bash install.sh --symlink    # symlink instead of copy (contributor / dev mode)
bash install.sh --uninstall  # remove all installed effortless-* skills
```

Use `--symlink` if you're actively editing skills — changes take effect immediately without reinstall.

## Author: add or edit a skill

### Add a new skill

```
<clone>/skills/effortless-myskill/SKILL.md
```

Frontmatter is what Claude Code uses to decide when to load the skill — write the description as a **trigger specification**, not a summary:

```yaml
---
name: effortless-myskill
description: >
  Use when ... (include exact phrases users will say, file/directory names that
  indicate relevance, and what NOT to use it for).
audience: customer
---
```

Then `bash install.sh --yes` (legacy) — or, when developing against the plugin, start Claude with `claude --plugin-dir <clone>` and run `/reload-plugins` after edits. Discovery is automatic either way; `skills/` is the plugin's skill directory.

**Keep the description short.** All 36 descriptions share one character budget in every session's system prompt; when it overflows, Claude Code silently drops descriptions from the least-used skills and they stop triggering. Target ≤ 350 characters: triggers + one-phrase scope tag. The full load-gate policy lives in `effortless-orchestrator`, not in each description.

### Edit an existing skill

1. Edit `<clone>/skills/<skill-name>/SKILL.md`
2. `bash lint-skills.sh`
3. Legacy: `bash install.sh --yes` (skip in `--symlink` mode). Plugin: `/reload-plugins` under `--plugin-dir`, or push and let users update.

### Skill-writing principles

- Concise — these are for Claude, not human onboarding. Target ~150 lines.
- Lead with rules/axioms; skip tutorial framing.
- Link to other effortless-* skills instead of restating their content.
- Tables and code blocks beat prose paraphrases.
- The `description` is the load-decision; be explicit about triggers AND non-triggers.

### Deprecating a skill

Add an entry to `<clone>/DEPRECATED_SKILLS.md` (the installer parses this table to clean up users' installed copies). Optionally leave a shim `SKILL.md` in `skills/<old-name>/` pointing to the replacement until the target removal date.

## See also

- `effortless-cli` — for the CLI **binary** (different artifact entirely).
- `effortless-orchestrator` — top-level ERB framing; routes here for skill-set work.
