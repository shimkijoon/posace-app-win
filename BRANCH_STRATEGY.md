# POSAce 브랜치 전략

## 📋 브랜치 구조

```
main (프로덕션)
  ↑
  └─ dev (개발/스테이징)
       ↑
       ├─ feature/기능명 (새 기능 개발)
       ├─ fix/버그명 (버그 수정)
       └─ hotfix/긴급수정 (긴급 수정 → main 직행)
```

---

## 🌿 브랜치별 역할

### `main` - 프로덕션 브랜치
- **배포 환경**:
  - API: `https://api.posace.com` (Railway)
  - Backoffice: `https://backoffice.posace.com` (Vercel)
  - POS App: GitHub Releases (자동 빌드 & 배포)
- **보호 설정**: PR 없이 직접 푸시 금지
- **머지 조건**: dev 브랜치에서 충분히 테스트된 코드만
- **배포 타이밍**: 주 1회 또는 중요 기능 완성 시

### `dev` - 개발/스테이징 브랜치
- **배포 환경**: (선택사항)
  - API: Railway Preview 환경
  - Backoffice: Vercel Preview 배포
- **역할**: 기능 개발 및 통합 테스트
- **머지 대상**: feature, fix 브랜치들
- **배포**: 자동 배포 (Preview 환경)

### `feature/*` - 기능 개발 브랜치
- **명명 규칙**: `feature/기능명`
- **예시**:
  - `feature/table-management`
  - `feature/kitchen-display`
  - `feature/customer-loyalty`
- **생성**: dev 브랜치에서 분기
- **머지**: dev 브랜치로 PR 생성

### `fix/*` - 버그 수정 브랜치
- **명명 규칙**: `fix/버그명`
- **예시**:
  - `fix/receipt-printer-error`
  - `fix/tax-calculation`
- **생성**: dev 브랜치에서 분기
- **머지**: dev 브랜치로 PR 생성

### `hotfix/*` - 긴급 수정 브랜치
- **명명 규칙**: `hotfix/긴급수정명`
- **용도**: 프로덕션 긴급 버그 수정
- **생성**: **main 브랜치에서 분기** (중요!)
- **머지**: main과 dev 양쪽에 모두 머지

---

## 🔄 워크플로우

### 1️⃣ 새 기능 개발

```bash
# dev 브랜치로 이동
git checkout dev
git pull origin dev

# 새 기능 브랜치 생성
git checkout -b feature/my-feature

# 개발 & 커밋
git add .
git commit -m "feat: add my feature"

# 푸시
git push -u origin feature/my-feature

# GitHub에서 dev 브랜치로 PR 생성
```

### 2️⃣ dev → main 배포

```bash
# dev 브랜치 최신화
git checkout dev
git pull origin dev

# main으로 PR 생성 (GitHub에서)
# 리뷰 후 머지

# main 브랜치 자동 배포:
# - Railway: api.posace.com
# - Vercel: backoffice.posace.com
# - GitHub Actions: POS App Release (태그 푸시 시)
```

### 3️⃣ 긴급 수정 (Hotfix)

```bash
# main에서 분기
git checkout main
git pull origin main
git checkout -b hotfix/critical-bug

# 수정 & 커밋
git add .
git commit -m "fix: critical bug"

# main으로 PR 생성 및 머지
# 그 후 dev에도 체리픽 또는 머지
git checkout dev
git merge hotfix/critical-bug
git push origin dev
```

---

## 🚀 배포 환경별 브랜치 매핑

| 환경 | 브랜치 | 자동 배포 | URL |
|------|--------|-----------|-----|
| **프로덕션** | `main` | ✅ | api.posace.com, backoffice.posace.com |
| **스테이징** | `dev` | ✅ (선택) | Preview URLs |
| **개발** | `feature/*` | ❌ | 로컬 |

---

## 📌 커밋 메시지 규칙

```
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 수정
style: 코드 포맷팅 (기능 변경 없음)
refactor: 코드 리팩토링
test: 테스트 추가/수정
chore: 빌드, 설정 변경
ci: CI/CD 설정 변경
```

**예시**:
```bash
git commit -m "feat: add customer loyalty points system"
git commit -m "fix: resolve tax calculation rounding issue"
git commit -m "docs: update API deployment guide"
```

---

## 🛡️ 브랜치 보호 설정 (권장)

### GitHub Settings > Branches > Add rule

**main 브랜치 보호**:
- ✅ Require pull request reviews before merging
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- ✅ Do not allow bypassing the above settings

**dev 브랜치 보호** (선택):
- ✅ Require pull request reviews before merging

---

## 🎯 현재 상태 (2026-01-29)

### ✅ 완료
- `main` 브랜치: 프로덕션 배포 완료
- `dev` 브랜치: 생성 완료 (모든 프로젝트)
- 자동 배포: Railway, Vercel 연동 완료

### 🔜 다음 단계
1. GitHub 브랜치 보호 규칙 설정
2. 새 기능 개발 시 `feature/*` 브랜치 사용
3. PR 리뷰 프로세스 정착
4. dev 환경 Preview 배포 설정 (선택)

---

## 📚 참고 자료
- [GitHub Flow](https://guides.github.com/introduction/flow/)
- [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/)
- [Conventional Commits](https://www.conventionalcommits.org/)
