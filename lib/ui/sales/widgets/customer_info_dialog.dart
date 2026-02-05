import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CustomerInfo {
  final String name;
  final String phone;
  final DateTime? scheduledTime;
  final String? note;

  CustomerInfo({
    required this.name,
    required this.phone,
    this.scheduledTime,
    this.note,
  });
}

class CustomerInfoDialog extends StatefulWidget {
  const CustomerInfoDialog({Key? key}) : super(key: key);

  @override
  State<CustomerInfoDialog> createState() => _CustomerInfoDialogState();
}

class _CustomerInfoDialogState extends State<CustomerInfoDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  DateTime? _selectedTime;
  bool _isScheduled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final now = DateTime.now();
    final initialTime = TimeOfDay.fromDateTime(
      _selectedTime ?? now.add(const Duration(minutes: 15))
    );

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      final selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      // 현재 시간보다 이전이면 다음날로 설정
      final finalDateTime = selectedDateTime.isBefore(now)
          ? selectedDateTime.add(const Duration(days: 1))
          : selectedDateTime;

      setState(() {
        _selectedTime = finalDateTime;
      });
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '테이크아웃 주문 정보',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 고객명 입력
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '고객명 *',
                  hintText: '고객 이름을 입력하세요',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '고객명을 입력해주세요';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // 연락처 입력
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: '연락처 (선택사항)',
                  hintText: '010-1234-5678',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 20),

              // 예약 시간 설정
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '픽업 시간',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Radio<bool>(
                          value: false,
                          groupValue: _isScheduled,
                          onChanged: (value) => setState(() {
                            _isScheduled = false;
                            _selectedTime = null;
                          }),
                          activeColor: AppTheme.primary,
                        ),
                        const Text('즉시 조리'),
                        const SizedBox(width: 20),
                        Radio<bool>(
                          value: true,
                          groupValue: _isScheduled,
                          onChanged: (value) => setState(() {
                            _isScheduled = true;
                          }),
                          activeColor: AppTheme.primary,
                        ),
                        const Text('예약 주문'),
                      ],
                    ),
                    
                    if (_isScheduled) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _selectTime,
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            _selectedTime != null
                                ? '픽업 시간: ${_formatTime(_selectedTime!)}'
                                : '픽업 시간 선택',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 안내 메시지
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '주문번호가 발행되어 조리 완료 시 알림을 받을 수 있습니다.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '취소',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              if (_isScheduled && _selectedTime == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('픽업 시간을 선택해주세요')),
                );
                return;
              }

              final customerInfo = CustomerInfo(
                name: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                scheduledTime: _isScheduled ? _selectedTime : null,
              );
              Navigator.pop(context, customerInfo);
            }
          },
          icon: const Icon(Icons.restaurant_menu, size: 18),
          label: const Text('주문 등록'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}