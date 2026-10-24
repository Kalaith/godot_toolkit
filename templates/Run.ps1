param(
    [string]$GodotExe = '',
    [string[]]$GameArgs = @()
)
# Plays the game from source with the installed standard Godot 4.7 editor
# (the newest 4.7.x in Program Files unless -GodotExe says otherwise).
$ErrorActionPreference = 'Stop'
if (-not $GodotExe) {
    $installed = Get-ChildItem -Path 'C:\Program Files\Godot' -Filter 'Godot_v4.7.*-stable_win64_console.exe' -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Name -replace '^Godot_v(\d+\.\d+(\.\d+)?)-.*', '$1') } -Descending | Select-Object -First 1
    if ($installed) { $GodotExe = $installed.FullName }
}
if (-not $GodotExe -or -not (Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
    throw 'Godot executable not found. Pass -GodotExe with the path to your installed Godot 4.7 executable.'
}
& $GodotExe --path $PSScriptRoot @GameArgs
exit $LASTEXITCODE
