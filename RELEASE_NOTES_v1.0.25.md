# Release Notes - v1.0.25

## 주요 변경사항

### 버그 수정
- **타입 캐스팅 오류 수정**: 주문 처리 중 발생하던 `type 'String' is not a subtype of type 'num'` 오류를 전면 수정
  - 모든 데이터 모델의 `fromMap` 메서드에 안전한 타입 변환 로직 추가
  - `ProductModel`, `DiscountModel`, `SaleModel`, `SaleItemModel` 등 모든 숫자 필드에 안전한 파싱 적용
  - 주문 생성 시 `safeToDouble()`, `safeToInt()` 헬퍼 함수 사용

### UI/UX 개선
- **테이블 주문 UI 개선**: 테이블을 선택해서 주문화면으로 진입한 경우 "주문" 버튼 숨김 처리
  - 테이블 주문은 "즉시 결제" 버튼만 표시
  - 일반 주문 화면에서는 "즉시 결제"와 "주문" 버튼 모두 표시

### 안정성 향상
- 주문 시스템의 타입 안정성 전면 개선
- 데이터베이스나 API에서 받은 값이 예상 타입과 다를 때도 안전하게 처리
- 앱 크래시 방지

## 기술적 변경사항

### 수정된 파일
- `lib/data/local/models.dart`: 모든 모델의 타입 변환 로직 개선
- `lib/ui/sales/sales_page.dart`: 안전한 타입 변환 및 UI 조건부 렌더링
- `lib/data/models/unified_order.dart`: JSON 파싱 시 안전한 타입 변환
- `lib/ui/sales/widgets/cart_sidebar.dart`: 테이블 주문 조건 처리

## 설치 방법

1. `POSAce_Setup.exe` 파일을 다운로드합니다.
2. 실행하여 설치를 진행합니다.
3. 설치 완료 후 POSAce 앱을 실행합니다.

## 호환성

- Windows 10 이상 (64-bit)
- .NET Framework 또는 Visual C++ Runtime 필요
