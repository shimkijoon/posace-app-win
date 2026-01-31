# Windows 앱 다운로드 옵션 비교

## 현재 상황

백오피스의 `setup/page.tsx`에서 다운로드 링크가 다음과 같이 설정되어 있습니다:

```tsx
href="https://wqjirowshlxfjcjmydfk.supabase.co/storage/v1/object/public/releases/windows/posace_app_win.msix"
```

**문제**: 이 링크는 파일을 업로드하기 전까지는 작동하지 않습니다 (404 에러).

---

## 옵션 비교

### 옵션 1: Supabase Storage (현재 설정)

**장점**:
- ✅ 이미 Supabase를 사용 중 (추가 서비스 불필요)
- ✅ CDN 자동 적용
- ✅ 다운로드 통계 수집 가능
- ✅ Private 레포지토리 유지 가능

**단점**:
- ❌ 수동 업로드 필요
- ❌ Free 플랜: 1GB 제한
- ❌ 버전 관리 수동

**비용**:
- Free: 1GB storage, 2GB bandwidth/month
- Pro: $25/month (100GB storage, 200GB bandwidth)

**필요 작업**:
1. Supabase Dashboard에서 `releases` 버킷 생성
2. `windows/` 폴더 생성
3. MSIX 파일 업로드

---

### 옵션 2: GitHub Releases (권장)

**장점**:
- ✅ 자동화 가능 (GitHub Actions)
- ✅ 버전 관리 자동
- ✅ 무료 (무제한)
- ✅ 릴리즈 노트 작성 가능
- ✅ 다운로드 통계 제공

**단점**:
- ❌ Public 레포지토리 필요 (또는 GitHub Pro 필요)
- ❌ Private 레포지토리는 다운로드 제한 있음

**필요 작업**:
1. GitHub에서 Release 생성
2. MSIX 파일 첨부
3. 백오피스 링크 변경:
   ```tsx
   href="https://github.com/shimkijoon/posace-app-win/releases/latest/download/posace_app_win.msix"
   ```

**자동화 예시**:
```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags:
      - 'v*'
jobs:
  build-and-release:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter build windows --release
      - run: flutter pub run msix:create
      - uses: softprops/action-gh-release@v1
        with:
          files: build/windows/x64/runner/Release/posace_app_win.msix
```

---

### 옵션 3: 직접 호스팅 (Vercel Blob, AWS S3 등)

**장점**:
- ✅ 완전한 제어
- ✅ CDN 통합
- ✅ 다운로드 제한 설정 가능

**단점**:
- ❌ 추가 비용
- ❌ 설정 복잡도 증가

---

## 추천: GitHub Releases 사용

**이유**:
1. **무료**: Private 레포지토리도 사용 가능 (다운로드 제한 있지만 충분)
2. **자동화**: GitHub Actions로 자동 배포 가능
3. **버전 관리**: 태그 기반으로 자동 버전 관리
4. **간편함**: 수동 업로드 불필요

**변경 방법**:
1. GitHub에서 Release 생성 (또는 태그 푸시)
2. MSIX 파일 첨부
3. 백오피스 링크 변경:
   ```tsx
   href="https://github.com/shimkijoon/posace-app-win/releases/latest/download/posace_app_win.msix"
   ```

---

## 현재 선택: Supabase Storage를 계속 사용할지?

**Supabase Storage를 사용하려면**:
- 파일을 업로드해야 링크가 작동함
- 업로드 가이드: `SUPABASE_UPLOAD_INSTRUCTIONS.md`

**GitHub Releases로 변경하려면**:
- 백오피스 링크만 변경하면 됨
- 더 간편하고 자동화 가능

---

**결론**: GitHub Releases가 더 간편하고 자동화 가능하므로 권장합니다.
