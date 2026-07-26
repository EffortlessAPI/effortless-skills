// rulebook.js — read-only access to the hub.
//
// Reads effortless-rulebook.json and rulespeak/rulespeak.md. This portal pass
// is READ-ONLY: there is no write-back path here (see CLAUDE.md — the rulebook
// is edited directly or via Airtable, never through this portal).

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

// Two levels up from portal/server/ -> repo root when run on the host.
// In the container, the repo's effortless-rulebook/, skills/, and rulespeak/
// dirs are bind-mounted read-only at /repo instead (see ../docker-compose.yml)
// — REPO_ROOT can be overridden via env for that case.
export const REPO_ROOT = process.env.REPO_ROOT || join(import.meta.dirname, '..', '..');
const RB_PATH = join(REPO_ROOT, 'effortless-rulebook', 'effortless-rulebook.json');
const RULESPEAK_PATH = join(REPO_ROOT, 'rulespeak', 'rulespeak.md');

export function readRulebook() {
  return JSON.parse(readFileSync(RB_PATH, 'utf8'));
}

export function readRulespeak() {
  return readFileSync(RULESPEAK_PATH, 'utf8');
}

// Sections that are NOT domain tables (skip when listing tables).
const NON_TABLE_KEYS = new Set(['$schema', 'Name', 'Description', '_meta']);

// A "table" is any top-level object with a `schema` array and `data` array.
export function listTables(rb) {
  return Object.keys(rb)
    .filter((k) => !NON_TABLE_KEYS.has(k) && rb[k] && Array.isArray(rb[k].schema))
    .map((name) => ({
      name,
      description: rb[name].Description || '',
      fields: rb[name].schema.length,
      rows: (rb[name].data || []).length,
    }));
}
