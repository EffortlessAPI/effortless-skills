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
VIDEO_SLUG=<series>/<video> node server/fixedbid/drop/record_vo.mjs [scene ...]   # same recorder for ANY series (ep03 hardcodes 15-cli-tour/)
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
- **An arrow landing on a floating card was silently clipped** (`.fxsvg` z-index 4, cards 7-11).
  It shipped in four scenes before it was named. `arrow()` now lifts the layer itself
  (`stackOf`/`liftSvg`/`dropSvg`, refcounted, cleared by `reset()`) — never hand-set
  `CORE.svgLayer().style.zIndex` per scene again, which only ever fixed one of the four.
- **`retype`'s `selHold` is a DURATION, not a timestamp.** Passing `cue('a later phrase') - t`
  holds the selection for that whole span, so the typing fires after a build has already
  repainted the element: the value changes by itself and the edit is never seen. Keep it under
  ~1.5 s and pull a still INSIDE the edit window — the dry run and the render log cannot see this.
- **`effortless install` bricks the project** on CLI v2026-09-22-0609: it records the step as
  `".Cli install <tool> …"` when a CommandLine must start with the bare TOOL NAME, so every
  later `effortless` command dies with "Project tool '.Cli' is missing". It also prints that
  `ERROR:` and **exits 0**. Strip the whole `<anything> install ` prefix (rewriting it to
  `effortless` fails the same way). `capture_states.py` self-heals after each command.

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

## ⏩ Rendering at a SPEED (and why a CLI render can come out too long)

Two render paths, and only one knows about tempo:

| Path | Speed? |
|---|---|
| `render-cli.mjs` → `render.js` (scene path) | **no** — always 1× |
| Build MP4 button / `render-speed-cli.mjs` → `renderFinal()` in `acts.mjs` | yes (`atempo` + `setpts`, 0.5–1.5) |

```bash
node server/render-speed-cli.mjs <series>/<video> 1.15
```

Worked example, verified against the YouTube API and each cut's own rulebook (2026-09-25):

| Init video | scenes | clips | speed | published |
|---|---|---|---|---|
| release 5 (`EaAUbf6lN70`) | 31 | 25:51 | 1× | 26:21 |
| release 6 (`iXro60oobpU`) | 30 | 25:14 | 1.15× | 22:28 |

Runtime fell 3:53; **only 37s of that was editing**, the other 3:17 was tempo. A cut
mid-series also rendered **24:32** through `render-cli` after trimming ~110s, because the
speed was never applied — a regression that was a missing flag.

⚠️ This paragraph previously read *"take 5 shipped at ~1.29× (25:51 of clips → 21:40
published)"* — the 25:51 belonged to the 31-scene cut, the 21:40 to a different 30-scene
cut, and 1.29× was the ratio invented to reconcile them. **Never derive a speed by
dividing two numbers you did not measure off the same cut.**

Measure it properly instead:
- **Published duration** from YouTube (`videos.list?part=contentDetails` on
  `Publications.ExternalId`, or `node server/youtube-sync.mjs <slug>`) — not from a commit
  message, which drifts from what was actually uploaded.
- **Clip total** by summing `NativeDurationSeconds` over that rulebook's `stage-*` Assets.
  Never by walking `acts/*/final.mp4`: a renumber orphans old act folders instead of
  replacing them, so that sum is silently inflated.
- **Bookends are ~17s**, not 95s (0.5 thumb + 1.5 intro + ~14.9 outro, outro not sped up),
  so `published ≈ clips ÷ speed + 17`.

Compare CLIP TOTALS, not final runtimes.

## Filming a REAL web app (`server/threshold/`, built for `18-client-pitches/02-threshold-project-process`)

`server/threshold/film.mjs` + `stage.html` film a live browser app (the Threshold portal on
`localhost:5310`) inside a browser-window replica, one clip per scene, with whisper-cued beats.
Reuse it for any client prototype that is a web page:

- **Highlights track the real element, even while the page scrolls.** A tracker is injected
  INTO the app frame (`TRACKER`): it resolves each box's spec every animation frame and
  `postMessage`s the rects to the stage, which draws them. A spec is `css|text|nth|sub-css`
  (innermost css match whose text contains `text`), so `'.badge|Not Started|2'` or
  `'.workflow-card|Daily site huddle|0|.badge'` needs no ids in the app. Never hand-place a box.
- **Cues come from the word map on a letter stream** (`norm()` strips spaces and punctuation),
  so a script's "S D" matches whisper's "SD" and "twenty five" matches "twenty-five". Whisper
  still writes NUMERALS ("14 steps", "3 buildings"): cue on the noun, never the number.
- **`--dry` audits every cue against the maps without a browser** and prints the last beat as a
  percentage of the shot. Run it after every re-record and before every shoot.
- **Writes are real.** `setState()` puts the app's database in the state a scene expects
  (clean → logged → passed → owned) through the generated API, and the `finally` block resets
  it, so a re-shoot of one scene never films a stale row. Check the API's auto-save setting
  first: with auto-save ON, filmed writes would sync back into the client's rulebook file.
- **SPA navigation without a link:** `history.pushState` + a synthetic `popstate` moves
  react-router; a `location.reload()` drops the injected tracker, so `reload()` re-injects it.
- Real ids bite: a gate route 404s silently and the shoot dies on a `waitFor` timeout 30 s
  later. Read the id off the API (`/api/tables/<T>`) before writing a `goto`.
