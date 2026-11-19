param([string]$Destination = (Join-Path $env:LOCALAPPDATA 'astrbot-codex-bridge\NapCat'))
$ErrorActionPreference = 'Stop'
if ([Environment]::Is64BitOperatingSystem -eq $false -or
    ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64' -and $env:PROCESSOR_ARCHITEW6432 -ne 'AMD64')) {
    throw 'This NapCat installer supports Windows x64.'
}
$Destination = [IO.Path]::GetFullPath($Destination)
function Get-Launcher([string]$Directory) {
    $files = @(Get-ChildItem -LiteralPath $Directory -Recurse -File -Filter 'napcat.bat')
    if ($files.Count -gt 1) { throw 'Multiple NapCat launchers found. Select the intended instance manually.' }
    if ($files.Count) { return $files[0].FullName }
}
if (Test-Path -LiteralPath $Destination) {
    $existing = Get-Launcher $Destination
    if ($existing) { Write-Output $existing; return }
    throw "Choose a new destination or finish the existing installation in $Destination."
}
$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/NapNeko/NapCatQQ/releases/latest' -Headers @{'User-Agent'='AstrBot-Codex-Bridge-Setup'}
$asset = $release.assets | Where-Object name -eq 'NapCat.Shell.Windows.OneKey.zip' | Select-Object -First 1
if (!$asset -or !$asset.browser_download_url.StartsWith('https://github.com/NapNeko/NapCatQQ/releases/download/', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Official Windows OneKey asset unavailable. Check https://github.com/NapNeko/NapCatQQ/releases.'
}
$work = Join-Path ([IO.Path]::GetTempPath()) ('napcat-setup-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $work | Out-Null
$archive = Join-Path $work 'OneKey.zip'
try {
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $archive
    if ((Get-Item -LiteralPath $archive).Length -ne $asset.size) { throw 'Incomplete NapCat download.' }
    if ($asset.digest -and $asset.digest -ne ('sha256:' + (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash)) {
        throw 'NapCat archive checksum mismatch.'
    }
    Expand-Archive -LiteralPath $archive -DestinationPath $Destination
} finally {
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive }
    if (!(Get-ChildItem -LiteralPath $work -Force)) { [IO.Directory]::Delete($work) }
}
$installer = @(Get-ChildItem -LiteralPath $Destination -Recurse -File -Filter NapCatInstaller.exe)
if ($installer.Count -ne 1) { throw "Inspect the official installation package in $Destination." }
Write-Host "Installing NapCat $($release.tag_name) from the official Windows OneKey release."
$p = Start-Process -FilePath $installer[0].FullName -WorkingDirectory $installer[0].DirectoryName -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "NapCat installer exit code $($p.ExitCode). See $Destination." }
$launcher = Get-Launcher $Destination
if (!$launcher) { throw "Install did not produce napcat.bat in $Destination." }
Write-Output $launcher
