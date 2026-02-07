import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/i18n/app_localizations.dart';
import '../../data/local/app_database.dart';
import '../../data/local/models.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../core/theme/app_theme.dart';
import '../sales/widgets/title_bar.dart';
import '../common/navigation_title_bar.dart';
import '../common/navigation_tab.dart';
import 'widgets/receipt_detail_dialog.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/i18n/locale_helper.dart';

class SalesInquiryPage extends StatefulWidget {
  const SalesInquiryPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SalesInquiryPage> createState() => _SalesInquiryPageState();
}

class _SalesInquiryPageState extends State<SalesInquiryPage> {
  List<SaleModel> _sales = [];
  Map<String, String> _saleItemSummaries = {};
  bool _isLoading = true;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  String _countryCode = 'KR';
  String _intlLocale = 'ko_KR';

  @override
  void initState() {
    super.initState();
    _loadLocaleSettings();
    _loadSales();
  }

  Future<void> _loadLocaleSettings() async {
    try {
      final session = await AuthStorage().getSessionInfo();
      final sessionCountry = (session['country'] as String?)?.trim();
      final uiLanguage = (session['uiLanguage'] as String?) ?? '';
      final derivedCountry = () {
        if (uiLanguage.startsWith('ja')) return 'JP';
        if (uiLanguage == 'zh-TW') return 'TW';
        if (uiLanguage == 'zh-HK') return 'HK';
        if (uiLanguage == 'en-SG') return 'SG';
        if (uiLanguage == 'en-AU') return 'AU';
        return 'KR';
      }();
      final country = (sessionCountry != null && sessionCountry.isNotEmpty)
          ? sessionCountry
          : derivedCountry;

      // Intl locale for date formatting (best effort)
      String intlLocale = 'ko_KR';
      if (uiLanguage.startsWith('ja') || country == 'JP') intlLocale = 'ja_JP';
      else if (uiLanguage == 'zh-TW' || country == 'TW') intlLocale = 'zh_TW';
      else if (uiLanguage == 'zh-HK' || country == 'HK') intlLocale = 'zh_HK';
      else if (uiLanguage.startsWith('en')) intlLocale = 'en_US';

      await initializeDateFormatting(intlLocale, null);
      if (mounted) {
        setState(() {
          _countryCode = country;
          _intlLocale = intlLocale;
        });
      }
    } catch (_) {
      // ignore: fallback to KR defaults
      await initializeDateFormatting('ko_KR', null);
    }
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      final db = await widget.database.database;
      final maps = await db.query(
        'sales',
        where: 'createdAt BETWEEN ? AND ?',
        whereArgs: [
          _fromDate.toIso8601String().split('T')[0] + 'T00:00:00',
          _toDate.toIso8601String().split('T')[0] + 'T23:59:59',
        ],
        orderBy: 'createdAt DESC',
      );
      
      final salesData = maps.map((m) => SaleModel.fromMap(m)).toList();
      Map<String, String> summaries = {};

      for (var sale in salesData) {
        final items = await widget.database.getSaleItems(sale.id);
        if (items.isNotEmpty) {
          // Get first product name
          final productMaps = await db.query('products', where: 'id = ?', whereArgs: [items.first.productId]);
          final firstName = productMaps.isNotEmpty ? productMaps.first['name'] as String : 'Unknown';
          
          if (items.length > 1) {
            summaries[sale.id] = '$firstName 외 ${items.length - 1}건';
          } else {
            summaries[sale.id] = firstName;
          }
        } else {
          summaries[sale.id] = AppLocalizations.of(context)!.translate('salesInquiry.noProducts') ?? '상품 없음';
        }
      }

      if (mounted) {
        setState(() {
          _sales = salesData;
          _saleItemSummaries = summaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.translate('salesInquiry.dataLoadFailed') ?? '데이터 로드 실패'}: $e')),
        );
      }
    }
  }

  void _showReceiptDetail(SaleModel sale) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ReceiptDetailDialog(
        sale: sale,
        database: widget.database,
      ),
    );

    if (result == true) {
      _loadSales();
    }
  }

  Widget _buildSummaryDashboard(NumberFormat currencyFormat) {
    int totalAmount = 0;
    int completedCount = 0;
    int cancelledCount = 0;

    for (var sale in _sales) {
      if (sale.status == 'COMPLETED') {
        totalAmount += sale.totalAmount;
        completedCount++;
      } else if (sale.status == 'CANCELLED') {
        cancelledCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(AppLocalizations.of(context)!.translate('salesInquiry.totalSales'), currencyFormat.format(totalAmount), AppTheme.primary),
          _buildSummaryItem(AppLocalizations.of(context)!.translate('salesInquiry.paymentCount'), '$completedCount${AppLocalizations.of(context)!.translate('tables.count')}', AppTheme.success),
          _buildSummaryItem(AppLocalizations.of(context)!.translate('salesInquiry.cancelCount'), '$cancelledCount${AppLocalizations.of(context)!.translate('tables.count')}', AppTheme.error),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  String _localizePaymentMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CARD': return AppLocalizations.of(context)!.translate('salesInquiry.card');
      case 'CASH': return AppLocalizations.of(context)!.translate('salesInquiry.cash');
      default: return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd (E) HH:mm', _intlLocale);
    final currencyFormat = LocaleHelper.getCurrencyFormat(_countryCode);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          NavigationTitleBar(
            currentTab: NavigationTab.history,
            database: widget.database,
          ),
          
          // Filters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: AppTheme.primary,
                              onPrimary: Colors.white,
                              onSurface: AppTheme.textPrimary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _fromDate = picked.start;
                        _toDate = picked.end;
                      });
                      _loadSales();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    side: BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(Icons.calendar_today, size: 18, color: AppTheme.primary),
                  label: Text(
                    '${DateFormat('yyyy-MM-dd').format(_fromDate)} ~ ${DateFormat('yyyy-MM-dd').format(_toDate)}',
                    style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadSales,
                  icon: Icon(Icons.refresh, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          if (!_isLoading) _buildSummaryDashboard(currencyFormat),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sales.isEmpty
                    ? Center(
                        child: Text(AppLocalizations.of(context)!.translate('salesInquiry.noResults') ?? '조회된 매출 내역이 없습니다.', 
                          style: TextStyle(color: AppTheme.textSecondary)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _sales.length,
                        itemBuilder: (context, index) {
                          final sale = _sales[index];
                          final isCancelled = sale.status == 'CANCELLED';
                          final summary = _saleItemSummaries[sale.id] ?? '';
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCancelled ? AppTheme.error.withOpacity(0.3) : AppTheme.border,
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              onTap: () => _showReceiptDetail(sale),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isCancelled ? AppTheme.error : AppTheme.success).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCancelled ? Icons.close : Icons.check,
                                  color: isCancelled ? AppTheme.error : AppTheme.success,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      summary,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    currencyFormat.format(sale.totalAmount),
                                    style: TextStyle(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.bold,
                                      color: isCancelled ? AppTheme.error : AppTheme.primary,
                                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  if (isCancelled) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(AppLocalizations.of(context)!.translate('salesInquiry.cancelledBadge') ?? '취소됨', 
                                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${dateFormat.format(sale.createdAt)}  |  ${_localizePaymentMethod(sale.paymentMethod ?? 'CASH')}',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ),
                              trailing: Icon(Icons.chevron_right, color: AppTheme.border),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
