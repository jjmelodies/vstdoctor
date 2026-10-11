# test-all-shapes.ps1 — configure + build the template for every PLUGIN_SHAPE
# value, verifying all four code paths through CMakeLists.txt compile correctly.
#
# Uses a single temporary build tree (Builds-ShapeTest/) that is deleted on
# completion, leaving your working Builds/ untouched.  ProductConfig.cmake is
# patched per shape and restored in a finally block (survives Ctrl+C).
#
# Usage:
#   pwsh -File tools\test-all-shapes.ps1
#   pwsh -File tools\test-all-shapes.ps1 -BuildType Release
#   pwsh -File tools\test-all-shapes.ps1 -Shapes FX,Synth      # subset

[CmdletBinding()]
param(
    [ValidateSet('Debug','Release','RelWithDebInfo')]
    [string]   $BuildType = 'Debug',
    [string[]] $Shapes    = @('FX','Synth','MIDIFX','MIDIGen'),
    [switch]   $SkipTests,
    [switch]   $KeepBuildDir,
    [switch]   $NoLog
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$cfgPath  = Join-Path $repoRoot 'ProductConfig.cmake'
$buildDir = Join-Path $repoRoot 'Builds-ShapeTest'

if (-not (Test-Path $cfgPath)) { throw "ProductConfig.cmake not found at $cfgPath" }

$transcriptStarted = $false
if (-not $NoLog) {
    $logsDir = Join-Path $repoRoot 'logs'
    if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }
    $logPath = Join-Path $logsDir "test-all-shapes-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    Start-Transcript -Path $logPath -Force | Out-Null
    $transcriptStarted = $true
    Write-Host "[shapes] transcript -> $logPath"
}

$original = Get-Content -Path $cfgPath -Raw
$pattern  = '(?m)^(set\(PLUGIN_SHAPE\s+")([^"]+)("\))'
$match    = [regex]::Match($original, $pattern)
if (-not $match.Success) { throw "Could not locate PLUGIN_SHAPE in ProductConfig.cmake" }
$origShape = $match.Groups[2].Value
Write-Host "[shapes] original PLUGIN_SHAPE = $origShape"
Write-Host "[shapes] build dir             = $buildDir"

$results = @()

try {
    foreach ($shape in $Shapes) {
        Write-Host ""
        Write-Host "================================================================"
        Write-Host "[shapes] PLUGIN_SHAPE = $shape  ($BuildType)"
        Write-Host "================================================================"

        $patched = [regex]::Replace($original, $pattern, "`${1}$shape`${3}")
        [System.IO.File]::WriteAllText($cfgPath, $patched, [System.Text.UTF8Encoding]::new($false))

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $ok = $true
        $stage = ''
        try {
            $stage = 'configure'
            & cmake -B $buildDir -G Ninja "-DCMAKE_BUILD_TYPE=$BuildType"
            if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }

            $stage = 'build'
            & cmake --build $buildDir
            if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }

            if (-not $SkipTests) {
                $stage = 'ctest'
                & ctest --test-dir $buildDir -C $BuildType --output-on-failure
                if ($LASTEXITCODE -ne 0) { throw "ctest failed" }
            }
        } catch {
            $ok = $false
            Write-Host "[shapes] $shape FAILED at $stage : $_" -ForegroundColor Red
        }
        $sw.Stop()
        $results += [pscustomobject]@{
            Shape   = $shape
            Ok      = $ok
            Seconds = [int]$sw.Elapsed.TotalSeconds
        }
    }
} finally {
    [System.IO.File]::WriteAllText($cfgPath, $original, [System.Text.UTF8Encoding]::new($false))
    Write-Host ""
    Write-Host "[shapes] restored ProductConfig.cmake (PLUGIN_SHAPE = $origShape)"

    if (-not $KeepBuildDir -and (Test-Path $buildDir)) {
        Write-Host "[shapes] cleaning up $buildDir"
        Remove-Item -Path $buildDir -Recurse -Force -ErrorAction SilentlyContinue
    }
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
    Write-Host "All shapes built." -ForegroundColor Green
}

if ($transcriptStarted) {
    try { Stop-Transcript | Out-Null } catch { }
}

exit $exitCode
