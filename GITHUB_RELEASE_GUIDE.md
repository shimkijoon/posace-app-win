# GitHub Releases 배포 가이드

## 📦 현재 상태

- **MSIX 파일**: `build\windows\x64\runner\Release\posace_app_win.msix`
- **버전**: 1.0.1.0
- **크기**: 약 18.57 MB

## 🚀 GitHub Release 생성 방법

### 방법 1: GitHub 웹 인터페이스 (간단)

1. **GitHub 레포지토리 접속**
   - https://github.com/shimkijoon/posace-app-win

2. **Releases 페이지로 이동**
   - 우측 사이드바에서 **Releases** 클릭
   - 또는 URL: https://github.com/shimkijoon/posace-app-win/releases

3. **새 Release 생성**
   - **Create a new release** 또는 **Draft a new release** 클릭

4. **Release 정보 입력**
   - **Tag**: `v1.0.1` (또는 원하는 버전)
   - **Release title**: `POSAce Windows App v1.0.1`
   - **Description** (선택사항):
     ```markdown
     ## POSAce Windows App v1.0.1
     
     ### 주요 변경사항
     - Error Diagnostic System (Phase 2)
     - Payment Sync Safety 개선
     - Offline-First Architecture
     - 빌드 오류 수정
     
     ### 설치 방법
     1. `posace_app_win.msix` 파일 다운로드
     2. 파일을 더블클릭하여 설치
     3. Windows가 자동으로 설치 프로세스 시작
     ```

5. **파일 첨부**
   - **Attach binaries** 섹션에서
   - `build\windows\x64\runner\Release\posace_app_win.msix` 파일 드래그 앤 드롭
   - 또는 **Choose your files** 클릭하여 파일 선택

6. **Release 발행**
   - **Publish release** 클릭

### 방법 2: Git 태그 사용 (자동화 가능)

```bash
# 1. 태그 생성 및 푸시
cd D:\workspace\github.com\shimkijoon\posace-app-win
git tag v1.0.1
git push origin v1.0.1

# 2. GitHub에서 Release 생성
# - 웹 인터페이스에서 태그를 선택하여 Release 생성
# - 또는 GitHub CLI 사용:
gh release create v1.0.1 build/windows/x64/runner/Release/posace_app_win.msix --title "POSAce Windows App v1.0.1" --notes "Release notes here"
```

## 🔗 다운로드 링크

Release 생성 후 다음 링크로 자동 다운로드 가능:

```
https://github.com/shimkijoon/posace-app-win/releases/latest/download/posace_app_win.msix
```

또는 특정 버전:
```
https://github.com/shimkijoon/posace-app-win/releases/download/v1.0.1/posace_app_win.msix
```

## ✅ 확인사항

Release 생성 후:
1. 백오피스 setup 페이지에서 다운로드 링크 확인
2. 링크 클릭하여 다운로드 가능한지 테스트
3. MSIX 파일 설치 테스트

## 🔄 자동화 (선택사항)

GitHub Actions를 사용하여 자동 배포 설정:

```yaml
# .github/workflows/release.yml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.7'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Build Windows
        run: flutter build windows --release
      
      - name: Create MSIX
        run: flutter pub run msix:create
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: build/windows/x64/runner/Release/posace_app_win.msix
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

사용 방법:
1. 위 파일을 `.github/workflows/release.yml`로 저장
2. 태그 푸시: `git tag v1.0.2 && git push origin v1.0.2`
3. 자동으로 빌드 및 Release 생성

## 📝 버전 관리

- **태그 형식**: `v1.0.1`, `v1.0.2`, `v1.1.0` 등
- **Semantic Versioning** 권장:
  - `MAJOR.MINOR.PATCH`
  - 예: `1.0.1` → `1.0.2` (패치), `1.1.0` (기능 추가), `2.0.0` (대규모 변경)

---

**생성일**: 2026-01-31
