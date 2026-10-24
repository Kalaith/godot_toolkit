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

This section is identical in the AGENTS.md of every WebHatchery Godot project (`auto_resolved`, `bound_god`, `dreamspire`, `personal_best`, `small_following`, `spiritwright`, `godot_toolkit`). Change it in all seven together; project-specific rules go in the sections above.

### Working

- Work only inside this project unless the user explicitly broadens the task. Preserve any user changes.
- Do not install or upgrade Godot, export templates, tools, plugins or GDExtensions without approval. Prefer built-in engine features.
- Do not overwrite original art.

### Code

- Godot **4.7.2** GDScript. The renderer is set per project (see above).
- Static typing everywhere: variables, parameters and return types.
- Load dependencies with `const X = preload("res://...")`.
- Tabs, LF, UTF-8, final newline (`.editorconfig`).
- Split scripts by responsibility before they grow. Size limits are below.
- Simulation and rules code never touches the scene tree, `Time`, `OS` or the global `randi()`/`randf()`. All randomness comes from an owned `RandomNumberGenerator`, so the same seed gives the same result. Presentation reads that state and sends commands; it never changes it any other way.
- Balance numbers and catalogs live in JSON under `data/` with stable ids (and `schema_version` where a catalog has one), validated at startup. Missing or mistyped data fails fast: report it, never silently default in code.
- Keep every catalog (upgrades, parts, miracles, blocks and so on) bounded to implemented effects. Do not add entries the code does not support.
- Persistent state lives under `user://` with schema validation, staged writes and backup recovery. A failed save must never lose progress or spend anything.

### Verification

- Do not create a `tests/` directory, test frameworks or test addons. Automated checks, where a project has them, are headless scripts in `tools/`, kept out of the exported game.
- Checks do not gate commits. Run the full set (the project's checks, if any, and a parse/import check with `--headless --editor --quit`) when a major feature or milestone is finished, and fix what they find before calling it done.
- Headless checks do not verify visuals, audio, input or feel. Verify anything visual by running the game (`Run.ps1`) and looking at it.
- Say plainly what was and was not checked.

### Verification images

- There is one folder for verification images: `docs/verification/`, flat. It holds a `.gdignore` (so does `docs/`); keep both. Reference art goes in `docs/reference/` or `docs/art/`, never here.
- Take screenshots through the toolkit's capture runner (`testing/capture_runner.gd`) or `testing/capture_paths.gd` (`CapturePaths.file(label)`). Do not pass an output directory or write captures anywhere else (`builds/`, `exports/`, OS temp, `user://`).
- Names are stable `<label>.png`: no subfolders, timestamps, run or revision suffixes, size suffixes, `-final`/`-fix` variants or backup copies. A new capture of the same screen or state overwrites its file; add a label only for a genuinely new screen or state.
- Capture at one window size and one UI scale per game, and look at the image before saying a visual change works.

### Size limits (hard rule)

- **No function may exceed 400 lines.**
- **No file may exceed 800 lines**: scripts, scenes, data, docs and text catalogs. Check with `git ls-files -co --exclude-standard | grep -E '\.(gd|tscn|json|md)$' | xargs wc -l | sort -n | tail`.
- When a change would push a function or file past its limit, or one is already over, **bring it below the limit in the same change**. Split a long function into well-named helpers; shrink a file by moving a cohesive responsibility (HUD, settings wiring, area building, save validation, layout, a catalog section and so on) into its own file and having the original delegate to or load it.
- **Never shrink a function or file by deleting blank lines, joining statements, removing comments, minifying or packing several entries onto one line.** Blank lines between functions and the existing comment density stay as they are. Line count comes down by moving content, not by squeezing it.
- Keep public members that other scripts use working, either in place or through a delegating function.

### Commits

- Commit early and often: after every complete, working step (a system, a fix, a data pass), not at the end of a milestone. Commits do not wait on checks (see Verification).
- Commit **all pending project changes**, including modified, added and deleted files you did not make yourself. Do not leave user changes or another agent's changes uncommitted because you did not touch them: review and preserve their contents, include them in the validation, and finish with a clean working tree.
- Existing ignore rules still apply to generated files, local tooling and credentials. Never force-add ignored files or commit secrets.
- Do not push or publish unless the user asks.

Message style: one line describing what changed **as it is felt by the player** (for the toolkit, by the games that use it), then a short plain tag in parentheses saying what it is technically.

```
Neris raises a ward whenever she is struck (spirit trait)
A prayer at the tree now feeds the god's Favour (shrine favour)
The Lantern Fair opens: be more interesting than the fair (third map)
Every game's saves now survive a torn write (json save)
Scribes set down the covenant: design and building plan (docs)
```

- Present tense, no trailing period, under ~100 characters before the tag where possible.
- Fixes and refactors are still described by their effect: `Builders no longer wall themselves into the cottage they are raising (site reservation fix)`, `No script over 800 lines: split main and the ritual screen (refactor)`.
- Tags are lowercase and plain: the system touched, `docs`, `refactor`, or a milestone id such as `M25`.
- Add a body only when the reason is not obvious from the line.
