# Shared publishing functions for Godot 4.7.2 games: export, verified build
# manifests, WebHatchery deployment (filesystem and FTP), Project Roost
# records and itch.io pushes. Dot-source it from a game's publish.ps1 and
# publish-itch.ps1 (see templates/). No work runs when loaded.
#
# A game's publish.json:
#   slug           lowercase id; deploys to <root>/games/<slug>
#   display_name   shown on the download page and in Project Roost
#   description
#   godot_version  must be 4.7.2
#   executable     Windows executable name (default: display name in PascalCase + .exe)
#   targets        ["web", "windows"] or ["windows"] (default: web when itch has an html5 channel)
#   itch_target    owner/game
#   itch_channels  { "html5": "...", "windows": "..." } for the targets built
#
# A web game deploys its export plus Apache headers (web.htaccess). A
# Windows-only game deploys its ZIP and a download page made from
# download.html. A game may override either file with its own copy in
# tools/publishing/. A `licences/` folder beside project.godot ships its *.txt
# files beside the executable.
Set-StrictMode -Version Latest

$script:WebFiles = @('index.html', 'index.js', 'index.wasm', 'index.pck', 'index.audio.worklet.js')

function Write-PublishJson($Path, $Value) {
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
}

function Get-PublishProperty($Object, [string]$Name, $Default = $null) {
    $property = $Object.PSObject.Properties[$Name]
    if ($property -and $null -ne $property.Value) { return $property.Value }
    return $Default
}

function Get-PublishProject([string]$ProjectDir) {
    $root = (Resolve-Path -LiteralPath $ProjectDir).Path
    foreach ($file in @('project.godot', 'publish.json', 'export_presets.cfg')) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $file) -PathType Leaf)) { throw "Missing project file: $file" }
    }
    $config = Get-Content -LiteralPath (Join-Path $root 'publish.json') -Raw | ConvertFrom-Json
    if ($config.slug -notmatch '^[a-z0-9][a-z0-9_-]*$') { throw 'Invalid project slug.' }
    if ($config.godot_version -ne '4.7.2') { throw 'This publisher is validated for Godot 4.7.2.' }
    if ($config.itch_target -notmatch '^[a-z0-9_-]+/[a-z0-9_-]+$') { throw 'Invalid itch target; use owner/game.' }
    $channels = Get-PublishProperty $config 'itch_channels' ([pscustomobject]@{})
    $targets = @(Get-PublishProperty $config 'targets' @())
    if ($targets.Count -eq 0) {
        $targets = if (Get-PublishProperty $channels 'html5') { @('web', 'windows') } else { @('windows') }
    }
    foreach ($target in $targets) {
        if ($target -notin @('web', 'windows')) { throw "Unknown publish target: $target" }
    }
    if ('windows' -notin $targets) { throw 'Every game publishes a Windows build; add "windows" to targets.' }
    $itch = @{}
    foreach ($target in $targets) {
        $name = if ($target -eq 'web') { 'html5' } else { 'windows' }
        $channel = Get-PublishProperty $channels $name
        if ($channel -notmatch '^[a-z0-9][a-z0-9-]*$') { throw "Invalid or missing itch channel for $name." }
        $itch[$name] = $channel
    }
    if ($itch.Count -gt 1 -and $itch.html5 -eq $itch.windows) { throw 'Itch channels must be distinct.' }
    $exe = Get-PublishProperty $config 'executable'
    if (-not $exe) {
        $words = ([string](Get-PublishProperty $config 'display_name' $config.slug)) -split '[^A-Za-z0-9]+' | Where-Object { $_ }
        $exe = (($words | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join '') + '.exe'
    }
    if ($exe -notmatch '^[A-Za-z0-9_-]+\.exe$') { throw 'Invalid executable name; use Name.exe.' }
    return [pscustomobject]@{ Root = $root; Slug = $config.slug; Config = $config; Exe = $exe; Targets = $targets; Itch = $itch; Web = ('web' -in $targets) }
}

# A game's own copy in tools/publishing/ wins over the toolkit's.
function Get-PublishAsset($Info, [string]$Name) {
    $own = Join-Path $Info.Root "tools/publishing/$Name"
    if (Test-Path -LiteralPath $own -PathType Leaf) { return $own }
    return Join-Path $PSScriptRoot $Name
}

function Read-PublishEnvironment([string]$Path) {
    $settings = @{}
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        foreach ($line in Get-Content -LiteralPath $Path) {
            if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
                $settings[$matches[1]] = $matches[2].Trim('"').Trim("'")
            }
        }
    }
    return $settings
}

function Get-PublishSetting($Settings, [string]$Name, [string]$Default = '') {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ($value) { return $value }
    if ($Settings.ContainsKey($Name) -and $Settings[$Name]) { return $Settings[$Name] }
    return $Default
}

function New-PublishProjectRoostPayload($Info, [string]$EnvironmentName, [string]$TargetType, [string]$Destination, [string]$RemotePath, [string]$PublishMode) {
    $displayName = [string](Get-PublishProperty $Info.Config 'display_name' '')
    $description = [string](Get-PublishProperty $Info.Config 'description' '')
    if ([string]::IsNullOrWhiteSpace($displayName)) {
        $displayName = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase(($Info.Slug -replace '[-_]', ' ').ToLowerInvariant())
    }
    if ([string]::IsNullOrWhiteSpace($description)) { $description = "$displayName." }
    return [ordered]@{
        project = $Info.Slug
        game_title = $displayName
        game_description = $description
        environment = $EnvironmentName
        target_type = $TargetType
        status = 'success'
        frontend_deployed = $true
        backend_deployed = $false
        destination_path = $Destination
        remote_path = $RemotePath
        source_path = $Info.Root
        publish_mode = $PublishMode
        actor = if ($env:USERNAME) { $env:USERNAME } else { $env:USER }
        deployed_at = [DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture)
    }
}

function Register-PublishProjectRoostDeployment($Settings, $Info, [string]$EnvironmentName, [string]$TargetType, [string]$Destination, [string]$RemotePath, [string]$PublishMode) {
    $token = Get-PublishSetting $Settings 'PROJECT_ROOST_PUBLISH_TOKEN'
    $urlKey = if ($EnvironmentName -eq 'production') { 'PROJECT_ROOST_API_URL_PRODUCTION' } else { 'PROJECT_ROOST_API_URL_PREVIEW' }
    $apiUrl = (Get-PublishSetting $Settings $urlKey).TrimEnd('/')
    if ([string]::IsNullOrWhiteSpace($token) -or [string]::IsNullOrWhiteSpace($apiUrl)) {
        Write-Warning "Project Roost tracking skipped: configure PROJECT_ROOST_PUBLISH_TOKEN and $urlKey."
        return $false
    }
    $payload = New-PublishProjectRoostPayload $Info $EnvironmentName $TargetType $Destination $RemotePath $PublishMode
    $headers = @{ 'X-Project-Roost-Publish-Token' = $token }
    try {
        $result = Invoke-RestMethod -Uri "$apiUrl/deployments/publish" -Method Post -Body ($payload | ConvertTo-Json -Depth 5) -ContentType 'application/json' -Headers $headers -TimeoutSec 15 -ErrorAction Stop
        if (-not $result.success) { throw 'Project Roost returned an unsuccessful publish response.' }
        Write-Host "Project Roost recorded $($Info.Slug) $EnvironmentName deployment."
        return $true
    } catch {
        Write-Warning "Project Roost tracking failed for ${EnvironmentName}: $($_.Exception.Message)"
        return $false
    }
}

function Get-DeployDirectory([string]$Root, $Info) {
    if (-not [IO.Path]::IsPathRooted($Root)) { throw 'DeployRoot must be an absolute path.' }
    $path = [IO.Path]::GetFullPath((Join-Path $Root "games/$($Info.Slug)"))
    $project = $Info.Root.TrimEnd('\', '/')
    if ($path.Equals($project, [StringComparison]::OrdinalIgnoreCase) -or
        $project.StartsWith($path + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Deployment cannot contain the source project.'
    }
    return $path
}

function Invoke-PublishTool([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Tool failed with exit code ${LASTEXITCODE}: $Executable" }
}

# The standard (non-mono) editor is looked for as -GodotExe, then GODOT_EXE,
# then the installed copy in Program Files.
function Resolve-PublishGodot($Info, [string]$Requested) {
    if (-not $Requested) { $Requested = $env:GODOT_EXE }
    if (-not $Requested) { $Requested = 'C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe' }
    if (-not (Test-Path -LiteralPath $Requested -PathType Leaf)) { throw 'Standard Godot 4.7.2 not found. Pass -GodotExe or set GODOT_EXE.' }
    $version = (& $Requested --headless --version | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.7\.2\.stable\.' -or $version -match 'mono') {
        throw "Use the standard (non-mono) Godot 4.7.2 editor for exports. Found: $version"
    }
    return (Resolve-Path -LiteralPath $Requested).Path
}

function Invoke-PublishGodot([string]$Executable, [string[]]$Arguments, [string]$Log) {
    # Godot can log errors and still exit zero; inspect both signals.
    & $Executable @Arguments *> $Log
    $exitCode = $LASTEXITCODE
    $errors = Select-String -LiteralPath $Log -Pattern '(?m)^\s*(ERROR:|SCRIPT ERROR:|Error:)'
    if ($exitCode -ne 0 -or $errors) { throw "Godot failed (exit $exitCode). Inspect $Log" }
}

function New-PublishBuild($Info, [string]$RequestedGodot) {
    $godot = Resolve-PublishGodot $Info $RequestedGodot
    $buildRoot = Join-Path $Info.Root 'builds/publish'
    $id = [guid]::NewGuid().ToString('N')
    $directory = Join-Path $buildRoot $id
    New-Item -ItemType Directory -Path "$directory/windows" -Force | Out-Null
    # Export mode performs the editor import before exporting. A separate
    # --import invocation hits a known automatic-shutdown exit 1 on this machine.
    [IO.File]::WriteAllText((Join-Path $Info.Root 'builds/.gdignore'), '')
    if (Test-Path -LiteralPath (Join-Path $Info.Root 'exports')) {
        [IO.File]::WriteAllText((Join-Path $Info.Root 'exports/.gdignore'), '')
    }
    if ($Info.Web) {
        New-Item -ItemType Directory -Path "$directory/web" -Force | Out-Null
        Invoke-PublishGodot $godot @('--headless', '--path', $Info.Root, '--export-release', 'Web', "$directory/web/index.html") "$directory/web-export.log"
        foreach ($file in $script:WebFiles) {
            if (-not (Test-Path -LiteralPath "$directory/web/$file" -PathType Leaf)) { throw "Web export missing $file" }
        }
        $files = @(Get-ChildItem -LiteralPath "$directory/web" -Recurse -File)
        if ($files.Count -gt 1000 -or ($files | Measure-Object Length -Sum).Sum -gt 500MB) { throw 'Web export exceeds itch package limits.' }
        foreach ($file in $files) {
            if ($file.Length -gt 200MB -or $file.FullName.Substring($directory.Length + 5).Length -gt 240) { throw 'Web export exceeds itch file limits.' }
        }
    }
    Invoke-PublishGodot $godot @('--headless', '--path', $Info.Root, '--export-release', 'Windows Desktop', "$directory/windows/$($Info.Exe)") "$directory/windows-export.log"
    if (-not (Test-Path -LiteralPath "$directory/windows/$($Info.Exe)" -PathType Leaf)) { throw 'Windows export missing.' }
    foreach ($licence in Get-ChildItem -LiteralPath (Join-Path $Info.Root 'licences') -Filter '*.txt' -File -ErrorAction SilentlyContinue) {
        Copy-Item -LiteralPath $licence.FullName -Destination "$directory/windows/" -Force
    }
    Compress-Archive -Path "$directory/windows/*" -DestinationPath "$directory/$($Info.Slug)_windows.zip"
    $records = @()
    foreach ($file in Get-ChildItem -LiteralPath $directory -Recurse -File | Where-Object { $_.Extension -ne '.log' }) {
        $records += [ordered]@{
            path = $file.FullName.Substring($directory.Length + 1).Replace('\', '/')
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        }
    }
    Write-PublishJson "$directory/manifest.json" ([ordered]@{ schema = 1; slug = $Info.Slug; targets = $Info.Targets; created_utc = [DateTime]::UtcNow.ToString('o'); files = $records })
    # The pointer changes only after every export and the packaging succeeded.
    Write-PublishJson "$buildRoot/latest.tmp" @{ id = $id }
    Move-Item -LiteralPath "$buildRoot/latest.tmp" -Destination "$buildRoot/latest.json" -Force
    return Read-PublishBuild $Info
}

function Read-PublishBuild($Info) {
    $buildRoot = Join-Path $Info.Root 'builds/publish'
    $pointer = Join-Path $buildRoot 'latest.json'
    if (-not (Test-Path -LiteralPath $pointer)) { throw 'No completed build. Run .\publish.ps1 -BuildOnly first.' }
    $id = (Get-Content -LiteralPath $pointer -Raw | ConvertFrom-Json).id
    if ($id -notmatch '^[a-f0-9]{32}$') { throw 'Invalid build pointer.' }
    $directory = Join-Path $buildRoot $id
    $manifest = Get-Content -LiteralPath "$directory/manifest.json" -Raw | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.slug -ne $Info.Slug) { throw 'Invalid build manifest.' }
    $folders = @('windows')
    $required = @("windows/$($Info.Exe)", "$($Info.Slug)_windows.zip")
    if ($Info.Web) {
        $folders += 'web'
        $required += $script:WebFiles | ForEach-Object { "web/$_" }
    }
    $pattern = '^((' + ($folders -join '|') + ')/[a-zA-Z0-9._-]+|[a-z0-9_-]+_windows\.zip)$'
    $paths = @{}
    foreach ($record in $manifest.files) {
        if ($record.path -notmatch $pattern -or $paths.ContainsKey($record.path)) { throw 'Invalid or duplicate build file path.' }
        $paths[$record.path] = $true
        $file = Join-Path $directory $record.path
        if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $record.sha256) {
            throw "Build file missing or changed: $($record.path). Rebuild before publishing."
        }
    }
    foreach ($path in $required) {
        if (-not $paths.ContainsKey($path)) { throw "Build manifest missing $path" }
    }
    foreach ($folder in $folders) {
        foreach ($file in Get-ChildItem -LiteralPath "$directory/$folder" -Recurse -File -Force) {
            if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -or -not $paths.ContainsKey($file.FullName.Substring($directory.Length + 1).Replace('\', '/'))) {
                throw 'Untracked or linked file in build. Rebuild before publishing.'
            }
        }
    }
    return [pscustomobject]@{ Directory = $directory; Manifest = $manifest }
}

# A Windows-only game's web page: a download page generated from download.html.
function New-PublishDownloadPage($Info, [string]$Path) {
    $page = Get-Content -LiteralPath (Get-PublishAsset $Info 'download.html') -Raw
    $page = $page.Replace('{{TITLE}}', [Net.WebUtility]::HtmlEncode([string](Get-PublishProperty $Info.Config 'display_name' $Info.Slug)))
    $page = $page.Replace('{{DESCRIPTION}}', [Net.WebUtility]::HtmlEncode([string](Get-PublishProperty $Info.Config 'description' '')))
    $page = $page.Replace('{{ZIP}}', "$($Info.Slug)_windows.zip")
    $page = $page.Replace('{{BUILT}}', [DateTime]::UtcNow.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture))
    [IO.File]::WriteAllText($Path, $page, [Text.UTF8Encoding]::new($false))
}

# The files a deployment holds, index.html last so a half-finished upload is
# never the page players load: [{ Source; Name }].
function Get-PublishSiteFiles($Build, $Info) {
    $files = @()
    if ($Info.Web) {
        foreach ($file in Get-ChildItem -LiteralPath "$($Build.Directory)/web" -File | Sort-Object Name) {
            if ($file.Name -ne 'index.html') { $files += [pscustomobject]@{ Source = $file.FullName; Name = $file.Name } }
        }
        $files += [pscustomobject]@{ Source = "$($Build.Directory)/$($Info.Slug)_windows.zip"; Name = "$($Info.Slug)_windows.zip" }
        $files += [pscustomobject]@{ Source = (Get-PublishAsset $Info 'web.htaccess'); Name = '.htaccess' }
        $files += [pscustomobject]@{ Source = "$($Build.Directory)/web/index.html"; Name = 'index.html' }
    } else {
        $page = Join-Path $Build.Directory 'index.html'
        New-PublishDownloadPage $Info $page
        $files += [pscustomobject]@{ Source = "$($Build.Directory)/$($Info.Slug)_windows.zip"; Name = "$($Info.Slug)_windows.zip" }
        $files += [pscustomobject]@{ Source = $page; Name = 'index.html' }
    }
    return $files
}

function Copy-PublishWebsite($Build, $Info, [string]$Destination) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    # Never recursively mirror or delete a deployment directory or its neighbours.
    foreach ($file in Get-PublishSiteFiles $Build $Info) {
        Copy-Item -LiteralPath $file.Source -Destination (Join-Path $Destination $file.Name) -Force
    }
}

. (Join-Path $PSScriptRoot 'PublisherRemote.ps1')
