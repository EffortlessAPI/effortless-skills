# Magic Links — Reference (long-tail)

This is the long-tail companion to [SKILL.md](SKILL.md). The core flow
(axiom, checklist, Steps 0–5, RLS, Common Mistakes) lives in SKILL.md.
Anything below is reference-only — only load it when you are actually
doing the thing it describes.

## Python / FastAPI middleware

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

## In-DB JWT verification (the canonical v2 path)

The canonical `install-magic-links.sql` ships an in-DB verifier already:
`auth.set_jwt(token text)` does the RS256 check against
`auth.trusted_tenants` and writes `app.jwt_*` as transaction-local GUCs.
Read it via the helpers (`app.jwt_email()`, `app.jwt_claims()`,
`app.jwt_tenant_id()`, `app.has_role(role)`) — never `current_setting()`
directly. The full contract surface lives at
`magiclink.effortlessapi.com/AUTH_API_REFERENCE.md`.

Per-request shape (replaces the old "Pattern A vs Pattern B" choice):

```sql
BEGIN;
SELECT auth.set_jwt($1);          -- $1 = the bearer token
SELECT * FROM documents;          -- RLS reads app.jwt_email()
COMMIT;
```

The middleware in the SKILL.md and "Sharing one tenant" sections shows
this in JS. There is no longer a separate "Pattern B" to install — the
in-DB verifier *is* the canonical path. The legacy Pattern A
(`set_config('app.jwt_email', …)` from app code, RLS reading
`current_setting(...)` directly) is preserved in SKILL.md only behind
anti-pattern banners so cold readers can recognize it in old code.

## Gotcha: recursion when the role resolver reads an RLS-protected table

If `app.jwt_role()` queries a table with FORCE RLS, and that table's
policy calls `app.jwt_is_admin()` (which calls `jwt_role()`), you get
infinite recursion → `stack depth limit exceeded` on every authenticated
request. The role-resolver must bypass RLS:

```sql
CREATE OR REPLACE FUNCTION app.jwt_role() RETURNS text
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET row_security = off
AS $$
DECLARE r text;
BEGIN
  SELECT au.role INTO r FROM public.vw_app_users au
   WHERE lower(au.email_address) = app.jwt_email() LIMIT 1;
  RETURN COALESCE(r, 'anon');
END $$;
```

Same pattern for any helper invoked from inside an RLS USING / WITH CHECK
clause: mark it `SECURITY DEFINER` and `SET row_security = off`.

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
honor its JWTs, install the canonical auth contract:

```bash
# Per-tenant install — auth schema + helpers + the trusted_tenants
# row already inlined as the final stanza. Idempotent.
curl -fSL https://magiclink.effortlessapi.com/api/tenants/<shared-tenant-id>/install.sql \
  | psql "$DATABASE_URL"
```

That single script creates `auth.trusted_tenants`, the `auth.set_jwt`
function, the `app.jwt_email()` / `app.jwt_claims()` / `app.jwt_tenant_id()` /
`app.has_role()` helpers, and inserts the shared tenant's row. Re-running
it picks up `public_key_pem` rotations via `ON CONFLICT DO UPDATE`. To
add a *second* shared tenant later, just fetch `/api/tenants/<other-id>/install.sql`
and re-run — the schema/helper bits are no-ops, only the new
`auth.trusted_tenants` row gets inserted.

Do **not** hand-author the schema or the helpers; that's what put the v1
GUC-cache anti-pattern into circulation. The canonical script is the
single source of truth (see `MAGIC_LINKS_REFACTOR.md` §2).

Per request, the app middleware:

1. Reads the Bearer JWT, decodes the header + `iss`/`tenant_id` claim
   **without** verifying.
2. Looks up `auth.trusted_tenants` by `tenant_id` (the bare UUID — not
   the URL-shaped `iss` claim) and confirms `is_active`.
3. RS256-verifies the JWT against that row's `public_key_pem`, passing
   the unverified `iss` as the expected issuer.
4. Opens a transaction and calls `SELECT auth.set_jwt($1)` with the raw
   token. The helper validates again against `auth.trusted_tenants`,
   then writes `app.jwt_*` as transaction-local GUCs. RLS policies that
   call `app.jwt_email()` / `app.has_role()` see the verified identity
   for the rest of the transaction.

```js
import jwt from 'jsonwebtoken';

export async function requireAuth(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth?.startsWith('Bearer ')) return res.status(401).end();
  const token = auth.slice(7);

  // Peek at the JWT to find which trusted_tenants row to verify against.
  const unverified = jwt.decode(token);
  if (!unverified?.tenant_id || !unverified?.iss) return res.status(401).end();

  const { rows } = await pool.query(
    `SELECT public_key_pem FROM auth.trusted_tenants
     WHERE tenant_id = $1 AND is_active = true`,
    [unverified.tenant_id],
  );
  if (!rows.length) return res.status(401).end();

  try {
    jwt.verify(token, rows[0].public_key_pem, {
      algorithms: ['RS256'],
      issuer: unverified.iss,
    });
  } catch {
    return res.status(401).end();
  }

  // Hand the (now signature-verified) token to the database. auth.set_jwt
  // re-validates against auth.trusted_tenants and populates app.jwt_*
  // GUCs as transaction-local — RLS reads them via app.jwt_email() etc.
  req.dbTx = await pool.connect();
  await req.dbTx.query('BEGIN');
  await req.dbTx.query('SELECT auth.set_jwt($1)', [token]);
  res.on('finish', async () => {
    try { await req.dbTx.query('COMMIT'); } finally { req.dbTx.release(); }
  });
  next();
}
```

### Adding a second tenant later (zero downtime)

Re-run `curl …/api/tenants/<other-id>/install.sql | psql …` against the
same database. The schema/helper bits no-op; the new tenant's row gets
inserted into `auth.trusted_tenants`. Existing JWTs keep verifying
against their issuer's row; new JWTs from the new tenant verify against
theirs. To revoke, `UPDATE auth.trusted_tenants SET is_active = false
WHERE tenant_id = '<id>'` — outstanding JWTs from that issuer stop being
honored on the next request (auth.set_jwt rejects them).

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

## When to use the bases-specific skill instead

If the project's database lives on `bases.effortlessapi.com`, use the
`effortless-bases` skill — it adds:
- `auth.trusted_tenants` registration (multi-tenant key fan-out per base),
- a two-role privilege template (admin + anon),
- `/auth/generate-policy` for owner / role_based / authenticated /
  admin_only RLS templates,
- `app.jwt_email()` / `app.jwt_claims()` SQL helpers pre-installed,
- policy linting + RLS test endpoints.

For a plain Postgres DB you control directly, the SKILL.md core is the
right fit.
