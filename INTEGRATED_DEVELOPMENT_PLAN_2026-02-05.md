# POSAce 통합 개발 계획 (2026-02-05)

**프로젝트**: POSAce Windows App 기능 확장 및 안정성 개선  
**기간**: 2026-02-05 ~ 2026-02-20 (약 15일)  
**상태**: 계획 수립 완료

---

## 🎯 개발 목표

### 주요 기능 추가
1. **테이크아웃 주문 관리 시스템** - 커피 전문점 특화 기능
2. **결제 버튼 분리** - 즉시 결제 vs 테이크아웃 주문 구분
3. **설치 안정성 개선** - VCRUNTIME140_1.dll 오류 해결

### 품질 개선
- Windows Surface PC 호환성 확보
- 사용자 경험 개선
- 설치 성공률 향상

---

## 📅 통합 개발 일정

### **Week 1: 기반 구조 및 UI 개선 (2/5 ~ 2/11)**

#### **Day 1-2: 결제 시스템 개선** 
**담당**: UI/UX 팀  
**우선순위**: High

- [x] 결제 버튼 분리 설계 완료
- [ ] CartSidebar 위젯 수정 (수평 분할 버튼)
- [ ] CartBottomSheet 위젯 수정
- [ ] 고객 정보 입력 다이얼로그 생성
- [ ] SalesPage 콜백 함수 추가

**결과물**:
- 수평 분할 결제 버튼 UI
- 고객 정보 입력 시스템
- 테이크아웃/즉시결제 구분 로직

#### **Day 3-4: 테이크아웃 데이터 모델**
**담당**: 백엔드 팀  
**우선순위**: High

- [ ] TakeoutOrderModel 클래스 설계 및 구현
- [ ] 데이터베이스 스키마 추가 (takeout_orders 테이블)
- [ ] 주문번호 생성 시스템 구현
- [ ] TakeoutOrderDao CRUD 작업 구현

**결과물**:
- 테이크아웃 주문 데이터 구조
- 주문번호 발행 시스템
- 로컬 데이터베이스 확장

#### **Day 5: 설치 시스템 개선**
**담당**: DevOps 팀  
**우선순위**: High

- [x] VCRUNTIME 오류 분석 완료
- [x] 개선된 설치 스크립트 작성 완료
- [ ] 런타임 DLL 수집 및 테스트
- [ ] 향상된 설치 파일 빌드

**결과물**:
- VCRUNTIME140_1.dll 오류 해결
- Surface PC 호환성 확보
- 자동화된 빌드 스크립트

### **Week 2: 주문 관리 화면 구현 (2/12 ~ 2/18)**

#### **Day 6-8: 주문 관리 UI**
**담당**: UI/UX 팀  
**우선순위**: High

- [ ] TakeoutOrderManagementPage 구현
- [ ] OrderCard 위젯 (주문 카드 UI)
- [ ] 상태별 필터링 (대기중/조리중/완료/전체)
- [ ] 실시간 업데이트 시스템 (StreamBuilder)
- [ ] 상태 변경 버튼 (조리시작/완료/픽업완료)

**결과물**:
- 직관적인 주문 관리 화면
- 실시간 주문 상태 추적
- 터치 친화적 인터페이스

#### **Day 9-10: 알림 시스템**
**담당**: 시스템 팀  
**우선순위**: Medium

- [ ] NotificationService 추상화
- [ ] SMS 알림 구현 (외부 API 연동)
- [ ] 고객용 디스플레이 화면
- [ ] 알림 설정 관리 시스템

**결과물**:
- 다양한 알림 방법 지원
- 고객용 디스플레이 시스템
- 설정 가능한 알림 옵션

#### **Day 11: 판매 시스템 연동**
**담당**: 백엔드 팀  
**우선순위**: High

- [ ] SalesPage와 테이크아웃 주문 연동
- [ ] 영수증/주문서 출력 개선
- [ ] 주문번호 포함 템플릿 생성
- [ ] 결제 완료 후 주문 등록 로직

**결과물**:
- 완전한 테이크아웃 주문 플로우
- 주문번호 포함 출력물
- 기존 시스템과의 완벽한 통합

### **Week 3: 테스트 및 배포 (2/19 ~ 2/20)**

#### **Day 12-13: 통합 테스트**
**담당**: QA 팀  
**우선순위**: High

- [ ] 기능 테스트 (테이크아웃 주문 전체 플로우)
- [ ] 호환성 테스트 (Surface PC, 다양한 Windows 버전)
- [ ] 성능 테스트 (다중 주문 처리)
- [ ] 사용성 테스트 (실제 카페 환경 시뮬레이션)

#### **Day 14-15: 배포 및 문서화**
**담당**: 전체 팀  
**우선순위**: High

- [ ] 프로덕션 빌드 및 배포
- [ ] 사용자 매뉴얼 작성
- [ ] 기술 문서 업데이트
- [ ] 배포 후 모니터링

---

## 🏗️ 기술 아키텍처

### 새로운 컴포넌트

#### 1. UI 컴포넌트
```
lib/ui/takeout/
├── takeout_order_management_page.dart    # 주문 관리 메인 화면
├── customer_display_page.dart            # 고객용 디스플레이
└── widgets/
    ├── order_card.dart                   # 주문 카드 위젯
    ├── order_status_filter.dart          # 상태 필터
    ├── order_stats_summary.dart          # 통계 요약
    └── customer_info_dialog.dart         # 고객 정보 입력
```

#### 2. 데이터 모델
```
lib/data/local/models/
├── takeout_order_model.dart              # 테이크아웃 주문 모델
└── order_notification_settings.dart     # 알림 설정 모델
```

#### 3. 서비스 계층
```
lib/core/services/
├── takeout_order_service.dart            # 주문 관리 서비스
├── order_number_generator.dart           # 주문번호 생성
└── notification_service.dart             # 알림 서비스
```

#### 4. 설치 시스템
```
installers/
├── setup_enhanced.iss                    # 개선된 설치 스크립트
├── redistributables/                     # 런타임 DLL 저장소
└── scripts/
    ├── collect_runtime_dlls.ps1          # DLL 수집 스크립트
    └── build_setup_enhanced.ps1          # 빌드 스크립트
```

### 데이터베이스 확장
```sql
-- 새로 추가될 테이블
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

## 🎨 UI/UX 설계

### 결제 버튼 개선
**Before**:
```
┌─────────────────────┐
│ [      결제      ] │
└─────────────────────┘
```

**After**:
```
┌─────────────────────────────────────┐
│ [  💳 즉시 결제  ] [  📋 테이크아웃  ] │
└─────────────────────────────────────┘
```

### 주문 관리 화면
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
│ │ 🔴 대기중│ │ 🟡 조리중│ │ 🟢 완료 │                         │
│ │ 아메리카노│ │ 카페라떼 │ │ 카푸치노 │                         │
│ │ 12:34   │ │ 12:35   │ │ 12:36   │                         │
│ │ 김○○   │ │ 이○○   │ │ 박○○   │                         │
│ │ [조리시작]│ │ [완료]  │ │ [픽업]  │                         │
│ └─────────┘ └─────────┘ └─────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔧 구현 우선순위

### Critical Path (필수 구현)
1. **결제 버튼 분리** → 테이크아웃 주문 생성 가능
2. **주문 데이터 모델** → 주문 저장 및 관리 가능  
3. **주문 관리 화면** → 주문 상태 추적 가능
4. **VCRUNTIME 오류 해결** → Surface PC 설치 가능

### Nice to Have (선택적 구현)
1. SMS 알림 시스템
2. 고객용 디스플레이
3. 고급 통계 기능
4. 음성 알림

---

## 📊 성공 지표

### 기능적 지표
- ✅ 테이크아웃 주문 생성 성공률: 95% 이상
- ✅ 주문 상태 변경 응답 시간: 1초 이내
- ✅ Surface PC 설치 성공률: 98% 이상
- ✅ VCRUNTIME 오류 발생률: 2% 이하

### 사용자 경험 지표
- ✅ 주문 처리 시간 단축: 30% 이상
- ✅ 사용자 만족도: 4.5/5.0 이상
- ✅ 설치 관련 지원 요청: 50% 감소

---

## 🚨 위험 요소 및 대응책

### 기술적 위험
1. **Flutter Windows 호환성**
   - 위험도: Medium
   - 대응: 다양한 Windows 버전에서 사전 테스트

2. **실시간 업데이트 성능**
   - 위험도: Medium  
   - 대응: StreamBuilder 최적화, 메모리 관리 강화

3. **설치 파일 크기 증가**
   - 위험도: Low
   - 대응: 선택적 DLL 포함, 온라인 다운로드 옵션

### 비즈니스 위험
1. **기존 사용자 워크플로우 변경**
   - 위험도: Medium
   - 대응: 기존 기능 유지, 점진적 마이그레이션

2. **테스트 기간 부족**
   - 위험도: High
   - 대응: 병렬 개발, 조기 베타 테스트

---

## 📋 체크리스트

### 개발 완료 조건
- [ ] 결제 버튼 분리 구현 완료
- [ ] 테이크아웃 주문 생성/관리 기능 완료
- [ ] 주문 상태 변경 및 알림 기능 완료
- [ ] VCRUNTIME 오류 해결 완료
- [ ] 모든 기능 테스트 통과
- [ ] 성능 요구사항 충족
- [ ] 사용자 문서 작성 완료

### 배포 준비 조건
- [ ] 프로덕션 빌드 성공
- [ ] Surface PC 호환성 검증
- [ ] 보안 검토 완료
- [ ] 백업 및 롤백 계획 수립
- [ ] 사용자 교육 자료 준비

---

**작성일**: 2026-02-05  
**검토자**: 개발팀 전체  
**승인자**: 프로젝트 매니저  
**다음 검토일**: 2026-02-12