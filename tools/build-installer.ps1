# build-installer.ps1 — produce a release Windows installer end-to-end.
#
# Pipeline:
#   1. Read product identity from ProductConfig.cmake.
#   2. Configure + build a Release tree under BuildsRelease\.
#   3. Optional ctest gate.
#   4. Regenerate docs\manual.pdf (skip with -SkipManual).
#   5. Compile packaging\installer.iss with iscc.exe.
#   6. Report final installer path under packaging\Output\.
#
# Usage (from a Developer Command Prompt for VS 2022):
#   pwsh -File tools\build-installer.ps1
#   pwsh -File tools\build-installer.ps1 -SkipTests
#   pwsh -File tools\build-installer.ps1 -SkipManual

[CmdletBinding()]
param(
    [switch] $SkipTests,
    [switch] $SkipManual,
    [switch] $SkipBuild,
    [string] $BuildDir = "BuildsRelease"
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path "$PSScriptRoot\.."
Set-Location $repoRoot

# .iss reads this to locate <BuildDir>/<PROJECT_NAME>_artefacts/Release/.
$env:PLUGIN_BUILD_DIR = $BuildDir

function Require-Tool {
    param([string] $Name, [string] $Hint)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required tool '$Name' not found on PATH. $Hint"
    }
}

# 1. Product identity from ProductConfig.cmake
$productCfg = Get-Content (Join-Path $repoRoot 'ProductConfig.cmake') -Raw
function Read-CMakeSet {
    param([string] $Var)
    if ($productCfg -match "set\($Var\s+`"([^`"]+)`"\)") { return $Matches[1] }
    throw "Could not parse $Var from ProductConfig.cmake"
}
$env:PROJECT_NAME = Read-CMakeSet 'PROJECT_NAME'
$env:PRODUCT_NAME = Read-CMakeSet 'PRODUCT_NAME'
$env:COMPANY_NAME = Read-CMakeSet 'COMPANY_NAME'
$version = (Get-Content (Join-Path $repoRoot 'VERSION') -Raw).Trim()

Write-Host "[installer] PROJECT_NAME=$($env:PROJECT_NAME)"
Write-Host "[installer] PRODUCT_NAME=$($env:PRODUCT_NAME)"
Write-Host "[installer] COMPANY_NAME=$($env:COMPANY_NAME)"
Write-Host "[installer] VERSION     =$version"

# 2. Build Release
if ($SkipBuild) {
    Write-Host "[installer] skipping build (using existing $BuildDir tree)"
} else {
    Require-Tool cmake "Install CMake >= 3.25 and add it to PATH."
    Require-Tool ninja "Install Ninja and add it to PATH (or run from a VS Developer shell)."

    Write-Host "[installer] cmake configure (Release) -> $BuildDir"
    & cmake -B $BuildDir -G Ninja -DCMAKE_BUILD_TYPE=Release
    if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }

    Write-Host "[installer] cmake build (Release)"
    & cmake --build $BuildDir --config Release
    if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }

    if (-not $SkipTests) {
        Write-Host "[installer] ctest"
        & ctest --test-dir $BuildDir -C Release --output-on-failure
        if ($LASTEXITCODE -ne 0) { throw "tests failed (re-run with -SkipTests to bypass)" }
    }
}

$vst3 = Join-Path $repoRoot "$BuildDir\$($env:PROJECT_NAME)_artefacts\Release\VST3\$($env:PRODUCT_NAME).vst3"
$exe  = Join-Path $repoRoot "$BuildDir\$($env:PROJECT_NAME)_artefacts\Release\Standalone\$($env:PRODUCT_NAME).exe"
if (-not (Test-Path $vst3)) { throw "VST3 bundle missing at $vst3" }
if (-not (Test-Path $exe))  { throw "Standalone exe missing at $exe" }

# 3. Manual PDF
$manualPdf = Join-Path $repoRoot 'docs\manual.pdf'
if ($SkipManual) {
    if (-not (Test-Path $manualPdf)) {
        throw "-SkipManual requested but $manualPdf is missing. Drop the flag or generate it once."
    }
    Write-Host "[installer] skipping manual regen (using existing $manualPdf)"
} else {
    & (Join-Path $PSScriptRoot 'build-manual.ps1')
    if ($LASTEXITCODE -ne 0) { throw "manual generation failed" }
}

# 4. Inno Setup
$iscc = $null
foreach ($candidate in @(
    'iscc',
    'C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    'C:\Program Files\Inno Setup 6\ISCC.exe',
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)) {
    $found = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($found) { $iscc = $found.Source; break }
    if (Test-Path $candidate) { $iscc = $candidate; break }
}
if (-not $iscc) {
    throw "Inno Setup compiler (iscc.exe) was not found. Install: winget install --id JRSoftware.InnoSetup"
}
Write-Host "[installer] using iscc: $iscc"

$iss = Join-Path $repoRoot 'packaging\installer.iss'
& $iscc /Q $iss
if ($LASTEXITCODE -ne 0) { throw "iscc failed with exit code $LASTEXITCODE" }

# 5. Report
$out = Join-Path $repoRoot "packaging\Output\$($env:PRODUCT_NAME)-$version-Windows.exe"
if (-not (Test-Path $out)) {
    throw "iscc completed but expected output is missing: $out"
}
Write-Host ""
Write-Host "[installer] DONE -> $out"
$size = (Get-Item $out).Length
Write-Host ("[installer] size  -> {0:N0} bytes ({1:N1} MB)" -f $size, ($size / 1MB))
