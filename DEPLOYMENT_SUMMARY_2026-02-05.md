# 배포 요약 - 2026년 2월 5일

## 개요
테이크아웃 주문 기능의 타입 안정성 개선 및 UI/UX 개선

## 주요 변경사항

### 1. 타입 캐스팅 오류 전면 수정
**파일**: 
- `lib/data/local/models.dart`
- `lib/ui/sales/sales_page.dart`
- `lib/data/models/unified_order.dart`

**문제**:
- `type 'String' is not a subtype of type 'num' in type cast` 오류 반복 발생
- 데이터베이스나 API에서 받은 값이 예상 타입과 다를 때 앱 크래시 발생

**해결**:
- 모든 모델의 `fromMap` 메서드에 안전한 타입 변환 로직 추가
- `ProductModel`, `DiscountModel`, `SaleModel`, `SaleItemModel` 등 모든 숫자 필드에 안전한 파싱 적용
- 주문 생성 시 `safeToDouble()`, `safeToInt()` 헬퍼 함수 사용
- `CartItem.unitPrice` 사용으로 이미 계산된 안전한 값 활용

**수정된 모델**:
- `CategoryModel`: `sortOrder` 안전한 파싱
- `ProductModel`: `price`, `stockQuantity`, `stockEnabled`, `isActive` 안전한 파싱
- `DiscountModel`: `rateOrAmount`, `priority` 안전한 파싱
- `MemberModel`: `points` 안전한 파싱
- `SaleModel`: `totalAmount`, `paidAmount`, `taxAmount`, `discountAmount`, `memberPointsEarned` 안전한 파싱
- `SaleItemModel`: `qty`, `price`, `discountAmount` 안전한 파싱
- `UnifiedOrder`: `totalAmount` 안전한 파싱
- `UnifiedOrderItem`: `price`, `qty` 안전한 파싱

**코드 예시**:
```dart
// 기존 (위험한 캐스팅)
sortOrder: map['sortOrder'] as int,

// 개선 (안전한 파싱)
sortOrder: (map['sortOrder'] is int) 
    ? map['sortOrder'] as int
    : int.tryParse(map['sortOrder'].toString()) ?? 0,
```

### 2. 테이블 주문 UI 개선
**파일**: 
- `lib/ui/sales/sales_page.dart`
- `lib/ui/sales/widgets/cart_sidebar.dart`

**변경사항**:
- 테이블을 선택해서 주문화면으로 진입한 경우 "주문" 버튼 숨김 처리
- 테이블 주문은 "즉시 결제" 버튼만 표시
- 일반 주문 화면에서는 "즉시 결제"와 "주문" 버튼 모두 표시

**로직**:
```dart
// 테이블 주문이 아닐 때만 "주문" 버튼 표시
if (_selectedTableOrder == null) {
  // 주문 버튼 표시
}
```

**영향**:
- 사용자 혼란 방지 (테이블 주문은 테이크아웃 주문 불필요)
- UI/UX 개선

## 테스트
- 타입 캐스팅 오류 해결 검증 완료
- 테이블 주문 시 "주문" 버튼 숨김 확인 완료
- 일반 주문 시 "주문" 버튼 표시 확인 완료
- 빌드 테스트 완료

## 배포 정보
- **브랜치**: `dev` → `main`
- **주요 커밋**:
  - `da67ca8` - Fix all unsafe type casting in model fromMap methods
  - `e8e4b45` - Fix type casting errors in order processing
  - `74d189c` - Hide takeout order button when table is selected
- **배포 일시**: 2026-02-05

## 관련 이슈
- 주문 처리 중 타입 캐스팅 오류 해결
- 테이블 주문 UI/UX 개선
- 앱 안정성 향상
