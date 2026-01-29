# POSAce 프로덕션 배포 완료 (2026-01-29)

## 🎉 주요 성과

오늘 POSAce의 전체 시스템을 프로덕션 환경에 성공적으로 배포했습니다!

---

## 🌐 배포된 서비스

### 1️⃣ API 서버 (Railway)
- **URL**: `https://api.posace.com`
- **플랫폼**: Railway
- **데이터베이스**: Supabase PostgreSQL
- **인증**: Supabase + Custom JWT
- **환경변수**: 
  - DATABASE_URL, JWT_SECRET, SUPABASE_JWT_SECRET
  - CORS_ORIGINS, FRONTEND_URL
  - RESEND_API_KEY (이메일)

### 2️⃣ 백오피스 (Vercel)
- **URL**: `https://backoffice.posace.com`
- **플랫폼**: Vercel
- **프레임워크**: Next.js 15
- **환경변수**:
  - NEXT_PUBLIC_SUPABASE_URL
  - NEXT_PUBLIC_SUPABASE_ANON_KEY
  - NEXT_PUBLIC_API_URL

### 3️⃣ POS 클라이언트 (GitHub Releases)
- **다운로드**: `https://github.com/shimkijoon/posace-app-win/releases/latest/download/posace_app_win.msix`
- **플랫폼**: Windows 10/11
- **배포 방식**: GitHub Actions 자동 빌드
- **API 연결**: `https://api.posace.com/api/v1`

---

## 🔧 기술 스택

### Backend (API)
- NestJS + TypeScript
- Prisma ORM
- PostgreSQL (Supabase)
- Supabase Auth + Custom JWT
- Resend (Email)

### Frontend (Backoffice)
- Next.js 15 (App Router)
- React 19
- TypeScript
- TailwindCSS
- Supabase Client

### Client (POS App)
- Flutter 3.38.7
- Windows Desktop
- SQLite (로컬 캐싱)
- HTTP Client
- MSIX 패키징

---

## 📝 주요 작업 내역

### 1. API 서버 배포 (Railway)

#### ✅ 환경변수 설정
```env
DATABASE_URL=postgresql://...
SUPABASE_URL=https://wqjirowshlxfjcjmydfk.supabase.co
SUPABASE_JWT_SECRET=R0CMmjFncFEuGiVKOBRqUGRucjDXH2DlCxHnsjKIolUHTGV/vIqYPAd8E3dBCfGqTCNORSnTBptyJm+GMSZO3w==
NODE_ENV=production
JWT_SECRET=F69BPjlIduocHEVS8wxMWr1pqNCzZ4Uk7sRQmOa5DKnLJ3GAbYTfhvyi2gtXe0
JWT_REFRESH_SECRET=iEZqbS3veRzV0gJTp7dQH5WuljstBL4XxKYPIOGoFy8wnNAhk9CDMma2Ufc16r
JWT_EXPIRES_IN=7d
JWT_REFRESH_EXPIRES_IN=30d
POS_JWT_EXPIRES_IN=30d
CORS_ORIGINS=https://backoffice.posace.com
FRONTEND_URL=https://backoffice.posace.com
EMAIL_FROM=noreply@posace.app
EMAIL_FROM_NAME=POSAce
RESEND_API_KEY=re_***
```

#### ✅ 커스텀 도메인 연결
- Railway 프로젝트에 `api.posace.com` 도메인 추가
- Webtizen DNS에 CNAME 레코드 추가:
  ```
  api → [railway-cname].up.railway.app
  ```

#### ✅ 배포 확인
- Health Check: ✅
- Prisma Migration: ✅
- API 엔드포인트: ✅

---

### 2. 백오피스 배포 (Vercel)

#### ✅ 환경변수 설정
```env
NEXT_PUBLIC_SUPABASE_URL=https://wqjirowshlxfjcjmydfk.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
NEXT_PUBLIC_API_URL=https://api.posace.com/api/v1
```

#### ✅ 커스텀 도메인 연결
- `backoffice.posace.com` 추가
- Webtizen DNS에 CNAME 레코드 추가:
  ```
  backoffice → cname.vercel-dns.com
  ```

#### ✅ POS 앱 다운로드 연동
- Setup 페이지에 GitHub Releases 다운로드 링크 추가
- URL: `https://github.com/shimkijoon/posace-app-win/releases/latest/download/posace_app_win.msix`

#### ✅ About 페이지 리뉴얼
- 거창한 표현 → 담담하고 진솔한 톤으로 전면 개편
- 핵심 메시지:
  1. 작은 마트의 필요로 시작
  2. 회원 10,000명과 함께 16년간 성장
  3. AI의 도움으로 글로벌 확장
- 모든 언어 번역 (ko, en, ja, zh-TW, zh-HK)

---

### 3. POS 클라이언트 배포

#### ✅ API 도메인 프로덕션 적용
```dart
// lib/core/app_config.dart
static const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.posace.com/api/v1', // ✅ 프로덕션
);
```

#### ✅ MSIX 빌드 설정
```yaml
# pubspec.yaml
msix_config:
  display_name: POSAce
  publisher_display_name: POSAce
  publisher: CN=SHIMKIJOON, O=POSAce, C=KR
  identity_name: com.posace.app.win
  msix_version: 1.0.0.0
  capabilities: internetClient, privateNetworkClientServer
  install_certificate: true
```

#### ✅ GitHub Actions 자동 릴리즈
```yaml
# .github/workflows/release.yml
name: Build and Release MSIX
on:
  push:
    tags: ['v*']
  workflow_dispatch:
```

#### ✅ 레포지토리 Public 전환
- Private → Public 변경
- 이유: GitHub Releases 공개 다운로드 지원
- 장점: 무제한 다운로드, CDN 지원, 오픈소스 신뢰성

---

### 4. 도메인 리다이렉션 준비

#### ✅ www.posace.com → backoffice.posace.com
- Vercel 도메인 리다이렉션 설정 완료
- 또는 next.config.js 리다이렉트 설정

---

## 🌿 브랜치 전략 수립

### ✅ 브랜치 생성
- `main`: 프로덕션 (안정 버전)
- `dev`: 개발/스테이징 (새 기능 통합)

### ✅ 워크플로우
```
feature/* → dev → main
fix/* → dev → main
hotfix/* → main (긴급)
```

### ✅ 적용 프로젝트
- posace-api
- posace-backoffice
- posace-app-win

---

## 📊 최종 아키텍처

```
┌─────────────────────────────────────────────┐
│           사용자 (Windows POS 단말)           │
│                                             │
│  POSAce Client (posace_app_win.msix)       │
│  - Flutter Desktop App                      │
│  - 다운로드: GitHub Releases                 │
└──────────────────┬──────────────────────────┘
                   │
                   │ HTTPS
                   ↓
┌─────────────────────────────────────────────┐
│      API 서버 (api.posace.com)              │
│                                             │
│  - Railway 배포                             │
│  - NestJS + Prisma                         │
│  - Supabase Auth + Custom JWT              │
└──────────────────┬──────────────────────────┘
                   │
                   │
                   ↓
┌─────────────────────────────────────────────┐
│    데이터베이스 (Supabase PostgreSQL)         │
│                                             │
│  - 매장, 상품, 매출 데이터                   │
│  - 사용자 인증                              │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│    점주/관리자 (웹 브라우저)                  │
│                                             │
│  백오피스 (backoffice.posace.com)           │
│  - Vercel 배포                              │
│  - Next.js 15                              │
└──────────────────┬──────────────────────────┘
                   │
                   │ HTTPS
                   ↓
            API 서버 (동일)
```

---

## 🎯 다음 단계

### 1️⃣ 모니터링 & 로깅
- [ ] Railway 로그 모니터링 설정
- [ ] Vercel Analytics 활성화
- [ ] Sentry 에러 트래킹 (선택)

### 2️⃣ 브랜치 보호 설정
- [ ] GitHub main 브랜치 보호 규칙 설정
- [ ] PR 리뷰 필수 설정
- [ ] CI/CD 테스트 자동화

### 3️⃣ 문서화
- [x] 브랜치 전략 문서 작성
- [x] 배포 가이드 작성
- [ ] API 문서 자동 생성 (Swagger)

### 4️⃣ 성능 최적화
- [ ] API 응답 속도 개선
- [ ] 백오피스 빌드 최적화
- [ ] POS 앱 초기 로딩 속도 개선

### 5️⃣ 보안 강화
- [ ] API Rate Limiting
- [ ] HTTPS 강제
- [ ] 환경변수 암호화 검토

---

## 📚 참고 문서

- [BRANCH_STRATEGY.md](./BRANCH_STRATEGY.md) - 브랜치 전략 상세 가이드
- [posace-api/README.md](./posace-api/README.md) - API 서버 문서
- [posace-backoffice/README.md](./posace-backoffice/README.md) - 백오피스 문서
- [posace-app-win/README.md](./posace-app-win/README.md) - POS 클라이언트 문서
- [posace-backoffice/docs/deployment-*.md](./posace-backoffice/docs/) - 배포 가이드

---

## ✨ 성과 요약

- ✅ **3개 서비스 프로덕션 배포 완료**
- ✅ **커스텀 도메인 연결 완료**
- ✅ **자동 배포 파이프라인 구축**
- ✅ **브랜치 전략 수립 및 적용**
- ✅ **오픈소스 공개 (POS 앱)**
- ✅ **문서화 완료**

**이제 POSAce는 전 세계 사용자에게 서비스할 준비가 되었습니다!** 🚀

---

**작성일**: 2026-01-29  
**작성자**: POSAce Team
