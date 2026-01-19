# POSACE Windows App Context
> AI 프롬프트 입력 시 이 내용을 'Context'로 제공하면 효율적입니다.

## 1. Project Identity
- **Name**: POSACE Windows Client
- **Type**: Desktop POS Application (Retail First)
- **Target OS**: Windows (via Flutter)

## 2. Tech Stack
- **Framework**: Flutter (Dart >= 3.9.2)
- **Key Packages**:
  - `sqflite_common_ffi` (Local DB: SQLite)
  - `http` (API Communication)
  - `shared_preferences` (Simple Token Storage)
  - `provider` (State Management - Expected / Verify if used)

### Current Status
- [x] Sales Sync Fix (getSaleItems whereArgs fix)
- [x] Discount Logic Redesign (Aggregate all discounts into one row, use Gross Subtotal)
- [x] Cart UI Refinement (Fixed footer for cart discounts, Red font for all discounts, Auto-scroll, Persistent scrollbar)

## 3. Key Architecture & Rules
- **Offline First**: Always save to SQLite first, then sync to Server.
- **Sync Strategy**:
  - GET `/master` (`updatedAfter`) -> Update Local DB.
  - Sales -> Save Local Queue -> Upload Background.
- **Directories**:
  - `core/`: Business Logic & Models
  - `data/`: Repositories & API/DB Clients
  - `ui/`: Widgets & Screens

## 5. Communication & Risk Management
- **Risk Assessment**: 작업 범위가 너무 크거나 시스템에 큰 영향을 줄 수 있는 경우, 즉시 실행하지 말고 사용자에게 의도를 확인하고 요건을 구체화하는 과정을 거친다.
- **Clarification**: 불확실한 부분은 추측하지 말고 질문한다.

## 6. Environment & Git Rules
- **Git Commit**: 한글 인코딩 문제를 방지하기 위해 UTF-8 설정을 사용하며, 메시지는 명확하게 작성한다.
- **Terminal**: Windows PowerShell 환경에서 UTF-8(`65001`)을 기본으로 사용한다.

## 4. Current Status (Example)
- Barcode/Cart implemented.
- Receipt printing pending.
