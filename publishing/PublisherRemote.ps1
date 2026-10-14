# FTP deployment and itch.io (butler) helpers, loaded by Publisher.ps1.
Set-StrictMode -Version Latest

function Get-PublishFtpConfig($Settings, [string]$Slug) {
    $config = @{}
    foreach ($key in @('FTP_SERVER', 'FTP_USERNAME', 'FTP_PASSWORD')) {
        $config[$key] = Get-PublishSetting $Settings $key
        if (-not $config[$key]) { throw "Missing $key. Set it in the environment or the external .env file." }
    }
    if ($config.FTP_SERVER -notmatch '^[a-zA-Z0-9.-]+$') { throw 'FTP_SERVER must be a hostname.' }
    $config.Port = [int](Get-PublishSetting $Settings 'FTP_PORT' '21')
    if ($config.Port -lt 1 -or $config.Port -gt 65535) { throw 'Invalid FTP_PORT.' }
    foreach ($key in @('FTP_USE_SSL', 'FTP_PASSIVE_MODE')) {
        $default = if ($key -eq 'FTP_USE_SSL') { 'false' } else { 'true' }
        $value = Get-PublishSetting $Settings $key $default
        if ($value -notmatch '^(true|false|1|0|yes|no|on|off)$') { throw "Invalid boolean $key" }
        $config[$key] = $value -match '^(true|1|yes|on)$'
    }
    $remoteRoot = (Get-PublishSetting $Settings 'FTP_REMOTE_ROOT' '/').Replace('\', '/').TrimEnd('/')
    if ($remoteRoot -and (-not $remoteRoot.StartsWith('/') -or $remoteRoot -match '(^|/)\.\.?(/|$)')) { throw 'FTP_REMOTE_ROOT must be an absolute path without traversal.' }
    $config.RemoteDirectory = "$remoteRoot/games/$Slug"
    return $config
}

function New-PublishFtpRequest($Config, [string]$Path, [string]$Method) {
    $escaped = (($Path -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
    $request = [Net.FtpWebRequest]::Create("ftp://$($Config.FTP_SERVER):$($Config.Port)$escaped")
    $request.Credentials = [Net.NetworkCredential]::new($Config.FTP_USERNAME, $Config.FTP_PASSWORD)
    $request.Method = $Method
    $request.EnableSsl = $Config.FTP_USE_SSL
    $request.UsePassive = $Config.FTP_PASSIVE_MODE
    $request.UseBinary = $true
    $request.KeepAlive = $false
    $request.Timeout = 60000
    $request.ReadWriteTimeout = 60000
    return $request
}

function Send-PublishWebsite($Build, $Info, $Config) {
    $current = ''
    foreach ($part in $Config.RemoteDirectory.Trim('/').Split('/')) {
        $current += "/$part"
        try { (New-PublishFtpRequest $Config $current 'MKD').GetResponse().Close() }
        catch {
            # Confirm an existing directory instead of treating every 550 as success.
            (New-PublishFtpRequest $Config $current 'NLST').GetResponse().Close()
        }
    }
    foreach ($file in Get-PublishSiteFiles $Build $Info) {
        $length = (Get-Item -LiteralPath $file.Source).Length
        Write-Host "Uploading $($file.Name) ($length bytes)"
        $request = New-PublishFtpRequest $Config "$($Config.RemoteDirectory)/$($file.Name)" 'STOR'
        $request.ContentLength = $length
        $inputStream = [IO.File]::OpenRead($file.Source)
        try {
            $outputStream = $request.GetRequestStream()
            try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
        } finally { $inputStream.Dispose() }
        $request.GetResponse().Close()
    }
}

function Resolve-PublishButler([string]$Requested) {
    if (-not $Requested) { $Requested = $env:BUTLER_EXE }
    if (-not $Requested) {
        $command = Get-Command butler -ErrorAction SilentlyContinue
        if ($command) { $Requested = $command.Source }
    }
    if (-not $Requested) { $Requested = 'D:\WebHatchery\RustGames\rust_management\itch-butler\butler.exe' }
    if (-not (Test-Path -LiteralPath $Requested -PathType Leaf)) { throw 'Butler not found. Pass -ButlerPath or set BUTLER_EXE.' }
    return (Resolve-Path -LiteralPath $Requested).Path
}

# Pushes the latest verified build to each requested itch channel
# ('html5', 'windows', or 'all' for every channel this game builds).
function Invoke-PublishItch($Info, [string]$Channel, [string]$ButlerPath, [string]$UserVersion, [switch]$Preview, [switch]$Status, [switch]$DryRun) {
    $channels = if ($Channel -eq 'all') { @($Info.Itch.Keys | Sort-Object) } else { @($Channel) }
    foreach ($name in $channels) {
        if (-not $Info.Itch.ContainsKey($name)) { throw "This game has no $name build or itch channel." }
    }
    if (-not $Status) { $build = Read-PublishBuild $Info }
    if (-not $DryRun) { $butler = Resolve-PublishButler $ButlerPath }
    foreach ($name in $channels) {
        $target = "$($Info.Config.itch_target):$($Info.Itch[$name])"
        if ($Status) { Invoke-PublishTool $butler @('status', $target); continue }
        $source = if ($name -eq 'html5') { Join-Path $build.Directory 'web' } else { Join-Path $build.Directory 'windows' }
        if ($DryRun) { Write-Host "[dry-run] $source -> $target"; continue }
        if ($Preview) { Invoke-PublishTool $butler @('push-preview', '--changes-only', $source, $target); continue }
        $arguments = @('push', '--assume-yes', '--if-changed')
        if ($name -eq 'html5') { $arguments += '--auto-wrap' }
        if ($UserVersion) { $arguments += @('--userversion', $UserVersion) }
        $arguments += @($source, $target)
        Invoke-PublishTool $butler $arguments
    }
}
