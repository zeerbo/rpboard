# Builds RPBoard for Windows and packages it into installer\output\RPBoard-Setup-<version>.exe
# Usage: powershell -ExecutionPolicy Bypass -File installer\build.ps1

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$InstallerDir = Join-Path $RepoRoot "installer"
$VcRedistPath = Join-Path $InstallerDir "vc_redist.x64.exe"
$VcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"

# --- Read version from pubspec.yaml (drop the +buildNumber suffix) ---
$pubspecPath = Join-Path $RepoRoot "pubspec.yaml"
$versionLine = Select-String -Path $pubspecPath -Pattern '^version:\s*(\S+)' | Select-Object -First 1
if (-not $versionLine) {
    throw "Could not find a 'version:' line in $pubspecPath"
}
$fullVersion = $versionLine.Matches[0].Groups[1].Value
$version = $fullVersion.Split('+')[0]
Write-Host "App version: $version (from pubspec.yaml: $fullVersion)"

# --- Ensure vc_redist.x64.exe is available locally ---
if (-not (Test-Path $VcRedistPath)) {
    Write-Host "vc_redist.x64.exe not found locally, downloading from $VcRedistUrl ..."
    Invoke-WebRequest -Uri $VcRedistUrl -OutFile $VcRedistPath
    Write-Host "Downloaded to $VcRedistPath"
} else {
    Write-Host "vc_redist.x64.exe already present, skipping download."
}

# --- Locate Inno Setup's ISCC.exe ---
$isccCandidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    $onPath = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($onPath) { $iscc = $onPath.Source }
}
if (-not $iscc) {
    throw "ISCC.exe (Inno Setup compiler) not found. Install it with: winget install JRSoftware.InnoSetup"
}
Write-Host "Using Inno Setup compiler: $iscc"

# --- Build the Flutter Windows release ---
Write-Host "Running 'flutter build windows --release' ..."
Push-Location $RepoRoot
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

# --- Compile the installer ---
Write-Host "Compiling installer with Inno Setup ..."
& $iscc "/DMyAppVersion=$version" (Join-Path $InstallerDir "setup.iss")
if ($LASTEXITCODE -ne 0) { throw "ISCC failed with exit code $LASTEXITCODE" }

$outputExe = Join-Path $InstallerDir "output\RPBoard-Setup-$version.exe"
Write-Host ""
Write-Host "Installer ready: $outputExe"
