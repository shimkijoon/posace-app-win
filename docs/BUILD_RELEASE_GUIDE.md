# POSAce Windows App Build & Release Guide

This document describes the standard procedure for building and releasing new versions of the POSAce Windows application.

## 📋 Prerequisites
- **Flutter SDK**: Ensure you have the stable channel installed.
- **Inno Setup**: Version 5 or 6 must be installed at `C:\Program Files (x86)\Inno Setup 6\ISCC.exe` (or version 5).
- **GitHub CLI (`gh`)**: For automated release and asset upload.
- **Git**: For version tagging.

## 🚀 Step-by-Step Release Flow

### 1. Version Update
Update the version in `pubspec.yaml`.
- Format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`
- Example: `version: 1.0.24+24`

### 2. Run Build Script
Use the provided PowerShell script to build the Flutter app and compile the Inno Setup installer.
```powershell
# From the project root
powershell -ExecutionPolicy Bypass -File .\scripts\build_setup.ps1
```
- **Output**: `installers\Output\POSAce_Setup.exe`

### 3. Commit and Tag
Once the local build is successful, commit your changes and tag the new version.
```powershell
git add .
git commit -m "chore: release v1.0.24 with UI refinements and fixes"
git tag v1.0.24
git push origin main
git push origin v1.0.24
```

### 4. Create GitHub Release
Use the GitHub CLI to create the release and upload the installer asset.
```powershell
gh release create v1.0.24 installers\Output\POSAce_Setup.exe --title "v1.0.24 - UI Refinements & Fixes" --notes "Release notes summary here..."
```

## 🛠 Troubleshooting
- **Build Failures**: Check for syntax errors or missing dependencies using `flutter analyze`.
- **Inno Setup Not Found**: Ensure the path in `scripts\build_setup.ps1` matches your local installation.
- **&& Error**: When using PowerShell, use `;` instead of `&&` to chain commands, or run them individually.

## 🔄 Automatic Release (CI)
Pushing a tag (e.g., `v*`) will trigger the GitHub Action `Release Windows App`, but manual local build ensures the installer is generated correctly before pushing.
