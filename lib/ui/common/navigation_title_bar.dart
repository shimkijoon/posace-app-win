import 'package:flutter/material.dart';
import '../../core/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/i18n/app_localizations.dart';
import '../../data/local/app_database.dart';
import 'navigation_tab.dart';
import '../home/home_page.dart';
import '../sales/sales_page.dart';
import '../tables/table_layout_page.dart';
import '../orders/unified_order_management_page.dart';
import '../sales/sales_inquiry_page.dart';
import '../home/settings_page.dart';

class NavigationTitleBar extends StatelessWidget {
  const NavigationTitleBar({
    super.key,
    required this.currentTab,
    required this.database,
    this.onTabChanged,
  });

  final NavigationTab currentTab;
  final AppDatabase database;
  final Function(NavigationTab)? onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60, // 상단 탭 크기 축소
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 좌측: 탭 네비게이션
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildNavTab(
                    context,
                    tab: NavigationTab.home,
                    icon: Icons.home,
                    label: AppLocalizations.of(context)!.translate('nav.home'),
                  ),
                  _buildNavTab(
                    context,
                    tab: NavigationTab.sales,
                    icon: Icons.point_of_sale,
                    label: AppLocalizations.of(context)!.translate('nav.sales'),
                  ),
                  _buildNavTab(
                    context,
                    tab: NavigationTab.tables,
                    icon: Icons.table_restaurant,
                    label: AppLocalizations.of(context)!.translate('nav.tables'),
                  ),
                  _buildNavTab(
                    context,
                    tab: NavigationTab.orders,
                    icon: Icons.restaurant_menu,
                    label: AppLocalizations.of(context)!.translate('nav.orders'),
                  ),
                  _buildNavTab(
                    context,
                    tab: NavigationTab.history,
                    icon: Icons.history,
                    label: AppLocalizations.of(context)!.translate('nav.history'),
                  ),
                  _buildNavTab(
                    context,
                    tab: NavigationTab.settings,
                    icon: Icons.settings,
                    label: AppLocalizations.of(context)!.translate('nav.settings'),
                  ),
                ],
              ),
            ),
          ),
          
          // 우측: 버전 정보
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${AppConfig.appName} v1.0',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab(
    BuildContext context, {
    required NavigationTab tab,
    required IconData icon,
    required String label,
  }) {
    final isActive = currentTab == tab;
    
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToTab(context, tab),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isActive 
                ? AppTheme.primary.withOpacity(0.1)
                : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive 
                ? Border.all(color: AppTheme.primary.withOpacity(0.3))
                : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive 
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive 
                      ? AppTheme.primary
                      : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToTab(BuildContext context, NavigationTab tab) {
    if (tab == currentTab) return; // 현재 탭이면 무시
    
    Widget page;
    switch (tab) {
      case NavigationTab.home:
        page = HomePage(database: database);
        break;
      case NavigationTab.sales:
        page = SalesPage(database: database);
        break;
      case NavigationTab.tables:
        page = TableLayoutPage(database: database);
        break;
      case NavigationTab.orders:
        page = UnifiedOrderManagementPage(database: database);
        break;
      case NavigationTab.history:
        page = SalesInquiryPage(database: database);
        break;
      case NavigationTab.settings:
        page = SettingsPage(database: database);
        break;
    }

    // 현재 페이지를 새 페이지로 교체
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => page),
    );
  }
}