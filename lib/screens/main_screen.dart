import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
        title: Text(_currentIndex == 0 ? 'WattWise' : 'Insights'),
        actions: [
          Consumer<WattWiseStore>(
            builder: (context, store, child) {
              final alerts = store.buildAlerts();
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.bell),
                    onPressed: () => context.push('/alerts'),
                  ),
                  if (alerts.isNotEmpty)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${alerts.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () {}, // Optional: Add settings route later
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(LucideIcons.barChart2),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}
