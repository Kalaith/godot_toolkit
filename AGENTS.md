# Godot Toolkit agent instructions

This folder is the shared library for WebHatchery's Godot games, not a game. `addons/hatchery/` is the code games load as `res://addons/hatchery/`; `publishing/` and `templates/` are the shared export and deploy scripts; `tools/` holds the toolkit's own checks. Read [README.md](README.md) and [GODOT_TOOLKIT.md](GODOT_TOOLKIT.md) before changing anything. The shared standards at the end of this file apply as well as everything here.

## Scope

- Do not edit games to use the toolkit as a side effect; adopting it in a game needs an explicit request.
- A change here affects every game linked by junction. Keep public functions and signals backwards compatible, or say plainly which games break and how.
- Move something into the toolkit only when at least two games need it, or a game's copy is clearly generic. Game rules, content, art and text stay in the games.

## Project engineering

- Code must work under both the Compatibility renderer (web exports) and Forward+.
- Never declare `class_name`: it would collide with names in the games. Preload paths are `res://addons/hatchery/...`.
- Configuration comes from the caller (paths, actions, defaults, palettes, callables); no game names or game paths in the library.
- Simulation-facing modules (`core/`) follow the shared determinism rule; randomness comes from a caller's RandomNumberGenerator.
- Player-facing English is a fallback; widgets accept a text callable or return error codes.

## Project checks

- The checks are `tools/parse_all.gd` and `tools/self_checks.gd` (commands in README.md); run them when a major feature is finished. Add a check in `tools/checks/` when behaviour lands.
- Check the publisher with `-DryRun` against a real game; never deploy from here.
- Headless checks do not verify touch, gamepads or browsers either.

## Commit voice

Commit lines describe what changed for the games that use the toolkit.

```
Every game's saves now survive a torn write (json save)
```

## Shared WebHatchery Godot standards

Identical in every WebHatchery Godot project's AGENTS.md; change all together. Project-specific rules go above.

### Working

- Stay inside this project unless the user broadens the task; preserve user changes; never overwrite original art.
- No installing/upgrading Godot, export templates, tools, plugins or GDExtensions without approval; prefer built-in features.

### Code

- Godot **4.7.2** GDScript, statically typed everywhere (variables, parameters, returns). `const X = preload("res://...")`. Tabs, LF, UTF-8, final newline.
- Simulation/rules code never touches the scene tree, `Time`, `OS` or global `randi()`/`randf()`; randomness comes from an owned `RandomNumberGenerator` (same seed, same result). Presentation reads state and sends commands, nothing else.
- Balance and catalogs (upgrades, parts, miracles, blocks, ...) live in JSON under `data/` with stable ids (and `schema_version` where present), validated at startup, holding only implemented effects. Missing or mistyped data fails fast and is reported; never default silently in code.
- Persistent state lives under `user://` with schema validation, staged writes and backup recovery. A failed save never loses progress or spends anything.

### Verification

- No `tests/` directory, frameworks or addons. Any automated checks are headless scripts in `tools/`, kept out of the export.
- Checks don't gate commits. At a major feature or milestone, run all checks (plus `--headless --editor --quit`) and fix findings.
- Headless checks can't verify visuals, audio, input or feel: run the game and look. State plainly what was and wasn't checked.

### Verification images

- Only `docs/verification/` (flat; keep its `.gdignore` and `docs/`'s). Reference art: `docs/reference/` or `docs/art/`.
- Capture via the toolkit's `testing/capture_runner.gd` or `testing/capture_paths.gd` (`CapturePaths.file(label)`); never pass an output directory or write elsewhere (`builds/`, `exports/`, OS temp, `user://`).
- Stable names `<label>.png`: no subfolders, timestamps, run/revision/size suffixes, `-final`/`-fix` variants or backups. Recapturing a screen or state overwrites; new labels only for genuinely new ones.
- One window size and UI scale per game. Look at the image before saying a visual change works.

### Size limits (hard rule)

- **Functions ≤ 400 lines; files ≤ 800 lines** (scripts, scenes, data, docs, catalogs). Check: `git ls-files -co --exclude-standard | grep -E '\.(gd|tscn|json|md)$' | xargs wc -l | sort -n | tail`.
- Split scripts by responsibility before they grow. A change that would cross a limit, or touches something already over, brings it under in the same change: split functions into named helpers; move a cohesive responsibility (HUD, settings wiring, area building, save validation, layout, a catalog section, ...) into its own file the original delegates to or loads. Keep public members other scripts use working.
- **Never shrink by deleting blank lines, joining statements, removing comments, minifying or packing entries onto one line.** Move content; don't squeeze it.

### Commits

- **ALWAYS commit each feature slice and bug fix the moment it works. Mandatory.** One slice per commit; never batch, never leave finished work uncommitted, never end a turn with an uncommitted feature or fix. Don't wait to be asked or offer instead of doing it; a later request ("also tweak X") is a new slice.
- Commit **all pending changes**, including modified, added and deleted files you didn't make: review and preserve them, include them in validation, finish with a clean tree.
- **Before the final reply of any turn that touched files:** run `git status --short`; if it prints anything, commit and rerun until empty. A dirty tree means unfinished; the closing summary says the tree is clean.
- Ignore rules still apply; never force-add ignored files or commit secrets. Don't push or publish unless asked.

Message: one present-tense line, no trailing period, under ~100 characters before the tag, saying what changed **as the player feels it** (for the toolkit, as the games using it feel it), then a plain lowercase tag in parentheses for what it technically is (the system touched, `docs`, `refactor` for structural changes, or a milestone id such as `M25`). Fixes and refactors are still described by effect. Add a body only when the reason isn't obvious.

```
The Lantern Fair opens: be more interesting than the fair (third map)
A prayer at the tree now feeds the god's Favour (shrine favour)
Builders no longer wall themselves into the cottage they are raising (site reservation fix)
No script over 800 lines: split main and the ritual screen (refactor)
Every game's saves now survive a torn write (json save)
Scribes set down the covenant: design and building plan (docs)
```
