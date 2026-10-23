[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectDir,
    [switch]$DryRun
)
# Brings a game's boilerplate in line with the toolkit's standard layout:
#   - copies the shared scripts and config (templates/), overwriting the game's
#     publish.ps1, publish-itch.ps1, Run.ps1, .editorconfig and .gitattributes
#   - adds any .gitignore line from the template the game lacks (keeps its own)
#   - links addons/hatchery (see Link-Toolkit.ps1)
#   - makes docs/ and docs/verification/ invisible to Godot (.gdignore)
# It never touches scripts, scenes, data or assets, and never publishes.
$ErrorActionPreference = 'Stop'
$templates = Join-Path $PSScriptRoot '..\templates' | Resolve-Path | Select-Object -ExpandProperty Path
$project = (Resolve-Path -LiteralPath $ProjectDir).Path
if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot') -PathType Leaf)) { throw "Not a Godot project: $project" }

function Write-Lf([string]$Path, [string]$Text) {
    if ($DryRun) { Write-Host "[dry-run] write $Path"; return }
    [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), (New-Object Text.UTF8Encoding($false)))
}

$copies = [ordered]@{
    'publish.ps1' = 'publish.ps1'; 'publish-itch.ps1' = 'publish-itch.ps1'; 'Run.ps1' = 'Run.ps1'
    '.editorconfig' = 'editorconfig'; '.gitattributes' = 'gitattributes'
}
foreach ($name in $copies.Keys) {
    $wanted = [IO.File]::ReadAllText((Join-Path $templates $copies[$name])) -replace "`r`n", "`n"
    $path = Join-Path $project $name
    $current = if (Test-Path -LiteralPath $path) { [IO.File]::ReadAllText($path) -replace "`r`n", "`n" } else { $null }
    if ($current -ne $wanted) { Write-Host "update $name"; Write-Lf $path $wanted }
}

$ignorePath = Join-Path $project '.gitignore'
$template = [IO.File]::ReadAllText((Join-Path $templates 'gitignore')) -replace "`r`n", "`n"
if (-not (Test-Path -LiteralPath $ignorePath)) {
    Write-Host 'create .gitignore'; Write-Lf $ignorePath $template
} else {
    $existing = [IO.File]::ReadAllText($ignorePath) -replace "`r`n", "`n"
    $have = $existing -split "`n" | ForEach-Object { $_.Trim().TrimStart('/') }
    $missing = $template -split "`n" | Where-Object { $_.Trim() -and -not $_.StartsWith('#') -and ($_.Trim().TrimStart('/') -notin $have) }
    if ($missing) {
        Write-Host ".gitignore: add $($missing -join ', ')"
        Write-Lf $ignorePath ($existing.TrimEnd("`n") + "`n`n# Added by godot_toolkit/tools/Sync-Project.ps1.`n" + ($missing -join "`n") + "`n")
    }
}

foreach ($folder in @('docs', 'docs/verification')) {
    $directory = Join-Path $project $folder
    if (-not $DryRun) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $marker = Join-Path $directory '.gdignore'
    if (-not (Test-Path -LiteralPath $marker)) { Write-Host "create $folder/.gdignore"; if (-not $DryRun) { New-Item -ItemType File -Path $marker | Out-Null } }
}

& (Join-Path $PSScriptRoot 'Link-Toolkit.ps1') -ProjectDir $project -DryRun:$DryRun
