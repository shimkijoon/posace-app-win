import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/i18n/app_localizations.dart';

class VirtualKeypad extends StatelessWidget {
  const VirtualKeypad({
    super.key,
    required this.onKeyPress,
    required this.onDelete,
    required this.onClear,
    this.onEnter,
  });

  final ValueChanged<String> onKeyPress;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final VoidCallback? onEnter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRow(['1', '2', '3']),
          const SizedBox(height: 8),
          _buildRow(['4', '5', '6']),
          const SizedBox(height: 8),
          _buildRow(['7', '8', '9']),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildButton('C', color: Colors.red.shade50, textColor: Colors.red, onTap: onClear)),
              const SizedBox(width: 8),
              Expanded(child: _buildButton('0', onTap: () => onKeyPress('0'))),
              const SizedBox(width: 8),
              Expanded(child: _buildButton('⌫', onTap: onDelete)),
            ],
          ),
          if (onEnter != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: onEnter,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(AppLocalizations.of(context)!.translate('payment.inputComplete'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildButton(key, onTap: () => onKeyPress(key)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildButton(String text, {required VoidCallback onTap, Color? color, Color? textColor}) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.white,
          foregroundColor: textColor ?? Colors.black,
          elevation: 0,
          side: const BorderSide(color: Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
