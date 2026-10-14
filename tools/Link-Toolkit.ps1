[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectDir,
    [ValidateSet('Junction', 'Copy')][string]$Mode = 'Junction',
    [switch]$DryRun
)
# Makes the toolkit available to a game as res://addons/hatchery/.
#   Junction (default): one shared copy; edits here are live in every linked
#                       game. Godot and exports read through the junction.
#   Copy:               a vendored snapshot; re-run to update it.
# Never replaces an existing addons/hatchery that is not a junction to here.
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '..\addons\hatchery' | Resolve-Path | Select-Object -ExpandProperty Path
$project = (Resolve-Path -LiteralPath $ProjectDir).Path
if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)) { throw "Not a Godot project: $project" }
$target = Join-Path $project 'addons\hatchery'
if (Test-Path -LiteralPath $target) {
    $item = Get-Item -LiteralPath $target -Force
    $linked = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and ($item.Target -contains $source)
    if ($Mode -eq 'Junction' -and $linked) { Write-Host "Already linked: $target"; return }
    if ($Mode -eq 'Junction' -or $linked) { throw "$target already exists. Move it aside first." }
}
if ($DryRun) { Write-Host "[dry-run] $Mode $source -> $target"; return }
New-Item -ItemType Directory -Path (Join-Path $project 'addons') -Force | Out-Null
if ($Mode -eq 'Junction') {
    New-Item -ItemType Junction -Path $target -Target $source | Out-Null
} else {
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    Copy-Item -LiteralPath $source -Destination $target -Recurse
}
Write-Host "$Mode ready: $target"
