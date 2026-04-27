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
  "wire magic links into this app", "RLS app from scratch",
  "create a magic-links tenant".
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

# 0. One-time: get a self-auth JWT (developer's own email).
curl -sS "$MAGICLINK/auth/send-code" \
  -H "Content-Type: application/json" \
  -d '{"email":"dev@example.com"}'

SELF_JWT=$(curl -sS "$MAGICLINK/auth/verify-code" \
  -H "Content-Type: application/json" \
  -d '{"email":"dev@example.com","code":"123456"}' | jq -r .jwt)

# 1. Create a tenant. Server generates the keypair.
TENANT=$(curl -sS "$MAGICLINK/api/tenants" \
  -H "Authorization: Bearer $SELF_JWT" \
  -H "Content-Type: application/json" \
  -d '{"from_email":"noreply@example.com","jwt_expires_in_seconds":3600}')

TENANT_ID=$(echo "$TENANT" | jq -r .tenant_id)
PUBLIC_KEY=$(echo "$TENANT" | jq -r .public_key_pem)

# 2. Register the trusted tenant on the base.
psql "$BASE_ADMIN_URL" <<SQL
INSERT INTO auth.trusted_tenants (tenant_id, public_key_pem, is_active)
VALUES ('$TENANT_ID', '$PUBLIC_KEY', true);
SQL

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
- **Reusing one tenant across unrelated apps.** One tenant per app —
  rotation, ownership, and audit all live at the tenant boundary.
- **Letting the anon role read `auth.trusted_tenants`.** It must not.
  Verify with `GET .../auth/privileges` —
  `securityCheck.anonCanReadTrustedTenants` must be `false`.
- **Hand-decoding JWTs in the app without verifying the signature.**
  Always RS256-verify against the saved `public_key_pem`.
- **Trying to put bases-side knowledge in magic-links via a custom
  endpoint.** Use `additional_claims` instead — they bake straight into
  the JWT, and reserved claims always win.
