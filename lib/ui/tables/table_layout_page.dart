import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/app_database.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/table_management_api.dart';
import '../sales/sales_page.dart';
import '../sales/widgets/title_bar.dart';
import '../common/navigation_title_bar.dart';
import '../common/navigation_tab.dart';
import 'widgets/table_management_dialog.dart';

class TableLayoutPage extends StatefulWidget {
  const TableLayoutPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<TableLayoutPage> createState() => _TableLayoutPageState();
}

class _TableLayoutPageState extends State<TableLayoutPage> {
  List<Map<String, dynamic>> _layouts = [];
  List<Map<String, dynamic>> _activeOrders = [];
  int _selectedLayoutIndex = 0;
  bool _isLoading = true;
  final _storage = AuthStorage();

  @override
  void initState() {
    super.initState();
    _loadLayouts();
  }

  Future<void> _loadLayouts() async {
    setState(() => _isLoading = true);
    
    try {
      // ✅ 1. 로컬 DB에서 테이블 레이아웃 로드
      final layouts = await widget.database.getTableLayouts();
      
      // ✅ 2. 로컬 DB에서 미전송 판매 조회 (테이블별)
      final unsyncedSales = await widget.database.getUnsyncedSales();
      final localActiveOrders = _convertUnsyncedSalesToActiveOrders(unsyncedSales);
      
      // ✅ 3. 서버에서 활성 주문 조회 (백그라운드, 실패해도 계속)
      List<Map<String, dynamic>> serverActiveOrders = [];
      String? serverError;
      
      try {
        final accessToken = await _storage.getAccessToken();
        if (accessToken != null) {
          final apiClient = ApiClient(accessToken: accessToken);
          final session = await _storage.getSessionInfo();
          final storeId = session['storeId'];
          
          if (storeId != null) {
            final response = await http.get(
              apiClient.buildUri('/tables/active-orders', {'storeId': storeId}),
              headers: apiClient.headers,
            );
            
            if (response.statusCode == 200) {
              final data = List<Map<String, dynamic>>.from(jsonDecode(response.body));
              serverActiveOrders = data;
            }
          }
        }
      } catch (e) {
        print('[TableLayout] ⚠️ Server active orders fetch failed, using local only: $e');
        serverError = e.toString();
      }
      
      // ✅ 4. 로컬과 서버 주문 병합 (로컬 우선)
      final mergedOrders = _mergeActiveOrders(localActiveOrders, serverActiveOrders);
      
      setState(() {
        _layouts = layouts;
        _activeOrders = mergedOrders;
        _isLoading = false;
      });
      
      // ✅ 5. 서버 오류 시 조용한 알림 (디버그용)
      if (serverError != null && mounted) {
        print('[TableLayout] 💡 Using local orders only. Server error: $serverError');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.translate('tables.dataLoadFailed') ?? '데이터 로드 실패'}: $e')),
        );
      }
    }
  }

  /// 미전송 판매를 활성 주문 형식으로 변환
  List<Map<String, dynamic>> _convertUnsyncedSalesToActiveOrders(List<dynamic> unsyncedSales) {
    final activeOrders = <Map<String, dynamic>>[];
    
    for (final sale in unsyncedSales) {
      // tableId가 있는 판매만 처리
      if (sale.tableId != null) {
        activeOrders.add({
          'id': sale.id,
          'tableId': sale.tableId,
          'totalAmount': sale.totalAmount,
          'status': sale.status,
          'createdAt': sale.createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
          'source': 'local',
          'isLocalOnly': true,
        });
      }
    }
    
    return activeOrders;
  }

  /// 로컬과 서버 활성 주문 병합 (로컬 우선)
  List<Map<String, dynamic>> _mergeActiveOrders(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> server,
  ) {
    final merged = <String, Map<String, dynamic>>{};
    
    // ✅ 로컬 우선 (로컬 DB가 최신 정보)
    for (final order in local) {
      final tableId = order['tableId'] as String?;
      if (tableId != null) {
        merged[tableId] = {
          ...order,
          'isLocalOnly': true,
        };
      }
    }
    
    // ✅ 서버 정보 추가 (로컬에 없는 테이블만)
    for (final order in server) {
      final tableId = order['tableId'] as String?;
      if (tableId != null && !merged.containsKey(tableId)) {
        merged[tableId] = {
          ...order,
          'source': 'server',
          'isLocalOnly': false,
        };
      }
    }
    
    return merged.values.toList();
  }

  void _showTableManagementDialog(Map<String, dynamic> table, Map<String, dynamic> activeOrder) {
    showDialog(
      context: context,
      builder: (context) => TableManagementDialog(
        table: table,
        activeOrder: activeOrder,
        allTables: _layouts[_selectedLayoutIndex]['tables'],
        database: widget.database,
        onActionComplete: () {
          _loadLayouts(); // Refresh state after action
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          NavigationTitleBar(
            currentTab: NavigationTab.tables,
            database: widget.database,
          ),
          _buildSubHeader(),
          Expanded(
            child: _layouts.isEmpty
                ? Center(child: Text(AppLocalizations.of(context)!.translate('tables.noLayouts') ?? '설정된 테이블 레이아웃이 없습니다.'))
                : _buildLayoutView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    if (_layouts.isEmpty) return const SizedBox.shrink();
    
    final currentLayout = _layouts[_selectedLayoutIndex];
    final List<dynamic> tables = currentLayout['tables'] ?? [];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // 레이아웃 선택 (인디고 스타일 탭)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _layouts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final name = entry.value['name'];
                  final isSelected = _selectedLayoutIndex == index;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: InkWell(
                      onTap: () => setState(() => _selectedLayoutIndex = index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : AppTheme.border,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          const SizedBox(width: 24),
          
          // 상태 요약
          _buildStatusSummary(tables.length),
        ],
      ),
    );
  }

  Widget _buildStatusSummary(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIndicator(Colors.grey, AppLocalizations.of(context)!.translate('tables.empty')),
          const SizedBox(width: 16),
          _buildStatusIndicator(AppTheme.warning, AppLocalizations.of(context)!.translate('tables.ordering')),
          const SizedBox(width: 16),
          Text(
            '${AppLocalizations.of(context)!.translate('tables.total')} $total${AppLocalizations.of(context)!.translate('tables.count')}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildLayoutView() {
    final currentLayout = _layouts[_selectedLayoutIndex];
    final List<dynamic> tables = currentLayout['tables'] ?? [];

    if (tables.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.translate('tables.noTables') ?? '설정된 테이블이 없습니다.'));
    }

    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: AppTheme.border.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 균형 잡힌 배열을 위한 계산 로직
            // 만약 서버에서 posX, posY가 모두 0이거나 특정 패턴이 없다면 자동 그리드(Auto-Grid) 보강
            
            // 기본 레이아웃 설정
            const int crossAxisCount = 5; // 한 줄에 5개
            final double spacing = 20.0;
            final double availableWidth = constraints.maxWidth - (spacing * (crossAxisCount + 1));
            final double itemWidth = availableWidth / crossAxisCount;
            final double itemHeight = itemWidth * 0.9; // 약간 직사각형

            return Stack(
              children: [
                // 배경 격자 페인터
                CustomPaint(
                  size: Size.infinite,
                  painter: GridPainter(),
                ),
                
                // 테이블 배치 루프
                ...List.generate(tables.length, (index) {
                  final table = tables[index];
                  
                  // 서버의 좌표가 유효한지 확인 (0,0 이외의 좌표가 있는지)
                  // 여기서는 사용자의 요청에 따라 '균형잡힌 배열'을 위해 
                  // 서버 좌표와 자동 그리드 좌표를 섞어서 처리할 수 있는 로직을 제안합니다.
                  
                  final double serverX = (table['x'] as num).toDouble();
                  final double serverY = (table['y'] as num).toDouble();
                  
                  // 만약 모든 위치가 (0,0) 근처라면 자동 그리드로 전환하는 논리적 판단
                  // (실제 프로덕션에서는 서버 좌표 우선이지만, 현재는 '개선' 요청이므로 자동 그리드 패턴 적용)
                  
                  final int row = index ~/ crossAxisCount;
                  final int col = index % crossAxisCount;
                  
                  // 서버 백분율 좌표를 기반으로 하되, 0% 위치인 것들은 그리드 형태로 보정
                  double finalX = (serverX == 0 && col > 0) ? (col * (100 / crossAxisCount)) : serverX;
                  double finalY = (serverY == 0 && row > 0) ? (row * (100 / (tables.length / crossAxisCount).ceil())) : serverY;

                  // 실제 렌더링 위치 계산
                  return Positioned(
                    left: (finalX * constraints.maxWidth / 100).clamp(spacing, constraints.maxWidth - itemWidth - spacing),
                    top: (finalY * constraints.maxHeight / 100).clamp(spacing, constraints.maxHeight - itemHeight - spacing),
                    width: itemWidth,
                    height: itemHeight,
                    child: _buildTableCard(table),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTableCard(Map<String, dynamic> table) {
    final activeOrder = _activeOrders.firstWhere(
      (o) => o['tableId'] == table['id'], 
      orElse: () => {},
    );
    bool hasOrder = activeOrder.isNotEmpty;
    bool isLocalOnly = activeOrder['isLocalOnly'] == true;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasOrder 
            ? (isLocalOnly ? Colors.orange : AppTheme.warning)
            : AppTheme.border,
          width: hasOrder ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hasOrder 
              ? (isLocalOnly ? Colors.orange.withOpacity(0.1) : AppTheme.warning.withOpacity(0.1))
              : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 전체 영역: 주문 화면으로 이동 (추가 주문 대응)
            Material(
              color: Colors.transparent,
              child: InkWell(
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
                child: const SizedBox.expand(),
              ),
            ),

            // 카드 상단 색상 바
            IgnorePointer(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: hasOrder 
                    ? (isLocalOnly ? Colors.orange : AppTheme.warning)
                    : Colors.grey.shade200,
                ),
              ),
            ),

            // ✅ 로컬 전용 주문 표시
            if (isLocalOnly)
              Positioned(
                top: 8,
                left: 8,
                child: IgnorePointer(
                  child: Tooltip(
                    message: '미전송 주문 (서버 동기화 필요)',
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_off,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

            // 중앙 정보 표시
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      table['name'] ?? 'T',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: hasOrder 
                          ? (isLocalOnly ? Colors.orange : AppTheme.warning)
                          : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasOrder 
                          ? (isLocalOnly 
                            ? Colors.orange.withOpacity(0.1)
                            : AppTheme.warning.withOpacity(0.1))
                          : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        hasOrder ? '${activeOrder['totalAmount'] ?? 0}${AppLocalizations.of(context)!.translate('session.won')}' : AppLocalizations.of(context)!.translate('tables.empty'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: hasOrder 
                            ? (isLocalOnly ? Colors.orange : AppTheme.warning)
                            : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 우측 상단: 관리 메뉴 버튼 (주문 중일 경우에만 노출하거나 상시 노출)
            if (hasOrder)
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: (isLocalOnly ? Colors.orange : AppTheme.warning).withOpacity(0.1),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _showTableManagementDialog(table, activeOrder),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.settings,
                        size: 18,
                        color: isLocalOnly ? Colors.orange : AppTheme.warning,
                      ),
                    ),
                  ),
                ),
              ),

            // 하단 구석 아이콘
            Positioned(
              bottom: 10,
              right: 12,
              child: IgnorePointer(
                child: Icon(
                  hasOrder ? Icons.restaurant : Icons.event_seat_outlined,
                  size: 16,
                  color: hasOrder 
                    ? (isLocalOnly 
                      ? Colors.orange.withOpacity(0.5)
                      : AppTheme.warning.withOpacity(0.5))
                    : Colors.grey.shade300,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 배경 격자 페인터
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border.withOpacity(0.2)
      ..strokeWidth = 1;

    const double step = 30;

    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
