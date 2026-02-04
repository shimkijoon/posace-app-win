# 배포 요약 (2026-02-01) - POS Windows App

**날짜**: 2026-02-01  
**대상**: `posace-app-win` (Windows / MSIX)

---

## ✅ 변경사항(핵심)

- **언어 표시 정책 정리 + 즉시 반영**
  - 언어 결정 우선순위: **앱 전역 언어(appLanguage) → POS 세션 언어(uiLanguage) → 시스템 로케일 → 기본값(en)**
  - 로그인/로그아웃/언어 변경 시 **앱 재시작 없이 Locale 즉시 갱신**
- **통화 표시 일관성**
  - POS 세션에 `country/currency` 저장
  - 판매/장바구니/영수증/보류 등 금액 표시를 `LocaleHelper.getCurrencyFormat(country)` 기반으로 통일
- **다국어 누락 보완(일부)**
  - 장바구니 아이템 선택 시 노출되는 “삭제” 등 일부 하드코딩 문구를 i18n 키로 전환

---

## 🚀 배포(설치파일)

- **버전**: 1.0.10+1
- **릴리즈 태그**: `v1.0.10`
- **릴리즈 페이지**: `https://github.com/shimkijoon/posace-app-win/releases/tag/v1.0.10`
- **설치파일(MSIX)**: `posace_app_win.msix`

---

## 🔍 확인 항목

- AU 계정: UI가 영어로 표시되고 통화가 `A$`로 표시되는지
- JP 계정: UI가 일본어로 표시되고 통화가 `¥`로 표시되는지
- 동일 계정으로 백오피스와 POS 언어가 일치하는지

