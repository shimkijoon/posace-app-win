# Supabase Storage 업로드 가이드

## 📦 MSIX 파일 정보

- **파일 위치**: `build\windows\x64\runner\Release\posace_app_win.msix`
- **파일 크기**: 약 18.57 MB
- **버전**: 1.0.1.0

## 🚀 수동 업로드 방법

### 1. Supabase Dashboard 접속

1. https://supabase.com/dashboard 접속
2. 프로젝트 선택 (wqjirowshlxfjcjmydfk)

### 2. Storage 버킷 생성/확인

1. 좌측 메뉴에서 **Storage** 클릭
2. **releases** 버킷이 있는지 확인
   - 없으면 **New bucket** 클릭
   - Name: `releases`
   - Public bucket: ✅ **Yes** (체크)
   - **Create bucket** 클릭

### 3. 폴더 생성

1. `releases` 버킷 클릭
2. **New folder** 클릭
3. 폴더명: `windows`
4. **Create folder** 클릭

### 4. 파일 업로드

1. `windows` 폴더 클릭
2. **Upload file** 버튼 클릭
3. `build\windows\x64\runner\Release\posace_app_win.msix` 선택
4. 업로드 완료 대기

### 5. Public URL 확인

1. 업로드된 `posace_app_win.msix` 파일 클릭
2. **Get public URL** 버튼 클릭
3. URL 복사:
   ```
   https://wqjirowshlxfjcjmydfk.supabase.co/storage/v1/object/public/releases/windows/posace_app_win.msix
   ```

## ✅ 확인사항

업로드 후 다음 URL로 접속하여 다운로드 가능한지 확인:
```
https://wqjirowshlxfjcjmydfk.supabase.co/storage/v1/object/public/releases/windows/posace_app_win.msix
```

## 🔄 자동화 (선택사항)

### Supabase CLI 설치 및 사용

```powershell
# Supabase CLI 설치
npm install -g supabase

# 로그인
supabase login

# 파일 업로드
cd D:\workspace\github.com\shimkijoon\posace-app-win
supabase storage upload releases/windows/posace_app_win.msix build/windows/x64/runner/Release/posace_app_win.msix --project-ref wqjirowshlxfjcjmydfk
```

또는 PowerShell 스크립트 사용:
```powershell
.\scripts\upload-to-supabase.ps1
```

## 📝 참고사항

- **Public URL**: 백오피스 setup 페이지에서 이미 설정됨
- **파일 덮어쓰기**: 같은 경로에 업로드하면 자동으로 덮어쓰기됨
- **버전 관리**: 파일명에 버전 포함 권장 (예: `posace_app_win_1.0.1.msix`)

---

**생성일**: 2026-01-31
