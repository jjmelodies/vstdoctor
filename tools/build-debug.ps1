# build-debug.ps1 — fast incremental Debug build for day-to-day iteration.
#
# Configures once into Builds/ if not already configured, then builds.
# Subsequent runs skip configure and go straight to ninja — only changed
# files recompile.
#
# Usage:
#   pwsh -File tools\build-debug.ps1
#   pwsh -File tools\build-debug.ps1 -Tests        # also run ctest
#   pwsh -File tools\build-debug.ps1 -Reconfigure  # force cmake re-configure

[CmdletBinding()]
param(
    [switch] $Tests,
    [switch] $Reconfigure
)

$ErrorActionPreference = 'Stop'

$vcvars   = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat'
$repoRoot = Resolve-Path "$PSScriptRoot\.."
$buildDir = Join-Path $repoRoot 'Builds'

if (-not (Test-Path $vcvars)) {
    throw "vcvars64.bat not found at $vcvars — install Visual Studio 2022 with the C++ workload."
}

# Source MSVC environment into this process.
cmd /c "`"$vcvars`" >nul && set" | ForEach-Object {
    if ($_ -match '^([^=]+)=(.*)$') { Set-Item "env:$($Matches[1])" $Matches[2] }
}

$needConfigure = $Reconfigure -or -not (Test-Path (Join-Path $buildDir 'build.ninja'))

if ($needConfigure) {
    Write-Host "[debug] cmake configure -> Builds/"
    & cmake -B $buildDir -G Ninja -DCMAKE_BUILD_TYPE=Debug
    if ($LASTEXITCODE -ne 0) { throw "configure failed" }
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "[debug] cmake build"
& cmake --build $buildDir
if ($LASTEXITCODE -ne 0) { throw "build failed" }
$sw.Stop()
Write-Host ("[debug] built in {0:N1}s" -f $sw.Elapsed.TotalSeconds)

if ($Tests) {
    Write-Host "[debug] ctest"
    & ctest --test-dir $buildDir --output-on-failure
    if ($LASTEXITCODE -ne 0) { throw "tests failed" }
}
