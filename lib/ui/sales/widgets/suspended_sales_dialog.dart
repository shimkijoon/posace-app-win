import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../data/local/app_database.dart';
import '../../../../core/storage/auth_storage.dart';
import '../../../../data/remote/pos_suspended_api.dart';
import '../../../../core/i18n/locale_helper.dart';

class SuspendedSalesDialog extends StatefulWidget {
  const SuspendedSalesDialog({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  State<SuspendedSalesDialog> createState() => _SuspendedSalesDialogState();
}

class _SuspendedSalesDialogState extends State<SuspendedSalesDialog> {
  List<dynamic> _suspendedSales = [];
  bool _isLoading = true;
  String _countryCode = 'KR';

  @override
  void initState() {
    super.initState();
    _loadSuspendedSales();
  }

  Future<void> _loadSuspendedSales() async {
    setState(() => _isLoading = true);
    
    try {
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      final token = await auth.getAccessToken();
      final storeId = session['storeId'];
      final sessionCountry = (session['country'] as String?)?.trim();
      final uiLanguage = (session['uiLanguage'] as String?)?.trim() ?? '';

      if (storeId == null) throw Exception('매장 정보가 없습니다.');
      final derivedCountry = () {
        if (uiLanguage.startsWith('ja')) return 'JP';
        if (uiLanguage == 'zh-TW') return 'TW';
        if (uiLanguage == 'zh-HK') return 'HK';
        if (uiLanguage == 'en-SG') return 'SG';
        if (uiLanguage == 'en-AU') return 'AU';
        return 'KR';
      }();
      _countryCode = (sessionCountry != null && sessionCountry.isNotEmpty) ? sessionCountry : derivedCountry;

      // ✅ 1. 로컬 DB에서 보류 거래 조회
      List<dynamic> localSales = [];
      try {
        // TODO: 로컬 DB에 보류 거래 테이블이 있다면 조회
        // localSales = await widget.database.getSuspendedSales(storeId);
      } catch (e) {
        print('[SuspendedSales] Local DB query failed: $e');
      }

      // ✅ 2. 서버에서 보류 거래 조회 (실패해도 계속)
      List<dynamic> serverSales = [];
      String? serverError;
      if (token != null) {
        try {
          final api = PosSuspendedApi(accessToken: token);
          serverSales = await api.getSuspendedSales(storeId);
        } catch (e) {
          print('[SuspendedSales] Server fetch failed: $e');
          serverError = e.toString();
        }
      }

      // ✅ 3. 병합 (중복 제거)
      final mergedSales = _mergeSuspendedSales(localSales, serverSales);
      
      if (mounted) {
        setState(() {
          _suspendedSales = mergedSales;
          _isLoading = false;
        });

        // ✅ 4. 서버 오류 알림 (로컬도 없고 서버도 실패한 경우)
        if (mergedSales.isEmpty && serverError != null && localSales.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('⚠️ 서버 연결 실패'),
                  Text(
                    '로컬 보류 거래도 없습니다',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.translate('sales.suspendedOrderLoadFailed')}: $e')),
        );
      }
    }
  }

  /// 로컬과 서버 보류 거래 병합 (중복 제거)
  List<dynamic> _mergeSuspendedSales(
    List<dynamic> local,
    List<dynamic> server,
  ) {
    final merged = <String, dynamic>{};
    
    // ✅ 로컬 우선 (최신 정보)
    for (final sale in local) {
      merged[sale['id']] = {
        ...sale,
        'source': 'local',
        'isLocalOnly': true,
      };
    }
    
    // ✅ 서버 정보 추가 (로컬에 없는 것만)
    for (final sale in server) {
      if (merged.containsKey(sale['id'])) {
        // 이미 로컬에 있으면 서버 동기화됨 표시
        merged[sale['id']]!['isLocalOnly'] = false;
      } else {
        merged[sale['id']] = {
          ...sale,
          'source': 'server',
          'isLocalOnly': false,
        };
      }
    }
    
    // ✅ 생성일 내림차순 정렬 (최신순)
    final result = merged.values.toList()
      ..sort((a, b) {
        try {
          final aDate = DateTime.parse(a['createdAt']);
          final bDate = DateTime.parse(b['createdAt']);
          return bDate.compareTo(aDate);
        } catch (e) {
          return 0;
        }
      });
    
    return result;
  }

  Future<void> _deleteSale(String id) async {
    try {
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      final token = await auth.getAccessToken();
      final storeId = session['storeId'];
      
      if (storeId == null || token == null) return;

      final api = PosSuspendedApi(accessToken: token);
      await api.deleteSuspendedSale(storeId, id);
      _loadSuspendedSales();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context)!.translate('sales.suspendedOrderDeleteFailed')}: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = LocaleHelper.getCurrencyFormat(_countryCode);
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.pause_circle_outline, color: AppTheme.warning),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.translate('sales.suspendedSalesTitle'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: AppLocalizations.of(context)!.translate('common.close'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_suspendedSales.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(AppLocalizations.of(context)!.translate('sales.noSuspendedOrders'), style: const TextStyle(color: Colors.grey)),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suspendedSales.length,
                  itemBuilder: (context, index) {
                    final sale = _suspendedSales[index];
                    final date = DateTime.parse(sale['createdAt']);
                    final isLocalOnly = sale['isLocalOnly'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLocalOnly ? Colors.orange : AppTheme.border,
                          width: isLocalOnly ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: () => Navigator.pop(context, sale),
                        leading: isLocalOnly
                            ? const Tooltip(
                                message: '미전송 (서버 동기화 필요)',
                                child: Icon(
                                  Icons.cloud_off,
                                  color: Colors.orange,
                                ),
                              )
                            : null,
                        title: Text(
                          currencyFormat.format(num.tryParse(sale['totalAmount'].toString()) ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dateFormat.format(date)),
                            if (isLocalOnly)
                              const Text(
                                '⚠️ 로컬 전용 (서버 미동기화)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, sale),
                              child: Text(AppLocalizations.of(context)!.translate('sales.retrieve')),
                            ),
                            IconButton(
                              onPressed: () => _deleteSale(sale['id']),
                              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
