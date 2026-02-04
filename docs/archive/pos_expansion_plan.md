# Implementation Plan: Windows POS App Feature Integration

고도화된 백엔드 API를 기반으로 윈도우 POS 앱(`posace-app-win`)의 기능을 확장합니다.

## Proposed Changes

### 1. Data Layer (Models & Database)
- **[MODIFY] [models.dart](file:///d:/workspace/github.com/shimkijoon/posace-app-win/lib/data/local/models.dart)**
  - `SaleModel`에 `sessionId`, `employeeId` 필드 추가.
  - `SalePaymentModel`, `EmployeeModel`, `PosSessionModel` 신규 생성.
- **[MODIFY] [app_database.dart](file:///d:/workspace/github.com/shimkijoon/posace-app-win/lib/data/local/app_database.dart)**
  - 데이터베이스 버전을 8로 업데이트.
  - `employees`, `pos_sessions`, `sale_payments`, `table_layouts`, `restaurant_tables`, `table_orders` 테이블 생성 로직 추가 (`_onUpgrade`).

### 2. Network Layer (API Clients)
- **[NEW] [employees_api.dart](file:///d:/workspace/github.com/shimkijoon/posace-app-win/lib/data/remote/employees_api.dart)**: 직원 PIN 인증 및 목록 조회.
- **[NEW] [table_service_api.dart](file:///d:/workspace/github.com/shimkijoon/posace-app-win/lib/data/remote/table_service_api.dart)**: 테이블 레이아웃 및 주문 관리.
- **[MODIFY] [pos_sales_api.dart](file:///d:/workspace/github.com/shimkijoon/posace-app-win/lib/data/remote/pos_sales_api.dart)**: 분할 결제(payments array) 업로드 지원.

### 3. UI/UX (Screens & Widgets)
- **[NEW] [pin_login_page.dart](file:///d:/workspace/github.com/shimkijoon/posace-app-win/lib/ui/auth/pin_login_page.dart)**: 텐키(Ten-key) 패드 형태의 직원 PIN 입력 화면.
- **[NEW] [split_payment_dialog.dart](file:///d:/workspace/github.com/shimkijoon/posace-app-win/lib/ui/sales/widgets/split_payment_dialog.dart)**: 다중 결제수단 추가 및 금액 분할 UI.
- **[NEW] [table_layout_page.dart](file:///d:/workspace/github.com/shimkijoon/posace-app-win/lib/ui/tables/table_layout_page.dart)**: 매장 테이블 배치도 및 주문 현황 뷰.
- **[MODIFY] [sales_page.dart](file:///d:/workspace/github.com/shimkijoon/posace-app-win/lib/ui/sales/sales_page.dart)**: 분할 결제 기능 연동 및 세션/직원 정보 반영.

## Verification Plan

### Automated Tests
- `sqflite` 마이그레이션 테스트: 버전 7에서 8로 업그레이드 시 데이터 보존 및 테이블 생성 확인.
- `SaleModel` 직렬화 테스트: 분할 결제 데이터가 JSON으로 올바르게 변환되는지 확인.

### Manual Verification
1. **직원 인증**: 관리자 계정 로그인 후 직원 PIN(1234)으로 직원 전환 성공 여부 확인.
2. **분할 결제**: 10,000원 상품 결제 시 현금 3,000원 + 카드 7,000원 결제 및 서버 동기화 확인.
3. **세션 종료**: 마감 시 영수증에 통계 데이터(Z-Report) 출력 확인.
