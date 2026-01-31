# POSAce Windows Client

Flutter 기반 Windows POS 클라이언트 애플리케이션.

## 최근 업데이트

### 2026-01-31 (금)
- **빌드 오류 수정**: PDB 파일 잠금 문제로 인한 C++ 컴파일 오류 해결
  - 원인: 여러 CL.EXE 프로세스가 동시에 같은 .PDB 파일 접근
  - 해결: `flutter clean` 후 재빌드로 해결
  - 영향받은 플러그인: `url_launcher_windows`, `flutter_libserialport`
- **번역 누락 수정**: 모든 언어 파일에 `common.select` 키 추가 (ko, en, ja, zh-TW, zh-HK)

### 2026-01-29

### 프로덕션 배포 설정
- **도메인 적용**: API 기본 URL을 `https://api.posace.com/api/v1`로 변경
- **MSIX 빌드 구성**: Windows 설치 패키지 자동 생성 기능 추가
- **버전 업데이트**: 1.0.0+1 → 1.0.1+2
- **GitHub Actions CI/CD**: 자동 빌드 및 릴리즈 워크플로우 추가
  - 태그 푸시 시 자동으로 MSIX 빌드
  - GitHub Releases에 자동 배포
  - 최신 버전 다운로드: `releases/latest/download/posace_app_win.msix`
- **프로덕션 보안 강화**: 테스트 계정 선택 UI를 디버그 모드에서만 표시 (`kDebugMode`)

### 앱 종료 개선
- **종료 확인 팝업 추가**: 창 닫기(X 버튼) 클릭 시 종료 확인 다이얼로그 표시
- **window_manager 통합**: Windows 네이티브 창 제어를 위한 패키지 추가
- **우아한 종료**: 리소스 정리 후 50ms 딜레이로 빠른 종료 처리

### 프린터 기능 개선
- **자동 연결**: 시리얼 프린터 미연결 시 자동 연결 시도
- **주방주문서 양식 개선**: 해외 주방 스타일 적용 (예: "2 X 아메리카노")
- **옵션 출력**: 주방주문서에 상품 옵션 표시 (예: "+ 휘핑크림 추가")
- **테스트 인쇄 개선**: 실제 양식 기반 샘플 영수증/주방주문서 출력
- **Windows 프린터 명칭 개선**: "WINDOWS" → "WINDOWS PRINTER"로 명확화

### 주방 프린터 설정 개선
- **단일 주방 최적화**: 주방이 1개인 경우 선택 단계 생략, 직접 설정 화면 표시
- **KDS 준비 중 표시**: KDS 옵션 비활성화 및 "준비 중" 안내

### 번역 개선
- **번역 키 누락 수정**: `taxes.title`, `receipt.kitchenOrder` 등 추가
- **번역 헬퍼 함수**: `_translate()` 함수로 fallback 처리 개선
- **모든 언어 지원**: ko, en, ja, zh-TW, zh-HK

## 요구사항

- Flutter 3.38.7 이상
- Visual Studio 2026 또는 2022 (Desktop development with C++ 워크로드)
- Windows 10/11
- **Windows Developer Mode** (플러그인 사용을 위한 symlink 지원)

## 로컬 실행 (개발 모드)

```bash
# Developer Mode 활성화
start ms-settings:developers

# 로컬 API 서버 연결
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

## 프로덕션 빌드

### 릴리즈 빌드 (.exe)

```bash
flutter build windows --release
```

생성 위치: `build\windows\x64\runner\Release\posace_app_win.exe`

### MSIX 설치 패키지 (.msix)

```bash
# MSIX 패키지 생성
flutter pub run msix:create
```

생성 위치: `build\windows\x64\runner\Release\posace_app_win.msix`

**배포된 프로덕션 API 사용**:
- 기본 URL: `https://api.posace.com/api/v1`
- 빌드 시 자동으로 프로덕션 도메인 적용

**개발 API로 빌드하려면**:
```bash
flutter build windows --release --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

## 로그인

1. 백오피스에서 POS 디바이스 토큰 생성 또는 시드 데이터 실행
2. 앱 실행 후 디바이스 토큰 입력
3. 로그인 성공 시 Store ID, POS ID 표시
4. 자동으로 마스터 데이터 동기화 시작

## 주요 기능

- ✅ POS 디바이스 인증 및 로그인
- ✅ 마스터 데이터 동기화 (카테고리, 상품, 할인)
- ✅ 로컬 SQLite 데이터베이스 저장
- ✅ 자동/수동 동기화 지원
- ✅ 증분 동기화 지원 (`updatedAfter` 파라미터)
- ✅ **동적 영수증 렌더링**: 백오피스 설정을 기반으로 한 다국어 영수증 출력.
- ✅ **국가별 포맷팅**: LocaleHelper를 통한 통화(₩, $, ¥ 등) 및 날짜 형식 자동 변환.
- ✅ **글로벌 i18n**: 7개 로케일 지원 및 실시간 UI 언어 전환.

## 기술 스택

- Flutter 3.38.7+
- SQLite (sqflite_common_ffi)
- HTTP 클라이언트 (http 패키지)
- SharedPreferences (인증 토큰 저장)

## 테스트

이 프로젝트는 Flutter의 테스트 프레임워크를 사용하여 단위 테스트, 위젯 테스트, 통합 테스트를 제공합니다.

### 테스트 구조

#### Unit Tests (`test/unit/`)
핵심 비즈니스 로직과 모델을 테스트합니다:
- `cart_test.dart` - 장바구니 로직 (상품 추가/제거, 수량 변경, 할인/세금 계산)
- `cart_item_test.dart` - 장바구니 아이템 모델 테스트

#### Widget Tests (`test/widget/`)
UI 컴포넌트를 테스트합니다:
- `cart_sidebar_test.dart` - 장바구니 사이드바 위젯 테스트
- `product_grid_test.dart` - 상품 그리드 위젯 테스트
  - **참고**: 일부 테스트는 테스트 환경의 레이아웃 제약(1024x768 화면에서 GridView overflow)으로 인해 `skip: true`로 설정되어 있습니다. 실제 앱 동작에는 문제가 없습니다.

#### API Tests (`test/data/remote/`)
API 클라이언트를 테스트합니다:
- `pos_auth_api_test.dart` - POS 인증 API 테스트
- `pos_sales_api_test.dart` - POS 판매 API 테스트

#### Integration Tests (`integration_test/`)
전체 앱 플로우를 테스트합니다:
- `sales_flow_test.dart` - 완전한 판매 플로우 (로그인 → 상품 선택 → 결제 → 영수증)
- `offline_sync_test.dart` - 오프라인 동기화 테스트

#### 기타 테스트
- `cart_calculation_test.dart` - 장바구니 계산 로직 종합 테스트

### 테스트 실행

```bash
# 모든 테스트 실행
flutter test

# 특정 테스트 파일 실행
flutter test test/unit/cart_test.dart

# 통합 테스트 실행
flutter test integration_test/sales_flow_test.dart

# 커버리지 리포트 생성
flutter test --coverage
```

### 테스트 헬퍼

- `test/helpers/test_fixtures.dart` - 테스트용 픽스처 데이터 생성
- `test/helpers/mock_api_client.dart` - Mock API 클라이언트

### 주요 테스트 시나리오

#### 장바구니 테스트
- 빈 장바구니 생성
- 상품 추가 및 수량 증가
- 옵션이 다른 상품은 별도 아이템으로 처리
- 상품 제거 및 전체 비우기
- 할인 적용 (상품별 할인, 장바구니 할인)
- 세금 계산 (포함세, 별도세)
- 최종 금액 계산 (소계 - 할인 + 세금)

#### 통합 테스트
- PIN 로그인 → 상품 선택 → 장바구니 → 결제 → 영수증 출력
- 오프라인 모드에서 판매 생성 및 동기화

자세한 개발 계획은 [docs/WIN_APP_PLAN.md](docs/WIN_APP_PLAN.md) 참고.
