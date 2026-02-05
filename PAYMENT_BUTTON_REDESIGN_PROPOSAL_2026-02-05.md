# 결제 버튼 분리 설계 제안서 (2026-02-05)

**목적**: 즉시 결제와 테이크아웃 주문 관리를 구분하는 UI 개선  
**날짜**: 2026-02-05

---

## 🎯 현재 문제점

### 기존 구조
- **단일 결제 버튼**: 모든 주문이 즉시 완료 처리
- **테이크아웃 관리 불가**: 조리 대기, 완료 알림 등 후속 관리 없음
- **사용자 혼란**: 매장 내 식사와 테이크아웃 구분 불가

---

## 💡 제안하는 UI 패턴

### 🏆 **패턴 1: 수평 분할 버튼 (추천)**

#### 시각적 설계
```
┌─────────────────────────────────────────────────────┐
│ 💰 총 금액: 15,000원                                │
├─────────────────────────────────────────────────────┤
│ ┌─────────────────┐ ┌─────────────────────────────┐ │
│ │   💳 즉시 결제   │ │  📋 테이크아웃 주문 등록   │ │
│ │   (기존 방식)    │ │    (신규 기능)             │ │
│ └─────────────────┘ └─────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

#### 장점
- ✅ **직관적**: 두 옵션이 명확히 구분됨
- ✅ **빠른 선택**: 한 번의 터치로 의도 전달
- ✅ **공간 효율적**: 기존 영역 내에서 해결
- ✅ **접근성**: 버튼 크기가 충분히 큼

#### 색상 및 스타일
- **즉시 결제**: 기본 Primary 색상 (파란색)
- **테이크아웃**: Secondary 색상 (주황색) + 아이콘

---

## 🔧 구현 계획

### 1단계: UI 컴포넌트 수정

#### 1.1 CartSidebar 위젯 수정
**파일**: `lib/ui/sales/widgets/cart_sidebar.dart`

**기존 코드**:
```dart
// 결제 버튼
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: onCheckout,
    child: Text('결제'),
  ),
)
```

**변경 후**:
```dart
// 분할 결제 버튼
Row(
  children: [
    // 즉시 결제 버튼
    Expanded(
      flex: 1,
      child: ElevatedButton.icon(
        onPressed: onCheckout,
        icon: Icon(Icons.payment),
        label: Text('즉시 결제'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    ),
    SizedBox(width: 12),
    // 테이크아웃 주문 버튼
    Expanded(
      flex: 1,
      child: ElevatedButton.icon(
        onPressed: onTakeoutOrder,
        icon: Icon(Icons.restaurant_menu),
        label: Text('테이크아웃'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.secondary,
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    ),
  ],
)
```

#### 1.2 CartBottomSheet 위젯 수정
**파일**: `lib/ui/sales/widgets/cart_bottom_sheet.dart`
- CartSidebar와 동일한 패턴 적용

### 2단계: 콜백 함수 추가

#### 2.1 SalesPage 수정
**파일**: `lib/ui/sales/sales_page.dart`

**추가할 콜백**:
```dart
// 테이크아웃 주문 처리 콜백
void _handleTakeoutOrder() async {
  // 1. 고객 정보 입력 다이얼로그
  final customerInfo = await _showCustomerInfoDialog();
  if (customerInfo == null) return;
  
  // 2. 결제 처리 (기존과 동일)
  await _processPayment();
  
  // 3. 테이크아웃 주문 생성
  await _createTakeoutOrder(customerInfo);
  
  // 4. 주문서 출력
  await _printOrderSlip();
}

// 고객 정보 입력 다이얼로그
Future<CustomerInfo?> _showCustomerInfoDialog() async {
  return await showDialog<CustomerInfo>(
    context: context,
    builder: (context) => CustomerInfoDialog(),
  );
}
```

### 3단계: 고객 정보 다이얼로그 생성

#### 3.1 CustomerInfoDialog 위젯
**파일**: `lib/ui/sales/widgets/customer_info_dialog.dart`

```dart
class CustomerInfoDialog extends StatefulWidget {
  @override
  _CustomerInfoDialogState createState() => _CustomerInfoDialogState();
}

class _CustomerInfoDialogState extends State<CustomerInfoDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('📋 테이크아웃 주문 정보'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '고객명',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: '연락처 (선택사항)',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          SizedBox(height: 16),
          Text(
            '💡 주문번호가 발행되어 조리 완료 시 알림을 받을 수 있습니다.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            final customerInfo = CustomerInfo(
              name: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
            );
            Navigator.pop(context, customerInfo);
          },
          child: Text('주문 등록'),
        ),
      ],
    );
  }
}

class CustomerInfo {
  final String name;
  final String phone;
  
  CustomerInfo({required this.name, required this.phone});
}
```

---

## 🎨 대안 UI 패턴들

### 패턴 2: 메인/서브 버튼
```
┌─────────────────────────────────────────┐
│ [        💳 즉시 결제        ]          │
│                                         │
│ [📋 테이크아웃 주문으로 등록]           │
└─────────────────────────────────────────┘
```

**장점**: 기본 동작(즉시 결제)이 명확  
**단점**: 세로 공간을 더 많이 차지

### 패턴 3: 토글 + 단일 버튼
```
┌─────────────────────────────────────────┐
│ 주문 유형: [즉시완료] [테이크아웃] ◄─── │
├─────────────────────────────────────────┤
│ [         결제하기         ]            │
└─────────────────────────────────────────┘
```

**장점**: 기존 버튼 구조 유지  
**단점**: 2단계 조작 필요 (토글 → 결제)

### 패턴 4: 드롭다운 방식
```
┌─────────────────────────────────────────┐
│ [    결제 방식 선택 ▼    ]              │
│ └─ • 즉시 결제 완료                     │
│    • 테이크아웃 주문 등록               │
└─────────────────────────────────────────┘
```

**장점**: 공간 절약, 확장 가능  
**단점**: 터치 기반 POS에서 불편함

---

## 🚀 구현 우선순위

### Phase 1: 기본 UI 분리 (1일)
- [ ] CartSidebar 수정 - 수평 분할 버튼
- [ ] CartBottomSheet 수정 - 동일 패턴 적용
- [ ] SalesPage 콜백 함수 추가

### Phase 2: 고객 정보 입력 (0.5일)
- [ ] CustomerInfoDialog 위젯 생성
- [ ] 입력 유효성 검사 추가
- [ ] 다국어 지원 키 추가

### Phase 3: 테이크아웃 주문 연동 (1일)
- [ ] 테이크아웃 주문 생성 로직
- [ ] 주문번호 발행 시스템
- [ ] 주문서 출력 기능

### Phase 4: 사용성 개선 (0.5일)
- [ ] 애니메이션 효과 추가
- [ ] 접근성 개선 (음성 안내 등)
- [ ] 키보드 단축키 지원

**총 예상 기간**: 3일

---

## 📱 반응형 고려사항

### 모바일/태블릿 (좁은 화면)
```
┌─────────────────────┐
│ [    즉시 결제    ] │
│ [  테이크아웃 등록  ] │
└─────────────────────┘
```
- 세로 배치로 변경
- 버튼 높이 증가

### 데스크톱 (넓은 화면)
```
┌─────────────────────────────────────┐
│ [  즉시 결제  ] [  테이크아웃 등록  ] │
└─────────────────────────────────────┘
```
- 수평 배치 유지
- 버튼 간격 증가

---

## 🎯 사용자 시나리오

### 시나리오 1: 매장 내 식사
1. 상품 선택 완료
2. **"즉시 결제"** 버튼 클릭
3. 결제 방법 선택 (카드/현금/포인트)
4. 결제 완료 → 영수증 출력
5. 주문 완료 (기존과 동일)

### 시나리오 2: 테이크아웃 주문
1. 상품 선택 완료
2. **"테이크아웃 등록"** 버튼 클릭
3. 고객 정보 입력 (이름, 연락처)
4. 결제 방법 선택
5. 결제 완료 → 주문번호 #A01 발행
6. 주문서 출력 (주문번호 포함)
7. 주문 관리 화면에 자동 등록

---

## 💡 추가 개선 아이디어

### 단기 개선
- **빠른 고객 등록**: 단골 고객 목록에서 선택
- **기본값 설정**: 매장별로 주 사용 방식을 기본값으로 설정
- **통계 연동**: 테이크아웃 vs 매장 내 비율 분석

### 장기 개선
- **QR 코드 주문**: 고객이 직접 주문하고 테이크아웃 등록
- **예약 주문**: 특정 시간에 픽업하는 사전 주문
- **배달 연동**: 배달 서비스와 연계

---

**작성일**: 2026-02-05  
**설계자**: AI Assistant  
**우선 구현**: 패턴 1 (수평 분할 버튼)