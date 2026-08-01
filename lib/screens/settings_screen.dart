import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../store/wattwise_store.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _popupBannersEnabled = true;
  bool _protectedTariff = false;
  String _selectedProvider = 'LESCO';

  final _providers = [
    'LESCO',
    'MEPCO',
    'FESCO',
    'IESCO',
    'PESCO',
    'GEPCO',
    'HESCO',
    'SEPCO',
    'QESCO',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (context.mounted) {
              context.pop();
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('General Preferences'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.building2, color: AppTheme.accent),
                  ),
                  title: const Text('Default Provider',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Primary electricity company'),
                  trailing: DropdownButton<String>(
                    value: _selectedProvider,
                    underline: const SizedBox(),
                    items: _providers
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedProvider = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Notifications & Banners'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.bell, color: AppTheme.success),
                  ),
                  title: const Text('Reading Reminders',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Receive alerts before cycle ends'),
                  value: _notificationsEnabled,
                  onChanged: (val) => setState(() => _notificationsEnabled = val),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.messageSquare, color: AppTheme.accent),
                  ),
                  title: const Text('Pop-up Banners',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Floating in-app pop-up notifications'),
                  value: _popupBannersEnabled,
                  onChanged: (val) => setState(() => _popupBannersEnabled = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Billing Calculation'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.shieldCheck, color: AppTheme.warning),
                  ),
                  title: const Text('Protected Consumer Tariff',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Apply subsidized rates for under 200 units'),
                  value: _protectedTariff,
                  onChanged: (val) => setState(() => _protectedTariff = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Data & Storage'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.trash2, color: AppTheme.danger),
                  ),
                  title: const Text('Reset Dismissed Alerts',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Clear all hidden notification cards'),
                  onTap: () {
                    final store = context.read<WattWiseStore>();
                    store.dismissed.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Dismissed alerts reset.')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'WattWise v1.0.0 • Smart Electricity Meter Assistant',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
