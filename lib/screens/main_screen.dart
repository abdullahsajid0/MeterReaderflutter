import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'insights_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const InsightsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'WattWise' : 'Insights',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.slidersHorizontal, size: 20),
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
        ),
        actions: [
          Consumer<WattWiseStore>(
            builder: (context, store, child) {
              final alerts = store.buildAlerts();
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.bell, size: 20),
                    tooltip: 'Notifications',
                    onPressed: () => context.push('/alerts'),
                  ),
                  if (alerts.isNotEmpty)
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.surface, width: 1.5),
                        ),
                        child: Text(
                          '${alerts.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: const Border(
            top: BorderSide(color: AppTheme.border, width: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.accent.withValues(alpha: 0.12),
          elevation: 0,
          height: 64,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(LucideIcons.gauge, size: 22, color: AppTheme.textSecondary),
              selectedIcon: Icon(LucideIcons.gauge, size: 22, color: AppTheme.accent),
              label: 'Meters',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.trendingUp, size: 22, color: AppTheme.textSecondary),
              selectedIcon: Icon(LucideIcons.trendingUp, size: 22, color: AppTheme.accent),
              label: 'Insights',
            ),
          ],
        ),
      ),
    );
  }
}
