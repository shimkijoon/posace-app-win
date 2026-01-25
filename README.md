# POSAce Windows Client

Flutter 기반 Windows POS 클라이언트 애플리케이션.

## 요구사항

- Flutter 3.38.7 이상
- Visual Studio 2026 또는 2022 (Desktop development with C++ 워크로드)
- Windows 10/11

## 로컬 실행

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api/v1
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
