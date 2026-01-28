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
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    
    // 1. Local Search
    final results = await widget.database.searchMembersByPhone(query);
    
    // 2. Online Search (if local not enough or always to be sure)
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
      }
    }

    setState(() {
      _results = results;
      _isLoading = false;
    });
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
                const Text(
                  '회원 찾기',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      hintText: '휴대폰 번호 뒷자리 (예: 1234)',
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
                  child: Text(AppLocalizations.of(context)!.translate('common.search')),
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
                        onTap: () => Navigator.pop(context, member),
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
                  child: Text(AppLocalizations.of(context)!.translate('sales.noSearchResults'), style: const TextStyle(color: Colors.grey)),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openRegistration,
              icon: const Icon(Icons.person_add_outlined),
              label: Text(AppLocalizations.of(context)!.translate('sales.registerNewMember')),
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
