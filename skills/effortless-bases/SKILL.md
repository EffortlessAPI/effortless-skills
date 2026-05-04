---
name: effortless-bases
description: >
  Use when the user wants to spin up a Postgres base on
  bases.effortlessapi.com and secure it end-to-end with magic-links auth and
  Row-Level Security — the "create a base + magic-links tenant + RLS-secured
  app in 5 minutes" flow. Covers tenant creation against
  magiclink.effortlessapi.com's unified `/api/*` surface, registering
  trusted tenants on the base, applying the two-role privilege template,
  and writing email-DAG RLS policies. Triggers: "set up a secure base",
  "wire magic links into this app on bases.effortlessapi.com",
  "RLS app on bases", "create a magic-links tenant for a base".

  **Scope (load gate):** Loads only on explicit user request — applies to any Postgres-backed app on bases.effortlessapi.com, not just Effortless-marked projects. Do not auto-load just because a project uses Postgres.
audience: customer
---

# Effortless Bases + Magic Links Quickstart

## The axiom (load-bearing — read first)

> **Magic-links is a notary, not a referee.** It makes one claim per JWT:
> *"we sent code C to email E, the holder of C returned it, therefore E is verified."*
>
> Magic-links **stores no users, knows no users, has no concept of tenant
> ownership.** Everything user-shaped — `auth.trusted_tenants`, `app_users`,
> ownership records, role mapping, RLS policies — lives in **bases**.
>
> If a feature requires magic-links to know something about an end-user,
> it belongs in bases (or in the consumer app), not in magic-links. See
> `magiclink.effortlessapi.com/UNIFICATION-PLAN.md` for the full contract.

Practical consequence: this skill uses magic-links only to **mint a
tenant** and **issue end-user JWTs**. All other state — who owns what, who
can read what — is bases-side.

---

## The API surface (one path, `/api/*`)

There is one unified API. All endpoints live under `/api`. The server
generates and holds RSA keypairs; **the private key never leaves
magic-links.** Callers receive `{tenant_id, public_key_pem}` and verify
JWTs with the public key.

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/api/tenants` | self-auth JWT | Create tenant. Server mints keypair, returns public half. |
| `GET`  | `/api/tenants/{id}` | open | Public info: `tenant_id`, `public_key_pem`, `from_email`, `jwt_expires_in_seconds`. |
| `PATCH`| `/api/tenants/{id}` | self-auth + ownership | Update `from_email`, `jwt_expires_in_seconds`. |
| `DELETE`| `/api/tenants/{id}` | self-auth + ownership | Remove tenant. |
| `POST` | `/api/tenants/{id}/send-code` | open | `{email, additional_claims?}` → emails a 6-digit code. |
| `POST` | `/api/tenants/{id}/verify-code` | open | `{email, code, additional_claims?}` → `{ok, jwt, expires_in}`. |
| `POST` | `/api/tenants/{id}/refresh` | Bearer expired JWT | Multi-use within grace window → fresh JWT. |

**`additional_claims` rules:** sent on send-code and/or verify-code, baked
into the JWT verbatim. **Reserved claims always win:** `email`, `iss`,
`iat`, `nbf`, `exp`, `sub`, `tenant_id`. No namespacing — tenants own
their own claim conventions.

**Self-auth** (the JWT required to create/mutate tenants) comes from
magic-links dogfooding itself: it has its own tenant and its own
`/auth/send-code` + `/auth/verify-code` flow that issues a JWT carrying
`app_user_id` and `role` as `additional_claims`.

```
POST {MAGICLINK}/auth/send-code   { email }
POST {MAGICLINK}/auth/verify-code { email, code }   → { jwt }   ← self-auth JWT
```

The self-auth JWT is what authorizes `POST /api/tenants` and any
ownership-gated mutation. Cache it for the lifetime of the skill run; it
expires per the self-tenant's `jwt_expires_in_seconds`.

---

## Five-minute flow: zero → RLS-secured app

```bash
MAGICLINK="https://magiclink.effortlessapi.com"
BASES="https://bases.effortlessapi.com"

# 0. Self-auth — Claude drives this, user just reads back the 6-digit code.
#    Cache the token in /tmp so subsequent ops in the same session don't
#    re-burden the user. /auth/verify-code returns the JWT as `.token`
#    (NOT `.jwt` — that's only the per-tenant /verify-code shape).
#    See magic-links skill "Step 0" for the full pattern Claude should follow.
SELF_JWT=$(jq -r .token "/tmp/magiclink-self-auth-$DEV_EMAIL.json" 2>/dev/null) \
  || { echo "Run the send-code/verify-code dance and cache the result first."; exit 1; }

# 1. Create a tenant. Server generates the keypair. Pass project_name +
#    display_name so the bases tenant list shows real names instead of
#    UUIDs (per MAGIC_LINKS_REFACTOR.md §1).
TENANT=$(curl -sS "$MAGICLINK/api/tenants" \
  -H "Authorization: Bearer $SELF_JWT" \
  -H "Content-Type: application/json" \
  -d "{\"from_email\":\"noreply@example.com\",
       \"jwt_expires_in_seconds\":3600,
       \"project_name\":\"$PROJECT_NAME\",
       \"display_name\":\"$PROJECT_NAME — $CONTEXT\"}")

TENANT_ID=$(echo "$TENANT" | jq -r .tenant_id)

# 2. Register the trusted tenant on the base by FETCHING the per-tenant
#    install script — it contains the auth schema, the helpers, AND the
#    auth.trusted_tenants row already inlined as the final stanza. This
#    is the only legitimate way to register; we do NOT hand-INSERT, and
#    we do NOT psql against bases directly. For a bases base, the
#    fetch-then-apply happens via postgres/apply-migration.sh — not
#    a raw `psql $BASES_DATABASE_URL`.
curl -fSL "$MAGICLINK/api/tenants/$TENANT_ID/install.sql" \
  -o postgres/migrations/0050-install-magic-links-tenant.sql
bash postgres/apply-migration.sh \
  postgres/migrations/0050-install-magic-links-tenant.sql

# 3. Apply the two-role privilege template (admin + anon).
curl -sS "$BASES/bases/$BASE_ID/auth/apply-privileges-template" \
  -H "Authorization: Bearer $SELF_JWT" \
  -H "Content-Type: application/json" \
  -d '{"force":false,"returnCredentials":true}'

# 4. Generate an RLS policy for one of your tables.
curl -sS "$BASES/bases/$BASE_ID/auth/generate-policy" \
  -H "Authorization: Bearer $SELF_JWT" \
  -H "Content-Type: application/json" \
  -d '{"tablename":"documents","policyName":"owner_access",
       "policyType":"owner","ownerColumn":"owner_id","dryRun":false}'
```

Now any end-user who hits `/api/tenants/$TENANT_ID/send-code` and
`/verify-code` gets a JWT the base will accept — RLS does the rest.

---

## End-user flow (the new app talks to magic-links + base)

```js
// 1. Send code.
await fetch(`${MAGICLINK}/api/tenants/${TENANT_ID}/send-code`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email })
});

// 2. Verify code → JWT. Optionally enrich with bases-side claims.
const { jwt } = await fetch(
  `${MAGICLINK}/api/tenants/${TENANT_ID}/verify-code`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email,
      code,
      additional_claims: { app_user_id, role }   // optional, baked verbatim
    })
  }
).then(r => r.json());

// 3. Talk to the base. Anon role + RLS does the filtering.
await fetch(`${BASES}/bases/${BASE_ID}/...`, {
  headers: { Authorization: `Bearer ${jwt}` }
});
```

Verifying the JWT yourself: RS256, `iss = {magiclink_base}/{tenant_id}`,
verify against the `public_key_pem` you got from `POST /api/tenants` (or
fetch it any time from `GET /api/tenants/{id}`).

**Refresh:** when a JWT is near-expired or freshly expired, send the
expired token back as a Bearer to `POST /api/tenants/{id}/refresh` to get
a new one. Multi-use within a grace window — works across replicas, no
session affinity.

---

## RLS pattern (email DAG)

Helpers installed in the base:

```sql
app.jwt_email()       -- verified email or NULL
app.jwt_claims()      -- full claims jsonb or NULL
app.jwt_tenant_id()   -- iss tenant_id
```

Policy template (the `owner` policy type generates this):

```sql
CREATE POLICY "owner_access" ON documents
  FOR ALL
  USING (
    owner_id IN (
      SELECT app_user_id FROM app_users
      WHERE email_address = app.jwt_email()
        AND is_active = true
    )
  );
```

Available `policyType` values:
- `owner` — users see only their own rows
- `role_based` — admins see all, others see own
- `authenticated` — any authenticated user
- `admin_only` — only admins

Role/permission changes take effect on the **next query** — there is no
session priming step. The JWT is verified in-line at every query.

---

## Sharing a tenant with a downstream consumer app

A common topology: a base lives on `bases.effortlessapi.com` **and** a
separate downstream app (its own Postgres, often on the user's machine)
reads/writes against a sibling DB. End-users should sign in **once** and
have JWTs honored on both.

**Do this — share one tenant.** Don't mint a second tenant for the
downstream app. Magic-links is issuer-only; trust is expressed entirely
on the consumer side via `auth.trusted_tenants`.

1. Find the existing tenant for the base (the one already registered in
   the base's `auth.trusted_tenants`).
2. `GET {MAGICLINK}/api/tenants/{tenant_id}` to fetch its
   `public_key_pem` (open endpoint, no auth required).
3. In the downstream app's Postgres, install the same `auth.trusted_tenants`
   table and insert the same `(tenant_id, public_key_pem)` row.
4. Install the same `app.jwt_email()` / `app.jwt_claims()` helpers in the
   downstream Postgres so RLS policies can use them.
5. The downstream app's middleware looks up `auth.trusted_tenants` by
   the `tenant_id` claim, RS256-verifies against that row's
   `public_key_pem`, then opens a transaction and calls
   `SELECT auth.set_jwt($1)` with the raw token. The helper writes
   `app.jwt_*` as transaction-local GUCs; RLS reads them via
   `app.jwt_email()` / `app.has_role()`. **Never** `set_config(...)`
   or `SET LOCAL app.jwt_*` from app code — that's the v1 GUC-cache
   anti-pattern and bypasses the in-DB validation.

JWTs minted at `/api/tenants/<shared>/verify-code` now verify cleanly on
both databases. No cross-API plumbing, no key rotation choreography.

For the generic shape of this pattern (multi-row registry, peek-iss-then-
verify middleware, zero-downtime tenant addition/revocation) see the
**`effortless-magic-links`** skill's REFERENCE.md, "Sharing one tenant
across multiple databases" section.

---

## Cheat sheet

| You want to… | Endpoint |
|---|---|
| Get a self-auth JWT (developer login) | `POST {MAGICLINK}/auth/send-code` then `/auth/verify-code` |
| Create a tenant | `POST {MAGICLINK}/api/tenants` (self-auth Bearer) |
| Look up a tenant's public key | `GET {MAGICLINK}/api/tenants/{id}` |
| Update tenant settings | `PATCH {MAGICLINK}/api/tenants/{id}` (self-auth + ownership) |
| Delete a tenant | `DELETE {MAGICLINK}/api/tenants/{id}` |
| Issue an end-user JWT | `POST {MAGICLINK}/api/tenants/{id}/send-code` then `/verify-code` |
| Refresh an end-user JWT | `POST {MAGICLINK}/api/tenants/{id}/refresh` (Bearer expired JWT) |
| Apply two-role security to a base | `POST {BASES}/bases/{baseId}/auth/apply-privileges-template` |
| Generate an RLS policy | `POST {BASES}/bases/{baseId}/auth/generate-policy` |
| Audit role privileges | `GET {BASES}/bases/{baseId}/auth/privileges` |
| Lint policies for legacy patterns | `GET {BASES}/bases/{baseId}/auth/lint-policies` |
| Test RLS with a JWT | `POST {BASES}/bases/{baseId}/auth/test-rls` |

---

## Common mistakes

- **Treating magic-links as a user store.** It isn't. `app_users` lives in
  the base. Anything user-shaped goes there.
- **Asking magic-links for the private key.** It will never give it to
  you. The only key the API ever returns is `public_key_pem`.
- **Reusing one tenant across *unrelated* apps.** One tenant per product surface —
  rotation, ownership, and audit all live at the tenant boundary.
- **Letting the anon role read `auth.trusted_tenants`.** It must not.
  Verify with `GET .../auth/privileges` —
  `securityCheck.anonCanReadTrustedTenants` must be `false`.
- **Hand-decoding JWTs in the app without verifying the signature.**
  Always RS256-verify against the saved `public_key_pem`.
- **Trying to put bases-side knowledge in magic-links via a custom
  endpoint.** Use `additional_claims` instead — they bake straight into
  the JWT, and reserved claims always win.

---

## See also

- `effortless-magic-links` — the **generic** magic-links flow for any Postgres app, when the DB is NOT on bases.effortlessapi.com. Same axiom, fewer bases-specific endpoints.
- `effortless-orchestrator` — for the "AppUsers belongs in Airtable, not in `app.app_users` by hand" rule.
- `effortless-sql` — for `*b-customize-*.sql` placement of `auth.trusted_tenants` and `app.jwt_*()` helpers.
- `effortless-setup-postgres` — if you're standing up the underlying Postgres ERB project, run that first.

---

## Magic-links refactor (v0.2)

> See [../../MAGIC_LINKS_REFACTOR.md](../../MAGIC_LINKS_REFACTOR.md) §4 + §11 for the canonical v0.2 magic-links contract.

**Changes to ANY BASES BASE NEEDS TO BE REALLY EXPLICITLY GATED!! DO NOT JUST GO MAKE CHANGES WITHOUT CONFIRMING EXACTLY WHAT CHANGES ARE GOING TO BE MADE.**

Before any change to a bases base: fetch `Stage` via `GET /api/bases/{id}`.
- `Stage = prod`: state exact DDL/data/RLS diff, get explicit confirmation, run against dev/staging first, then use `confirm-prod-change: <summary>` header on the bases API call.
- `Stage = staging`: state changes, one confirmation, then proceed.
- `Stage = dev`: proceed normally; summarize at end of turn.

Never run `effortless build` / `init-db.sh` against a bases base. Never `DROP` without explicit `--i-mean-it`. Migrations only, via `postgres/apply-migration.sh` (per the bases repo's BASES_MIGRATION_GUIDE.md).

RLS policy lifecycle (§11): RLS changes for bases are MIGRATION FILES only. Never edit `04b-customize-policies.sql` and rebuild — that drops policies on bases.

## LOCALHOST MODE — read before doing anything

Before any magic-links / bases work, check whether `MAGICLINK_BASE_URL` is set to a `http://localhost:*` URL (or the operator said "use the local dev stack" / "localhost"). If so, follow [MAGIC_LINKS_REFACTOR.md §13](../../MAGIC_LINKS_REFACTOR.md#13-localhost-mode--opt-in-via-env-vars) — production URLs become localhost URLs, the magic-link email loop is replaced by debug code `424242`, and bases registration goes against the local bases server.

Operator quick-ref in localhost mode:
- magiclink server: `http://localhost:4787` (admin UI at `/`)
- bases server:     `http://localhost:4788` (admin UI at `/`)
- unified dash:     `http://localhost:4789`
- env file:         `magic-links-refactor/test-env/dev/.env` — `source` it before any curl recipe; gives you `OWNER_JWT`, `MAGICLINK_BASE_URL`, `BASES_BASE_URL`, etc.

Up-check (run before assuming the stack is live):
```
curl -fsS http://localhost:4787/install-magic-links/v1.sql >/dev/null && echo "magiclink up" || echo "magiclink DOWN"
curl -fsS http://localhost:4788/health >/dev/null && echo "bases up" || echo "bases DOWN"
```
If down, run `bash magic-links-refactor/test-env/scripts/dev-stack-up.sh`.
