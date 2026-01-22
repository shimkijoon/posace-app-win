import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/local/app_database.dart';
import '../../../../data/local/models.dart';

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
    final results = await widget.database.searchMembersByPhone(query);
    setState(() {
      _results = results;
      _isLoading = false;
    });
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
                  child: const Text('검색'),
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
                            const Text('보유 포인트', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text('${member.points}P', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            else if (_searchController.text.isNotEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('검색 결과가 없습니다.', style: TextStyle(color: Colors.grey)),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: 회원 신규 등록 기능 (다음 고도화 시)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원 신규 등록은 현재 백오피스에서 가능합니다.')));
              },
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('신규 회원 등록'),
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
