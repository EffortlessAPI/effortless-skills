---
name: effortless-airtable
description: >
  Use when making schema or data changes via the Airtable API in an ERB project —
  adding fields, creating tables, modifying existing fields, or when you need to
  understand Airtable API limitations (e.g., formula fields cannot be created via API).

  **Scope (load gate):** Effortless projects only — project root must contain `effortless.json` AND a CLAUDE.md identifying the project as ERB methodology. Do NOT load otherwise.
audience: customer
---

# Airtable as Single Source of Truth

ERB projects use Airtable as the authoritative source of truth for schema definitions. The local `effortless-rulebook.json` file is normally generated FROM Airtable.

**Preferred flow (Path A):** Edit Airtable, then `effortless build` to regenerate the JSON and all downstream files.

**Reverse-sync flow (Path B):** When necessary, you CAN edit `effortless-rulebook.json` directly, then push back to Airtable via `effortless build -id` from the `push-to-airtable/` subfolder.

**In either case, always ask the user for permission before modifying the rulebook or Airtable.**

## Getting the API Key

**IMPORTANT: Always check the environment variable FIRST — do not grep config files or search the filesystem before trying this.**

```bash
echo "$AIRTABLE_API_KEY"
```

If `AIRTABLE_API_KEY` is set and non-empty, use it immediately. Only if it is empty, fall back in this order:
1. `~/.ssotme/ssotme.key` → parse JSON → `APIKeys.airtable`
2. `effortless.json` → `ProjectSettings` → `_apikey_`

### Reading from `~/.ssotme/ssotme.key`

The file is JSON:
```json
{
  "EmailAddress": "user@example.com",
  "Secret": "...",
  "APIKeys": {
    "airtable": "patXXXXXXXX.XXXXXXXX"
  }
}
```

Extract the key:
```bash
cat ~/.ssotme/ssotme.key | python3 -c "import sys,json; print(json.load(sys.stdin)['APIKeys']['airtable'])"
```

### Setting the API Key

```bash
effortless -setAccountAPIKey airtable=patXXXXXXXX.XXXXXXXX
```

This stores the key in `~/.ssotme/ssotme.key` under `APIKeys.airtable`.

### The `-account airtable` Flag

When using effortless CLI transpilers that talk to Airtable, **always pass `-account airtable`**. This tells the CLI to send the API key configured in `~/.ssotme/ssotme.key`:

```bash
effortless airtable-to-rulebook -o effortless-rulebook.json -account airtable
effortless rulebook-to-airtable -i ../effortless-rulebook.json -account airtable
```

### `effortless.env`

An `effortless.env` file in the project root can also store keys as environment variables (standard dotenv format). This is an alternative for project-scoped secrets.

## Getting the Base ID

The Airtable base ID for the project is stored in the project settings file (`effortless.json`) as `baseId`:

```bash
cat effortless.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(next(s['Value'] for s in d['ProjectSettings'] if s['Name']=='baseId'))"
```

This base ID is shared across all airtable-facing tools and should always be read from here.

## Making Schema Changes

**ALL schema changes must go through Airtable, then regenerate:**

1. **Get the base ID** from `effortless.json` (the `baseId` setting)
2. **Get the API key** using the priority order above
3. **Use the Airtable API** to make changes
4. **ALWAYS run `effortless build`** from project root to regenerate all code — every time Airtable schema or data is modified, a build must follow

## Adding a Field to a Table

```bash
# 1. Get table schema to find table ID
curl -s "https://api.airtable.com/v0/meta/bases/{BASE_ID}/tables" \
  -H "Authorization: Bearer {API_KEY}" | jq '.tables[] | {id, name}'

# 2. Add the field
curl -s -X POST "https://api.airtable.com/v0/meta/bases/{BASE_ID}/tables/{TABLE_ID}/fields" \
  -H "Authorization: Bearer {API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "FieldName",
    "type": "singleLineText",
    "description": "Field description"
  }'

# 3. Regenerate code
effortless build
```

## Common Airtable Field Types
- `singleLineText` - short text
- `multilineText` - long text
- `number` - numeric values
- `checkbox` - boolean
- `singleSelect` - dropdown
- `multipleSelects` - multi-select
- `date` - date only
- `dateTime` - date and time
- `email` - email address
- `url` - URL
- `formula` - calculated field (CANNOT be created/modified via API)
- `multipleRecordLinks` - foreign key relationship

## Modifying an Existing Field

```bash
curl -s -X PATCH "https://api.airtable.com/v0/meta/bases/{BASE_ID}/tables/{TABLE_ID}/fields/{FIELD_ID}" \
  -H "Authorization: Bearer {API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "NewFieldName",
    "description": "Updated description"
  }'
```

## Creating a New Table

```bash
curl -s -X POST "https://api.airtable.com/v0/meta/bases/{BASE_ID}/tables" \
  -H "Authorization: Bearer {API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "TableName",
    "description": "Table description",
    "fields": [
      {"name": "Name", "type": "singleLineText"},
      {"name": "Status", "type": "singleSelect", "options": {"choices": [{"name": "Active"}, {"name": "Inactive"}]}}
    ]
  }'
```

## Generating OMNI Prompts for Base Setup

When creating prompts for Airtable's OMNI AI to set up tables, **always use the two-part split pattern** documented in the `effortless-omni-prompt` skill:

- **Part 1**: Raw fields + `Link to another record` FKs + Name formula. No other computed fields.
- **Part 2**: Lookups & formulas, **organized by table** (OMNI can only work on one table at a time). Excludes MANY-side rollups.

This pattern ensures linked records are established first, making lookups trivial in Part 2. Never combine into a single file — OMNI will produce incorrect field types.

### OMNI Prompt Field Rules

1. **Table names are PascalCase** — `ShaclShapes`, NOT `shacl_shapes`
2. **`Name` is ALWAYS the first field** — it is a formula that creates a lowercase, dash-separated compound key: `Name | formula | SUBSTITUTE(LOWER({{DisplayName}}), " ", "-")`
3. **`DisplayName` (or `Title`/`Label`)** comes next — the human-readable natural language identifier
4. **NEVER include `{Entity}Id` fields** — surrogate keys are managed by the substrate off-screen
5. **Links use singular PascalCase**: `Schema | link:SDCSchemas`, `TargetClass | link:SDCTypes`

## When Airtable API Has Limitations

Some operations (like modifying formula fields) cannot be done via API. When you hit these limitations:

1. **Tell the user** what you cannot do programmatically
2. **Explain the options**:
   - User can make the change manually in Airtable's UI
   - User can add logic to a customization file (e.g., `02b-customize-functions.sql`)
3. **Wait for user direction** - do not proceed with manual edits to generated files

---

## See also

- `effortless-airtable-omni` — load this instead when the change is a formula, lookup, rollup, or new table (the API can't do those).
- `effortless-workflow` — for Path A vs Path B decisions and permission checkpoints around schema changes.
- `effortless-conventions` — for the naming / DAG rules that any new field or table must follow.
- `effortless-cli` — for `effortless -setAccountAPIKey airtable=...` and `~/.ssotme/ssotme.key` mechanics.
