// db.js — the ephemeral Postgres substrate, seeded GENERICALLY from any rulebook.
//
// On boot we DROP + recreate the `portal` schema and inject EVERY table the
// rulebook defines (any top-level key with a `.schema` array and `.data`
// array — see rulebook.js#listTables). This is intentionally NOT a hardcoded
// 4-table mirror: it works for any Effortless rulebook, not just this one.
//
// Read-only: there is no write path back to the rulebook here. The DB is a
// disposable projection, rebuilt fresh from effortless-rulebook.json on every
// `docker compose up --build`.

import pg from 'pg';
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { listTables, REPO_ROOT } from './rulebook.js';

const { Pool } = pg;

export const pool = new Pool({
  host: process.env.PGHOST || 'localhost',
  port: Number(process.env.PGPORT || 55432),
  user: process.env.PGUSER || 'portal',
  password: process.env.PGPASSWORD || 'portal',
  database: process.env.PGDATABASE || 'rulebook',
  max: 6,
});

export async function waitForDb(retries = 60) {
  for (let i = 0; i < retries; i++) {
    try {
      await pool.query('select 1');
      return;
    } catch {
      await new Promise((r) => setTimeout(r, 500));
    }
  }
  throw new Error('Postgres never became reachable on ' + (process.env.PGPORT || 55432));
}

// ---- naming helpers ----------------------------------------------------

const snake = (s) =>
  s
    .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
    .replace(/[^a-zA-Z0-9]+/g, '_')
    .toLowerCase()
    .replace(/^_+|_+$/g, '');

const tableIdent = (name) => `portal.${snake(name)}`;
const colIdent = (name) => snake(name);

// Map a rulebook field's `datatype` to a Postgres column type. Safe fallback
// to `text` for anything we don't recognize (must never crash the seed for
// an unfamiliar rulebook).
function pgType(datatype) {
  switch ((datatype || '').toLowerCase()) {
    case 'integer':
    case 'int':
      return 'bigint';
    case 'boolean':
    case 'bool':
      return 'boolean';
    case 'float':
    case 'number':
    case 'decimal':
      return 'double precision';
    case 'string':
    default:
      return 'text';
  }
}

// ---- minimal formula evaluation for `calculated` fields ------------------
//
// `calculated` (and some `lookup`) fields are NOT stored in `.data` rows —
// per effortless-schema, their values are derived at read time from a
// spreadsheet-style formula referencing sibling fields via {{FieldName}}.
// This is a read-only display projection, not a full formula engine: we only
// need to evaluate the small set of shapes this repo's conventions actually
// produce for the calculated `Name` PK and similar same-row derivations —
// `=SUBSTITUTE(LOWER({{Field}}), " ", "-")`, string concatenation with `&`,
// and a bare `={{Field}}` reference. Anything else falls back to null rather
// than crashing the seed (defensive — this must not explode on an unfamiliar
// rulebook's formula shapes; cross-table lookups are handled separately by
// the relationship-label resolver, not by this evaluator).
function evalFormula(formula, row) {
  if (!formula || typeof formula !== 'string' || !formula.startsWith('=')) return undefined;
  let expr = formula.slice(1).trim();

  // SUBSTITUTE(LOWER({{Field}}), " ", "-")
  let m = expr.match(/^SUBSTITUTE\(LOWER\(\{\{(\w+)\}\}\),\s*"([^"]*)"\s*,\s*"([^"]*)"\)$/i);
  if (m) {
    const [, field, search, replace] = m;
    const v = row[field];
    if (v == null) return undefined;
    return String(v).toLowerCase().split(search).join(replace);
  }

  // Bare {{Field}} reference, optionally concatenated with string literals via &
  if (/^\{\{\w+\}\}$/.test(expr)) {
    const field = expr.slice(2, -2);
    return row[field] ?? undefined;
  }

  // "literal" & {{Field}} & "literal" ... (string concatenation)
  if (expr.includes('&')) {
    const parts = expr.split('&').map((p) => p.trim());
    let out = '';
    for (const p of parts) {
      const lit = p.match(/^"([^"]*)"$/);
      const ref = p.match(/^\{\{(\w+)\}\}$/);
      if (lit) out += lit[1];
      else if (ref) out += row[ref[1]] ?? '';
      else return undefined; // unrecognized shape — bail out to null
    }
    return out;
  }

  return undefined; // unrecognized formula shape — leave null rather than guess
}

// Fill in any `calculated` field missing from a raw data row by evaluating
// its formula against the row's own (already-present) fields. Cross-table
// `lookup` formulas are intentionally NOT evaluated here — the API layer
// resolves relationship display labels live instead (see resolveLabel).
function materializeCalculatedFields(schemaFields, row) {
  const out = { ...row };
  for (const f of schemaFields) {
    if (f.type === 'calculated' && (out[f.name] === undefined || out[f.name] === null)) {
      const v = evalFormula(f.formula, out);
      if (v !== undefined) out[f.name] = v;
    }
  }
  return out;
}

// Defensive cell coercion: JSON-stringify arrays/objects so nothing ever
// throws at insert time, regardless of what a given rulebook puts in a cell.
function coerceCell(value, datatype) {
  if (value === undefined) return null;
  if (value === null) return null;
  if (Array.isArray(value) || (typeof value === 'object')) return JSON.stringify(value);
  const dt = (datatype || '').toLowerCase();
  if ((dt === 'integer' || dt === 'int') && typeof value !== 'number') {
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
  }
  return value;
}

// ---- generic schema + seed ----------------------------------------------

// In-memory metadata describing every seeded table: columns, and which
// columns are soft FKs (relationship fields) pointing at which target table.
// Shape: { [tableName]: { fields: [...schema], fkFields: [{ field, relatedTo }] } }
let TABLE_META = {};

export function getTableMeta() {
  return TABLE_META;
}

export async function seedFromRulebook(rb) {
  const tables = listTables(rb); // [{ name, description, fields, rows }]
  TABLE_META = {};

  const c = await pool.connect();
  try {
    await c.query('begin');
    await c.query('drop schema if exists portal cascade');
    await c.query('create schema portal');

    for (const t of tables) {
      const tableName = t.name;
      const schemaFields = rb[tableName].schema;
      const rows = rb[tableName].data || [];

      const fkFields = schemaFields
        .filter((f) => f.type === 'relationship' && f.RelatedTo)
        .map((f) => ({ field: f.name, relatedTo: f.RelatedTo }));

      TABLE_META[tableName] = { fields: schemaFields, fkFields, rowCount: rows.length };

      // Build CREATE TABLE. Every schema field becomes a column (raw,
      // calculated, lookup, relationship, aggregation — all of them). This is
      // a read-only display projection, not a normalized FK model, so no
      // real foreign-key constraints — soft references only (see note below).
      const cols = schemaFields.map((f) => `${colIdent(f.name)} ${pgType(f.datatype)}`);
      // Name is the logical PK per ERB convention; keep it as a plain unique
      // text column rather than a hard PK constraint, since a malformed
      // rulebook could in principle have a dup — we want to SHOW that, not
      // fail to boot.
      const createSql = `create table ${tableIdent(tableName)} (\n  ${cols.join(',\n  ')}\n)`;
      await c.query(createSql);

      if (rows.length) {
        const colNames = schemaFields.map((f) => colIdent(f.name));
        const placeholders = colNames.map((_, i) => `$${i + 1}`).join(',');
        const insertSql = `insert into ${tableIdent(tableName)} (${colNames.join(',')}) values (${placeholders})`;
        for (const rawRow of rows) {
          // `calculated` fields (notably the `Name` logical PK) are derived,
          // not stored — materialize them from same-row formulas before insert.
          const row = materializeCalculatedFields(schemaFields, rawRow);
          const vals = schemaFields.map((f) => coerceCell(row[f.name], f.datatype));
          await c.query(insertSql, vals);
        }
      }
    }

    // ---- SPECIAL CASE: drift detection for SkillBodies ----
    if (TABLE_META.SkillBodies) {
      await c.query(`alter table ${tableIdent('SkillBodies')} add column if not exists drifted boolean`);
      await c.query(`alter table ${tableIdent('SkillBodies')} add column if not exists drift_reason text`);
      const { rows: bodyRows } = await c.query(
        `select name, path, full_text from ${tableIdent('SkillBodies')}`,
      );
      for (const row of bodyRows) {
        const { drifted, reason } = computeDrift(row.path, row.full_text);
        await c.query(
          `update ${tableIdent('SkillBodies')} set drifted=$1, drift_reason=$2 where name=$3`,
          [drifted, reason, row.name],
        );
      }
    }

    await c.query('commit');
  } catch (e) {
    await c.query('rollback');
    throw e;
  } finally {
    c.release();
  }
}

function computeDrift(relPath, snapshotText) {
  if (!relPath) return { drifted: true, reason: 'missing_path' };
  const abs = join(REPO_ROOT, relPath);
  if (!existsSync(abs)) return { drifted: true, reason: 'missing_file' };
  let live;
  try {
    live = readFileSync(abs, 'utf8');
  } catch {
    return { drifted: true, reason: 'missing_file' };
  }
  if (live === snapshotText) return { drifted: false, reason: null };
  return { drifted: true, reason: 'content_changed' };
}

// ---- generic read API -----------------------------------------------------

export async function listTableSummaries() {
  return Object.entries(TABLE_META).map(([name, meta]) => ({
    name,
    fields: meta.fields.length,
    rows: meta.rowCount,
  }));
}

// Resolve a relationship-typed field's value to a display label from the
// target table's Name column (soft — null if dangling, never throws).
async function resolveLabel(targetTable, nameValue) {
  if (nameValue == null) return null;
  const meta = TABLE_META[targetTable];
  if (!meta) return null;
  try {
    const { rows } = await pool.query(
      `select name from ${tableIdent(targetTable)} where name = $1 limit 1`,
      [String(nameValue)],
    );
    return rows.length ? rows[0].name : null;
  } catch {
    return null;
  }
}

// Full schema + all rows for a table, with relationship fields resolved to a
// display label (`<field>__fk_label` — double-underscore to avoid colliding
// with a real `<Field>Label` lookup column the rulebook may already define,
// e.g. Skills.CategoryLabel) alongside the raw value.
export async function getTableRows(tableName) {
  const meta = TABLE_META[tableName];
  if (!meta) return null;
  const { rows } = await pool.query(`select * from ${tableIdent(tableName)}`);

  for (const row of rows) {
    for (const fk of meta.fkFields) {
      const col = colIdent(fk.field);
      row[col + '__fk_label'] = await resolveLabel(fk.relatedTo, row[col]);
    }
  }
  return { fields: meta.fields, fkFields: meta.fkFields, rows };
}

export async function getRow(tableName, name) {
  const meta = TABLE_META[tableName];
  if (!meta) return null;
  const { rows } = await pool.query(
    `select * from ${tableIdent(tableName)} where name = $1 limit 1`,
    [name],
  );
  if (!rows.length) return null;
  const row = rows[0];
  for (const fk of meta.fkFields) {
    const col = colIdent(fk.field);
    row[col + '_label'] = await resolveLabel(fk.relatedTo, row[col]);
  }
  return { fields: meta.fields, fkFields: meta.fkFields, row };
}

// Global dangling-FK report across every table's relationship fields —
// generalized version of the old Skills-only `integrity()`.
export async function integrity() {
  const issues = [];
  for (const [tableName, meta] of Object.entries(TABLE_META)) {
    if (!meta.fkFields.length) continue;
    const { rows } = await pool.query(`select * from ${tableIdent(tableName)}`);
    for (const row of rows) {
      for (const fk of meta.fkFields) {
        const col = colIdent(fk.field);
        const val = row[col];
        if (val == null || val === '') continue;
        const label = await resolveLabel(fk.relatedTo, val);
        if (label == null) {
          issues.push({
            table: tableName,
            row: row.name,
            field: fk.field,
            relatedTo: fk.relatedTo,
            danglingValue: val,
          });
        }
      }
    }
  }
  return issues;
}

export async function driftSummary() {
  if (!TABLE_META.SkillBodies) return [];
  const { rows } = await pool.query(
    `select name, path, drifted, drift_reason from ${tableIdent('SkillBodies')} order by name`,
  );
  return rows;
}
