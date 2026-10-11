# install-pluginval.ps1 — download Tracktion pluginval into tools/.
#
# Usage:
#   pwsh -File tools\install-pluginval.ps1
#   pwsh -File tools\install-pluginval.ps1 -Force        # overwrite existing
#
# pluginval.exe is gitignored; this script reproduces it on a fresh checkout.

[CmdletBinding()]
param(
    [switch] $Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$dest     = Join-Path $repoRoot 'tools\pluginval.exe'

if ((Test-Path $dest) -and -not $Force) {
    Write-Host "[pluginval] already present at $dest (use -Force to overwrite)"
    & $dest --version
    return
}

$url = 'https://github.com/Tracktion/pluginval/releases/latest/download/pluginval_Windows.zip'
$tmp = Join-Path $env:TEMP "pluginval-$([guid]::NewGuid()).zip"
$ext = Join-Path $env:TEMP "pluginval-$([guid]::NewGuid())"

try {
    Write-Host "[pluginval] downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing

    Write-Host "[pluginval] extracting"
    Expand-Archive -Path $tmp -DestinationPath $ext -Force

    $exe = Get-ChildItem -Path $ext -Recurse -Filter 'pluginval.exe' | Select-Object -First 1
    if (-not $exe) { throw "pluginval.exe not found in archive" }

    Copy-Item -Path $exe.FullName -Destination $dest -Force
    Write-Host "[pluginval] installed -> $dest"
    & $dest --version
} finally {
    if (Test-Path $tmp) { Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue }
    if (Test-Path $ext) { Remove-Item -Path $ext -Recurse -Force -ErrorAction SilentlyContinue }
}
