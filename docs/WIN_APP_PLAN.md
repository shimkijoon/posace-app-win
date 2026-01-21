# POS Windows 앱 개발 계획

> 목적: Windows POS 클라이언트 개발을 단계별로 진행하기 위한 계획서
> 범위: Windows 우선 개발 후 Android 확장 대비

## 0) 목표/원칙

- 로컬 DB는 SQLite 사용
- 앱 실행 시 마스터 자동 동기화 + 수동 동기화 버튼 제공
- 매출은 즉시 업로드 + 실패 시 큐에 저장 후 재시도
- 로컬 DB는 언제든 삭제 후 서버 마스터로 복구 가능
- 전세계 오픈을 고려해 다국어/통화/세금/시간대 대응
- 국가별 세금(부가세/판매세 등) 차이를 고려한 계산 구조
- 영수증 출력 기능 포함
- 결제단말기 연동은 국가별로 순차 지원

## 0-1) 업종 모드(유통/외식) 전략

### 업종별 차이 요약
- 유통업(리테일): 바코드 기반 빠른 판매, 상품/재고 중심, 단순 주문 구조
- 외식업(레스토랑): 테이블/좌석, 코스/주문 흐름, 주방 전송, 팁/봉사료 등

### 코드 관리 방식 제안
- **단일 코드베이스 + 모드 선택(권장)**
  - 공통(core/data/sync) 레이어 공유
  - UI/업무흐름만 모듈 분리(유통/외식)
  - 런타임 모드 선택 또는 매장 설정으로 분기
- 대안: 레포 분리(유지보수/릴리즈 비용 증가, 공통 로직 중복)

### 우선 구현 추천
- **유통업 모드 우선**
  - 기능 범위가 단순해 MVP 출시가 빠름
  - 이후 외식업 기능(테이블/주방)을 모듈로 추가
  - 글로벌 확장 시 리테일 수요가 더 광범위

## 1) 기반 구조

- 프로젝트 구조 (권장)
  - `core/` 도메인/유스케이스
  - `data/` API/SQLite/리포지토리
  - `ui/` 화면/위젯
  - `sync/` 동기화/큐/재시도
- 환경설정: `API_BASE_URL`, POS 토큰 저장

## 2) 인증/디바이스 등록

- 백오피스에서 POS 디바이스 토큰 발급
- 앱에서 디바이스 토큰 입력 → POS 로그인
- POS JWT 저장

## 3) 마스터 동기화

- `GET /pos/stores/{storeId}/master` 호출
- SQLite에 카테고리/상품/할인 저장
- `updatedAfter` 기반 증분 동기화
- 수동 동기화 버튼 제공

## 4) 판매/장바구니

- 상품 검색/추가/수량 변경
- 할인 적용(상품/장바구니)
- 결제 수단 선택

## 5) 매출 업로드

- 결제 완료 즉시 업로드
- 실패 시 로컬 큐 저장
- 백그라운드/재시도 처리

## 6) 재고/상품 상태 동기화

- 재고 조정
- 상품 판매중/중지 토글

## 7) 세션/마감

- 오픈/클로즈 금액 입력
- 차이(variance) 계산 및 기록

## 8) 로그/모니터링 (선택)

- 에러/상태 로그 업로드

## 9) 진행 체크리스트

- [x] 1) 기반 구조
- [x] 2) 인증/디바이스 등록
- [x] 3) 마스터 동기화
- [x] 4) 판매/장바구니
- [x] 매출 업로드 (백엔드 연동)
- [x] 매출 업로드 (결제 로직 연결)
- [x] 매출 동기화 오류 수정 (whereArgs 누락 수정)
- [x] 할인 로직 고도화 및 UI 개선 (Footerd fixed, Red color, Aggregation)
- [x] 7) Z-Report/마감 (구조만 준비됨)
- [ ] 8) 로그/모니터링

## 10) 현재까지 진행 내역

- Flutter Windows 프로젝트 생성 및 구조 분리(core/data/ui/sync)
- POS 디바이스 토큰 로그인 화면 구현
- POS 토큰/매장 정보 로컬 저장
- Flutter 업데이트 완료 (3.35.5 → 3.38.7)
- Visual Studio 2026 설치 완료 (D:\Microsoft Visual Studio\18\Community)
- Windows 앱 빌드 및 실행 성공
- POS 디바이스 토큰으로 로그인 성공 확인
- 시드 데이터에 POS 디바이스 토큰 자동 생성 기능 추가
- SQLite 데이터베이스 설정 완료 (sqflite_common_ffi 사용)
- 마스터 데이터 모델 정의 (CategoryModel, ProductModel, DiscountModel)
- API 클라이언트에 마스터 데이터 엔드포인트 추가 (`/pos/stores/:storeId/master`)
- 동기화 서비스 구현 (자동/수동 동기화, 증분 동기화 지원)
- 홈 화면에 동기화 버튼 및 데이터 통계 표시 추가
- 마스터 데이터 동기화 성공 확인 (카테고리 5개, 상품 25개, 할인 2개)
2026-01-19:
 - 매출 동기화 중 `Invalid argument` 오류 수정 (SQL 인자 누락 해결)
 - 할인 계산 로직 재설계 (상품 할인 + 장바구니 할인 통합 표시)
 - 소계(Subtotal) 정의 변경 (정가 합계로 변경하여 투명성 제고)
 - 장바구니 UI 개선 (고정 푸터 할인 행, Red 폰트, 자동 스크롤, 상시 스크롤바)
- 판매 화면 레이아웃 구현 (50:50 분할, 좌측 장바구니 그리드, 우측 상품 선택 영역)
- 화면 기본 크기 1024x768 설정
- 장바구니 그리드 개선:
  - 바코드, 할인금액 컬럼 추가
  - 컬럼 헤더 우측에 스크롤 버튼 추가 (스크롤 가능할 때만 표시)
  - 상품 선택 시 X 버튼 표시 기능 추가
  - 선택된 행 시각적 강조 (배경색, 텍스트 스타일)
- 상품 선택 영역 구현:
  - 카테고리 탭 (가로 스크롤)
  - 상품 그리드 (4열 2행)
  - 상품 검색 및 바코드 입력 기능
  - 기능 버튼 (할인, 회원, 취소, 거래보류, 결제)
- 장바구니 하단 합계 정보 표시 (소계, 할인, 세금, 총액)
- 카테고리 버튼 스타일 개선 및 크기 증가
- 기능 버튼과 결제 버튼 스타일 통일
- 로컬 SQLite DB 확장:
  - `sales`, `sale_items` 테이블 추가 (버전 2)
  - `SaleModel`, `SaleItemModel` 정의
  - 매출 저장 및 동기화용 메서드 구현 (`insertSale`, `getUnsyncedSales` 등)
- 판매 화면 결제 로직 연결:
  - `uuid` 패키지 추가
  - 결제 수단 선택 다이얼로그 (현금/카드) 구현
  - 결제 완료 시 로컬 DB 저장 (`Sale`, `SaleItem`) 및 장바구니 초기화 로직 구현
- 매출 데이터 서버 동기화 구현:
  - `PosSalesApi` 원격 클라이언트 구현
  - `SyncService` 내 매출 업로드 큐 처리 로직 (`flushSalesQueue`) 구현
  - 홈 화면에 '미전송 매출' 카운터 추가 및 동기화 버튼 연동
2026-01-21:
- 이메일/비밀번호 기반 매장주 로그인 전환 및 테스트 로그인 기능 추가
- 로컬 DB v5 마이그레이션 (`products.type` 컬럼 추가)
- 장바구니 할인 중복 적용 방지 로직 구현 (Deduplication)
- 상품 옵션(온도 등) 파싱 오류 수정 및 선택 다이얼로그 연동 확인
- 장바구니 고액(10,000원 이상) 결제 시 레이아웃 오버플로우 수정
- 메인 화면에 '데이터 초기화' 버튼 추가 (동기화 꼬임 방지용)

## 11) 로컬 실행 방법 (전체 스택)

### 1) DB (Postgres)
```
cd D:\workspace\github.com\shimkijoon\posace-api
docker compose -f docker-compose.local.yml up -d
```

### 2) API
```
cd D:\workspace\github.com\shimkijoon\posace-api
$env:DATABASE_URL="postgresql://posace:posace@localhost:5432/posace_local"
$env:JWT_SECRET="dev-secret"
pnpm dev
```

### 3) Backoffice
```
cd D:\workspace\github.com\shimkijoon\posace-backoffice
$env:NEXT_PUBLIC_API_BASE_URL="http://localhost:3000/api/v1"
pnpm dev
```

### 4) Windows App
```
cd D:\workspace\github.com\shimkijoon\posace-app-win
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

**참고:**
- Visual Studio 2026 (또는 2022) 설치 필요 (Desktop development with C++ 워크로드)
- Flutter 3.38.7 이상 권장
- 시드 데이터 실행 후 생성된 POS 디바이스 토큰을 앱에 입력하여 로그인

## 12) 문서 및 워크플로우 규칙

### 문서 관리 원칙
1.  **Single Source of Truth**: 모든 기능 명세, 일정, 진행 상황은 이 파일(`WIN_APP_PLAN.md`)에서 관리한다.
2.  **Archive Strategy**: 조사를 위한 임시 문서 등은 목적 달성 후 `docs/archive/`로 이동하거나 삭제한다.
3.  **Scratchpad**: 단순 메모, 로그, 일일 업무 정리는 `docs/SCRATCHPAD.md`를 사용한다.

### 업무 루틴 (Routine)
- **Start**: `PLAN.md` 체크리스트 확인 -> `SCRATCHPAD.md` Next Step 확인
- **End**: `PLAN.md` 업데이트 -> `SCRATCHPAD.md`에 "오늘 한 일 & 내일 할 일" 정리

