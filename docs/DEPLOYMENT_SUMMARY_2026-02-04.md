# 배포 요약 (2026-02-04) - POS Windows App v1.0.24

**날짜**: 2026-02-04  
**버전**: `1.0.24+24`  
**대상**: `posace-app-win` (Windows / EXE Installer)

---

## ✅ 주요 작업 내용

### 1. 소셜 로그인 오류 수정
- **원인**: `PosAuthService.completeSocialLogin`에서 Supabase 쿼리 시 필드 매핑 불일치 (CamelCase vs snake_case).
- **수정**: `ownerId`, `businessNumber` 필드명을 올바르게 수정하고, 매장 선택에 필요한 `posDevices` 데이터를 포함하도록 쿼리 개선.

### 2. UI 개선 및 다국어 지원 (i18n)
- **통화 기호 제거**: `LocaleHelper`를 수정하여 모든 국가에서 통화 기호(₩, ¥ 등)를 제거하고 숫자와 천 단위 구분자만 표시되도록 수정.
- **회원 검색/등록**: 모든 하드코딩된 한국어 문자열을 `AppLocalizations` 키로 대체하고, 전화번호 유효성 검사를 완화하여 국가별 유연성 확보.
- **판매 페이지**: "총 할인", "상품 없음" 등의 안내 문구를 다국어 지원 가능하도록 수정.

### 3. 주요 버그 수정
- **회원 포인트 파싱**: 서버에서 넘어오는 포인트 값이 문자열(Decimal)일 경우 발생하는 타입 에러를 방지하도록 `MemberModel` 수정.
- **복합 결제 현금 입력**: 가상 키패드 입력 시 기존 잔액에 덧붙여지는 현상을 수정하고, '0'부터 새로 입력되도록 개선.

### 4. 빌드 및 배포 프로세스 표준화
- `scripts/build_setup.ps1`을 통한 로컬 빌드 및 인스톨러 생성 확인.
- GitHub CLI(`gh`)를 이용한 릴리즈 생성 및 자동 업로드 프로세스 정립.

---

## 🚀 다음 단계 (Next Steps)
- [ ] v1.0.24 실환경 테스트 (특히 구글 로그인 및 통화 표시 확인).
- [ ] 나머지 하드코딩된 문자열 (환경설정 등) 추가 발굴 및 i18n 적용.
- [ ] 영수증 템플릿의 통화 기호 제거 여부 최종 확인.

---

## 🔗 관련 문서
- [BUILD_RELEASE_GUIDE.md](./BUILD_RELEASE_GUIDE.md): 빌드 및 릴리즈 상세 가이드
- [walkthrough.md](../../../.gemini/antigravity/brain/85564259-34a8-4f9a-be52-961c5dea1e5c/walkthrough.md): 상세 변경 사항 기술 문서
