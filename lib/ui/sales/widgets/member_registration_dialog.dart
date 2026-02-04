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
    final loc = AppLocalizations.of(context)!;
    try {
      final authStorage = AuthStorage();
      final session = await authStorage.getSessionInfo();
      final accessToken = await authStorage.getAccessToken();
      final storeId = session['storeId'];

      if (storeId == null || accessToken == null) {
        throw Exception(loc.translate('auth.noLoginInfo') ?? '로그인 정보가 없습니다.');
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
        SnackBar(
          content: Text('${loc.translate('customers.registerFailed') ?? '회원 등록 실패'}: $e'), 
          backgroundColor: Colors.red
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
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
              Text(
                loc.translate('customers.registerNew') ?? '신규 회원 등록',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: loc.translate('customers.name') ?? '이름',
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => 
                  (value == null || value.isEmpty) ? loc.translate('customers.enterName') ?? '이름을 입력하세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: loc.translate('customers.phone') ?? '휴대폰 번호',
                  hintText: loc.translate('customers.phoneHint') ?? '전화번호 입력',
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) return loc.translate('customers.enterPhone') ?? '번호를 입력하세요.';
                  // Relaxed validation: just length check or nothing
                  if (value.length < 3) return loc.translate('customers.phoneTooShort') ?? '번호가 너무 짧습니다.';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: Text(loc.translate('common.cancel')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(loc.translate('common.confirm') ?? '등록'),
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
