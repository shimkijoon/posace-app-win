# 상태 손실 위험 요소 전체 검토

**날짜**: 2026-01-31  
**브랜치**: dev  
**목적**: 동기화 및 화면 전환 시 데이터 손실 위험 요소 파악 및 개선

## 📋 검토 대상

1. ✅ **결제 중 동기화** - `sales_page.dart` → **개선 완료**
2. ⚠️ **테이블 주문 관리** - `table_layout_page.dart`
3. ⚠️ **보류 거래 복원** - `suspended_sales_dialog.dart`
4. ⚠️ **회원 검색 및 등록** - `member_search_dialog.dart`
5. ✅ **홈 화면 자동 동기화** - `home_page.dart`

---

## 1. ✅ 결제 중 동기화 (개선 완료)

### 위치
`lib/ui/sales/sales_page.dart` - `_performAutoSync()`

### 개선 사항
- ✅ 장바구니 상태 보존
- ✅ 할인 정보 보존
- ✅ 멤버 정보 보존
- ✅ 사용자 확인 다이얼로그
- ✅ 중복 결제 방지

### 상세 내용
`PAYMENT_SYNC_SAFETY_2026-01-31.md` 참조

---

## 2. ⚠️ 테이블 주문 관리

### 위치
`lib/ui/tables/table_layout_page.dart`

### 현재 구조

```dart
class _TableLayoutPageState extends State<TableLayoutPage> {
  List<Map<String, dynamic>> _layouts = [];
  List<Map<String, dynamic>> _activeOrders = [];
  int _selectedLayoutIndex = 0;
  
  Future<void> _loadLayouts() async {
    // 1. 테이블 레이아웃 로드
    final layouts = await widget.database.getTableLayouts();
    
    // 2. 활성 주문 정보 로드 (서버)
    final response = await http.get(...);
    _activeOrders = data;
    
    setState(() {
      _layouts = layouts;
    });
  }
  
  // 테이블 카드 클릭 → SalesPage로 이동
  InkWell(
    onTap: () async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SalesPage(
            database: widget.database, 
            tableId: table['id'],
            tableName: table['name'],
          ),
        ),
      );
      _loadLayouts(); // 주문 후 돌아오면 상태 갱신
    },
  )
}
```

### 🚨 잠재적 위험 요소

#### 위험 1: 서버 통신 실패 시 로컬 주문 정보 손실
```dart
// 현재 구조
final response = await http.get(.../active-orders);
if (response.statusCode == 200) {
  _activeOrders = data;
}

// ❌ 문제점:
// - 서버 통신 실패 시 _activeOrders = []
// - 로컬 DB의 미전송 판매 정보 무시
// - 사용자에게 "빈 테이블"로 보임 (실제로는 주문 있음)
```

#### 위험 2: 네트워크 지연 시 화면 동기화 문제
```dart
await Navigator.push(...);
_loadLayouts(); // 네트워크 지연 동안 오래된 정보 표시

// ❌ 시나리오:
// 1. 사용자가 테이블 1번에서 주문
// 2. 뒤로가기
// 3. _loadLayouts() 실행 중 (네트워크 지연)
// 4. 사용자가 다시 테이블 1번 클릭
// 5. 새 주문 시작 (기존 주문 무시)
```

#### 위험 3: 동시 접속 시 주문 충돌
```dart
// POS 1: 테이블 1번 주문 중
// POS 2: 테이블 1번을 "비어있음"으로 인식하고 새 주문 시작
// → 주문 충돌, 데이터 불일치
```

### ✅ 개선 방안

#### 방안 1: 로컬 DB 우선 조회 (Offline-First)

```dart
Future<void> _loadLayouts() async {
  setState(() => _isLoading = true);
  
  try {
    // ✅ 1. 로컬 DB에서 레이아웃 로드
    final layouts = await widget.database.getTableLayouts();
    
    // ✅ 2. 로컬 DB에서 미전송 판매 조회
    final unsyncedSales = await widget.database.getUnsyncedSalesByTable();
    final localActiveOrders = _convertToActiveOrders(unsyncedSales);
    
    // ✅ 3. 서버에서 활성 주문 조회 (백그라운드, 실패해도 계속)
    List<Map<String, dynamic>> serverActiveOrders = [];
    try {
      final accessToken = await _storage.getAccessToken();
      if (accessToken != null) {
        final apiClient = ApiClient(accessToken: accessToken);
        final response = await http.get(...);
        if (response.statusCode == 200) {
          serverActiveOrders = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        }
      }
    } catch (e) {
      print('⚠️ Server active orders fetch failed, using local only: $e');
    }
    
    // ✅ 4. 로컬과 서버 주문 병합 (로컬 우선)
    final mergedOrders = _mergeActiveOrders(localActiveOrders, serverActiveOrders);
    
    setState(() {
      _layouts = layouts;
      _activeOrders = mergedOrders;
      _isLoading = false;
    });
  } catch (e) {
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ 데이터 로드 실패: $e')),
      );
    }
  }
}

List<Map<String, dynamic>> _mergeActiveOrders(
  List<Map<String, dynamic>> local,
  List<Map<String, dynamic>> server,
) {
  final merged = <String, Map<String, dynamic>>{};
  
  // ✅ 로컬 우선 (로컬 DB가 최신 정보)
  for (final order in local) {
    merged[order['tableId']] = order;
  }
  
  // ✅ 서버 정보 추가 (로컬에 없는 것만)
  for (final order in server) {
    if (!merged.containsKey(order['tableId'])) {
      merged[order['tableId']] = order;
    }
  }
  
  return merged.values.toList();
}
```

#### 방안 2: 테이블 잠금 (Lock) 메커니즘

```dart
// SalesPage 진입 시 테이블 잠금
Future<void> _lockTable(String tableId) async {
  await widget.database.lockTable(
    tableId: tableId,
    posId: session['posId'],
    lockedAt: DateTime.now(),
  );
}

// SalesPage 이탈 시 테이블 잠금 해제
Future<void> _unlockTable(String tableId) async {
  await widget.database.unlockTable(tableId);
}

// 테이블 카드 클릭 시 잠금 확인
InkWell(
  onTap: () async {
    // ✅ 잠금 확인
    final lock = await widget.database.getTableLock(table['id']);
    if (lock != null && lock['posId'] != session['posId']) {
      // 다른 POS에서 사용 중
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ 테이블 사용 중'),
          content: Text('이 테이블은 다른 POS(${lock['posId']})에서 사용 중입니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }
    
    // ✅ 잠금 후 진입
    await _lockTable(table['id']);
    
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SalesPage(
          database: widget.database, 
          tableId: table['id'],
          tableName: table['name'],
        ),
      ),
    );
    
    // ✅ 잠금 해제
    await _unlockTable(table['id']);
    
    _loadLayouts(); // 상태 갱신
  },
)
```

#### 방안 3: 실시간 상태 표시

```dart
Widget _buildTableCard(Map<String, dynamic> table) {
  final activeOrder = _activeOrders.firstWhere(...);
  final hasOrder = activeOrder.isNotEmpty;
  final isLocalOnly = activeOrder['source'] == 'local'; // 로컬 DB만 있는 주문
  
  return Container(
    decoration: BoxDecoration(
      border: Border.all(
        color: hasOrder 
          ? (isLocalOnly ? Colors.orange : AppTheme.warning) 
          : AppTheme.border,
        width: hasOrder ? 2 : 1,
      ),
    ),
    child: Stack(
      children: [
        // ✅ 로컬 전용 주문 표시
        if (isLocalOnly)
          Positioned(
            top: 8,
            left: 8,
            child: Tooltip(
              message: '미전송 주문 (서버 동기화 필요)',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off, size: 12, color: Colors.white),
              ),
            ),
          ),
        // ... 기존 코드
      ],
    ),
  );
}
```

### 🎯 권장 개선 순서

1. **방안 1** (Offline-First) → 즉시 적용 가능, 안정성 확보
2. **방안 3** (실시간 상태) → 사용자 경험 개선
3. **방안 2** (테이블 잠금) → 다중 POS 환경에서 필요 시

---

## 3. ⚠️ 보류 거래 복원

### 위치
`lib/ui/sales/widgets/suspended_sales_dialog.dart`

### 현재 구조

```dart
class _SuspendedSalesDialogState extends State<SuspendedSalesDialog> {
  List<dynamic> _suspendedSales = [];
  
  Future<void> _loadSuspendedSales() async {
    // 서버에서 보류 거래 조회
    final api = PosSuspendedApi(accessToken: token);
    final sales = await api.getSuspendedSales(storeId);
    
    setState(() {
      _suspendedSales = sales;
    });
  }
  
  // 복원 버튼 클릭
  ListTile(
    onTap: () => Navigator.pop(context, sale['id']),
  )
}
```

### 🚨 잠재적 위험 요소

#### 위험 1: 보류 거래 복원 시 현재 장바구니 손실
```dart
// sales_page.dart에서 호출
final suspendedId = await showDialog<String>(
  context: context,
  builder: (context) => SuspendedSalesDialog(database: widget.database),
);

if (suspendedId != null) {
  // ❌ 문제점: 현재 장바구니를 확인하지 않고 바로 복원
  await _restoreSuspendedSale(suspendedId);
}

// ❌ 시나리오:
// 1. 사용자가 장바구니에 상품 5개 담음
// 2. "보류 거래 복원" 클릭
// 3. 이전 거래 선택
// 4. 현재 장바구니 5개 → 사라짐 💥
```

#### 위험 2: 네트워크 오류 시 보류 거래 목록 로드 실패
```dart
try {
  final sales = await api.getSuspendedSales(storeId);
} catch (e) {
  // 오류 표시만 하고 로컬 DB는 확인하지 않음
  ScaffoldMessenger.showSnackBar(...);
}

// ❌ 문제점:
// - 로컬 DB에 보류 거래가 있어도 표시하지 않음
// - 오프라인 모드에서 보류 거래 복원 불가
```

### ✅ 개선 방안

#### 방안 1: 현재 장바구니 확인 및 저장

```dart
// sales_page.dart
Future<void> _handleSuspendedSalesRestore() async {
  // ✅ 1. 현재 장바구니 확인
  if (_cart.items.isNotEmpty) {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('보류 거래 복원'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('현재 장바구니에 상품이 있습니다.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📦 현재 장바구니',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('• 상품: ${_cart.items.length}개'),
                  Text('• 금액: ₩${_cart.total.toStringAsFixed(0)}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('어떻게 하시겠습니까?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('현재 장바구니 보류 후 복원'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('현재 장바구니 삭제 후 복원'),
          ),
        ],
      ),
    );
    
    if (confirm == null) return; // 취소
    
    // ✅ 2. 현재 장바구니 보류
    if (confirm == 'save') {
      await _suspendCurrentSale();
    }
  }
  
  // ✅ 3. 보류 거래 복원
  final suspendedId = await showDialog<String>(
    context: context,
    builder: (context) => SuspendedSalesDialog(database: widget.database),
  );
  
  if (suspendedId != null) {
    await _restoreSuspendedSale(suspendedId);
  }
}
```

#### 방안 2: 로컬 DB 우선 조회

```dart
// suspended_sales_dialog.dart
Future<void> _loadSuspendedSales() async {
  setState(() => _isLoading = true);
  
  try {
    final auth = AuthStorage();
    final session = await auth.getSessionInfo();
    final token = await auth.getAccessToken();
    final storeId = session['storeId'];
    
    // ✅ 1. 로컬 DB에서 보류 거래 조회
    final localSales = await widget.database.getSuspendedSales(storeId);
    
    // ✅ 2. 서버에서 보류 거래 조회 (실패해도 계속)
    List<dynamic> serverSales = [];
    try {
      if (storeId != null && token != null) {
        final api = PosSuspendedApi(accessToken: token);
        serverSales = await api.getSuspendedSales(storeId);
      }
    } catch (e) {
      print('⚠️ Server suspended sales fetch failed, using local only: $e');
    }
    
    // ✅ 3. 병합 (중복 제거)
    final mergedSales = _mergeSuspendedSales(localSales, serverSales);
    
    if (mounted) {
      setState(() {
        _suspendedSales = mergedSales;
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ 보류 거래 로드 실패: $e')),
      );
    }
  }
}

List<dynamic> _mergeSuspendedSales(
  List<dynamic> local,
  List<dynamic> server,
) {
  final merged = <String, dynamic>{};
  
  // 로컬 우선
  for (final sale in local) {
    merged[sale['id']] = {...sale, 'source': 'local'};
  }
  
  // 서버 정보 추가
  for (final sale in server) {
    if (!merged.containsKey(sale['id'])) {
      merged[sale['id']] = {...sale, 'source': 'server'};
    }
  }
  
  return merged.values.toList()
    ..sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
}
```

---

## 4. ⚠️ 회원 검색 및 등록

### 위치
`lib/ui/sales/widgets/member_search_dialog.dart`

### 현재 구조

```dart
class _MemberSearchDialogState extends State<MemberSearchDialog> {
  List<MemberModel> _results = [];
  
  Future<void> _search() async {
    // 1. 로컬 검색
    final results = await widget.database.searchMembersByPhone(query);
    
    // 2. 온라인 검색 (로컬 결과 없을 때만)
    if (results.isEmpty) {
      try {
        final member = await customerApi.searchOnlineMember(storeId, query);
        await widget.database.upsertMember(member);
        results.add(member);
      } catch (e) {
        print('Online search failed: $e');
      }
    }
    
    setState(() {
      _results = results;
    });
  }
  
  Future<void> _openRegistration() async {
    final result = await showDialog<MemberModel>(
      context: context,
      builder: (context) => MemberRegistrationDialog(database: widget.database),
    );
    
    if (result != null && mounted) {
      Navigator.pop(context, result); // ✅ 바로 선택
    }
  }
}
```

### 🚨 잠재적 위험 요소

#### 위험 1: 회원 등록 다이얼로그 여러 개 중첩
```dart
// ❌ 시나리오:
// 1. 회원 검색 다이얼로그 열림 (depth 1)
// 2. "신규 회원 등록" 클릭
// 3. 회원 등록 다이얼로그 열림 (depth 2)
// 4. 등록 완료 → result 반환
// 5. Navigator.pop(context, result) → 회원 검색 다이얼로그 닫힘
// 6. SalesPage로 회원 정보 전달됨 ✅

// ✅ 현재 코드는 안전함!
```

#### 위험 2: 온라인 검색 실패 시 사용자 혼란
```dart
if (results.isEmpty) {
  try {
    final member = await customerApi.searchOnlineMember(...);
  } catch (e) {
    print('Online search failed: $e'); // 콘솔에만 출력
    // ❌ 사용자에게 피드백 없음
  }
}

// ❌ 문제점:
// - 로컬에 없고, 서버 검색도 실패했는지
// - 실제로 회원이 없는지 구분 불가
```

### ✅ 개선 방안

#### 방안 1: 검색 실패 시 명확한 피드백

```dart
Future<void> _search() async {
  final query = _searchController.text.trim();
  if (query.isEmpty) return;

  setState(() => _isLoading = true);
  
  // ✅ 1. 로컬 검색
  final results = await widget.database.searchMembersByPhone(query);
  
  // ✅ 2. 온라인 검색
  String? onlineSearchError;
  if (results.isEmpty) {
    try {
      final authStorage = AuthStorage();
      final session = await authStorage.getSessionInfo();
      final accessToken = await authStorage.getAccessToken();
      final storeId = session['storeId'];
      
      if (storeId != null && accessToken != null) {
        final apiClient = ApiClient(accessToken: accessToken);
        final customerApi = PosCustomerApi(apiClient);
        final member = await customerApi.searchOnlineMember(storeId, query);
        
        await widget.database.upsertMember(member);
        results.add(member);
      }
    } catch (e) {
      print('Online search failed: $e');
      onlineSearchError = e.toString();
    }
  }

  setState(() {
    _results = results;
    _isLoading = false;
  });
  
  // ✅ 3. 결과 없을 때 명확한 메시지
  if (mounted && results.isEmpty) {
    String message;
    if (onlineSearchError != null) {
      message = '⚠️ 로컬 및 서버 검색 모두 실패\n'
                '로컬: 결과 없음\n'
                '서버: $onlineSearchError\n\n'
                '신규 회원으로 등록하시겠습니까?';
    } else {
      message = '검색 결과가 없습니다.\n'
                '신규 회원으로 등록하시겠습니까?';
    }
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('검색 결과 없음'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('신규 등록'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _openRegistration();
    }
  }
}
```

#### 방안 2: 회원 정보 실시간 동기화

```dart
// 회원 선택 시 최신 정보 확인
ListTile(
  onTap: () async {
    // ✅ 서버에서 최신 회원 정보 확인 (백그라운드)
    MemberModel finalMember = member;
    try {
      final authStorage = AuthStorage();
      final session = await authStorage.getSessionInfo();
      final accessToken = await authStorage.getAccessToken();
      final storeId = session['storeId'];
      
      if (storeId != null && accessToken != null) {
        final apiClient = ApiClient(accessToken: accessToken);
        final customerApi = PosCustomerApi(apiClient);
        final updatedMember = await customerApi.getMember(storeId, member.id);
        
        await widget.database.upsertMember(updatedMember);
        finalMember = updatedMember;
      }
    } catch (e) {
      print('⚠️ Failed to fetch latest member info, using cached: $e');
    }
    
    if (mounted) {
      Navigator.pop(context, finalMember);
    }
  },
)
```

---

## 5. ✅ 홈 화면 자동 동기화

### 위치
`lib/ui/home/home_page.dart` - `_performInitialSync()`

### 현재 구조

```dart
Future<void> _performInitialSync() async {
  try {
    print('[HomePage] 🔄 Starting initial master data sync...');
    
    final result = await syncService.syncMaster(
      storeId: storeId,
      manual: true, // 전체 동기화
    );
    
    if (result.success) {
      print('[HomePage] ✅ Initial sync completed successfully');
      _loadDataCounts(); // 동기화 후 개수 업데이트
    }
  } catch (e) {
    print('[HomePage] ❌ Initial sync error: $e');
    // 동기화 실패해도 앱은 계속 사용 가능
  }
}
```

### ✅ 현재 상태

- ✅ 백그라운드 동기화 (UI 블록 없음)
- ✅ 실패해도 앱 사용 가능
- ✅ 로그로 상태 확인 가능

### 🎯 추가 개선 가능 사항

```dart
Future<void> _performInitialSync() async {
  try {
    // ✅ 동기화 시작 알림 (선택사항)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('마스터 데이터 동기화 중...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    final result = await syncService.syncMaster(
      storeId: storeId,
      manual: true,
    );
    
    if (result.success && mounted) {
      // ✅ 동기화 완료 알림
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                '동기화 완료: ${result.categoriesCount}개 카테고리, ${result.productsCount}개 상품',
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadDataCounts();
    } else if (!result.success && mounted) {
      // ⚠️ 동기화 실패 알림 (조용하게)
      print('[HomePage] ⚠️ Sync failed: ${result.error}');
      // 사용자에게는 알리지 않음 (백그라운드 작업이므로)
    }
  } catch (e) {
    print('[HomePage] ❌ Initial sync error: $e');
  }
}
```

---

## 📊 전체 우선순위

### 🔴 High Priority (즉시 개선 필요)

1. **보류 거래 복원 시 장바구니 확인** - 데이터 손실 위험 높음
2. **테이블 주문 로컬 DB 우선 조회** - 오프라인 모드 대응

### 🟡 Medium Priority (개선 권장)

3. **회원 검색 실패 시 명확한 피드백**
4. **테이블 주문 실시간 상태 표시**

### 🟢 Low Priority (선택사항)

5. **홈 화면 동기화 알림**
6. **테이블 잠금 메커니즘** (다중 POS 환경에서만 필요)

---

## ✅ 다음 단계

### 즉시 적용 가능
- ✅ 보류 거래 복원 개선 (방안 1)
- ✅ 테이블 주문 Offline-First (방안 1)
- ✅ 회원 검색 피드백 개선

### 중기 개선
- 테이블 주문 실시간 상태
- 회원 정보 실시간 동기화

### 장기 개선
- 테이블 잠금 메커니즘
- 다중 POS 동시 접속 처리

---

**작성자**: AI Assistant  
**검증자**: User (shimkijoon)  
**리뷰어**: User (shimkijoon) - "이런 맥락으로 다른 기능도 검토" 요청
