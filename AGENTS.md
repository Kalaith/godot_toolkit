# Godot Toolkit agent instructions

This folder is the shared library for WebHatchery's Godot games, not a game.
`addons/hatchery/` is the code games load as `res://addons/hatchery/`;
`publishing/` and `templates/` are the shared export and deploy scripts;
`tools/` holds the toolkit's own checks. Read [README.md](README.md) and
[GODOT_TOOLKIT.md](GODOT_TOOLKIT.md) before changing anything.

## Scope

- Work only inside this folder unless the user explicitly asks to adopt the
  toolkit in a game. Do not edit games to use it as a side effect.
- A change here affects every game linked by junction. Keep public functions
  and signals backwards compatible, or say plainly which games break and how.
- Move something into the toolkit only when at least two games need it, or a
  game's copy is clearly generic. Game rules, content, art and text stay in
  the games.

## Engineering

- Godot **4.2.2** GDScript. Code must work under both the Compatibility
  renderer (web exports) and Forward+.
- Static typing everywhere. Tabs, LF, UTF-8 (`.editorconfig`).
- Load dependencies with `const X = preload("res://addons/hatchery/...")`.
  Never declare `class_name`: it would collide with names in the games.
- Configuration comes from the caller (paths, actions, defaults, palettes,
  callables); no game names or game paths in the library.
- Simulation-facing modules (`core/`) never touch the scene tree, `Time`, `OS`
  or the global `randi()`/`randf()`. Randomness comes from a caller's
  RandomNumberGenerator.
- Fail fast on bad data: report it, never silently default.
- Player-facing English is a fallback; widgets accept a text callable or
  return error codes.
- Keep scripts under ~400 lines and split by responsibility before they grow.
  No file over 800 lines.

## Checks

- Run `tools/parse_all.gd` and `tools/self_checks.gd` (commands in README.md)
  before every commit that touches scripts. Add a check in `tools/checks/` when
  behaviour lands. Do not add a `tests/` directory or test frameworks.
- Check the publisher with `-DryRun` against a real game; never deploy from
  here.
- Headless checks do not verify visuals, audio, touch, gamepads or browsers.
  Say plainly what was and was not checked.

## Commits

Commit after each complete, working step. Message style: one present-tense
line describing what changed for the games that use it, then a short plain
tag in parentheses, e.g. `Every game's saves now survive a torn write (json save)`.
