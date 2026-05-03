---
name: effortless-conventions
description: >
  Use when you need ERB naming conventions, DAG structure rules, PascalCase table
  names, primary key and foreign key patterns, the Name field requirement, or
  understanding why many-to-many relationships are not allowed.

  **Scope (load gate):** Effortless projects only — project root must contain `effortless.json` AND a CLAUDE.md identifying the project as ERB methodology. Do NOT load otherwise.
audience: customer
---

# ERB Naming & Design Conventions

> **Load-bearing axiom: `Name` is the primary key. Surrogates are the substrate's problem.**
> Every table's first field is `Name` — a kebab-cased compound formula that
> uniquely identifies a row in human-readable form. `{Entity}Id` columns
> never appear in the rulebook; substrates (Postgres, Airtable, etc.) may
> mint surrogate keys off-screen for referential integrity, but they are
> invisible to the domain model.

## Table Names
- **PascalCase**, no spaces, no symbols, no underscores
- Plural for collections: `Customers`, `WorkflowSteps`, `TypesOfAgents`
- Example: `ClientProgramSessions`, `DocumentCategories`, `ApprovalGates`

## The Name Field (PRIMARY KEY)
- **`Name` is ALWAYS the FIRST field in EVERY table. No exceptions.**
- `Name` is ALWAYS a `formula`/`calculated` field that produces a lowercase, dash-separated compound key — the human-readable unique identifier for each row.
- Formula pattern: `SUBSTITUTE(LOWER({{DisplayName}}), " ", "-")` for simple tables, or compound keys like `SUBSTITUTE(LOWER({{OrderNumber}} & "-" & {{Status}}), " ", "-")` for junction/child tables.
- `Name` IS the primary key in the rulebook. It is query-friendly (no spaces), human-readable, and unique within the table.
- In Airtable, this is the primary field (first column) that labels each record.

## Surrogate Keys (`{Entity}Id`) — NEVER in Schema
- Surrogate keys (e.g., `CustomerId`, `WorkflowStepId`) are managed **by the execution substrate** (Airtable row IDs, Postgres UUIDs, etc.) — they are NEVER declared in omni prompts, schema definitions, or the rulebook's field list.
- The `Name` formula IS the logical key. Substrates may add a surrogate key "off-screen" for referential integrity, but it is invisible to the domain model.
- **Do NOT include `{Entity}Id` fields in omni prompts or table definitions. Ever.**

## Every Table and Field Must Have a Description
- Descriptions form the semantic backbone of the DAG
- They explain purpose, usage context, and ontology mappings
- Example: `"Human-readable name for the workflow. Maps to dct:title per Dublin Core."`

## Foreign Key Conventions

**The FK field uses the SINGULAR entity name, NO "Id" suffix:**

```
Order.Customer     (FK to Customers table)    -- NOT Order.CustomerId
Employee.Role      (FK to Roles table)        -- NOT Employee.RoleId
Artifact.DerivedFrom (FK to Artifacts table)  -- NOT Artifact.DerivedFromId
```

**The reverse relationship uses the PLURAL name:**

```
Customer.Orders    (relationship, RelatedTo: "Orders")
Role.Employees     (relationship, RelatedTo: "Employees")
Workflow.WorkflowSteps (relationship, RelatedTo: "WorkflowSteps")
```

**Always 1-to-many. The singular side is the parent (1), the plural side is the children (many).**

## NO MANY-TO-MANY RELATIONSHIPS. EVER.

The rulebook is a **Directed Acyclic Graph (DAG)**. Many-to-many breaks the acyclic requirement.

If you think you need many-to-many, introduce a **junction table**:
```
# WRONG: Students <-> Courses (many-to-many)

# RIGHT: Students -> Enrollments <- Courses (two 1-to-many via junction)
Students.Enrollments   (1-to-many)
Courses.Enrollments    (1-to-many)
Enrollment.Student     (FK to Students)
Enrollment.Course      (FK to Courses)
```

## Calculated Field Naming Patterns

| Pattern | Meaning | Example |
|---------|---------|---------|
| `Is{Something}` | Boolean flag | `IsRedHeaded`, `IsWinningBid`, `IsHighQualityFit` |
| `CountOf{Related}` | Aggregation count | `CountOfWorkflowSteps`, `CountOfOrders` |
| `{FK}{FieldName}` | Lookup field | `AssignedRoleLabel`, `IsStepOfTitle`, `CustomerName` |
| `{Noun}Amount` | Monetary/numeric total | `BidAmount`, `TotalSales` |
| `{Noun}Status` | Status lookup | `RfpStatus`, `VendorStatus` |

---

## The DAG: Directed Acyclic Graph

The rulebook IS a DAG. Understanding this is essential.

### Table-Level DAG
- **Tables are nodes**, FK relationships are directed edges
- Edges point from child to parent: `Order -> Customer`, `WorkflowStep -> Workflow`
- No cycles allowed. If A references B, B cannot reference A (directly or transitively)
- Lookup/aggregation fields traverse these edges to pull or roll up data

### Field-Level DAG (within a table)
- **Level 0**: Raw fields (no dependencies)
- **Level 1**: Calculated fields that depend only on Level 0 raw fields
- **Level 2+**: Calculated fields that depend on other calculated fields
- Formula parsing must respect this ordering — compute Level 0 first, then Level 1, etc.

### Visualizing the DAG
```
Departments
    |
    v
Roles ---------> Agents
    |
    v
WorkflowSteps --> Workflows
    |
    v
Artifacts ------> Datasets
```

Arrows point from child (many-side) to parent (one-side). Data flows UPWARD through lookups and aggregations.

---

## See also

- `effortless-schema` — for the JSON shape these conventions produce in `effortless-rulebook.json`.
- `effortless-orchestrator` — for the bigger mental model these conventions live inside.
- `effortless-airtable-omni` — for OMNI prompts that respect the `Name` formula and singular-FK rules.
- `effortless-sql` — for how PascalCase / `Name` / FK conventions translate to snake_case columns and `vw_*` views.

---

## Magic-links refactor (v0.2)

> See [../../MAGIC_LINKS_REFACTOR.md](../../MAGIC_LINKS_REFACTOR.md) §6 for the canonical v0.2 magic-links contract.

Anti-patterns to flag during a project audit:

1. **`MagicLinkIntegration` / `ERBmagiclinks` rulebook tables** — auth state does not belong in the rulebook. The only source of truth is `auth.trusted_tenants` from `install-magic-links.sql`. Offer migration when seen.

2. **v1 GUC-cache pattern** — raw `set_config('app.jwt_email', …)` from Node middleware + RLS reading `current_setting('app.jwt_email', true)` directly, with no `auth.set_jwt(token)` in transaction. The v2 shape is `BEGIN; SELECT auth.set_jwt($1); … COMMIT;` and policies use `app.jwt_email()`. Offer migration when seen.
