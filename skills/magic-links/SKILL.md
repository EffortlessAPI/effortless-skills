---
name: magic-links
description: >
  Use when the user wants to add passwordless email-code (magic-link) auth to
  any project backed by a Postgres database — not just bases.effortlessapi.com.
  Covers minting a tenant on magiclink.effortlessapi.com, storing the
  public key for JWT verification, wiring app-side `Authorization: Bearer`
  middleware, and (optionally) installing the `app.jwt_*()` SQL helpers so
  RLS policies can filter by the verified email. Triggers: "add magic links
  to this app", "secure this app with magic links", "passwordless auth on a
  postgres app", "wire JWT auth into this project".
---

# Magic Links → any Postgres app

## The axiom (load-bearing)

> **Magic-links is a notary, not a referee.** It makes one claim per JWT:
> *"we sent code C to email E, the holder of C returned it, therefore E is
> verified."* Magic-links stores no end-users, no roles, no ownership. All
> user-shaped state lives in the **consuming app's** Postgres database.

If a feature wants magic-links to know what an end-user does in your app,
the feature belongs in your app — not in magic-links. See
`magiclink.effortlessapi.com/UNIFICATION-PLAN.md` for the full contract.

This skill is the **generic** flow: any project, any Postgres database. For
the bases-specific flow (auto-RLS templates, `auth.trusted_tenants`,
`/auth/generate-policy`), use the `effortless-bases` skill instead.

---

## What "adding magic links" actually means

Three artifacts get added to your project:

1. **A tenant** on `magiclink.effortlessapi.com` (one per app). You
   receive `{tenant_id, public_key_pem}`. The private key never leaves
   magic-links.
2. **An auth middleware** in your app (or per request handler) that:
   - reads `Authorization: Bearer <jwt>`,
   - RS256-verifies it against the cached `public_key_pem`,
   - exposes `req.user.email` (and any `additional_claims`).
3. **A login UI** with two steps: collect email → call `send-code`, then
   collect 6-digit code → call `verify-code` → store the JWT.

**Optional but usually wanted:** SQL helpers + RLS so the *database* also
knows the verified email and can filter rows directly.

---

## API surface (the unified `/api/*` paths)

```
MAGICLINK = https://magiclink.effortlessapi.com
```

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/auth/send-code` | open | Self-auth: send code to **developer's** email. |
| `POST` | `/auth/verify-code` | open | Self-auth: verify → JWT used to create tenants. |
| `POST` | `/api/tenants` | self-auth Bearer | Mint a tenant. Server generates keypair. Returns `{tenant_id, public_key_pem}`. |
| `GET`  | `/api/tenants/{id}` | open | Public info: `{tenant_id, public_key_pem, from_email, jwt_expires_in_seconds}`. |
| `PATCH`| `/api/tenants/{id}` | self-auth + ownership | Update `from_email` / `jwt_expires_in_seconds`. |
| `DELETE`| `/api/tenants/{id}` | self-auth + ownership | Remove tenant. |
| `POST` | `/api/tenants/{id}/send-code` | open | `{email, additional_claims?}` → `{ok:true}`. |
| `POST` | `/api/tenants/{id}/verify-code` | open | `{email, code, additional_claims?}` → `{ok, jwt, expires_in}`. |
| `POST` | `/api/tenants/{id}/refresh` | Bearer expired JWT | Multi-use within grace window → fresh JWT. |

**`additional_claims`** are baked into the JWT verbatim. Reserved claims
**always win** (and you cannot override them): `email`, `iss`, `iat`,
`nbf`, `exp`, `sub`, `tenant_id`. No namespacing — your app owns its own
claim conventions (e.g. `role`, `app_user_id`).

**JWT details:** RS256, `iss = {tenant_id}`, `email` = verified email,
`exp` per the tenant's `jwt_expires_in_seconds` (default 3600s).

---

## Recipe: zero → secured app

### Step 0 — get a self-auth JWT (one time, per developer)

```bash
MAGICLINK="https://magiclink.effortlessapi.com"
DEV_EMAIL="dev@example.com"

curl -sS "$MAGICLINK/auth/send-code" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$DEV_EMAIL\"}"

# Read the 6-digit code from the email, then:
SELF_JWT=$(curl -sS "$MAGICLINK/auth/verify-code" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$DEV_EMAIL\",\"code\":\"123456\"}" | jq -r .jwt)
```

Cache `SELF_JWT` for the rest of the session. Re-run the two-step flow
when it expires.

### Step 1 — mint the tenant

```bash
TENANT=$(curl -sS "$MAGICLINK/api/tenants" \
  -H "Authorization: Bearer $SELF_JWT" \
  -H "Content-Type: application/json" \
  -d '{"from_email":"noreply@yourapp.com","jwt_expires_in_seconds":3600}')

TENANT_ID=$(echo "$TENANT" | jq -r .tenant_id)
PUBLIC_KEY=$(echo "$TENANT" | jq -r .public_key_pem)
```

Persist `TENANT_ID` and `PUBLIC_KEY` in the project (config/env vars). The
`public_key_pem` is also fetchable any time from `GET /api/tenants/{id}`,
so caching it is a perf optimization, not a requirement.

**Suggested env vars:**
```
MAGICLINK_BASE_URL=https://magiclink.effortlessapi.com
MAGICLINK_TENANT_ID=<tenant_id>
MAGICLINK_PUBLIC_KEY_PEM=<public_key_pem multi-line>
```

### Step 2 — install the JWT verification middleware

**Node / Express:**
```js
import jwt from 'jsonwebtoken';

const PUBLIC_KEY = process.env.MAGICLINK_PUBLIC_KEY_PEM;
const TENANT_ID  = process.env.MAGICLINK_TENANT_ID;

export function requireAuth(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'missing_token' });
  }
  try {
    const decoded = jwt.verify(auth.slice(7), PUBLIC_KEY, {
      algorithms: ['RS256'],
      issuer: TENANT_ID,
    });
    req.user = decoded; // { email, sub, iss, exp, ...additional_claims }
    next();
  } catch {
    return res.status(401).json({ error: 'invalid_token' });
  }
}
```

**Python / FastAPI:**
```python
import jwt
from fastapi import Header, HTTPException

PUBLIC_KEY = os.environ["MAGICLINK_PUBLIC_KEY_PEM"]
TENANT_ID  = os.environ["MAGICLINK_TENANT_ID"]

def require_auth(authorization: str = Header(...)):
    if not authorization.startswith("Bearer "):
        raise HTTPException(401, "missing_token")
    try:
        return jwt.decode(
            authorization[7:], PUBLIC_KEY,
            algorithms=["RS256"], issuer=TENANT_ID,
        )
    except jwt.PyJWTError:
        raise HTTPException(401, "invalid_token")
```

### Step 3 — build the two-step login UI

```js
// 1. Email step
await fetch(`${MAGICLINK}/api/tenants/${TENANT_ID}/send-code`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email }),
});

// 2. Code step — optionally enrich with app-side claims
const { jwt } = await fetch(
  `${MAGICLINK}/api/tenants/${TENANT_ID}/verify-code`,
  {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email, code,
      additional_claims: { app_user_id, role }, // optional
    }),
  },
).then(r => r.json());

localStorage.setItem('jwt', jwt);
```

All subsequent API calls send `Authorization: Bearer ${jwt}`.

### Step 4 (optional) — push the verified email into Postgres

If you want **the database** to filter rows by the JWT email (RLS), you
have two patterns. Pick one:

#### Pattern A — app sets a session variable per request

Simplest, no DB extensions. The app verifies the JWT, then sets a session
GUC before running queries:

```sql
-- Run once after connecting (or per request, before the query):
SELECT set_config('app.jwt_email',  $1, true);  -- true = LOCAL to txn
SELECT set_config('app.jwt_claims', $2, true);
```

```sql
-- In RLS policies:
CREATE POLICY "owner_access" ON documents
  FOR ALL
  USING (
    owner_email = current_setting('app.jwt_email', true)
  );
```

`current_setting('...', true)` returns NULL when unset → policy fails
closed.

#### Pattern B — verify the JWT inside Postgres (pgjwt / plpython)

Heavier — requires the `pgjwt` extension (or a custom plpgsql function
that does RS256 verification). Only worth it if you cannot trust the
caller to set the GUC, e.g. direct DB access. For most app-fronted DBs,
Pattern A is correct.

### Step 5 — write RLS policies (skip if the DB doesn't need to filter)

```sql
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

-- Default deny.
CREATE POLICY "deny_all" ON documents FOR ALL USING (false);

-- Owner sees their rows.
CREATE POLICY "owner_select" ON documents
  FOR SELECT
  USING (owner_email = current_setting('app.jwt_email', true));

-- Owner can write their own rows.
CREATE POLICY "owner_modify" ON documents
  FOR ALL
  USING (owner_email = current_setting('app.jwt_email', true))
  WITH CHECK (owner_email = current_setting('app.jwt_email', true));
```

Test with a JWT email vs without:
```sql
SET LOCAL app.jwt_email = 'alice@example.com';
SELECT * FROM documents;  -- only Alice's rows
RESET app.jwt_email;
SELECT * FROM documents;  -- empty (deny_all wins)
```

---

## Refresh flow

When a JWT is near-expired or freshly expired:

```js
const { jwt: newJwt } = await fetch(
  `${MAGICLINK}/api/tenants/${TENANT_ID}/refresh`,
  {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${expiredJwt}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ grace_period: 86400 }), // optional
  },
).then(r => r.json());
```

Multi-use within the grace window. No session affinity, works across
replicas.

---

## Cheat sheet

| You want to… | Endpoint |
|---|---|
| Get a self-auth JWT (developer login) | `POST {MAGICLINK}/auth/send-code` then `/auth/verify-code` |
| Create a tenant | `POST {MAGICLINK}/api/tenants` (self-auth Bearer) |
| Look up a tenant's public key | `GET {MAGICLINK}/api/tenants/{id}` |
| Update tenant settings | `PATCH {MAGICLINK}/api/tenants/{id}` |
| Delete a tenant | `DELETE {MAGICLINK}/api/tenants/{id}` |
| Issue an end-user JWT | `POST {MAGICLINK}/api/tenants/{id}/send-code` then `/verify-code` |
| Refresh an end-user JWT | `POST {MAGICLINK}/api/tenants/{id}/refresh` |

---

## Common mistakes

- **Hand-decoding JWTs without verifying the signature.** Always RS256-verify
  against the saved `public_key_pem`. `atob(jwt.split('.')[1])` is a debug
  tool, not auth.
- **Treating magic-links as a user store.** It isn't. Your app's `users`
  table lives in your Postgres database, keyed by `email`.
- **Asking magic-links for the private key.** It will never give it to you.
  The only key the API ever returns is `public_key_pem`.
- **Reusing one tenant across unrelated apps.** One tenant per app —
  rotation, ownership, and audit live at the tenant boundary.
- **Forgetting to set `iss` on the verifier.** Without `issuer: TENANT_ID`,
  a JWT minted for *any* tenant the same magic-links instance hosts would
  pass — which is a cross-tenant auth bug.
- **Putting bases-side knowledge into magic-links via a custom endpoint.**
  Use `additional_claims` instead — they bake straight into the JWT, and
  reserved claims always win.
- **Persisting `app.jwt_email` as a session-wide setting.** Use `SET
  LOCAL` (txn-scoped) so it cannot leak across requests on a pooled
  connection.

---

## When to use the bases-specific skill instead

If the project's database lives on `bases.effortlessapi.com`, use the
`effortless-bases` skill — it adds:
- `auth.trusted_tenants` registration (multi-tenant key fan-out per base),
- a two-role privilege template (admin + anon),
- `/auth/generate-policy` for owner / role_based / authenticated /
  admin_only RLS templates,
- `app.jwt_email()` / `app.jwt_claims()` SQL helpers pre-installed,
- policy linting + RLS test endpoints.

For a plain Postgres DB you control directly, this skill is the right
fit.
