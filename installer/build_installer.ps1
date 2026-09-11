# ============================================================================
#  build_installer.ps1
#  Membangun installer Windows "Manafidh Store" dalam satu perintah:
#    1. flutter build windows --release
#    2. Menyalin runtime Visual C++ (app-local) ke folder Release
#    3. Mengompilasi installer dengan Inno Setup (ISCC.exe)
#
#  Prasyarat: Flutter SDK & Inno Setup 6 (https://jrsoftware.org/isdl.php).
#
#  Jalankan dari mana saja:
#    powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1
#  Opsi:
#    -SkipBuild   : lewati "flutter build" (pakai folder Release yang sudah ada)
#    powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1 -SkipBuild
# ============================================================================
param(
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

# Folder proyek = induk dari folder installer\ tempat skrip ini berada.
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ReleaseDir  = Join-Path $ProjectRoot 'build\windows\x64\runner\Release'
$IssFile     = Join-Path $PSScriptRoot 'manafidh_store.iss'

Write-Host "Proyek     : $ProjectRoot"
Write-Host "Release dir: $ReleaseDir"
Write-Host ""

# --- 1. Build release -------------------------------------------------------
if (-not $SkipBuild) {
    Write-Host "==> [1/3] flutter build windows --release" -ForegroundColor Cyan
    Push-Location $ProjectRoot
    try {
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build gagal (exit $LASTEXITCODE)." }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "==> [1/3] Lewati build (-SkipBuild)" -ForegroundColor Yellow
}

$exe = Join-Path $ReleaseDir 'myapp.exe'
if (-not (Test-Path $exe)) {
    throw "myapp.exe tidak ditemukan di $ReleaseDir. Jalankan tanpa -SkipBuild."
}

# --- 2. Salin runtime Visual C++ (app-local) --------------------------------
Write-Host "==> [2/3] Menyalin runtime Visual C++ ke folder Release" -ForegroundColor Cyan
$sys = Join-Path $env:WINDIR 'System32'
$runtimeDlls = @(
    'VCRUNTIME140.dll', 'VCRUNTIME140_1.dll', 'MSVCP140.dll',
    'MSVCP140_1.dll', 'MSVCP140_2.dll', 'MSVCP140_CODECVT_IDS.dll', 'CONCRT140.dll'
)
foreach ($dll in $runtimeDlls) {
    $src = Join-Path $sys $dll
    if (Test-Path $src) {
        Copy-Item $src $ReleaseDir -Force
        Write-Host "    + $dll"
    } else {
        Write-Warning "    ! $dll tidak ada di System32 - dilewati."
    }
}

# --- 3. Kompilasi installer dengan Inno Setup -------------------------------
Write-Host "==> [3/3] Mengompilasi installer dengan Inno Setup" -ForegroundColor Cyan
$pf86 = ${env:ProgramFiles(x86)}
$pf   = $env:ProgramFiles
$isccCandidates = @()
if ($pf86) { $isccCandidates += (Join-Path $pf86 'Inno Setup 6\ISCC.exe') }
if ($pf)   { $isccCandidates += (Join-Path $pf   'Inno Setup 6\ISCC.exe') }
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    throw "ISCC.exe (Inno Setup 6) tidak ditemukan. Install dulu dari https://jrsoftware.org/isdl.php"
}

& $iscc $IssFile
if ($LASTEXITCODE -ne 0) { throw "Kompilasi Inno Setup gagal (exit $LASTEXITCODE)." }

$outDir = Join-Path $PSScriptRoot 'output'
Write-Host ""
Write-Host "SELESAI. Installer ada di: $outDir" -ForegroundColor Green
Get-ChildItem $outDir -Filter *.exe -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 |
    ForEach-Object { Write-Host ("  -> " + $_.FullName) -ForegroundColor Green }
