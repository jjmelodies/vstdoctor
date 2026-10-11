# build-manual.ps1 — regenerate docs/manual.pdf from docs/manual.md.
# Preferred: pandoc + wkhtmltopdf. Fallback: tools/build-manual-fallback.py (reportlab).

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$src = Join-Path $repoRoot 'docs\manual.md'
$dst = Join-Path $repoRoot 'docs\manual.pdf'

if (-not (Test-Path $src)) {
    throw "Source not found: $src"
}

# Title/author from env vars set by build-installer.ps1; fall back to placeholders
# if the user runs build-manual.ps1 standalone.
$title = if ($env:PRODUCT_NAME) { "$env:PRODUCT_NAME User Manual" } else { "User Manual" }
$author = if ($env:COMPANY_NAME) { $env:COMPANY_NAME } else { "" }

$pandoc = Get-Command pandoc -ErrorAction SilentlyContinue
if ($pandoc) {
    Write-Host "[manual] pandoc -> $dst"
    & pandoc $src `
        -o $dst `
        --pdf-engine=wkhtmltopdf `
        --metadata "title=$title" `
        --metadata "author=$author" `
        --toc `
        --toc-depth=2 `
        -V margin-top=20mm `
        -V margin-bottom=20mm `
        -V margin-left=20mm `
        -V margin-right=20mm
    if ($LASTEXITCODE -ne 0) { throw "pandoc failed with exit code $LASTEXITCODE" }
} else {
    Write-Host "[manual] pandoc not found; using Python fallback"
    $py = Get-Command py -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $py) {
        throw "Neither pandoc nor python found on PATH. Install pandoc (winget install JohnMacFarlane.Pandoc) or Python 3."
    }
    & $py.Source (Join-Path $PSScriptRoot 'build-manual-fallback.py')
    if ($LASTEXITCODE -ne 0) { throw "fallback failed with exit code $LASTEXITCODE" }
}

Write-Host "[manual] wrote $dst"
