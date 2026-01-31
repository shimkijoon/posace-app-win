# Error Diagnostic System - Phase 2 구현

**날짜**: 2026-01-31  
**브랜치**: dev  
**상태**: ✅ 완료

## 📋 개요

Phase 2에서는 **UI 컴포넌트**와 **자동 복구 로직**을 구현했습니다.

## 🎨 새로운 UI 컴포넌트

### DiagnosticErrorDialog

사용자 친화적인 에러 다이얼로그:

```dart
await DiagnosticErrorDialog.show(
  context: context,
  error: diagnosticError,
  onSyncPressed: () => _performAutoSync(),
  onRetryPressed: () => _retryPayment(),
  systemInfo: {...},
);
```

#### 주요 기능

1. **아이콘 & 색상**
   - 에러 타입별 아이콘 자동 선택
   - 상태 코드별 색상 (500: 빨강, 400: 주황, 기타: 파랑)

2. **섹션별 정보**
   - ✅ 오류 내용: 사용자 메시지
   - ✅ 원인: 기술적 메시지
   - ✅ 해결 방법: 권장 조치 (하이라이트)
   - ✅ 상세 정보: 접을 수 있는 ExpansionTile

3. **액션 버튼**
   - 권장 조치에 따라 자동으로 버튼 생성
   - `SYNC_MASTER_DATA` → "지금 동기화하기" 버튼
   - `RETRY` → "다시 시도" 버튼
   - `RE_LOGIN` → "다시 로그인" 버튼
   - "리포트 복사" 버튼 (항상 표시)
   - "닫기" 버튼

## 🔧 자동 복구 로직

### 1. 자동 동기화

```dart
Future<void> _performAutoSync() async {
  // 1. 로딩 표시
  // 2. SyncService 사용하여 전체 동기화
  // 3. 성공 시 데이터 다시 로드
  // 4. 결과 메시지 표시
}
```

**특징:**
- ✅ 로딩 다이얼로그 표시
- ✅ 전체 동기화 (manual: true)
- ✅ 성공 시 데이터 자동 리로드
- ✅ 동기화 결과 표시 (카테고리/상품 개수)

### 2. 결제 재시도

```dart
onRetryPressed: () async {
  await _processPaymentSuccess(
    method,
    paidAmount: paidAmount,
    // ... 모든 파라미터 재전달
  );
}
```

### 3. 시스템 정보 수집

```dart
systemInfo: {
  'storeId': session['storeId'],
  'posId': session['posId'],
  'appVersion': '1.0.0',
  'lastSyncAt': lastSync?.toIso8601String() ?? 'Never',
  'productCount': productCount,
  'categoryCount': categoryCount,
  'cartItemCount': _cart.items.length,
  'totalAmount': totalAmount,
}
```

## 📊 실제 사용 예시

### 시나리오: 상품 정보 없음 오류

#### 1. 에러 발생
```
POST /api/sales/pos
404 Not Found
{
  "errorCode": "SALE_PRODUCT_NOT_FOUND",
  "userMessage": "상품 정보가 서버에 존재하지 않습니다",
  "suggestedAction": "SYNC_MASTER_DATA",
  "actionMessage": "마스터 데이터 동기화를 실행해주세요",
  "details": {
    "missingIds": ["uuid-1", "uuid-2"],
    "entity": "Product"
  }
}
```

#### 2. 다이얼로그 표시

```
┌─────────────────────────────────────┐
│ 🔄 데이터 없음                 ✕   │
├─────────────────────────────────────┤
│                                     │
│ 오류 내용                           │
│ 상품 정보가 서버에 존재하지 않습니다 │
│                                     │
│ 원인                                │
│ Product not found in database       │
│                                     │
│ 해결 방법                           │
│ ┌─────────────────────────────────┐ │
│ │ 💡 마스터 데이터 동기화를        │ │
│ │    실행해주세요                  │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ▼ 상세 정보                         │
│   엔티티: Product                   │
│   누락된 항목: 2개                  │
│   • 12345678...                     │
│   • 87654321...                     │
│                                     │
├─────────────────────────────────────┤
│  [지금 동기화하기] [리포트 복사] [닫기] │
└─────────────────────────────────────┘
```

#### 3. "지금 동기화하기" 클릭

```
┌─────────────────────────────┐
│                             │
│    ⏳                       │
│  마스터 데이터 동기화 중...  │
│                             │
└─────────────────────────────┘

↓ (3초 후)

✅ 동기화 완료: 3개 카테고리, 8개 상품
```

#### 4. 자동으로 데이터 리로드
- 카테고리 목록 갱신
- 상품 목록 갱신
- 화면 자동 업데이트

#### 5. 사용자는 다시 결제 시도 가능!

## 🎯 개선 사항 요약

### Before (Phase 1만 있을 때)
```
❌ 결제 처리 실패: Exception: Failed to upload sale: 404
```
→ 사용자는 어떻게 해야 할지 모름

### After (Phase 2 완료)
```
┌────────────────────────────┐
│ 🔄 데이터 없음        ✕  │
│                            │
│ 상품 정보가 서버에        │
│ 존재하지 않습니다          │
│                            │
│ 💡 마스터 데이터 동기화를 │
│    실행해주세요            │
│                            │
│ [지금 동기화하기]  [닫기]  │
└────────────────────────────┘
```
→ 즉시 문제 이해 + 원클릭 해결!

## ✅ 적용된 파일

### posace-app-win (신규)
- ✨ `lib/ui/common/diagnostic_error_dialog.dart` (신규)

### posace-app-win (수정)
- 🔧 `lib/ui/sales/sales_page.dart`
  - DiagnosticErrorDialog import
  - ErrorDiagnosticService import
  - catch 블록에 진단 로직 추가
  - _performAutoSync() 메서드 추가
  - 시스템 정보 수집 로직 추가

## 📈 장점

### 사용자 관점
1. **명확한 문제 이해**: "상품 정보가 없다"
2. **즉시 해결 가능**: "지금 동기화하기" 버튼 클릭
3. **자동 복구**: 동기화 후 자동으로 데이터 리로드

### AS 담당자 관점
1. **상세한 리포트**: "리포트 복사" 버튼으로 즉시 정보 수집
2. **시스템 상태 확인**: productCount, lastSyncAt 등
3. **빠른 원인 파악**: 에러 코드, 누락된 ID 등

### 개발자 관점
1. **재사용 가능**: DiagnosticErrorDialog는 어디서나 사용 가능
2. **자동화**: 권장 조치에 따라 버튼 자동 생성
3. **확장 가능**: 새로운 액션 타입 추가 용이

## 🔄 다음 단계

### Phase 3 (선택사항)
1. **에러 로깅 & 모니터링**
   - Firebase Crashlytics 연동
   - 에러 발생 빈도 추적
   - 자주 발생하는 에러 대시보드

2. **추가 자동 복구 로직**
   - 토큰 만료 시 자동 갱신
   - 네트워크 오류 시 자동 재시도
   - 오프라인 모드 자동 전환

3. **사용자 교육**
   - 첫 오류 발생 시 튜토리얼 표시
   - 자주 묻는 질문 (FAQ) 링크

## 🎉 결과

**완전한 Error Diagnostic System 구현 완료!**

사용자는 이제:
- ✅ 에러 원인을 즉시 이해할 수 있습니다
- ✅ 원클릭으로 문제를 해결할 수 있습니다
- ✅ AS 담당자에게 정확한 리포트를 전달할 수 있습니다

---

**작성자**: AI Assistant  
**검증자**: User (shimkijoon)
