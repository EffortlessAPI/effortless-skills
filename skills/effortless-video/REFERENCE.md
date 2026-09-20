# effortless-video · reference (the cookbook)

Companion to `SKILL.md`. The skill is the method. This file is how take 5 of
`15-cli-tour/06-effortless-init` was actually built, so the next video can reuse it.
All paths are relative to `~/development/effortless-videos`.

## Repo map

```
series/<series>/<video>/
  effortless-rulebook/effortless-rulebook.json   the video's SSoT
  effortless.json  ANIMATION-SPEC.md (hand-written influence)  STORYBOARD.md (GENERATED)
  assets/vo/vo-NN.wav + vo-NN.words.json   narration + whisper word maps
  assets/screencasts/stage-NN.mp4          one clip per scene
  assets/captures/states-v5/<NN-step>/     real CLI states (checked in; demo-build/ is gitignored)
  thumbnails/  renders/<name>.final.mp4
server/cli_tour/init5/                     the HTML desktop stage
producer-catalog/                          Series / Videos / Thumbnails / Publications rulebook
effortless-rulebook/                       shared cast, props, brand (repo root)
```

## Commands, in the order you use them

```bash
./start.sh list                                   # videos, grouped by series
cd series/<s>/<v> && effortless build             # regenerate STORYBOARD.md + rulespeak
cp storyboard-doc/output.txt STORYBOARD.md        # if the build skipped STORYBOARD.md

python3 server/cli_tour/init5/capture_states.py <scratch-dir>   # drive the REAL CLI, snapshot states
python3 server/cli_tour/init5/prep_data.py                      # pack states into stage/data.json

CLI_TOUR_VIDEO=<video> node server/cli_tour/ep03_record_vo.mjs [scene ...]   # ElevenLabs takes
python3 server/exp05/make_word_maps.py <series>/<video>                      # whisper word maps
node server/cli_tour/init5/shoot.mjs --dry                                   # cue audit: zero ✗

node server/cli_tour/init5/shoot.mjs 24 --stills every:6 --out <scratch>     # review frames, no mp4
node server/cli_tour/init5/shoot.mjs 24 --stills 9,14,25.6 --out <scratch>   # frames at exact seconds
node server/cli_tour/init5/shoot.mjs [scene ...] --jobs 4                    # film (30 scenes ≈ 3.5 min)

node server/render-cli.mjs <series>/<video>       # final MP4; measure only after it exits
```

The recorder holds the rulebook in memory and rewrites it after each scene. Do not edit the
rulebook while it runs.

## Dash guard before recording

```bash
python3 -c "import json; d=json.load(open('effortless-rulebook/effortless-rulebook.json')); [print('DASH', s['SceneOrder']) for s in d['Scenes']['data'] if any(c in (s.get('Script') or '') for c in '—–')]"
```

## After every re-record

1. Rebuild the word maps.
2. Read what whisper HEARD for every proper noun and acronym. It is the only check available
   without ears. "Effortless AP, I watch as" exposed a mispronunciation that way.
3. `shoot.mjs --dry`. Repoint each failed cue to the words whisper heard ("to look up" for
   "two look up", "cost" for "costs"). A cue whose sentence was cut moves to the line that now
   carries that moment.
4. Reshoot only the changed scenes, then render.

## The desktop stage (`server/cli_tour/init5/stage/`)

One HTML page, ticked one frame at a time by `shoot.mjs` under a virtual clock (30 fps, shot
at 1.5x, piped to ffmpeg, unchanged frames skipped). Shot length = VO + 0.6 s.

| File | Role |
|---|---|
| `core.js` | clock and overlays: `at`, `tween`, `cue`, `show/hide`, `flash`, `spot/unspot`, `mark`, `note`, `arrow`, `pointTo`, `click`, caret, `typeText`, `retype`, `backspace` |
| `code.js` | the document model: token-addressed JSON (`t0.f2`, `t0.r1.v1`), `render`, `apply` (in-place diff to the next state), `sqlHtml` |
| `ide.js` | VS Code replica: explorer tree, tabs, full-width terminal (`type` in chunks, `enter`, `out`, `spin`), watch status strip, Claude Code panel (`claudeType/Send/Think/Say/Tool`) |
| `apps.js` | Browser, admin portal grid, export page, boot checklist, Excel, DocWin, Phone, Doll, WideTree |
| `scenes-base.js` | scene plumbing: `ideAt(state)`, `termBuild` (the order law), `typeInstall` (annotated chunks), `pipeCard` (the counter card), `register(n, fn)` |
| `scenes-a..e.js` | the scenes themselves |

A scene is `register(n, (D) => { … })`. `D` is the shot length. Every beat takes a time, and
the time is almost always a cue:

```js
const tFn = cue('And here is a function');            // seconds, from the word map, 0.28 s early
spot(tFn, rng(f1Top, f1End), { pad: 8, alpha: 0.5 }); // dim everything but these lines
mark(cue('followed by the name'), () => $$('.q-col', L(f1Body)())[0], 'blue', { until: cue('Below it is') });
arrow(cue("That's Alice's rule") + 0.4, from, to, { color: 'purple', until: cue('Below it is') });
```

`cue(phrase, { after, lead, end, fallback })`. `after` disambiguates a phrase spoken twice.
Targets are functions returning elements, resolved at that moment, so highlights track the
real layout. Find line numbers from the content:

```js
const find = (re, from) => lines.findIndex((l, i) => i >= from && re.test(l)) + 1;
const f1Def = find(/FUNCTION calc_professors_introduction/, i0);   // never `base + 3`
```

Opening a scene in the state the last one ended in: `ideAt('21-reassign-built', { watch: true, … })`.
Moving to the next real state in place: `applyNow(ide, '22-postgres')` diffs the same document
and flashes the worked-out values that changed green.

## Traps already hit (all also in the repo `CLAUDE.md`)

- `python3 -m http.server` drops sockets under parallel Playwright workers (blank scenes,
  "SB is not defined"). `shoot.mjs` runs its own node static server. Keep it.
- A generated page in an iframe ships smooth scrolling and transitions that run in REAL time.
  Inject `*{scroll-behavior:auto!important;transition:none!important;animation:none!important}` on load.
- No CSS transitions, `setTimeout` or `requestAnimationFrame` in the stage. Only `at` and `tween`.
- One stylesheet, many replicas: prefix class names (`.hub`, `.ts` collided silently).
- CSS `zoom` multiplies `left`. Code under 14 px needs line-height 1.33 to fit two tables.
- An edited-but-unbuilt state still holds the OLD generated files. Skip what the rulebook no
  longer names when packing data.
- `server/render.js` outputs 1280x720 regardless of `__meta__ render.width`.
- `effortless build` can take minutes on a cold transpiler. Wait. Leave other sessions'
  `buildOnSave` watchers alone.

## Review loop (do this, do not skip it)

For each scene: `--stills every:6`, open the PNGs, and check that every box surrounds its
text, no arrow crosses a cell it does not mean, nothing is clipped at an edge, nothing from the
previous scene lingers, the opening frame is not empty, and every name matches the story so
far. Fix, reshoot the stills, look again. Then check the dry-run line: the last beat should sit
past 90% of the shot.

## Thumbnail recipe (clickbait, still on brand)

A raw frame of a pale diagram is mush at 210 px. Design a hero card instead:

1. Pick the video's most surprising true claim as a first-person hook ("I DELETED MY WHOLE PROJECT").
2. Build a ~1360x1124 HTML card (1.21:1) and screenshot it with Playwright: the real command,
   a few struck-out filenames, a big tilted stamp with a REAL number from the captured log
   ("23 FILES DELETED"), the one survivor glowing, and a cast doll looking at camera
   (`assets/characters/<name>/look-cam.png`).
3. Compose and register it, then re-render so it becomes frame 0:

```bash
python3 server/gen-hero-thumbnail.py --theme <series-theme> --hero hero.png \
  --kicker "EffortlessAPI · CLI Tour" --headline "*I DELETED|MY WHOLE|PROJECT." \
  --footer "on purpose.|one command brought it all back." --accent danger --out thumb.png
node server/gen-thumbnails.mjs <slug> --image thumb.png      # adds mark + border + catalog row
node server/gen-thumbnails.mjs <slug> --set-default <n>
```

Use the series' own `--theme` (rows in the shared rulebook), keep the top right clear for the
mark, and never pass `--caption` on a composed hero.

## Closing report to the owner

Lead with the outcome and what was not verified. Give the true runtime. List judgement calls
(a sentence added to explain a visible parameter, a claim softened, a resolution limit). Say
what was not done (thumbnail, publish). End with whether anything is still running.
