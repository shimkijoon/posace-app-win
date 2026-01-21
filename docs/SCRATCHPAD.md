# Scratchpad & Daily Log

이 문서는 개발 과정에서의 임시 메모, 에러 로그, 하루의 생각 흐름을 기록하는 공간입니다.
* 중요한 결론이나 결정사항은 반드시 `WIN_APP_PLAN.md`로 옮기고 여기서는 지우거나 아카이빙합니다.
* 날짜별로 최신 내용이 위로 오도록, 또는 아래로 쌓이도록 일관성 있게 작성합니다.

## Next Step (다음에 바로 할 일)
- [ ] Z-Report (마감) 기능 구현
- [ ] 멤버십/회원 포인트 기능 연동
- [ ] 영수증 출력 (Thermal Printer) 라이브러리 조사 및 연동

### 🔑 현재 테스트 정보 (2026-01-19)
- **POS Device Token**: `f0438cd9fce380c0c447d8a8475ca3fe5fb7964e54cbac01`
- **Owner Login**: `owner@posace.dev` / `Password123!`

---
## 2026-01-21 (Today)
### ✅ Achievements
- **Authentication**: Replaced device token login with Email/Password login for owners.
- **Database**: Bumbed to v5, added `type` column to products, fixed `taxAmount` storage.
- **Bug Fixes**:
  - Cart discount deduplication (fixing double discount application).
  - Product option parsing fix (boolean/int type mismatch).
  - Cart layout overflow fix (flex adjustment for large amounts > 10,000 KRW).
- **Features**: Added "Data Reset" (데이터 초기화) button to Home for troubleshooting.

### 💡 Note
- Model parsing from API needs to handle both `bool` and `int` for SQLite compatibility.
- Cart layout uses flex ratios: Product(5), Barcode(2), Price(2), Qty(2), Discount(2), Final(3).

---
## 2026-01-19

### 💡 Git 한글 깨짐 해결 설정
윈도우 환경에서 한글 커밋 메시지가 깨지는 경우 다음 명령어를 실행합니다 (이미 설정 완료):
```powershell
git config --global core.quotepath false
git config --global i18n.commitEncoding utf-8
git config --global i18n.logOutputEncoding utf-8
$env:LESSCHARSET='utf-8' # (선택사항) log 조회 시
```
또한 터미널 인코딩을 UTF-8로 유지해야 합니다. (`chcp 65001`)
