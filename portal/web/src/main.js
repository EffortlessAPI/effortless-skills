import { md } from './md.js';

const app = document.getElementById('app');

// view: { kind: 'home' } | { kind: 'table', name } | { kind: 'row', table, name }
//     | { kind: 'drift' } | { kind: 'rulespeak' }
let view = { kind: 'home' };
let S = null; // /api/state
let tableCache = {}; // tableName -> { fields, fkFields, rows }
let rulespeakText = null;

async function api(path) {
  const r = await fetch('/api' + path);
  if (!r.ok) throw new Error((await r.json().catch(() => ({}))).error || r.statusText);
  return r.json();
}

function nav(next) {
  view = next;
  render();
}

async function boot() {
  app.innerHTML = `<div class="boot">seeding scratch Postgres from the rulebook…</div>`;
  try {
    S = await api('/state');
    render();
  } catch (e) {
    app.innerHTML = `<div class="boot">portal API not reachable.<br><small>${e.message}</small><br>
      <small>start it with: cd portal &amp;&amp; docker compose up --build</small></div>`;
  }
}

function render() {
  app.innerHTML = `
    <div class="topbar">
      <div class="brand"><span class="dot"></span>Rulebook Portal<small>${S.rulebookName}</small></div>
      <span class="db-chip"><span class="pg"></span>read-only · ephemeral pg</span>
      ${
        S.integrity.count
          ? `<span class="db-chip integrity" id="integrityChip" title="Dangling foreign-key references in the rulebook">⚠ ${S.integrity.count} integrity ${S.integrity.count === 1 ? 'issue' : 'issues'}</span>`
          : ''
      }
      ${
        S.drift.driftedCount
          ? `<span class="db-chip integrity" id="driftChip" title="SKILL.md files that no longer match the SkillBodies snapshot">⚠ ${S.drift.driftedCount} drifted</span>`
          : `<span class="db-chip" id="driftChip" style="cursor:pointer" title="Drift view">✓ in sync</span>`
      }
      <div class="spacer"></div>
      <nav class="topnav">
        <button data-nav="home" aria-pressed="${view.kind === 'home'}">Tables</button>
        <button data-nav="drift" aria-pressed="${view.kind === 'drift'}">Drift</button>
        <button data-nav="rulespeak" aria-pressed="${view.kind === 'rulespeak'}">RuleSpeak</button>
      </nav>
      <button class="theme" id="themeBtn" title="Toggle theme">◐</button>
    </div>
    <div class="shell">
      <aside class="rail">
        <div class="rail-search"><div class="rail-meta" id="tableList"></div></div>
      </aside>
      <main class="inspector" id="inspector"></main>
    </div>`;

  app.querySelector('#themeBtn').onclick = toggleTheme;
  app.querySelectorAll('[data-nav]').forEach((b) => {
    b.onclick = () => nav({ kind: b.dataset.nav });
  });
  const ichip = app.querySelector('#integrityChip');
  if (ichip) ichip.onclick = () => nav({ kind: 'home' });
  const dchip = app.querySelector('#driftChip');
  if (dchip) dchip.onclick = () => nav({ kind: 'drift' });

  renderRail();
  renderInspector();
}

function renderRail() {
  const list = app.querySelector('#tableList');
  list.innerHTML = '';
  const head = document.createElement('div');
  head.className = 'cat-head';
  head.innerHTML = `<span>Tables</span><span class="c">${S.tables.length}</span>`;
  list.appendChild(head);
  for (const t of S.tables) {
    const r = document.createElement('div');
    r.className = 'srow' + (view.kind === 'table' && view.name === t.name ? ' active' : '');
    r.innerHTML = `<span class="state"></span>
      <span class="nm">${t.name}</span>
      <span class="gate-tag">${t.rows}</span>`;
    r.onclick = () => nav({ kind: 'table', name: t.name });
    list.appendChild(r);
  }
}

async function ensureTable(name) {
  if (!tableCache[name]) tableCache[name] = await api(`/tables/${name}`);
  return tableCache[name];
}

function esc(s) {
  return String(s ?? '').replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
}

function cellValue(v) {
  if (v == null) return '<span class="v-null">—</span>';
  if (typeof v === 'boolean') return v ? '<span class="v-bool true">true</span>' : '<span class="v-bool">false</span>';
  const s = String(v);
  if (s.length > 140) return esc(s.slice(0, 140)) + '…';
  return esc(s);
}

async function renderInspector() {
  const insp = app.querySelector('#inspector');

  if (view.kind === 'home') {
    insp.innerHTML = `<div class="insp-inner">
      <div class="crumb">${S.rulebookName}</div>
      <div class="h-title"><h1>${esc(S.rulebookName)}</h1></div>
      <p class="lead">${esc(S.rulebookDescription || '')}</p>
      <div class="sect-label">Tables<span class="meta">${S.tables.length} tables</span></div>
      <div class="table-grid">
        ${S.tables
          .map(
            (t) => `<div class="table-card" data-goto="${t.name}">
              <div class="tc-name">${t.name}</div>
              <div class="tc-desc">${esc(t.description)}</div>
              <div class="tc-meta"><span>${t.fields} fields</span><span>${t.rows} rows</span></div>
            </div>`,
          )
          .join('')}
      </div>
      ${
        S.integrity.count
          ? `<div class="sect-label">Integrity issues<span class="meta">${S.integrity.count} dangling references</span></div>
             <div class="issue-list">
               ${S.integrity.issues
                 .map(
                   (i) =>
                     `<div class="issue-row"><span class="badge dirty">⚠</span>
                      <code>${i.table}.${i.field}</code> on row <code>${esc(i.row)}</code>
                      points at <code>${i.relatedTo}</code> value <code>${esc(i.danglingValue)}</code> — no such row.</div>`,
                 )
                 .join('')}
             </div>`
          : ''
      }
    </div>`;
    insp.querySelectorAll('[data-goto]').forEach((el) => {
      el.onclick = () => nav({ kind: 'table', name: el.dataset.goto });
    });
    return;
  }

  if (view.kind === 'table') {
    insp.innerHTML = `<div class="insp-inner"><div class="boot" style="height:200px">loading ${esc(view.name)}…</div></div>`;
    let data;
    try {
      data = await ensureTable(view.name);
    } catch (e) {
      insp.innerHTML = `<div class="insp-inner"><div class="boot">failed to load table.<br><small>${esc(e.message)}</small></div></div>`;
      return;
    }
    const fields = data.fields;
    insp.innerHTML = `<div class="insp-inner">
      <div class="crumb">${S.rulebookName} <span class="sep">/</span> Tables <span class="sep">/</span> ${view.name}</div>
      <div class="h-title"><h1>${view.name}</h1><span class="badge clean">${data.rows.length} rows</span></div>
      <div class="tablewrap">
        <table class="data-table">
          <thead><tr>${fields.map((f) => `<th>${f.name}<span class="ftype">${f.type}</span></th>`).join('')}</tr></thead>
          <tbody>
            ${data.rows
              .map((row) => {
                const cells = fields
                  .map((f) => {
                    const col = f.name
                      .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
                      .replace(/[^a-zA-Z0-9]+/g, '_')
                      .toLowerCase()
                      .replace(/^_+|_+$/g, '');
                    const val = row[col];
                    if (f.type === 'relationship') {
                      const label = row[col + '__fk_label'];
                      if (val == null) return `<td>${cellValue(null)}</td>`;
                      return `<td>${
                        label != null
                          ? `<a class="fk-link" data-table="${f.RelatedTo}" data-row="${esc(val)}">${esc(label)}</a>`
                          : `<span class="v-dangling" title="dangling reference">⚠ ${esc(val)}</span>`
                      }</td>`;
                    }
                    if (col === 'name') {
                      return `<td><a class="fk-link" data-table="${view.name}" data-row="${esc(val)}">${esc(val)}</a></td>`;
                    }
                    return `<td>${cellValue(val)}</td>`;
                  })
                  .join('');
                return `<tr>${cells}</tr>`;
              })
              .join('')}
          </tbody>
        </table>
      </div>
    </div>`;
    wireFkLinks(insp);
    return;
  }

  if (view.kind === 'row') {
    insp.innerHTML = `<div class="insp-inner"><div class="boot" style="height:200px">loading…</div></div>`;
    let detail;
    try {
      detail = await api(`/tables/${view.table}/rows/${encodeURIComponent(view.name)}`);
    } catch (e) {
      insp.innerHTML = `<div class="insp-inner"><div class="boot">not found.<br><small>${esc(e.message)}</small></div></div>`;
      return;
    }
    const row = detail.row;
    const fields = detail.fields;
    insp.innerHTML = `<div class="insp-inner">
      <div class="crumb">${S.rulebookName} <span class="sep">/</span>
        <a class="crumb-link" data-table="${view.table}">${view.table}</a> <span class="sep">/</span> ${esc(view.name)}</div>
      <div class="h-title"><h1>${esc(view.name)}</h1></div>
      <div class="fields">
        ${fields
          .map((f) => {
            const col = f.name
              .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
              .replace(/[^a-zA-Z0-9]+/g, '_')
              .toLowerCase()
              .replace(/^_+|_+$/g, '');
            const val = row[col];
            let vhtml;
            if (f.type === 'relationship') {
              const label = row[col + '__fk_label'];
              vhtml =
                val == null
                  ? cellValue(null)
                  : label != null
                    ? `<a class="fk-link" data-table="${f.RelatedTo}" data-row="${esc(val)}">${esc(label)} <span class="fk">→ ${f.RelatedTo}</span></a>`
                    : `<span class="v-dangling">⚠ ${esc(val)} (no such row in ${f.RelatedTo})</span>`;
            } else {
              vhtml = `<div class="v mono">${cellValue(val)}</div>`;
            }
            return `<div class="field full"><div class="k">${f.name} <span class="fk">${f.type} · ${f.datatype}</span></div><div class="v">${vhtml}</div>
              ${f.Description ? `<div class="hint">${esc(f.Description)}</div>` : ''}</div>`;
          })
          .join('')}
      </div>
      ${view.table === 'SkillBodies' ? renderBodyPreview(row) : ''}
    </div>`;
    wireFkLinks(insp);
    const crumbLink = insp.querySelector('.crumb-link');
    if (crumbLink) crumbLink.onclick = () => nav({ kind: 'table', name: view.table });
    return;
  }

  if (view.kind === 'drift') {
    insp.innerHTML = `<div class="insp-inner"><div class="boot" style="height:200px">loading drift report…</div></div>`;
    const drift = await api('/drift');
    insp.innerHTML = `<div class="insp-inner">
      <div class="crumb">${S.rulebookName} <span class="sep">/</span> Drift</div>
      <div class="h-title"><h1>Drift report</h1><span class="badge ${drift.some((d) => d.drifted) ? 'dirty' : 'clean'}">
        ${drift.filter((d) => d.drifted).length} / ${drift.length} drifted</span></div>
      <p class="lead">Compares each <code>SkillBodies</code> snapshot (captured at rulebook-authoring time) byte-for-byte
        against the live file on disk. This is a point-in-time check, not an editing surface.</p>
      <div class="tablewrap">
        <table class="data-table">
          <thead><tr><th>Skill</th><th>Path</th><th>Status</th></tr></thead>
          <tbody>
            ${drift
              .map(
                (d) => `<tr>
                  <td><a class="fk-link" data-table="SkillBodies" data-row="${esc(d.skill)}">${esc(d.skill)}</a></td>
                  <td class="mono">${esc(d.path)}</td>
                  <td>${
                    d.drifted
                      ? `<span class="badge drift-badge">⚠ drifted${d.drift_reason ? ' · ' + esc(d.drift_reason) : ''}</span>`
                      : `<span class="badge sync-badge">✓ in sync</span>`
                  }</td>
                </tr>`,
              )
              .join('')}
          </tbody>
        </table>
      </div>
    </div>`;
    wireFkLinks(insp);
    return;
  }

  if (view.kind === 'rulespeak') {
    insp.innerHTML = `<div class="insp-inner"><div class="boot" style="height:200px">loading rulespeak…</div></div>`;
    if (rulespeakText == null) {
      const r = await fetch('/api/rulespeak');
      rulespeakText = await r.text();
    }
    insp.innerHTML = `<div class="insp-inner">
      <div class="crumb">${S.rulebookName} <span class="sep">/</span> RuleSpeak</div>
      <div class="h-title"><h1>RuleSpeak</h1></div>
      <p class="lead">Plain-English business rules generated by <code>rulebook-to-rulespeak</code> from the hub.</p>
      <div class="bodytext prose">${md(rulespeakText)}</div>
    </div>`;
    return;
  }
}

function renderBodyPreview(row) {
  const text = row.full_text;
  if (!text) return '';
  return `<div class="sect-label">SKILL.md body<span class="meta">stored verbatim in the rulebook snapshot</span></div>
    <div class="bodywrap"><div class="bodytext prose">${md(text)}</div></div>`;
}

function wireFkLinks(root) {
  root.querySelectorAll('.fk-link').forEach((el) => {
    el.onclick = (e) => {
      e.preventDefault();
      nav({ kind: 'row', table: el.dataset.table, name: el.dataset.row });
    };
  });
}

function toggleTheme() {
  const cur = document.documentElement.getAttribute('data-theme');
  const next =
    cur === 'dark' ? 'light' : cur === 'light' ? 'dark' : matchMedia('(prefers-color-scheme: dark)').matches ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', next);
}

boot();
