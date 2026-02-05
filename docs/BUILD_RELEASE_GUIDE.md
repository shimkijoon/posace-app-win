# POSAce Windows App Build & Release Guide

This document describes the standard procedure for building and releasing new versions of the POSAce Windows application.

## 📋 Prerequisites
- **Flutter SDK**: Ensure you have the stable channel installed.
- **Inno Setup**: Version 5 or 6 must be installed at:
  - `C:\Program Files (x86)\Inno Setup 6\ISCC.exe` (Version 6)
  - `C:\Program Files (x86)\Inno Setup 5\ISCC.exe` (Version 5)
  - The script will automatically detect and use the installed version.
- **GitHub CLI (`gh`)**: For automated release and asset upload.
- **Git**: For version tagging.

## 🚀 Step-by-Step Release Flow

### 1. Version Update
Update the version in `pubspec.yaml`.
- Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`
- Example: `version: 1.0.25+25`

### 2. Run Enhanced Build Script
Use the enhanced PowerShell script to build the Flutter app and compile the Inno Setup installer with Visual C++ Runtime support.

```powershell
# From the project root
powershell -ExecutionPolicy Bypass -File .\scripts\build_setup_enhanced.ps1 -Version "1.0.25"
```

**Script Features:**
- Automatically updates version in `setup_enhanced.iss`
- Builds Flutter Windows app (can be skipped with `-SkipFlutterBuild`)
- Collects Visual C++ Runtime DLLs (can be skipped with `-SkipDllCollection`)
- Compiles enhanced installer with VCRUNTIME support
- **Output**: `installers\Output\POSAce_Setup_Enhanced.exe`

**Script Options:**
- `-Version "1.0.25"`: Specify the version number (required)
- `-SkipFlutterBuild`: Skip Flutter build step (if already built)
- `-SkipDllCollection`: Skip DLL collection step
- `-Force`: Force re-download/re-collect files

**Example with options:**
```powershell
# Full build (recommended)
powershell -ExecutionPolicy Bypass -File .\scripts\build_setup_enhanced.ps1 -Version "1.0.25"

# Skip Flutter build if already done
powershell -ExecutionPolicy Bypass -File .\scripts\build_setup_enhanced.ps1 -Version "1.0.25" -SkipFlutterBuild

# Skip DLL collection
powershell -ExecutionPolicy Bypass -File .\scripts\build_setup_enhanced.ps1 -Version "1.0.25" -SkipDllCollection
```

### 3. Commit and Tag
Once the local build is successful, commit your changes and tag the new version.

```powershell
git add .
git commit -m "chore: release v1.0.25 with type safety improvements"
git tag v1.0.25
git push origin main
git push origin v1.0.25
```

### 4. Create GitHub Release
Use the GitHub CLI to create the release and upload the installer asset.

```powershell
gh release create v1.0.25 installers\Output\POSAce_Setup_Enhanced.exe --title "v1.0.25 - Type Safety & UI Improvements" --notes-file RELEASE_NOTES_v1.0.25.md
```

Or with custom notes:
```powershell
gh release create v1.0.25 installers\Output\POSAce_Setup_Enhanced.exe --title "v1.0.25 - Type Safety & UI Improvements" --notes "Release notes here..."
```

## 📁 Output Files

After successful build:
- **Installer**: `installers\Output\POSAce_Setup_Enhanced.exe`
- **App Executable**: `build\windows\x64\runner\Release\posace_app_win.exe`
- **Runtime DLLs**: `installers\redistributables\` (if collected)

## 🛠 Troubleshooting

### Build Failures
- Check for syntax errors or missing dependencies using `flutter analyze`
- Ensure Flutter is in PATH: `flutter --version`
- Clean build: `flutter clean && flutter pub get`

### Inno Setup Not Found
- Ensure Inno Setup 5 or 6 is installed at:
  - `C:\Program Files (x86)\Inno Setup 6\ISCC.exe` (Version 6)
  - `C:\Program Files (x86)\Inno Setup 5\ISCC.exe` (Version 5)
- The script will automatically detect and use the installed version.
- Download from: https://jrsoftware.org/isinfo.php

### VCRUNTIME140_1.dll Error
- The enhanced installer includes Visual C++ Runtime support
- If DLLs are missing, the script will download the redistributable automatically
- Manual collection: Run `.\scripts\collect_runtime_dlls.ps1`

### PowerShell Execution Policy
- If script execution is blocked, use: `-ExecutionPolicy Bypass`
- Or set policy: `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`

## 🔄 Automatic Release (CI)

Pushing a tag (e.g., `v*`) will trigger the GitHub Action `Release Windows App`, but manual local build ensures the installer is generated correctly before pushing.

## 📝 Notes

- The enhanced installer (`POSAce_Setup_Enhanced.exe`) includes Visual C++ Runtime support to resolve `VCRUNTIME140_1.dll` errors on Surface PCs and clean Windows installations.
- Always test the installer on a clean Windows system before releasing.
- The script automatically updates the version in `setup_enhanced.iss`, so manual editing is not required.
