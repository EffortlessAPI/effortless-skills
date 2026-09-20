---
name: effortless-video
description: >
  Make, storyboard, script, thumbnail or render an explainer VIDEO in the
  effortless-videos producer repo (reference: 15-cli-tour/06-effortless-init). Triggers:
  "make a video about X", "storyboard a video", "record the VO", "render the MP4", "add
  scene N", "change the narration", "make a thumbnail". Load before any storyboard,
  scene, or render code.
audience: general
---

# Effortless Video Producer

A video here is an Effortless project: a rulebook (`Storyboards → Acts → Scenes → Clips →
Assets`) that gets *rendered*. Producer repo: `~/development/effortless-videos`. A video lives
at `series/<series>/<video>/` and its slug is compound (`15-cli-tour/06-effortless-init`).
That repo's `CLAUDE.md` is long and binding. Read it. This skill is the method; **`REFERENCE.md`
beside it is the cookbook** (stage API, commands, traps, thumbnail recipe).

## The reference cut

**`series/15-cli-tour/06-effortless-init` (take 5) is the bar.** The owner's verdict: "every
single thing in this video was gold." Before authoring, read its `ANIMATION-SPEC.md`, skim its
`STORYBOARD.md`, and watch a few scenes. It replaced a take the owner rejected as wireframes
with no context. Everything below is what changed between those two takes.
For a short one-concept explainer, also read `series/03-effortless-demos/03-closure/ANIMATION-SPEC.md`
(land the idea in the body before naming it, counter-examples do the teaching).

## 🟥 The rulebook decides, render code renders

Add, remove, reorder or reword anything the viewer perceives by editing
`effortless-rulebook/effortless-rulebook.json`, then `effortless build`. Never hand-edit
`STORYBOARD.md`, `rulespeak/*` or `storyboard-doc/*`. Never fake a story change in `server/*`.
Each Scene carries three authored fields, and `STORYBOARD.md` prints all three:

| Field | Holds |
|---|---|
| `Purpose` | why the scene exists, what the viewer's model gains |
| `Visualization` | the shot plan: what is on screen, what moves, which spoken words each motion is keyed to |
| `Script` | spoken words ONLY. It goes to TTS verbatim |

Write `Visualization` for EVERY scene before building anything. "Go through every scene and
write a detailed visualization to go with the narration" was the owner's instruction, and it
is what stopped the shots being decorated at random.

## 1. Context first (the first 30 seconds)

The viewer knows nothing and does not know why this is on their screen. The last cut that
skipped this averaged 22 seconds of watch time.
- **Scene 1 says what the video is and makes a promise** with a stake ("I'm going to delete
  almost all of this, on purpose, and nothing will be lost").
- **Scene 2 is the problem**, shown on something ordinary (one fact written in two places, and
  one copy goes stale).
- **Scene 3 is the plan and the cast.** Every character gets a reason to exist ("the one thing
  Alice needs help with"). Only then does anyone type a command.
- Before any idea, tool or file is used, one sentence says what it is for. Start one level of
  context higher than feels necessary ("a rulebook is…", "this starter is the hello world").
- **Length is whatever the story needs.** Do not cut for time and do not pad. Tell the owner
  the real length; do not estimate low.

## 2. The script is a presenter talking to a room

- Full sentences with connective tissue ("because", "so", "which means"). Two or more
  sentences under ~8 words in a row is the headline-fragment defect, not a draft.
- **Read the screen aloud.** Say the three to five words that matter on each screen ("an I D,
  a Name, and an Introduction"), so someone listening without watching can follow.
- One recurring phrase carries the thesis. Take 5's is **"follows along"**.
- Explain every parameter the viewer can see, and do not show one the tool does not need:
  `rulebookPath` defaults to `-i`, so typing it was noise the owner cut. Signpost repetition
  ("the same dash i, the same rulebook").
- Role-first alliterative intros on first mention (Admin Alice, Developer Debbie), bare name after.
- Banned: em and en dashes, "honest(ly)", "here's the thing", "not just X, it's Y", an
  invented "they" or "the board", stage directions, speaker labels.
- Never say the running-example company or people are real, and never say they are fictional.
- The product and the company are **EffortlessAPI**. Only the typed command is `effortless`.
- A deliberate one second beat is a STANDALONE ` ... ` between sentences (the recorder splits there).

**TTS spellings for `Script`** (add new findings to this table, never only to private memory):

| Write | For | Why |
|---|---|---|
| roe | row | misread otherwise |
| Effortless A P I | EffortlessAPI | says the letters |
| A P I, I D, S Q L, X L S X | acronyms | says the letters |
| Acme | ACME | all caps is mangled |
| a noun or comma after "Effortless A P I" | "Effortless A P I watches" | the I runs into the verb ("A P, I watch") |
| period, comma, "and" | any dash | a dash is read as a Japanese syllable |
| a distinctive word for a rename | "Everyone" -> "Everybody" | too close to hear as a change; "All" reads instantly and still works |
| Dash eye | `-i` | "the i in dash i" is misread otherwise |

"Ivan" must sound like EYE-vən. Read the whisper transcript of every take that introduces a
proper noun or acronym before calling it final.

## 3. Film real artifacts, not wireframes

- **Real data.** Drive the real tool through the whole story first and snapshot every state
  (`capture_states.py`: 25 states of a scratch project). Every frame reads those captures, so
  nothing on screen is invented and nothing can disagree with the real CLI.
- **Real-looking replicas.** One HTML "desktop stage" holds a VS Code window with explorer
  icons, a terminal, a Claude Code panel with a thinking state, a browser with the admin portal
  and its boot checklist, Excel with tabs and a formula bar, a document window, and a phone
  holding real screenshots of the real built app. Model replicas on the owner's own captures.
- All JSON and SQL is syntax highlighted and always a complete, valid snapshot.
- Modern pointer, blinking caret, typing in place. No unexplained empty boxes.
- The stage is per-scene, not mandatory. PIL `draw(t)`, real screen capture and generated
  stills remain right for other beats. The contract is only a correct `.mp4` at the Asset path.

## 4. The laws of the cut

1. **The order law.** Edit in place, THEN the terminal opens, THEN the command is typed, THEN
   time visibly passes, THEN the page updates (highlighted), THEN the prompt returns, THEN the
   terminal leaves. The result always arrives before the command disappears.
2. **The same document never disappears.** A scene that shares a document with the previous
   one opens in the exact state that one ended in. No fade, no re-show. A change is an
   in-place diff of the same text, even a wholesale rename.
3. **Inserting a scene is a THREE-field renumber, and the third one is silent.** Shifting
   `SceneOrder` and `Clips.Scene` and renaming the asset files still leaves `Clips.Asset`
   pointing at the old number, so the voice moves up a scene and the picture does not: the whole
   tail of the cut plays one scene behind. Nothing else catches it. The cue audit reads word
   maps, not clips, and a still pulled from the one act whose video and voice still agree looks
   correct. After ANY renumber, assert that each scene's clip asset, its `vo-NN`, and its act's
   `src.mp4`/`vo.wav` durations all belong to that scene. `shoot.mjs` now hard-fails on this.
   Act folders are keyed on number + title slug, so a renumber orphans the old folder instead of
   replacing it; delete the strays or a stale one can be picked up later.
4. **Every later screen shows every earlier change.** Bobby, then Robert, then the professors
   appear identically in the JSON, docs, workbook, portal, SQL and app. A later screen that
   contradicts the story is a FAIL. Reading every screen from the captured states makes this free.
5. **The edited value must not already show its result** before the build runs.
6. **Commands are typed in annotated chunks** (verb, tool, input) while the narrator explains
   each, with something above the terminal that sets the expectation (a card counting "tools
   reading this rulebook").
7. **Red means exactly one thing:** a copy that is now wrong, or a file being deleted.
8. **A colour follows the THING:** blue = a fact a person typed (and every reference to it,
   `{{Name}}` included), purple = the rule's own text, green = a worked-out value or anything
   that just followed along, grey = syntax. Follow one token through every panel before shipping.
9. **Highlights are computed from the real element's rect, never hand-placed, and line numbers
   are found from the text, never counted by hand.** The one defect in take 5 was a SQL
   spotlight one row short because of a hand-counted offset. Arrows stop at the edge of a box
   and point at the actual row.
10. **A highlight lives exactly as long as the thing it points at.** An `until:` keyed to a
   later cue outlives a file switch or a page change and strands a box over empty space. When a
   scene changes document, retire that document's marks at the switch, not at the next sentence.
11. **The arrow layer paints under cards.** `.fxsvg` is z-index 4 and a full-width card is 8, so
   an arrow that lands on a card is silently clipped. Lift the svg layer while those arrows run.
12. **Motion runs the whole shot**, each beat keyed to the spoken word (`cue('words')`, 0.28 s
   lead). The last beat of every scene should land past 90% of its length.
13. **The hub is the Single Source of Truth**, never "the source". Spokes can write back
    (Excel edit, import, one build carries it everywhere).

## 5. Workflow

1. Read the subject (usually `../effortless-rulebooks/rulebook-examples|toy-rulebooks/<domain>/`:
   its `CLAUDE.md`, rulebook, README). Find the ONE idea and write it as one sentence.
2. Create the folder WITH `effortless-rulebook.json` + `effortless.json` in the same step
   (never a planning doc alone). Every Scene row carries `Storyboard`; `Clips.Scene` is the
   compound key `<Storyboard> / NN - <Title>`. `effortless build`, confirm it lists.
3. Ask the owner every blocking question ONCE, up front (length, names, real vs replica, VO
   spend), then work unattended. Commit often.
4. Write Purpose, Visualization and Script for every scene. Guard for dashes.
5. Capture the real states. Record VO, then word maps, then the cue audit (three steps, always).
6. Build the stage scenes. Dump stills and LOOK at them: every scene, after every fix.
7. `effortless build`, render, and measure the MP4 only after `render-cli` has exited.
8. Compose a designed thumbnail and set it default BEFORE the final render (it becomes frame 0).
9. Report plainly: real length, what was verified by eye, what was not (you cannot hear audio,
   so say so), and every judgement call the owner should check. Never publish without a yes.

## Guardrails

- Never fabricate a substrate result. A video is a claim in public.
- A repeatable trap goes in checked-in docs (the repo `CLAUDE.md`, this skill), not only memory.
- Re-recording VO is three steps; a stale word map or an unmatched cue fails silently elsewhere
  (the stage makes it a hard failure, keep it that way).
- Never `ffprobe` the final MP4 while `render-cli` is running. Never add caching. Never write
  DDL against the catalog Postgres. Check `TinyLinks` before shortening a URL.
- Demo apps and screenshots are colourful and phone-shaped, except the rulebook editor.
