# POSAce Windows 앱 설치 가이드

**버전**: 1.0.1+2  
**빌드 날짜**: 2026-01-31  
**파일**: `posace_app_win.msix`

---

## 📦 설치 파일 위치

```
D:\workspace\github.com\shimkijoon\posace-app-win\build\windows\x64\runner\Release\posace_app_win.msix
```

---

## 🚀 설치 방법

### 방법 1: MSIX 직접 설치 (권장)

1. **MSIX 파일 다운로드**
   - 파일 위치에서 `posace_app_win.msix` 복사

2. **설치 실행**
   - MSIX 파일을 더블클릭하여 설치
   - Windows가 자동으로 설치 프로세스 시작

3. **인증서 확인** (필요시)
   - "앱을 설치할 수 없습니다" 오류 발생 시:
   - PowerShell을 관리자 권한으로 실행
   - 다음 명령 실행:
   ```powershell
   Add-AppxPackage -Path "C:\path\to\posace_app_win.msix"
   ```

### 방법 2: Supabase Storage 배포 (공개 다운로드)

#### 1. Supabase Storage에 업로드

**대시보드 방법:**
1. Supabase Dashboard 접속: https://supabase.com/dashboard
2. Storage 메뉴 → `releases` 버킷 (없으면 생성)
3. **Upload file** → `posace_app_win.msix` 선택
4. 업로드 완료 후 Public URL 복사

**CLI 방법:**
```bash
# Supabase CLI 설치 (없는 경우)
npm install -g supabase

# 로그인
supabase login

# 파일 업로드
supabase storage upload releases/windows/posace_app_win.msix build/windows/x64/runner/Release/posace_app_win.msix --project-ref YOUR_PROJECT_ID
```

#### 2. 다운로드 링크 생성

Public URL 형식:
```
https://YOUR_PROJECT_ID.supabase.co/storage/v1/object/public/releases/windows/posace_app_win.msix
```

#### 3. 백오피스에 링크 추가

`src/app/setup/page.tsx` 또는 다운로드 페이지에 링크 추가:
```tsx
<a 
  href="https://YOUR_PROJECT_ID.supabase.co/storage/v1/object/public/releases/windows/posace_app_win.msix"
  download="posace_app_win.msix"
>
  Download Windows App (.msix)
</a>
```

---

## 📋 설치 요구사항

- **OS**: Windows 10 (버전 1809 이상) 또는 Windows 11
- **아키텍처**: x64 (64-bit)
- **디스크 공간**: 약 100MB
- **인터넷 연결**: 초기 동기화 및 업데이트 확인용

---

## 🔧 문제 해결

### 오류: "앱을 설치할 수 없습니다"

**원인**: 개발자 인증서가 신뢰되지 않음

**해결 방법**:
1. PowerShell을 관리자 권한으로 실행
2. 다음 명령 실행:
   ```powershell
   Add-AppxPackage -Path "C:\path\to\posace_app_win.msix" -AllowUnsigned
   ```

### 오류: "인증서를 확인할 수 없습니다"

**해결 방법**:
1. MSIX 파일 우클릭 → 속성
2. "차단 해제" 체크박스 선택
3. 확인 클릭
4. 다시 설치 시도

### 오류: "이 앱은 디바이스에서 실행할 수 없습니다"

**원인**: 아키텍처 불일치 (32-bit vs 64-bit)

**해결 방법**:
- x64 버전의 MSIX 파일을 사용해야 합니다
- 현재 빌드: `build\windows\x64\runner\Release\posace_app_win.msix`

---

## 📝 설치 후 확인사항

1. ✅ 시작 메뉴에서 "POSAce" 검색
2. ✅ 앱 실행 확인
3. ✅ 로그인 기능 확인
4. ✅ 서버 동기화 확인
5. ✅ 결제 플로우 테스트

---

## 🔄 업데이트 방법

### 자동 업데이트 (향후 구현)
- 앱 내에서 자동으로 업데이트 확인
- 새 버전 발견 시 다운로드 및 설치 안내

### 수동 업데이트
1. 새 MSIX 파일 다운로드
2. 기존 앱 제거 (선택사항)
3. 새 MSIX 파일 설치
4. 데이터는 자동으로 보존됨

---

## 📊 파일 정보

- **파일명**: `posace_app_win.msix`
- **버전**: 1.0.1.0
- **패키지 이름**: `com.posace.app.win`
- **게시자**: CN=SHIMKIJOON, O=POSAce, C=KR
- **크기**: 약 19-25MB (실제 크기 확인 필요)

---

## 🎯 다음 단계

1. ✅ MSIX 파일 생성 완료
2. ⏳ Supabase Storage 업로드 (선택사항)
3. ⏳ 백오피스 다운로드 링크 추가
4. ⏳ 설치 테스트
5. ⏳ 사용자 배포

---

**생성일**: 2026-01-31  
**생성자**: AI Assistant
