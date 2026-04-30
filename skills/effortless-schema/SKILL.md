---
name: effortless-schema
description: >
  Use when you need to understand the structure of effortless-rulebook.json —
  table objects, field schema definitions, field types (raw, calculated, lookup,
  relationship, aggregation), datatypes, formula syntax, or the _meta section.
audience: customer
---

# Rulebook JSON Schema Reference

## Top-Level Structure

```json
{
  "$schema": "https://example.com/cmcc-schema/v1",
  "Name": "Project Display Name",
  "Description": "Rulebook generated from Airtable base 'Base Name'.",
  "TableName": {
    "Description": "Table: TableName",
    "schema": [ /* field definitions */ ],
    "data": [ /* row records */ ]
  },
  "AnotherTable": { ... },
  "_meta": { /* conversion metadata */ }
}
```

**Top-level keys:**
| Key | Purpose |
|-----|---------|
| `$schema` | Schema version URI (always `https://example.com/cmcc-schema/v1`) |
| `Name` | Human-readable project/base name |
| `Description` | Auto-generated description |
| `{TableName}` | One key per entity table (PascalCase) |
| `_meta` | Conversion metadata, type mappings, tool version |

## Table Object

Each table key contains:
```json
{
  "Description": "Table: TableName",
  "schema": [ /* array of field definitions */ ],
  "data": [ /* array of row objects */ ]
}
```

## Field Schema Object

Every field in the `schema` array follows this structure:

```json
{
  "name": "FieldName",
  "datatype": "string",
  "type": "raw",
  "nullable": true,
  "Description": "What this field represents and how it is used.",
  "formula": "=CONCAT({{FirstName}}, \" \", {{LastName}})",
  "RelatedTo": "OtherTable"
}
```

| Property | Required | Values | Notes |
|----------|----------|--------|-------|
| `name` | Yes | PascalCase string | Field identifier |
| `datatype` | Yes | `string`, `integer`, `number`, `boolean`, `datetime` | Target data type |
| `type` | Yes | `raw`, `calculated`, `lookup`, `relationship`, `aggregation` | Field derivation type |
| `nullable` | Yes | `true` / `false` | Whether NULL is allowed |
| `Description` | Should exist | Free text | Purpose, usage, ontology mapping |
| `formula` | If calculated/lookup/aggregation | Excel-dialect formula | How the value is derived |
| `RelatedTo` | If relationship | Table name (PascalCase) | FK target entity |

## Field Types

| Type | Meaning | Stored In | Example |
|------|---------|-----------|---------|
| `raw` | Direct user input | Base table | `FirstName`, `EmailAddress`, `DueDate` |
| `calculated` | Derived from formula on same-row fields | View (via function) | `FullName = {{LastName}} & ", " & {{FirstName}}` |
| `lookup` | Value pulled from a related table via FK | View (via function) | `=INDEX(Roles!{{Label}}, MATCH({{AssignedRole}}, Roles!{{RoleId}}, 0))` |
| `relationship` | Foreign key reference to another table | Base table (as text ID) | `Customer` pointing to `Customers` table |
| `aggregation` | Rollup/count/sum over related rows | View (via function) | `=COUNTIFS(Orders!{{Customer}}, Customers!{{CustomerId}})` |

## Data Types

| Datatype | Postgres | Go | Python | Airtable Source |
|----------|----------|-----|--------|-----------------|
| `string` | `TEXT` | `string` | `str` | singleLineText, multilineText, email, url, phoneNumber, singleSelect |
| `integer` | `INTEGER` | `int` | `int` | number (when whole) |
| `number` | `NUMERIC` | `float64` | `float` | number (when decimal) |
| `boolean` | `BOOLEAN` | `bool` | `bool` | checkbox |
| `datetime` | `TIMESTAMPTZ` | `time.Time` | `datetime` | date, dateTime |

## Formula Syntax

Formulas use Excel dialect with `={{FieldName}}` for field references:

```
# String concatenation
={{LastName}} & ", " & {{FirstName}}

# Conditional
=IF({{Status}} = "Active", TRUE(), FALSE())

# Boolean compound
=AND({{HasSyntax}}, {{IsParsed}}, NOT({{CanBeHeld}}))

# Lookup (cross-table)
=INDEX(Roles!{{Label}}, MATCH({{AssignedRole}}, Roles!{{RoleId}}, 0))

# Aggregation
=COUNTIFS(WorkflowSteps!{{IsStepOf}}, Workflows!{{WorkflowId}})
=SUMIFS(Orders!{{Amount}}, Orders!{{Customer}}, Customers!{{CustomerId}})

# String manipulation
=SUBSTITUTE(LOWER({{CompanyName}}), " ", "-")
```

**Supported functions:** IF, AND, OR, NOT, TRUE, FALSE, CONCAT, SUBSTITUTE, LOWER, UPPER, LEFT, RIGHT, MID, LEN, TRIM, FIND, SEARCH, TEXT, VALUE, SUM, COUNT, COUNTIFS, SUMIFS, AVERAGEIFS, MIN, MAX, INDEX, MATCH, POWER, LOG, LOG10, ABS, ROUND, COALESCE/IFERROR.

## The _meta Section

```json
"_meta": {
  "_CMCC_Summary": "Airtable export with schema-first type mapping...",
  "_conversion_metadata": {
    "source_base_id": "appXXXXXXXXXXXX",
    "table_count": 5,
    "tool_version": "2.0.0",
    "field_type_mapping": "checkbox->boolean, number->number/integer, multipleRecordLinks->relationship...",
    "export_mode": "schema_first_type_mapping",
    "type_inference": {
      "priority": "airtable_metadata (NO COERCION) -> formula_analysis -> data_analysis (fallback only)",
      "error_value_handling": "#NUM!, #ERROR!, #N/A, #REF!, #DIV/0!, #VALUE!, #NAME? are treated as NULL"
    }
  }
}
```

---

## See also

- `effortless-query` — for one-liners that extract this structure without reading the full file.
- `effortless-conventions` — for the naming / DAG rules that explain *why* the JSON looks the way it does.
- `effortless-sql` — for how each field type / datatype maps to the generated Postgres tables, functions, and views.
- `effortless-orchestrator` — for the canonical "Token Discipline" rule that says: query this JSON, never read it whole.
