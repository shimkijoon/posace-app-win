import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/storage/auth_storage.dart';
import '../../../../data/local/app_database.dart';
import '../../../../data/local/models.dart';
import '../../../../data/remote/api_client.dart';
import '../../../../data/remote/pos_customer_api.dart';

class MemberRegistrationDialog extends StatefulWidget {
  const MemberRegistrationDialog({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  State<MemberRegistrationDialog> createState() => _MemberRegistrationDialogState();
}

class _MemberRegistrationDialogState extends State<MemberRegistrationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final authStorage = AuthStorage();
      final session = await authStorage.getSessionInfo();
      final accessToken = await authStorage.getAccessToken();
      final storeId = session['storeId'];

      if (storeId == null || accessToken == null) {
        throw Exception('로그인 정보가 없습니다.');
      }

      final apiClient = ApiClient(accessToken: accessToken);
      final customerApi = PosCustomerApi(apiClient);

      final member = await customerApi.registerMember(
        storeId,
        _nameController.text.trim(),
        _phoneController.text.trim(),
      );

      // 로컬 DB 업데이트
      await widget.database.upsertMember(member);

      if (!mounted) return;
      Navigator.pop(context, member);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원 등록 실패: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '신규 회원 등록',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => 
                  (value == null || value.isEmpty) ? '이름을 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '휴대폰 번호',
                  hintText: '010-0000-0000',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return '번호를 입력하세요.';
                  if (!RegExp(r'^010-\d{4}-\d{4}$').hasMatch(value)) {
                    return '형식이 올바르지 않습니다 (010-0000-0000).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('등록'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
