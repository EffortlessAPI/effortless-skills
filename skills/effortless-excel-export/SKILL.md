---
name: effortless-excel-export
description: >
  Use when adding Excel export to any Effortless project backed by a Postgres
  database. Covers: building a rulebook-export.json from live DB data, running
  the rulebook-to-xlsx transpiler, wiring a server endpoint, and adding a
  download link to the React app.

  **Scope (load gate):** Effortless projects with a Postgres DB and a running
  Express server. Requires `effortless.json` + CLAUDE.md identifying project as
  ERB methodology.
audience: customer
---

# Effortless Excel Export

> **Do NOT use ExcelJS or any other npm xlsx library.** The correct approach
> is the `rulebook-to-xlsx` effortless transpiler — it reads a populated
> `rulebook-export.json` and produces the workbook. No npm dependency, no
> in-process spreadsheet logic.

Any Effortless project can export its current state as a full Excel workbook
— one sheet per entity, all calculated and aggregated columns included.

## How it works

1. Load `effortless-rulebook.json` and clear all `data` arrays (schema stays).
2. Query each `vw_*` view in Postgres and populate the corresponding table's
   `data` array with the live rows.
3. Write the result to `rulebook-export.json`.
4. Run `effortless rulebook-to-xlsx -i rulebook-export.json -o <project>.xlsx`.
5. Stream the xlsx file back to the browser as a download.

## Server endpoint

Add to `server/src/index.ts`:

```typescript
import { execSync } from 'child_process'
import * as fs from 'fs'
import * as path from 'path'

app.get('/api/export/xlsx', async (req, res) => {
  try {
    // 1. Load rulebook and strip data
    const rulebookPath = path.join(__dirname, '../../effortless-rulebook/effortless-rulebook.json')
    const rulebook = JSON.parse(fs.readFileSync(rulebookPath, 'utf8'))

    const reservedKeys = new Set(['$schema', 'Name', 'Description', '_meta'])
    const tableNames = Object.keys(rulebook).filter(k => !reservedKeys.has(k))

    for (const table of tableNames) {
      rulebook[table].data = []
    }

    // 2. Populate from vw_* views (columns are snake_case from Postgres)
    for (const table of tableNames) {
      const viewName = `vw_${table.toLowerCase()}`
      try {
        const { rows } = await pool.query(`SELECT * FROM ${viewName}`)
        // Map snake_case column names back to PascalCase field names
        const schema: Array<{ name: string }> = rulebook[table].schema
        rulebook[table].data = rows.map((row: Record<string, unknown>) => {
          const mapped: Record<string, unknown> = {}
          for (const field of schema) {
            const snakeKey = field.name
              .replace(/([A-Z])/g, '_$1')
              .toLowerCase()
              .replace(/^_/, '')
            if (snakeKey in row) mapped[field.name] = row[snakeKey]
          }
          return mapped
        })
      } catch {
        // View may not exist for this table; leave data empty
      }
    }

    // 3. Write export file
    const exportPath = '/tmp/rulebook-export.json'
    fs.writeFileSync(exportPath, JSON.stringify(rulebook, null, 2))

    // 4. Run transpiler
    const projectName = process.env.PROJECT_NAME ?? 'export'
    const xlsxPath = `/tmp/${projectName}.xlsx`
    execSync(`effortless rulebook-to-xlsx -i ${exportPath} -o ${xlsxPath}`)

    // 5. Stream download
    res.download(xlsxPath, `${projectName}.xlsx`, () => {
      fs.unlinkSync(xlsxPath)
    })
  } catch (err) {
    console.error('Export failed:', err)
    res.status(500).json({ error: 'Export failed' })
  }
})
```

Set `PROJECT_NAME` in your env or `start.sh`:

```bash
export PROJECT_NAME="expense-approval-system"
```

## React download link

Add to any page or the shell nav — no fetch needed, just a plain anchor:

```tsx
<a href="/api/export/xlsx" download>
  Download Excel Export
</a>
```

For a styled button:

```tsx
<a
  href="/api/export/xlsx"
  download
  className="export-btn"
>
  ↓ Export to Excel
</a>
```

## Column name mapping

The `vw_*` views expose columns in `snake_case` (Postgres convention). The
rulebook field names are `PascalCase`. The endpoint above maps them by
converting each schema field name to snake_case before looking it up in the
row. If a column doesn't resolve, it's silently skipped — check the schema
field names against `\d vw_<table>` in psql if columns are missing.

## Pitfalls

- **`effortless` must be on the server's PATH.** If the endpoint throws
  `command not found`, add the effortless binary directory to the server's
  `PATH` in `start.sh` before `npm run dev`.
- **`/tmp` on the server.** Fine for dev/demo. For production, use a proper
  temp directory or stream directly from memory.
- **Large datasets.** The export is synchronous (`execSync`). For very large
  tables (10k+ rows) consider an async job + polling pattern. For demos this
  is not a concern.
- **Calculated fields in the export.** Because the export reads from `vw_*`
  views, every calculated, lookup, and aggregation column is included — the
  Excel file is a full snapshot, not just raw data.

## Installing the transpiler

If `rulebook-to-xlsx` is not yet installed:

```bash
effortless -install rulebook-to-xlsx
```

Verify with `effortless -list | grep xlsx`.
