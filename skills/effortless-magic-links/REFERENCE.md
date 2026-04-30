# Magic Links — Reference (long-tail)

This is the long-tail companion to [SKILL.md](SKILL.md). The core flow
(axiom, checklist, Steps 0–3, RLS Pattern A, Common Mistakes) lives in
SKILL.md. Anything below is reference-only — only load it when you are
actually doing the thing it describes.

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

## Pattern B — verify the JWT inside Postgres

Heavier than Pattern A — requires the `pgjwt` extension (or a custom
plpgsql function that does RS256 verification). Only worth it if you
cannot trust the caller to set the GUC, e.g. direct DB access. For most
app-fronted DBs, **Pattern A in SKILL.md is correct.**

If you do need it, the shape:

```sql
CREATE EXTENSION IF NOT EXISTS pgjwt;

-- Verify and return claims, or NULL on failure.
CREATE OR REPLACE FUNCTION app.jwt_claims_from_header(hdr text)
RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
DECLARE
  pem text;
  token text;
  v jsonb;
BEGIN
  IF hdr IS NULL OR hdr NOT LIKE 'Bearer %' THEN RETURN NULL; END IF;
  token := substring(hdr from 8);

  SELECT public_key_pem INTO pem
    FROM auth.trusted_tenants
   WHERE tenant_id = (extensions.jwt_decode(token)->>'tenant_id')
     AND is_active;

  IF pem IS NULL THEN RETURN NULL; END IF;
  -- Real implementation must RS256-verify against pem; pgjwt's verify_*()
  -- helpers don't ship RS256 out of the box, so this typically wraps
  -- plpython3 + cryptography. Treat the snippet as a sketch.
  v := extensions.jwt_decode(token);
  RETURN v;
END $$;
```

Most teams pick Pattern A, set the GUC at the connection-pool boundary,
and skip pgjwt entirely.

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
