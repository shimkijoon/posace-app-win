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

자세한 개발 계획은 [docs/WIN_APP_PLAN.md](docs/WIN_APP_PLAN.md) 참고.
