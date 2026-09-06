---
name: effortless-seeds
description: >
  Effortless seeds — starting a project from a public GitHub repository and publishing
  one: "list seeds", "clone a seed", "start from a seed", "make this repo a seed",
  "seed sources", "effortless seed", `listSeeds`, `cloneSeed`, `addSeedSource`,
  `effortless-seed.json`, `$key$` replacements. Any project or no project (cloning a seed
  creates one).
audience: customer
---

# Effortless Seeds

A **seed** is a public GitHub repository with `effortless.json` at its root: a complete
starter project (root or child) that someone clones and builds. Nothing else makes a repo
a seed — no registry, no manifest, no naming rule. The CLI discovers seeds by listing an
account's public repositories and keeping the ones whose default branch has
`effortless.json` at the root.

**Scope gate:** load on any of the triggers above, in any directory. Cloning a seed is
how a directory *becomes* an Effortless project, so no `effortless.json` is required first.

## What a seed is / is not

| Is | Is not |
|---|---|
| A public repo with `effortless.json` at its root | A transpiler (those are catalog tools or `effortless-tools/` local tools) |
| A whole project: rulebook, pipeline, README, maybe app code | A single file or a snippet |
| Cloned with its `.git` history intact | Executed on clone — nothing runs until the user runs `effortless build` |
| Optionally parameterized with `effortless-seed.json` `$key$` tokens | A template engine; replacement is literal token substitution |

## Seed sources

Discovery spans an **ordered list of GitHub accounts** (users or organizations). The
defaults are `ssotme` and `effortlessapi`. The list is stored at
`~/.effortless/seed_sources.json` (`{ "sources": ["ssotme", "effortlessapi", ...] }`) once
the user changes it; while the file is absent the defaults apply.

```bash
effortless listSeedSources             # in order; "(default)" while no file exists
effortless addSeedSource my-org        # appends and persists the full list
effortless removeSeedSource ssotme     # defaults can be removed; the file records the rest
```

`EFFORTLESS_SEED_GITHUB_ACCOUNT=<account>` adds one more account, searched **first**, for a
single invocation. It is never written to the file.

## Finding and cloning

```bash
effortless listSeeds                   # every source in order, grouped by account, with descriptions
effortless listSeeds my-org            # one account only
effortless cloneSeed my-org/my-seed    # exactly that repository
effortless cloneSeed my-seed           # bare name: searched across the sources
effortless cloneSeed my-seed ./dir     # optional destination directory
effortless cloneSeed https://github.com/my-org/my-seed.git
```

Rules Claude should apply:

- A **bare name** must match in exactly one source. The CLI prints
  `Found '<repo>' in seed source '<account>'.` and clones. If two sources have the name
  (or one account has both `root-x` and `x`), the CLI errors with the candidates and asks
  for `account/repo` — pass the qualified form; do not guess.
- The short name `x` also matches repositories named `seed-x` or `root-x`.
- The clone must contain `effortless.json` at its root or the CLI fails; that is the
  seed contract being enforced, not a network problem.
- `.git` is preserved. Tell the user the clone is a normal repository they can inspect
  before building.
- **Nothing runs on clone.** The next step is always explicit:
  `cd <dir> && effortless build`. Read the seed's README and `effortless.json` first and
  say what the build will do.

## `$key$` replacements (`effortless-seed.json`)

A seed can ship `effortless-seed.json` at its root (the legacy `ssotme-seed.json` is also
read):

```json
{
  "replacements": [
    { "key": "project-name", "description": "Short lower-case project name", "default": "orders" },
    { "key": "airtable-api-key", "description": "Airtable PAT", "secret": true }
  ]
}
```

On **every project load** (first `effortless build`, `describe`, etc. in the clone) the CLI
resolves each key, in this order, and replaces `$key$` (case-insensitive) in file contents
**and file names** throughout the tree (skipping `.git`, `.effortless`, `bin`, `obj`,
`node_modules`):

1. `seed-config-values.json` (or `seed-secret-values.json` for `secret: true`) in the clone,
2. `seed-config-values.json` in the **parent** directory (so a root seed can answer for its child seeds),
3. the key's `default`,
4. a prompt on stdin; the answer is then written to the config/secret values file.

Files look like `{ "replacements": [ { "key": "project-name", "value": "orders" } ] }`.
Defaults are applied without being recorded. Keep `seed-secret-values.json` out of git.
Because replacement is idempotent and the template file itself is never rewritten, a
seed author can commit `$project-name$.md` and `"Name": "$project-name$"` freely.

## Authoring and publishing a seed

1. Make the project build cleanly from a fresh clone: `effortless.json` at the root, the
   rulebook under `effortless-rulebook/`, the pipeline registered with `-install`.
2. Parameterize with `effortless-seed.json` where a clone needs its own values; use
   `default` for anything that has a sensible answer; mark credentials `secret: true`.
3. Write a README that says **what the seed produces** after `effortless build` and which
   tools it needs (Docker, Postgres, an Airtable base...).
4. Push it as a **public** repository under a GitHub account, then either add that account
   as a seed source (`effortless addSeedSource <account>`) or tell users to clone it
   qualified: `effortless cloneSeed <account>/<repo>`.
5. Verify: `effortless listSeeds <account>` lists it (the check is `effortless.json` on the
   default branch); `effortless cloneSeed <account>/<repo> /tmp/x && cd /tmp/x && effortless build`.

## Nested seeds and `buildWithSubprojects`

A seed may contain child directories that are themselves Effortless projects (each with
its own `effortless.json`). A child project does **not** inherit the parent's settings or
its `effortless-tools/`; it does consult the parent's `seed-config-values.json` for
replacement answers. `effortless build` in the root builds the root pipeline only;
`effortless buildWithSubprojects` (alias `bws`) also descends into each child project
and runs its build. Use it when a root seed stitches several child seeds together.

## See also

- `effortless-cli` — the full command reference, install/update of the binary.
- `effortless-init` — creating a project from nothing instead of from a seed.
- `effortless-pipeline` — `effortless.json` / `ProjectTranspilers` in depth.
