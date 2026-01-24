import 'package:flutter/material.dart';
import '../../../core/app_config.dart';
import '../../../core/theme/app_theme.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.title,
    required this.onHomePressed,
    this.leadingIcon = Icons.home,
    this.leadingTooltip = '홈으로',
  });

  final String title;
  final VoidCallback onHomePressed;
  final IconData leadingIcon;
  final String leadingTooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, AppTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 좌측: 홈/뒤로가기 버튼 + 타이틀
          Row(
            children: [
              IconButton(
                onPressed: onHomePressed,
                icon: Icon(leadingIcon, color: Colors.white),
                tooltip: leadingTooltip,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          
          // 우측: 버전 정보
          Text(
            '${AppConfig.appName} v1.0.0',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
          ),
        ],
      ),
    );
  }
}
