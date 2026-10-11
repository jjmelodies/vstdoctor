# build-all-shape-installers.ps1 — produce a Release installer for every
# PLUGIN_SHAPE into packaging\Output\, named:
#
#   <ProductName>-<Shape>-<Version>-Windows.exe
#
# All shapes share a single BuildsRelease\ tree.  Each iteration
# reconfigures (fast — only the plugin-client TU changes between shapes)
# then builds, runs iscc, and renames the output before the next shape runs.
#
# ProductConfig.cmake is patched per shape and restored (even on Ctrl+C).
#
# Usage (from a Developer Command Prompt for VS 2022):
#   pwsh -File tools\build-all-shape-installers.ps1
#   pwsh -File tools\build-all-shape-installers.ps1 -Shapes FX,Synth
#   pwsh -File tools\build-all-shape-installers.ps1 -SkipTests

[CmdletBinding()]
param(
    [string[]] $Shapes    = @('FX','Synth','MIDIFX','MIDIGen'),
    [string]   $BuildDir  = 'BuildsRelease',
    [switch]   $SkipTests,
    [switch]   $SkipBuild,
    [switch]   $NoLog
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$cfgPath  = Join-Path $repoRoot 'ProductConfig.cmake'
$outDir   = Join-Path $repoRoot 'packaging\Output'

if (-not (Test-Path $cfgPath)) { throw "ProductConfig.cmake not found at $cfgPath" }

$transcriptStarted = $false
if (-not $NoLog) {
    $logsDir = Join-Path $repoRoot 'logs'
    if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }
    $logPath = Join-Path $logsDir "build-all-shape-installers-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    Start-Transcript -Path $logPath -Force | Out-Null
    $transcriptStarted = $true
    Write-Host "[all-shapes] transcript -> $logPath"
}

$original = Get-Content -Path $cfgPath -Raw
$pattern  = '(?m)^(set\(PLUGIN_SHAPE\s+")([^"]+)("\))'
$match    = [regex]::Match($original, $pattern)
if (-not $match.Success) { throw "Could not locate PLUGIN_SHAPE in ProductConfig.cmake" }
$origShape = $match.Groups[2].Value
Write-Host "[all-shapes] original PLUGIN_SHAPE = $origShape"
Write-Host "[all-shapes] build dir             = $BuildDir"

# Read product name + version once.
function Read-CMakeSet { param([string]$Var)
    if ($original -match "set\($Var\s+`"([^`"]+)`"\)") { return $Matches[1] }
    throw "Could not parse $Var from ProductConfig.cmake"
}
$productName = Read-CMakeSet 'PRODUCT_NAME'
$version     = (Get-Content (Join-Path $repoRoot 'VERSION') -Raw).Trim()

# Generate the manual once up front.
$manualPdf = Join-Path $repoRoot 'docs\manual.pdf'
if (-not (Test-Path $manualPdf)) {
    Write-Host "[all-shapes] generating manual.pdf..."
    & (Join-Path $PSScriptRoot 'build-manual.ps1')
    if ($LASTEXITCODE -ne 0) { throw "manual generation failed" }
}

$results = @()

try {
    foreach ($shape in $Shapes) {
        Write-Host ""
        Write-Host "================================================================"
        Write-Host "[all-shapes] PLUGIN_SHAPE = $shape  ->  $BuildDir"
        Write-Host "================================================================"

        $patched = [regex]::Replace($original, $pattern, "`${1}$shape`${3}")
        [System.IO.File]::WriteAllText($cfgPath, $patched, [System.Text.UTF8Encoding]::new($false))

        $sw  = [System.Diagnostics.Stopwatch]::StartNew()
        $ok  = $true
        $out = ''
        try {
            $passArgs = @{ BuildDir = $BuildDir; SkipManual = $true }
            if ($SkipTests) { $passArgs['SkipTests'] = $true }
            if ($SkipBuild)  { $passArgs['SkipBuild'] = $true }

            & (Join-Path $PSScriptRoot 'build-installer.ps1') @passArgs
            if ($LASTEXITCODE -ne 0) { throw "build-installer.ps1 exited $LASTEXITCODE" }

            # Rename before the next shape run overwrites it.
            $generic = Join-Path $outDir "$productName-$version-Windows.exe"
            $shaped  = Join-Path $outDir "$productName-$shape-$version-Windows.exe"
            if (Test-Path $shaped) { Remove-Item $shaped -Force }
            Move-Item -Path $generic -Destination $shaped
            $out = $shaped
            Write-Host "[all-shapes] -> $(Split-Path $shaped -Leaf)"
        } catch {
            $ok = $false
            Write-Host "[all-shapes] $shape FAILED: $_" -ForegroundColor Red
        }
        $sw.Stop()
        $results += [pscustomobject]@{
            Shape   = $shape
            Ok      = $ok
            Seconds = [int]$sw.Elapsed.TotalSeconds
            Output  = if ($out) { Split-Path $out -Leaf } else { '-' }
        }
    }
} finally {
    [System.IO.File]::WriteAllText($cfgPath, $original, [System.Text.UTF8Encoding]::new($false))
    Write-Host ""
    Write-Host "[all-shapes] restored ProductConfig.cmake (PLUGIN_SHAPE = $origShape)"
}

Write-Host ""
Write-Host "================================================================"
Write-Host "Summary"
Write-Host "================================================================"
$results | Format-Table -AutoSize

$exitCode = 0
if ($results | Where-Object { -not $_.Ok }) {
    Write-Host "One or more shapes failed." -ForegroundColor Red
    $exitCode = 1
} else {
    Write-Host "All shape installers built." -ForegroundColor Green
}

if ($transcriptStarted) {
    try { Stop-Transcript | Out-Null } catch { }
}

exit $exitCode
