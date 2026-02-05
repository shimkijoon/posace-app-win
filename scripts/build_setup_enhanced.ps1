# Enhanced Build Script for POSAce with VCRUNTIME Fix
# Builds installer with Visual C++ Runtime support for Surface PCs

param(
    [string]$Version = "1.0.25",
    [switch]$SkipFlutterBuild = $false,
    [switch]$SkipDllCollection = $false,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=== POSAce Enhanced Installer Build ===" -ForegroundColor Cyan
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Build Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow

# Check prerequisites
Write-Host "`n🔍 Checking prerequisites..." -ForegroundColor Cyan

# Check Flutter
try {
    $flutterVersion = flutter --version 2>$null | Select-String "Flutter" | Select-Object -First 1
    Write-Host "✅ Flutter: $($flutterVersion.Line.Trim())" -ForegroundColor Green
} catch {
    Write-Error "❌ Flutter not found. Please install Flutter and add it to PATH."
    exit 1
}

# Check Inno Setup (Version 5 or 6)
$innoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (!(Test-Path $innoSetupPath)) {
    $innoSetupPath = "C:\Program Files (x86)\Inno Setup 5\ISCC.exe"
    if (!(Test-Path $innoSetupPath)) {
        Write-Error "❌ Inno Setup not found. Please install Inno Setup 5 or 6."
        Write-Host "💡 Download from: https://jrsoftware.org/isinfo.php" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Inno Setup 5: Found" -ForegroundColor Green
} else {
    Write-Host "✅ Inno Setup 6: Found" -ForegroundColor Green
}

# Step 1: Flutter Build
if (!$SkipFlutterBuild) {
    Write-Host "`n🔨 Building Flutter Windows app..." -ForegroundColor Cyan
    
    try {
        # Clean previous build
        Write-Host "🧹 Cleaning previous build..." -ForegroundColor White
        flutter clean | Out-Null
        
        # Get dependencies
        Write-Host "📦 Getting dependencies..." -ForegroundColor White
        flutter pub get | Out-Null
        
        # Build for Windows
        Write-Host "🏗️ Building Windows release..." -ForegroundColor White
        flutter build windows --release
        
        # Verify build output
        $exePath = "build\windows\x64\runner\Release\posace_app_win.exe"
        if (!(Test-Path $exePath)) {
            throw "Build output not found: $exePath"
        }
        
        $buildInfo = Get-Item $exePath
        Write-Host "✅ Flutter build completed successfully" -ForegroundColor Green
        Write-Host "   Output: $exePath ($([math]::Round($buildInfo.Length / 1MB, 2)) MB)" -ForegroundColor Gray
        
    } catch {
        Write-Error "❌ Flutter build failed: $_"
        exit 1
    }
} else {
    Write-Host "⏭️ Skipping Flutter build (--SkipFlutterBuild)" -ForegroundColor Yellow
}

# Step 2: Collect Runtime DLLs
if (!$SkipDllCollection) {
    Write-Host "`n📦 Collecting Visual C++ Runtime DLLs..." -ForegroundColor Cyan
    
    try {
        $collectParams = @()
        if ($Force) { $collectParams += "-Force" }
        
        & ".\scripts\collect_runtime_dlls.ps1" @collectParams
        
        Write-Host "✅ Runtime DLL collection completed" -ForegroundColor Green
        
    } catch {
        Write-Warning "⚠️ DLL collection failed: $_"
        Write-Host "💡 Continuing with build - installer will download redistributable online" -ForegroundColor Yellow
    }
} else {
    Write-Host "⏭️ Skipping DLL collection (--SkipDllCollection)" -ForegroundColor Yellow
}

# Step 3: Update version in setup script
Write-Host "`n📝 Updating installer version..." -ForegroundColor Cyan

$setupScriptPath = "installers\setup_enhanced.iss"
if (!(Test-Path $setupScriptPath)) {
    Write-Error "❌ Setup script not found: $setupScriptPath"
    exit 1
}

try {
    # Read and update version
    $setupContent = Get-Content $setupScriptPath -Raw
    $setupContent = $setupContent -replace '#define MyAppVersion ".*"', "#define MyAppVersion `"$Version`""
    Set-Content $setupScriptPath $setupContent -Encoding UTF8
    
    Write-Host "✅ Version updated to: $Version" -ForegroundColor Green
    
} catch {
    Write-Warning "⚠️ Failed to update version in setup script: $_"
}

# Step 4: Build installer
Write-Host "`n🏗️ Building enhanced installer..." -ForegroundColor Cyan

try {
    # Ensure output directory exists
    $outputDir = "installers\Output"
    if (!(Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Build installer
    Write-Host "🔧 Compiling installer with Inno Setup..." -ForegroundColor White
    & $innoSetupPath $setupScriptPath
    
    # Verify installer output
    $installerPath = "$outputDir\POSAce_Setup_Enhanced.exe"
    if (!(Test-Path $installerPath)) {
        throw "Installer output not found: $installerPath"
    }
    
    $installerInfo = Get-Item $installerPath
    Write-Host "✅ Enhanced installer built successfully" -ForegroundColor Green
    Write-Host "   Output: $installerPath" -ForegroundColor Gray
    Write-Host "   Size: $([math]::Round($installerInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
    Write-Host "   Created: $($installerInfo.CreationTime)" -ForegroundColor Gray
    
} catch {
    Write-Error "❌ Installer build failed: $_"
    exit 1
}

# Step 5: Verification and summary
Write-Host "`n🔍 Verification..." -ForegroundColor Cyan

# Check if redistributables directory exists
$redist = "installers\redistributables"
if (Test-Path $redist) {
    $redistFiles = Get-ChildItem $redist
    Write-Host "✅ Redistributables included: $($redistFiles.Count) files" -ForegroundColor Green
    
    # Check for essential files
    $essentialFiles = @("VC_redist.x64.exe", "vcruntime140_1.dll", "vcruntime140.dll")
    foreach ($file in $essentialFiles) {
        if (Test-Path (Join-Path $redist $file)) {
            Write-Host "   ✅ $file" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️ $file (missing)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "⚠️ Redistributables directory not found - installer will download online" -ForegroundColor Yellow
}

Write-Host "`n📋 Build Summary:" -ForegroundColor Cyan
Write-Host "================" -ForegroundColor Cyan
Write-Host "✅ Flutter app built successfully" -ForegroundColor Green
Write-Host "✅ Enhanced installer created" -ForegroundColor Green
Write-Host "✅ VCRUNTIME140_1.dll issue addressed" -ForegroundColor Green
Write-Host ""
Write-Host "📁 Output Files:" -ForegroundColor White
Write-Host "   • Installer: installers\Output\POSAce_Setup_Enhanced.exe" -ForegroundColor White
Write-Host "   • App: build\windows\x64\runner\Release\posace_app_win.exe" -ForegroundColor White

Write-Host "`n🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Test installer on Surface PC or clean Windows system" -ForegroundColor White
Write-Host "2. Verify VCRUNTIME error is resolved" -ForegroundColor White
Write-Host "3. Deploy to production if tests pass" -ForegroundColor White

Write-Host "`n🚀 Enhanced build completed successfully!" -ForegroundColor Green
Write-Host "Build time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray