# Build POSAce Windows App & Installer
# Usage: .\scripts\build_setup.ps1

$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Build Process..." -ForegroundColor Cyan

# 1. Flutter Build
Write-Host "🛠 Building Flutter Windows App..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter Build Failed" -ForegroundColor Red
    exit 1
}

# 2. Inno Setup Compiler Path
# Check for common Inno Setup paths (v5 or v6)
$isccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $isccPath)) {
    $isccPath = "C:\Program Files (x86)\Inno Setup 5\ISCC.exe"
}

if (-not (Test-Path $isccPath)) {
    Write-Host "❌ Inno Setup compiler (ISCC.exe) not found." -ForegroundColor Red
    Write-Host "Please install Inno Setup 5 or 6."
    exit 1
}

Write-Host "📦 Compiling Installer using $isccPath..." -ForegroundColor Yellow

# 3. Run ISCC
& $isccPath "installers\setup.iss"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Installer created successfully!" -ForegroundColor Green
    Write-Host "File location: installers\Output\POSAce_Setup.exe" -ForegroundColor Green
} else {
    Write-Host "❌ Installer compilation failed." -ForegroundColor Red
    exit 1
}
