import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/app_database.dart';
import '../sales/sales_page.dart';

class TableLayoutPage extends StatefulWidget {
  const TableLayoutPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<TableLayoutPage> createState() => _TableLayoutPageState();
}

class _TableLayoutPageState extends State<TableLayoutPage> {
  List<Map<String, dynamic>> _layouts = [];
  int _selectedLayoutIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLayouts();
  }

  Future<void> _loadLayouts() async {
    setState(() => _isLoading = true);
    try {
      final layouts = await widget.database.getTableLayouts();
      setState(() {
        _layouts = layouts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('레이아웃 로드 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_layouts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('테이블 관리')),
        body: const Center(child: Text('설정된 테이블 레이아웃이 없습니다.')),
      );
    }

    final currentLayout = _layouts[_selectedLayoutIndex];
    final List<dynamic> tables = currentLayout['tables'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('테이블 관리'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_layouts.length, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(_layouts[index]['name']),
                    selected: _selectedLayoutIndex == index,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedLayoutIndex = index);
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: tables.map((table) {
              return Positioned(
                left: table['x'] * constraints.maxWidth / 100,
                top: table['y'] * constraints.maxHeight / 100,
                child: _buildTableCard(table),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildTableCard(Map<String, dynamic> table) {
    // For demo, we assume table state is handled elsewhere or fetched
    bool hasOrder = false; // Placeholder
    
    return InkWell(
      onTap: () {
        // Navigate to sales page for this table
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SalesPage(database: widget.database), // Should be TableSalesPage in real impl
          ),
        );
      },
      child: Container(
        width: 100, // Fixed size for demo, should use table['width']
        height: 100,
        decoration: BoxDecoration(
          color: hasOrder ? Colors.orange.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasOrder ? Colors.orange : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              table['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (hasOrder) ...[
              const SizedBox(height: 4),
              const Text('사용 중', style: TextStyle(fontSize: 12, color: Colors.orange)),
            ] else 
              const Text('빈 테이블', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
