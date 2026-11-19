param(
    [Parameter(Mandatory, Position=0)]
    [ValidateSet('Install','Remove','Watch','CreateShortcut','RemoveShortcut','Launch')] [string]$Action,
    [string]$AstrBotExe, [string]$PythonExe, [string]$CodexExe,
    [ValidateRange(1,65535)] [int]$Port = 8787,
    [string]$BridgeStartScript, [string]$NapCatStartScript,
    [ValidateRange(0,65535)] [int]$NapCatPort
)
$ErrorActionPreference = 'Stop'
$state = Join-Path $env:LOCALAPPDATA 'astrbot-codex-bridge'
$config = Join-Path $state 'desktop-follow.json'
$startup = [Environment]::GetFolderPath('Startup')
$link = Join-Path $startup 'AstrBot Codex Bridge - Desktop follow.lnk'
$isShortcut = $Action -in @('CreateShortcut','RemoveShortcut','Launch')
if ($isShortcut) {
    $startup = [Environment]::GetFolderPath('DesktopDirectory')
    $link = Join-Path $startup 'AstrBot + NapCat + Codex Bridge.lnk'
    $config = Join-Path $state 'desktop-launcher.json'
}
$shell = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path -LiteralPath $shell)) { $shell = Join-Path $PSHOME 'pwsh.exe' }

function Get-FilePath([string]$Path, [string]$Extension) {
    $file = Get-Item -LiteralPath $Path
    if ($file.PSIsContainer -or $file.Extension -ne $Extension) { throw "Expected a $Extension file: $Path" }
    return $file.FullName
}
function Test-Listening([int]$Number) {
    $socket = [Net.Sockets.TcpClient]::new()
    try { $socket.Connect('127.0.0.1', $Number); return $true }
    catch [Net.Sockets.SocketException] { return $false }
    finally { $socket.Dispose() }
}
function Start-Script([string]$FilePath) {
    if ([IO.Path]::GetExtension($FilePath) -eq '.bat') {
        Start-Process -FilePath $FilePath -WorkingDirectory (Split-Path -LiteralPath $FilePath) -WindowStyle Hidden
        return
    }
    Start-Process -FilePath $shell -ArgumentList ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $FilePath + '"') -WindowStyle Hidden
}
function Start-Companions($settings) {
    if (-not (Test-Listening $settings.port)) {
        if ($settings.bridgeScript) { Start-Script $settings.bridgeScript }
        else {
            $argsLine = '-B -X utf8 "' + $settings.entry + '" --port ' + $settings.port
            if ($settings.codex) { $argsLine += ' --codex "' + $settings.codex + '"' }
            Start-Process -FilePath $settings.python -ArgumentList $argsLine -WindowStyle Hidden -WorkingDirectory $state -RedirectStandardOutput (Join-Path $state 'desktop-bridge.out.log') -RedirectStandardError (Join-Path $state 'desktop-bridge.err.log')
        }
    }
    if ($settings.napcatScript -and -not (Test-Listening $settings.napcatPort)) { Start-Script $settings.napcatScript }
}
function Get-DesktopProcess($settings) {
    $session = [Diagnostics.Process]::GetCurrentProcess().SessionId
    Get-Process -Name AstrBot -ErrorAction SilentlyContinue | Where-Object {
        $_.SessionId -eq $session -and $_.Path -eq $settings.desktop
    } | Select-Object -First 1
}
if ($Action -in @('Remove','RemoveShortcut')) {
    foreach ($file in @($link, $config)) {
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
    }
    Write-Output "Removed $link. Running applications keep their current state."
    return
}
if ($Action -in @('Install','CreateShortcut')) {
    $desktop = Get-FilePath $AstrBotExe '.exe'
    if ([IO.Path]::GetFileName($desktop) -ne 'AstrBot.exe') { throw 'Select the original AstrBot.exe.' }
    if ($BridgeStartScript) { $BridgeStartScript = Get-FilePath $BridgeStartScript '.ps1' }
    else {
        $PythonExe = Get-FilePath $PythonExe '.exe'
        & $PythonExe -c 'import sys; sys.exit(sys.version_info < (3,10))'
        if ($LASTEXITCODE -ne 0) { throw 'Python 3.10+ is required.' }
    }
    if ($CodexExe) { $CodexExe = Get-FilePath $CodexExe '.exe' }
    if ($isShortcut -and !$NapCatStartScript) { throw 'The three-app shortcut requires the existing NapCat launcher and port.' }
    if ($NapCatStartScript) {
        if (!$NapCatPort -or $NapCatPort -eq $Port) { throw 'Supply the separate local port of this NapCat instance.' }
        $ext = [IO.Path]::GetExtension($NapCatStartScript)
        if ($ext -notin @('.ps1','.bat')) { throw 'Select the NapCat .ps1 or .bat startup script.' }
        $NapCatStartScript = Get-FilePath $NapCatStartScript $ext
    }
    $entry = (Get-Item -LiteralPath (Join-Path $PSScriptRoot 'codex_bridge.py')).FullName
    $settings = @{ desktop=$desktop; python=$PythonExe; codex=$CodexExe; port=$Port; entry=$entry
        bridgeScript=$BridgeStartScript; napcatScript=$NapCatStartScript; napcatPort=$NapCatPort
        revision=[guid]::NewGuid().ToString() }
    New-Item -Type Directory -Path $state,$startup -Force | Out-Null
    $temp = Join-Path $state ($settings.revision + '.tmp')
    [IO.File]::WriteAllText($temp, ($settings | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    if ([IO.File]::Exists($config)) { [IO.File]::Replace($temp, $config, [System.Management.Automation.Language.NullString]::Value) }
    else { [IO.File]::Move($temp, $config) }
    $next = if ($isShortcut) { 'Launch' } else { 'Watch' }
    $arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" ' + $next
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($link)
    $shortcut.TargetPath = $shell
    $shortcut.Arguments = $arguments
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.IconLocation = "$desktop,0"
    $shortcut.Save()
    if ($isShortcut) { Write-Output $link; return }
    Start-Process -FilePath $shell -ArgumentList $arguments -WindowStyle Hidden
    Write-Output "Desktop follow enabled for $desktop"
    return
}

if ($Action -eq 'Launch') {
    $guard = [Threading.Mutex]::new($false, 'Local\AstrBotCodexBridgeDesktopLaunch')
    try {
        try { $owned = $guard.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owned = $true }
        if (!$owned) { return }
        $settings = Get-Content -LiteralPath $config -Raw -Encoding UTF8 | ConvertFrom-Json
        if (!(Get-DesktopProcess $settings)) {
            Start-Process -FilePath $settings.desktop -WorkingDirectory (Split-Path -LiteralPath $settings.desktop)
        }
        Start-Companions $settings
        $until = [DateTime]::UtcNow.AddSeconds(60)
        do {
            if ((Test-Listening $settings.port) -and (Test-Listening $settings.napcatPort) -and (Get-DesktopProcess $settings)) { return }
            Start-Sleep -Milliseconds 500
        } while ([DateTime]::UtcNow -lt $until)
        throw 'Check the AstrBot window, NapCat WebUI port and bridge startup logs.'
    } catch {
        Add-Content -LiteralPath (Join-Path $state 'desktop-launcher.log') -Value "$([DateTime]::Now) $_"
        (New-Object -ComObject WScript.Shell).Popup($_.Exception.Message, 20, 'AstrBot + NapCat + Codex Bridge', 48) | Out-Null
        throw
    } finally {
        if ($owned) { $guard.ReleaseMutex() }
        $guard.Dispose()
    }
}

$mutex = [Threading.Mutex]::new($false, 'Local\AstrBotCodexBridgeDesktopFollow')
try {
    try { $owns = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $owns = $true }
    if (-not $owns) { return }
    $lastLaunch = ''
    while (Test-Path -LiteralPath $config) {
        $settings = Get-Content -LiteralPath $config -Raw -Encoding UTF8 | ConvertFrom-Json
        $desktop = Get-DesktopProcess $settings
        if ($desktop) {
            $launch = "$($settings.revision)/$($desktop.Id)"
            if ($launch -ne $lastLaunch) {
                $lastLaunch = $launch
                try {
                    Start-Companions $settings
                } catch { Add-Content -LiteralPath (Join-Path $state 'desktop-follow.log') -Value "$([DateTime]::Now) $_" }
            }
        } else { $lastLaunch = '' }
        Start-Sleep -Seconds 3
    }
} finally {
    if ($owns) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
