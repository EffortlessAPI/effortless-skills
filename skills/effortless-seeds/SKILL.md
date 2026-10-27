---
name: effortless-seeds
description: >
  Effortless seeds: start a project from one, or drop an add-in into one. "list seeds", "clone a seed",
  "add magic links / Shopify / auth to this project", "start from a seed", `listSeeds`, `cloneSeed`,
  `effortless-seed.json`, `$key$` replacements, seed sources. Building or publishing a seed:
  effortless-seed-authoring.
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

## Two kinds: roots start projects, add-ins drop into them

| Kind | `effortless-seed.json` `seed.kind` | What it is | How you use it |
|---|---|---|---|
| **Root** | `root` | A whole project that owns the rulebook (a starter, "from Airtable", ...) | `cloneSeed` into an empty directory: the directory *becomes* the project |
| **Add-in** | `child` | A folder of code that builds against, or plugs into, an existing project's rulebook. No rulebook of its own | `cloneSeed` into the project at the seed's `mountPath`, delete its `.git`, follow its `INTEGRATE.md` |
| **Package** | either, with `subSeeds` | Several seeds installed together, in order | the installer expands it |

An add-in names the add-in it needs in `requires` (for example `rulebook-backend`); do not install it
before that one is there. **Reach for an add-in when the need is a known, repeated one** (sign-in,
a Shopify connection, docs, deploy) instead of writing it fresh: the seed carries the tested version
and its gotchas, and every project that uses it behaves the same way.

| Need | Seed | Mount |
|---|---|---|
| A backend: Postgres, Node API, TypeScript SDK | `rulebook-backend` | `backend/` |
| Approved-user sign-in: magic links in beta/production, **pick-your-user in dev**, row-level security the database enforces in both | `effortless-magic-links` | `magic-links/` |
| Shopify products, customers and orders as rulebook tables, kept current by sync and webhooks | `effortless-node-shopify` | `node-shopify/` |
| Roles and RLS compiled from the rulebook's Security module | `rulebook-auth` | `auth/` |
| Deploy to Control Plane; a native mobile app; reference docs | `cpln-deploy`, `mobile-app`, `rulebook-docs` | per README |

`effortless listSeeds` is the live list; the table above is only what existed when this was written.

### Installing an add-in into a project

```bash
cd <project root>                                   # has effortless.json and the Backend API add-in
effortless cloneSeed effortlessapi/effortless-magic-links magic-links     # a RELATIVE destination
rm -rf magic-links/.git
```

Then **read the add-in's `INTEGRATE.md`** (the wiring, written to be followed step by step, each step
saying how to know it worked) and its README. Typical shape: merge the seed's rulebook tables with
`node <mount>/scripts/merge-rulebook.mjs --rulebook ... ` (dry run first; `--write` edits the project's
source of truth, so say what it adds and get a yes), `effortless build`, one registration line in the
generated API's `custom.js` (the file rebuilds never overwrite), load the seed's web component in the app.
Ask the person only what the seed's questions need (an email, a store address); do the rest.

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

**Replacement behaviour to know** (each of these has bitten someone):

- Only keys the seed *declares* are replaced; `$1`, `$$` and SQL `$body$` quoting are left alone.
- The replaced file is edited **in the clone**, so the committed template is the clone's first
  state only: run the CLI inside a template repo that already has its manifest and it substitutes the
  tokens away. Seed authors tokenise last.
- Every key needs a `default` (or an answer), secrets included (`""` is fine), or a non-interactive
  build fails with "has no configured value or default".
- A **secret** is read from `seed-secret-values.json`, and a *persisted* secret (`persist: true`) reaches a
  published run as `SEED_SECRET_<key>` in the environment. Code reads the environment; no token for a
  secret belongs in any committed file.
- Code that reads a replaced file must still work when the file was never replaced (a seed copied by
  hand): treat a value that still contains `$key$` as unanswered and use the default.
- A seed that registers nothing to transpile (`"ProjectTranspilers": []`) is valid; `effortless build`
  says "Nothing to build" and still applies replacements. Its files are the seed.

## Authoring and publishing a seed

Building add-ins (the assembly line: layout, manifest, rulebook fragments, tests, what to check, the
gotchas already found) is its own skill: **`effortless-seed-authoring`**. The short version for a plain
root seed:

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

- `effortless-seed-authoring` — building, testing and publishing seeds, add-ins especially.
- `effortless-magic-links` — the generic magic-links flow for a project that is not using the seed.
- `effortless-cli` — the full command reference, install/update of the binary.
- `effortless-init` — creating a project from nothing instead of from a seed.
- `effortless-pipeline` — `effortless.json` / `ProjectTranspilers` in depth.
