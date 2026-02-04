import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/storage/auth_storage.dart';
import '../../../../data/local/app_database.dart';
import '../../../../data/local/models.dart';
import '../../../../data/remote/api_client.dart';
import '../../../../data/remote/pos_customer_api.dart';
import './member_registration_dialog.dart';

class MemberSearchDialog extends StatefulWidget {
  const MemberSearchDialog({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  State<MemberSearchDialog> createState() => _MemberSearchDialogState();
}

class _MemberSearchDialogState extends State<MemberSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<MemberModel> _results = [];
  bool _isLoading = false;

  Future<void> _search() async {
    final loc = AppLocalizations.of(context)!;
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    
    // ✅ 1. 로컬 검색
    final results = await widget.database.searchMembersByPhone(query);
    
    // ✅ 2. 온라인 검색 (로컬 결과 없을 때만)
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
    
    // ✅ 3. 결과 없을 때 명확한 메시지 및 등록 제안
    if (mounted && results.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 8),
              Text(loc.translate('customers.noSearchResultsTitle')),
            ],
          ),
          content: Text(loc.translate('customers.registerPrompt')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(loc.translate('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(loc.translate('customers.registerNew')),
            ),
          ],
        ),
      );
      
      if (confirm == true) {
        await _openRegistration();
      }
    }
  }

  Future<void> _openRegistration() async {
    final result = await showDialog<MemberModel>(
      context: context,
      builder: (context) => MemberRegistrationDialog(database: widget.database),
    );

    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.person_search_outlined, color: AppTheme.primary),
                const SizedBox(width: 12),
                Text(
                  loc.translate('customers.searchTitle'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: loc.translate('customers.searchHint'),
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.phone,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _search,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(loc.translate('common.search')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_results.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final member = _results[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ListTile(
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
                              
                              // 최신 회원 정보 가져오기 (포인트 등)
                              final updatedMember = await customerApi.searchOnlineMember(storeId, member.phone);
                              await widget.database.upsertMember(updatedMember);
                              finalMember = updatedMember;
                              
                              print('[MemberSearch] ✅ Updated member info from server');
                            }
                          } catch (e) {
                            print('[MemberSearch] ⚠️ Failed to fetch latest member info, using cached: $e');
                            // 실패해도 캐시된 정보 사용
                          }
                          
                          if (mounted) {
                            Navigator.pop(context, finalMember);
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: Text(member.name[0], style: const TextStyle(color: AppTheme.primary)),
                        ),
                        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(member.phone),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(AppLocalizations.of(context)!.translate('sales.points'), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            Text('${member.points}P', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            else if (_searchController.text.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(AppLocalizations.of(context)!.translate('customers.noSearchResults'), style: const TextStyle(color: Colors.grey)),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openRegistration,
              icon: const Icon(Icons.person_add_outlined),
              label: Text(AppLocalizations.of(context)!.translate('customers.registerNew')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
