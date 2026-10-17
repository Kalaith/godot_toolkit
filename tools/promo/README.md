# Godot promo capture

`capture_promo.gd` is the shared Godot 4 driver used by WebHatchery Promoter.
Promoter launches it against a selected game's project, loads that project's
configured main scene, follows a JSON shot plan, and saves viewport frames.
The FFmpeg renderer, captions, update coverage and final video stay in
Promoter. Games do not need a copied driver, plugin, or project-specific
capture tool.

## What the driver supports

- A configured `application/run/main_scene` that opens in a desktop Godot 4
  build.
- A list of timed shots with a caption and stable feature IDs.
- `InputMap` action presses, releases and taps, plus mouse clicks at viewport
  coordinates.
- A fixed frame rate and an initial settle period before the shots begin.

The shot plan and project-relative source file list are kept in Promoter's
ignored `data/media/godot/<project-key>/promo/` folder. The shared driver is
invoked through `scripts/godot-promo.ps1`; do not run it against the toolkit's
own project.

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
first step. Ask whether a normal gameplay route or an approved test build can
show it.

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
