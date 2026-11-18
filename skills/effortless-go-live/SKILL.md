---
name: effortless-go-live
description: >
  Before a project's Beta/Production publish, or when the app has sign-in, a login, a token, a secret, an API
  key or "who can see what": the go-live checklist for an ERB project on Effortless — sign-in is the sign-in
  seed (never a token of your own), secrets are the stage's Secrets (generate_secret / check_secrets), the
  database refuses roles and tables of your own. Triggers: "publish to production", "make it secure", "add
  login", "where does this key go", "permission denied for schema app". ERB projects only.
audience: customer
---

# Go live: sign-in, secrets, and what a stage's database refuses

A project that works in Dev can fail at Publish for reasons Dev never shows: Dev's Postgres is a superuser's, a
stage's is a shared server's. Everything below was learned from a real failed Production publish
(enable-u-demo, 2026-11-18: a signing key kept in a table, a literal fallback for it in code, `CREATE ROLE ... PASSWORD
'explore'`, and an app that read `WALLET_PASS_SECRET` while the stage held `PASS_SECRET`).

## 1. Sign-in is the sign-in seed. Never roll your own.

The chain (`effortless-seeds/SIGN-IN.md` in effortlessapi-www, section 2):

1. **Proof**: the person types their email, gets a code, types it; the project's server checks it against the
   project's magic-links tenant (its PUBLIC key). Used once, then dropped.
2. **App user**: the server finds the row for that email in the project's users table. No row, no sign-in.
3. **App session**: the server issues the project's own token, signed with a key that belongs to THAT database,
   made by the seed on first start and kept in a schema no request can read.
4. **Database**: each `/api` call runs `auth.sign_in('<session>')`; the policies (RLS) read the claims.

So: the seed makes the signing key and the database function. **You do not.** Never mint a token ("pass", home-made
HMAC) with a secret you keep, never copy a signing secret into a table, never add a "connect straight to Postgres"
login. If the project has no sign-in seed, add one (`effortless-seeds`, `effortless-magic-links`); do not write the
chain by hand. Who may open each published stage is the stage's **Access** (open / code / sign-in): a project with a
sign-in seed runs real sign-in on every published stage, so a stage left `open` is the choice to check.

## 2. A secret is one of three kinds

| Kind | Examples | Who makes it |
|---|---|---|
| Platform | `DATABASE_URL`, `MAGICLINK_TENANT_ID`, `STAGE`, `PW_*` | Nobody: the platform sets it. Never name a secret like these. |
| The app's own | a signing key, pass or session secret, an HMAC key | **You**, with `generate_secret` on each stage. Nobody sees the value. |
| From outside | `STRIPE_SECRET_KEY`, an SMTP password | The customer, by name, under Settings > Secrets (or the stage's card on the Publish tab). Never in the chat. |

Read it in `server/` as `process.env.<NAME>` with **no fallback**, and throw when it is missing:
`process.env.X || 'literal'` is a secret kept in code. The value never goes in a table, a file, the rulebook or SQL;
a database function cannot read a Secret at all, so a design that needs Postgres to hold one is the wrong design.
The stage is told by `STAGE` (`dev` or none = Dev), never `NODE_ENV`.

## 3. What a stage's database refuses

Beta and Production run your SQL as the database's owner on a shared server: no table or column of your own (a
rulebook edit makes it), no `CREATE ROLE` or login, nothing in the platform's `app`/`auth` schemas. A row that does
works in Dev and fails at Publish. `effortless-sql` has the full rule for `ERBCustomizations` rows.

## 4. Before every publish

1. `check_secrets` (Loops): a secret the code reads that a stage lacks or holds under another name, a literal
   fallback, a database role in the SQL. Fix each, call it again, publish only when it is clean.
2. `list_secrets`: names only; Dev reads a new one when its engine next starts, Beta/Production on their next
   publish or Apply now.
3. Dev-only settings (`ALLOW_DEV_AUTH`, a simulated user) never reach a stage; the stage's Access is what you intend.
4. A failed publish on your own SQL: read the statement it names, fix the row, retry; do not work around it by hand.
