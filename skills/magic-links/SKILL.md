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

## Default action when invoked

When the user says "add magic links to this project" / "wire up magic
links" / "integrate magic links" / "secure this app with magic links" or
debugs a broken magic-link login, **just do it** — don't ask "want me to
proceed?" before each step. The user invoking the skill **is** the
go-ahead.

Run this checklist top-to-bottom:

1. **Locate or mint the tenant.** Grep the project for an existing
   `TENANT_ID` / `MAGICLINK_TENANT_ID`. If found, verify it still exists
   on the magic-link service:
   ```bash
   curl -s "https://magiclink.effortlessapi.com/api/tenants/<id>" -w '\nHTTP %{http_code}\n'
   ```
   404 `tenant_not_found` → re-mint (the upstream may have been wiped, or
   the tenant was minted on a different magic-link instance). 200 with
   `public_key_pem` → reuse it; just confirm the in-app public key matches.
   No tenant in the project → mint a new one.
   To mint: run Step 0 (self-auth) then Step 1 (POST `/api/tenants`)
   below. **Do not put this in the user's lap as "you go run these
   curls."** Claude drives the curls; the user only reads a code from
   their inbox.
2. **Pick where the tenant config lives.** New project → env vars
   (`MAGICLINK_BASE_URL`, `MAGICLINK_TENANT_ID`, `MAGICLINK_PUBLIC_KEY_PEM`).
   Existing project that already hard-codes them → keep the same shape so
   you don't churn the diff.
3. **Wire (or fix) the server-side proxy + verifier.** Two routes —
   `POST /api/auth/request-code` → upstream `/api/tenants/<id>/send-code`,
   and `POST /api/auth/verify-code` → upstream
   `/api/tenants/<id>/verify-code` (note: upstream takes `code`, not
   `token`). Verify the returned JWT locally with RS256 against
   `public_key_pem`, with `tenant_id` claim pinned to your tenant.
4. **Wire (or check) the login UI** — two-step email → code, JWT stored
   in `localStorage` and sent as `Authorization: Bearer` on subsequent
   calls.
5. **Restart and smoke-test.** `curl` the local request-code endpoint;
   real `ok:true` means the upstream sent an email. (Heads-up:
   upstream `send-code` always returns `ok:true` even for non-existent
   tenants — see "Common mistakes". Always pair it with `GET
   /api/tenants/<id>` on first wire-up to confirm the tenant actually
   exists.)
6. **Persist tenant id + public-key location** in project memory or a
   short note in CLAUDE.md so future sessions don't re-mint.

If the project is on `bases.effortlessapi.com`, switch to the
`effortless-bases` skill before Step 3 — bases adds `auth.trusted_tenants`
registration and `app.jwt_*()` helpers that change the wiring.

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

**JWT details:** RS256, `iss = {magiclink_base}/{tenant_id}` (the **full
URL**, not the bare UUID), `tenant_id` = the bare UUID (separate claim),
`email` = verified email, `exp` per the tenant's `jwt_expires_in_seconds`
(default 3600s).

**Verifier gotcha:** look up your `auth.trusted_tenants` row by the
`tenant_id` claim — **not** by `iss`. Then pass `iss` as the expected
issuer to your JWT library. Confusing the two means your registry lookup
silently misses every token.

---

## Recipe: zero → secured app

### Step 0 — get a self-auth JWT (Claude drives this; user just reads a code)

**This is Claude's job, not the user's.** Whenever a tenant create/modify
operation is needed (`POST/PATCH/DELETE /api/tenants`), Claude obtains and
caches the self-auth JWT itself. The user's only involvement is reading
the 6-digit code from their inbox when asked.

The flow:

1. Claude POSTs `/auth/send-code` with the user's email (from
   `git config user.email`, the user's known email in context, or by
   asking once if neither is available).
2. Claude tells the user "I sent a code to <email> — paste it back."
3. User pastes the 6-digit code.
4. Claude POSTs `/auth/verify-code` and stores the returned token
   somewhere session-durable (e.g. `/tmp/magiclink-self-auth-<email>.json`
   with mode 0600). The response shape is `{ token, expires_in, user }`
   — the JWT field is `token`, **not** `jwt` (`/api/tenants/{id}/verify-code`
   uses `jwt`; `/auth/verify-code` uses `token` — easy to get wrong).
5. Claude reuses that cached token for every subsequent tenant op in the
   session, until `expires_in` lapses (default 3600s). Then re-runs Steps
   1–4.

```bash
MAGICLINK="https://magiclink.effortlessapi.com"
DEV_EMAIL="<the user's email>"

# Claude runs:
curl -sS "$MAGICLINK/auth/send-code" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$DEV_EMAIL\"}"
# → tell the user: "I sent a code to $DEV_EMAIL — paste it back."

# After user pastes CODE:
curl -sS "$MAGICLINK/auth/verify-code" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$DEV_EMAIL\",\"code\":\"$CODE\"}" \
  > /tmp/magiclink-self-auth-$DEV_EMAIL.json
chmod 600 /tmp/magiclink-self-auth-$DEV_EMAIL.json

SELF_JWT=$(jq -r .token /tmp/magiclink-self-auth-$DEV_EMAIL.json)
```

**Do not put this flow in the user's lap as "you go run these curls."**
The user shouldn't be juggling tokens; that's the agent's responsibility.

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
    const token = auth.slice(7);
    // iss is the FULL URL form: https://magiclink.effortlessapi.com/<tenant_id>
    // Read it off the unverified payload, then pass it to jwt.verify so the
    // verifier checks the signature *and* matches the expected issuer.
    const unverified = jwt.decode(token);
    if (unverified?.tenant_id !== TENANT_ID) throw new Error('wrong_tenant');
    const decoded = jwt.verify(token, PUBLIC_KEY, {
      algorithms: ['RS256'],
      issuer: unverified.iss,
    });
    req.user = decoded; // { email, sub, iss, tenant_id, exp, ...additional_claims }
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

## Sharing one tenant across multiple databases (mutual trust)

Magic-links is **issuer-only** — it has no concept of "trust." Trust is
expressed entirely on the consumer side: each Postgres database keeps a
small registry of `(tenant_id, public_key_pem)` rows it will honor, and
verifies any inbound JWT against the row whose `tenant_id` matches the
JWT's `iss` claim.

This makes mutual trust trivial. **You do not need one tenant per app.**
A JWT issued at `/api/tenants/<T>/verify-code` is signed with tenant T's
private key, and will verify cleanly on any database that has T's public
key in its registry.

### When to share a tenant vs mint a new one

- **Share** when multiple apps/databases form one product surface and
  end-users should sign in once and have access across them (e.g.
  `bases.effortlessapi.com` + a downstream consumer app that reads from
  the same base).
- **Mint a new tenant** when the apps are independent products, have
  different `from_email` branding, or need independent rotation/revocation.

### The pattern

Pick (or mint) **one** tenant, then in **every** Postgres that should
honor its JWTs:

```sql
CREATE SCHEMA IF NOT EXISTS auth;

CREATE TABLE IF NOT EXISTS auth.trusted_tenants (
  tenant_id      text PRIMARY KEY,
  public_key_pem text NOT NULL,
  is_active      boolean NOT NULL DEFAULT true,
  added_at       timestamptz NOT NULL DEFAULT now()
);

INSERT INTO auth.trusted_tenants (tenant_id, public_key_pem)
VALUES ('<shared-tenant-id>', '<public_key_pem>')
ON CONFLICT (tenant_id) DO UPDATE
  SET public_key_pem = EXCLUDED.public_key_pem,
      is_active = true;
```

Per request, the app middleware:

1. Reads the Bearer JWT, decodes the header + `iss` claim **without**
   verifying.
2. Looks up `auth.trusted_tenants` by `tenant_id = iss AND is_active`.
3. RS256-verifies the JWT against that row's `public_key_pem`, with
   `issuer: tenant_id`.
4. Sets `app.jwt_email` / `app.jwt_claims` GUCs (Pattern A) so RLS fires.

```js
import jwt from 'jsonwebtoken';

export async function requireAuth(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) return res.status(401).end();
  const token = auth.slice(7);

  // Peek at iss without verifying.
  const unverified = jwt.decode(token);
  if (!unverified?.iss) return res.status(401).end();

  const { rows } = await pool.query(
    `SELECT public_key_pem FROM auth.trusted_tenants
     WHERE tenant_id = $1 AND is_active = true`,
    [unverified.iss],
  );
  if (!rows.length) return res.status(401).end();

  try {
    req.user = jwt.verify(token, rows[0].public_key_pem, {
      algorithms: ['RS256'],
      issuer: unverified.iss,
    });
    next();
  } catch {
    res.status(401).end();
  }
}
```

### Adding a second tenant later (zero downtime)

Just `INSERT` another row. Existing JWTs keep verifying against their
issuer's row; new JWTs from the new tenant verify against theirs. To
revoke, set `is_active = false` — outstanding JWTs from that issuer stop
being honored on the next request.

### Anti-pattern

- **Hard-coding a single `MAGICLINK_PUBLIC_KEY_PEM` env var.** Works for
  one tenant, breaks the moment you need a second. Prefer the
  `auth.trusted_tenants` table from the start, even when there's only one
  row — it costs nothing and the second-tenant migration is a no-op.
- **Caching the public key without keying by `iss`.** A process-wide
  single-key cache hides the multi-tenant case until production. If you
  cache, key by `tenant_id`.

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
- **Forgetting to set `iss` on the verifier.** Without an `issuer` option,
  a JWT minted for *any* tenant the same magic-links instance hosts would
  pass — which is a cross-tenant auth bug. Pass the **decoded `iss`** (the
  URL form), not the bare tenant UUID.
- **Looking up `auth.trusted_tenants` by `iss`.** The registry's primary
  key is the bare UUID; `iss` is a URL. Use the `tenant_id` claim for the
  lookup. (Discovered the hard way in the v2-naked-claude-demo project.)
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
