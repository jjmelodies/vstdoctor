# regen-appid.ps1 — replace the Inno Setup AppId GUID in packaging/installer.iss.
#
# Run this ONCE after forking the template, before the first public release.
# After shipping, NEVER change AppId — Add/Remove Programs keys on it; rotating
# orphans existing installs and turns upgrades into parallel installs.
#
# Usage:
#   pwsh -File tools\regen-appid.ps1                    # interactive confirm
#   pwsh -File tools\regen-appid.ps1 -Force             # no prompt
#   pwsh -File tools\regen-appid.ps1 -Guid <UUID>       # use a specific GUID

[CmdletBinding()]
param(
    [string] $Guid,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$iss      = Join-Path $repoRoot 'packaging\installer.iss'

if (-not (Test-Path $iss)) { throw "installer.iss not found at $iss" }

if (-not $Guid) {
    $Guid = [guid]::NewGuid().ToString().ToUpper()
} else {
    try { [guid]::Parse($Guid) | Out-Null }
    catch { throw "'$Guid' is not a valid GUID" }
    $Guid = $Guid.ToUpper().Trim('{','}')
}

$content = Get-Content -Path $iss -Raw
$pattern = '(?m)^(AppId=\{\{)([0-9A-Fa-f-]+)(\})'
$match   = [regex]::Match($content, $pattern)
if (-not $match.Success) {
    throw "No 'AppId={{<guid>}}' line found in $iss"
}

$old = $match.Groups[2].Value
if ($old -ieq $Guid) {
    Write-Host "[appid] already set to $Guid; no change"
    return
}

if (-not $Force) {
    Write-Host "[appid] file: $iss"
    Write-Host "[appid]  old: $old"
    Write-Host "[appid]  new: $Guid"
    Write-Host ""
    Write-Host "WARNING: only run this BEFORE the first public release. After shipping," -ForegroundColor Yellow
    Write-Host "rotating AppId orphans existing installs in Add/Remove Programs."        -ForegroundColor Yellow
    $reply = Read-Host "Proceed? (y/N)"
    if ($reply -notmatch '^(y|yes)$') { Write-Host "aborted"; return }
}

$updated = [regex]::Replace($content, $pattern, "`${1}$Guid`${3}")
[System.IO.File]::WriteAllText($iss, $updated, [System.Text.UTF8Encoding]::new($false))

Write-Host "[appid] $iss -> {{$Guid}}"
