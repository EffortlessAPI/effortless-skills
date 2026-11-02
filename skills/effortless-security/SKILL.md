---
name: effortless-security
description: >
  ERB Security module — roles, the <Role>CRUD matrix on ERBTables/ERBFields, role_<id> schemas, per-role
  TypeScript types; hiding columns is also the performance fix. Triggers: "who can see", "hide this column",
  "role types", "slow persona". ERB projects only.
audience: customer
---

# Security module: roles, the CRUD matrix, role schemas, role types

Security is **shape, not a check**: each role gets its own Postgres schema (`role_<id>`) holding only the
tables it may read, only the columns it may read, only the rows it may see. A table or column a role cannot
read **does not exist** for it. That is also the performance lever: a derived column is a function call per
row, and a column that is not in the role's view is never computed.

## Pipeline

```
effortless-rulebook.json (Security module on)
  -> rulebook-to-rbac                      -> rbac/effortless-rbac.json + rbac/role-types/*.d.ts
  -> effortless-rbac-to-postgres-policies  -> postgres/06-rbac-policies.sql (roles, grants, RLS, role_<id> schemas)
```

`rulebook-to-postgres` does not do this; do not look for role views there.

## Where permissions live

| Where | What | Use for |
|---|---|---|
| `ERBRoles` | one row per role: `DefaultCRUD`, `DefaultRowFilter`, `IsAdminEquivalent`, `IsTenantExempt` | the role and its default |
| **`ERBTables.<Role>CRUD`** | one column per role, a CRUD string for the table | table access (the matrix) |
| **`ERBFields.<Role>CRUD`** | same, per field | hiding or narrowing columns (the matrix) |
| `ERBRoleTablePermissions` | rows `(role, table) -> CRUD, RowFilter` | row filters; also table CRUD when no matrix column exists |
| `ERBRoleFieldPermissions` | rows `(role, field) -> CRUD` | field denials when no matrix column exists |

**The matrix is the compact form**: 30 roles are 30 columns, not thousands of rows, and a UI edits it as a grid.
Column name = each word of the role id capitalised + `CRUD` (`floor-player` -> `FloorPlayerCRUD`, `sre` ->
`SreCRUD`). A column that matches no role is reported, never silently dropped. Adding a role adds a column
(the schema changes; roles change rarely). Where the matrix and permission rows disagree, **the matrix wins**.

## The cascade (blank inherits, empty means none)

`role default -> table cell -> field cell -> row filter`

- **blank/null cell = inherit.** A field inherits its table; a table inherits its permission row, else the
  meta-table rule (non-admin roles get no ERB/meta table), else the role default.
- **`""` or `"-"` = no access.** On a field: that column disappears from the role's view. On a table: no view.
- **A cell can only narrow.** `R` on a table makes every column read-only; `""` on one field hides just it.
  A field cell never grants beyond its table.
- The key column cannot be hidden (it addresses the row); a cell there is ignored with a warning.
- A matrix grant on a **meta table** does not inherit the role's default row filter (it is not tenant data).
- Row filters (`DefaultRowFilter`, `RowFilter`) are written in rulebook names with `{{var}}` placeholders.

## Make a persona fast: narrow the wide tables

When a table has many roll-up columns (counts, statuses, report flags) only an admin or dashboard needs:

1. Give every other role `R` on the table (`ERBTables.<Role>CRUD`) if they need it at all.
2. Put `""` in `ERBFields.<Role>CRUD` for every roll-up field; leave the identity/look fields blank.
3. Their `role_<id>.<table>` view then lists a dozen cheap columns, and **`select *` through it is cheap**.

Measured (russell-witt-demo `ERBRoles`, 50 columns, ~40 derived): `select *` from `public.vw_erb_roles`
259 ms; from `role_floor.erb_roles` (22 columns) 2-3 ms. The same projection through `?fields=` is
equally fast, so keep naming fields in the app as well (see `effortless-rulebook-editor`).

## Role types: trust the shape

`rbac/role-types/<role>.d.ts` is generated from the same cascade as the role's views, so it is complete:

```ts
import type { RoleTables, RoleFields } from "./generated/role-types";
type Row = RoleTables["floor"]["ERBRoles"];            // snake_case keys, exactly the view's columns
const f: RoleFields["floor"]["ERBRoles"] = "ThemeName"; // PascalCase names ?fields= accepts
```

Per role: `Tables` (row type per readable table), `Fields` (names for `?fields=`), `Writable` (names a create/update
body may carry). `index.d.ts` has `RoleName`, `RoleTables`, `RoleFields`, `RoleWritable`. Reading a hidden column
or table is a compile error. Never hand-write these types; regenerate (the files are build output).

## Rules

- **Fix a slow persona by hiding columns, not by caching.** Look at `ERBFields.<Role>CRUD` first.
- **Never edit `06-rbac-policies.sql`**; change the rulebook cells and rebuild.
- A role that cannot see a table cannot name it in a filter either; filters must name columns of their own table.
- Verify with a query as the role: `set search_path = role_<id>; select * from <table>;`.
- Adding a raw column (a new `<Role>CRUD`) needs the editor's full restart, not `reload`.
