# Release Notes - v1.0.25

## 주요 변경사항

### 오류 처리 개선
- **일관된 오류 처리 시스템**: 모든 API 파일에 `DiagnosticException` 적용
  - 서버에서 제공하는 진단 정보를 사용자에게 명확하게 표시
  - `DiagnosticErrorDialog`를 통한 개선된 오류 UI
  - 모든 API 파일(`pos_sales_api`, `pos_master_api`, `pos_auth_api`, `unified_order_api` 등)에 적용
  - 자동 동기화 및 재시도 기능 개선

### 설치 파일 개선
- **한글 깨짐 문제 해결**: 설치 파일에서 한글 언어 옵션 제거
  - 모든 설치 파일 텍스트를 영어로 변경
  - Windows 환경에서의 한글 인코딩 문제 해결
  - 더 안정적인 설치 경험 제공

### 버그 수정
- **타입 캐스팅 오류 수정**: 주문 처리 중 발생하던 `type 'String' is not a subtype of type 'num'` 오류를 전면 수정
  - 모든 데이터 모델의 `fromMap` 메서드에 안전한 타입 변환 로직 추가
  - `ProductModel`, `DiscountModel`, `SaleModel`, `SaleItemModel` 등 모든 숫자 필드에 안전한 파싱 적용
  - 주문 생성 시 `safeToDouble()`, `safeToInt()` 헬퍼 함수 사용

### UI/UX 개선
- **테이블 주문 UI 개선**: 테이블을 선택해서 주문화면으로 진입한 경우 "주문" 버튼 숨김 처리
  - 테이블 주문은 "즉시 결제" 버튼만 표시
  - 일반 주문 화면에서는 "즉시 결제"와 "주문" 버튼 모두 표시
- **상단 탭 네비게이션 개선**: 탭 기반 전환 UI 적용 및 크기 조정
  - 홈 화면에서는 네비게이션 제거, 로그아웃만 노출
  - 판매/테이블/주문관리/판매내역/설정 탭 가독성 개선
- **하단 버튼 레이아웃 정리**: 버튼 높이/간격 통일 및 오버플로우 개선
  - 메인/보조 버튼 스타일 정렬 및 라벨 정돈
- **보류 거래 UI 개선**
  - 보류 거래내역 다국어 적용
  - 테이블 주문 진입 시 보류 버튼 숨김
  - 보류 거래내역 X 버튼 동작 수정

### 주문관리 개선
- **탭 고정 및 상태 전환 강화**
  - 대기/조리 대기열/결제 대기/테이크아웃/테이블/전체 탭 구성
  - 주문 상태 전환 버튼 추가(주문 확정/조리 시작/준비 완료/서빙·픽업 완료)
  - 조리 상태 변경 시 주문 상태 자동 연동
- **결제 분리 표시**
  - 미결제/결제 완료 배지 표시
  - 결제 대기 탭 추가
- **테이블 전환 접근성 개선**
  - 주문 카드에서 테이블 화면 바로 이동 버튼 제공
- **전체 라벨 다국어 적용**
  - 주문관리 탭/필터/상태/배지/빈 상태/상세 다이얼로그 문구 i18n 적용

### 안정성 향상
- 주문 시스템의 타입 안정성 전면 개선
- 데이터베이스나 API에서 받은 값이 예상 타입과 다를 때도 안전하게 처리
- 앱 크래시 방지
- 향상된 오류 진단 및 사용자 가이드

## 기술적 변경사항

### 수정된 파일
- `lib/data/local/models.dart`: 모든 모델의 타입 변환 로직 개선
- `lib/ui/sales/sales_page.dart`: 안전한 타입 변환 및 UI 조건부 렌더링
- `lib/data/models/unified_order.dart`: JSON 파싱 시 안전한 타입 변환
- `lib/ui/sales/widgets/cart_sidebar.dart`: 테이블 주문 조건 처리
- `lib/ui/common/navigation_title_bar.dart`: 상단 탭 네비게이션 구성/크기 조정
- `lib/ui/home/home_page.dart`: 홈 하단 버튼 레이아웃 및 라벨 정리
- `lib/ui/orders/unified_order_management_page.dart`: 주문관리 탭/상태/결제 분리 개선
- `lib/ui/orders/widgets/order_card.dart`: 주문 카드 상태/결제 배지 및 액션 개선
- `lib/ui/orders/widgets/order_filter_bar.dart`: 필터 다국어 적용
- `lib/ui/orders/widgets/cooking_queue_section.dart`: 조리 대기열 다국어 적용
- `lib/ui/sales/widgets/function_buttons.dart`: 하단 기능 버튼 레이아웃/표시 제어
- `lib/ui/sales/widgets/suspended_sales_dialog.dart`: 보류 거래내역 다국어/X 버튼 수정
- `lib/l10n/*.json`: 주문관리/홈/보류 거래 관련 다국어 키 추가

## 설치 방법

1. `POSAce_Setup.exe` 파일을 다운로드합니다.
2. 실행하여 설치를 진행합니다.
3. 설치 완료 후 POSAce 앱을 실행합니다.

## 호환성

- Windows 10 이상 (64-bit)
- .NET Framework 또는 Visual C++ Runtime 필요
