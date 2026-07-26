#!/usr/bin/env node
// Deterministic SKILL.min.md generator.
//
// Source of truth: effortless-rulebook/effortless-rulebook.json (Skills, Concepts,
// ConceptSkills, Gotchas, GotchaSkills, SkillArtifacts, ConceptCategories).
// Output: skills/<slug>/SKILL.min.md — a real, standalone, drop-in SKILL.md
// (valid frontmatter incl. description:, so Claude Code's routing can discover it).
//
// No LLM calls. No network. Pure data assembly — same rulebook in, same files out.

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const RULEBOOK_PATH = path.join(REPO_ROOT, 'effortless-rulebook/effortless-rulebook.json');

function erbSlug(label) {
  return label.toLowerCase().replace(/ /g, '-');
}

function loadRulebook() {
  return JSON.parse(readFileSync(RULEBOOK_PATH, 'utf8'));
}

function indexBy(rows, keyFn) {
  const m = new Map();
  for (const r of rows) m.set(keyFn(r), r);
  return m;
}

function groupBy(rows, keyFn) {
  const m = new Map();
  for (const r of rows) {
    const k = keyFn(r);
    if (!m.has(k)) m.set(k, []);
    m.get(k).push(r);
  }
  return m;
}

// Wraps YAML frontmatter description the same way hand-authored SKILL.md files do:
// a `description: >` folded block, blank-line-separated paragraphs, 2-space indent.
function yamlFoldedBlock(paragraphs, indent = '  ') {
  const wrapped = paragraphs.map((p) => wrapText(p, 78, indent));
  return wrapped.join('\n' + indent + '\n');
}

function wrapText(text, width, indent) {
  const words = text.split(/\s+/);
  const lines = [];
  let line = '';
  for (const w of words) {
    if ((line + ' ' + w).trim().length > width) {
      lines.push(line.trim());
      line = w;
    } else {
      line = (line + ' ' + w).trim();
    }
  }
  if (line) lines.push(line.trim());
  return lines.map((l) => indent + l).join('\n');
}

function buildDescription(skill, scopeGateType) {
  const paragraphs = [skill.Description];
  if (scopeGateType) {
    paragraphs.push(`**Scope (load gate):** ${scopeGateType.Description}`);
  }
  return paragraphs;
}

function buildFrontmatter(skill, scopeGateType, audienceLabel, deprecatedNames) {
  const lines = ['---', `name: ${skill.Slug}`, 'description: >'];
  lines.push(yamlFoldedBlock(buildDescription(skill, scopeGateType)));
  if (audienceLabel) lines.push(`audience: ${audienceLabel}`);
  if (deprecatedNames && deprecatedNames.length) {
    lines.push('deprecated_skill_names:');
    for (const n of deprecatedNames) lines.push(`  - ${n}`);
  }
  lines.push('---');
  return lines.join('\n');
}

function buildConceptsSection(concepts, conceptCategoriesById) {
  if (!concepts.length) return '';
  const byCategory = groupBy(concepts, (c) => c.Category);
  const orderedCats = [...byCategory.keys()].sort((a, b) => {
    const sa = conceptCategoriesById.get(a)?.SortOrder ?? 999;
    const sb = conceptCategoriesById.get(b)?.SortOrder ?? 999;
    return sa - sb;
  });
  const parts = ['## Concepts', ''];
  for (const catSlug of orderedCats) {
    const cat = conceptCategoriesById.get(catSlug);
    const label = cat ? cat.CategoryLabel : catSlug;
    parts.push(`**${label}**`);
    for (const c of byCategory.get(catSlug)) {
      parts.push(`- **${c.ConceptLabel}** — ${c.Description}`);
    }
  }
  return parts.join('\n');
}

function buildGotchasSection(gotchas) {
  if (!gotchas.length) return '';
  // critical first, then moderate; stable within each by Title
  const sevRank = { critical: 0, moderate: 1 };
  const sorted = [...gotchas].sort((a, b) => {
    const r = (sevRank[a.Severity] ?? 9) - (sevRank[b.Severity] ?? 9);
    if (r !== 0) return r;
    return a.Title.localeCompare(b.Title);
  });
  const parts = ['## Gotchas', ''];
  for (const g of sorted) {
    const tag = g.Severity === 'critical' ? '[CRITICAL]' : '[moderate]';
    parts.push(`- **${tag} ${g.Title}** — looks right: ${g.LooksRight} → actual fix: ${g.ActualFix}`);
  }
  return parts.join('\n');
}

function buildArtifactsSection(artifacts) {
  if (!artifacts.length) return '';
  const parts = ['## Further Reading', ''];
  for (const a of artifacts) {
    parts.push(`- **${a.Filename}** — ${a.Summary} (\`${a.Path}\`)`);
  }
  return parts.join('\n');
}

function buildSeeAlsoSection(skill) {
  // Deterministic placeholder: point back at the full skill body, since that's
  // always a safe, always-correct "more depth" pointer regardless of skill.
  return [
    '## See Also',
    '',
    `- Full reference: \`skills/${skill.Slug}/SKILL.md\``,
  ].join('\n');
}

function generateSkillMinMd(skill, ctx) {
  const {
    scopeGateTypesByName,
    audiencesByName,
    conceptsBySkill,
    gotchasBySkill,
    conceptCategoriesById,
    artifactsBySkill,
  } = ctx;

  const scopeGateType = scopeGateTypesByName.get(skill.ScopeGate);
  const audience = audiencesByName.get(skill.Audience);
  const audienceLabel = audience ? audience.AudienceLabel : undefined;

  const frontmatter = buildFrontmatter(skill, scopeGateType, audienceLabel, []);

  const concepts = conceptsBySkill.get(skill.Slug) || [];
  const gotchas = gotchasBySkill.get(skill.Slug) || [];
  const artifacts = artifactsBySkill.get(skill.Slug) || [];

  const sections = [
    `# ${skill.Slug}`,
    '',
    skill.Description,
    '',
    buildConceptsSection(concepts, conceptCategoriesById),
    '',
    buildGotchasSection(gotchas),
    '',
    buildArtifactsSection(artifacts),
    '',
    buildSeeAlsoSection(skill),
  ].filter((s) => s !== '' || true); // keep structure; blank-line collapse happens below

  const body = sections.join('\n').replace(/\n{3,}/g, '\n\n').trim();

  return frontmatter + '\n\n' + body + '\n';
}

function main() {
  const rb = loadRulebook();

  const skills = rb.Skills.data;
  const concepts = rb.Concepts.data.map((c) => ({ ...c, __slug: erbSlug(c.ConceptLabel) }));
  const conceptsBySlug = indexBy(concepts, (c) => c.__slug);
  const conceptCategoriesById = indexBy(rb.ConceptCategories.data, (c) => erbSlug(c.CategoryLabel));

  const conceptSkillLinks = rb.ConceptSkills.data;
  const conceptsBySkill = new Map();
  for (const link of conceptSkillLinks) {
    const concept = conceptsBySlug.get(link.Concept);
    if (!concept) {
      console.error(`WARN: ConceptSkills row references unknown concept slug "${link.Concept}" (skill ${link.Skill})`);
      continue;
    }
    if (!conceptsBySkill.has(link.Skill)) conceptsBySkill.set(link.Skill, []);
    conceptsBySkill.get(link.Skill).push(concept);
  }

  const gotchas = rb.Gotchas.data.map((g) => ({ ...g, __slug: erbSlug(g.GotchaKey) }));
  const gotchasBySlug = indexBy(gotchas, (g) => g.__slug);
  const gotchaSkillLinks = rb.GotchaSkills.data;
  const gotchasBySkill = new Map();
  for (const link of gotchaSkillLinks) {
    const gotcha = gotchasBySlug.get(link.Gotcha);
    if (!gotcha) {
      console.error(`WARN: GotchaSkills row references unknown gotcha slug "${link.Gotcha}" (skill ${link.Skill})`);
      continue;
    }
    if (!gotchasBySkill.has(link.Skill)) gotchasBySkill.set(link.Skill, []);
    gotchasBySkill.get(link.Skill).push(gotcha);
  }

  const artifactsBySkill = groupBy(rb.SkillArtifacts.data, (a) => a.Skill);

  const scopeGateTypesByName = indexBy(rb.ScopeGateTypes.data, (s) => erbSlug(s.GateLabel));
  const audiencesByName = indexBy(rb.Audiences.data, (a) => erbSlug(a.AudienceLabel));

  const ctx = {
    scopeGateTypesByName,
    audiencesByName,
    conceptsBySkill,
    gotchasBySkill,
    conceptCategoriesById,
    artifactsBySkill,
  };

  let written = 0;
  for (const skill of skills) {
    const dir = path.join(REPO_ROOT, 'skills', skill.Slug);
    if (!existsSync(dir)) {
      console.error(`WARN: no skills/${skill.Slug}/ directory — skipping`);
      continue;
    }
    const md = generateSkillMinMd(skill, ctx);
    writeFileSync(path.join(dir, 'SKILL.min.md'), md, 'utf8');
    written++;
  }

  console.log(`Generated ${written} SKILL.min.md file(s) from ${RULEBOOK_PATH}`);
}

main();
