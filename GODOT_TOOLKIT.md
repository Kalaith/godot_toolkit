# Godot Toolkit module guide

All paths below are under `res://addons/hatchery/`. Each script is preloaded
by path; none declares a `class_name`.

## What each game duplicated, and where it now lives

| Toolkit module | bound_god | small_following | spiritwright |
| --- | --- | --- | --- |
| `input/key_bindings.gd` | `scripts/core/key_bindings.gd` | `scripts/key_bindings.gd` | — |
| `input/pad_bindings.gd` | `scripts/core/pad_bindings.gd` | `scripts/pad_bindings.gd` | — |
| `settings/settings_store.gd` | `scripts/core/settings_store.gd` | `scripts/settings_store.gd` | — |
| `ui/settings_panel.gd` | `presentation/ui/settings_screen.gd` | `scripts/settings_screen.gd` | — |
| `storage/json_save.gd` | settings file | `progression.gd` save code, settings file | `core/save_file.gd` |
| `storage/slot_store.gd` | `scripts/core/save_store.gd` | — | — |
| `core/balance.gd`, `core/dot_table.gd` | `scripts/core/balance.gd` | `scripts/balance.gd` | `catalog.num()` |
| `core/text_catalog.gd` | `core/data.gd` labels, `core/text.gd` | — | — |
| `core/json_io.gd`, `core/data_rules.gd` | `validation*.gd` `_number`, `_schema` | `progression.gd` `_finite_number`, `_integer_between` | `catalog.gd` `_read` |
| `core/det.gd` | sim rng picks, stable `sort_custom` | — | `battle_sim.gd` rng |
| `audio/synth.gd`, `audio/voice_pool.gd` | `audio_director.gd`, `music_director.gd` | `game_audio.gd` cooldowns | — |
| `audio/levels.gd` | bus volumes in `settings_store.gd` | `game_audio.gd` `_level` | — |
| `audio/ambience.gd` | — (new) | — | ambience beds |
| `fx/shake.gd` | — (new) | — | battle screen shake |
| `ui/palette.gd`, `ui/ui_kit.gd` | `presentation/ui/style.gd` | `ritual_style.gd`, settings styling | `scripts/ui/style.gd` |
| `ui/screen_switcher.gd`, `ui/focus.gd` | `screens_controller.gd` focus/back | settings `focus_first` | `main.gd` `_swap`/`_back` |
| `input/pointer_tap.gd` | — | `scripts/village_input.gd` | — |
| `draw/shapes.gd` | — | `scripts/draw_shapes.gd` | map/golem drawing |
| `settings/display.gd` | fullscreen toggle, UI scale | fullscreen, web exit | — |
| `testing/check_runner.gd`, `testing/expect.gd` | `tools/sim_checks.gd` | — (no tests by policy) | `tools/sim_checks.gd` |
| `testing/capture_runner.gd` | `presentation/capture*.gd` | — | `tools/capture.gd` |
| `publishing/Publisher.ps1` | `tools/publishing/Publisher.ps1` | `tools/publishing/Publisher.ps1` | `tools/publishing/Publisher.ps1` |

bound_god uses publishing, balance, the text catalog, JSON and data-rule
helpers, bindings and the settings store, the slot store, synth and voice
pool, and the check runner; it keeps its own UI style, settings screen,
captures and simulation randomness. small_following and spiritwright have not
been changed. Adopting it is per game and per module; nothing here requires
adopting everything.

## Ownership rules

- The toolkit owns mechanisms (file safety, binding rules, check running,
  export and deploy). Games own policy and content: their actions, defaults,
  schemas, validation rules, palettes, text and art.
- Simulation helpers (`core/det.gd`, `core/data_rules.gd`, `core/dot_table.gd`)
  never touch the scene tree, `Time`, `OS` or the global `randi()`/`randf()`.
- Player-facing English in the toolkit is a fallback only; every widget takes
  a text callable or error codes so a game can serve its own catalog.

## core

**`json_io.gd`** reads JSON without console noise and tells "absent" (null)
from "empty". `read_object(path, errors, schema_version)` returns `{}` and
records a message for a missing, non-object or wrong-schema file.

**`data_rules.gd`** has predicates (`finite`, `whole`, `integer_in`,
`fraction`, `nonempty`, `is_vec2`) and an error collector for catalog
validators:

```gdscript
var errors: Array[String] = []
var rules := DataRules.new(errors, "blocks")
rules.schema_version(data, 1)
for entry in data.blocks:
    var block := rules.at("blocks[%s]" % entry.get("name", "?"))
    block.integer_between(entry, "id", 0, 255)
    block.boolean(entry, "solid")
    block.one_of(entry, "shape", data.shapes)
    block.optional(entry, "yield", "number")
```

**`dot_table.gd`** reads `"section.key"` paths with caching and fails fast on
a missing path. **`balance.gd`** is the static `Balance.number("a.b")` facade
both games already call; set `Balance.path` first if balance lives elsewhere.

**`text_catalog.gd`** merges label catalogs split by responsibility, reports
keys defined twice, overlays `data/locale/<code>/*.json` (known keys only),
and offers the pseudo-language for layout testing:

```gdscript
static var text := TextCatalog.new(["res://data/text.json", "res://data/text_ui.json"])
text.format("prayer_heard", {"name": person.name})
text.pseudo = settings.values.pseudo_language
errors.append_array(text.problems())
```

**`det.gd`** gives seeded `pick`, `weighted_index`, `weighted_key`,
`shuffle`, `chance`, `fork(seed, stream)` (independent per-system streams),
and `sort_by(items, score, id)`, a sort that tie-breaks on a stable id
because `sort_custom` is not stable.

## storage

**`atomic_file.gd`**: the primitives (stage and verify a `.tmp`, rotate to
`.bak`/`.corrupt`, promote, preserve without overwriting).

**`json_save.gd`**: one versioned JSON document with every guarantee the
games implemented separately: validation before and after writing, `.bak`
rotation, recovery from backup, damaged files preserved as `.corrupt` (an
existing `.corrupt` is never replaced), newer-version files block writes,
optional `migrate` for older schemas, `keep_previous()` before a new game,
`enabled = false` for checks.

```gdscript
var save := JsonSave.new("user://progression.json", SAVE_VERSION, _valid)
save.schema_key = "schema_version"
save.migrate = SaveSchema.migrate
var data := save.load_data()
if data.is_empty(): new_game()
if not save.save_data(snapshot()): notice(save.last_error)
```

`block_on_damage = true` is the preferences policy: unreadable settings with
no good backup turn saving off for the session instead of starting fresh.

**`slot_store.gd`**: multi-file saves in one folder per slot (bound_god's
world saves), staged so a failure leaves the previous save whole. Files added
after older saves were written go in `optional`: absent ones are skipped,
damaged ones still fail the read.

## input

**`key_bindings.gd`** and **`pad_bindings.gd`** are the two games' binding
scripts as instances: pass the action-to-label dictionary, read defaults from
project.godot, validate saved mappings, `apply` without disturbing other
event types. Missing newer actions take their default or a spare key. Errors
are codes (`bind_key_taken|E|interact`) worded by the game or by `describe`.

**`pointer_tap.gd`** is small_following's tap-to-walk gesture: one `tapped`
signal for a short press on open ground, by mouse or touch; drags, second
fingers and focus loss cancel it.

## settings

**`settings_store.gd`** holds values (bools, 0..1 numbers, ranged numbers,
string choices) plus optional bindings, tolerates files missing newer keys,
and saves through `JsonSave`. **`display.gd`** answers headless/web/can-quit
questions and handles fullscreen and UI scale.

```gdscript
var settings := SettingsStore.new({"master": 1.0, "music": 1.0, "muted": false, "fullscreen": false})
settings.keys = KeyBindings.new(KEY_ACTIONS)
settings.pad = PadBindings.new(PAD_ACTIONS, [JOY_BUTTON_START, JOY_BUTTON_B])
settings.load_settings()
settings.apply_bindings()
Levels.apply_buses(settings.values, {"Master": "master", "Music": "music"})
Display.set_fullscreen(settings.values.fullscreen)
```

## audio

**`synth.gd`**: bound_god's generated sounds (tones with partials and noise,
plucks, wind, rain, drones), seeded from a caller's rng. **`voice_pool.gd`**:
a round-robin player pool with per-cue cooldowns that drop excess cues
instead of queueing them, and a headless-safe mode. **`levels.gd`**: linear
volume to dB, gain chains, bus creation and setting. **`ambience.gd`**:
background beds of looping layers (wind over a drone, rain over a hum),
crossfaded when the bed changes; asking for the bed already on does nothing,
so screens can request theirs every time they show.

```gdscript
Levels.ensure_bus("Ambience")
var ambience := Ambience.new()
ambience.bus = &"Ambience"
add_child(ambience)
var rng := RandomNumberGenerator.new()
ambience.play_bed("ruins", [{"stream": Synth.wind_loop(rng, 9.0), "db": -16.0},
    {"stream": Synth.drone_loop(55.0, [1.0, 1.5], 8.0), "db": -24.0, "offset": 0.4}])
```

## fx

**`shake.gd`**: trauma-based screen shake. Hits `add` trauma, it drains each
`step(delta)`, and the offset grows with trauma squared; `enabled = false`
(a "screen shake" setting) keeps the view still. Seeded, never the global rng.

## ui

**`palette.gd`** + **`ui_kit.gd`**: one palette per game, builders for labels,
headings, wrapped text, touch-sized buttons and toggles, sliders, panels,
meters, modal shade, the radial backdrop, and a project `Theme`. Accessibility
(colour-safe, high contrast) swaps the palette in place.

```gdscript
static var ui := UiKit.new(_palette())
static func _palette() -> Palette:
    var p := Palette.new()
    p.accent = Color("e2bf7c")
    p.display_font = preload("res://assets/fonts/Title.ttf")
    return p
```

**`settings_panel.gd`**: the settings page both rebinding games built by hand:
sections of sliders and toggles, key and pad capture with Esc to cancel, clear
and reset, PageUp/PageDown and bumpers to change tab, B or `close_action` to
close, optional Title and Exit (disabled on the web). Each word goes through
`text: Callable(key, english)`. Each slider reads out its value (a
percentage, or `slider_text: Callable(key, value)`), and keys listed in
`commit_on_release` (a UI scale) apply when the drag ends rather than
resizing the page under the pointer.

**`screen_switcher.gd`**: whole-screen swaps with a Back target per screen
(spiritwright's `_swap`). **`focus.gd`**: focus the first control on show and
find the topmost open overlay for gamepad play.

## draw

**`shapes.gd`**: ovals, ground shadows, rings, dashed rings, polygons and
stars, outlines, rounded rectangles, idle bob.

## testing

**`check_runner.gd`**: the headless scenario runner (bound_god's design):
modules of `check_*` methods returning `""` or a message, `--only=`,
`--module=`, `--long`, exit code for CI.

```gdscript
extends "res://addons/hatchery/testing/check_runner.gd"
func modules() -> Array[String]:
    return ["res://tools/checks/checks_data.gd", "res://tools/checks/checks_battle.gd"]
```

**`expect.gd`**: `all`, `truthy`, `equal`, `near`, `contains`,
`deterministic(run, seed)`, `scratch_path(name)`. **`capture_runner.gd`**:
scripted screenshot tours (`open_scene`, `frames`, `seconds`, `shot`).

## publishing

`publishing/Publisher.ps1` merges the three games' publishers. `publish.json`
gains two optional fields: `targets` (`["web", "windows"]` or `["windows"]`,
inferred from `itch_channels` when absent) and `executable` (inferred from
`display_name` when absent). Web games deploy the export with `web.htaccess`;
Windows-only games deploy their ZIP and a page from `download.html`. A game's
own `tools/publishing/web.htaccess` or `download.html` overrides the shared
one. A `licences/` folder ships beside the executable. The standard Godot
editor is found from `-GodotExe`, `GODOT_EXE`, or any sibling game's
`exports/tooling/`.

## Suggested adoption order

1. **Publishing**: lowest risk, identical behaviour, removes three copies.
2. **Bindings and settings store**: the two copies are already near-identical.
3. **Balance, JsonIO, DataRules**: drop-in for small helpers.
4. **JsonSave**: replace hand-written save code, keeping each game's schema
   and migration.
5. **Settings panel, UiKit, check runner**: larger, per-game styling work.
