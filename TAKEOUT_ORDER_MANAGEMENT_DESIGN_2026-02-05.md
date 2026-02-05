# 테이크아웃 주문 관리 시스템 설계서 (2026-02-05)

**프로젝트**: POSAce - 테이크아웃 주문 관리 기능 추가  
**대상**: 테이크아웃 커피 전문점  
**날짜**: 2026-02-05

---

## 📋 비즈니스 요구사항

### 🎯 목표
- 테이크아웃 주문의 체계적 관리
- 조리 완료 시 고객 알림 자동화
- 주문번호 기반 주문 추적
- 효율적인 주문 처리 워크플로우

### 🏪 타겟 비즈니스
- **테이크아웃 커피 전문점**
- **패스트푸드 매장**
- **베이커리 (사전주문)**
- **기타 테이크아웃 전문점**

---

## 🎨 UI/UX 설계

### 1. 메인 네비게이션 추가
**위치**: 홈 화면 메인 버튼 영역
```
[상품 판매] [테이블 주문] [주문 관리] [판매 내역] [환경설정]
                          ↑ 새로 추가
```

### 2. 주문 관리 화면 (Order Management Page)
**레이아웃**: 3단 구조
```
┌─────────────────────────────────────────────────────────────┐
│ [← 홈] 주문 관리                    [새로고침] [설정] [알림]  │
├─────────────────────────────────────────────────────────────┤
│ 📊 현황: 대기 3건 | 조리중 2건 | 완료 1건 | 총 6건           │
├─────────────────────────────────────────────────────────────┤
│ [대기중] [조리중] [완료] [전체]                               │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐                         │
│ │ #001    │ │ #002    │ │ #003    │                         │
│ │ 아메리카노│ │ 카페라떼 │ │ 카푸치노 │                         │
│ │ 12:34   │ │ 12:35   │ │ 12:36   │                         │
│ │ 김○○   │ │ 이○○   │ │ 박○○   │                         │
│ │ [조리시작]│ │ [완료]  │ │ [알림]  │                         │
│ └─────────┘ └─────────┘ └─────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

### 3. 주문 카드 상세 설계
```
┌─────────────────────────────────┐
│ #001                    🔴 대기중 │
├─────────────────────────────────┤
│ 📱 010-1234-5678               │
│ 👤 김○○                        │
│ 🕐 12:34 (3분 경과)            │
├─────────────────────────────────┤
│ ☕ 아메리카노 HOT x1            │
│ ☕ 카페라떼 ICE x2              │
│ 🍰 치즈케이크 x1                │
├─────────────────────────────────┤
│ 💰 총 15,000원                 │
├─────────────────────────────────┤
│ [조리 시작] [상세보기] [취소]    │
└─────────────────────────────────┘
```

### 4. 상태별 색상 시스템
- 🔴 **대기중**: 빨간색 (긴급도 표시)
- 🟡 **조리중**: 노란색 (진행중)
- 🟢 **완료**: 초록색 (픽업 대기)
- ⚪ **픽업완료**: 회색 (완료됨)

---

## 🏗️ 시스템 아키텍처

### 1. 데이터 모델 설계

#### TakeoutOrder (테이크아웃 주문)
```dart
class TakeoutOrderModel {
  final String id;                    // UUID
  final String orderNumber;           // 주문번호 (예: "001", "A01")
  final String saleId;               // 원본 판매 ID (Sale 테이블 참조)
  final TakeoutOrderStatus status;   // 주문 상태
  final DateTime createdAt;          // 주문 생성 시간
  final DateTime? cookingStartedAt;  // 조리 시작 시간
  final DateTime? completedAt;       // 조리 완료 시간
  final DateTime? pickedUpAt;        // 픽업 완료 시간
  final String? customerName;        // 고객명
  final String? customerPhone;       // 고객 전화번호
  final String? specialInstructions; // 특별 요청사항
  final int estimatedMinutes;        // 예상 조리 시간
  final bool notificationSent;       // 알림 발송 여부
}

enum TakeoutOrderStatus {
  waiting,    // 대기중
  cooking,    // 조리중  
  completed,  // 조리완료 (픽업 대기)
  pickedUp    // 픽업완료
}
```

#### OrderNotificationSettings (알림 설정)
```dart
class OrderNotificationSettings {
  final bool smsEnabled;           // SMS 알림 사용
  final bool buzzerEnabled;        // 진동벨 사용
  final bool displayEnabled;       // 고객용 디스플레이 사용
  final String smsTemplate;        // SMS 템플릿
  final int autoCompleteMinutes;   // 자동 완료 처리 시간
}
```

### 2. 데이터베이스 스키마

#### takeout_orders 테이블
```sql
CREATE TABLE takeout_orders (
  id TEXT PRIMARY KEY,
  order_number TEXT NOT NULL UNIQUE,
  sale_id TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  cooking_started_at TEXT,
  completed_at TEXT,
  picked_up_at TEXT,
  customer_name TEXT,
  customer_phone TEXT,
  special_instructions TEXT,
  estimated_minutes INTEGER DEFAULT 10,
  notification_sent INTEGER DEFAULT 0,
  FOREIGN KEY (sale_id) REFERENCES sales (id)
);
```

#### order_notification_settings 테이블
```sql
CREATE TABLE order_notification_settings (
  id INTEGER PRIMARY KEY,
  sms_enabled INTEGER DEFAULT 0,
  buzzer_enabled INTEGER DEFAULT 1,
  display_enabled INTEGER DEFAULT 0,
  sms_template TEXT DEFAULT '주문이 완료되었습니다. 주문번호: {orderNumber}',
  auto_complete_minutes INTEGER DEFAULT 30
);
```

---

## 🔧 구현 계획

### Phase 1: 기본 구조 (1-2일)

#### 1.1 데이터 모델 및 데이터베이스
- [ ] `TakeoutOrderModel` 클래스 생성
- [ ] 데이터베이스 마이그레이션 스크립트
- [ ] `TakeoutOrderDao` 구현 (CRUD 작업)

#### 1.2 주문번호 생성 시스템
- [ ] 주문번호 생성 로직 (예: 일별 순번, 알파벳+숫자)
- [ ] 중복 방지 메커니즘
- [ ] 설정 가능한 번호 형식

#### 1.3 기본 UI 구조
- [ ] `TakeoutOrderManagementPage` 생성
- [ ] 홈 화면에 "주문 관리" 버튼 추가
- [ ] 기본 레이아웃 및 네비게이션

### Phase 2: 주문 관리 화면 (2-3일)

#### 2.1 주문 목록 표시
- [ ] 주문 카드 위젯 (`OrderCard`)
- [ ] 상태별 필터링 (대기중/조리중/완료/전체)
- [ ] 실시간 업데이트 (Stream/StateManagement)

#### 2.2 상태 변경 기능
- [ ] "조리 시작" 버튼 → 대기중 → 조리중
- [ ] "조리 완료" 버튼 → 조리중 → 완료
- [ ] "픽업 완료" 버튼 → 완료 → 픽업완료

#### 2.3 시간 추적 및 표시
- [ ] 경과 시간 실시간 표시
- [ ] 예상 완료 시간 계산
- [ ] 지연 주문 하이라이트

### Phase 3: 판매 연동 (1-2일)

#### 3.1 SalesPage 수정
- [ ] 결제 완료 시 테이크아웃 주문 생성 옵션
- [ ] 고객 정보 입력 다이얼로그 (이름, 전화번호)
- [ ] 주문번호 표시 및 안내

#### 3.2 영수증 출력 개선
- [ ] 영수증에 주문번호 추가
- [ ] 별도 주문서 템플릿 생성
- [ ] 주문서 출력 기능

### Phase 4: 알림 시스템 (2-3일)

#### 4.1 알림 인프라
- [ ] 알림 서비스 추상화 (`NotificationService`)
- [ ] SMS 알림 구현 (외부 API 연동)
- [ ] 진동벨 시뮬레이션 (소리 또는 시각적 효과)

#### 4.2 고객용 디스플레이
- [ ] 별도 고객용 화면 (`CustomerDisplayPage`)
- [ ] 완료된 주문번호 표시
- [ ] 자동 새로고침 및 애니메이션

#### 4.3 알림 설정
- [ ] 알림 방법 선택 (SMS/진동벨/디스플레이)
- [ ] SMS 템플릿 편집
- [ ] 자동 완료 처리 시간 설정

### Phase 5: 고급 기능 (1-2일)

#### 5.1 통계 및 분석
- [ ] 평균 조리 시간 계산
- [ ] 일별/시간대별 주문 현황
- [ ] 지연 주문 분석

#### 5.2 사용성 개선
- [ ] 키보드 단축키 (F1: 조리시작, F2: 완료 등)
- [ ] 소리 알림 (새 주문, 완료 등)
- [ ] 다크모드 지원

---

## 📁 파일 구조

### 새로 생성할 파일들
```
lib/
├── ui/
│   ├── takeout/
│   │   ├── takeout_order_management_page.dart
│   │   ├── customer_display_page.dart
│   │   └── widgets/
│   │       ├── order_card.dart
│   │       ├── order_status_filter.dart
│   │       ├── order_stats_summary.dart
│   │       └── customer_info_dialog.dart
├── data/
│   ├── local/
│   │   └── models/
│   │       ├── takeout_order_model.dart
│   │       └── order_notification_settings.dart
│   └── remote/
│       └── notification_api.dart
├── core/
│   ├── services/
│   │   ├── takeout_order_service.dart
│   │   ├── order_number_generator.dart
│   │   └── notification_service.dart
│   └── printer/
│       └── order_slip_templates.dart
└── l10n/
    └── (다국어 지원 키 추가)
```

### 수정할 기존 파일들
```
lib/
├── ui/
│   ├── home/home_page.dart              # 주문 관리 버튼 추가
│   └── sales/sales_page.dart            # 테이크아웃 주문 생성 연동
├── data/local/app_database.dart         # 새 테이블 추가
└── core/printer/receipt_templates.dart  # 주문번호 추가
```

---

## 🎯 사용자 시나리오

### 시나리오 1: 일반적인 주문 처리
1. **고객 주문**: 아메리카노 2잔, 카페라떼 1잔
2. **직원 결제 처리**: SalesPage에서 결제 완료
3. **테이크아웃 주문 생성**: 고객 정보 입력 후 주문번호 #A01 발행
4. **주문서 출력**: 주문번호와 상품 목록이 포함된 주문서 출력
5. **주문 관리**: 주문 관리 화면에서 #A01 확인
6. **조리 시작**: "조리 시작" 버튼 클릭 → 상태 변경
7. **조리 완료**: "조리 완료" 버튼 클릭 → 고객에게 SMS 발송
8. **픽업**: 고객 방문 시 "픽업 완료" 클릭 → 주문 완료

### 시나리오 2: 바쁜 시간대 관리
1. **다중 주문**: 10개 주문이 동시에 대기중
2. **우선순위 관리**: 경과 시간 기준으로 정렬
3. **배치 처리**: 여러 주문을 동시에 조리 시작
4. **실시간 모니터링**: 각 주문의 진행 상황 실시간 확인
5. **자동 알림**: 완료된 주문들 자동으로 고객에게 알림

---

## 🔍 기술적 고려사항

### 1. 성능 최적화
- **실시간 업데이트**: StreamBuilder 사용으로 효율적인 UI 업데이트
- **메모리 관리**: 완료된 주문의 적절한 정리 (24시간 후 자동 삭제)
- **데이터베이스 인덱싱**: order_number, status, created_at 컬럼 인덱스

### 2. 확장성
- **플러그인 아키텍처**: 다양한 알림 방법 추가 가능
- **설정 시스템**: 매장별 맞춤 설정 지원
- **다국어 지원**: 글로벌 확장 대비

### 3. 안정성
- **오프라인 지원**: 네트워크 연결 없이도 기본 기능 동작
- **데이터 백업**: 주문 데이터 자동 백업
- **에러 처리**: 알림 발송 실패 시 재시도 로직

---

## 📊 예상 개발 일정

| Phase | 작업 내용 | 예상 기간 | 우선순위 |
|-------|-----------|-----------|----------|
| 1 | 기본 구조 및 데이터 모델 | 1-2일 | High |
| 2 | 주문 관리 화면 | 2-3일 | High |
| 3 | 판매 연동 | 1-2일 | High |
| 4 | 알림 시스템 | 2-3일 | Medium |
| 5 | 고급 기능 | 1-2일 | Low |

**총 예상 기간**: 7-12일

---

## 💡 추가 아이디어

### 단기 확장 기능
- **QR 코드**: 주문번호 QR 코드 생성으로 빠른 확인
- **음성 알림**: TTS로 주문번호 호출
- **태블릿 지원**: 고객용 디스플레이를 태블릿으로 분리

### 장기 확장 기능
- **모바일 앱 연동**: 고객용 모바일 앱에서 주문 상태 확인
- **예약 주문**: 특정 시간에 픽업할 사전 주문 기능
- **로열티 연동**: 단골 고객 우대 시스템

---

**작성일**: 2026-02-05  
**설계자**: AI Assistant  
**검토 필요**: 비즈니스 요구사항 재확인, UI/UX 피드백