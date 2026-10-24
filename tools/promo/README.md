# Godot promo capture

`capture_promo.gd` is the shared Godot 4 driver used by WebHatchery Promoter.
Promoter launches it against a selected game's project, loads that project's
configured main scene, follows a JSON shot plan, and samples gameplay off-screen with bounded background image encoding.
The FFmpeg renderer, captions, update coverage and final video stay in
Promoter. Games do not need a copied driver, plugin, or project-specific
capture tool.

## What the driver supports

- A configured `application/run/main_scene` that opens in a desktop Godot 4
  build.
- A list of timed shots with a caption and stable feature IDs.
- `InputMap` action presses, releases and taps, plus mouse clicks at viewport
  coordinates. Actions update polled input state and are also delivered as
  `InputEventAction` events, so UI toggled from `_unhandled_input` reacts.
- Real-time input scheduling, optional `setupActions`, and an initial settle period before the shots begin.
- An off-screen, non-focused window; capture-only VSync disabling and a 60 FPS game cap.
- At most two JPEG encoding jobs, so encoding and disk writes cannot block the game thread.
- A plan `scene` (a `res://` scene to start in instead of the main scene) and a save fixture copied into `user://` before the game starts (`--user-files=<dir>`, passed by Promoter for a plan's `saveFixture`).
- A game-owned setup hook for plan `setup` and `hook` actions (below).
- Unrecorded shots (`"record": false`) that let the game run between filmed shots. Plans may total up to 180 seconds; each shot is at most 30.

The shot plan and project-relative source file list are kept in Promoter's
ignored `data/media/godot/<project-key>/promo/` folder. The shared driver is
invoked through `scripts/godot-promo.ps1`; do not run it against the toolkit's
own project.

## Game setup hook

When a feature cannot be reached repeatably from a fresh title screen (a particular seed, a later save, another map), the game may declare a hook in `project.godot`:

```ini
[promotion]
setup_script="res://scripts/presentation/promo_setup.gd"
```

The script provides `static func prepare(setup: Dictionary) -> String`, called with the plan's `setup` object before the start scene loads, and `static func action(scene: Node, action: Dictionary) -> String`, called for each `{"type": "hook", ...}` action with the current scene. Each returns `""` or the reason it failed; a failure stops the capture. Plans using `setup` or hook actions are refused when no hook is declared.

Keep hooks honest: use the routes a player has (new world from a seed, load a slot, travel the game's normal way, let time pass by simulating it, set preferences, game speed, camera and UI). Never stamp buildings, grant resources or edit world state to stage a shot; footage must show what the game actually does. Bound God's `promo_setup.gd` is the reference.

## Game README notes

Add a short **Promoter capture** section to each game's README. Keep the
instructions useful to someone who has not played the game:

- Name the publicly released features that are straightforward to show.
- List the normal controls or `InputMap` action names that reach those scenes
  and interactions.
- Describe the shortest normal route from the title screen to each feature.
- Note whether a fresh run, save, seed, or setup step is needed for a repeatable
  view.
- Mention limitations that affect capture, such as a required .NET build or a
  feature that only appears after a long run.

Describe the player's visible route, not private implementation details. The
agent should inspect the project and verify the route before recording it in a
plan. The driver can use ordinary input; when a project needs bespoke state
mutation to show a feature, do not add a project-specific capture script as a
first step. Ask whether a normal gameplay route, a save fixture or the game's
setup hook can show it.

## Promoter commands

From a game project root in the WebHatchery workspace:

```powershell
$promoter = (Resolve-Path '..\..\local_apps\promoter').Path
$project = (Resolve-Path '.').Path
& "$promoter\scripts\godot-promo.ps1" -Mode status -ProjectRoot $project -ProjectKey my-game
```

For a first video, create a `launch` plan using the schema in Promoter's
[`adapters/godot/README.md`](../../../../local_apps/promoter/adapters/godot/README.md).
For later videos, check `status`, then create an `update` plan with only
publicly released features added or materially changed since the last video.
Reuse a feature's ID when showing its further update. Promoter blocks unchanged
coverage, so an update video does not repeat an already covered feature unless
one of its linked source files changed.

Set `GODOT_EXECUTABLE` to a Godot 4 desktop executable, then use the same
project key for every video:

```powershell
$plan = Join-Path $promoter 'data\media\godot\my-game\promo\plan-001.json'
& "$promoter\scripts\godot-promo.ps1" -Mode generate -ProjectRoot $project -ProjectKey my-game -PlanFile $plan
```

Python 3, FFmpeg and ffprobe are also required. Promos remain drafts; the
capture workflow does not approve or publish them.

## Capture protocol

Launch through the current Promoter `scripts/godot-promo.ps1`. Direct legacy two-argument driver calls are no longer supported: the driver requires `--promo-background` and the launcher creates a private Windows desktop. Both toolkit and Promoter must be updated together. Games must declare `promotion/background_capture_safe=true` only after their mouse-mode writes are guarded against physical capture in promo mode. The driver fails closed without that declaration. Bound God has adopted this; other games need equivalent pointer handling before using the background driver. Normal game settings are unchanged.

The driver loads the main scene as `current_scene`, allowing normal title-to-game transitions. Setup inputs and settling run before recording. Shots use wall-clock input timing and sample slots, save JPEGs asynchronously, and write schema-1 `capture.json` reports with sample indices and performance measurements. GPU readback stays on the main thread, but VSync is disabled in this isolated process to avoid waiting on presentation; encoding and disk I/O run in bounded workers. The game is capped at 60 FPS. Promoter resamples completed shots afterward, reports repeated frames and rejects long stalls. Its launcher owns timeout cleanup, output logging and private-desktop lifecycle; see its adapter README for details.
