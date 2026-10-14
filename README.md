# Godot Toolkit

Shared GDScript and publishing tooling for WebHatchery's Godot 4.2.2 games
(`bound_god`, `small_following`, `spiritwright` and the games after them). It
collects what those games each wrote for themselves: key and gamepad
rebinding, preferences, crash-safe saves, balance and text catalogs, data
validation, seeded randomness, placeholder audio and drawing, a code-built UI
kit with a ready-made settings page, the headless check runner, and the export
and deploy scripts.

This folder is a library with its own small Godot project for checks. It is
not a game. It has no export, no `publish.ps1` of its own, and no web page.

## Use in a game

The code lives in `addons/hatchery/` and must appear in a game as
`res://addons/hatchery/` (scripts preload each other by that path).

```powershell
# One shared copy, live in every linked game (a directory junction):
.\tools\Link-Toolkit.ps1 -ProjectDir ..\my_game
# Or a vendored snapshot, re-run to update:
.\tools\Link-Toolkit.ps1 -ProjectDir ..\my_game -Mode Copy
```

Then preload what you need. Nothing registers a global `class_name`, so
toolkit scripts never collide with a game's own names:

```gdscript
const Balance = preload("res://addons/hatchery/core/balance.gd")
const KeyBindings = preload("res://addons/hatchery/input/key_bindings.gd")
const SettingsStore = preload("res://addons/hatchery/settings/settings_store.gd")
```

For publishing, copy `templates/publish.ps1` and `templates/publish-itch.ps1`
beside the game's `project.godot`. They dot-source
`../godot_toolkit/publishing/Publisher.ps1` (override with `-ToolkitDir`), and
read the game's existing `publish.json`.

## Documentation

- [Module guide](GODOT_TOOLKIT.md): every module, what it replaces in the
  existing games, and integration examples.
- [Agent instructions](AGENTS.md): rules for changing the toolkit.

## Validation

From this folder, with the standard Godot 4.2.2 console editor:

```powershell
$godot = '..\small_following\exports\tooling\Godot_v4.2.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tools/parse_all.gd     # every script loads
& $godot --headless --path . --script res://tools/self_checks.gd   # behaviour checks
```

The self-checks cover data rules, catalogs, saves and recovery, bindings,
settings, synthesis and the settings page's wiring. They run headless, so they
do not establish how anything looks, sounds, or behaves with real touch,
gamepads or browsers: verify those in a consuming game.

The publisher can be checked without writing anything:

```powershell
.\templates\publish.ps1 -ProjectDir ..\spiritwright -ToolkitDir . -DryRun
.\templates\publish-itch.ps1 -ProjectDir ..\spiritwright -ToolkitDir . -DryRun
```
