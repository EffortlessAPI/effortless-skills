# 📘 Effortless Claude — RuleSpeak

_Self-describing rulebook for the effortless-claude skill suite. The skills repo modeled with its own methodology — each skill is a row, each high-level attribute (category, scope gate, audience) is a parent table._

> Declarative business rules rendered from the rulebook. Every statement
> below expresses truth in the business domain — it is neither a procedure
> nor an imperative. The rulebook's formulas are the single source of truth;
> this document is their plain-language reading.

## 1 Business Vocabulary

| Term | Description | Narrative Comment |
|------|-------------|-------------------|
| **Audience** | Intended consumer of a skill's behavior. customer = end users of the suite; general = applicable beyond marked Effortless projects. | — |
| Name | Computed as the lower-cased audience label with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> | _Logical PK — kebab-cased audience label._ |
| Count of Skills | The number of skills related to the audience. | _How many skills declare this audience._ |
| **Skill Category** | Functional grouping of skills as presented in the README. Categories are presentation/discovery groupings, not load-gate semantics (that's ScopeGateTypes). | — |
| Name | Computed as the lower-cased category label with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> | _Logical PK — kebab-cased category label._ |
| Count of Skills | The number of skills related to the skill category. | _How many skills are in this category._ |
| **Scope Gate Type** | When the harness loads a skill into context. The four patterns referenced in the skill-writing conventions (project-only / entry-point / tooling / theory). | — |
| Name | Computed as the lower-cased gate label with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> | _Logical PK — kebab-cased gate label._ |
| Count of Skills | The number of skills related to the scope gate type. | _How many skills use this gate pattern._ |
| **Skill** | One row per SKILL.md under skills/. The 23 currently live skills in the suite. Deprecation history is in DEPRECATED_SKILLS.md, not here. | — |
| Name | Computed as the lower-cased slug with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> | _Logical PK — equals the kebab-cased Slug, which equals the directory name._ |
| Directory Path | Computed as “skills/”, followed by the slug, followed by a slash. | _Filesystem path to the skill directory, relative to repo root._ |
| Category Label | Taken from the linked category. | _Display label of the parent category._ |
| Scope Gate Label | Taken from the linked scope gate. | _Display label of the parent scope-gate type._ |
| Audience Label | Taken from the linked audience. | _Display label of the parent audience._ |
| **Concept Category** | Thematic grouping of cross-skill concepts (analogous to SkillCategories, but for Concepts). | — |
| Name | Computed as the lower-cased category label with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> | _Logical PK — kebab-cased category label._ |
| Count of Concepts | The number of concepts related to the concept category. | _How many concepts are in this category._ |
| **Concept** | Cross-skill vocabulary extracted from surveying all skills/*/SKILL.md — named ideas/terms that recur across multiple skills and that a newcomer needs defined to understand ERB. Hand-authored, not derived from Airtable. | — |
| Name | Computed as the lower-cased concept label with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> | _Logical PK — kebab-cased ConceptLabel._ |
| **Concept Skill** | Junction table: which skill(s) each Concept is most central to. A many-to-many between Concepts and Skills modeled as two 1-to-many FKs, per ERB DAG conventions. | — |
| Name | Computed as the concept, followed by “::”, followed by the skill. | _Logical PK — Concept + Skill composite._ |
| **Gotcha** | Specific anti-patterns per skill — what the plausible-but-wrong approach looks like and what the actual fix is. Extracted from each SKILL.md's explicit warnings; distinct from Concepts (definitions) — these are traps. | — |
| Name | Computed as the lower-cased gotcha key with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> | _Logical PK — kebab-cased GotchaKey._ |
| **Gotcha Skill** | Junction table: which skill(s) each Gotcha applies to. A many-to-many between Gotchas and Skills modeled as two 1-to-many FKs, per ERB DAG conventions. | — |
| Name | Computed as the gotcha, followed by “::”, followed by the skill. | _Logical PK — Gotcha + Skill composite._ |
| **Skill Body** | Point-in-time SNAPSHOT of each SKILL.md file, captured for the read-only rulebook portal's drift display. SKILL.md remains the hand-authored SSoT (see project CLAUDE.md) — FullText here is NOT a generation source, it is what the file looked like as of the last snapshot. The portal compares this byte-for-byte against the live file to show when a skill has drifted from its last-known-good rulebook snapshot. | — |
| Name | The same as its skill. | _Logical PK — equals Skill._ |
| **Skill Artifact** | Hand-maintained reference/subtask docs that go deeper than a compressed skill body can hold — optional, freeform naming, referenced by a Concepts.Description 'See <topic>' pointer or directly by a skill. Tracked here so the rulebook stays the single source of truth end-to-end, even for material that isn't generated. | — |
| Name | Computed as the skill, followed by “::”, followed by the filename. | _Logical PK — Skill + Filename composite._ |
| Path | Computed as “skills/”, followed by the skill, followed by a slash, followed by the filename. | _Repo-relative path, conventionally under the skill's directory._ |

## 2 Fact Types

- a **skill** references exactly one **skill category**
- a **skill** references exactly one **scope gate type**
- a **skill** references exactly one **audience**
- a **concept** references exactly one **concept category**
- a **concept skill** references exactly one **concept**
- a **concept skill** references exactly one **skill**
- a **gotcha skill** references exactly one **gotcha**
- a **gotcha skill** references exactly one **skill**
- a **skill body** references exactly one **skill**
- a **skill artifact** references exactly one **skill**

## 3 Operative Rules

_Operative rules state what the business **obliges**, **prohibits**, or
advises (**should**). Structural rules come from required fields and foreign keys;
semantic rules come from the Constraints table, each keyed on a boolean the rulebook
already computes (cross-referenced as DR-N in the Definitional Rules below)._

### Structural Constraints (from the schema)

- An audience **must** have an audience label and a description.
- A skill category **must** have a category label, a description, and a sort order.
- A scope gate type **must** have a gate label and a description, and record whether it requires marker and whether it is loads on explicit request.
- A skill **must** reference exactly one skill category as its category.
- A skill **must** reference exactly one scope gate type as its scope gate.
- A skill **must** reference exactly one audience.
- A skill **must** have a slug, a description, and a why it exists.
- A concept category **must** have a category label, a description, and a sort order.
- A concept **must** reference exactly one concept category as its category.
- A concept **must** have a concept label and a description.
- A concept skill **must** reference exactly one concept.
- A concept skill **must** reference exactly one skill.
- A gotcha **must** have a gotcha key, a title, a looks right, an actual fix, and a severity.
- A gotcha skill **must** reference exactly one gotcha.
- A gotcha skill **must** reference exactly one skill.
- A skill body **must** reference exactly one skill.
- A skill body **must** have a path, a full text, a bytes, and a lines.
- A skill artifact **must** reference exactly one skill.
- A skill artifact **must** have a filename and a summary.

## 4 Definitional Rules

_All statements express truth in the business domain; they are neither
procedures nor imperatives. "iff" is avoided in favor of "only if" so a
one-directional necessity is not mistaken for an equivalence. A
**⚠︎ mechanical** chip marks a rule whose deterministic wording is faithful
but clunky — a flag for an optional downstream reword pass, not a defect._

| ID | Declarative rule |
|----|------------------|
| **DR-1 Name** | An audience's name is computed as the lower-cased audience label with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> |
| **DR-2 Count of Skills** | An audience's count of skills is the number of skills related to the audience. |
| **DR-3 Name** | A skill category's name is computed as the lower-cased category label with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> |
| **DR-4 Count of Skills** | A skill category's count of skills is the number of skills related to the skill category. |
| **DR-5 Name** | A scope gate type's name is computed as the lower-cased gate label with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> |
| **DR-6 Count of Skills** | A scope gate type's count of skills is the number of skills related to the scope gate type. |
| **DR-7 Name** | A skill's name is computed as the lower-cased slug with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> |
| **DR-8 Directory Path** | A skill's directory path is computed as “skills/”, followed by the slug, followed by a slash. |
| **DR-9 Category Label** | A skill's category label — taken from the linked category. |
| **DR-10 Scope Gate Label** | A skill's scope gate label — taken from the linked scope gate. |
| **DR-11 Audience Label** | A skill's audience label — taken from the linked audience. |
| **DR-12 Name** | A concept category's name is computed as the lower-cased category label with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> |
| **DR-13 Count of Concepts** | A concept category's count of concepts is the number of concepts related to the concept category. |
| **DR-14 Name** | A concept's name is computed as the lower-cased concept label with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> |
| **DR-15 Name** | A concept skill's name is computed as the concept, followed by “::”, followed by the skill. |
| **DR-16 Name** | A gotcha's name is computed as the lower-cased gotcha key with every a space replaced by a hyphen. ⚠︎ mechanical <!-- rulespeak:reword --> |
| **DR-17 Name** | A gotcha skill's name is computed as the gotcha, followed by “::”, followed by the skill. |
| **DR-18 Name** | A skill body's name is the same as its skill. |
| **DR-19 Name** | A skill artifact's name is computed as the skill, followed by “::”, followed by the filename. |
| **DR-20 Path** | A skill artifact's path is computed as “skills/”, followed by the skill, followed by a slash, followed by the filename. |

## 5 Traceability to Schema

_The expression column is the rule's definition in RuleSpeak notation —
the same logic the rulebook stores, written for a business reader._

| Schema element | Kind | Expression |
|----------------|------|------------|
| **Audiences.Name** | formula | `Replace(Lower(AudienceLabel), " ", "-")` |
| **Audiences.CountOfSkills** | rollup | `Count(Skills via Audience)` |
| **SkillCategories.Name** | formula | `Replace(Lower(CategoryLabel), " ", "-")` |
| **SkillCategories.CountOfSkills** | rollup | `Count(Skills via Category)` |
| **ScopeGateTypes.Name** | formula | `Replace(Lower(GateLabel), " ", "-")` |
| **ScopeGateTypes.CountOfSkills** | rollup | `Count(Skills via ScopeGate)` |
| **Skills.Name** | formula | `Replace(Lower(Slug), " ", "-")` |
| **Skills.DirectoryPath** | formula | `"skills/" & Slug & "/"` |
| **Skills.CategoryLabel** | lookup | `Lookup(SkillCategories.CategoryLabel via Category)` |
| **Skills.ScopeGateLabel** | lookup | `Lookup(ScopeGateTypes.GateLabel via ScopeGate)` |
| **Skills.AudienceLabel** | lookup | `Lookup(Audiences.AudienceLabel via Audience)` |
| **ConceptCategories.Name** | formula | `Replace(Lower(CategoryLabel), " ", "-")` |
| **ConceptCategories.CountOfConcepts** | rollup | `Count(Concepts via Category)` |
| **Concepts.Name** | formula | `Replace(Lower(ConceptLabel), " ", "-")` |
| **ConceptSkills.Name** | formula | `Concat(Concept, "::", Skill)` |
| **Gotchas.Name** | formula | `Replace(Lower(GotchaKey), " ", "-")` |
| **GotchaSkills.Name** | formula | `Concat(Gotcha, "::", Skill)` |
| **SkillBodies.Name** | formula | `Skill` |
| **SkillArtifacts.Name** | formula | `Concat(Skill, "::", Filename)` |
| **SkillArtifacts.Path** | formula | `"skills/" & Skill & "/" & Filename` |

---

_This document is rendered in **RuleSpeak®**, the declarative business-rule
notation created by **Ronald G. Ross**, and follows the conventions of
**SBVR** (Semantics of Business Vocabulary and Business Rules). With thanks to
Ronald G. Ross for RuleSpeak and his foundational work on business rules —
[www.RonRoss.info](https://www.RonRoss.info)._
