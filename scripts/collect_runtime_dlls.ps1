# Visual C++ Runtime DLL Collection Script for POSAce
# Resolves VCRUNTIME140_1.dll missing error on Surface PCs

param(
    [string]$OutputDir = "installers\redistributables",
    [switch]$Force = $false
)

Write-Host "=== POSAce Runtime DLL Collection Script ===" -ForegroundColor Cyan
Write-Host "Target directory: $OutputDir" -ForegroundColor Yellow

# Create output directory
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "✅ Created directory: $OutputDir" -ForegroundColor Green
} elseif ($Force) {
    Remove-Item "$OutputDir\*" -Force -Recurse -ErrorAction SilentlyContinue
    Write-Host "🗑️ Cleaned existing files in $OutputDir" -ForegroundColor Yellow
}

# Essential DLLs for Visual C++ Runtime
$RequiredDlls = @(
    "vcruntime140.dll",      # Visual C++ 2015-2022 Runtime
    "vcruntime140_1.dll",    # Additional Visual C++ Runtime (the problematic one)
    "msvcp140.dll",          # C++ Standard Library
    "concrt140.dll",         # Concurrency Runtime
    "vccorlib140.dll"        # Visual C++ Core Library
)

# Search paths for DLLs (ordered by preference)
$SearchPaths = @(
    "$env:SystemRoot\System32",
    "$env:SystemRoot\SysWOW64",
    # Visual C++ Redistributable installation paths
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\*\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT",
    "${env:ProgramFiles}\Microsoft Visual Studio\2019\*\VC\Redist\MSVC\*\x64\Microsoft.VC142.CRT",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\*\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\*\VC\Redist\MSVC\*\x64\Microsoft.VC142.CRT",
    # Common Visual C++ Runtime paths
    "${env:ProgramFiles}\Common Files\Microsoft Shared\VC",
    "${env:ProgramFiles(x86)}\Common Files\Microsoft Shared\VC"
)

# Additional WinSxS search (searched separately due to complexity)
$WinSxSPaths = @(
    "$env:SystemRoot\WinSxS"
)

Write-Host "`n📦 Collecting Visual C++ Runtime DLLs..." -ForegroundColor Cyan

$CollectedDlls = @()
$MissingDlls = @()

foreach ($dll in $RequiredDlls) {
    $found = $false
    $targetPath = Join-Path $OutputDir $dll
    
    # Skip if already exists and not forcing
    if ((Test-Path $targetPath) -and !$Force) {
        Write-Host "⏭️ $dll already exists, skipping..." -ForegroundColor Gray
        $CollectedDlls += $dll
        continue
    }
    
    Write-Host "🔍 Searching for $dll..." -ForegroundColor White
    
    # Search standard paths
    foreach ($searchPath in $SearchPaths) {
        # Handle wildcard paths
        if ($searchPath -like "*`**") {
            try {
                $baseDir = $searchPath -replace '\*.*$', ''
                $remainingPath = $searchPath.Substring($baseDir.Length)
                if ($remainingPath.StartsWith('\')) {
                    $remainingPath = $remainingPath.Substring(1)
                }
                
                $expandedPaths = @()
                if (Test-Path $baseDir) {
                    $dirs = Get-ChildItem -Path $baseDir -Directory -ErrorAction SilentlyContinue
                    foreach ($dir in $dirs) {
                        $fullPath = Join-Path $dir.FullName $remainingPath
                        if (Test-Path $fullPath) {
                            $expandedPaths += $fullPath
                        }
                    }
                }
                $pathsToCheck = $expandedPaths
            } catch {
                $pathsToCheck = @()
            }
        } else {
            $pathsToCheck = @($searchPath)
        }
        
        foreach ($path in $pathsToCheck) {
            $fullPath = Join-Path $path $dll
            if (Test-Path $fullPath) {
                try {
                    Copy-Item $fullPath $targetPath -Force
                    $fileInfo = Get-Item $fullPath
                    Write-Host "  ✅ $dll copied from: $path" -ForegroundColor Green
                    Write-Host "     Version: $($fileInfo.VersionInfo.FileVersion)" -ForegroundColor Gray
                    $CollectedDlls += $dll
                    $found = $true
                    break
                } catch {
                    Write-Warning "  ❌ Failed to copy $dll from $path : $_"
                }
            }
        }
        
        if ($found) { break }
    }
    
    # Search WinSxS if not found in standard paths
    if (!$found) {
        foreach ($winSxSPath in $WinSxSPaths) {
            if (Test-Path $winSxSPath) {
                try {
                    # Search for DLL in WinSxS subdirectories matching VC runtime pattern
                    $matchingDirs = Get-ChildItem -Path $winSxSPath -Directory -Filter "*vc-runtime*" -ErrorAction SilentlyContinue
                    foreach ($dir in $matchingDirs) {
                        $fullPath = Join-Path $dir.FullName $dll
                        if (Test-Path $fullPath) {
                            try {
                                Copy-Item $fullPath $targetPath -Force
                                $fileInfo = Get-Item $fullPath
                                Write-Host "  ✅ $dll copied from WinSxS: $($dir.Name)" -ForegroundColor Green
                                Write-Host "     Version: $($fileInfo.VersionInfo.FileVersion)" -ForegroundColor Gray
                                $CollectedDlls += $dll
                                $found = $true
                                break
                            } catch {
                                Write-Warning "  ❌ Failed to copy $dll from WinSxS : $_"
                            }
                        }
                    }
                    if ($found) { break }
                } catch {
                    # Silently continue if WinSxS search fails
                }
            }
        }
    }
    
    if (!$found) {
        Write-Warning "⚠️ Could not find $dll in any search location"
        $MissingDlls += $dll
    }
}

Write-Host "`n📥 Downloading Visual C++ Redistributable..." -ForegroundColor Cyan

# Download Visual C++ Redistributable
$vcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
$vcRedistPath = Join-Path $OutputDir "VC_redist.x64.exe"

if ((Test-Path $vcRedistPath) -and !$Force) {
    Write-Host "⏭️ VC_redist.x64.exe already exists, skipping download..." -ForegroundColor Gray
} else {
    try {
        Write-Host "🌐 Downloading from: $vcRedistUrl" -ForegroundColor White
        
        # Use TLS 1.2 for compatibility
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Download with progress
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($vcRedistUrl, $vcRedistPath)
        
        $fileInfo = Get-Item $vcRedistPath
        Write-Host "  ✅ VC_redist.x64.exe downloaded successfully" -ForegroundColor Green
        Write-Host "     Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
    } catch {
        Write-Warning "⚠️ Failed to download Visual C++ Redistributable: $_"
        Write-Host "💡 Please download manually from: $vcRedistUrl" -ForegroundColor Yellow
    }
}

Write-Host "`n📋 Collection Summary:" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

if ($CollectedDlls.Count -gt 0) {
    Write-Host "✅ Successfully collected DLLs:" -ForegroundColor Green
    foreach ($dll in $CollectedDlls) {
        $filePath = Join-Path $OutputDir $dll
        if (Test-Path $filePath) {
            $size = [math]::Round((Get-Item $filePath).Length / 1KB, 1)
            Write-Host "   • $dll ($size KB)" -ForegroundColor White
        }
    }
}

if ($MissingDlls.Count -gt 0) {
    Write-Host "`n⚠️ Missing DLLs (will rely on redistributable installation):" -ForegroundColor Yellow
    foreach ($dll in $MissingDlls) {
        Write-Host "   • $dll" -ForegroundColor Red
    }
}

# Verify VC Redistributable
if (Test-Path $vcRedistPath) {
    Write-Host "`n✅ Visual C++ Redistributable: Ready" -ForegroundColor Green
} else {
    Write-Host "`n❌ Visual C++ Redistributable: Missing" -ForegroundColor Red
}

Write-Host "`n📁 Output directory contents:" -ForegroundColor Cyan
if (Test-Path $OutputDir) {
    Get-ChildItem $OutputDir | ForEach-Object {
        $size = if ($_.PSIsContainer) { "DIR" } else { "$([math]::Round($_.Length / 1KB, 1)) KB" }
        Write-Host "   $($_.Name) ($size)" -ForegroundColor White
    }
} else {
    Write-Host "   (Directory not found)" -ForegroundColor Red
}

Write-Host "`n🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Review the collected files in: $OutputDir" -ForegroundColor White
Write-Host "2. Build the installer using: setup_enhanced.iss" -ForegroundColor White
Write-Host "3. Test on a Surface PC or clean Windows installation" -ForegroundColor White

if ($MissingDlls.Count -gt 0) {
    Write-Host "`n💡 Note: Missing DLLs will be handled by the Visual C++ Redistributable installer" -ForegroundColor Yellow
}

Write-Host "`n✨ Collection completed!" -ForegroundColor Green